## Learned User Preferences

- Before locking a plan, surface remaining forks as explicit questions; the final plan should state decisions only (no lingering “A or B” tables).
- When executing an attached plan, treat it as read-only reference: do not edit that plan file.
- For Turnout, prioritize a fast default-browser hot path and keep a Browserosaurus-caliber picker; Electron is acceptable for the chooser if another stack matches the UI bar.
- Prefer architecture “A”: a lean default-handler (Go/native) for most links, with an Electron picker invoked only when the router delegates (not Electron on every URL by default).
- Routing should combine ordered regex handlers (Finicky-style, first match wins) with eTLD+1 frecency for the long tail; explicit handlers must override learned frecency so org/repo rules stay deterministic.
- Finicky-style policy is often maintained in a user-level JS config (e.g. under `~/.config/`); v1 Turnout maps that mental model to YAML without executing JS in the router.

## Learned Workspace Facts

- The product is **Turnout**, living at `~/personal/mac-utils/turnout`. This repo is the product (router, picker, config, docs); `references/browserosaurus` and `references/finicky` are untouched upstream clones tracked as git submodules, for reference only — never ship code from them.
- One app: `/Applications/Turnout.app` (router, the default browser) with the Electron picker embedded at `Contents/Helpers/Turnout Picker.app`; the router execs it with a `turnout://pick` URL in argv. Built, signed and installed by `turnout/scripts/release.sh`. Option-click a link forces the picker.
- Beta releases: `VERSION` file + `./scripts/beta-release.sh` (manual, no CI; `--publish` tags and creates a GitHub pre-release). See `docs/release.md`.
- macOS identifiers: router `io.turnout.router`, embedded picker `io.turnout.picker` (not registered for the scheme), delegate scheme `turnout://` (argv only); user state under `~/.config/turnout/` (`router.yaml`, `frecency.json`).
- The picker is a non-activating `NSPanel` (`type: 'panel'`) so tiling window managers (AeroSpace, Rectangle) leave it alone. Turnout must work without per-WM config — don't add rules to the user's AeroSpace/Rectangle setup.
- Picker code is GPL-3.0 (Browserosaurus-derived patterns); the Go router is MIT in-repo; combined distribution has GPL obligations for the picker component.

## Agent workflow (Turnout local macOS)

- **Do not ask the user to run `npm start` manually** for routine dev. From `turnout/` run **`./scripts/local-dev.sh`** — it builds the Router, installs picker deps, writes **`~/.config/turnout/picker-dev-path`**, and starts the **Picker in the background** (`picker-daemon`). When **`picker-dev-path` exists**, the Router **always** delegates to the picker via **`node …/run-electron.mjs turnout://…`** (never bare `open turnout://`), so macOS cannot launch the wrong Electron; a second instance forwards to the first. Tear down with **`./scripts/stop-local-dev.sh`**. End-to-end check: **`./scripts/dev-smoke.sh`**.
- **Confirmation / AskQuestion** only when something needs human eyes or UI action: e.g. “did the default browser open the right app?”, “did the picker appear and did choosing a browser open the link?”, Gatekeeper/notarization, or changing **System Settings → Default web browser**.
- Full automated smoke (Router + picker + log assertions): **`./scripts/e2e-local.sh`**.
- **Release / daily driver:** `./scripts/release.sh` from the repo root rebuilds and reinstalls the app in `/Applications` and deletes `picker-dev-path`. Running `local-dev.sh` writes it back, so the installed Router then uses the dev picker until the next `release.sh`.
