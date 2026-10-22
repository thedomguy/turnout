package launch

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestMatchProfile(t *testing.T) {
	profiles := []browserProfile{
		{name: "Personal", args: []string{"a"}},
		{name: "Work - Acme", args: []string{"b"}},
		{name: "Work", args: []string{"c"}},
	}
	if p, err := matchProfile(profiles, "work"); err != nil || p.args[0] != "c" {
		t.Fatalf("exact match should win: %+v %v", p, err)
	}
	if p, err := matchProfile(profiles, "acme"); err != nil || p.args[0] != "b" {
		t.Fatalf("unique substring: %+v %v", p, err)
	}
	if _, err := matchProfile(profiles[:2], "o"); err == nil {
		t.Fatal("ambiguous substring should error")
	}
	if _, err := matchProfile(profiles, "school"); err == nil {
		t.Fatal("missing profile should error")
	}
}

func TestFirefoxProfilesIni(t *testing.T) {
	root := t.TempDir()
	ini := "[Profile0]\nName=default-release\nIsRelative=1\nPath=Profiles/abc.default-release\n\n" +
		"[General]\nVersion=2\n\n[Profile1]\nName=abs\nIsRelative=0\nPath=/tmp/abs-profile\n"
	if err := os.WriteFile(filepath.Join(root, "profiles.ini"), []byte(ini), 0o644); err != nil {
		t.Fatal(err)
	}
	got := firefoxProfileList(root)
	want := []browserProfile{
		{name: "default-release", args: []string{"--profile", filepath.Join(root, "Profiles/abc.default-release")}},
		{name: "abs", args: []string{"--profile", "/tmp/abs-profile"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %+v want %+v", got, want)
	}
}

func TestChromiumLocalState(t *testing.T) {
	root := t.TempDir()
	state := `{"profile":{"info_cache":{"Default":{"name":"Personal"},"Profile 3":{"name":"Work"}}}}`
	if err := os.WriteFile(filepath.Join(root, "Local State"), []byte(state), 0o644); err != nil {
		t.Fatal(err)
	}
	p, err := matchProfile(chromiumProfileList(root), "work")
	if err != nil || p.args[0] != "--profile-directory=Profile 3" {
		t.Fatalf("got %+v %v", p, err)
	}
}

func TestOpenArgsWithoutProfile(t *testing.T) {
	got, err := OpenArgs("Firefox", "", "https://example.com", false)
	if err != nil || !reflect.DeepEqual(got, []string{"-a", "Firefox", "https://example.com"}) {
		t.Fatalf("got %q %v", got, err)
	}
}
