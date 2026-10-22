#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-Turnout.app}"

CGO_ENABLED=1 go build -o Turnout ./cmd/turnout-router
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Turnout "$APP/Contents/MacOS/"
cp macos/Info.plist.router.xml "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp ../assets/icon/Turnout.icns "$APP/Contents/Resources/"

# Sign with a stable identity so the default-browser choice and any grants survive rebuilds.
# Identity: $SIGN_IDENTITY, else the first line of ../.signing-identity (git-ignored), else ad-hoc.
if [[ -z "${SIGN_IDENTITY:-}" && -f ../.signing-identity ]]; then
  SIGN_IDENTITY="$(head -n 1 ../.signing-identity)"
fi
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  echo "No signing identity (set SIGN_IDENTITY or .signing-identity); signing ad-hoc." >&2
  SIGN_IDENTITY="-"
elif [[ "$SIGN_IDENTITY" != "-" ]] && ! security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY"; then
  echo "Signing identity not found ($SIGN_IDENTITY); falling back to ad-hoc." >&2
  SIGN_IDENTITY="-"
fi
codesign --force --sign "$SIGN_IDENTITY" "$APP"

DEST="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
echo "Packaged: $DEST"
