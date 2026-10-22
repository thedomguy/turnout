#!/usr/bin/env node
/**
 * Build release/Turnout Picker-darwin-<arch>/Turnout Picker.app: a background (LSUIElement) app
 * embedded in Turnout.app (the router execs it), signed with a stable identity so macOS grants survive rebuilds.
 * Identity: $SIGN_IDENTITY, else the first line of ../.signing-identity (git-ignored), else ad-hoc.
 */
import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { packager } from '@electron/packager'

const pickerRoot = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')

function configuredIdentity() {
  if (process.env.SIGN_IDENTITY) return process.env.SIGN_IDENTITY
  try {
    const line = fs.readFileSync(path.join(pickerRoot, '..', '.signing-identity'), 'utf8').split('\n')[0].trim()
    if (line) return line
  } catch {
    /* no local identity file */
  }
  console.warn('No signing identity (set SIGN_IDENTITY or .signing-identity); signing ad-hoc.')
  return '-'
}

// TURNOUT_DIST=1 (beta-release.sh): hardened runtime + secure timestamp, required for notarization.
const dist = process.env.TURNOUT_DIST === '1'
let identity = configuredIdentity()
if (identity !== '-') {
  const identities = execFileSync('security', ['find-identity', '-v', '-p', 'codesigning'], {
    encoding: 'utf8',
  })
  if (!identities.includes(identity)) {
    console.warn(`Signing identity not found (${identity}); falling back to ad-hoc.`)
    identity = '-'
  }
}

const [appDir] = await packager({
  dir: pickerRoot,
  name: 'Turnout Picker',
  platform: 'darwin',
  arch: process.arch,
  appBundleId: 'io.turnout.picker',
  appVersion: process.env.TURNOUT_SHORT_VERSION || undefined,
  buildVersion: process.env.TURNOUT_BUILD || undefined,
  appCategoryType: 'public.app-category.utilities',
  icon: path.join(pickerRoot, '..', 'assets', 'icon', 'Turnout.icns'),
  extendInfo: { LSUIElement: true },
  // file-icon ships a native binary that must stay a plain file on disk.
  asar: false,
  prune: true,
  overwrite: true,
  out: path.join(pickerRoot, 'release'),
  ignore: [/^\/release($|\/)/, /^\/test($|\/)/, /^\/scripts($|\/)/, /^\/picker\.css$/, /^\/tailwind\.config\.cjs$/],
  // No secure timestamp: it's only needed for distribution, and Apple's timestamp server makes
  // local signing flaky ("internal error in Code Signing subsystem").
  osxSign:
    identity === '-'
      ? false
      : {
          identity,
          optionsForFile: () =>
            dist
              ? { hardenedRuntime: true, entitlements: path.join(pickerRoot, 'macos', 'entitlements.plist') }
              : { timestamp: 'none' },
        },
})

const app = path.join(appDir, 'Turnout Picker.app')
if (identity === '-') {
  execFileSync('codesign', ['--force', '--deep', '--sign', '-', app], { stdio: 'inherit' })
}
// @electron/packager only warns when signing fails; refuse to hand on a broken bundle.
try {
  execFileSync('codesign', ['--verify', '--deep', '--strict', app], { stdio: 'pipe' })
} catch (e) {
  console.error(`Signature check failed for ${app}:\n${e.stderr}`)
  process.exit(1)
}
console.log(`Packaged: ${app}`)
