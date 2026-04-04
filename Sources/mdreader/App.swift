import AppKit
import WebKit
import UniformTypeIdentifiers
import CoreServices

@main
struct MDReaderEntry {
    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        // CLI flags — handle before launching GUI
        if args.contains("--version") || args.contains("-v") {
            print("mdreader \(appVersion)")
            exit(0)
        }

        if args.contains("--help") || args.contains("-h") {
            print("""
            mdreader \(appVersion) — A beautiful markdown reader for macOS

            USAGE:
                mdreader [options] [file|folder]
                mdreader open <file|folder>

            OPTIONS:
                -h, --help       Show this help message
                -v, --version    Show version number
                --log-path       Print log file path

            EXAMPLES:
                mdreader                     Open mdreader
                mdreader README.md           Open a markdown file
                mdreader ./docs              Open a folder
                mdreader open ~/notes        Open a folder
            """)
            exit(0)
        }

        if args.contains("--log-path") {
            print(MDLogger.shared.logFilePath)
            exit(0)
        }

        // Strip `open` subcommand so downstream code sees just the path
        var fileArgs = args
        if fileArgs.first == "open" {
            fileArgs.removeFirst()
        }

        // If launched from a terminal, detach and re-launch as a GUI process
        if isatty(STDIN_FILENO) == 1, ProcessInfo.processInfo.environment["MDREADER_LAUNCHED"] == nil {
            let execPath = CommandLine.arguments[0]
            var env = ProcessInfo.processInfo.environment
            env["MDREADER_LAUNCHED"] = "1"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = fileArgs
            process.environment = env
            // Detach from terminal
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            // Parent exits immediately, returning the terminal
            exit(0)
        }

