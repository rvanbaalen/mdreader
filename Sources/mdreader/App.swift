import AppKit
import WebKit
import UniformTypeIdentifiers
import CoreServices

@main
struct MDReaderEntry {
    static func main() {
        // If launched from a terminal, detach and re-launch as a GUI process
        if isatty(STDIN_FILENO) == 1, ProcessInfo.processInfo.environment["MDREADER_LAUNCHED"] == nil {
            var args = CommandLine.arguments
            let execPath = args.removeFirst()
            var env = ProcessInfo.processInfo.environment
            env["MDREADER_LAUNCHED"] = "1"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = args
            process.environment = env
            // Detach from terminal
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            // Parent exits immediately, returning the terminal
            exit(0)
        }

        _ = ResourceLoader.fontsRegistered
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

// MARK: - WindowController (per-window state)

class WindowController: NSObject, WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var currentFile: URL?
    var currentFolder: URL?
    var watcher: DispatchSourceFileSystemObject?
    var webReady = false
    var pendingFile: URL?

    func setup() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1060, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.delegate = self
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 600, height: 400)
        window.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "app")
        config.setURLSchemeHandler(LocalFileHandler(), forURLScheme: "mdfile")

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        window.contentView!.addSubview(webView)

        let fileRoot = URL(fileURLWithPath: "/")
        if ProcessInfo.processInfo.environment["MDREADER_DEV"] == "1" {
            webView.load(URLRequest(url: URL(string: "http://localhost:5173")!))
        } else if let distIndex = ResourceLoader.url(forResource: "dist/index.html") {
            webView.loadFileURL(distIndex, allowingReadAccessTo: fileRoot)
        } else {
            let html = buildHTML()
            let bundleParent = ResourceLoader.bundle.bundleURL.deletingLastPathComponent()
            let tempHTML = bundleParent.appendingPathComponent("mdreader_ui.html")
            try? html.data(using: .utf8)?.write(to: tempHTML)
            webView.loadFileURL(tempHTML, allowingReadAccessTo: fileRoot)
        }
    }

    // MARK: - File ops

    func openFile(_ url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        currentFile = url
        let dirPath = url.deletingLastPathComponent().path
        webView.evaluateJavaScript("app.openFile(`\(content.jsEscaped())`, '\(url.lastPathComponent.jsEscaped())', '\((currentFolder?.lastPathComponent ?? "").jsEscaped())', '\(dirPath.jsEscaped())')")
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
            if let event = NSApplication.shared.currentEvent {
                window.performDrag(with: event)
            }
        case "setDefaultApp":
            UserDefaults.standard.set(true, forKey: "defaultAppAsked")
            AppDelegate.shared.setAsDefaultApp(from: self)
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
            let scheme = url.scheme ?? ""
            let host = url.host ?? ""
            if scheme == "file" || scheme == "about" || scheme == "ws" || scheme == "wss"
                || host == "localhost" || host == "127.0.0.1" {
                decisionHandler(.allow)
                return
            }
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
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

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        watcher?.cancel()
        DispatchQueue.main.async { [self] in
            AppDelegate.shared.windowDidClose(self)
        }
    }
}

