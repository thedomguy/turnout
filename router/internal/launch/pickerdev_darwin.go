//go:build darwin

package launch

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func turnoutConfigDir() (string, bool) {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return "", false
	}
	return filepath.Join(home, ".config", "turnout"), true
}

func readPickerDevPath() string {
	dir, ok := turnoutConfigDir()
	if !ok {
		return ""
	}
	b, err := os.ReadFile(filepath.Join(dir, "picker-dev-path"))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// findNode looks beyond PATH: apps launched by LaunchServices get /usr/bin:/bin:/usr/sbin:/sbin,
// which misses Homebrew's node.
func findNode() (string, error) {
	if p, err := exec.LookPath("node"); err == nil {
		return p, nil
	}
	for _, p := range []string{"/opt/homebrew/bin/node", "/usr/local/bin/node"} {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p, nil
		}
	}
	return "", exec.ErrNotFound
}

func spawnPickerDev(pickerDir, targetURL string) error {
	node, err := findNode()
	if err != nil {
		return err
	}
	run := filepath.Join(pickerDir, "run-electron.mjs")
	if _, err := os.Stat(run); err != nil {
		return err
	}
	pick := "turnout://pick?u=" + encodePickParam(targetURL)
	cmd := exec.Command(node, run, pick)
	cmd.Dir = pickerDir
	cmd.Env = os.Environ()
	return cmd.Start()
}

// trySpawnPickerDev starts node run-electron.mjs with app dir + turnout URL in argv.
// Used whenever ~/.config/turnout/picker-dev-path exists (local dev).
//
// If the picker is already running, a second Electron exits immediately and the first
// instance receives second-instance / the URL — unlike "open turnout://", which can
// launch the wrong registered handler (bare Electron → splash screen).
func trySpawnPickerDev(targetURL string) bool {
	devDir := readPickerDevPath()
	if devDir == "" {
		return false
	}
	if err := spawnPickerDev(devDir, targetURL); err != nil {
		return false
	}
	return true
}
