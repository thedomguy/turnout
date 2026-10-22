import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

export const DEFAULT_PICKER_HEIGHT = 200

export function browserosaurusStorePath() {
  return path.join(os.homedir(), 'Library', 'Application Support', 'Browserosaurus', 'store.json')
}

function parseHeight(value) {
  return Number.isInteger(value) && value >= 112 ? value : DEFAULT_PICKER_HEIGHT
}

export function loadBrowserosaurusPrefs({
  installedNames,
  storePath = browserosaurusStorePath(),
}) {
  const installed = new Set(installedNames)
  try {
    const raw = fs.readFileSync(storePath, 'utf8')
    const store = JSON.parse(raw)
    const storedApps = Array.isArray(store.apps) ? store.apps : []
    const apps = []
    const seen = new Set()

    for (const storedApp of storedApps) {
      const name = typeof storedApp?.name === 'string' ? storedApp.name : ''
      if (!name || !installed.has(name) || seen.has(name)) continue
      const hotCode = typeof storedApp.hotCode === 'string' ? storedApp.hotCode : null
      apps.push({ name, hotCode })
      seen.add(name)
    }

    for (const name of installedNames) {
      if (!seen.has(name)) apps.push({ name, hotCode: null })
    }

    return {
      apps,
      height: parseHeight(store.height),
    }
  } catch {
    return {
      apps: installedNames.map((name) => ({ name, hotCode: null })),
      height: DEFAULT_PICKER_HEIGHT,
    }
  }
}
