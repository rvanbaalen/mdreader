# mdreader

## Architecture

- **Borderless NSWindow** with a single **WKWebView** filling the entire frame
- ALL UI is rendered in the WebView (HTML/CSS/JS) — no native SwiftUI or AppKit UI components
- Traffic lights, titlebar, sidebar, ToC, reader, welcome screen — everything is web
- Swift handles: file I/O, NSOpenPanel, menu bar, window management, theme persistence
- Communication: JS → Swift via `window.webkit.messageHandlers.app.postMessage()`, Swift → JS via `evaluateJavaScript()`
- Design system from ~/Sites/robinvanbaalen.nl/DESIGN.md (Lora serif, DM Sans, IBM Plex Mono, oklch colors)

## Build

```bash
./build.sh        # builds .app bundle
open mdreader.app  # run it
```

## Rules

- Never add native SwiftUI or AppKit views for UI — use the WebView for everything
- CSS/HTML changes go in `Sources/mdreader/Resources/style.css` and `app.html`
- Swift changes go in `Sources/mdreader/App.swift` (the only Swift file that matters)
- Fonts are bundled in `Sources/mdreader/Resources/Fonts/`
- Always clean build when testing: `rm -rf .build/release mdreader.app && ./build.sh`

## UI Guidelines

- Use CSS transitions and animations everywhere — nothing should snap, everything flows
- Staggered appear animations for content (fadeUp with increasing delay)
- Smooth theme transitions (background, color, border all transition together)
- Use Phosphor Icons (as inline SVGs) for all icons — no emoji, no SF Symbols in the WebView
- Button press states with scale transform
- Sidebar/ToC slide in from their respective edges
- Inline code elements are click-to-copy with visual feedback
- Code blocks have a copy button that appears on hover
