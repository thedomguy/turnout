const { contextBridge, ipcRenderer, clipboard } = require('electron')

contextBridge.exposeInMainWorld('turnout', {
  onInit(cb) {
    ipcRenderer.on('picker-init', (_e, payload) => cb(payload))
  },
  pick(name, url, opts) {
    ipcRenderer.send('pick-browser', {
      name,
      url,
      background: !!(opts && opts.background),
      isAlt: !!(opts && opts.isAlt),
      isShift: !!(opts && opts.isShift),
    })
  },
  rendered() {
    ipcRenderer.send('picker-rendered')
  },
  cancel() {
    ipcRenderer.send('cancel-picker')
  },
  copyUrl(text) {
    clipboard.writeText(text)
  },
})
