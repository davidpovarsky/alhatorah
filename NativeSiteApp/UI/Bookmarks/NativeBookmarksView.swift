import SwiftUI

public struct NativeBookmarksView: View {
    @ObservedObject var dataStore: AlHaTorahDataStore = .shared
    @ObservedObject var coordinator: AppCoordinator = .shared
    @ObservedObject var sessionStore: AlHaTorahSessionStore = .shared

    @State private var searchText = ""
    @State private var itemToDelete: AlHaTorahBookmark?
    @State private var showingDeleteAlert = false

    public init() {}

    private var filteredBookmarks: [AlHaTorahBookmark] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return dataStore.bookmarks
        }
        let query = searchText.lowercased()
        return dataStore.bookmarks.filter { bookmark in
            bookmark.displayTitle.lowercased().contains(query) ||
            bookmark.displayTitleEn.lowercased().contains(query) ||
            bookmark.location.book.lowercased().contains(query) ||
            bookmark.location.parshan.lowercased().contains(query)
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if dataStore.bookmarks.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            AppLocalization.text("bookmarks.empty.title", "אין סימניות"),
                            systemImage: "bookmark",
                            description: Text(sessionStore.isLoggedIn
                                              ? AppLocalization.text("bookmarks.empty.detail", "סמן פסוקים או מקורות בקורא כדי לשמור אותם כאן.")
                                              : AppLocalization.text("bookmarks.empty.login_detail", "התחבר לחשבון על־התורה כדי לסנכרן את הסימניות שלך."))
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(AppLocalization.text("bookmarks.empty.title", "אין סימניות"))
                                .font(.title3.bold())
                            Text(sessionStore.isLoggedIn
                                 ? AppLocalization.text("bookmarks.empty.detail", "סמן פסוקים או מקורות בקורא כדי לשמור אותם כאן.")
                                 : AppLocalization.text("bookmarks.empty.login_detail", "התחבר לחשבון על־התורה כדי לסנכרן את הסימניות שלך."))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                } else {
                    List {
                        Section {
                            ForEach(filteredBookmarks) { bookmark in
                                Button {
                                    coordinator.openInReader(location: bookmark.location)
                                } label: {
                                    HStack(alignment: .center, spacing: 12) {
                                        Image(systemName: "bookmark.fill")
                                            .foregroundColor(.accentColor)
                                            .font(.body)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(bookmark.displayTitle)
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            if !bookmark.displayTitleEn.isEmpty && bookmark.displayTitleEn != bookmark.displayTitle {
                                                Text(bookmark.displayTitleEn)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.backward")
                                            .font(.footnote)
                                            .foregroundColor(.tertiaryLabel)
                                    }
                                    .padding(.vertical, 2)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        itemToDelete = bookmark
                                        showingDeleteAlert = true
                                    } label: {
                                        Label(AppLocalization.text("common.delete", "מחיקה"), systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            if !filteredBookmarks.isEmpty {
                                Text("\(filteredBookmarks.count) " + AppLocalization.text("bookmarks.count_label", "סימניות"))
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(AppLocalization.text("tabs.bookmarks", "סימניות"))
            .searchable(text: $searchText, prompt: AppLocalization.text("bookmarks.search_prompt", "חיפוש בסימניות"))
            .refreshable {
                await dataStore.syncAll()
            }
            .confirmationDialog(
                AppLocalization.text("bookmarks.delete_confirm_title", "מחיקת סימניה"),
                isPresented: $showingDeleteAlert,
                titleVisibility: .visible,
                presenting: itemToDelete
            ) { bookmark in
                Button(AppLocalization.text("common.delete", "מחק"), role: .destructive) {
                    Task {
                        try? await dataStore.removeBookmark(id: bookmark.id)
                    }
                }
                Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
            } message: { bookmark in
                Text(bookmark.displayTitle)
            }
        }
    }
}
