//go:build darwin

package launch

import (
	"os"
	"os/exec"
	"path/filepath"
)

// embeddedPickerBinary returns the Electron picker bundled inside this app
// (Turnout.app/Contents/Helpers/Turnout Picker.app), or "" when running outside a bundle.
func embeddedPickerBinary() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	bin := filepath.Join(filepath.Dir(exe), "..", "Helpers", "Turnout Picker.app", "Contents", "MacOS", "Turnout Picker")
	if st, err := os.Stat(bin); err != nil || st.IsDir() {
		return ""
	}
	return bin
}

// PrewarmPicker starts the bundled picker with no URL so its window, browser list and icons are
// ready before the first chooser is needed. If it is already running, the new process loses the
// single-instance lock and exits at once.
func PrewarmPicker() {
	if readPickerDevPath() != "" {
		return // local dev: the picker runs from the checkout via picker-daemon
	}
	bin := embeddedPickerBinary()
	if bin == "" {
		return
	}
	cmd := exec.Command(bin)
	cmd.Env = os.Environ()
	if err := cmd.Start(); err == nil {
		go cmd.Wait()
	}
}

// trySpawnPickerEmbedded execs the bundled picker with the turnout://pick URL in argv. A running
// picker holds the single-instance lock, so a second exec just forwards the URL and exits.
func trySpawnPickerEmbedded(targetURL string) bool {
	bin := embeddedPickerBinary()
	if bin == "" {
		return false
	}
	cmd := exec.Command(bin, "turnout://pick?u="+encodePickParam(targetURL))
	cmd.Env = os.Environ()
	if err := cmd.Start(); err != nil {
		return false
	}
	go cmd.Wait() // reap the child; the picker outlives this call
	return true
}
