import Foundation

protocol TabStoreDelegate: AnyObject {
    func tabStoreDidChange(_ store: TabStore)
}

final class TabStore {
    weak var delegate: TabStoreDelegate?

    private let fileName: String
    private let currentTabKey: String
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

    init(settings: AppSettings, siteID: String? = nil, sceneID: String? = nil, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let site = settings.siteProfile(withID: siteID) ?? settings.defaultSite
        let scope = Self.scopeIdentifier(siteID: site.id, sceneID: sceneID)
        self.fileName = "tabs-\(scope).json"
        self.currentTabKey = "native_site_app.current_tab_id.\(scope).v2"

        self.tabs = FileStore.load([BrowserTab].self, from: fileName) ?? []
        if tabs.isEmpty {
            let tab = BrowserTab(title: site.name, urlString: site.homeURL.absoluteString)
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

    private static func scopeIdentifier(siteID: String, sceneID: String?) -> String {
        let raw = [siteID, sceneID].compactMap { $0 }.joined(separator: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(filtered).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
