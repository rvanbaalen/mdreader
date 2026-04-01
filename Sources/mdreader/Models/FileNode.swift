import Foundation

struct FileNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    let children: [FileNode]

    func hash(into hasher: inout Hasher) { hasher.combine(url) }
    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.url == rhs.url }
}

struct HeadingItem: Identifiable, Codable {
    var id: String { self.headingId }
    let headingId: String
    let text: String
    let level: Int

    enum CodingKeys: String, CodingKey {
        case headingId = "id"
        case text
        case level
    }
}
