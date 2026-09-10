import Foundation
import Combine

public enum AppTab: Int, CaseIterable, Identifiable {
    case reader = 0
    case history = 1
    case bookmarks = 2
    case notes = 3
    case search = 4
    case settings = 5

    public var id: Int { rawValue }

    public var titleKey: String {
        switch self {
        case .reader: return "tabs.reader"
        case .history: return "tabs.history"
        case .bookmarks: return "tabs.bookmarks"
        case .notes: return "tabs.notes"
        case .search: return "tabs.search"
        case .settings: return "tabs.settings"
        }
    }

    public var titleFallback: String {
        switch self {
        case .reader: return "אתר"
        case .history: return "היסטוריה"
        case .bookmarks: return "סימניות"
        case .notes: return "הערות"
        case .search: return "חיפוש"
        case .settings: return "הגדרות"
        }
    }

    public var systemImage: String {
        switch self {
        case .reader: return "globe"
        case .history: return "clock"
        case .bookmarks: return "bookmark"
        case .notes: return "note.text"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
public final class AppCoordinator: ObservableObject {
    public static let shared = AppCoordinator()

    @Published public var selectedTab: AppTab = .reader
    public var onNavigateReader: ((URL) -> Void)?

    public init() {}

    public func openInReader(url: URL) {
        selectedTab = .reader
        onNavigateReader?(url)
    }

    public func openInReader(location: AlHaTorahLocation) {
        guard let url = location.readerURL else { return }
        openInReader(url: url)
    }

    public func openIncomingURL(_ url: URL) {
        if let destination = DeepLinkParser.destinationURL(from: url) {
            openInReader(url: destination)
        } else {
            openInReader(url: url)
        }
    }
}
