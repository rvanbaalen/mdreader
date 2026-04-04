# Quick Look Preview Extension — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS Quick Look Preview Extension so pressing Space on a `.md` file in Finder shows it rendered with mdreader's typography and styling.

**Architecture:** A `QLPreviewProvider` app extension (`.appex`) embedded in `mdreader.app/Contents/PlugIns/`. The extension reads markdown, resolves images to base64 data URIs, and returns a self-contained HTML document rendered client-side with the same marked + highlight.js pipeline as the main app. Theme follows system appearance via `prefers-color-scheme`.

**Tech Stack:** Swift (compiled with `swiftc`), Quartz/QuickLookUI framework, existing JS libraries (marked.min.js, highlight.min.js), CSS custom properties for theming.

**Spec:** `docs/superpowers/specs/2026-04-04-quick-look-preview-design.md`

---

## File Structure

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `Sources/mdreader-quicklook/PreviewProvider.swift` | QL extension: read markdown, resolve images, assemble HTML, return reply |
| Create | `Sources/mdreader-quicklook/Resources/quicklook.css` | Standalone CSS: theme tokens + content styles + hljs, using `prefers-color-scheme` |
| Modify | `build.sh` | Compile extension, assemble `.appex`, embed in app bundle, code sign |
| Modify | `CLAUDE.md` | Add Quick Look dev/test workflow instructions |

Resources copied into `.appex` at build time (not new files — existing assets):
- `Sources/mdreader/Resources/marked.min.js`
- `Sources/mdreader/Resources/highlight.min.js`
- `Sources/mdreader/Resources/Fonts/*` (all 6 font files)

---

## Task 1: Create quicklook.css

**Files:**
- Create: `Sources/mdreader-quicklook/Resources/quicklook.css`

This CSS file is a standalone extraction from `web/src/index.css` (theme tokens, font families) and `web/src/content.css` (markdown styling, hljs colors). It replaces `[data-theme="light"]` selectors with `@media (prefers-color-scheme: light)` for automatic system theme following.

Excluded from the main app's CSS: copy-btn styles (no interactivity in QL), staggered appear animations, scrollbar hiding, tailwind imports, shadcn tokens not used by content styles.

- [ ] **Step 1: Create the quicklook.css file**

The full CSS content is specified in the plan code block below. Write it to `Sources/mdreader-quicklook/Resources/quicklook.css`.

The CSS structure:
1. A placeholder comment `/* QUICKLOOK_FONT_FACE_DECLARATIONS */` where Swift injects base64 font-face rules at runtime
2. Base reset and body setup (max-width 800px centered, 48px/32px padding)
3. `:root` block with dark theme tokens (from `web/src/index.css` lines 17-53)
4. `@media (prefers-color-scheme: light)` block overriding tokens (from `web/src/index.css` lines 56-89)
5. `.content` markdown styles (from `web/src/content.css` lines 1-83, excluding `.copy-btn` block and `.animate-content` block)
6. highlight.js dark theme colors (from `web/src/content.css` lines 96-115)
7. highlight.js light theme inside `@media (prefers-color-scheme: light)` (from `web/src/content.css` lines 117-129, selector changed from `[data-theme="light"]`)

Key CSS custom properties needed (dark/light):
- `--font-serif`, `--font-sans`, `--font-mono`
- `--color-background`, `--color-foreground`, `--color-primary`
- `--color-muted`, `--color-muted-foreground`, `--color-accent`
- `--color-accent-bright`, `--color-accent-dim`, `--color-accent-glow`
- `--color-border`, `--color-card`, `--color-card-foreground`, `--color-dim`

- [ ] **Step 2: Verify CSS matches source**

Compare against `web/src/index.css` (theme tokens) and `web/src/content.css` (content styles). Confirm every `[data-theme="light"]` selector has been converted to `@media (prefers-color-scheme: light)`. Confirm copy-btn and animation styles are excluded.

- [ ] **Step 3: Commit**

