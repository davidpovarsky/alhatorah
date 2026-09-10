import SwiftUI

struct NativeHistoryView: View {
    @ObservedObject var dataStore: AlHaTorahDataStore = .shared
    @ObservedObject var coordinator: AppCoordinator = .shared
    @ObservedObject var sessionStore: AlHaTorahSessionStore = .shared

    @State private var searchText = ""
    @State private var itemToDelete: AlHaTorahHistoryItem?
    @State private var showingDeleteAlert = false
    @State private var showingClearAlert = false

    init() {}

    private var filteredItems: [AlHaTorahHistoryItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return dataStore.historyItems
        }
        let query = searchText.lowercased()
        return dataStore.historyItems.filter { item in
            item.title.lowercased().contains(query) ||
            item.displayCorpus.lowercased().contains(query) ||
            (item.commentator?.lowercased().contains(query) ?? false) ||
            item.urlString.lowercased().contains(query)
        }
    }

    private var headerCountText: String {
        let label = AppLocalization.text("history.count_label", "פריטים")
        return "\(filteredItems.count) \(label)"
    }

    var body: some View {
        NavigationView {
            Group {
                if dataStore.historyItems.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            AppLocalization.text("history.empty.title", "אין היסטוריה"),
                            systemImage: "clock",
                            description: Text(sessionStore.isLoggedIn
                                              ? AppLocalization.text("history.empty.detail", "דפים ומקורות שקראת באתר יופיעו כאן.")
                                              : AppLocalization.text("history.empty.login_detail", "התחבר לחשבון על־התורה כדי לסנכרן את היסטוריית הקריאה שלך."))
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(AppLocalization.text("history.empty.title", "אין היסטוריה"))
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(sessionStore.isLoggedIn
                                 ? AppLocalization.text("history.empty.detail", "דפים ומקורות שקראת באתר יופיעו כאן.")
                                 : AppLocalization.text("history.empty.login_detail", "התחבר לחשבון על־התורה כדי לסנכרן את היסטוריית הקריאה שלך."))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                } else {
                    List {
                        Section {
                            ForEach(filteredItems) { item in
                                Button {
                                    if let url = item.url {
                                        coordinator.openInReader(url: url)
                                    }
                                } label: {
                                    HStack(alignment: .center, spacing: 12) {
                                        Image(systemName: "clock")
                                            .foregroundColor(.secondary)
                                            .font(.body)

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(item.title)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)

                                                if let comm = item.commentator, !comm.isEmpty {
                                                    Text("• \(comm)")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }
                                            }

                                            HStack(spacing: 8) {
                                                Text(item.displayCorpus)
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.15))
                                                    .cornerRadius(4)

                                                Text(DateFormatting.short.string(from: item.visitedAt))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.backward")
                                            .font(.footnote)
                                            .foregroundColor(Color(UIColor.tertiaryLabel))
                                    }
                                    .padding(.vertical, 2)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                        showingDeleteAlert = true
                                    } label: {
                                        Label(AppLocalization.text("common.delete", "מחיקה"), systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            if !filteredItems.isEmpty {
                                Text(headerCountText)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(AppLocalization.text("tabs.history", "היסטוריה"))
            .searchable(text: $searchText, prompt: AppLocalization.text("history.search_prompt", "חיפוש בהיסטוריה"))
            .refreshable {
                await dataStore.syncAll()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !dataStore.historyItems.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                showingClearAlert = true
                            } label: {
                                Label(AppLocalization.text("history.clear_all", "נקה היסטוריה"), systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog(
                AppLocalization.text("history.delete_confirm_title", "מחיקת פריט היסטוריה"),
                isPresented: $showingDeleteAlert,
                titleVisibility: .visible,
                presenting: itemToDelete
            ) { item in
                Button(AppLocalization.text("common.delete", "מחק"), role: .destructive) {
                    Task {
                        try? await dataStore.deleteHistoryItem(id: item.id)
                    }
                }
                Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
            } message: { item in
                Text(item.title)
            }
            .confirmationDialog(
                AppLocalization.text("history.clear_confirm_title", "ניקוי היסטוריה"),
                isPresented: $showingClearAlert,
                titleVisibility: .visible
            ) {
                Button(AppLocalization.text("history.clear_all_action", "נקה את כל ההיסטוריה"), role: .destructive) {
                    dataStore.clearAllHistory()
                }
                Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
            } message: {
                Text(AppLocalization.text("history.clear_confirm_message", "האם למחוק את כל פריטי ההיסטוריה מחשבונך?"))
            }
        }
        .navigationViewStyle(.stack)
    }
}
