# Migrating from `~/.config/finicky.js` to Turnout

Turnout v1 does **not** execute JavaScript. Translate your Finicky config to YAML.

## Mapping

| finicky.js | router.yaml |
|------------|---------------|
| `defaultBrowser` | `defaultBrowser` (same string, macOS app name) |
| `handlers[].match` (string or array of regex) | `handlers[].match` (string or YAML array of regex strings) |
| `handlers[].browser` | `handlers[].browser` |

Regex patterns apply to the **full URL string** (e.g. `https://github.com/acme-corp/repo`), same as Finicky.

## Example

**finicky.js**

```js
module.exports = {
  defaultBrowser: "Brave Browser",
  handlers: [
    { match: /localhost/, browser: "Arc" },
    { match: [/github\.com\/acme-corp/, /cursor\.com/], browser: "Zen" },
  ],
};
```

**router.yaml**

```yaml
defaultBrowser: Brave Browser
handlers:
  - match: localhost
    browser: Arc
  - match:
      - github\.com/acme-corp
      - cursor\.com
    browser: Zen
```

Note: In JS you often write `/pattern/`; in YAML use the pattern **without** slashes as a plain string (Go `regexp` uses the same syntax as the inner part of JS literals).

## Features Finicky has that Turnout v1 omits

- JavaScript `rewriteUrl` and full `finicky.setPreference` API  
- JSON rules file merge  
- Short-URL expansion (can be added to the router later)

Use explicit `handlers` for anything you relied on JS logic for.
