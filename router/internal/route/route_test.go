package route

import (
	"testing"

	"turnout/router/internal/config"
	"turnout/router/internal/frecency"
)

func TestDomainKey(t *testing.T) {
	if g := DomainKey("https://gist.github.com/foo/bar"); g != "github.com" {
		t.Fatalf("got %q want github.com", g)
	}
	// Public suffix list rolls *.azure.com to registrable eTLD+1 "azure.com"
	if h := DomainKey("https://dev.azure.com/x"); h != "azure.com" {
		t.Fatalf("got %q want azure.com (PSL)", h)
	}
}

func TestHandlersFirstMatch(t *testing.T) {
	cfg := &config.RouterConfig{
		Handlers: []config.HandlerRule{
			{Match: []string{"localhost"}, Browser: "Arc"},
			{Match: []string{`github\.com/acme-corp`}, Browser: "Zen"},
		},
		DefaultBrowser: "Brave Browser",
		Frecency:       config.FrecencySettings{MinHits: 1, MinScore: 1},
	}
	cfg.ApplyDefaultsForTest()
	eng, err := NewEngine(cfg)
	if err != nil {
		t.Fatal(err)
	}
	data := frecency.EmptyForTest()
	r, err := eng.Resolve("http://localhost:3000/x", data)
	if err != nil {
		t.Fatal(err)
	}
	if r.Decision != Launch || r.Browser != "Arc" {
		t.Fatalf("got %+v", r)
	}
	r2, _ := eng.Resolve("https://github.com/acme-corp/z", data)
	if r2.Browser != "Zen" {
		t.Fatalf("got %+v", r2)
	}
	r3, _ := eng.Resolve("https://github.com/other/z", data)
	if r3.Browser != "Brave Browser" {
		t.Fatalf("default: got %+v", r3)
	}
}

func TestFrecencyWhenNoHandler(t *testing.T) {
	cfg := &config.RouterConfig{
		DefaultBrowser: "",
		Frecency:       config.FrecencySettings{MinHits: 2, MinScore: 2},
	}
	cfg.ApplyDefaultsForTest()
	eng, _ := NewEngine(cfg)
	data := frecency.EmptyForTest()
	frecency.Bump(data, "example.com", "Firefox", 1)
	r, _ := eng.Resolve("https://example.com/a", data)
	if r.Decision != DelegatePicker {
		t.Fatalf("want picker, got %+v", r)
	}
	frecency.Bump(data, "example.com", "Firefox", 1)
	r2, _ := eng.Resolve("https://example.com/b", data)
	if r2.Decision != Launch || r2.Browser != "Firefox" || !r2.RecordFrecency {
		t.Fatalf("got %+v", r2)
	}
}

func TestUnwrapTeamsSafelink(t *testing.T) {
	wrapped := "https://teams.public.onecdn.static.microsoft/evergreen-assets/safelinks/2/atp-safelinks.html?url=https%3A%2F%2Fdev.azure.com%2FIOMCloud%2FPRIMA%2520Replatforming%2F_git%2FIOM-PRIMA-Backend%2Fpullrequest%2F28623&locale=en-gb"
	want := "https://dev.azure.com/IOMCloud/PRIMA%20Replatforming/_git/IOM-PRIMA-Backend/pullrequest/28623"
	if g := Unwrap(wrapped); g != want {
		t.Fatalf("got %q want %q", g, want)
	}
	outlook := "https://ind01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fexample.com%2Fa&data=x"
	if g := Unwrap(outlook); g != "https://example.com/a" {
		t.Fatalf("got %q", g)
	}
	if g := Unwrap("https://example.com/?url=https%3A%2F%2Fevil.com"); g != "https://example.com/?url=https%3A%2F%2Fevil.com" {
		t.Fatalf("unrelated URL changed: %q", g)
	}

	cfg := &config.RouterConfig{
		Handlers:       []config.HandlerRule{{Match: []string{`dev\.azure\.com/IOM`}, Browser: "Firefox", Profile: "Work - Prima"}},
		DefaultBrowser: "Brave Browser",
		Frecency:       config.FrecencySettings{MinHits: 1, MinScore: 1},
	}
	cfg.ApplyDefaultsForTest()
	eng, err := NewEngine(cfg)
	if err != nil {
		t.Fatal(err)
	}
	r, err := eng.Resolve(wrapped, frecency.EmptyForTest())
	if err != nil {
		t.Fatal(err)
	}
	if r.Browser != "Firefox" || r.Profile != "Work - Prima" || r.TargetURL != want {
		t.Fatalf("got %+v", r)
	}
}
