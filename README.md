# mdreader

A beautiful, native macOS markdown reader. Open any `.md` file and read it the way it was meant to be read.

![mdreader](screenshot.png)

## Why

Every markdown tool on macOS is either an editor that happens to render, or a basic viewer with zero design craft. mdreader is a **reader**, not an editor. It treats markdown as a first-class reading experience with proper typography, syntax highlighting, and a design that gets out of the way.

## Features

- **Beautiful typography** — Lora serif for body, DM Sans for UI, IBM Plex Mono for code
- **Syntax highlighting** — powered by highlight.js
- **Dark and light mode** — defaults to your system preference
- **Multi-window** — open multiple files in separate windows, all under one dock icon
- **File browser sidebar** — open a folder and browse all markdown files
- **Table of contents** — auto-generated from headings with scroll tracking
- **Source view** — toggle raw markdown with syntax-highlighted coloring
- **Click to copy** — inline code and code blocks, with toast notification
- **Live reload** — file changes on disk are reflected instantly
- **Drag and drop** — drop any `.md` file onto the window

## Install

### Homebrew

```bash
brew install rvanbaalen/tap/mdreader
sudo ln -sf $(brew --prefix)/opt/mdreader/mdreader.app /Applications/mdreader.app
```

### From source

```bash
git clone https://github.com/rvanbaalen/mdreader.git
cd mdreader
./build.sh
open mdreader.app
```

## Development

```bash
npm run dev    # build Swift (debug), start Vite dev server, launch app with HMR
npm run build  # production build
npm start      # open the built app
```

Web changes are instant via Vite HMR. Swift changes require restarting `npm run dev`.

## Usage

```bash
mdreader README.md
mdreader ./docs
open -a mdreader README.md
```

Or just open the app and use `⌘O` / `⌘⇧O`.

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New window | `⌘N` |
| Close window | `⌘W` |
| Open file | `⌘O` |
| Open folder | `⌘⇧O` |
| Toggle sidebar | `⌘\` |
| Toggle table of contents | `⌘⇧E` |
| Toggle source view | `⌘⇧S` |
| Toggle theme | `⌘⇧T` |

## Architecture

`NSWindow` with transparent titlebar, native traffic lights, and a single `WKWebView`. All UI is HTML/CSS/JS (React + Tailwind). Swift handles file I/O, menus, and window management. Each window is an independent `WindowController` with its own web view and file state. Design system adapted from [robinvanbaalen.nl](https://robinvanbaalen.nl).

## License

MIT
