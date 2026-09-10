import Foundation
import Combine

@MainActor
public final class AlHaTorahDataStore: ObservableObject {
    public static let shared = AlHaTorahDataStore()

    @Published public private(set) var historyItems: [AlHaTorahHistoryItem] = []
    @Published public private(set) var bookmarks: [AlHaTorahBookmark] = []
    @Published public private(set) var notes: [AlHaTorahNote] = []
    @Published public private(set) var highlights: [AlHaTorahHighlight] = []

    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastSyncDate: Date? = nil
    @Published public var errorMessage: String? = nil

    private let apiClient: AlHaTorahAPIClient
    private let sessionStore: AlHaTorahSessionStore
    private var cancellables = Set<AnyCancellable>()

    private let bookmarksFileName = "aht_bookmarks.json"
    private let notesFileName = "aht_notes.json"
    private let highlightsFileName = "aht_highlights.json"
    private let historyFileName = "aht_history.json"

    public init(apiClient: AlHaTorahAPIClient = .shared, sessionStore: AlHaTorahSessionStore = .shared) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore

        loadLocalCache()

        sessionStore.$isLoggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loggedIn in
                if loggedIn {
                    Task {
                        await self?.syncAll()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Sync

    public func syncAll() async {
        guard sessionStore.isLoggedIn else {
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 1. Sync dashboard history
        do {
            let serverHistory = try await apiClient.fetchDashboardHistory()
            if !serverHistory.isEmpty {
                self.historyItems = serverHistory
                saveLocal(historyItems, to: historyFileName)
            }
        } catch {
            AppLogger.shared.log("History sync failed: \(error.localizedDescription)")
        }

        // 2. Sync export data (bookmarks, notes, highlights)
        do {
            let export = try await apiClient.exportData()
            if let payload = export.data {
                if let rawBookmarks = payload.bookmark {
                    self.bookmarks = rawBookmarks.compactMap { $0.toBookmark() }
                    saveLocal(self.bookmarks, to: bookmarksFileName)
                }

                if let rawNotes = payload.gilayon {
                    self.notes = rawNotes.compactMap { $0.toNote() }
                    saveLocal(self.notes, to: notesFileName)
                }

                if let rawHighlights = payload.highlight {
                    self.highlights = rawHighlights.compactMap { $0.toHighlight() }
                    saveLocal(self.highlights, to: highlightsFileName)
                }
            }
            lastSyncDate = Date()
        } catch {
            AppLogger.shared.log("Export data sync failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Bookmarks

    public func addBookmark(location: AlHaTorahLocation) async throws {
        _ = try await apiClient.addBookmark(location: location)
        let newBookmark = AlHaTorahBookmark(
            id: UUID().uuidString,
            type: location.type,
            location: location,
            createdAt: Date()
        )
        bookmarks.removeAll { $0.location == location }
        bookmarks.insert(newBookmark, at: 0)
        saveLocal(bookmarks, to: bookmarksFileName)
    }

    public func removeBookmark(id: String) async throws {
        _ = try await apiClient.removeData(id: id)
        bookmarks.removeAll { $0.id == id }
        saveLocal(bookmarks, to: bookmarksFileName)
    }

    public func removeBookmark(location: AlHaTorahLocation) async throws {
        _ = try await apiClient.removeBookmark(location: location)
        bookmarks.removeAll { $0.location == location }
        saveLocal(bookmarks, to: bookmarksFileName)
    }

    public func isBookmarked(location: AlHaTorahLocation) -> Bool {
        bookmarks.contains { b in
            b.location.book == location.book &&
            b.location.unit == location.unit &&
            b.location.subUnit == location.subUnit &&
            b.location.parshan == location.parshan
        }
    }

    // MARK: - Notes

    public func createNote(
        title: String,
        content: String,
        location: AlHaTorahLocation,
        paragraph: Int? = nil,
        begin: Int = 0,
        end: Int = 0
    ) async throws -> AlHaTorahNote {
        let note = try await apiClient.createNote(
            title: title,
            content: content,
            location: location,
            paragraph: paragraph,
            begin: begin,
            end: end
        )
        notes.insert(note, at: 0)
        saveLocal(notes, to: notesFileName)
        return note
    }

    public func editNote(id: String, content: String) async throws {
        _ = try await apiClient.editNote(id: id, content: content)
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].content = content
            saveLocal(notes, to: notesFileName)
        }
    }

    public func deleteNote(id: String) async throws {
        _ = try await apiClient.removeData(id: id)
        notes.removeAll { $0.id == id }
        saveLocal(notes, to: notesFileName)
    }

    // MARK: - Highlights

    public func addHighlight(
        color: String,
        location: AlHaTorahLocation,
        paragraph: Int? = nil,
        begin: Int,
        end: Int
    ) async throws -> AlHaTorahHighlight {
        let highlight = try await apiClient.addHighlight(
            color: color,
            location: location,
            paragraph: paragraph,
            begin: begin,
            end: end
        )
        highlights.insert(highlight, at: 0)
        saveLocal(highlights, to: highlightsFileName)
        return highlight
    }

    public func changeHighlightColor(
        id: String,
        newColor: String,
        location: AlHaTorahLocation,
        paragraph: Int? = nil,
        begin: Int,
        end: Int
    ) async throws -> AlHaTorahHighlight {
        let updated = try await apiClient.changeHighlightColor(
            oldId: id,
            newColor: newColor,
            location: location,
            paragraph: paragraph,
            begin: begin,
            end: end
        )
        highlights.removeAll { $0.id == id }
        highlights.insert(updated, at: 0)
        saveLocal(highlights, to: highlightsFileName)
        return updated
    }

    public func deleteHighlight(id: String) async throws {
        _ = try await apiClient.removeData(id: id)
        highlights.removeAll { $0.id == id }
        saveLocal(highlights, to: highlightsFileName)
    }

    // MARK: - History

    public func recordHistory(location: AlHaTorahLocation, title: String? = nil, url: URL? = nil) {
        let finalTitle = title ?? location.displayTitle
        let urlStr = url?.absoluteString ?? (location.readerURL?.absoluteString ?? "")
        let newItem = AlHaTorahHistoryItem(
            id: UUID().uuidString,
            base: location.mg,
            locnum: nil,
            title: finalTitle,
            urlString: urlStr,
            commentator: location.isCommentary ? location.parshan : nil,
            visitedAt: Date(),
            isSynced: false
        )

        // Prevent duplicate consecutive entries
        if let first = historyItems.first, first.urlString == urlStr {
            return
        }

        historyItems.insert(newItem, at: 0)
        if historyItems.count > 500 {
            historyItems = Array(historyItems.prefix(500))
        }
        saveLocal(historyItems, to: historyFileName)

        if sessionStore.isLoggedIn {
            Task {
                _ = try? await apiClient.recordHistory(location: location)
            }
        }
    }

    public func deleteHistoryItem(id: String) async throws {
        _ = try? await apiClient.removeData(id: id)
        historyItems.removeAll { $0.id == id }
        saveLocal(historyItems, to: historyFileName)
    }

    public func clearAllHistory() {
        for item in historyItems {
            Task {
                _ = try? await apiClient.removeData(id: item.id)
            }
        }
        historyItems.removeAll()
        saveLocal(historyItems, to: historyFileName)
    }

    // MARK: - Local Cache Helpers

    private func loadLocalCache() {
        if let cachedBookmarks = FileStore.load([AlHaTorahBookmark].self, from: bookmarksFileName) {
            self.bookmarks = cachedBookmarks
        }
        if let cachedNotes = FileStore.load([AlHaTorahNote].self, from: notesFileName) {
            self.notes = cachedNotes
        }
        if let cachedHighlights = FileStore.load([AlHaTorahHighlight].self, from: highlightsFileName) {
            self.highlights = cachedHighlights
        }
        if let cachedHistory = FileStore.load([AlHaTorahHistoryItem].self, from: historyFileName) {
            self.historyItems = cachedHistory
        }
    }

    private func saveLocal<T: Encodable>(_ data: T, to fileName: String) {
        FileStore.save(data, to: fileName)
    }
}
