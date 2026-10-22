package frecency

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"turnout/router/internal/config"
)

const currentVersion = 1

// Data is ~/.config/turnout/frecency.json
type Data struct {
	Version int                              `json:"version"`
	Domains map[string]map[string]BrowserHit `json:"domains"`
}

// BrowserHit tracks usage per browser for an eTLD+1 key.
type BrowserHit struct {
	Hits     int     `json:"hits"`
	Score    float64 `json:"score"`
	LastUsed string  `json:"last_used,omitempty"`
}

// Load reads frecency.json. Missing file returns empty store.
func Load(path string) (*Data, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return empty(), nil
		}
		return nil, err
	}
	var d Data
	if err := json.Unmarshal(b, &d); err != nil {
		return nil, err
	}
	if d.Domains == nil {
		d.Domains = map[string]map[string]BrowserHit{}
	}
	if d.Version == 0 {
		d.Version = currentVersion
	}
	return &d, nil
}

func empty() *Data {
	return &Data{
		Version: currentVersion,
		Domains: map[string]map[string]BrowserHit{},
	}
}

// EmptyForTest returns an empty in-memory store for tests.
func EmptyForTest() *Data { return empty() }

// SaveAtomic writes JSON via temp file + rename.
func SaveAtomic(path string, d *Data) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	d.Version = currentVersion
	b, err := json.MarshalIndent(d, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// Top returns the highest-score browser for domain if thresholds are met.
func Top(d *Data, domain string, pol config.FrecencySettings) (browser string, ok bool) {
	if d == nil || domain == "" {
		return "", false
	}
	byBrowser, exists := d.Domains[domain]
	if !exists || len(byBrowser) == 0 {
		return "", false
	}
	var bestName string
	var bestScore float64
	var bestHits int
	for name, h := range byBrowser {
		if h.Score > bestScore || (h.Score == bestScore && h.Hits > bestHits) {
			bestScore = h.Score
			bestHits = h.Hits
			bestName = name
		}
	}
	minHits := pol.MinHits
	minScore := pol.MinScore
	if minHits <= 0 {
		minHits = 2
	}
	if minScore <= 0 {
		minScore = 1
	}
	if bestHits >= minHits && bestScore >= minScore {
		return bestName, true
	}
	return "", false
}

// Bump increases score/hits for domain+browser (picker or auto frecency path).
func Bump(d *Data, domain, browser string, scoreDelta float64) {
	if d.Domains == nil {
		d.Domains = map[string]map[string]BrowserHit{}
	}
	if d.Domains[domain] == nil {
		d.Domains[domain] = map[string]BrowserHit{}
	}
	cur := d.Domains[domain][browser]
	cur.Hits++
	cur.Score += scoreDelta
	if cur.Score < 0 {
		cur.Score = 0
	}
	cur.LastUsed = time.Now().UTC().Format(time.RFC3339)
	d.Domains[domain][browser] = cur
}

// RecordPick is used by the picker after a manual choice.
func RecordPick(path, rawURL, domain, browser string) error {
	if domain == "" || browser == "" {
		return fmt.Errorf("frecency: domain and browser required")
	}
	d, err := Load(path)
	if err != nil {
		return err
	}
	Bump(d, domain, browser, 1)
	return SaveAtomic(path, d)
}
