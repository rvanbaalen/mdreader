const { app, BrowserWindow, dialog, Menu, ipcMain, nativeTheme } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow;
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
    // Open file from CLI args
    const fileArg = process.argv.find((arg, i) => i > 0 && !arg.startsWith('-') && !arg.includes('electron'));
    if (fileArg) {
      const resolved = path.resolve(fileArg);
      const stat = fs.statSync(resolved, { throwIfNoEntry: false });
      if (stat?.isDirectory()) {
        openFolder(resolved);
      } else if (stat?.isFile()) {
        openFile(resolved);
      }
    }
  });
}

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
  // Open first markdown file
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

// IPC handlers
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
  // mode: 'dark', 'light', or 'system'
  nativeTheme.themeSource = mode;
});

// Menu
const template = [
  {
    label: app.name,
    submenu: [
      { role: 'about' },
      { type: 'separator' },
      { role: 'quit' },
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
        accelerator: 'CmdOrCtrl+Shift+O',
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

app.whenReady().then(() => {
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
  createWindow();
});

app.on('window-all-closed', () => app.quit());
app.on('open-file', (e, filePath) => {
  e.preventDefault();
  if (mainWindow) openFile(filePath);
});
