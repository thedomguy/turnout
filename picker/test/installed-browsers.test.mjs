import assert from 'node:assert/strict'
import test from 'node:test'

import { filterKnownBrowserNames } from '../lib/installed-browsers.mjs'

test('keeps only browser apps in Browserosaurus order', () => {
  assert.deepEqual(
    filterKnownBrowserNames([
      'Slack',
      'Firefox',
      'Arc',
      'Finicky',
      'Google Chrome',
      'Microsoft Teams',
      'Safari',
      'zoom.us',
      'Zen',
    ]),
    ['Arc', 'Firefox', 'Google Chrome', 'Safari', 'Zen'],
  )
})
