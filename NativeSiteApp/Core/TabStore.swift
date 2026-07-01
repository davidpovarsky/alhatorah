import Foundation

protocol TabStoreDelegate: AnyObject {
    func tabStoreDidChange(_ store: TabStore)
}

final class TabStore {
    weak var delegate: TabStoreDelegate?

    private let fileName = "tabs.json"
    private let currentTabKey = "native_site_app.current_tab_id.v1"
    private let userDefaults: UserDefaults

    private(set) var tabs: [BrowserTab] = [] {
        didSet {
            FileStore.save(tabs, to: fileName)
            delegate?.tabStoreDidChange(self)
        }
    }

    private(set) var currentTabID: UUID? {
        didSet {
            userDefaults.set(currentTabID?.uuidString, forKey: currentTabKey)
            delegate?.tabStoreDidChange(self)
        }
    }

    init(settings: AppSettings, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.tabs = FileStore.load([BrowserTab].self, from: fileName) ?? []
        if tabs.isEmpty {
            let tab = BrowserTab(title: "Home", urlString: settings.homeURL.absoluteString)
            tabs = [tab]
        }
        if let idString = userDefaults.string(forKey: currentTabKey), let id = UUID(uuidString: idString), tabs.contains(where: { $0.id == id }) {
            currentTabID = id
        } else {
            currentTabID = tabs.first?.id
        }
    }

    var currentTab: BrowserTab? {
        guard let currentTabID else { return tabs.first }
        return tabs.first(where: { $0.id == currentTabID }) ?? tabs.first
    }

    @discardableResult
    func createTab(title: String = "New Tab", url: URL, select: Bool = true) -> BrowserTab {
        let tab = BrowserTab(title: title, urlString: url.absoluteString)
        tabs.insert(tab, at: 0)
        if select { currentTabID = tab.id }
        return tab
    }

    func selectTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].lastAccessedAt = Date()
        currentTabID = id
        FileStore.save(tabs, to: fileName)
    }

    func updateCurrentTab(title: String?, url: URL?) {
        guard let currentTabID, let index = tabs.firstIndex(where: { $0.id == currentTabID }) else { return }
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tabs[index].title = title
        }
        if let url {
            tabs[index].urlString = url.absoluteString
        }
        tabs[index].lastAccessedAt = Date()
        FileStore.save(tabs, to: fileName)
        delegate?.tabStoreDidChange(self)
    }

    func deleteTab(id: UUID, fallbackURL: URL) {
        guard tabs.count > 1 else {
            tabs = [BrowserTab(title: "Home", urlString: fallbackURL.absoluteString)]
            currentTabID = tabs.first?.id
            return
        }

        let wasCurrent = currentTabID == id
        tabs.removeAll { $0.id == id }
        if wasCurrent {
            currentTabID = tabs.first?.id
        }
    }

    func closeAllAndCreateHome(url: URL) {
        let tab = BrowserTab(title: "Home", urlString: url.absoluteString)
        tabs = [tab]
        currentTabID = tab.id
    }
}
