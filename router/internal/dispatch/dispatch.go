package dispatch

import (
	"fmt"
	"log/slog"
	"strings"

	"turnout/router/internal/config"
	"turnout/router/internal/frecency"
	"turnout/router/internal/launch"
	"turnout/router/internal/route"
)

type resolved struct {
	cfg      *config.RouterConfig
	data     *frecency.Data
	freqPath string
	res      *route.Result
}

// resolve loads config + frecency and decides where absURL goes.
// forcePicker (Option held while clicking) bypasses policy and always shows the picker.
func resolve(absURL string, forcePicker bool) (*resolved, error) {
	cfgPath := config.DefaultRouterPath()
	cfg, err := config.Load(cfgPath)
	if err != nil {
		slog.Error("config load", "path", cfgPath, "err", err)
		return nil, err
	}

	freqPath := config.DefaultFrecencyPath()
	data, err := frecency.Load(freqPath)
	if err != nil {
		slog.Error("frecency load", "path", freqPath, "err", err)
		return nil, err
	}

	engine, err := route.NewEngine(cfg)
	if err != nil {
		slog.Error("route engine", "err", err)
		return nil, err
	}

	var res *route.Result
	if forcePicker {
		res = &route.Result{Decision: route.DelegatePicker, TargetURL: absURL}
	} else if res, err = engine.Resolve(absURL, data); err != nil {
		return nil, err
	}
	return &resolved{cfg: cfg, data: data, freqPath: freqPath, res: res}, nil
}

// HandleURL resolves routing, launches browser or picker, updates frecency when needed.
func HandleURL(absURL string, forcePicker bool) error {
	r, err := resolve(absURL, forcePicker)
	if err != nil {
		return err
	}
	res := r.res

	slog.Info("route resolved", "decision", res.Decision.String(), "browser", res.Browser, "profile", res.Profile, "target_url", res.TargetURL)

	switch res.Decision {
	case route.Launch:
		err := launch.OpenApp(res.Browser, res.Profile, res.TargetURL, false)
		if err != nil && res.Profile != "" {
			// A renamed/missing profile shouldn't swallow the link: open it in the browser anyway.
			slog.Error("open profile, falling back to browser default", "browser", res.Browser, "profile", res.Profile, "err", err)
			err = launch.OpenApp(res.Browser, "", res.TargetURL, false)
		}
		if err != nil {
			slog.Error("open app", "browser", res.Browser, "err", err)
			return err
		}
		if res.RecordFrecency && res.FrecencyDomain != "" {
			frecency.Bump(r.data, res.FrecencyDomain, res.Browser, 1)
			if err := frecency.SaveAtomic(r.freqPath, r.data); err != nil {
				slog.Error("frecency save", "err", err)
			}
		}
	case route.DelegatePicker:
		if err := launch.OpenPicker(res.TargetURL, r.cfg.Picker.BundleID); err != nil {
			slog.Error("open picker", "err", err)
			return err
		}
	}
	return nil
}

// Explain describes what HandleURL would do for absURL without opening anything.
func Explain(absURL string, forcePicker bool) (string, error) {
	r, err := resolve(absURL, forcePicker)
	if err != nil {
		return "", err
	}
	res := r.res
	if res.Decision == route.DelegatePicker {
		return fmt.Sprintf("decision: %s (picker %s)", res.Decision, r.cfg.Picker.BundleID), nil
	}
	args, err := launch.OpenArgs(res.Browser, res.Profile, res.TargetURL, false)
	if err != nil {
		return "", err
	}
	quoted := make([]string, len(args))
	for i, a := range args {
		quoted[i] = fmt.Sprintf("%q", a)
	}
	return fmt.Sprintf("decision: %s\nbrowser: %s\nprofile: %s\nopen %s",
		res.Decision, res.Browser, res.Profile, strings.Join(quoted, " ")), nil
}
