import Foundation
import Quartz
import UniformTypeIdentifiers

class PreviewProvider: QLPreviewProvider {

    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, (any Error)?) -> Void) {
        let fileURL = request.fileURL
        guard let markdown = try? String(contentsOf: fileURL, encoding: .utf8) else {
            handler(nil, NSError(domain: "com.rvanbaalen.mdreader.quicklook", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read file"]))
            return
        }
        let baseDir = fileURL.deletingLastPathComponent()
        let resolved = resolveImages(in: markdown, relativeTo: baseDir)
        let html = buildHTML(markdown: resolved)

        let reply = QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 800, height: 600)
        ) { _ in
            Data(html.utf8)
        }
        handler(reply, nil)
    }

    // MARK: - Image Resolution

    /// Scans markdown for relative image references and replaces them with base64 data URIs.
    /// Based on the regex pattern from web/src/lib/markdown.ts:28, excluding the mdfile://
    /// lookahead which is app-specific and not relevant in the Quick Look context.
    private func resolveImages(in markdown: String, relativeTo baseDir: URL) -> String {
        let pattern = #"!\[([^\]]*)\]\((?!https?://|data:)([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return markdown
        }

        let nsMarkdown = markdown as NSString
        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length))

        // Process in reverse so replacement ranges stay valid
        var result = markdown
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let altRange = match.range(at: 1)
            let pathRange = match.range(at: 2)
            guard let swiftAltRange = Range(altRange, in: result),
                  let swiftPathRange = Range(pathRange, in: result),
                  let swiftFullRange = Range(match.range, in: result) else { continue }

            let alt = String(result[swiftAltRange])
            let relativePath = String(result[swiftPathRange])

            let imageURL = baseDir.appendingPathComponent(relativePath)
            guard let imageData = try? Data(contentsOf: imageURL) else { continue }

            let mime = mimeType(for: imageURL.pathExtension)
            let base64 = imageData.base64EncodedString()
            let dataURI = "data:\(mime);base64,\(base64)"

            result.replaceSubrange(swiftFullRange, with: "![\(alt)](\(dataURI))")
        }

        return result
    }

    // MARK: - MIME Type

    /// Maps file extensions to MIME types. Same mapping as LocalFileHandler in App.swift.
    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "ico": return "image/x-icon"
        default: return "application/octet-stream"
        }
    }

    // MARK: - HTML Builder

    /// Assembles a self-contained HTML document with inline CSS, fonts, and JS.
    /// Uses innerHTML to render the user's own local markdown file (no sanitization
    /// needed per design spec — this is local file preview, not untrusted input).
    private func buildHTML(markdown: String) -> String {
        let bundle = Bundle(for: PreviewProvider.self)
        let resourcesURL = bundle.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")

        // Load JS libraries
        let markedJS = (try? String(contentsOf: resourcesURL.appendingPathComponent("marked.min.js"), encoding: .utf8)) ?? ""
        let highlightJS = (try? String(contentsOf: resourcesURL.appendingPathComponent("highlight.min.js"), encoding: .utf8)) ?? ""

        // Load and patch CSS with embedded fonts
        var css = (try? String(contentsOf: resourcesURL.appendingPathComponent("quicklook.css"), encoding: .utf8)) ?? ""
        let fontFaceCSS = buildFontFaceCSS(from: resourcesURL.appendingPathComponent("Fonts"))
        css = css.replacingOccurrences(of: "/* QUICKLOOK_FONT_FACE_DECLARATIONS */", with: fontFaceCSS)

        // Fallback: if critical JS is missing, show raw markdown as plain text
        guard !markedJS.isEmpty else {
            let escaped = markdown
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
            return """
            <!DOCTYPE html>
            <html><body>
            <pre style="white-space:pre-wrap;font-family:monospace;padding:24px">\(escaped)</pre>
            </body></html>
            """
        }

        // Escape markdown for safe JS embedding
        let escapedMarkdown = escapeForJS(markdown)

        // Note: innerHTML is intentional — we render the user's own local file,
        // not untrusted input. No DOMPurify needed (see design spec).
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style>
        </head>
        <body>
        <article class="content" id="content"></article>
        <script>\(markedJS)</script>
        <script>\(highlightJS)</script>
        <script>
        (function() {
            var renderer = new marked.Renderer();
            renderer.code = function(args) {
                var text = args.text;
                var lang = args.lang;
                var highlighted = lang && hljs.getLanguage(lang)
                    ? hljs.highlight(text, { language: lang }).value
                    : hljs.highlightAuto(text).value;
                var langAttr = lang ? ' data-lang="' + lang + '"' : '';
                return '<pre' + langAttr + '><code class="hljs">' + highlighted + '</code></pre>';
            };
            marked.use({ renderer: renderer, gfm: true, breaks: false });
            var md = \(escapedMarkdown);
            document.getElementById('content').innerHTML = marked.parse(md);
        })();
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Font Embedding

    /// Generates base64 @font-face CSS declarations for all bundled fonts.
    private func buildFontFaceCSS(from fontsDir: URL) -> String {
        struct FontSpec {
            let filename: String
            let family: String
            let weight: String
            let style: String
            let format: String
        }

        let fonts: [FontSpec] = [
            FontSpec(filename: "Lora-Regular.otf", family: "Lora", weight: "400", style: "normal", format: "opentype"),
            FontSpec(filename: "Lora-Bold.otf", family: "Lora", weight: "700", style: "normal", format: "opentype"),
            FontSpec(filename: "Lora-Italic.otf", family: "Lora", weight: "400", style: "italic", format: "opentype"),
            FontSpec(filename: "Lora-BoldItalic.otf", family: "Lora", weight: "700", style: "italic", format: "opentype"),
            FontSpec(filename: "DMSans-Variable.ttf", family: "DM Sans", weight: "100 1000", style: "normal", format: "truetype"),
            FontSpec(filename: "IBMPlexMono-Regular.otf", family: "IBM Plex Mono", weight: "400", style: "normal", format: "opentype"),
        ]

        var declarations: [String] = []
        for font in fonts {
            let fileURL = fontsDir.appendingPathComponent(font.filename)
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            let base64 = data.base64EncodedString()
            let mime = font.filename.hasSuffix(".ttf") ? "font/ttf" : "font/otf"

            declarations.append("""
            @font-face {
              font-family: '\(font.family)';
              src: url('data:\(mime);base64,\(base64)') format('\(font.format)');
              font-weight: \(font.weight);
              font-style: \(font.style);
            }
            """)
        }

        return declarations.joined(separator: "\n")
    }

    // MARK: - JS Escaping

    /// Produces a JSON-encoded string literal safe for embedding in JavaScript.
    private func escapeForJS(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: string,
            options: .fragmentsAllowed
        ) else {
            return "\"\""
        }
        return String(data: data, encoding: .utf8) ?? "\"\""
    }
}
