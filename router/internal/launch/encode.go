package launch

import (
	"encoding/base64"
	"net/url"
)

func encodePickParam(targetURL string) string {
	b := []byte(targetURL)
	enc := base64.RawURLEncoding.EncodeToString(b)
	return url.QueryEscape(enc)
}
