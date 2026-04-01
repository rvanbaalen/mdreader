import SwiftUI
import WebKit

struct ReaderWebView: NSViewRepresentable {
    let markdown: String
    let theme: String
    let onHeadings: ([HeadingItem]) -> Void
    let onScroll: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "headings")
        config.userContentController.add(context.coordinator, name: "scroll")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        context.coordinator.webView = webView

        // Load the HTML with inlined CSS and JS
        let html = buildHTML()
        let resourceURL = Bundle.module.bundleURL.appendingPathComponent("Resources")
        webView.loadHTMLString(html, baseURL: resourceURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        // Wait for page to be ready, then render
        if context.coordinator.isReady {
            webView.evaluateJavaScript("renderMarkdown(`\(escaped)`)")
            webView.evaluateJavaScript("setTheme('\(theme)')")
        } else {
            context.coordinator.pendingMarkdown = escaped
            context.coordinator.pendingTheme = theme
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onHeadings: onHeadings, onScroll: onScroll)
    }

    private func buildHTML() -> String {
        var html = loadResource("reader.html")
        html = html.replacingOccurrences(of: "STYLE_PLACEHOLDER", with: loadResource("style.css"))
        html = html.replacingOccurrences(of: "MARKED_PLACEHOLDER", with: loadResource("marked.min.js"))
        html = html.replacingOccurrences(of: "HLJS_PLACEHOLDER", with: loadResource("highlight.min.js"))
        html = html.replacingOccurrences(of: "PURIFY_PLACEHOLDER", with: loadResource("purify.min.js"))
        return html
    }

    private func loadResource(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources") ??
              Bundle.module.url(forResource: name, withExtension: nil) else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onHeadings: ([HeadingItem]) -> Void
        let onScroll: (String) -> Void
        var webView: WKWebView?
        var isReady = false
        var pendingMarkdown: String?
        var pendingTheme: String?

        init(onHeadings: @escaping ([HeadingItem]) -> Void, onScroll: @escaping (String) -> Void) {
            self.onHeadings = onHeadings
            self.onScroll = onScroll
            super.init()
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "headings", let json = message.body as? String,
               let data = json.data(using: .utf8),
               let items = try? JSONDecoder().decode([HeadingItem].self, from: data) {
                DispatchQueue.main.async { self.onHeadings(items) }
            } else if message.name == "scroll", let id = message.body as? String {
                DispatchQueue.main.async { self.onScroll(id) }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            if let md = pendingMarkdown {
                webView.evaluateJavaScript("renderMarkdown(`\(md)`)")
                pendingMarkdown = nil
            }
            if let theme = pendingTheme {
                webView.evaluateJavaScript("setTheme('\(theme)')")
                pendingTheme = nil
            }
        }
    }
}
