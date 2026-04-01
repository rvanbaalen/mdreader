const { app, BrowserWindow, dialog, Menu, ipcMain, nativeTheme } = require('electron');
const { autoUpdater } = require('electron-updater');
const path = require('path');
const fs = require('fs');

// Set app name before anything else
app.setName('mdreader');

let mainWindow;
let aboutWindow;
let currentFile = null;
let currentFolder = null;
let watcher = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 750,
    minWidth: 600,
    minHeight: 400,
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 20, y: 18 },
    backgroundColor: '#0a0a0f',
    vibrancy: 'sidebar',
    show: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  mainWindow.loadFile('index.html');
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    const fileArg = process.argv.find((arg, i) => i > 0 && !arg.startsWith('-') && !arg.includes('electron'));
    if (fileArg) {
      const resolved = path.resolve(fileArg);
      const stat = fs.statSync(resolved, { throwIfNoEntry: false });
      if (stat?.isDirectory()) openFolder(resolved);
      else if (stat?.isFile()) openFile(resolved);
    }
  });
}

// ── About window ───────────────────────────────────────────────

function showAbout() {
  if (aboutWindow) {
    aboutWindow.focus();
    return;
  }

  aboutWindow = new BrowserWindow({
    width: 320,
    height: 340,
    resizable: false,
    minimizable: false,
    maximizable: false,
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#0a0a0f',
    show: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  const version = app.getVersion();
  const electronVersion = process.versions.electron;

  const html = `<!DOCTYPE html>
<html>
<head>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Lora:wght@400;700&family=DM+Sans:wght@400;450;500&family=IBM+Plex+Mono:wght@400&display=swap');
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: oklch(10% 0.01 260);
    color: oklch(65% 0.01 80);
    font-family: 'DM Sans', -apple-system, sans-serif;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100vh;
    -webkit-app-region: drag;
    user-select: none;
  }
  .icon { margin-bottom: 20px; }
  .icon img { width: 80px; height: 80px; border-radius: 18px; }
  h1 {
    font-family: 'Lora', Georgia, serif;
    font-size: 24px;
    font-weight: 700;
    color: oklch(93% 0.015 80);
    margin-bottom: 4px;
    letter-spacing: -0.01em;
  }
  .version {
    font-size: 13px;
    color: oklch(45% 0.008 260);
    margin-bottom: 16px;
  }
  .desc {
    font-size: 13px;
    color: oklch(55% 0.008 260);
    text-align: center;
    line-height: 1.5;
    max-width: 240px;
    margin-bottom: 20px;
  }
  .links {
    display: flex;
    gap: 16px;
    -webkit-app-region: no-drag;
  }
  a {
    font-size: 12px;
    color: oklch(62% 0.04 260);
    text-decoration: none;
    transition: color 0.15s ease;
  }
  a:hover { color: oklch(70% 0.05 260); }
  .copy {
    font-size: 11px;
    color: oklch(30% 0.008 260);
    margin-top: 16px;
  }
</style>
</head>
<body>
  <div class="icon"><img src="build/icon.png"></div>
  <h1>mdreader</h1>
  <div class="version">Version ${version}</div>
  <div class="desc">A beautiful macOS markdown reader with editorial typography and a design that gets out of the way.</div>
  <div class="links">
    <a href="#" onclick="require('electron').shell.openExternal('https://github.com/rvanbaalen/mdreader');return false">GitHub</a>
    <a href="#" onclick="require('electron').shell.openExternal('https://github.com/rvanbaalen/mdreader/releases');return false">Releases</a>
  </div>
  <div class="copy">&copy; ${new Date().getFullYear()} Robin van Baalen</div>
</body>
</html>`;

  aboutWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`);
  aboutWindow.once('ready-to-show', () => aboutWindow.show());
  aboutWindow.on('closed', () => { aboutWindow = null; });
}

// ── Auto-updater ───────────────────────────────────────────────

autoUpdater.autoDownload = false;
autoUpdater.autoInstallOnAppQuit = true;

autoUpdater.on('update-available', (info) => {
  const result = dialog.showMessageBoxSync(mainWindow, {
    type: 'info',
    title: 'Update Available',
    message: `mdreader ${info.version} is available.`,
    detail: 'Would you like to download and install it?',
    buttons: ['Download', 'Later'],
    defaultId: 0,
  });
  if (result === 0) autoUpdater.downloadUpdate();
});

autoUpdater.on('update-downloaded', () => {
  const result = dialog.showMessageBoxSync(mainWindow, {
    type: 'info',
    title: 'Update Ready',
    message: 'Update has been downloaded.',
    detail: 'It will be installed when you quit mdreader. Restart now?',
    buttons: ['Restart', 'Later'],
    defaultId: 0,
  });
  if (result === 0) autoUpdater.quitAndInstall();
});

autoUpdater.on('error', () => {
  // Silent fail — don't bother the user if update check fails
});

// ── File operations ────────────────────────────────────────────

function openFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    currentFile = filePath;
    addToRecent(filePath);
    mainWindow.webContents.send('file-opened', { path: filePath, content, folder: currentFolder });
    watchFile(filePath);
  } catch (e) {
    mainWindow.webContents.send('file-error', filePath);
  }
}

function openFolder(folderPath) {
  currentFolder = folderPath;
  const tree = scanFolder(folderPath);
  mainWindow.webContents.send('folder-opened', { path: folderPath, tree });
  const first = findFirstMd(tree);
  if (first) openFile(first);
}

function scanFolder(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true })
    .filter(e => !e.name.startsWith('.'))
    .sort((a, b) => {
      if (a.isDirectory() && !b.isDirectory()) return -1;
      if (!a.isDirectory() && b.isDirectory()) return 1;
      return a.name.localeCompare(b.name);
    });

  return entries.map(entry => {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const children = scanFolder(fullPath);
      if (children.some(c => c.children?.length > 0 || c.name.match(/\.(md|markdown)$/i))) {
        return { name: entry.name, path: fullPath, isDir: true, children };
      }
      return null;
    } else if (entry.name.match(/\.(md|markdown)$/i)) {
      return { name: entry.name, path: fullPath, isDir: false };
    }
    return null;
  }).filter(Boolean);
}

function findFirstMd(tree) {
  const readme = tree.find(n => !n.isDir && n.name.toLowerCase() === 'readme.md');
  if (readme) return readme.path;
  const firstFile = tree.find(n => !n.isDir);
  if (firstFile) return firstFile.path;
  for (const node of tree) {
    if (node.isDir && node.children) {
      const found = findFirstMd(node.children);
      if (found) return found;
    }
  }
  return null;
}

function watchFile(filePath) {
  if (watcher) watcher.close();
  watcher = fs.watch(filePath, () => {
    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      mainWindow.webContents.send('file-updated', content);
    } catch {}
  });
}

function addToRecent(filePath) {
  app.addRecentDocument(filePath);
}

// ── IPC handlers ───────────────────────────────────────────────

ipcMain.on('open-file-dialog', () => {
  const result = dialog.showOpenDialogSync(mainWindow, {
    filters: [{ name: 'Markdown', extensions: ['md', 'markdown'] }],
    properties: ['openFile'],
  });
  if (result?.[0]) openFile(result[0]);
});

ipcMain.on('open-folder-dialog', () => {
  const result = dialog.showOpenDialogSync(mainWindow, {
    properties: ['openDirectory'],
  });
  if (result?.[0]) openFolder(result[0]);
});

ipcMain.on('open-file', (_, filePath) => openFile(filePath));

ipcMain.on('set-theme', (_, mode) => {
  nativeTheme.themeSource = mode;
});

// ── Menu ───────────────────────────────────────────────────────

const template = [
  {
    label: 'mdreader',
    submenu: [
      {
        label: 'About mdreader',
        click: () => showAbout(),
      },
      {
        label: 'Check for Updates...',
        click: () => autoUpdater.checkForUpdates(),
      },
      { type: 'separator' },
      { role: 'hide', label: 'Hide mdreader' },
      { role: 'hideOthers' },
      { role: 'unhide' },
      { type: 'separator' },
      { role: 'quit', label: 'Quit mdreader' },
    ],
  },
  {
    label: 'File',
    submenu: [
      {
        label: 'Open File...',
        accelerator: 'CmdOrCtrl+O',
        click: () => ipcMain.emit('open-file-dialog'),
      },
      {
        label: 'Open Folder...',
        accelerator: 'CmdOrCtrl+Shift+O',
        click: () => ipcMain.emit('open-folder-dialog'),
      },
    ],
  },
  {
    label: 'View',
    submenu: [
      {
        label: 'Toggle Sidebar',
        accelerator: 'CmdOrCtrl+\\',
        click: () => mainWindow.webContents.send('toggle-sidebar'),
      },
      {
        label: 'Toggle Table of Contents',
        accelerator: 'CmdOrCtrl+Shift+E',
        click: () => mainWindow.webContents.send('toggle-toc'),
      },
      {
        label: 'Toggle Theme',
        accelerator: 'CmdOrCtrl+Shift+T',
        click: () => mainWindow.webContents.send('toggle-theme-cmd'),
      },
      { type: 'separator' },
      { role: 'toggleDevTools' },
    ],
  },
  { label: 'Edit', submenu: [{ role: 'copy' }, { role: 'selectAll' }] },
  { label: 'Window', submenu: [{ role: 'minimize' }, { role: 'close' }] },
];

// ── Default app check ──────────────────────────────────────────

ipcMain.on('check-default-app', () => {
  if (!app.isPackaged) return;
  const { execFileSync } = require('child_process');
  try {
    const plist = execFileSync('defaults', [
      'read', 'com.apple.LaunchServices/com.apple.launchservices.secure', 'LSHandlers'
    ], { encoding: 'utf-8' });
    const isMdreader = plist.includes('com.rvanbaalen.mdreader');
    if (!isMdreader) {
      mainWindow.webContents.send('ask-default-app');
    }
  } catch {
    mainWindow.webContents.send('ask-default-app');
  }
});

ipcMain.on('set-default-app', () => {
  const { execFileSync } = require('child_process');
  try {
    execFileSync('which', ['duti'], { encoding: 'utf-8' });
    execFileSync('duti', ['-s', 'com.rvanbaalen.mdreader', 'net.daringfireball.markdown', 'viewer'], { encoding: 'utf-8' });
  } catch {
    dialog.showMessageBox(mainWindow, {
      type: 'info',
      title: 'Set Default App',
      message: 'To set mdreader as your default markdown reader:',
      detail: '1. Right-click any .md file in Finder\n2. Click "Get Info"\n3. Under "Open with", select mdreader\n4. Click "Change All..."',
      buttons: ['OK'],
    });
  }
});

// ── App lifecycle ──────────────────────────────────────────────

app.whenReady().then(() => {
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
  createWindow();
  // Check for updates silently on launch (not in dev)
  if (app.isPackaged) {
    autoUpdater.checkForUpdates();
  }
});

app.on('window-all-closed', () => app.quit());
app.on('open-file', (e, filePath) => {
  e.preventDefault();
  if (mainWindow) openFile(filePath);
});
