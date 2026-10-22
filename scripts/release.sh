#!/usr/bin/env bash
set -euo pipefail
# Build signed Turnout.app (router) + Turnout Picker.app, install both into /Applications,
# seed ~/.config/turnout/router.yaml if missing, and start the picker in the background.
# Setting the default browser stays manual: System Settings → Desktop & Dock → Default web browser.

TURNOUT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${TURNOUT_INSTALL_DIR:-/Applications}"
CONFIG_DIR="${HOME}/.config/turnout"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
ROUTER_BUILD="${TURNOUT_ROOT}/dist/release/Turnout.app"
PICKER_BUILD="${TURNOUT_ROOT}/picker/release/Turnout Picker-darwin-$(uname -m)/Turnout Picker.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Turnout release builds only on macOS." >&2
  exit 1
fi

echo "==> Tests"
(cd "$TURNOUT_ROOT/router" && go test ./...)
(cd "$TURNOUT_ROOT/picker" && npm install --no-audit --no-fund && npm test)

echo "==> Turnout.app (router)"
mkdir -p "$(dirname "$ROUTER_BUILD")"
"$TURNOUT_ROOT/router/scripts/package-macos-app.sh" "$ROUTER_BUILD"

echo "==> Turnout Picker.app"
(cd "$TURNOUT_ROOT/picker" && npm run package)

echo "==> Install into $DEST"
killall Turnout "Turnout Picker" 2>/dev/null || true
"$TURNOUT_ROOT/scripts/picker-daemon.sh" stop >/dev/null 2>&1 || true
for app in "$ROUTER_BUILD" "$PICKER_BUILD"; do
  target="$DEST/$(basename "$app")"
  rm -rf "$target"
  ditto "$app" "$target"
  "$LSREGISTER" -f "$target"
done

echo "==> Config ($CONFIG_DIR)"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/router.yaml" ]]; then
  cp "$TURNOUT_ROOT/config/examples/router.yaml" "$CONFIG_DIR/router.yaml"
  echo "    Seeded router.yaml from config/examples (edit it to taste)."
fi
# picker-dev-path makes the router spawn the dev picker from this checkout; the installed app replaces it.
rm -f "$CONFIG_DIR/picker-dev-path"

open -g "$DEST/Turnout Picker.app"

echo ""
echo "Installed: $DEST/Turnout.app and $DEST/Turnout Picker.app"
echo "Next: System Settings → Desktop & Dock → Default web browser → Turnout"
