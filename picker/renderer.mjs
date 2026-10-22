/** Picker renderer — layout/behavior aligned with Browserosaurus picker `layout.tsx` + `url-bar` + keyboard hooks. */
const api = window.turnout

let currentUrl = ''
/** @type {{ name: string, hotCode: string | null }[]} */
let browsers = []
/** @type {Record<string, string>} */
let icons = {}
/** @type {Record<string, string>} */
let keyCodeMap = {}
/** @type {HTMLButtonElement[]} */
let rowEls = []

const root = document.getElementById('root')
const loadingEl = document.getElementById('loading')
const scrollerEl = document.getElementById('scroller')
const gridEl = document.getElementById('grid')
const urlbarText = document.getElementById('urlbar-text')
const urlbarBtn = document.getElementById('urlbar')

async function loadKeyLayoutMap() {
  try {
    const map = await navigator.keyboard.getLayoutMap()
    /** @type {Record<string, string>} */
    const o = {}
    for (const [key, value] of map.entries()) {
      o[key] = value
    }
    keyCodeMap = o
    refreshKbdLabels()
  } catch {
    keyCodeMap = {}
  }
}

function refreshKbdLabels() {
  rowEls.forEach((btn, i) => {
    const app = browsers[i]
    if (!app) return
    const kbd = btn.querySelector('kbd')
    if (!kbd) return
    if (app.hotCode && keyCodeMap[app.hotCode]) {
      kbd.textContent = keyCodeMap[app.hotCode]
      kbd.classList.remove('hidden')
    } else {
      kbd.classList.add('hidden')
    }
  })
}

function setUrlBar(urlStr) {
  if (!urlbarText || !root) return
  root.title = urlStr
  let host = ''
  let port = ''
  try {
    const u = new URL(urlStr)
    host = u.hostname.replace(/^www\./i, '')
    port = u.port
  } catch {
    host = ''
  }
  if (host) {
    urlbarText.textContent = `${host}${port ? `:${port}` : ''}`
  } else {
    urlbarText.innerHTML = '<span class="opacity-30">Turnout</span>'
  }
}

function focusRow(index) {
  const i = Math.max(0, Math.min(index, rowEls.length - 1))
  rowEls[i]?.focus()
}

function renderList() {
  if (!gridEl) return
  gridEl.replaceChildren()
  rowEls = []

  if (browsers.length === 0) {
    const p = document.createElement('p')
    p.className = 'px-4 py-8 text-center text-sm text-opacity-70 dark:text-white dark:text-opacity-60'
    p.textContent = 'No supported browsers found in /Applications or ~/Applications.'
    gridEl.appendChild(p)
    return
  }

  browsers.forEach((app, index) => {
    const wrap = document.createElement('div')
    const btn = document.createElement('button')
    btn.type = 'button'
    btn.setAttribute('role', 'option')
    btn.setAttribute('aria-label', `${app.name} App`)
    btn.className =
      'flex h-12 w-full shrink-0 items-center justify-between space-x-4 rounded-xl px-4 py-2 text-left focus:bg-blue-500 focus:text-white focus:outline-none focus:dark:bg-blue-700 hover:bg-black/10 hover:dark:bg-blue-50/10'

    const nameSpan = document.createElement('span')
    nameSpan.textContent = app.name

    const right = document.createElement('span')
    right.className = 'flex items-center space-x-4'

    const kbd = document.createElement('kbd')
    kbd.className =
      'hidden shrink-0 rounded border border-gray-400 bg-black/5 px-2 py-0.5 text-center text-xs font-bold uppercase dark:border-black dark:bg-black/30'
    if (app.hotCode && keyCodeMap[app.hotCode]) {
      kbd.textContent = keyCodeMap[app.hotCode]
      kbd.classList.remove('hidden')
    }

    const img = document.createElement('img')
    img.alt = ''
    img.className = 'size-6 shrink-0 no-drag'
    const iconSrc = icons[app.name]
    if (iconSrc) {
      img.src = iconSrc
    } else {
      img.classList.add('hidden')
    }

    right.appendChild(kbd)
    right.appendChild(img)
    btn.appendChild(nameSpan)
    btn.appendChild(right)

    btn.addEventListener('click', (e) => {
      api.pick(app.name, currentUrl, {
        isAlt: e.altKey,
        isShift: e.shiftKey,
      })
    })
    btn.addEventListener('keydown', (e) => {
      if (e.code === 'ArrowDown') {
        e.preventDefault()
        e.stopPropagation()
        focusRow(index + 1)
      } else if (e.code === 'ArrowUp') {
        e.preventDefault()
        e.stopPropagation()
        focusRow(index - 1)
      } else if (e.code === 'Enter' || e.code === 'NumpadEnter') {
        e.preventDefault()
        api.pick(app.name, currentUrl, {
          isAlt: e.altKey,
          isShift: e.shiftKey,
        })
      } else if (e.code === 'Escape') {
        e.preventDefault()
        api.cancel()
      }
    })

    wrap.appendChild(btn)
    gridEl.appendChild(wrap)
    rowEls.push(btn)
  })

  if (rowEls[0]) rowEls[0].focus()
}

function showMainUi() {
  loadingEl?.classList.add('hidden')
  scrollerEl?.classList.remove('hidden')
}

api.onInit((payload) => {
  currentUrl = payload.url || ''
  browsers = payload.browsers || []
  icons = payload.icons || {}
  setUrlBar(currentUrl)
  showMainUi()
  renderList()
  // Main shows the (pre-created, hidden) window once the list is in the DOM.
  api.rendered()
  void loadKeyLayoutMap()
})

urlbarBtn?.addEventListener('click', () => {})

document.addEventListener('keydown', (event) => {
  if (['Tab', 'Enter', 'Space'].includes(event.code)) {
    return
  }

  if (event.code === 'Escape') {
    event.preventDefault()
    api.cancel()
    return
  }

  if (event.metaKey && event.key.toLowerCase() === 'c' && currentUrl) {
    event.preventDefault()
    api.copyUrl(currentUrl)
    api.cancel()
    return
  }

  event.preventDefault()

  const found = browsers.find((a) => a.hotCode && a.hotCode === event.code)
  if (!event.metaKey && found) {
    api.pick(found.name, currentUrl, {
      isAlt: event.altKey,
      isShift: event.shiftKey,
    })
  }
})
