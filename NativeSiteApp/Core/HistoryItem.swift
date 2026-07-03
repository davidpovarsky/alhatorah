import Foundation

struct HistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let urlString: String
    let visitedAt: Date
    let siteID: String?

    init(id: UUID = UUID(), title: String, urlString: String, visitedAt: Date = Date(), siteID: String? = nil) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.visitedAt = visitedAt
        self.siteID = siteID
    }

    var url: URL? { URL(string: urlString) }
}
