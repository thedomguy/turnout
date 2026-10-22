import { app, BrowserWindow, ipcMain, screen } from 'electron'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import fs from 'node:fs'
import os from 'node:os'
import { execFile } from 'node:child_process'
import yaml from 'js-yaml'
import { getDomain } from 'tldts'

import { APPS_CONFIG } from './config/browser-apps.js'
import { getInstalledBrowserNames } from './lib/installed-browsers.mjs'
import { getIconsForApps } from './lib/app-icons.mjs'
import {
  DEFAULT_PICKER_HEIGHT,
  loadBrowserosaurusPrefs,
} from './lib/browserosaurus-prefs.mjs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

/** @type {BrowserWindow | null} */
let win = null
let pendingTargetUrl = ''

function routerConfigPath() {
  return path.join(os.homedir(), '.config', 'turnout', 'router.yaml')
}

function frecencyPath() {
  return path.join(os.homedir(), '.config', 'turnout', 'frecency.json')
}

function loadDenylist() {
  try {
    const raw = fs.readFileSync(routerConfigPath(), 'utf8')
    const doc = yaml.load(raw)
    if (doc && Array.isArray(doc.denylist)) return doc.denylist.map(String)
  } catch {
    /* missing config */
  }
  return []
}

function denylisted(name, denylist) {
  const lower = name.toLowerCase()
  return denylist.some((d) => d && lower.includes(String(d).toLowerCase()))
}

function openBrowserApp(appName, url, isAlt, isShift) {
  const cfg = APPS_CONFIG[appName] || {}
  const convertedUrl = typeof cfg.convertUrl === 'function' ? cfg.convertUrl(url) : url
  const args = ['-a', appName]
  if (isAlt) args.push('--background')
  if (isShift && cfg.privateArg) {
    args.push('--new', '--args', cfg.privateArg)
  }
  args.push(convertedUrl)
  execFile('open', args, (err) => {
    if (err) console.error('open', err)
  })
}

function etldPlusOne(urlStr) {
  const d = getDomain(urlStr, { detectIp: false, mixedInputs: false })
  return d || ''
}

function recordFrecency(urlStr, browserName) {
  const domain = etldPlusOne(urlStr)
  if (!domain || !browserName) return

  const p = frecencyPath()
  let data = { version: 1, domains: {} }
  try {
    const raw = fs.readFileSync(p, 'utf8')
    data = JSON.parse(raw)
  } catch {
    /* new file */
  }
  if (!data.domains) data.domains = {}
  if (!data.domains[domain]) data.domains[domain] = {}
  const cur = data.domains[domain][browserName] || { hits: 0, score: 0 }
  cur.hits += 1
  cur.score += 1
  cur.last_used = new Date().toISOString()
  data.domains[domain][browserName] = cur
  data.version = 1

  const dir = path.dirname(p)
  fs.mkdirSync(dir, { recursive: true })
  const tmp = `${p}.tmp`
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2), 'utf8')
  fs.renameSync(tmp, p)
}

function windowTitleForUrl(urlStr) {
  try {
    const u = new URL(urlStr)
    const h = u.hostname.replace(/^www\./i, '')
    return h ? `Turnout — ${h}` : 'Turnout'
  } catch {
    return 'Turnout'
  }
}

function placeWindowNearCursor(w) {
  if (!w) return
  const displayBounds = screen.getDisplayNearestPoint(screen.getCursorScreenPoint()).bounds
  const displayEnd = {
    x: displayBounds.x + displayBounds.width,
    y: displayBounds.y + displayBounds.height,
  }
  const mousePoint = screen.getCursorScreenPoint()
  const b = w.getBounds()
  const nudge = { x: -125, y: -30 }
  let x = mousePoint.x + nudge.x
  let y = mousePoint.y + nudge.y
  if (x + b.width > displayEnd.x) x = displayEnd.x - b.width
  if (y + b.height > displayEnd.y) y = displayEnd.y - b.height
  w.setPosition(Math.round(x), Math.round(y), false)
}


/** @type {{ browsers: { name: string, hotCode: string | null }[], icons: Record<string, string> }} */
let browserCache = { browsers: [], icons: {} }
/** @type {Promise<void> | null} */
let refreshing = null
let pageLoaded = false
let quitting = false

/**
 * Rebuild the browser list (installed apps, denylist, Browserosaurus order/hotkeys) and fetch
 * icons only for browsers not cached yet. Runs at startup and in the background after each
 * show, so showing the picker never waits on `find` or file-icon.
 */
function refreshBrowsers() {
  if (refreshing) return refreshing
  refreshing = (async () => {
    try {
      const denylist = loadDenylist()
      const installed = (await getInstalledBrowserNames()).filter((n) => !denylisted(n, denylist))
      const { apps } = loadBrowserosaurusPrefs({ installedNames: installed })
      const missing = apps.map((a) => a.name).filter((n) => !browserCache.icons[n])
      const icons = { ...browserCache.icons, ...(await getIconsForApps(missing)) }
      const next = { browsers: apps, icons }
      if (JSON.stringify(next.browsers) !== JSON.stringify(browserCache.browsers) || missing.length > 0) {
        browserCache = next
        if (win?.isVisible()) sendPickerInit(pendingTargetUrl)
      }
    } catch (e) {
      console.error('refresh browsers', e)
    } finally {
      refreshing = null
    }
  })()
  return refreshing
}

