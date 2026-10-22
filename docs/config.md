# Turnout configuration

## Paths

| File | Purpose |
|------|---------|
| `~/.config/turnout/router.yaml` | Policy: handlers, default browser, denylist, frecency thresholds, picker bundle id |
| `~/.config/turnout/frecency.json` | Learned browser preferences per **eTLD+1** (written by router and picker) |

Copy [config/examples/router.yaml](../config/examples/router.yaml) as a starting point.

## `router.yaml` fields

### `defaultBrowser`

macOS application name passed to `open -a` (e.g. `Brave Browser`, `Arc`).

### `handlers`

Ordered list. Each item:

- **`match`**: Either a single regex string or a YAML list of regex strings. If **any** pattern matches the full URL, the handler applies.
- **`browser`**: Target app name for `open -a`.
- **`profile`** (optional): Browser profile name as shown in the browser. Supported for Firefox-family browsers (Firefox, Firefox Developer Edition/Nightly, Zen, LibreWolf, Floorp — both the Firefox 138+ profile manager and classic `profiles.ini`) and Chromium-family browsers (Chrome, Brave, Edge, Chromium, Vivaldi — names from `Local State`). Exact case-insensitive match first, then a unique substring (`work` finds `Work - Acme`). Opens with `open -n -a <browser> --args --profile <dir>` (Firefox) or `--profile-directory=<dir>` (Chromium); the browser forwards the URL to that profile's running window. If the profile can't be found, the link opens in the browser without it and the error goes to `router.log`.

```yaml
handlers:
  - match: dev\.azure\.com/acme-corp
    browser: Firefox
    profile: Work
```

**Check a rule without opening anything:** from `router/`, `CGO_ENABLED=0 go run ./cmd/turnout-router -url '<url>' -explain` prints the decision and the exact `open` command.

First matching handler wins (Finicky-compatible semantics).

### `denylist`

List of substrings matched case-insensitively against browser display names and bundle-like tokens. Used to:

- Remove entries from the picker grid
- Prevent a browser from being chosen by **frecency** auto-open

Explicit `handlers` still win even if the browser appears on the denylist (you configured it on purpose).

### `frecency`

- **`minHits`**: Minimum number of recorded picks/opens for the winning browser on this eTLD+1 before auto-open.
- **`minScore`**: Minimum cumulative score (each picker/auto-frecency bump adds `1` by default).

Defaults if omitted: `minHits: 2`, `minScore: 1` (router applies these when both are zero).

### `picker`

- **`bundleId`**: Bundle id of the installed picker (default `io.turnout.picker`). The router opens it with `open -b <bundleId> turnout://…`.

## `frecency.json` schema

```json
{
  "version": 1,
  "domains": {
    "example.com": {
      "Firefox": { "hits": 3, "score": 3, "last_used": "2026-05-01T12:00:00Z" }
    }
  }
}
```

- **Keys** under `domains` are **eTLD+1** strings from the public suffix list.
- **Inner keys** are browser names (same strings as `open -a`).

Writes should be atomic (temp file + rename). The Go router and Electron picker both update this file.

## Custom URL scheme (picker)

The router delegates with:

`turnout://pick?u=<url-encoded-base64url(https-url)>`

The picker decodes `u`, shows the UI, then opens the chosen browser and updates `frecency.json`.
