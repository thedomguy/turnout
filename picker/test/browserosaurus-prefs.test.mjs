import assert from 'node:assert/strict'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'

import { loadBrowserosaurusPrefs } from '../lib/browserosaurus-prefs.mjs'

test('loads Browserosaurus picker order, hotkeys, and height for installed apps', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'turnout-picker-'))
  const storePath = path.join(dir, 'store.json')

  writeFileSync(
    storePath,
    JSON.stringify({
      apps: [
        { hotCode: 'KeyA', isInstalled: true, name: 'Arc' },
        { hotCode: 'KeyB', isInstalled: true, name: 'Brave Browser' },
        { hotCode: null, isInstalled: true, name: 'Slack' },
        { hotCode: 'KeyS', isInstalled: false, name: 'Safari' },
      ],
      height: 200,
    }),
  )

  try {
    assert.deepEqual(
      loadBrowserosaurusPrefs({
        installedNames: ['Arc', 'Brave Browser', 'Safari'],
        storePath,
      }),
      {
        apps: [
          { hotCode: 'KeyA', name: 'Arc' },
          { hotCode: 'KeyB', name: 'Brave Browser' },
          { hotCode: 'KeyS', name: 'Safari' },
        ],
        height: 200,
      },
    )
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
})

test('falls back to installed browser names when Browserosaurus storage is missing', () => {
  assert.deepEqual(
    loadBrowserosaurusPrefs({
      installedNames: ['Arc', 'Firefox'],
      storePath: '/missing/store.json',
    }),
    {
      apps: [
        { hotCode: null, name: 'Arc' },
        { hotCode: null, name: 'Firefox' },
      ],
      height: 200,
    },
  )
})
