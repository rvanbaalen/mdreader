import AppKit
import Quartz
import CoreText
import JavaScriptCore

class PreviewViewController: NSViewController, QLPreviewingController {

    private let textView = NSTextView()
    private let scrollView = NSScrollView()

    private let bgColor = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)

    override func loadView() {
        registerFonts()

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = bgColor

        textView.isEditable = false
        textView.isSelectable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 40, height: 40)
        textView.backgroundColor = bgColor
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true

        self.view = scrollView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        guard let markdown = try? String(contentsOf: url, encoding: .utf8) else {
            handler(NSError(domain: "nl.robinvanbaalen.mdreader.quicklook", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "Could not read file"]))
            return
        }

        // Render markdown → HTML via JavaScriptCore + marked.js
        let html = renderMarkdownToHTML(markdown)

        // Wrap in full document with inline CSS
        let css = loadCSS()
        let document = """
        <html>
        <head><meta charset="utf-8"><style>\(css)</style></head>
        <body><article class="content">\(html)</article></body>
        </html>
        """

        // Convert HTML → NSAttributedString for display
        if let data = document.data(using: .utf8),
           let attributed = NSAttributedString(html: data, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            // Fallback: plain text
            textView.string = markdown
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.textColor = NSColor(red: 0.88, green: 0.88, blue: 0.9, alpha: 1)
        }

        handler(nil)
    }

    // MARK: - Font Registration

    private func registerFonts() {
        let bundle = Bundle(for: PreviewViewController.self)
        let fontsURL = bundle.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Fonts")

        for file in ["Lora-Regular.otf", "Lora-Bold.otf", "Lora-Italic.otf",
                      "Lora-BoldItalic.otf", "IBMPlexMono-Regular.otf", "DMSans-Variable.ttf"] {
            let url = fontsURL.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: url.path) {
                var err: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err)
            }
        }
    }

    // MARK: - Markdown → HTML via JavaScriptCore

    private func renderMarkdownToHTML(_ markdown: String) -> String {
        let bundle = Bundle(for: PreviewViewController.self)
        let resourcesURL = bundle.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")

        // Load marked.js
        let markedURL = resourcesURL.appendingPathComponent("marked.min.js")
        guard let markedJS = try? String(contentsOf: markedURL, encoding: .utf8) else {
            // Fallback: return escaped plain text
            return markdown
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: "\n", with: "<br>")
        }

        let ctx = JSContext()!
        ctx.evaluateScript(markedJS)
        ctx.evaluateScript("marked.use({ gfm: true, breaks: false });")

        // Escape markdown for JS embedding
        guard let jsonData = try? JSONSerialization.data(withJSONObject: markdown, options: .fragmentsAllowed),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return markdown
        }

        let result = ctx.evaluateScript("marked.parse(\(jsonString))")
        return result?.toString() ?? markdown
    }

    // MARK: - CSS

    private func loadCSS() -> String {
        let bundle = Bundle(for: PreviewViewController.self)
        let cssURL = bundle.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("quicklook.css")

        guard let css = try? String(contentsOf: cssURL, encoding: .utf8) else {
            return ""
        }

        // NSAttributedString(html:) doesn't support CSS custom properties or oklch().
        // Resolve all var() references and oklch() values to concrete hex colors.
        return resolveCSS(css)
    }

    /// Resolves CSS custom properties (var(--xxx)) and oklch() values to concrete values
    /// that NSAttributedString(html:) can understand.
    private func resolveCSS(_ css: String) -> String {
        // Extract variable definitions from :root block
        var variables: [String: String] = [:]
        let varDefPattern = #"--([\w-]+)\s*:\s*([^;]+)"#
        if let regex = try? NSRegularExpression(pattern: varDefPattern) {
            let matches = regex.matches(in: css, range: NSRange(location: 0, length: (css as NSString).length))
            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: css),
                   let valueRange = Range(match.range(at: 2), in: css) {
                    let name = "--" + String(css[nameRange])
                    let value = String(css[valueRange]).trimmingCharacters(in: .whitespaces)
                    variables[name] = value
                }
            }
        }

        // Replace var(--xxx) references with their values
        var resolved = css
        let varRefPattern = #"var\((--[\w-]+)\)"#
        if let regex = try? NSRegularExpression(pattern: varRefPattern) {
            // Iterate until no more var() references (handles nested vars)
            for _ in 0..<3 {
                let matches = regex.matches(in: resolved, range: NSRange(location: 0, length: (resolved as NSString).length))
                if matches.isEmpty { break }
                for match in matches.reversed() {
                    if let nameRange = Range(match.range(at: 1), in: resolved),
                       let fullRange = Range(match.range, in: resolved) {
                        let varName = String(resolved[nameRange])
                        if let value = variables[varName] {
                            resolved.replaceSubrange(fullRange, with: value)
                        }
                    }
                }
            }
        }

        // Convert oklch() to hex — NSAttributedString doesn't support oklch
        resolved = convertOklchToHex(in: resolved)

        // Remove :root and @media blocks that only define variables
        // (they're now inlined, and NSAttributedString doesn't understand them)
        resolved = removeVariableBlocks(resolved)

        return resolved
    }

    /// Converts oklch(L% C H) and oklch(L% C H / A) values to hex colors.
    private func convertOklchToHex(in css: String) -> String {
        let pattern = #"oklch\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return css }

        var result = css
        let matches = regex.matches(in: css, range: NSRange(location: 0, length: (css as NSString).length))

        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let argsRange = Range(match.range(at: 1), in: result) else { continue }

            let args = String(result[argsRange])
            if let hex = oklchToHex(args) {
                result.replaceSubrange(fullRange, with: hex)
            }
        }
        return result
    }

    /// Parse "L% C H" or "L% C H / A" and convert to hex.
    private func oklchToHex(_ args: String) -> String? {
        // Split on "/" for alpha
        let parts = args.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        let lchParts = parts[0].split(whereSeparator: { $0.isWhitespace || $0 == "%" })
            .map { String($0) }

        guard lchParts.count >= 3,
              let l = Double(lchParts[0].replacingOccurrences(of: "%", with: "")),
              let c = Double(lchParts[1]),
              let h = Double(lchParts[2]) else { return nil }

        let alpha = parts.count > 1 ? Double(parts[1]) ?? 1.0 : 1.0

        // OKLCh → sRGB conversion
        let L = l / 100.0
        let a_ = c * cos(h * .pi / 180.0)
        let b_ = c * sin(h * .pi / 180.0)

        // OKLab → linear sRGB
        let l_ = L + 0.3963377774 * a_ + 0.2158037573 * b_
        let m_ = L - 0.1055613458 * a_ - 0.0638541728 * b_
        let s_ = L - 0.0894841775 * a_ - 1.2914855480 * b_

        let l3 = l_ * l_ * l_
        let m3 = m_ * m_ * m_
        let s3 = s_ * s_ * s_

        let r_lin = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        let g_lin = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        let b_lin = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3

        func gammaCorrect(_ x: Double) -> Double {
            x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1.0 / 2.4) - 0.055
        }

        let r = Int(max(0, min(255, round(gammaCorrect(r_lin) * 255))))
        let g = Int(max(0, min(255, round(gammaCorrect(g_lin) * 255))))
        let b = Int(max(0, min(255, round(gammaCorrect(b_lin) * 255))))

        if alpha < 1.0 {
            let a = Int(max(0, min(255, round(alpha * 255))))
            return String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, alpha)
        }
        return String(format: "#%02x%02x%02x", r, g, b)
    }

    /// Remove :root {} and @media blocks that only contain variable definitions.
    private func removeVariableBlocks(_ css: String) -> String {
        var result = css
        // Remove :root { ... } blocks
        let rootPattern = #":root\s*\{[^}]*\}"#
        if let regex = try? NSRegularExpression(pattern: rootPattern, options: .dotMatchesLineSeparators) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "")
        }
        return result
    }
}
