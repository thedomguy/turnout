package launch

import (
	"fmt"
	"os/exec"
)

// OpenArgs builds the `open` arguments for url in the named macOS application (-a name).
// A non-empty profile is resolved to browser-specific flags; -n makes macOS start a new
// process so the flags reach it, and the browser forwards the URL to an already-running
// instance of that profile.
func OpenArgs(appName, profile, targetURL string, background bool) ([]string, error) {
	if appName == "" {
		return nil, fmt.Errorf("launch: empty app name")
	}
	args := []string{"-a", appName}
	if background {
		args = append(args, "-g")
	}
	if profile == "" {
		return append(args, targetURL), nil
	}
	profileArgs, err := ProfileArgs(appName, profile)
	if err != nil {
		return nil, err
	}
	args = append(args, "-n", "--args")
	args = append(args, profileArgs...)
	return append(args, targetURL), nil
}

// OpenApp opens url in the named macOS application, in the given profile when set.
func OpenApp(appName, profile, targetURL string, background bool) error {
	args, err := OpenArgs(appName, profile, targetURL, background)
	if err != nil {
		return err
	}
	return exec.Command("open", args...).Run()
}

// OpenPicker shows the picker: the dev checkout when picker-dev-path exists, else the picker
// bundled inside this app, else (legacy standalone install) turnout://pick via open -b so no
// other app registered for turnout:// (e.g. a bare dev Electron) can intercept it.
func OpenPicker(targetURL, pickerBundleID string) error {
	if targetURL == "" {
		return fmt.Errorf("launch: empty target URL")
	}
	if trySpawnPickerDev(targetURL) {
		return nil
	}
	if trySpawnPickerEmbedded(targetURL) {
		return nil
	}
	pick := fmt.Sprintf("turnout://pick?u=%s", encodePickParam(targetURL))
	if pickerBundleID == "" {
		return exec.Command("open", pick).Run()
	}
	cmd := exec.Command("open", "-b", pickerBundleID, pick)
	return cmd.Run()
}
