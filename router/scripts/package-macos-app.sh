#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-Turnout.app}"
# PICKER_APP: built Turnout Picker.app to embed under Contents/Helpers (signed before the outer app).
PICKER_APP="${PICKER_APP:-}"

CGO_ENABLED=1 go build -o Turnout ./cmd/turnout-router
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Turnout "$APP/Contents/MacOS/"
cp macos/Info.plist.router.xml "$APP/Contents/Info.plist"
if [[ -n "${TURNOUT_SHORT_VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $TURNOUT_SHORT_VERSION" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${TURNOUT_BUILD:-$TURNOUT_SHORT_VERSION}" "$APP/Contents/Info.plist"
fi
mkdir -p "$APP/Contents/Resources"
cp ../assets/icon/Turnout.icns "$APP/Contents/Resources/"

if [[ -n "$PICKER_APP" ]]; then
  mkdir -p "$APP/Contents/Helpers"
  ditto "$PICKER_APP" "$APP/Contents/Helpers/Turnout Picker.app"
fi

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
# TURNOUT_DIST=1: hardened runtime + secure timestamp for notarization (the picker is already signed).
SIGN_FLAGS=()
if [[ "${TURNOUT_DIST:-}" == "1" ]]; then SIGN_FLAGS=(--options runtime --timestamp); fi
codesign --force "${SIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" "$APP"

DEST="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
echo "Packaged: $DEST"
