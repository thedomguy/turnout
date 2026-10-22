# Releasing Turnout (beta, manual)

Turnout ships as **one app**: `Turnout.app` is the Go router (the default browser); the Electron
picker is embedded at `Contents/Helpers/Turnout Picker.app` and exec'd by the router only when a
chooser is needed. One bundle means one signature, one notarization, one DMG.

## Versioning
`VERSION` (repo root) is the single source: `0.1.0-beta.1`. The numeric part becomes
`CFBundleShortVersionString`; `CFBundleVersion` is the commit count. Tags are `v<VERSION>`.
The first beta, `v0.1.0-beta.1`, is the base for the beta line; bump `beta.N` per release.

## Cutting a beta
1. Merge to `develop`, bump `VERSION`, commit (tree must be clean).
2. `./scripts/beta-release.sh` builds, signs, packages to `dist/beta/<version>/` (DMG, zip, `SHA256SUMS`). Nothing leaves the machine.
3. Try the DMG, then `./scripts/beta-release.sh --publish` tags `v<VERSION>`, pushes the tag and creates a GitHub **pre-release** with the artifacts.

`./scripts/release.sh` stays the local daily-driver install into `/Applications`.

## Signing and notarization
Public distribution on macOS needs a **Developer ID Application** certificate (paid Apple Developer
Program) plus notarization; the script does both when configured:

- `DEVELOPER_ID="Developer ID Application: … (TEAMID)"` or put it in git-ignored `.release-identity`.
- One-time: `xcrun notarytool store-credentials turnout-notary --apple-id … --team-id … --password <app-specific>`.
- The picker is signed first with hardened runtime and `picker/macos/entitlements.plist`, then the outer app; the app is notarized and stapled, then the DMG.

This Mac currently has only Apple Development identities, so the script falls back to a
**non-notarized** build for this Mac only. Testers on other Macs must run
`xattr -dr com.apple.quarantine /Applications/Turnout.app` after install.
Do not use the Friedman & Huey identities for Turnout.

## Later
Homebrew cask pointing at the GitHub release, Sparkle appcast for auto-update, CI. Not needed yet.
