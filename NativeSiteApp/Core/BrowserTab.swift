import Foundation

struct BrowserTab: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var urlString: String
    var createdAt: Date
    var lastAccessedAt: Date

    init(id: UUID = UUID(), title: String, urlString: String, createdAt: Date = Date(), lastAccessedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
    }

    var url: URL? { URL(string: urlString) }
}
