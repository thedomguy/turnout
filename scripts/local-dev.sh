#!/usr/bin/env bash
set -euo pipefail

TURNOUT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROUTER_APP="${TURNOUT_ROOT}/dist/local/Turnout.app"

OPEN_ROUTER=1
# Default: start Picker in background so turnout:// works without a second terminal.
RUN_PICKER_BG=1
RUN_PICKER_FG=0

for arg in "$@"; do
  case "$arg" in
    --picker)
      RUN_PICKER_FG=1
      RUN_PICKER_BG=0
      ;;
    --no-picker)
      RUN_PICKER_BG=0
      ;;
    --no-open) OPEN_ROUTER=0 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--no-picker] [--picker] [--no-open]"
      echo "  Builds dist/local/Turnout.app, npm install in picker, clears quarantine."
      echo "  Default: starts Turnout Picker in the background (picker-daemon) so Router can open turnout://."
      echo "  --no-picker   Do not start the Picker."
      echo "  --picker      Run npm start in the foreground (blocks; dev REPL style)."
      echo "  --no-open     Do not reveal or launch the Router after build."
      echo "  Stop daemons: ./scripts/stop-local-dev.sh"
      exit 0
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Turnout local dev only supports macOS (Router needs CGO + Cocoa)." >&2
  exit 1
fi

mkdir -p "$(dirname "$ROUTER_APP")"

echo "==> Turnout (dist/local)"
"$TURNOUT_ROOT/router/scripts/package-macos-app.sh" "$ROUTER_APP"

echo "==> Picker (npm install + Tailwind CSS)"
(cd "$TURNOUT_ROOT/picker" && npm install && npm run build:css)

xattr -cr "$ROUTER_APP" 2>/dev/null || true

mkdir -p "${HOME}/.config/turnout"
printf '%s\n' "$TURNOUT_ROOT/picker" > "${HOME}/.config/turnout/picker-dev-path"

echo ""
echo "Built: $ROUTER_APP"
echo "Router is a background agent (no Dock icon, no window). It runs when handling links."
echo "Set default browser: System Settings → Desktop & Dock → Default web browser → Turnout"
echo ""

if [[ "$OPEN_ROUTER" -eq 1 ]]; then
  open -R "$ROUTER_APP"
  open "$ROUTER_APP"
fi

if [[ "$RUN_PICKER_FG" -eq 1 ]]; then
  echo "==> Turnout Picker (foreground: npm start)"
  (cd "$TURNOUT_ROOT/picker" && exec npm start)
elif [[ "$RUN_PICKER_BG" -eq 1 ]]; then
  echo "==> Turnout Picker (background)"
  "$TURNOUT_ROOT/scripts/picker-daemon.sh" start
  echo "    Stop later: ./scripts/stop-local-dev.sh"
else
  echo "Picker not started (--no-picker). Use ./scripts/picker-daemon.sh start when needed."
fi
