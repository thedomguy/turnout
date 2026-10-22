package route

import (
	"fmt"
	"net/url"
	"regexp"

	"golang.org/x/net/publicsuffix"

	"turnout/router/internal/config"
	"turnout/router/internal/frecency"
)

// Decision is what the router should do for a URL.
type Decision int

const (
	Launch Decision = iota
	DelegatePicker
)

func (d Decision) String() string {
	switch d {
	case Launch:
		return "launch"
	case DelegatePicker:
		return "delegate_picker"
	default:
		return fmt.Sprintf("unknown(%d)", d)
	}
}

// Result is the outcome of policy + frecency evaluation.
type Result struct {
	Decision       Decision
	Browser        string
	Profile        string
	TargetURL      string
	FrecencyDomain string
	RecordFrecency bool
}

// Engine holds compiled handler regexes.
type Engine struct {
	cfg   *config.RouterConfig
	rules []compiledRule
}

type compiledRule struct {
	res     []*regexp.Regexp
	browser string
	profile string
}

// NewEngine compiles all handler patterns.
func NewEngine(cfg *config.RouterConfig) (*Engine, error) {
	var rules []compiledRule
	for _, h := range cfg.Handlers {
		var res []*regexp.Regexp
		for _, pat := range h.Match {
			re, err := regexp.Compile(pat)
			if err != nil {
				return nil, fmt.Errorf("handler for browser %q, pattern %q: %w", h.Browser, pat, err)
			}
			res = append(res, re)
		}
		rules = append(rules, compiledRule{res: res, browser: h.Browser, profile: h.Profile})
	}
	return &Engine{cfg: cfg, rules: rules}, nil
}

// DomainKey returns eTLD+1 for raw URL string, or hostname fallback.
func DomainKey(raw string) string {
	u, err := url.Parse(raw)
	if err != nil || u.Hostname() == "" {
		return ""
	}
	host := u.Hostname()
	e, err := publicsuffix.EffectiveTLDPlusOne(host)
	if err != nil {
		return host
	}
	return e
}

// Resolve applies handlers → frecency → defaultBrowser → picker.
func (e *Engine) Resolve(urlStr string, data *frecency.Data) (*Result, error) {
	urlStr = Unwrap(urlStr)
	domain := DomainKey(urlStr)

	for _, rule := range e.rules {
		for _, re := range rule.res {
			if re.MatchString(urlStr) {
				return &Result{
					Decision:       Launch,
					Browser:        rule.browser,
					Profile:        rule.profile,
					TargetURL:      urlStr,
					FrecencyDomain: domain,
					RecordFrecency: false,
				}, nil
			}
		}
	}

	if data != nil && domain != "" {
		if b, ok := frecency.Top(data, domain, e.cfg.Frecency); ok && !e.cfg.Denylisted(b) {
			return &Result{
				Decision:       Launch,
				Browser:        b,
				TargetURL:      urlStr,
				FrecencyDomain: domain,
				RecordFrecency: true,
			}, nil
		}
	}

	if e.cfg.DefaultBrowser != "" && !e.cfg.Denylisted(e.cfg.DefaultBrowser) {
		return &Result{
			Decision:       Launch,
			Browser:        e.cfg.DefaultBrowser,
			TargetURL:      urlStr,
			FrecencyDomain: domain,
			RecordFrecency: false,
		}, nil
	}

	return &Result{
		Decision:       DelegatePicker,
		TargetURL:      urlStr,
		FrecencyDomain: domain,
		RecordFrecency: false,
	}, nil
}
