import SwiftUI

public struct MainTabView: View {
    @ObservedObject var coordinator: AppCoordinator = .shared
    @ObservedObject var sessionStore: AlHaTorahSessionStore = .shared
    @ObservedObject var dataStore: AlHaTorahDataStore = .shared

    public init() {}

    public var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            // Tab 1: אתר (Reader WKWebView)
            ReaderTabView()
                .tabItem {
                    Label(AppLocalization.text("tabs.reader", "אתר"), systemImage: "globe")
                }
                .tag(AppTab.reader)

            // Tab 2: היסטוריה (History)
            NativeHistoryView()
                .tabItem {
                    Label(AppLocalization.text("tabs.history", "היסטוריה"), systemImage: "clock")
                }
                .tag(AppTab.history)

            // Tab 3: סימניות (Bookmarks)
            NativeBookmarksView()
                .tabItem {
                    Label(AppLocalization.text("tabs.bookmarks", "סימניות"), systemImage: "bookmark")
                }
                .tag(AppTab.bookmarks)

            // Tab 4: הערות (Notes)
            NativeNotesView()
                .tabItem {
                    Label(AppLocalization.text("tabs.notes", "הערות"), systemImage: "note.text")
                }
                .tag(AppTab.notes)

            // Tab 5: חיפוש (Search)
            NativeSearchView()
                .tabItem {
                    Label(AppLocalization.text("tabs.search", "חיפוש"), systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)

            // Tab 6: הגדרות (Settings)
            NativeSettingsView()
                .tabItem {
                    Label(AppLocalization.text("tabs.settings", "הגדרות"), systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .environment(\.layoutDirection, AppLocalization.isHebrew ? .rightToLeft : .leftToRight)
    }
}
