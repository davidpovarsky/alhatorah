import SwiftUI

struct NativeSearchView: View {
    @ObservedObject var coordinator: AppCoordinator = .shared

    @State private var searchText = ""
    @State private var allItems: [BookIndexItem] = []
    @State private var isLoadingIndex = false
    @State private var selectedFilter: SearchFilter = .all

    enum SearchFilter: String, CaseIterable, Identifiable {
        case all = "all"
        case tanakh = "tanakh"
        case shas = "shas"
        case commentators = "commentators"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return AppLocalization.text("search.filter.all", "הכל")
            case .tanakh: return AppLocalization.text("search.filter.tanakh", "תנ\"ך")
            case .shas: return AppLocalization.text("search.filter.shas", "ש\"ס")
            case .commentators: return AppLocalization.text("search.filter.commentators", "מפרשים")
            }
        }
    }

    init() {}

    private var filteredResults: [BookIndexItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return Array(allItems.prefix(40))
        }

        return Array(allItems.lazy.filter { item in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .tanakh:
                matchesFilter = item.categoryTitles.contains { $0.contains("תנ\"ך") || $0.contains("Tanakh") }
            case .shas:
                matchesFilter = item.categoryTitles.contains { $0.contains("ש\"ס") || $0.contains("Shas") || $0.contains("בבלי") }
            case .commentators:
                matchesFilter = item.categoryTitles.contains { $0.contains("מפרש") || $0.contains("Commentar") }
            }
            guard matchesFilter else { return false }

            let searchable = ([item.id, item.titleHe, item.titleEn, item.searchableText] + item.aliases + item.categoryTitles + item.sectionNames)
                .joined(separator: " ")
                .lowercased()
            return searchable.contains(query)
        }.prefix(60))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("סינון", selection: $selectedFilter) {
                    ForEach(SearchFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

                List {
                    // Web search shortcut section when there's a search term
                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section {
                            Button {
                                performAlHaTorahWebSearch(query: searchText)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(AppLocalization.text("search.web_search_title", "חיפוש בטקסט על־התורה"))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("\"\(searchText)\"")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.footnote)
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            Text(AppLocalization.text("search.web_search_header", "חיפוש טקסט מלא"))
                        }
                    }

                    // Book & Source Index Results
                    Section {
                        if filteredResults.isEmpty && !searchText.isEmpty {
                            Text(AppLocalization.text("search.no_results", "לא נמצאו מקורות באינדקס"))
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(filteredResults, id: \.id) { item in
                                Button {
                                    openBookItem(item)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "book")
                                            .foregroundColor(.secondary)
                                            .font(.body)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(primaryTitle(for: item))
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            let sec = secondaryTitle(for: item)
                                            if !sec.isEmpty {
                                                Text(sec)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.backward")
                                            .font(.footnote)
                                            .foregroundColor(Color(UIColor.tertiaryLabel))
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    } header: {
                        Text(AppLocalization.text("search.index_header", "אינדקס ספרים ומקורות"))
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(AppLocalization.text("tabs.search", "חיפוש"))
            .searchable(text: $searchText, prompt: AppLocalization.text("search.prompt", "חיפוש ספר, מסכת, מפרש..."))
            .onAppear {
                loadIndexIfNeeded()
            }
        }
        .navigationViewStyle(.stack)
    }

    private func loadIndexIfNeeded() {
        guard allItems.isEmpty else { return }
        if let bundle = RefPHPStore.shared.readCachedBundle() {
            self.allItems = bundle.booksIndex
        } else {
            isLoadingIndex = true
            SpotlightIndexManager.shared.refreshIfNeeded(force: false) { result in
                DispatchQueue.main.async {
                    self.isLoadingIndex = false
                    if case .success = result, let bundle = RefPHPStore.shared.readCachedBundle() {
                        self.allItems = bundle.booksIndex
                    }
                }
            }
        }
    }

    private func openBookItem(_ item: BookIndexItem) {
        let identifier = SpotlightIndexManager.shared.spotlightIdentifier(for: item.id)
        SpotlightIndexManager.shared.urlForSpotlightIdentifier(identifier) { url in
            DispatchQueue.main.async {
                if let url {
                    coordinator.openInReader(url: url)
                } else if let fallbackURL = URL(string: "https://mg.alhatorah.org/Full/Tanakh/\(item.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.id)/1.1") {
                    coordinator.openInReader(url: fallbackURL)
                }
            }
        }
    }

    private func performAlHaTorahWebSearch(query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let url = URL(string: "https://mg.alhatorah.org/Search?q=\(encoded)") {
            coordinator.openInReader(url: url)
        }
    }

    private func primaryTitle(for item: BookIndexItem) -> String {
        if AppLocalization.isHebrew {
            return item.titleHe.isEmpty ? item.titleEn : item.titleHe
        }
        return item.titleEn.isEmpty ? item.titleHe : item.titleEn
    }

    private func secondaryTitle(for item: BookIndexItem) -> String {
        var parts = [item.id]
        if !item.titleHe.isEmpty, item.titleHe != primaryTitle(for: item) { parts.append(item.titleHe) }
        if !item.titleEn.isEmpty, item.titleEn != primaryTitle(for: item) { parts.append(item.titleEn) }
        if !item.sectionNames.isEmpty { parts.append(item.sectionNames.prefix(2).joined(separator: " / ")) }
        return parts.filter { !$0.isEmpty }.joined(separator: " • ")
    }
}
