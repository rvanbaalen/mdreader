import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var cs

    var theme: String {
        switch state.themeMode {
        case .dark: return "dark"
        case .light: return "light"
        case .system: return cs == .dark ? "dark" : "light"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TitleBar()

            if state.currentFile == nil && state.folderURL == nil {
                WelcomeView()
            } else {
                ZStack {
                    MDColors.base(cs)

                    // Reader (full area)
                    ReaderWebView(
                        markdown: state.currentContent,
                        theme: theme,
                        onHeadings: { state.headings = $0 },
                        onScroll: { state.activeHeadingId = $0 }
                    )
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToHeading)) { notif in
                        // Handled inside the webview coordinator
                    }

                    // Floating sidebar (left)
                    if state.sidebarVisible {
                        HStack(spacing: 0) {
                            Sidebar()
                                .frame(width: 250)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            Spacer()
                        }
                    }

                    // Floating ToC (right)
                    if state.tocVisible {
                        HStack(spacing: 0) {
                            Spacer()
                            TocPanel()
                                .frame(width: 200)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .background(MDColors.base(cs))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in self.state.openFile(url) }
                }
            }
            return true
        }
    }
}
