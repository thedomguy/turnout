package route

import (
	"net/url"
	"strings"
)

const maxUnwrapDepth = 5

// Unwrap peels known link-wrapper redirects (Microsoft safelinks from
// Outlook/Teams) and returns the inner destination URL. Unrecognised URLs are
// returned unchanged.
func Unwrap(raw string) string {
	for i := 0; i < maxUnwrapDepth; i++ {
		inner, ok := unwrapOnce(raw)
		if !ok {
			break
		}
		raw = inner
	}
	return raw
}

func unwrapOnce(raw string) (string, bool) {
	u, err := url.Parse(raw)
	if err != nil {
		return "", false
	}
	host := strings.ToLower(u.Hostname())
	isSafelink := host == "safelinks.protection.outlook.com" ||
		strings.HasSuffix(host, ".safelinks.protection.outlook.com") ||
		strings.Contains(u.Path, "/safelinks/")
	if !isSafelink {
		return "", false
	}
	inner := u.Query().Get("url") // Query() already percent-decodes once
	if inner == "" {
		return "", false
	}
	iu, err := url.Parse(inner)
	if err != nil || (iu.Scheme != "http" && iu.Scheme != "https") || iu.Hostname() == "" {
		return "", false
	}
	return inner, true
}
