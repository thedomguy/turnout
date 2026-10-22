package routerlog

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"

	"turnout/router/internal/config"
)

// Setup configures the default slog logger for the macOS Router process.
// Debug mode (TURNOUT_DEBUG non-empty, or ~/.config/turnout/router.debug exists):
// log level is info, and logs are appended to ~/.config/turnout/router.log as well as stderr.
// Otherwise only errors are logged to stderr.
func Setup() {
	turnoutDir := filepath.Dir(config.DefaultRouterPath())
	debug := os.Getenv("TURNOUT_DEBUG") != ""
	if !debug {
		if st, err := os.Stat(filepath.Join(turnoutDir, "router.debug")); err == nil && !st.IsDir() {
			debug = true
		}
	}

	level := slog.LevelError
	if debug {
		level = slog.LevelInfo
	}

	w := io.Writer(os.Stderr)
	if debug {
		_ = os.MkdirAll(turnoutDir, 0755)
		if f, err := os.OpenFile(filepath.Join(turnoutDir, "router.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644); err == nil {
			w = io.MultiWriter(os.Stderr, f)
		}
	}

	slog.SetDefault(slog.New(slog.NewTextHandler(w, &slog.HandlerOptions{Level: level})))
}