function initialPickerHeight() {
  return loadBrowserosaurusPrefs({ installedNames: [] }).height || DEFAULT_PICKER_HEIGHT
}

function sendPickerInit(targetUrl) {
  win?.webContents.send('picker-init', { url: targetUrl, ...browserCache })
}

/** Created once at startup and kept hidden between links (like Browserosaurus). */
function createWindow() {
  /** @type {Electron.BrowserWindowConstructorOptions} */
  const opts = {
    width: 250,
    height: initialPickerHeight(),
    minWidth: 250,
    maxWidth: 250,
    minHeight: 112,
    show: false,
    title: 'Turnout',
    frame: true,
    fullscreenable: false,
    maximizable: false,
    minimizable: false,
    movable: false,
    resizable: true,
    alwaysOnTop: true,
    hasShadow: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      // Keep the hidden window's renderer responsive so it can render before being shown.
      backgroundThrottling: false,
    },
  }

  if (process.platform === 'darwin') {
    Object.assign(opts, {
      // A non-activating NSPanel (like Spotlight/Raycast): tiling window managers leave it alone
      // without any per-WM config, and the app you clicked from stays frontmost until the
      // chosen browser activates.
      type: 'panel',
      titleBarStyle: 'hidden',
      transparent: true,
      vibrancy: 'popover',
      visualEffectState: 'active',
    })
  }

  win = new BrowserWindow(opts)

  if (process.platform === 'darwin') {
    win.setWindowButtonVisibility(false)
    // The packaged app is already LSUIElement; without skipTransformProcessType Electron flips the
    // process to a foreground app and back, which flashes the Dock and can bounce focus.
    win.setVisibleOnAllWorkspaces(true, {
      visibleOnFullScreen: true,
      skipTransformProcessType: app.isPackaged,
    })
  }

  win.on('blur', () => {
    win?.hide()
  })

  win.on('close', (event) => {
    if (quitting) return
    event.preventDefault()
    win?.hide()
  })

  win.webContents.on('did-finish-load', () => {
    pageLoaded = true
    if (pendingTargetUrl) void showPicker(pendingTargetUrl)
  })

  win.loadFile(path.join(__dirname, 'index.html'))
}

let showWhenRendered = false
/** @type {NodeJS.Timeout | undefined} */
let showFallback

/** Push the URL + cached browsers; the window appears once the renderer has drawn the list. */
async function showPicker(targetUrl) {
  pendingTargetUrl = targetUrl
  if (!win || !pageLoaded) return
  // Only the very first link after launch can arrive before the initial refresh finishes.
  if (browserCache.browsers.length === 0 && refreshing) await refreshing
  win.setTitle(windowTitleForUrl(targetUrl))
  showWhenRendered = true
  sendPickerInit(targetUrl)
  showFallback = setTimeout(revealPicker, 150)
}

function revealPicker() {
  clearTimeout(showFallback)
  if (!win || !showWhenRendered) return
  showWhenRendered = false
  placeWindowNearCursor(win)
  win.show()
  win.focus()
  void refreshBrowsers()
}

ipcMain.on('picker-rendered', revealPicker)

ipcMain.on('pick-browser', (_e, { name, url, background, isAlt, isShift }) => {
  if (typeof url === 'string' && url.length > 0 && typeof name === 'string') {
    openBrowserApp(name, url, Boolean(isAlt) || Boolean(background), Boolean(isShift))
    recordFrecency(url, name)
  }
  win?.hide()
})

ipcMain.on('cancel-picker', () => {
  win?.hide()
})

function handleTurnoutUrl(raw) {
  try {
    const u = new URL(raw)
    if (u.protocol !== 'turnout:') return false
    if (u.hostname !== 'pick') return false
    const enc = u.searchParams.get('u')
    if (!enc) return false
    const decoded = Buffer.from(decodeURIComponent(enc), 'base64url').toString('utf8')
    if (!decoded.startsWith('http://') && !decoded.startsWith('https://')) return false
    void showPicker(decoded)
    return true
  } catch (e) {
    console.error('turnout url', e)
    return false
  }
}

const gotLock = app.requestSingleInstanceLock()
if (!gotLock) {
  app.quit()
} else {
  app.on('second-instance', (_ev, argv) => {
    const url = argv.find((a) => typeof a === 'string' && a.startsWith('turnout://'))
    if (url) handleTurnoutUrl(url)
  })

  // A cold launch via `open … turnout://…` delivers open-url before the app is ready;
  // showPicker just records the URL until the window has loaded.
  app.on('open-url', (event, url) => {
    event.preventDefault()
    handleTurnoutUrl(url)
  })

  app.on('before-quit', () => {
    quitting = true
  })

  app.whenReady().then(() => {
    // The picker ships inside Turnout.app; the router execs it with a turnout://pick URL in argv,
    // so it doesn't register the scheme. The router starts at login and pre-warms it (no argv).
    void refreshBrowsers()
    createWindow()

    const urlArg = process.argv.find((a) => typeof a === 'string' && a.startsWith('turnout://'))
    if (urlArg) {
      handleTurnoutUrl(urlArg)
      return
    }

    const devUrl = process.env.TURNOUT_DEV_URL
    if (devUrl) void showPicker(devUrl)
  })

  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit()
  })
}
