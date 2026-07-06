import Foundation

protocol HistoryStoreDelegate: AnyObject {
    func historyStoreDidChange(_ store: HistoryStore)
}

final class HistoryStore {
    weak var delegate: HistoryStoreDelegate?

    private let fileName = "history.json"
    private let maxItems = 2000

    private(set) var items: [HistoryItem] = [] {
        didSet {
            FileStore.save(items, to: fileName)
            delegate?.historyStoreDidChange(self)
        }
    }

    init() {
        self.items = FileStore.load([HistoryItem].self, from: fileName) ?? []
    }

    func add(title: String?, url: URL) {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return }

        if let first = items.first, first.urlString == url.absoluteString {
            return
        }

        let displayTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = HistoryItem(
            title: displayTitle?.isEmpty == false ? displayTitle! : url.host ?? url.absoluteString,
            urlString: url.absoluteString
        )

        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func clear() {
        items = []
    }

    func recentItems(limit: Int) -> [HistoryItem] {
        uniqueByURL(items, limit: limit)
    }

    private func uniqueByURL(_ sourceItems: [HistoryItem], limit: Int) -> [HistoryItem] {
        var seen = Set<String>()
        var result: [HistoryItem] = []

        for item in sourceItems {
            let key = item.urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(item)
            if result.count >= limit { break }
        }

        return result
    }
}

struct BookmarkItem: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let urlString: String
    let createdAt: Date

    init(id: UUID = UUID(), title: String, urlString: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.createdAt = createdAt
    }

    var url: URL? { URL(string: urlString) }
}

final class BookmarkStore {
    private let fileName = "bookmarks.json"
    private let maxItems = 2000

    private(set) var items: [BookmarkItem] = [] {
        didSet {
            FileStore.save(items, to: fileName)
        }
    }

    init() {
        self.items = FileStore.load([BookmarkItem].self, from: fileName) ?? []
    }

    func add(title: String?, url: URL) {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return }

        let displayTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTitle = displayTitle?.isEmpty == false ? displayTitle! : url.host ?? url.absoluteString

        items.removeAll { $0.urlString == url.absoluteString }
        items.insert(BookmarkItem(title: cleanedTitle, urlString: url.absoluteString), at: 0)

        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
    }

    func recentItems(limit: Int) -> [BookmarkItem] {
        uniqueByURL(items, limit: limit)
    }

    private func uniqueByURL(_ sourceItems: [BookmarkItem], limit: Int) -> [BookmarkItem] {
        var seen = Set<String>()
        var result: [BookmarkItem] = []

        for item in sourceItems {
            let key = item.urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(item)
            if result.count >= limit { break }
        }

        return result
    }
}
