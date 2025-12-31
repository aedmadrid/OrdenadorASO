const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("node:path");
const fs = require("fs");
const os = require("os");

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require("electron-squirrel-startup")) {
  app.quit();
}

const downloadIcon = async (iconUrl) => {
  try {
    const response = await fetch(iconUrl);
    const buffer = await response.arrayBuffer();
    const tempDir = os.tmpdir();
    const ext = path.extname(iconUrl) || ".png";
    const iconPath = path.join(tempDir, `icon_${Date.now()}${ext}`);
    fs.writeFileSync(iconPath, Buffer.from(buffer));
    return iconPath;
  } catch (error) {
    console.error("Error downloading icon:", error);
    return null;
  }
};

const createWebAppWindow = async (title, icon, url, userAgent) => {
  let iconPath = null;
  if (icon) {
    iconPath = await downloadIcon(icon);
  }
  const webAppWindow = new BrowserWindow({
    title,
    icon: iconPath,
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      contentSecurityPolicy:
        "default-src *; script-src * 'unsafe-inline' 'unsafe-eval'; style-src * 'unsafe-inline'; img-src * data:; connect-src *;",
    },
  });
  webAppWindow.webContents.setUserAgent(userAgent);
  webAppWindow.loadURL(url);
  webAppWindow.once("ready-to-show", () => {
    webAppWindow.setTitle(title);
  });
};

const parseWebAppArgs = () => {
  const args = process.argv.slice(2);
  if (args[0] !== "--webAPP") return null;
  let title, icon, ua, url;
  for (let i = 1; i < args.length; i++) {
    if (args[i] === "-n") title = args[++i];
    else if (args[i] === "-i") icon = args[++i];
    else if (args[i] === "-u") ua = args[++i];
    else url = args[i];
  }
  return { title, icon, ua, url };
};

const createWindow = () => {
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
    },
  });

  // and load the index.html of the app.
  mainWindow.loadFile(path.join(__dirname, "index.html"));

  // Obtener lista de apps disponibles
  fetch("https://aedmadrid.github.io/OrdenadorASO/swlist.json")
    .then((response) => response.json())
    .then((data) => {
      const apps = data;
      console.log("Lista de apps:", apps);
      mainWindow.webContents.send("apps-data", apps);
    })
    .catch((error) => {
      console.error("Error al obtener la lista de apps:", error);
    });
};

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.whenReady().then(async () => {
  const webAppArgs = parseWebAppArgs();
  if (webAppArgs) {
    await createWebAppWindow(
      webAppArgs.title,
      webAppArgs.icon,
      webAppArgs.url,
      webAppArgs.ua,
    );
  } else {
    createWindow();

    // On OS X it's common to re-create a window in the app when the
    // dock icon is clicked and there are no other windows open.
    app.on("activate", () => {
      if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
      }
    });
  }
});

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

ipcMain.handle("open-app", async (event, catalogoID) => {
  try {
    const response = await fetch(
      `https://aedmadrid.github.io/OrdenadorASO/${catalogoID}`,
    );
    const command = await response.text();
    const match = command.match(
      /portal --webAPP -n "([^"]*)" -i "([^"]*)" -u "([^"]*)" "([^"]*)"/,
    );
    if (match) {
      const [, title, icon, ua, url] = match;
      await createWebAppWindow(title, icon, url, ua);
    }
  } catch (error) {
    console.error("Error opening app:", error);
  }
});

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and import them here.
