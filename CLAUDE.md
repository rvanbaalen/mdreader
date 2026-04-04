# mdreader

## Architecture

- **NSWindow** with transparent titlebar, native traffic lights, and a single **WKWebView**
- ALL UI is rendered in the WebView (HTML/CSS/JS) — no native SwiftUI or AppKit UI components
- Titlebar (frosted glass overlay), sidebar, ToC, reader, welcome screen — everything is web
- Swift handles: file I/O, NSOpenPanel, menu bar, window management, theme persistence, update checks
- Communication: JS → Swift via `window.webkit.messageHandlers.app.postMessage()`, Swift → JS via `evaluateJavaScript()`
- Multi-window: each window is a `WindowController` with its own WKWebView and file state
- Images in markdown: resolved via `mdfile://` custom URL scheme handled by `LocalFileHandler`
- Design system defined in DESIGN.md (Lora serif, DM Sans, IBM Plex Mono, oklch colors)

## Build

```bash
npm run dev    # debug Swift build + Vite dev server + launch app with HMR
npm run build  # production build (./build.sh)
npm start      # open the built app
```

## App Icon

- Source SVGs: `build/icon-dark.svg` (dark mode) and `build/icon-light.svg` (light mode)
- Uses the Phosphor BookOpen icon (regular weight, filled path) on a dark cool-blue background
- Light/dark mode via Asset Catalog (`build/Assets.xcassets/`) compiled to `Assets.car`
- Fallback `.icns` for older macOS versions

**Regenerating icons after SVG changes:**

```bash
bash build/generate-icons.sh   # renders SVGs → PNGs → .icns + Assets.car
```

The script compiles `build/svg2png.swift` (a Swift SVG renderer) on first run, then generates all required sizes and the Asset Catalog. Both `icon.icns` and `Assets.car` are committed — no need to regenerate unless the SVGs change.

## Quick Look Extension

The app includes a Quick Look Preview Extension (`.appex`) that renders `.md` files when pressing Space in Finder.

- Source: `Sources/mdreader-quicklook/PreviewProvider.swift`
- Styles: `Sources/mdreader-quicklook/Resources/quicklook.css`
- Built and embedded automatically by `build.sh`

**Testing Quick Look changes:**

```bash
rm -rf .build/release mdreader.app && ./build.sh   # full rebuild
qlmanage -r                                         # reset Quick Look cache
qlmanage -p path/to/test.md                         # preview via CLI (or press Space in Finder)
```

The extension shares JS libraries and fonts with the main app (from `Sources/mdreader/Resources/`). CSS is standalone in `quicklook.css` — if you change content styles in `web/src/content.css`, update `quicklook.css` to match.

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
- Always write typesafe code. Never use `as any` — use proper types, interfaces, or `unknown` with type guards
- Never use `style={{}}` in React components — always use Tailwind classes including arbitrary values

## UX Principles

- Every user action must have visible feedback (toast, animation, state change)
- Never fail silently — always show user-friendly feedback on success AND failure
- Use non-technical language in all user-facing messages
- Keyboard shortcuts must work reliably — test the full chain (native menu → JS bridge → action)

## UI Guidelines

- Use CSS transitions and animations everywhere — nothing should snap, everything flows
- Staggered appear animations for content (fadeUp with increasing delay)
- Smooth theme transitions (background, color, border all transition together)
- Use `@phosphor-icons/react` with `NameIcon` convention (not deprecated `Name` exports) — never hand-code SVGs, never use emoji, SF Symbols, or ASCII/Unicode characters for icons or modifier keys (use CommandIcon, ArrowUpIcon, OptionIcon, ControlIcon etc.)
- Never edit shadcn components directly — compose around them
- Button press states with scale transform
- Sidebar/ToC slide in from their respective edges
- Inline code elements are click-to-copy with visual feedback
- Code blocks have a copy button that appears on hover
