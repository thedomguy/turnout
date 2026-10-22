package launch

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type profileScheme int

const (
	firefoxProfiles profileScheme = iota
	chromiumProfiles
)

// profileBrowsers maps app names to how their profiles are stored, relative to
// ~/Library/Application Support.
var profileBrowsers = map[string]struct {
	scheme profileScheme
	dir    string
}{
	"Firefox":                   {firefoxProfiles, "Firefox"},
	"Firefox Developer Edition": {firefoxProfiles, "Firefox"},
	"Firefox Nightly":           {firefoxProfiles, "Firefox"},
	"Zen":                       {firefoxProfiles, "zen"},
	"LibreWolf":                 {firefoxProfiles, "librewolf"},
	"Floorp":                    {firefoxProfiles, "Floorp"},
	"Google Chrome":             {chromiumProfiles, "Google/Chrome"},
	"Google Chrome Beta":        {chromiumProfiles, "Google/Chrome Beta"},
	"Brave Browser":             {chromiumProfiles, "BraveSoftware/Brave-Browser"},
	"Brave Browser Beta":        {chromiumProfiles, "BraveSoftware/Brave-Browser-Beta"},
	"Microsoft Edge":            {chromiumProfiles, "Microsoft Edge"},
	"Chromium":                  {chromiumProfiles, "Chromium"},
	"Vivaldi":                   {chromiumProfiles, "Vivaldi"},
}

// browserProfile is one profile as shown in the browser's UI, with the flags that select it.
type browserProfile struct {
	name string
	args []string
}

// ProfileArgs returns the command-line flags that open appName in the profile called name.
func ProfileArgs(appName, name string) ([]string, error) {
	b, ok := profileBrowsers[appName]
	if !ok {
		return nil, fmt.Errorf("profiles: %q is not a supported Firefox- or Chromium-family browser", appName)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	root := filepath.Join(home, "Library", "Application Support", b.dir)
	var profiles []browserProfile
	if b.scheme == firefoxProfiles {
		profiles = firefoxProfileList(root)
	} else {
		profiles = chromiumProfileList(root)
	}
	p, err := matchProfile(profiles, name)
	if err != nil {
		return nil, fmt.Errorf("profiles: %s: %w", appName, err)
	}
	return p.args, nil
}

// matchProfile prefers an exact case-insensitive name match, then a unique substring match
// (so "work" finds "Work - Acme").
func matchProfile(profiles []browserProfile, want string) (browserProfile, error) {
	w := strings.ToLower(strings.TrimSpace(want))
	var partial []browserProfile
	for _, p := range profiles {
		n := strings.ToLower(p.name)
		if n == w {
			return p, nil
		}
		if strings.Contains(n, w) {
			partial = append(partial, p)
		}
	}
	if len(partial) == 1 {
		return partial[0], nil
	}
	names := make([]string, 0, len(profiles))
	for _, p := range profiles {
		names = append(names, p.name)
	}
	sort.Strings(names)
	if len(partial) > 1 {
		return browserProfile{}, fmt.Errorf("profile %q is ambiguous; have %q", want, names)
	}
	return browserProfile{}, fmt.Errorf("no profile %q; have %q", want, names)
}

// firefoxProfileList reads profiles from Firefox's profile manager store (Profile Groups/*.sqlite,
// Firefox 138+) and the classic profiles.ini. Both are opened with --profile <dir>.
func firefoxProfileList(root string) []browserProfile {
	var out []browserProfile
	seen := map[string]bool{}
	add := func(name, path string, relative bool) {
		if name == "" || path == "" {
			return
		}
		if relative {
			path = filepath.Join(root, path)
		}
		if seen[path] {
			return
		}
		seen[path] = true
		out = append(out, browserProfile{name: name, args: []string{"--profile", path}})
	}

	dbs, _ := filepath.Glob(filepath.Join(root, "Profile Groups", "*.sqlite"))
	for _, db := range dbs {
		rows, err := exec.Command("/usr/bin/sqlite3", "-readonly", "-separator", "\t", db,
			"SELECT name, path FROM Profiles").Output()
		if err != nil {
			continue
		}
		for _, line := range strings.Split(strings.TrimSpace(string(rows)), "\n") {
			if name, path, ok := strings.Cut(line, "\t"); ok {
				add(name, path, !filepath.IsAbs(path))
			}
		}
	}

	for _, s := range parseProfilesIni(filepath.Join(root, "profiles.ini")) {
		add(s["Name"], s["Path"], s["IsRelative"] != "0")
	}
	return out
}

// parseProfilesIni returns the key/values of each [Profile*] section.
func parseProfilesIni(path string) []map[string]string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	var sections []map[string]string
	var cur map[string]string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if strings.HasPrefix(line, "[") {
			cur = nil
			if strings.HasPrefix(line, "[Profile") {
				cur = map[string]string{}
				sections = append(sections, cur)
			}
			continue
		}
		if k, v, ok := strings.Cut(line, "="); ok && cur != nil {
			cur[k] = v
		}
	}
	return sections
}

// chromiumProfileList reads display names from "Local State" (profile.info_cache), opened with
// --profile-directory=<dir>.
func chromiumProfileList(root string) []browserProfile {
	b, err := os.ReadFile(filepath.Join(root, "Local State"))
	if err != nil {
		return nil
	}
	var state struct {
		Profile struct {
			InfoCache map[string]struct {
				Name string `json:"name"`
			} `json:"info_cache"`
		} `json:"profile"`
	}
	if json.Unmarshal(b, &state) != nil {
		return nil
	}
	var out []browserProfile
	for dir, info := range state.Profile.InfoCache {
		out = append(out, browserProfile{name: info.Name, args: []string{"--profile-directory=" + dir}})
	}
	return out
}
