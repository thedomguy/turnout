#!/usr/bin/env bash
set -euo pipefail
# Start/stop Turnout Picker in the background. Uses picker/run-electron.mjs so the binary
# always comes from turnout/picker/node_modules/electron (not global electron / another repo).

TURNOUT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PICKER_DIR="${TURNOUT_ROOT}/picker"
LAUNCHER="${PICKER_DIR}/run-electron.mjs"
PIDFILE="${HOME}/.config/turnout/picker-daemon.pid"
LOGFILE="${TURNOUT_ROOT}/dist/local/picker-daemon.log"

pick_start() {
  mkdir -p "$(dirname "$PIDFILE")"
  if [[ -f "$PIDFILE" ]]; then
    old="$(cat "$PIDFILE" 2>/dev/null || true)"
    if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
      echo "picker-daemon: already running (pid $old)"
      return 0
    fi
    rm -f "$PIDFILE"
  fi
  if [[ ! -f "$LAUNCHER" ]]; then
    echo "picker-daemon: missing $LAUNCHER" >&2
    exit 1
  fi
  if [[ ! -f "${PICKER_DIR}/node_modules/electron/path.txt" ]]; then
    echo "picker-daemon: Electron not installed — run: (cd picker && npm install)" >&2
    exit 1
  fi
  # Unset override so a dev shell pointed at another project cannot load the wrong dist.
  nohup env -u ELECTRON_OVERRIDE_DIST_PATH bash -c "cd \"$PICKER_DIR\" && exec node run-electron.mjs" >>"$LOGFILE" 2>&1 &
  echo $! >"$PIDFILE"
  echo "picker-daemon: started pid $(cat "$PIDFILE") (log: $LOGFILE)"
}

pick_stop() {
  if [[ ! -f "$PIDFILE" ]]; then
    echo "picker-daemon: not running (no pidfile)"
    return 0
  fi
  pid="$(cat "$PIDFILE")"
  if kill -0 "$pid" 2>/dev/null; then
    pkill -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.2
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$PIDFILE"
  echo "picker-daemon: stopped"
}

pick_status() {
  if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "picker-daemon: running pid $(cat "$PIDFILE")"
  else
    echo "picker-daemon: not running"
  fi
}

case "${1:-}" in
  start) pick_start ;;
  stop) pick_stop ;;
  status) pick_status ;;
  restart) pick_stop; pick_start ;;
  *)
    echo "Usage: $(basename "$0") start|stop|status|restart" >&2
    exit 1
    ;;
esac
