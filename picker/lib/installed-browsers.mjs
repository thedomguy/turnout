/**
 * Installed .app names under ~/Applications and /Applications, filtered to known browsers.
 * Same approach as Browserosaurus `src/main/utils/get-installed-app-names.ts`.
 */
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import path from 'node:path'
import os from 'node:os'

import { BROWSER_APP_ORDER } from '../config/browser-apps.js'

const FIND_CMD = `find "${path.join(os.homedir(), 'Applications')}" /Applications -iname "*.app" -prune -not -path "*/.*" 2>/dev/null || true`
const NON_BROWSER_APP_NAMES = new Set([
  'Discord',
  'Discord Canary',
  'Discord PTB',
  'Figma',
  'Figma Beta',
  'Finicky',
  'Framer',
  'FreeTube',
  'Linear',
  'Microsoft Teams',
  'Microsoft Teams (work or school)',
  'Microsoft Teams classic',
  'Miro',
  'Notion',
  'Pocket',
  'Slack',
  'Spotify',
  'Twitter',
  'Yattee',
  'zoom.us',
])

export function filterKnownBrowserNames(appNames) {
  const onDisk = new Set(appNames)
  return BROWSER_APP_ORDER.filter((name) => onDisk.has(name) && !NON_BROWSER_APP_NAMES.has(name))
}

const execFileP = promisify(execFile)

export async function getInstalledBrowserNames() {
  const { stdout: raw } = await execFileP('/bin/bash', ['-c', FIND_CMD], { encoding: 'utf8' })
  const appNames = raw
    .trim()
    .split('\n')
    .filter(Boolean)
    .map((p) => path.parse(p).name)
  return filterKnownBrowserNames(appNames)
}
