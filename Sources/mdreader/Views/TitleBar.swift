import SwiftUI

struct TitleBar: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var cs

    var body: some View {
        ZStack {
            MDColors.surface(cs).opacity(0.5)
                .background(.ultraThinMaterial)

            HStack {
                // Traffic light spacer
                Color.clear.frame(width: 78, height: 1)

                Spacer()

                // File breadcrumb
                if let file = state.currentFile {
                    HStack(spacing: 4) {
                        if let folder = state.folderURL {
                            Text(folder.lastPathComponent)
                                .foregroundStyle(MDColors.dim(cs))
                            Text("/")
                                .foregroundStyle(MDColors.dim(cs).opacity(0.5))
                        }
                        Text(file.lastPathComponent)
                            .foregroundStyle(MDColors.secondary(cs))
                    }
                    .font(.system(size: 13, weight: .medium))
                }

                Spacer()

                // Actions
                HStack(spacing: 2) {
                    TitleBarButton(icon: "sidebar.leading", action: state.toggleSidebar)
                    TitleBarButton(icon: "list.bullet", action: state.toggleToc)
                    TitleBarButton(
                        icon: state.themeMode == .dark ? "sun.max" : (state.themeMode == .light ? "moon" : "desktopcomputer"),
                        action: state.cycleTheme
                    )
                }
                .padding(.trailing, 12)
            }
        }
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            MDColors.edge(cs).opacity(0.3).frame(height: 0.5)
        }
    }
}

struct TitleBarButton: View {
    let icon: String
    let action: () -> Void
    @Environment(\.colorScheme) var cs
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovered ? MDColors.secondary(cs) : MDColors.muted(cs))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hovered ? MDColors.surfaceHover(cs) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
