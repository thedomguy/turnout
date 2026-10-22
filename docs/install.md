# Installing Turnout

## Release install (daily use)

From the repo root run **`./scripts/release.sh`**. It runs the router and picker tests, builds `Turnout.app` (router) and `Turnout Picker.app`, signs both (see **Code signing** below), installs them into `/Applications` (override with `TURNOUT_INSTALL_DIR`), registers them with LaunchServices, seeds `~/.config/turnout/router.yaml` from `config/examples/` if it is missing, removes `~/.config/turnout/picker-dev-path`, and starts the picker in the background. The picker registers itself as a login item so it stays warm.

Then set **System Settings → Desktop & Dock → Default web browser** to **Turnout**. Re-run `release.sh` after changes; bundle IDs and signing stay the same, so the default-browser choice survives.

**Option-click** a link to skip handlers, frecency and `defaultBrowser` and open the picker.

### Code signing

Sign with a stable identity (e.g. your free **Apple Development** certificate from Xcode) so macOS keeps your default-browser choice across rebuilds. The build scripts use `SIGN_IDENTITY` if set, otherwise the first line of a git-ignored `.signing-identity` file in the repo root:

```bash
security find-identity -v -p codesigning          # list your identities
echo 'Apple Development: you@example.com (ABCDE12345)' > .signing-identity
```

With neither, both apps are signed ad-hoc (they still work; macOS may forget the default-browser choice after a rebuild).

### Requirements

macOS 12+, Xcode Command Line Tools (for `codesign` and the cgo build), Go 1.22+, Node.js 18+.

## Development

**Local debug (macOS):** from the repo root run **`./scripts/local-dev.sh`** — builds `dist/local/Turnout.app`, runs `npm install` in `picker`, clears quarantine, reveals the Router in Finder, launches it, and **starts the Turnout Picker in the background** (`scripts/picker-daemon.sh`) so `turnout://` works without opening a second terminal. Use **`./scripts/stop-local-dev.sh`** to stop the picker daemon and Router process. Options: `--no-picker`, **`--picker`** (foreground `npm start`, blocks), `--no-open`.

**One-command build + open + log check:** **`./scripts/dev-smoke.sh`** (rebuilds Router, restarts picker daemon, opens `https://example.com` via `dist/local/Turnout.app`, prints `~/.config/turnout/router.log`).

**End-to-end smoke (macOS):** `./scripts/e2e-local.sh` — rebuilds, starts the **Picker** (Electron) so `turnout://` works, enables `router.debug`, then opens `https://example.com` via the Router. Expect **`delegate_picker`** in the log and the picker UI (no `defaultBrowser` in config → long tail goes to the picker). Kills the Electron process when the script exits.

Turnout ships as two macOS apps:

1. **Turnout** — default browser (`http` / `https`); Go + Objective-C
2. **Turnout Picker** — handles `turnout://`; Electron (GPL-3.0)

## Build Router

From `turnout/router/` on macOS with Xcode CLI tools:

```bash
cd router
./scripts/package-macos-app.sh
```

This runs `CGO_ENABLED=1 go build`, assembles `Turnout.app`, and signs it (see `SIGN_IDENTITY` above). To only build the binary:

```bash
cd router
CGO_ENABLED=1 go build -o Turnout ./cmd/turnout-router
```

Package as `Turnout.app` manually: the template already sets `CFBundleIdentifier` to `io.turnout.router`, `CFBundleExecutable` to `Turnout`, and `CFBundleURLSchemes` for `http` and `https`. From `turnout/router/` after the build:

```bash
APP="Turnout.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Turnout "$APP/Contents/MacOS/"
cp macos/Info.plist.router.xml "$APP/Contents/Info.plist"
```

Resulting layout:

- `Turnout.app/Contents/MacOS/Turnout` — executable  
- `Turnout.app/Contents/Info.plist` — copy of [macos/Info.plist.router.xml](../router/macos/Info.plist.router.xml)

To customize the bundle id or URL schemes, edit `macos/Info.plist.router.xml` before copying, or edit `Contents/Info.plist` inside the app.

Set the default browser in **System Settings → Desktop & Dock → Default web browser** to **Turnout**.

## Build Picker

```bash
cd picker
npm install
npm run package   # → release/Turnout Picker-darwin-<arch>/Turnout Picker.app (signed)
```

For local development:

```bash
npm start
```

`npm run package` ([scripts/package-macos-app.mjs](../picker/scripts/package-macos-app.mjs)) uses `@electron/packager` to set the bundle id `io.turnout.picker`, declare `turnout` in `CFBundleURLTypes`, and set `LSUIElement` (no Dock icon). Only the packaged app calls `setAsDefaultProtocolClient('turnout')` and registers as a login item. The router opens it with `open -b io.turnout.picker turnout://…` (`picker.bundleId` in `router.yaml`), so a stray dev Electron registered for `turnout://` can't intercept the link.

**If you see Electron’s generic splash:** the wrong `Electron.app` ran without the Turnout app folder. After **`./scripts/local-dev.sh`**, **`~/.config/turnout/picker-dev-path`** exists and the Router opens the picker only via **`node …/run-electron.mjs turnout://…`** (not bare **`open turnout://`**), including when the picker daemon is already running (second instance forwards to the first). Quick test: **`./scripts/dev-smoke.sh`**. Avoid **`ELECTRON_OVERRIDE_DIST_PATH`** pointing at another repo.

## Config

Create `~/.config/turnout/router.yaml` (see [config/examples](../config/examples/)).

## Debug Router (links not firing)

By default the Router only logs **errors** to stderr (often invisible when launched as the default browser).

**Verbose logs (recommended):**

1. Create an empty flag file (works for GUI-launched Router; no shell env needed):

   ```bash
   mkdir -p ~/.config/turnout
   touch ~/.config/turnout/router.debug
   ```

2. Rebuild/restart the Router (quit **Turnout** in Activity Monitor if needed, then run `./scripts/local-dev.sh` or open the app again).

3. Set **Turnout** as the default browser, then:

   ```bash
   open 'https://example.com'
   ```

4. Tail the log file:

   ```bash
   tail -f ~/.config/turnout/router.log
   ```

   You should see `url event` (macOS delivered the URL to the app) and `route resolved` (policy ran). **If the file stays empty**, macOS is not routing `http`/`https` to this bundle—double-check **System Settings → Desktop & Dock → Default web browser** (must be **Turnout**, not another browser), and that you did not leave an old copy under `/Applications` while pointing Settings at `dist/local`.

**Alternative:** run the binary from a terminal (stderr visible) with debug on:

```bash
TURNOUT_DEBUG=1 ./dist/local/Turnout\ Router.app/Contents/MacOS/Turnout
```

Then run `open 'https://example.com'` in a second terminal.

**Console.app:** You can also filter by process **Turnout**; with debug off you will mostly only see `level=ERROR` lines.

## Verify

1. `open 'https://example.com'` — should hit Router, then default/handler/frecency/picker chain.
2. With no default and no matching handler, Router should run `open turnout://pick?u=…` and the Picker should appear.

## CLI smoke test (any OS)

Router logic only (will call `open` on macOS, may fail elsewhere):

```bash
cd router
go run ./cmd/turnout-router -url 'https://example.com'
```

On non-macOS builds, `turnout-router` is the CLI entry (no Cocoa event loop).