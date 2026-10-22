#!/usr/bin/env node
/**
 * Spawn the Electron binary shipped inside this package's node_modules/electron (see path.txt).
 * Avoids PATH/global `electron` and ignores ELECTRON_OVERRIDE_DIST_PATH so another project
 * (e.g. echo-note-backup) cannot substitute its dist.
 */
import { spawn } from 'node:child_process'
import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const pickerRoot = fileURLToPath(new URL('.', import.meta.url))
const pathTxt = path.join(pickerRoot, 'node_modules/electron/path.txt')
if (!existsSync(pathTxt)) {
  console.error('Turnout Picker: Electron not installed. Run: npm install')
  process.exit(1)
}
const rel = readFileSync(pathTxt, 'utf8').trim().replace(/\r?\n/g, '')
const electronBin = path.join(pickerRoot, 'node_modules/electron/dist', rel)
if (!existsSync(electronBin)) {
  console.error('Turnout Picker: missing binary at', electronBin)
  process.exit(1)
}

const env = { ...process.env }
delete env.ELECTRON_OVERRIDE_DIST_PATH

const args = [pickerRoot, ...process.argv.slice(2)]
const child = spawn(electronBin, args, {
  stdio: 'inherit',
  env,
  cwd: pickerRoot,
})

child.on('exit', (code, signal) => {
  if (signal) {
    process.exit(1)
  }
  process.exit(code ?? 1)
})
