#!/usr/bin/env bash
set -euo pipefail
# Manually triggered beta release: build one Turnout.app (picker embedded), sign it, notarize it
# when a Developer ID is available, package a DMG + zip + checksums under dist/beta/<version>/.
#
#   ./scripts/beta-release.sh              build + package only (nothing leaves this Mac)
#   ./scripts/beta-release.sh --publish    also tag v<VERSION> and create a GitHub pre-release
#
# Version comes from the VERSION file (e.g. 0.1.0-beta.1); bump it and commit before releasing.
#
# Signing / notarization (see docs/release.md):
#   DEVELOPER_ID   "Developer ID Application: Name (TEAMID)"; default: .release-identity (git-ignored)
#   NOTARY_PROFILE notarytool keychain profile (xcrun notarytool store-credentials); default: turnout-notary
# Without a Developer ID the build is signed with the personal Apple Development identity and is NOT
# notarized: it runs on this Mac only, other Macs need the quarantine flag cleared (docs/release.md).

TURNOUT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TURNOUT_ROOT"

PUBLISH=0
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    -h|--help) sed -n 2,16p "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }
[[ "$(uname -s)" == "Darwin" ]] || die "macOS only."

VERSION="$(tr -d '[:space:]' < VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]] || die "VERSION '$VERSION' must look like 0.1.0 or 0.1.0-beta.1"
TAG="v$VERSION"
export TURNOUT_SHORT_VERSION="${VERSION%%-*}"
export TURNOUT_BUILD="$(git rev-list --count HEAD)"   # monotonic CFBundleVersion
export TURNOUT_DIST=1                                  # hardened runtime + secure timestamp

echo "==> Preflight ($TAG, build $TURNOUT_BUILD)"
[[ -z "$(git status --porcelain)" ]] || die "working tree not clean; commit or stash first."
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists; bump VERSION."
[[ "$PUBLISH" -eq 0 ]] || { command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || die "--publish needs a logged-in gh."; }

# Signing identity: Developer ID (distributable) else personal Apple Development (local only).
DEVELOPER_ID="${DEVELOPER_ID:-}"
if [[ -z "$DEVELOPER_ID" && -f .release-identity ]]; then DEVELOPER_ID="$(head -n 1 .release-identity)"; fi
NOTARIZE=0
if [[ -n "$DEVELOPER_ID" ]]; then
  security find-identity -v -p codesigning | grep -qF "$DEVELOPER_ID" || die "identity not in Keychain: $DEVELOPER_ID"
  export SIGN_IDENTITY="$DEVELOPER_ID"
  NOTARIZE=1
else
  echo "warning: no Developer ID (DEVELOPER_ID / .release-identity): signing with the Apple Development identity, NOT notarized." >&2
fi
NOTARY_PROFILE="${NOTARY_PROFILE:-turnout-notary}"
if [[ "$NOTARIZE" -eq 1 ]]; then
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || die "notary profile '$NOTARY_PROFILE' missing. Run: xcrun notarytool store-credentials $NOTARY_PROFILE"
fi

echo "==> Tests"
(cd router && go test ./...)
(cd picker && npm install --no-audit --no-fund && npm test)

OUT="$TURNOUT_ROOT/dist/beta/$VERSION"
APP="$OUT/Turnout.app"
rm -rf "$OUT"; mkdir -p "$OUT"
PICKER_APP="$TURNOUT_ROOT/picker/release/Turnout Picker-darwin-$(uname -m)/Turnout Picker.app"

echo "==> Picker (embedded helper)"
(cd picker && npm run package)

echo "==> Turnout.app"
PICKER_APP="$PICKER_APP" router/scripts/package-macos-app.sh "$APP"
codesign --verify --deep --strict "$APP"

ZIP="$OUT/Turnout-$VERSION.zip"
DMG="$OUT/Turnout-$VERSION.dmg"

if [[ "$NOTARIZE" -eq 1 ]]; then
  echo "==> Notarize app"
  ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
  xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$OUT/notarize.zip"
fi

echo "==> Package"
ditto -c -k --keepParent "$APP" "$ZIP"
STAGE="$(mktemp -d)"
ditto "$APP" "$STAGE/Turnout.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Turnout $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
if [[ "$NOTARIZE" -eq 1 ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type execute --verbose "$APP"
fi
(cd "$OUT" && shasum -a 256 "$(basename "$DMG")" "$(basename "$ZIP")" > SHA256SUMS)

echo ""
echo "Built $TAG → $OUT"
cat "$OUT/SHA256SUMS"
[[ "$NOTARIZE" -eq 1 ]] || echo "NOT notarized: only this Mac will open it without clearing quarantine."

if [[ "$PUBLISH" -eq 1 ]]; then
  echo "==> Publish $TAG"
  git tag -a "$TAG" -m "Turnout $VERSION"
  git push origin "$TAG"
  NOTES="Turnout $VERSION (beta)."
  [[ "$NOTARIZE" -eq 1 ]] || NOTES="$NOTES Not notarized: run xattr -dr com.apple.quarantine /Applications/Turnout.app after install."
  gh release create "$TAG" "$DMG" "$ZIP" "$OUT/SHA256SUMS" --prerelease --title "Turnout $VERSION" --notes "$NOTES" --verify-tag
else
  echo ""
  echo "Not published. To release: ./scripts/beta-release.sh --publish"
fi
