//go:build !darwin

package launch

func trySpawnPickerEmbedded(string) bool { return false }