// MARK: - AppDelegate (window manager)

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    var windowControllers: [WindowController] = []
    private var cascadePoint = NSPoint.zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        if let url = ResourceLoader.url(forResource: "icon.icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }

        setupMenu()

        let wc = createWindow(center: true)
        if CommandLine.arguments.count > 1 {
            wc.pendingFile = URL(fileURLWithPath: CommandLine.arguments[1])
        }
        NSRunningApplication.current.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { createWindow(center: true) }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            // Reuse an empty window if one exists
            if let wc = windowControllers.first(where: { $0.currentFile == nil && $0.webReady }) {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue { wc.openFolder(url) } else { wc.openFile(url) }
                }
            } else {
                let wc = createWindow()
                wc.pendingFile = url
            }
        }
    }

    @discardableResult
    func createWindow(center: Bool = false) -> WindowController {
        let wc = WindowController()
        wc.setup()
        windowControllers.append(wc)
        if center {
            wc.window.center()
        }
        cascadePoint = wc.window.cascadeTopLeft(from: cascadePoint)
        wc.window.makeKeyAndOrderFront(nil)
        return wc
    }

    func windowDidClose(_ wc: WindowController) {
        windowControllers.removeAll { $0 === wc }
    }

    func keyWindowController() -> WindowController? {
        let key = NSApplication.shared.keyWindow
        return windowControllers.first { $0.window === key }
    }

    // MARK: - Default app

    func setAsDefaultApp(from wc: WindowController) {
        let appURL = Bundle.main.bundleURL
        LSRegisterURL(appURL as CFURL, true)

        guard let mdType = UTType(filenameExtension: "md") else { return }
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: mdType) { error in
            DispatchQueue.main.async {
                if let error {
                    let alert = NSAlert()
                    alert.messageText = "Couldn't set default"
                    alert.informativeText = "To set manually:\n1. Right-click any .md file in Finder\n2. Click \"Get Info\"\n3. Under \"Open with\", select mdreader\n4. Click \"Change All...\"\n\n(\(error.localizedDescription))"
                    alert.alertStyle = .informational
                    alert.runModal()
                } else {
                    if let markdownType = UTType(filenameExtension: "markdown") {
                        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: markdownType) { _ in }
                    }
                    wc.webView.evaluateJavaScript("app.showToast('mdreader is now your default markdown reader')")
                }
            }
        }
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
        let newWindowItem = NSMenuItem(title: "New Window", action: #selector(menuNewWindow), keyEquivalent: "n")
        newWindowItem.target = self; fileSub.addItem(newWindowItem)
        fileSub.addItem(.separator())
        let openFileItem = NSMenuItem(title: "Open File...", action: #selector(menuOpenFile), keyEquivalent: "o")
        openFileItem.target = self; fileSub.addItem(openFileItem)
        let openFolderItem = NSMenuItem(title: "Open Folder...", action: #selector(menuOpenFolder), keyEquivalent: "O")
        openFolderItem.target = self; fileSub.addItem(openFolderItem)
        fileSub.addItem(.separator())
        let closeItem = NSMenuItem(title: "Close Window", action: #selector(menuCloseWindow), keyEquivalent: "w")
        closeItem.target = self; fileSub.addItem(closeItem)
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

    @objc func menuNewWindow() { createWindow() }
    @objc func menuCloseWindow() { NSApplication.shared.keyWindow?.close() }

    @objc func menuOpenFile() {
        let wc = keyWindowController() ?? createWindow()
        let panel = NSOpenPanel()
        panel.allowsOtherFileTypes = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown"), .plainText].compactMap { $0 }
        if panel.runModal() == .OK, let url = panel.url { wc.openFile(url) }
    }

    @objc func menuOpenFolder() {
        let wc = keyWindowController() ?? createWindow()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url { wc.openFolder(url) }
    }

    @objc func menuSetDefault() {
        if let wc = keyWindowController() { setAsDefaultApp(from: wc) }
    }
    @objc func menuToggleSidebar() { keyWindowController()?.webView.evaluateJavaScript("app.toggleSidebar()") }
    @objc func menuToggleToc() { keyWindowController()?.webView.evaluateJavaScript("app.toggleToc()") }
    @objc func menuToggleTheme() { keyWindowController()?.webView.evaluateJavaScript("app.cycleTheme()") }

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

// MARK: - Custom URL scheme for local file access (images etc.)

class LocalFileHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        // mdfile:///path/to/image.png → /path/to/image.png
        let filePath = url.path
        let fileURL = URL(fileURLWithPath: filePath)
        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mimeType: String
        switch fileURL.pathExtension.lowercased() {
        case "png": mimeType = "image/png"
        case "jpg", "jpeg": mimeType = "image/jpeg"
        case "gif": mimeType = "image/gif"
        case "svg": mimeType = "image/svg+xml"
        case "webp": mimeType = "image/webp"
        case "bmp": mimeType = "image/bmp"
        case "ico": mimeType = "image/x-icon"
        default: mimeType = "application/octet-stream"
        }
        let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}

extension String {
    func jsEscaped() -> String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
