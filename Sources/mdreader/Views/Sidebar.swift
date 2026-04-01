import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var cs

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !state.folderFiles.isEmpty, let folder = state.folderURL {
                SectionLabel(folder.lastPathComponent)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        FileTree(nodes: state.folderFiles, depth: 0)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                MDColors.surface(cs).opacity(0.6)
            }
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MDColors.edge(cs).opacity(0.5), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 4)
        .padding(.leading, 12)
        .padding(.vertical, 8)
    }
}

struct SectionLabel: View {
    let text: String
    @Environment(\.colorScheme) var cs

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundStyle(MDColors.muted(cs))
            .tracking(0.8)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }
}

struct FileTree: View {
    let nodes: [FileNode]
    let depth: Int
    @EnvironmentObject var state: AppState

    var body: some View {
        ForEach(nodes) { node in
            if node.isDirectory {
                FolderRow(node: node, depth: depth)
            } else {
                FileRow(node: node, depth: depth)
            }
        }
    }
}

struct FileRow: View {
    let node: FileNode
    let depth: Int
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var cs
    @State private var hovered = false

    var isActive: Bool { state.currentFile == node.url }

    var body: some View {
        Button { state.openFile(node.url) } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? MDColors.accent(cs) : MDColors.muted(cs))
                    .frame(width: 16)
                Text(node.name)
                    .font(.system(size: 13, design: .default))
                    .foregroundStyle(isActive ? MDColors.accentBright(cs) : MDColors.secondary(cs))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.leading, CGFloat(16 + depth * 16))
            .padding(.trailing, 12)
            .padding(.vertical, 4)
            .background(
                isActive ? MDColors.accent(cs).opacity(0.1)
                : (hovered ? MDColors.surfaceHover(cs) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct FolderRow: View {
    let node: FileNode
    let depth: Int
    @Environment(\.colorScheme) var cs
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MDColors.dim(cs))
                        .frame(width: 12)
                    Image(systemName: expanded ? "folder.fill" : "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(MDColors.muted(cs))
                        .frame(width: 16)
                    Text(node.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MDColors.muted(cs))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.leading, CGFloat(16 + depth * 16))
                .padding(.trailing, 12)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if expanded {
                FileTree(nodes: node.children, depth: depth + 1)
            }
        }
    }
}
