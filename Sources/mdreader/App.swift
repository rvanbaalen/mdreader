import AppKit
import WebKit
import UniformTypeIdentifiers
import CoreServices

@main
struct MDReaderEntry {
    static func main() {
        _ = ResourceLoader.fontsRegistered
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var currentFile: URL?
    var currentFolder: URL?
    var watcher: DispatchSourceFileSystemObject?
    var webReady = false
    var pendingFile: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = ResourceLoader.url(forResource: "icon.icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }

        // Borderless window — just a rectangle
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1060, height: 720),
            styleMask: [.borderless, .resizable, .miniaturizable, .closable],
            backing: .buffered, defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        window.isMovableByWindowBackground = false

        // Rounded corners on the content view
        window.contentView!.wantsLayer = true
        window.contentView!.layer?.cornerRadius = 10
        window.contentView!.layer?.masksToBounds = true
        window.contentView!.layer?.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1).cgColor

        // WKWebView fills the entire window
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "app")
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        // Enable native momentum scrolling
        webView.enclosingScrollView?.scrollerStyle = .overlay
        webView.enclosingScrollView?.hasVerticalScroller = true
        webView.enclosingScrollView?.verticalScrollElasticity = .allowed
        window.contentView!.addSubview(webView)

        // Load UI
        let html = buildHTML()
        let bundleParent = ResourceLoader.bundle.bundleURL.deletingLastPathComponent()
        let tempHTML = bundleParent.appendingPathComponent("mdreader_ui.html")
        try? html.data(using: .utf8)?.write(to: tempHTML)
        webView.loadFileURL(tempHTML, allowingReadAccessTo: bundleParent)

        window.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate()

        if CommandLine.arguments.count > 1 {
            pendingFile = URL(fileURLWithPath: CommandLine.arguments[1])
        }
        setupMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if webReady { openFile(url) } else { pendingFile = url }
    }

    // MARK: - File ops

    func openFile(_ url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        currentFile = url
        webView.evaluateJavaScript("app.openFile(`\(content.jsEscaped())`, '\(url.lastPathComponent.jsEscaped())', '\((currentFolder?.lastPathComponent ?? "").jsEscaped())')")
        watchFile(url)
    }

    func openFolder(_ url: URL) {
        currentFolder = url
        let tree = scanFolder(url)
        let json = (try? JSONSerialization.data(withJSONObject: tree)) ?? Data()
        webView.evaluateJavaScript("app.openFolder('\(url.lastPathComponent.jsEscaped())', \(String(data: json, encoding: .utf8) ?? "[]"))")
        if let first = findFirstMd(tree) { openFile(URL(fileURLWithPath: first)) }
    }

    func scanFolder(_ dir: URL) -> [[String: Any]] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        return items.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { item -> [String: Any]? in
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                let children = scanFolder(item)
                return children.isEmpty ? nil : ["name": item.lastPathComponent, "path": item.path, "isDir": true, "children": children]
            } else if ["md", "markdown"].contains(item.pathExtension.lowercased()) {
                return ["name": item.lastPathComponent, "path": item.path, "isDir": false]
            }
            return nil
        }
    }

    func findFirstMd(_ nodes: [[String: Any]]) -> String? {
        if let r = nodes.first(where: { ($0["name"] as? String)?.lowercased() == "readme.md" && $0["isDir"] as? Bool != true }) { return r["path"] as? String }
        if let f = nodes.first(where: { $0["isDir"] as? Bool != true }) { return f["path"] as? String }
        for n in nodes { if let c = n["children"] as? [[String: Any]], let f = findFirstMd(c) { return f } }
        return nil
    }

    func watchFile(_ url: URL) {
        watcher?.cancel()
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        src.setEventHandler { [weak self] in
            guard let self, let c = try? String(contentsOf: url, encoding: .utf8) else { return }
            self.webView.evaluateJavaScript("app.updateContent(`\(c.jsEscaped())`)")
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        watcher = src
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
        switch action {
        case "openFile":
            let panel = NSOpenPanel()
            panel.allowsOtherFileTypes = true
            panel.allowedContentTypes = [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown"), .plainText].compactMap { $0 }
            if panel.runModal() == .OK, let url = panel.url { openFile(url) }
        case "openFolder":
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true; panel.canChooseFiles = false
            if panel.runModal() == .OK, let url = panel.url { openFolder(url) }
        case "openFilePath":
            if let p = body["path"] as? String { openFile(URL(fileURLWithPath: p)) }
        case "setTheme":
            if let m = body["mode"] as? String { UserDefaults.standard.set(m, forKey: "themeMode") }
        case "startDrag":
            // JS detected mousedown on the titlebar area — start native window drag
            if let event = NSApplication.shared.currentEvent {
                window.performDrag(with: event)
            }
        case "minimize":
            window.miniaturize(nil)
        case "close":
            window.close()
        case "zoom":
            window.zoom(nil)
        case "setDefaultApp":
            UserDefaults.standard.set(true, forKey: "defaultAppAsked")
            setAsDefaultApp()
        case "dismissDefaultBanner":
            UserDefaults.standard.set(true, forKey: "defaultAppAsked")
        case "ready":
            webReady = true
            let stored = UserDefaults.standard.string(forKey: "themeMode")
            let theme: String
            if let stored { theme = stored }
            else {
                let isDark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                theme = isDark ? "dark" : "light"
            }
            webView.evaluateJavaScript("app.setTheme('\(theme)')")
            // Check default app (only once)
            if !UserDefaults.standard.bool(forKey: "defaultAppAsked") {
                checkDefaultApp()
            }
            if let url = pendingFile {
                pendingFile = nil
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue { openFolder(url) } else { openFile(url) }
                }
            }
        default: break
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            // Allow file:// and about: (our local UI), block everything else → open in browser
            if url.scheme == "file" || url.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func setAsDefaultApp() {
        let appURL = Bundle.main.bundleURL
        // Register with LaunchServices first
        LSRegisterURL(appURL as CFURL, true)

        guard let mdType = UTType(filenameExtension: "md") else { return }
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: mdType) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    let alert = NSAlert()
                    alert.messageText = "Couldn't set default"
                    alert.informativeText = "To set manually:\n1. Right-click any .md file in Finder\n2. Click \"Get Info\"\n3. Under \"Open with\", select mdreader\n4. Click \"Change All...\"\n\n(\(error.localizedDescription))"
                    alert.alertStyle = .informational
                    alert.runModal()
                } else {
                    // Also set for .markdown extension
                    if let markdownType = UTType(filenameExtension: "markdown") {
                        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: markdownType) { _ in }
                    }
                    self?.webView.evaluateJavaScript("app.showToast('mdreader is now your default markdown reader')")
                }
            }
        }
    }

    func checkDefaultApp() {
        guard let mdUTI = UTType(filenameExtension: "md") else { return }
        if let handler = LSCopyDefaultRoleHandlerForContentType(mdUTI.identifier as CFString, .viewer)?.takeRetainedValue() as String? {
            if handler.lowercased() != "com.rvanbaalen.mdreader" {
                webView.evaluateJavaScript("app.showDefaultBanner()")
            }
        } else {
            webView.evaluateJavaScript("app.showDefaultBanner()")
        }
    }

    func buildHTML() -> String {
        var html = ResourceLoader.string(forResource: "app.html")
        let css = ResourceLoader.string(forResource: "style.css")
        let fontsDir = ResourceLoader.resourcesDirectory.appendingPathComponent("Fonts")
        html = html.replacingOccurrences(of: "/*STYLE*/", with: css.replacingOccurrences(of: "url('Fonts/", with: "url('\(fontsDir.absoluteString)/"))
        html = html.replacingOccurrences(of: "/*MARKED*/", with: ResourceLoader.string(forResource: "marked.min.js"))
        html = html.replacingOccurrences(of: "/*HLJS*/", with: ResourceLoader.string(forResource: "highlight.min.js"))
        html = html.replacingOccurrences(of: "/*PURIFY*/", with: ResourceLoader.string(forResource: "purify.min.js"))
        return html
    }

    // MARK: - Menu

    func setupMenu() {
        let menu = NSMenu()
        let appMenu = NSMenuItem(); let appSub = NSMenu()
        appSub.addItem(withTitle: "About mdreader", action: #selector(showAbout), keyEquivalent: "")
        let defaultItem = NSMenuItem(title: "Set as Default Reader...", action: #selector(menuSetDefault), keyEquivalent: "")
        defaultItem.target = self; appSub.addItem(defaultItem)
        appSub.addItem(.separator())
        appSub.addItem(withTitle: "Quit mdreader", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.submenu = appSub; menu.addItem(appMenu)

        let fileMenu = NSMenuItem(); let fileSub = NSMenu(title: "File")
        let openFileItem = NSMenuItem(title: "Open File...", action: #selector(menuOpenFile), keyEquivalent: "o")
        openFileItem.target = self; fileSub.addItem(openFileItem)
        let openFolderItem = NSMenuItem(title: "Open Folder...", action: #selector(menuOpenFolder), keyEquivalent: "O")
        openFolderItem.target = self; fileSub.addItem(openFolderItem)
        fileMenu.submenu = fileSub; menu.addItem(fileMenu)

        let viewMenu = NSMenuItem(); let viewSub = NSMenu(title: "View")
        let sidebarItem = NSMenuItem(title: "Toggle Sidebar", action: #selector(menuToggleSidebar), keyEquivalent: "\\")
        sidebarItem.target = self; viewSub.addItem(sidebarItem)
        let tocItem = NSMenuItem(title: "Toggle Table of Contents", action: #selector(menuToggleToc), keyEquivalent: "e")
        tocItem.keyEquivalentModifierMask = [.command, .shift]; tocItem.target = self; viewSub.addItem(tocItem)
        let themeItem = NSMenuItem(title: "Toggle Theme", action: #selector(menuToggleTheme), keyEquivalent: "t")
        themeItem.keyEquivalentModifierMask = [.command, .shift]; themeItem.target = self; viewSub.addItem(themeItem)
        viewMenu.submenu = viewSub; menu.addItem(viewMenu)

        let editMenu = NSMenuItem(); let editSub = NSMenu(title: "Edit")
        editSub.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editSub.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.submenu = editSub; menu.addItem(editMenu)

        NSApplication.shared.mainMenu = menu
    }

    @objc func menuOpenFile() {
        let panel = NSOpenPanel()
        panel.allowsOtherFileTypes = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown"), .plainText].compactMap { $0 }
        if panel.runModal() == .OK, let url = panel.url { openFile(url) }
    }
    @objc func menuOpenFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url { openFolder(url) }
    }
    @objc func menuSetDefault() { setAsDefaultApp() }
    @objc func menuToggleSidebar() { webView.evaluateJavaScript("app.toggleSidebar()") }
    @objc func menuToggleToc() { webView.evaluateJavaScript("app.toggleToc()") }
    @objc func menuToggleTheme() { webView.evaluateJavaScript("app.cycleTheme()") }

    @objc func showAbout() {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let c = ResourceLoader.string(forResource: "build-info.txt").trimmingCharacters(in: .whitespacesAndNewlines)
        let alert = NSAlert()
        alert.messageText = "mdreader"
        alert.informativeText = "v\(v)\(c.isEmpty ? "" : " (\(c))")\(b.isEmpty ? "" : " #\(b)")\n\nA beautiful macOS markdown reader\nrobinvanbaalen.nl/projects/mdreader"
        alert.alertStyle = .informational
        if let icon = NSApplication.shared.applicationIconImage { alert.icon = icon }
        alert.runModal()
    }
}

extension String {
    func jsEscaped() -> String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