        let isDev = ProcessInfo.processInfo.environment["MDREADER_DEV"] == "1"
        log.info("mdreader \(appVersion) starting (mode: \(isDev ? "dev" : "production"))")
        log.info("Log file: \(log.logFilePath)")

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
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 600, height: 400)
        window.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "app")
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setURLSchemeHandler(LocalFileHandler(), forURLScheme: "mdfile")

        // Forward JS console messages to Swift logger
        let consoleScript = WKUserScript(source: """
            (function() {
                function forward(level) {
                    const orig = console[level];
                    console[level] = function() {
                        const msg = Array.from(arguments).map(a => {
                            try { return typeof a === 'object' ? JSON.stringify(a) : String(a); }
                            catch { return String(a); }
                        }).join(' ');
                        window.webkit.messageHandlers.app.postMessage({ action: 'console', level: level, message: msg });
                        orig.apply(console, arguments);
                    };
                }
                ['log', 'warn', 'error', 'info', 'debug'].forEach(forward);
                window.addEventListener('error', function(e) {
                    window.webkit.messageHandlers.app.postMessage({
                        action: 'console', level: 'error',
                        message: e.message + ' (' + (e.filename || '') + ':' + (e.lineno || '') + ')'
                    });
                });
                window.addEventListener('unhandledrejection', function(e) {
                    window.webkit.messageHandlers.app.postMessage({
                        action: 'console', level: 'error',
                        message: 'Unhandled rejection: ' + (e.reason || '')
                    });
                });
            })();
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(consoleScript)

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        window.contentView!.addSubview(webView)

        // Enable Web Inspector in dev mode
        let isDev = ProcessInfo.processInfo.environment["MDREADER_DEV"] == "1"
        if isDev {
            webView.isInspectable = true
            log.info("Web Inspector enabled (right-click → Inspect Element)", component: "WebView")
        }

        let fileRoot = URL(fileURLWithPath: "/")
        if isDev {
            let devURL = URL(string: "http://localhost:5173")!
            log.info("Loading dev server: \(devURL)", component: "WebView")
            webView.load(URLRequest(url: devURL))
        } else if let distIndex = ResourceLoader.url(forResource: "dist/index.html") {
            log.info("Loading bundled UI: \(distIndex.path)", component: "WebView")
            webView.loadFileURL(distIndex, allowingReadAccessTo: fileRoot)
        } else {
            log.warn("No dist/ found, falling back to inline HTML", component: "WebView")
            let html = buildHTML()
            let bundleParent = ResourceLoader.bundle.bundleURL.deletingLastPathComponent()
            let tempHTML = bundleParent.appendingPathComponent("mdreader_ui.html")
            try? html.data(using: .utf8)?.write(to: tempHTML)
            webView.loadFileURL(tempHTML, allowingReadAccessTo: fileRoot)
        }
    }

    // MARK: - File ops

    func openFile(_ url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            log.error("Failed to read file: \(url.path)", component: "FileIO")
            return
        }
        log.info("Opening file: \(url.path) (\(content.count) bytes)", component: "FileIO")
        Recents.add(path: url.path, isDir: false)
        AppDelegate.shared.broadcastRecents()
        currentFile = url
        let dirPath = url.deletingLastPathComponent().path
        webView.evaluateJavaScript("app.openFile(`\(content.jsEscaped())`, '\(url.lastPathComponent.jsEscaped())', '\((currentFolder?.lastPathComponent ?? "").jsEscaped())', '\(dirPath.jsEscaped())')")
        watchFile(url)
    }

    func openFolder(_ url: URL) {
        log.info("Opening folder: \(url.path)", component: "FileIO")
        Recents.add(path: url.path, isDir: true)
        AppDelegate.shared.broadcastRecents()
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

    private var lastWatchedContent: String?

    func watchFile(_ url: URL) {
        watcher?.cancel()
        lastWatchedContent = try? String(contentsOf: url, encoding: .utf8)
        startWatcher(for: url)
    }

    private func startWatcher(for url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            // File may have been atomically replaced — retry shortly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startWatcher(for: url)
            }
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self else { return }
            // Re-read content after a tiny delay (editors may still be writing)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
                if content != self.lastWatchedContent {
                    self.lastWatchedContent = content
                    self.webView.evaluateJavaScript("app.updateContent(`\(content.jsEscaped())`)")
                    log.debug("File updated externally: \(url.lastPathComponent)", component: "FileIO")
                }
                // Re-establish watcher (atomic saves invalidate the fd)
                self.watcher?.cancel()
                self.startWatcher(for: url)
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        watcher = src
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
        if action == "console" {
            let level = body["level"] as? String ?? "log"
            let msg = body["message"] as? String ?? ""
            switch level {
            case "error": log.error(msg, component: "JS")
            case "warn":  log.warn(msg, component: "JS")
            case "debug": log.debug(msg, component: "JS")
            default:      log.info(msg, component: "JS")
            }
            return
        }
        log.debug("Message from JS: \(action)", component: "Bridge")
        switch action {
        case "open", "openFile":
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsOtherFileTypes = true
            panel.allowedContentTypes = [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown"), .plainText].compactMap { $0 }
            panel.prompt = "Open"
            if panel.runModal() == .OK, let url = panel.url {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    openFolder(url)
                } else {
                    openFile(url)
                }
            }
        case "openFolder":
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true; panel.canChooseFiles = false
            if panel.runModal() == .OK, let url = panel.url { openFolder(url) }
        case "openFilePath":
            if let p = body["path"] as? String {
                let url = URL(fileURLWithPath: p)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue {
                    openFolder(url)
                } else {
                    openFile(url)
                }
            }
        case "saveFile":
            if let content = body["content"] as? String, let file = currentFile {
                log.info("Saving file: \(file.path)", component: "FileIO")
                do {
                    // Update tracked content so watcher won't echo our own save
                    lastWatchedContent = content
                    try content.write(to: file, atomically: true, encoding: .utf8)
                    webView.evaluateJavaScript("app.onSaveComplete(true)")
                } catch {
                    log.error("Save failed: \(error.localizedDescription)", component: "FileIO")
                    webView.evaluateJavaScript("app.onSaveComplete(false)")
                }
            }
        case "setTheme":
            if let m = body["mode"] as? String { UserDefaults.standard.set(m, forKey: "themeMode") }
        case "startDrag":
            if let event = NSApplication.shared.currentEvent {
                window.performDrag(with: event)
            }
        case "installUpdate":
            AppDelegate.shared.runBrewUpgrade(from: self)
        case "restartApp":
            AppDelegate.shared.restartApp()
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
            if let json = Recents.json() {
                webView.evaluateJavaScript("app.setRecents(\(json))")
            }
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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log.info("Page loaded: \(webView.url?.absoluteString ?? "unknown")", component: "WebView")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log.error("Navigation failed: \(error.localizedDescription)", component: "WebView")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        log.error("Provisional navigation failed: \(error.localizedDescription) (URL: \(webView.url?.absoluteString ?? "unknown"))", component: "WebView")
    }

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
            if handler.lowercased() != "nl.robinvanbaalen.mdreader" {
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
        log.info("App launched, PID \(ProcessInfo.processInfo.processIdentifier)")

        if let url = ResourceLoader.url(forResource: "icon.icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }

        setupMenu()

        let wc = createWindow(center: true)
        if CommandLine.arguments.count > 1 {
            let path = CommandLine.arguments[1]
            log.info("CLI argument: \(path)")
            wc.pendingFile = URL(fileURLWithPath: path)
        }
        NSRunningApplication.current.activate()

        // Show changelog once after update
        showChangelogIfUpdated(in: wc)

        // Check for updates in background (skip in dev mode)
        if ProcessInfo.processInfo.environment["MDREADER_DEV"] != "1" {
            checkForUpdates()
        } else {
            log.debug("Skipping update check in dev mode", component: "Update")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { createWindow(center: true) }
        return true
    }

    func broadcastRecents() {
        guard let json = Recents.json() else { return }
        for wc in windowControllers where wc.webReady {
            wc.webView.evaluateJavaScript("app.setRecents(\(json))")
        }
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
        let hadFile = wc.currentFile != nil
        windowControllers.removeAll { $0 === wc }

        if windowControllers.isEmpty {
            if hadFile {
                // Last file window closed — open a welcome window
                createWindow(center: true)
            } else {
                // Welcome window closed — quit
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func keyWindowController() -> WindowController? {
        let key = NSApplication.shared.keyWindow
        return windowControllers.first { $0.window === key }
    }

    // MARK: - Update check

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() {
        log.info("Checking for updates (current: \(currentVersion))", component: "Update")
        guard let url = URL(string: "https://api.github.com/repos/rvanbaalen/mdreader/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let error {
                log.warn("Update check failed: \(error.localizedDescription)", component: "Update")
                return
            }
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else { return }
            let latest = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            guard latest != self.currentVersion, self.isNewer(latest, than: self.currentVersion) else {
                log.info("Up to date (latest: \(latest))", component: "Update")
                return
            }
            log.info("Update available: \(latest)", component: "Update")
            DispatchQueue.main.async {
                if let wc = self.windowControllers.first(where: { $0.webReady }) {
                    wc.webView.evaluateJavaScript("app.showUpdateBanner('\(self.currentVersion)', '\(latest)')")
                }
            }
        }.resume()
    }

    private func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").compactMap { Int($0) }
        let pb = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(pa.count, pb.count) {
            let va = i < pa.count ? pa[i] : 0
            let vb = i < pb.count ? pb[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }
        return false
    }

    // MARK: - Post-update changelog

    func showChangelogIfUpdated(in wc: WindowController) {
        let key = "lastSeenVersion"
        let lastSeen = UserDefaults.standard.string(forKey: key)
        let current = currentVersion
        guard current != "dev", lastSeen != nil, lastSeen != current else {
            UserDefaults.standard.set(current, forKey: key)
            return
        }
        // Version changed — show changelog once
        UserDefaults.standard.set(current, forKey: key)
        if let changelogURL = ResourceLoader.url(forResource: "CHANGELOG.md") {
            wc.pendingFile = changelogURL
        }
    }

    // MARK: - Brew upgrade

    func runBrewUpgrade(from wc: WindowController) {
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew", "/home/linuxbrew/.linuxbrew/bin/brew"]
        guard let brew = brewPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            // No brew found — open GitHub releases as fallback
            if let url = URL(string: "https://github.com/rvanbaalen/mdreader/releases/latest") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", "\(brew) update && \(brew) upgrade rvanbaalen/tap/mdreader"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
            DispatchQueue.main.async {
                wc.webView.evaluateJavaScript("window.__updateComplete?.()")
            }
        }
    }

    func restartApp() {
        let bundleId = Bundle.main.bundleIdentifier ?? "nl.robinvanbaalen.mdreader"
        let appPath = Bundle.main.bundleURL.path
        // Try bundle ID first (finds new version after brew upgrade), fall back to path (dev builds)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1 && open -b \"\(bundleId)\" 2>/dev/null || open \"\(appPath)\""]
        try? task.run()
        NSApplication.shared.terminate(nil)
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
        let openItem = NSMenuItem(title: "Open...", action: #selector(menuOpen), keyEquivalent: "o")
        openItem.target = self; fileSub.addItem(openItem)
        let saveItem = NSMenuItem(title: "Save", action: #selector(menuSave), keyEquivalent: "s")
        saveItem.target = self; fileSub.addItem(saveItem)
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
        let editItem = NSMenuItem(title: "Toggle Edit Mode", action: #selector(menuToggleEdit), keyEquivalent: "e")
        editItem.target = self; viewSub.addItem(editItem)
        viewMenu.submenu = viewSub; menu.addItem(viewMenu)

        let editMenu = NSMenuItem(); let editSub = NSMenu(title: "Edit")
        editSub.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editSub.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.submenu = editSub; menu.addItem(editMenu)

        let helpMenu = NSMenuItem(); let helpSub = NSMenu(title: "Help")
        let bugItem = NSMenuItem(title: "Report a Bug...", action: #selector(menuReportBug), keyEquivalent: "")
        bugItem.target = self; helpSub.addItem(bugItem)
        let featureItem = NSMenuItem(title: "Request a Feature...", action: #selector(menuRequestFeature), keyEquivalent: "")
        featureItem.target = self; helpSub.addItem(featureItem)
        helpSub.addItem(.separator())
        let copyLogsItem = NSMenuItem(title: "Copy Logs to Clipboard", action: #selector(menuCopyLogs), keyEquivalent: "")
        copyLogsItem.target = self; helpSub.addItem(copyLogsItem)
        let showLogsItem = NSMenuItem(title: "Show Logs in Finder", action: #selector(menuShowLogs), keyEquivalent: "")
        showLogsItem.target = self; helpSub.addItem(showLogsItem)
        helpMenu.submenu = helpSub; menu.addItem(helpMenu)

        NSApplication.shared.mainMenu = menu
    }

    @objc func menuNewWindow() { createWindow() }
    @objc func menuCloseWindow() { NSApplication.shared.keyWindow?.close() }
    @objc func menuSave() { keyWindowController()?.webView.evaluateJavaScript("app.save()") }

    @objc func menuOpen() {
        let wc = keyWindowController() ?? createWindow()
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsOtherFileTypes = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown"), .plainText].compactMap { $0 }
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                wc.openFolder(url)
            } else {
                wc.openFile(url)
            }
        }
    }

    @objc func menuSetDefault() {
        if let wc = keyWindowController() { setAsDefaultApp(from: wc) }
    }
    @objc func menuToggleSidebar() { keyWindowController()?.webView.evaluateJavaScript("app.toggleSidebar()") }
    @objc func menuToggleToc() { keyWindowController()?.webView.evaluateJavaScript("app.toggleToc()") }
    @objc func menuToggleTheme() { keyWindowController()?.webView.evaluateJavaScript("app.cycleTheme()") }
    @objc func menuToggleEdit() { keyWindowController()?.webView.evaluateJavaScript("app.toggleEdit()") }

    @objc func menuReportBug() {
        NSWorkspace.shared.open(URL(string: "https://github.com/rvanbaalen/mdreader/issues/new?labels=bug&template=bug_report.md")!)
    }

    @objc func menuRequestFeature() {
        NSWorkspace.shared.open(URL(string: "https://github.com/rvanbaalen/mdreader/issues/new?labels=enhancement&template=feature_request.md")!)
    }

    @objc func menuCopyLogs() {
        let contents = log.logContents()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contents, forType: .string)
        if let wc = keyWindowController(), wc.webReady {
            wc.webView.evaluateJavaScript("app.showToast('Logs copied to clipboard')")
        }
    }

    @objc func menuShowLogs() {
        NSWorkspace.shared.selectFile(log.logFilePath, inFileViewerRootedAtPath: log.logDirectoryPath)
    }

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

// MARK: - Recents

enum Recents {
    private static let key = "recentItems"
    private static let maxItems = 10

    static func add(path: String, isDir: Bool) {
        var items = load()
        items.removeAll { $0["path"] as? String == path }
        items.insert(["path": path, "name": URL(fileURLWithPath: path).lastPathComponent, "isDir": isDir], at: 0)
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }
        UserDefaults.standard.set(items, forKey: key)
        UserDefaults.standard.synchronize()
    }

    static func load() -> [[String: Any]] {
        UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
    }

    static func json() -> String? {
        let items = load().filter { item in
            guard let path = item["path"] as? String else { return false }
            return FileManager.default.fileExists(atPath: path)
        }
        guard !items.isEmpty, let data = try? JSONSerialization.data(withJSONObject: items) else { return nil }
        return String(data: data, encoding: .utf8)
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
