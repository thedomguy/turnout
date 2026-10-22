package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// RouterConfig is ~/.config/turnout/router.yaml
type RouterConfig struct {
	DefaultBrowser string           `yaml:"defaultBrowser"`
	Handlers       []HandlerRule    `yaml:"handlers"`
	Denylist       []string         `yaml:"denylist"`
	Picker         PickerSettings   `yaml:"picker"`
	Frecency       FrecencySettings `yaml:"frecency"`
}

type PickerSettings struct {
	BundleID string `yaml:"bundleId"`
}

type FrecencySettings struct {
	MinHits  int     `yaml:"minHits"`
	MinScore float64 `yaml:"minScore"`
}

// HandlerRule mirrors finicky.js handlers: match is one regex or any-of list.
// Profile optionally names a browser profile (Firefox-family or Chromium-family).
type HandlerRule struct {
	Match   StringOrStringSlice `yaml:"match"`
	Browser string              `yaml:"browser"`
	Profile string              `yaml:"profile"`
}

// StringOrStringSlice unmarshals either a string or []string from YAML.
type StringOrStringSlice []string

func (s *StringOrStringSlice) UnmarshalYAML(node *yaml.Node) error {
	if node.Kind == yaml.ScalarNode {
		var one string
		if err := node.Decode(&one); err != nil {
			return err
		}
		*s = []string{one}
		return nil
	}
	var many []string
	if err := node.Decode(&many); err != nil {
		return err
	}
	*s = many
	return nil
}

// DefaultRouterPath returns ~/.config/turnout/router.yaml
func DefaultRouterPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return filepath.Join(".config", "turnout", "router.yaml")
	}
	return filepath.Join(home, ".config", "turnout", "router.yaml")
}

// DefaultFrecencyPath returns ~/.config/turnout/frecency.json
func DefaultFrecencyPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return filepath.Join(".config", "turnout", "frecency.json")
	}
	return filepath.Join(home, ".config", "turnout", "frecency.json")
}

// Load reads and parses router.yaml. Missing file returns defaults (not an error).
func Load(path string) (*RouterConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return Default(), nil
		}
		return nil, err
	}
	var c RouterConfig
	if err := yaml.Unmarshal(data, &c); err != nil {
		return nil, fmt.Errorf("router.yaml: %w", err)
	}
	c.applyDefaults()
	return &c, nil
}

// Default returns policy when router.yaml is missing (no defaultBrowser → long tail goes to picker).
func Default() *RouterConfig {
	c := &RouterConfig{}
	c.applyDefaults()
	return c
}

// ApplyDefaultsForTest exposes applyDefaults for internal tests.
func (c *RouterConfig) ApplyDefaultsForTest() { c.applyDefaults() }

func (c *RouterConfig) applyDefaults() {
	if c.Picker.BundleID == "" {
		c.Picker.BundleID = "io.turnout.picker"
	}
	if c.Frecency.MinHits == 0 && c.Frecency.MinScore == 0 {
		c.Frecency.MinHits = 2
		c.Frecency.MinScore = 1
	}
}

// Denylisted reports whether name matches denylist (substring match, case-insensitive).
func (c *RouterConfig) Denylisted(name string) bool {
	if name == "" {
		return false
	}
	for _, d := range c.Denylist {
		if d != "" && containsFold(name, d) {
			return true
		}
	}
	return false
}

func containsFold(s, sub string) bool {
	if len(sub) > len(s) {
		return false
	}
	// simple ASCII fold for bundle ids / app names
	ls, lsub := toLower(s), toLower(sub)
	for i := 0; i+len(lsub) <= len(ls); i++ {
		if ls[i:i+len(lsub)] == lsub {
			return true
		}
	}
	return false
}

func toLower(b string) string {
	r := make([]byte, len(b))
	for i := 0; i < len(b); i++ {
		c := b[i]
		if c >= 'A' && c <= 'Z' {
			c += 'a' - 'A'
		}
		r[i] = c
	}
	return string(r)
}
