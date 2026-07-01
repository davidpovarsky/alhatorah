import Foundation

struct HistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let urlString: String
    let visitedAt: Date

    init(id: UUID = UUID(), title: String, urlString: String, visitedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.visitedAt = visitedAt
    }

    var url: URL? { URL(string: urlString) }
}
