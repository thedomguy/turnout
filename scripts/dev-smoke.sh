#!/usr/bin/env bash
set -euo pipefail
# One-shot dev workflow: build Router + picker deps, restart picker daemon, deliver a test URL.

TURNOUT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${TURNOUT_ROOT}/dist/local/Turnout.app"
LOG="${HOME}/.config/turnout/router.log"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "dev-smoke.sh requires macOS." >&2
  exit 1
fi

echo "==> 1/4 Build (Router + npm install, write picker-dev-path)"
"$TURNOUT_ROOT/scripts/local-dev.sh" --no-open --no-picker

echo "==> 2/4 Picker daemon"
"$TURNOUT_ROOT/scripts/picker-daemon.sh" restart
sleep 2

mkdir -p "${HOME}/.config/turnout"
touch "${HOME}/.config/turnout/router.debug"
rm -f "$LOG"

echo "==> 3/4 Launch Router + open https://example.com (via this .app)"
killall Turnout 2>/dev/null || true
sleep 0.3
open "$APP"
sleep 1
open -a "$APP" "https://example.com"
sleep 2

echo "==> 4/4 Router log (url event + route; no ERROR)"
if [[ -f "$LOG" ]]; then
  tail -25 "$LOG"
else
  echo "(no $LOG — set router.debug?)"
fi

echo ""
echo "Done. Expect Turnout Picker UI near the cursor (not the generic Electron splash)."
