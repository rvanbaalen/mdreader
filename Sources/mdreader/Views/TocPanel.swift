import SwiftUI

struct TocPanel: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var cs

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("On this page")
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.headings) { heading in
                        TocItem(heading: heading, isActive: heading.headingId == state.activeHeadingId)
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
        .padding(.trailing, 12)
        .padding(.vertical, 8)
    }
}

struct TocItem: View {
    let heading: HeadingItem
    let isActive: Bool
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var cs
    @State private var hovered = false

    var body: some View {
        Button {
            // Post scroll message to webview via notification
            NotificationCenter.default.post(name: .scrollToHeading, object: heading.headingId)
        } label: {
            Text(heading.text)
                .font(.system(size: heading.level == 1 ? 13 : (heading.level <= 2 ? 12 : 11),
                              weight: heading.level <= 1 ? .medium : .regular))
                .foregroundStyle(isActive ? MDColors.accentBright(cs) : MDColors.muted(cs))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, CGFloat(20 + (heading.level - 1) * 10))
                .padding(.trailing, 12)
                .padding(.vertical, 3)
                .background(hovered ? MDColors.surfaceHover(cs) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

extension Notification.Name {
    static let scrollToHeading = Notification.Name("scrollToHeading")
}