```bash
git add Sources/mdreader-quicklook/Resources/quicklook.css
git commit -m "feat(quicklook): add standalone CSS for Quick Look preview"
```

---

## Task 2: Create PreviewProvider.swift

**Files:**
- Create: `Sources/mdreader-quicklook/PreviewProvider.swift`

This is the entire Quick Look extension in a single file. It reads markdown, resolves images, assembles a self-contained HTML document, and returns it as a `QLPreviewReply`.

- [ ] **Step 1: Create the PreviewProvider.swift file**

Write to `Sources/mdreader-quicklook/PreviewProvider.swift`. The file contains a single class `PreviewProvider` extending `QLPreviewProvider` with these methods:

**`providePreview(for:)`** — Entry point. Reads markdown from `request.fileURL`, calls `resolveImages()`, calls `buildHTML()`, returns `QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 800, height: 600))`.

**`resolveImages(in:relativeTo:)`** — Regex scans for `![alt](path)` where path is not `https?://` or `data:`. For each match: resolves path relative to the markdown file's directory, reads file, base64-encodes, replaces with `data:<mime>;base64,...` URI. Processes matches in reverse order so replacement ranges stay valid. Uses same regex pattern as `web/src/lib/markdown.ts:28`.

**`mimeType(for:)`** — Maps file extensions to MIME types. Same mapping as `LocalFileHandler` in `Sources/mdreader/App.swift:784-792`.

**`buildHTML(markdown:)`** — Assembles the full HTML document:
1. Loads `marked.min.js`, `highlight.min.js`, `quicklook.css` from `Bundle(for: PreviewProvider.self)` resources directory
2. Generates base64 `@font-face` CSS via `buildFontFaceCSS()`
3. Replaces `/* QUICKLOOK_FONT_FACE_DECLARATIONS */` in CSS with generated font-face rules
4. JSON-encodes markdown string for safe JS embedding via `escapeForJS()`
5. Returns HTML with: `<style>` (CSS), `<article class="content" id="content">`, `<script>` (marked.js), `<script>` (highlight.js), `<script>` (render script)

The render script creates a custom `marked.Renderer` for code blocks matching `web/src/lib/markdown.ts:7-13` but **without the copy button** SVG. It calls `marked.parse()` and sets the result as the content element's HTML, then calls `hljs.highlightAll()` — but note highlight.js is already applied per-block by the custom renderer, so `highlightAll()` is not needed and should be omitted.

**`buildFontFaceCSS(from:)`** — Iterates over the 6 font files in the extension bundle's `Resources/Fonts/` directory:
- `Lora-Regular.otf` (family: Lora, weight: 400, style: normal, format: opentype)
- `Lora-Bold.otf` (family: Lora, weight: 700, style: normal, format: opentype)
- `Lora-Italic.otf` (family: Lora, weight: 400, style: italic, format: opentype)
- `Lora-BoldItalic.otf` (family: Lora, weight: 700, style: italic, format: opentype)
- `DMSans-Variable.ttf` (family: DM Sans, weight: 100 1000, style: normal, format: truetype)
- `IBMPlexMono-Regular.otf` (family: IBM Plex Mono, weight: 400, style: normal, format: opentype)

Each font is read, base64-encoded, and emitted as an `@font-face` rule with `src: url('data:<mime>;base64,...') format('<format>')`.

**`escapeForJS(_:)`** — Uses `JSONSerialization.data(withJSONObject:options:.fragmentsAllowed)` to produce a quoted, escaped JS string literal. Returns `""` on failure.

- [ ] **Step 2: Review against source patterns**

Verify:
- `QLPreviewProvider` exists in Quartz framework (macOS 12+)
- `providePreview(for:)` matches the `QLPreviewProvider` API signature
- `QLPreviewReply(dataOfContentType:contentSize:dataCreationBlock:)` is the correct initializer
- Code block renderer matches `web/src/lib/markdown.ts:7-14` (minus copy button)
- Image regex matches `web/src/lib/markdown.ts:28`
- Font file list matches `Sources/mdreader/Resources/Fonts/` directory contents
- Bundle path resolution uses `Bundle(for:)` which returns the `.appex` bundle, not the host app bundle

