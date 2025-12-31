const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  receiveApps: (callback) => ipcRenderer.on("apps-data", callback),
  openApp: (catalogoID) => ipcRenderer.invoke("open-app", catalogoID),
});
