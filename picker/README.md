# Turnout Picker

Electron app (GPL-3.0) that handles `turnout://pick?u=…` and records choices to `~/.config/turnout/frecency.json`.

## Develop

```bash
npm install
TURNOUT_DEV_URL=https://example.com npm start
```

## Protocol URL

The router opens:

`turnout://pick?u=<url-encoded-base64url(https-url)>`

`u` is decoded with `decodeURIComponent`, then `Buffer.from(..., 'base64url')`.

## Packaging

`npm run package` builds a signed `release/Turnout Picker-darwin-<arch>/Turnout Picker.app` (bundle id `io.turnout.picker`, `turnout://` scheme, no Dock icon). Use `../scripts/release.sh` to build and install both apps. Only the packaged app registers `turnout://` and adds itself as a login item.
