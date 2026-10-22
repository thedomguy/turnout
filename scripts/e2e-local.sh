#!/usr/bin/env bash
set -euo pipefail
# E2E (macOS): Router + Picker. Unmatched URLs should hit the picker (no defaultBrowser in config).

TURNOUT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${TURNOUT_ROOT}/dist/local/Turnout.app"
LOG="${HOME}/.config/turnout/router.log"
ROUTER_CFG="${HOME}/.config/turnout/router.yaml"
ROUTER_CFG_BAK="${ROUTER_CFG}.e2e.bak"
RESTORE_CFG=0

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "e2e-local.sh requires macOS." >&2
  exit 1
fi

cleanup() {
  "$TURNOUT_ROOT/scripts/picker-daemon.sh" stop 2>/dev/null || true
  if [[ "$RESTORE_CFG" -eq 1 ]] && [[ -f "$ROUTER_CFG_BAK" ]]; then
    mv -f "$ROUTER_CFG_BAK" "$ROUTER_CFG"
  fi
}
trap cleanup EXIT

# Picker only runs for the long tail when defaultBrowser is unset — isolate from your real router.yaml.
if [[ -f "$ROUTER_CFG" ]]; then
  mv -f "$ROUTER_CFG" "$ROUTER_CFG_BAK"
  RESTORE_CFG=1
fi

echo "==> Build + picker deps"
"$TURNOUT_ROOT/scripts/local-dev.sh" --no-open --no-picker

mkdir -p "${HOME}/.config/turnout"
touch "${HOME}/.config/turnout/router.debug"
rm -f "$LOG"

echo "==> Turnout Picker (daemon) for turnout://"
"$TURNOUT_ROOT/scripts/picker-daemon.sh" restart
sleep 4

killall Turnout 2>/dev/null || true
sleep 0.4

echo "==> Launch Router + open https://example.com (expect picker; no handler configured)"
open "$APP"
sleep 1
open -a "$APP" "https://example.com"
sleep 2

if [[ ! -f "$LOG" ]]; then
  echo "FAIL: $LOG missing (debug logging not working?)" >&2
  exit 1
fi

LAST="$(tail -16 "$LOG")"
echo "--- last log lines ---"
echo "$LAST"
echo "---"

if ! echo "$LAST" | grep -q 'msg="url event"'; then
  echo "FAIL: no url event in log." >&2
  exit 1
fi

if ! echo "$LAST" | grep -q 'decision=delegate_picker'; then
  echo "FAIL: expected decision=delegate_picker for an unmatched URL (check router.yaml defaultBrowser)." >&2
  exit 1
fi

if echo "$LAST" | grep -q 'level=ERROR'; then
  echo "FAIL: error in log (turnout:// not handled — is the Picker running?)." >&2
  exit 1
fi

echo "==> Automated checks passed."
echo "    Manual: Did the Turnout Picker window open for https://example.com ?"
