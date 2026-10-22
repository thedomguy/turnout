//go:build darwin && cgo

package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"log/slog"

	"turnout/router/internal/dispatch"
	"turnout/router/internal/launch"
)

//export TurnoutHandleURL
func TurnoutHandleURL(url *C.char, forcePicker C.int) {
	if url == nil {
		return
	}
	u := C.GoString(url)
	force := forcePicker != 0
	slog.Info("url event", "url", u, "force_picker", force)
	if err := dispatch.HandleURL(u, force); err != nil {
		slog.Error("dispatch", "url", u, "err", err)
	}
}

//export TurnoutPrewarm
func TurnoutPrewarm() {
	launch.PrewarmPicker()
}
