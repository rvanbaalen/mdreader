import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var cs

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("mdreader")
                .font(.custom("Georgia", size: 48).weight(.bold))
                .foregroundStyle(MDColors.primary(cs))
                .tracking(-1)

            Text("A beautiful markdown reader")
                .font(.system(size: 18))
                .foregroundStyle(MDColors.muted(cs))

            VStack(spacing: 8) {
                WelcomeButton(title: "Open File", shortcut: "⌘O") { state.showOpenPanel() }
                WelcomeButton(title: "Open Folder", shortcut: "⌘⇧O") { state.showOpenFolderPanel() }
            }
            .padding(.top, 8)

            Text("or drag a .md file anywhere")
                .font(.system(size: 12))
                .foregroundStyle(MDColors.dim(cs))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WelcomeButton: View {
    let title: String
    let shortcut: String
    let action: () -> Void
    @Environment(\.colorScheme) var cs
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MDColors.primary(cs))
                Spacer()
                Text(shortcut)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(MDColors.dim(cs))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(width: 220)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovered ? MDColors.surfaceHover(cs) : MDColors.surface(cs))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(MDColors.edge(cs), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { hovered = h } }
    }
}