- [ ] **Step 3: Commit**

```bash
git add Sources/mdreader-quicklook/PreviewProvider.swift
git commit -m "feat(quicklook): add Quick Look preview extension provider"
```

---

## Task 3: Update build.sh

**Files:**
- Modify: `build.sh:146` (replace existing codesign line and add QL build before it)

The extension is compiled with `swiftc` and assembled into a `.appex` bundle. Code signing order: extension first, then main app (inner-to-outer).

- [ ] **Step 1: Replace codesign block with QL build + signing**

In `build.sh`, remove line 146:
```bash
# Ad-hoc codesign
codesign --force --sign - --deep "$BUNDLE"
```

Replace with the Quick Look extension build block:

1. Set variables: `QL_APPEX="QuickLookPreview.appex"`, `QL_SRC="Sources/mdreader-quicklook/PreviewProvider.swift"`, `QL_MODULE="QuickLookPreview"`, paths for extension and shared resources
2. Compile with `swiftc`:
   - `-sdk "$(xcrun --show-sdk-path)"`
   - `-target "$(uname -m)-apple-macos15.0"`
   - `-framework Foundation -framework Quartz`
   - `-module-name "$QL_MODULE"`
   - `-Xlinker -e -Xlinker _NSExtensionMain`
   - `-o "$QL_MODULE"`
   - `"$QL_SRC"`
3. Create `.appex` directory structure: `Contents/MacOS/`, `Contents/Resources/Fonts/`
4. Move compiled binary to `$QL_APPEX/Contents/MacOS/`
5. Copy resources: `marked.min.js`, `highlight.min.js` from `Sources/mdreader/Resources/`, `quicklook.css` from `Sources/mdreader-quicklook/Resources/`, all fonts from `Sources/mdreader/Resources/Fonts/`
6. Generate `Info.plist` with heredoc containing:
   - `CFBundleIdentifier: com.rvanbaalen.mdreader.quicklook`
   - `CFBundleExecutable: QuickLookPreview`
   - `CFBundlePackageType: XPC!`
   - `NSExtension` dict with `NSExtensionPointIdentifier: com.apple.quicklook.preview` and `NSExtensionPrincipalClass: QuickLookPreview.PreviewProvider`
   - `QLSupportedContentTypes: [net.daringfireball.markdown]`
   - Version strings using `$VERSION` and `$BUILD_NUMBER` (same as main app)
7. Create `$BUNDLE/Contents/PlugIns/` and copy `.appex` into it
8. Clean up temp `.appex`
9. Code sign: `codesign --force --sign - "$BUNDLE/Contents/PlugIns/$QL_APPEX"` then `codesign --force --sign - "$BUNDLE"` (no `--deep` — explicit inner-to-outer)

- [ ] **Step 2: Verify build.sh syntax**

```bash
bash -n build.sh
```

Expected: no output (no syntax errors).

- [ ] **Step 3: Commit**

```bash
git add build.sh
git commit -m "feat(quicklook): add Quick Look extension to build pipeline"
```

---

## Task 4: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (insert after `## Build` section, before `## Release`)

- [ ] **Step 1: Add Quick Look section**

Insert after the build commands code block:

```markdown
## Quick Look Extension

The app includes a Quick Look Preview Extension (`.appex`) that renders `.md` files when pressing Space in Finder.

- Source: `Sources/mdreader-quicklook/PreviewProvider.swift`
- Styles: `Sources/mdreader-quicklook/Resources/quicklook.css`
- Built and embedded automatically by `build.sh`

**Testing Quick Look changes:**
\`\`\`bash
rm -rf .build/release mdreader.app && ./build.sh   # full rebuild
qlmanage -r                                         # reset Quick Look cache
qlmanage -p path/to/test.md                         # preview via CLI (or press Space in Finder)
\`\`\`

The extension shares JS libraries and fonts with the main app (from `Sources/mdreader/Resources/`). CSS is standalone in `quicklook.css` — if you change content styles in `web/src/content.css`, update `quicklook.css` to match.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add Quick Look extension workflow to CLAUDE.md"
```

