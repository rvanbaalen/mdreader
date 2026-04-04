# Quick Look Preview Extension for mdreader

## Overview

Add a macOS Quick Look Preview Extension so users can press Space on any `.md` file in Finder and see it rendered with mdreader's typography and styling. The preview shows the reader view only — no sidebar, ToC, titlebar, or interactive elements.

## Architecture

**Extension type:** Quick Look Preview Extension (`.appex` bundle)
**API:** `QLPreviewProvider` (macOS 12+, project targets 15+)
**Location in app:** `mdreader.app/Contents/PlugIns/QuickLookPreview.appex/`

### Preview flow

1. User selects a `.md` file in Finder and presses Space
2. macOS invokes `QLPreviewProvider.providePreview(for:)` with the file URL
3. Extension reads the markdown file as UTF-8 text
4. Scans for relative image references, resolves them against the file's directory, converts to base64 data URIs
5. Builds a self-contained HTML document: inline CSS + base64 fonts + JS libraries (marked, highlight.js) + markdown content as a JS string variable
6. Returns `QLPreviewReply` with content type `.html`
7. Quick Look's WebKit renders it — JS executes, markdown is parsed and displayed

### Theme support

CSS `prefers-color-scheme` media query switches between light/dark color tokens. Follows system appearance automatically — no Swift-side detection needed. The existing `[data-theme]` selector approach from the main app is replaced with `@media (prefers-color-scheme: light)` in the Quick Look CSS.

### UTI support

The extension's Info.plist declares `QLSupportedContentTypes`:
- `net.daringfireball.markdown`

Note: We intentionally avoid `public.plain-text` — it's too broad and would hijack Quick Look for `.txt` and other plain text files. If `.md` files aren't recognized under the markdown UTI on some systems, we can add specific file extension matching later.

## Rendering Pipeline

### HTML template

The extension builds a self-contained HTML document with this structure:

- `<head>` contains a single `<style>` block with:
  - Base64 `@font-face` declarations for Lora, DM Sans, IBM Plex Mono
  - Content styling from content.css with theme tokens
  - `@media (prefers-color-scheme: light)` block for light theme token overrides
- `<body>` contains:
  - An `<article class="content">` element where rendered markdown is inserted
  - Inline `<script>` blocks for marked.min.js and highlight.min.js
  - A final `<script>` that parses the markdown string and renders it into the article element, then runs highlight.js on all code blocks

The markdown content is escaped and embedded as a JavaScript string variable. The rendering script uses `marked.parse()` to convert it to HTML, sets it as the article's content, then calls `hljs.highlightAll()` for syntax highlighting.

### Key decisions

- **No DOMPurify.** We're rendering the user's own local file, not untrusted input. Skipping sanitization keeps the bundle smaller and avoids the DOM dependency.
- **No copy buttons on code blocks.** Quick Look is read-only preview, not interactive.
- **Fonts as base64 in CSS.** Embedded in `@font-face` declarations so the HTML is truly self-contained. One-time cost per preview (~300-500KB for the font set).
- **Images as base64 data URIs.** Swift scans the markdown for image references (`![](path)`), resolves relative paths against the `.md` file's directory, reads and base64-encodes them. Absolute URLs (http/https) are left as-is.
- **No sidebar, no ToC, no titlebar.** Just the `<article>` with content styling.

## Source Location

`Sources/mdreader-quicklook/PreviewProvider.swift` — single Swift file containing the `QLPreviewProvider` subclass and HTML templating logic.

## Extension Bundle Structure

```
QuickLookPreview.appex/
  Contents/
    Info.plist
    MacOS/
      QuickLookPreview
    Resources/
      marked.min.js
      highlight.min.js
      quicklook.css
      Fonts/
        Lora-Regular.otf
        Lora-Bold.otf
        Lora-Italic.otf
        Lora-BoldItalic.otf
        DMSans-Variable.ttf
        IBMPlexMono-Regular.otf
```

## Build System Integration

### Production build (build.sh)

Added after the main app assembly:

1. Compile the extension with `swiftc` — link against Foundation and QuickLookUI, use `-Xlinker -e -Xlinker _NSExtensionMain` for the app extension entry point
2. Create the `.appex/Contents/` directory structure
3. Copy the compiled binary to `MacOS/`
4. Generate `Info.plist` with `NSExtensionPointIdentifier: com.apple.quicklook.preview` and `NSExtensionPrincipalClass`
5. Copy JS, CSS, and font resources to `Resources/`
6. Place the `.appex` at `mdreader.app/Contents/PlugIns/QuickLookPreview.appex/`
7. Code sign the `.appex` before signing the main app (inner-to-outer signing order)

### Dev workflow

The Quick Look extension is invoked by Finder, not the app, so it doesn't benefit from HMR. To test:

1. Run `build.sh` (or `build.sh --ql-only` for faster iteration on just the extension)
2. Run `qlmanage -r` to reset Quick Look's extension cache
3. Press Space on a `.md` file in Finder to test the preview

### Fallback

If the `_NSExtensionMain` linker approach proves problematic during implementation, fallback is a minimal `.xcodeproj` for just the extension target.

## Distribution & Registration

The `.appex` is embedded inside `mdreader.app/Contents/PlugIns/`, which is the standard location macOS scans for app extensions. No extra user steps are needed — but the `.app` must be in `/Applications/` for macOS to discover it.

### Prerequisite: Auto-install .app to /Applications

Currently, `brew install mdreader` installs the CLI binary but the `.app` bundle requires a manual step to copy to `/Applications/`. This must be automated. The Homebrew formula's `post_install` block should:

1. Copy `mdreader.app` to `/Applications/mdreader.app`
2. Run `pluginkit -a /Applications/mdreader.app/Contents/PlugIns/QuickLookPreview.appex` to force-register the Quick Look extension (if needed)

This change lives in the formula template at `rvanbaalen/homebrew-tap` (`.github/workflows/update-formula.yml`).

### Extension discovery

- **After install:** macOS scans `/Applications/` for app extensions. The Quick Look `.appex` should be registered automatically.
- **If auto-discovery doesn't work:** The `pluginkit -a` call in `post_install` forces registration without requiring the user to open the app.
- **On uninstall:** Homebrew's `uninstall` block should remove `/Applications/mdreader.app`. macOS will automatically deregister the extension.
- **Verify during implementation** whether `pluginkit -a` is needed or if placing the `.app` in `/Applications/` is sufficient.

## CLAUDE.md Update

Add Quick Look dev/test workflow instructions to CLAUDE.md so the tooling is documented for future sessions.
