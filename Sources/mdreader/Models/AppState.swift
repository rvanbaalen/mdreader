import SwiftUI
import UniformTypeIdentifiers

enum ThemeMode: String {
    case dark, light, system
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentFile: URL?
    @Published var currentContent: String = ""
    @Published var sidebarVisible: Bool = true
    @Published var tocVisible: Bool = false
    @Published var folderURL: URL?
    @Published var folderFiles: [FileNode] = []
    @Published var headings: [HeadingItem] = []
    @Published var activeHeadingId: String = ""
    @Published var themeMode: ThemeMode

    private var fileWatcher: DispatchSourceFileSystemObject?

    init() {
        let stored = UserDefaults.standard.string(forKey: "themeMode") ?? "system"
        self.themeMode = ThemeMode(rawValue: stored) ?? .system
        self.sidebarVisible = UserDefaults.standard.object(forKey: "sidebarVisible") as? Bool ?? true
        self.tocVisible = UserDefaults.standard.object(forKey: "tocVisible") as? Bool ?? false
    }

    var resolvedColorScheme: ColorScheme? {
        switch themeMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    func cycleTheme() {
        switch themeMode {
        case .dark: themeMode = .light
        case .light: themeMode = .system
        case .system: themeMode = .dark
        }
        UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
    }

    func toggleSidebar() {
        withAnimation(.easeOut(duration: 0.25)) { sidebarVisible.toggle() }
        UserDefaults.standard.set(sidebarVisible, forKey: "sidebarVisible")
    }

    func toggleToc() {
        withAnimation(.easeOut(duration: 0.25)) { tocVisible.toggle() }
        UserDefaults.standard.set(tocVisible, forKey: "tocVisible")
    }

    func openFile(_ url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        currentFile = url
        currentContent = content
        watchFile(url)
    }

    func openFolder(_ url: URL) {
        folderURL = url
        folderFiles = scanDirectory(url)
        if let first = findFirstMd(folderFiles) { openFile(first) }
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!,
        ]
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { openFile(url) }
    }

    func showOpenFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url { openFolder(url) }
    }

    // MARK: - Private

    private func watchFile(_ url: URL) {
        fileWatcher?.cancel()
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                self?.currentContent = content
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatcher = source
    }

    private func scanDirectory(_ url: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        return items.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { item in
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                let children = scanDirectory(item)
                return children.isEmpty ? nil : FileNode(name: item.lastPathComponent, url: item, isDirectory: true, children: children)
            } else if ["md", "markdown"].contains(item.pathExtension.lowercased()) {
                return FileNode(name: item.lastPathComponent, url: item, isDirectory: false, children: [])
            }
            return nil
        }
    }

    private func findFirstMd(_ nodes: [FileNode]) -> URL? {
        if let readme = nodes.first(where: { $0.name.lowercased() == "readme.md" }) { return readme.url }
        if let first = nodes.first(where: { !$0.isDirectory }) { return first.url }
        for n in nodes where n.isDirectory { if let f = findFirstMd(n.children) { return f } }
        return nil
    }
}
