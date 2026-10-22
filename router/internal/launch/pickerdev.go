//go:build !darwin

package launch

func trySpawnPickerDev(string) bool { return false }
