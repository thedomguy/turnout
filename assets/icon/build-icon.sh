#!/usr/bin/env bash
set -euo pipefail
# Regenerate assets/icon/Turnout.icns (and icon-1024.png) from make-icon.swift.
cd "$(dirname "$0")"

swift make-icon.swift icon-1024.png
ICONSET="$(mktemp -d)/Turnout.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Turnout.icns
rm -rf "$(dirname "$ICONSET")"
echo "wrote $(pwd)/Turnout.icns"
