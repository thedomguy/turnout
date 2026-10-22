//go:build darwin && cgo

package main

/*
#cgo CFLAGS: -fobjc-arc -mmacosx-version-min=12.0
#cgo LDFLAGS: -framework Cocoa -framework Carbon -framework ApplicationServices

void turnout_run_app(void);
*/
import "C"

import (
	"runtime"

	"turnout/router/internal/routerlog"
)

func main() {
	routerlog.Setup()
	runtime.LockOSThread()
	C.turnout_run_app()
}
