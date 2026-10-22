/**
 * macOS app icons via `file-icon` (same stack as Browserosaurus `get-app-icons.ts`).
 */
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const execFileP = promisify(execFile)

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const binary = path.join(__dirname, '..', 'node_modules', 'file-icon', 'file-icon')
const MAX_BUFFER = 1024 * 1024 * 100

/**
 * @param {string} appDisplayName e.g. "Safari" — passed to file-icon as appOrPID
 * @returns {Promise<string | null>} data URI or null on failure
 */
export async function getIconDataURI(appDisplayName) {
  try {
    const { stdout } = await execFileP(
      binary,
      [JSON.stringify([{ appOrPID: appDisplayName, size: 64 }])],
      { encoding: null, maxBuffer: MAX_BUFFER },
    )
    return `data:image/png;base64,${stdout.toString('base64')}`
  } catch {
    return null
  }
}

/**
 * @param {string[]} names
 * @returns {Promise<Record<string, string>>}
 */
export async function getIconsForApps(names) {
  /** @type {Record<string, string>} */
  const icons = {}
  const uris = await Promise.all(names.map((name) => getIconDataURI(name)))
  names.forEach((name, i) => {
    if (uris[i]) icons[name] = uris[i]
  })
  return icons
}
