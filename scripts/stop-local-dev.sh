#!/usr/bin/env bash
set -euo pipefail
# Tear down Turnout local dev: background picker + Router process.

TURNOUT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(uname -s)" == "Darwin" ]]; then
  killall Turnout 2>/dev/null || true
fi

if [[ -x "$TURNOUT_ROOT/scripts/picker-daemon.sh" ]]; then
  "$TURNOUT_ROOT/scripts/picker-daemon.sh" stop
else
  echo "warn: picker-daemon.sh not found" >&2
fi

echo "stop-local-dev: Turnout and picker-daemon stopped (if they were running)."
