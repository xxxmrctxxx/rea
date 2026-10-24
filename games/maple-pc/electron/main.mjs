// Desktop window for the game. Run with `npm start` in games/maple-pc.
import { fileURLToPath } from "node:url";
import { app, BrowserWindow, Menu } from "electron";

const INDEX = fileURLToPath(new URL("../index.html", import.meta.url));

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 720,
    useContentSize: true,
    backgroundColor: "#05060f",
    title: "Maple PC",
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  Menu.setApplicationMenu(null);
  win.loadFile(INDEX);
}

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
