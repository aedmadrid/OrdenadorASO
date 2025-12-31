const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("node:path");
const fs = require("fs");
const os = require("os");
const { exec } = require("child_process");

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require("electron-squirrel-startup")) {
  app.quit();
  return;
}

const parseWebAppArgs = () => {
  const args = process.argv.slice(1);
  if (args.length === 0) return null;
  let startIndex = 0;
  if (
    args[0] &&
    (args[0].includes("electron") ||
      args[0].includes("portal") ||
      args[0] === ".")
  ) {
    startIndex = 1;
  }
  if (args[startIndex] !== "--webAPP") return null;
  let title, icon, ua, url;
  for (let i = startIndex + 1; i < args.length; i++) {
    if (args[i] === "-n") title = args[++i];
    else if (args[i] === "-i") icon = args[++i];
    else if (args[i] === "-u") ua = args[++i];
    else url = args[i];
  }
  return { title, icon, ua, url };
};

const launchWebAppInChrome = async ({ title, icon, ua, url }) => {
  const chromePaths = [
    "google-chrome-stable",
    "chromium",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ];

  let browserCommand = null;
  for (const chromePath of chromePaths) {
    try {
      await fs.promises.access(chromePath, fs.constants.X_OK);
      browserCommand = chromePath;
      break;
    } catch {
      continue;
    }
  }

  if (!browserCommand) {
    console.error("No compatible browser found (Google Chrome or Chromium).");
    return;
  }

  const command = `"${browserCommand}" --args --user-data-dir="/tmp/chrome-pwa-profile" --user-agent="${ua}" --app="${url}"`;
  exec(command, (error) => {
    if (error) {
      console.error("Error launching browser:", error.message);
    } else {
      app.quit(); // Close the Electron app if Chrome launches successfully
    }
  });
};

const createWindow = () => {
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 600,
    height: 600,
    minWidth: 550,
    minHeight: 600,
    icon: path.join(__dirname, "../icons/portal.png"),
    autoHideMenuBar: true,
    menuBarVisible: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
    },
  });

  mainWindow.setIcon(path.join(__dirname, "../icons/portal.png"));
  mainWindow.webContents.on("context-menu", (e) => e.preventDefault());

  // and load the index.html of the app.
  mainWindow.loadFile(path.join(__dirname, "index.html"));

  // Obtener lista de apps disponibles después de que la página termine de cargar
  mainWindow.webContents.on("did-finish-load", () => {
    fetch("https://aedmadrid.github.io/OrdenadorASO/swlist.json")
      .then((response) => response.json())
      .then((data) => {
        const apps = data;
        mainWindow.webContents.send("apps-data", apps);
      })
      .catch((error) => {
        console.error("Error al obtener la lista de apps:", error);
      });
  });

  // Handle opening SolApp as a PWA
  ipcMain.handle("open-solapp", async () => {
    const url = "https://u.aedm.org.es/solapp";
    const ua =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36";
    const title = "SolApp";
    const icon = ""; // Add an icon URL if needed
    await launchWebAppInChrome({ title, icon, ua, url });
  });
};

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.whenReady().then(async () => {
  const webAppArgs = parseWebAppArgs();
  if (webAppArgs) {
    await launchWebAppInChrome(webAppArgs);
  } else {
    createWindow();

    // On macOS, re-create a window in the app when the
    // dock icon is clicked and there are no other windows open.
    app.on("activate", () => {
      if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
      }
    });
  }
});

const detectBrowser = async () => {
  const chromePaths = [
    "google-chrome-stable",
    "chromium",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ];

  for (const chromePath of chromePaths) {
    try {
      await fs.promises.access(chromePath, fs.constants.X_OK);
      return chromePath;
    } catch {
      console.warn(`Browser not found or not executable: ${chromePath}`);
      continue;
    }
  }
  console.error("No compatible browser found. Checked paths:", chromePaths);
  return null;
};

// Quit when all windows are closed.
app.on("window-all-closed", () => {
  app.quit();
});

ipcMain.handle("open-app", async (event, catalogoID) => {
  try {
    const response = await fetch(
      `https://aedmadrid.github.io/OrdenadorASO/${catalogoID}.app`,
    );
    const command = await response.text();
    exec(command, (error, stdout, stderr) => {
      if (error) {
        console.error(`Error executing command: ${error.message}`);
        return;
      }
      console.log("Command executed successfully:", stdout);
    });
  } catch (error) {
    console.error("Error fetching command:", error.message);
  }
});

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and import them here.
