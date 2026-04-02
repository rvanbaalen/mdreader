# mdreader

## Architecture

- **NSWindow** with transparent titlebar, native traffic lights, and a single **WKWebView**
- ALL UI is rendered in the WebView (HTML/CSS/JS) — no native SwiftUI or AppKit UI components
- Titlebar (frosted glass overlay), sidebar, ToC, reader, welcome screen — everything is web
- Swift handles: file I/O, NSOpenPanel, menu bar, window management, theme persistence, update checks
- Communication: JS → Swift via `window.webkit.messageHandlers.app.postMessage()`, Swift → JS via `evaluateJavaScript()`
- Multi-window: each window is a `WindowController` with its own WKWebView and file state
- Images in markdown: resolved via `mdfile://` custom URL scheme handled by `LocalFileHandler`
- Design system from ~/Sites/robinvanbaalen.nl/DESIGN.md (Lora serif, DM Sans, IBM Plex Mono, oklch colors)

## Build

```bash
npm run dev    # debug Swift build + Vite dev server + launch app with HMR
npm run build  # production build (./build.sh)
npm start      # open the built app
```

## Release

- Releases are automated via release-please. Never manually bump versions.
- `build.sh` and `dev.sh` contain `x-release-please-version` placeholders — release-please updates these automatically.
- The Homebrew formula template lives in `rvanbaalen/homebrew-tap` at `.github/workflows/update-formula.yml`. If you change build dependencies, install steps, or caveats in the formula, update the template there — each release dispatch overwrites the formula from the template.

## Rules

- Never add native SwiftUI or AppKit views for UI — use the WebView for everything
- CSS/HTML changes go in `web/src/`
- Swift changes go in `Sources/mdreader/App.swift` (the only Swift file that matters)
- Fonts are bundled in `Sources/mdreader/Resources/Fonts/`
- Always clean build when testing: `rm -rf .build/release mdreader.app && ./build.sh`
- Never do manual work that an automated process handles (version bumps, formula updates, changelog generation)

## UI Guidelines

- Use CSS transitions and animations everywhere — nothing should snap, everything flows
- Staggered appear animations for content (fadeUp with increasing delay)
- Smooth theme transitions (background, color, border all transition together)
- Use `@phosphor-icons/react` with `NameIcon` convention (not deprecated `Name` exports) — never hand-code SVGs, never use emoji or SF Symbols
- Never edit shadcn components directly — compose around them
- Button press states with scale transform
- Sidebar/ToC slide in from their respective edges
- Inline code elements are click-to-copy with visual feedback
- Code blocks have a copy button that appears on hover
