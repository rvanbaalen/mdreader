const { ipcRenderer } = require('electron');
const { marked } = require('marked');
const hljs = require('highlight.js');
const DOMPurify = require('dompurify');
const path = require('path');

// ── Marked config ──────────────────────────────────────────────

const renderer = new marked.Renderer();
renderer.code = function({ text, lang }) {
  const highlighted = lang && hljs.getLanguage(lang)
    ? hljs.highlight(text, { language: lang }).value
    : hljs.highlightAuto(text).value;
  const langAttr = lang ? ` data-lang="${lang}"` : '';
  return `<pre${langAttr}><code class="hljs">${highlighted}</code></pre>`;
};
marked.use({ renderer, gfm: true, breaks: false });

function safeMarkdown(md) {
  return DOMPurify.sanitize(marked.parse(md), {
    ADD_TAGS: ['input'],
    ADD_ATTR: ['type', 'checked', 'disabled', 'data-lang'],
  });
}

// ── DOM refs ───────────────────────────────────────────────────

const $ = (s) => document.getElementById(s);
const welcome = $('welcome');
const content = $('content');
const sidebarEl = $('sidebar');
const sidebarContent = $('sidebar-content');
const titlebarPath = $('titlebar-path');
const btnTheme = $('btn-theme');
const btnSidebar = $('btn-sidebar');
const iconSun = $('icon-sun');
const iconMoon = $('icon-moon');
const iconSystem = $('icon-system');
const btnOpenFile = $('btn-open-file');
const btnOpenFolder = $('btn-open-folder');

const tocEl = $('toc');
const tocContent = $('toc-content');
const btnToc = $('btn-toc');

let currentFilePath = null;

// ── Theme: dark → light → system cycle, persisted ──────────────

const THEME_KEY = 'mdreader-theme';

function getStoredTheme() {
  return localStorage.getItem(THEME_KEY) || 'system';
}

function applyTheme(mode) {
  localStorage.setItem(THEME_KEY, mode);
  let resolved;
  if (mode === 'system') {
    resolved = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  } else {
    resolved = mode;
  }
  document.documentElement.dataset.theme = resolved;
  // Tell main process so window bg matches
  ipcRenderer.send('set-theme', mode);
  updateThemeIcon(mode);
}

function updateThemeIcon(mode) {
  iconSun.style.display = mode === 'dark' ? 'inline' : 'none';
  iconMoon.style.display = mode === 'light' ? 'inline' : 'none';
  iconSystem.style.display = mode === 'system' ? 'inline' : 'none';
}

function cycleTheme() {
  const order = ['dark', 'light', 'system'];
  const current = getStoredTheme();
  const next = order[(order.indexOf(current) + 1) % order.length];
  applyTheme(next);
}

btnTheme.addEventListener('click', cycleTheme);

// Listen for system theme changes when in system mode
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
  if (getStoredTheme() === 'system') applyTheme('system');
});

// ── Sidebar toggle, persisted ──────────────────────────────────

const SIDEBAR_KEY = 'mdreader-sidebar';

function getSidebarVisible() {
  const stored = localStorage.getItem(SIDEBAR_KEY);
  return stored === null ? true : stored === 'true';
}

function setSidebarVisible(visible) {
  localStorage.setItem(SIDEBAR_KEY, visible);
  sidebarEl.classList.toggle('hidden', !visible);
  content.classList.toggle('no-sidebar', !visible);
}

btnSidebar.addEventListener('click', () => setSidebarVisible(!getSidebarVisible()));
ipcRenderer.on('toggle-sidebar', () => setSidebarVisible(!getSidebarVisible()));
ipcRenderer.on('toggle-theme-cmd', () => cycleTheme());

// ── ToC toggle, persisted ──────────────────────────────────────

const TOC_KEY = 'mdreader-toc';

function getTocVisible() {
  const stored = localStorage.getItem(TOC_KEY);
  return stored === 'true';
}

function setTocVisible(visible) {
  localStorage.setItem(TOC_KEY, visible);
  tocEl.classList.toggle('hidden', !visible);
}

btnToc.addEventListener('click', () => setTocVisible(!getTocVisible()));
ipcRenderer.on('toggle-toc', () => setTocVisible(!getTocVisible()));

// ── File open / folder handlers ────────────────────────────────

btnOpenFile.addEventListener('click', () => ipcRenderer.send('open-file-dialog'));
btnOpenFolder.addEventListener('click', () => ipcRenderer.send('open-folder-dialog'));

ipcRenderer.on('file-opened', (_, { path: filePath, content: md, folder }) => {
  currentFilePath = filePath;
  welcome.style.display = 'none';
  content.style.display = 'block';
  setContent(md);
  content.scrollTop = 0;

  const name = path.basename(filePath);
  titlebarPath.textContent = folder ? `${path.basename(folder)} / ${name}` : name;
  updateSidebarActive(filePath);
});

ipcRenderer.on('file-updated', (_, md) => {
  const scrollPos = content.scrollTop;
  setContent(md);
  content.scrollTop = scrollPos;
});

