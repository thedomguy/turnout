#!/usr/bin/env bash
set -euo pipefail
# Build signed Turnout.app (router, with the picker embedded under Contents/Helpers), install it
# into /Applications and seed ~/.config/turnout/router.yaml if missing. Local daily-driver install;
# for a distributable beta use scripts/beta-release.sh.
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

echo "==> Turnout Picker.app (embedded)"
(cd "$TURNOUT_ROOT/picker" && npm run package)

echo "==> Turnout.app (router + picker)"
mkdir -p "$(dirname "$ROUTER_BUILD")"
PICKER_APP="$PICKER_BUILD" "$TURNOUT_ROOT/router/scripts/package-macos-app.sh" "$ROUTER_BUILD"

echo "==> Install into $DEST"
killall Turnout "Turnout Picker" 2>/dev/null || true
"$TURNOUT_ROOT/scripts/picker-daemon.sh" stop >/dev/null 2>&1 || true
# The picker used to be a separate app; remove a leftover standalone copy.
rm -rf "$DEST/Turnout Picker.app"
target="$DEST/Turnout.app"
rm -rf "$target"
ditto "$ROUTER_BUILD" "$target"
"$LSREGISTER" -f "$target"

echo "==> Config ($CONFIG_DIR)"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/router.yaml" ]]; then
  cp "$TURNOUT_ROOT/config/examples/router.yaml" "$CONFIG_DIR/router.yaml"
  echo "    Seeded router.yaml from config/examples (edit it to taste)."
fi
# picker-dev-path makes the router spawn the dev picker from this checkout; the installed app replaces it.
rm -f "$CONFIG_DIR/picker-dev-path"

open -g "$DEST/Turnout.app"

echo ""
echo "Installed: $DEST/Turnout.app (picker embedded)"
echo "Next: System Settings → Desktop & Dock → Default web browser → Turnout"
