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
}
