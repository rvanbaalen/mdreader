import SwiftUI

@main
struct MDReaderApp: App {
    @StateObject private var state = AppState()
    @NSApplicationDelegateAdaptor(MDReaderDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .preferredColorScheme(state.resolvedColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1060, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About mdreader") { delegate.showAbout() }
            }
            CommandGroup(replacing: .newItem) {
                Button("Open File...") { state.showOpenPanel() }
                    .keyboardShortcut("o")
                Button("Open Folder...") { state.showOpenFolderPanel() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") { state.toggleSidebar() }
                    .keyboardShortcut("\\", modifiers: .command)
                Button("Toggle Table of Contents") { state.toggleToc() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Toggle Theme") { state.cycleTheme() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}

class MDReaderDelegate: NSObject, NSApplicationDelegate {
    var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Style the main window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
                window.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
                window.minSize = NSSize(width: 600, height: 400)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func showAbout() {
        if let w = aboutWindow { w.makeKeyAndOrderFront(nil); return }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        w.center()
        w.contentView = NSHostingView(rootView: AboutView())
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        aboutWindow = w
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            Text("mdreader")
                .font(.custom("Georgia", size: 24).bold())
                .foregroundStyle(Color(nsColor: MDColors.darkPrimary))
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: MDColors.darkMuted))
            Text("A beautiful macOS markdown reader")
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: MDColors.darkSecondary))
                .multilineTextAlignment(.center)
            Text("\u{00A9} 2026 Robin van Baalen")
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: MDColors.darkDim))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: MDColors.darkBase))
    }
}