ipcRenderer.on('folder-opened', (_, { path: folderPath, tree }) => {
  renderSidebar(tree, folderPath);
});

ipcRenderer.on('file-error', (_, filePath) => {
  welcome.style.display = 'none';
  content.style.display = 'block';
  content.textContent = `Could not read ${filePath}`;
});

function setContent(md) {
  content.textContent = '';
  const tpl = document.createElement('template');
  tpl.innerHTML = safeMarkdown(md);
  content.appendChild(tpl.content);
  buildToc();
}

// ── Table of Contents ──────────────────────────────────────────

function buildToc() {
  tocContent.textContent = '';
  const label = el('div', 'toc-label', 'On this page');
  tocContent.appendChild(label);

  const headings = content.querySelectorAll('h1, h2, h3, h4');
  if (headings.length === 0) return;

  headings.forEach((heading, i) => {
    // Give each heading an ID for scroll targeting
    const id = `heading-${i}`;
    heading.id = id;

    const depth = parseInt(heading.tagName[1]);
    const btn = el('button', `toc-item depth-${depth}`, heading.textContent);
    btn.dataset.target = id;
    btn.addEventListener('click', () => {
      heading.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
    tocContent.appendChild(btn);
  });

  // Track scroll position to highlight active heading
  const reader = $('reader');
  let ticking = false;
  reader.addEventListener('scroll', () => {
    if (!ticking) {
      requestAnimationFrame(() => {
        updateActiveTocItem(headings);
        ticking = false;
      });
      ticking = true;
    }
  });
}

function updateActiveTocItem(headings) {
  const reader = $('reader');
  const scrollTop = reader.scrollTop;
  let activeId = null;

  headings.forEach(h => {
    if (h.offsetTop - 80 <= scrollTop) {
      activeId = h.id;
    }
  });

  tocContent.querySelectorAll('.toc-item').forEach(item => {
    item.classList.toggle('active', item.dataset.target === activeId);
  });
}

// ── Sidebar file tree ──────────────────────────────────────────

function renderSidebar(tree, rootPath) {
  sidebarContent.textContent = '';
  const label = el('div', 'sidebar-section-label', path.basename(rootPath));
  sidebarContent.appendChild(label);
  buildTree(tree, sidebarContent, 0);
}

function buildTree(nodes, container, depth) {
  for (const node of nodes) {
    if (node.isDir) {
      buildFolderNode(node, container, depth);
    } else {
      buildFileNode(node, container, depth);
    }
  }
}

function buildFolderNode(node, container, depth) {
  const row = el('button', 'tree-folder');
  row.style.paddingLeft = `${16 + depth * 16}px`;

  const chevron = el('i', 'ph ph-caret-right tree-chevron');
  const icon = el('i', 'ph ph-folder tree-icon');
  const name = el('span', 'tree-name', node.name);

  row.append(chevron, icon, name);
  container.appendChild(row);

  const children = el('div', 'tree-children collapsed');
  buildTree(node.children, children, depth + 1);
  container.appendChild(children);

  row.addEventListener('click', () => {
    const open = !children.classList.contains('collapsed');
    children.classList.toggle('collapsed', open);
    row.classList.toggle('open', !open);
    chevron.className = open ? 'ph ph-caret-right tree-chevron' : 'ph ph-caret-down tree-chevron';
    icon.className = open ? 'ph ph-folder tree-icon' : 'ph ph-folder-open tree-icon';
  });
}

function buildFileNode(node, container, depth) {
  const row = el('button', 'tree-file');
  row.style.paddingLeft = `${16 + depth * 16}px`;
  row.dataset.path = node.path;

  const icon = el('i', `ph ph-file-text tree-icon${getFileIconClass(node.name)}`);
  const name = el('span', 'tree-name', node.name);

  row.append(icon, name);
  container.appendChild(row);

  if (node.path === currentFilePath) row.classList.add('active');

  row.addEventListener('click', () => {
    ipcRenderer.send('open-file', node.path);
  });
}

function getFileIconClass(filename) {
  const lower = filename.toLowerCase();
  if (lower === 'readme.md') return ' readme';
  if (lower === 'changelog.md') return ' changelog';
  return '';
}

function updateSidebarActive(filePath) {
  sidebarContent.querySelectorAll('.tree-file').forEach(el => {
    el.classList.toggle('active', el.dataset.path === filePath);
  });
}

// ── Helpers ────────────────────────────────────────────────────

function el(tag, className, text) {
  const e = document.createElement(tag);
  if (className) e.className = className;
  if (text) e.textContent = text;
  return e;
}

// ── Drag and drop ──────────────────────────────────────────────

document.addEventListener('dragover', (e) => { e.preventDefault(); e.stopPropagation(); });
document.addEventListener('drop', (e) => {
  e.preventDefault();
  e.stopPropagation();
  const file = e.dataTransfer.files[0];
  if (file) ipcRenderer.send('open-file', file.path);
});

// ── Init ───────────────────────────────────────────────────────

applyTheme(getStoredTheme());
setSidebarVisible(getSidebarVisible());
setTocVisible(getTocVisible());