---

## Task 5: Build and Verify

No new files — validates the full build pipeline and Quick Look functionality.

- [ ] **Step 1: Clean build**

```bash
rm -rf .build/release mdreader.app && ./build.sh
```

Expected: build completes with "Building Quick Look extension..." in output, no errors.

- [ ] **Step 2: Verify .appex contents**

```bash
ls -la mdreader.app/Contents/PlugIns/QuickLookPreview.appex/Contents/MacOS/
ls -la mdreader.app/Contents/PlugIns/QuickLookPreview.appex/Contents/Resources/
ls -la mdreader.app/Contents/PlugIns/QuickLookPreview.appex/Contents/Resources/Fonts/
```

Expected: binary exists, Resources contain `marked.min.js`, `highlight.min.js`, `quicklook.css`, and `Fonts/` with 6 font files.

- [ ] **Step 3: Verify code signing**

```bash
codesign -dvv mdreader.app/Contents/PlugIns/QuickLookPreview.appex
```

Expected: signing info without errors.

- [ ] **Step 4: Reset Quick Look cache and test**

```bash
qlmanage -r
qlmanage -p README.md
```

Expected: a Quick Look preview window opens showing README.md rendered with mdreader typography (Lora serif headings, styled code blocks, theme colors).

If `qlmanage -p` shows plain text instead of rendered markdown:
1. Open `mdreader.app` once: `open mdreader.app` — registers the extension with the system
2. Run `qlmanage -r` again
3. Retry `qlmanage -p README.md`
4. Check registration: `pluginkit -m -p com.apple.quicklook.preview | grep mdreader`
5. Force register if needed: `pluginkit -a mdreader.app/Contents/PlugIns/QuickLookPreview.appex`

- [ ] **Step 5: Test system theme**

Toggle macOS appearance (System Settings > Appearance > Light/Dark) and preview a `.md` file. Verify the preview follows system theme.

- [ ] **Step 6: Test with images**

Find or create a `.md` file referencing local images with relative paths. Verify images render in the Quick Look preview.

- [ ] **Step 7: Commit any fixes**

If fixes were needed during testing, commit them with descriptive messages.

---

## Troubleshooting

### `_NSExtensionMain` linker error

If `swiftc` fails with an undefined symbol for `_NSExtensionMain`:

1. Try adding `-framework ExtensionFoundation`
2. If that fails, fall back to a minimal Xcode project:
   - Create `QuickLookPreview.xcodeproj` with a Quick Look Preview Extension target
   - Build: `xcodebuild -project QuickLookPreview.xcodeproj -scheme QuickLookPreview -configuration Release`
   - Copy built `.appex` into `mdreader.app/Contents/PlugIns/` in `build.sh`

### Extension not recognized by Quick Look

1. Ensure `mdreader.app` has been opened at least once
2. List registered QL extensions: `pluginkit -m -p com.apple.quicklook.preview`
3. Force register: `pluginkit -a mdreader.app/Contents/PlugIns/QuickLookPreview.appex`
4. Reset: `qlmanage -r`

### HTML renders as plain text in Quick Look

Quick Look's WebKit should execute JavaScript. If it doesn't, switch to server-side rendering: use JavaScriptCore in Swift to run `marked.parse()` and return static HTML. See the design spec's Approach 2 for details.

---

## Follow-up (separate repo)

The spec requires updating the Homebrew formula at `rvanbaalen/homebrew-tap` to auto-install `mdreader.app` to `/Applications/` in `post_install`. This ensures macOS discovers the Quick Look extension without manual steps. This work is outside the scope of this repo and should be done after the extension is merged and released.
