import SwiftUI

struct NativeNotesView: View {
    @ObservedObject var dataStore: AlHaTorahDataStore = .shared
    @ObservedObject var sessionStore: AlHaTorahSessionStore = .shared

    @State private var searchText = ""
    @State private var showingCreateSheet = false
    @State private var noteToDelete: AlHaTorahNote?
    @State private var showingDeleteAlert = false

    init() {}

    private var filteredNotes: [AlHaTorahNote] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return dataStore.notes
        }
        let query = searchText.lowercased()
        return dataStore.notes.filter { note in
            note.title.lowercased().contains(query) ||
            note.plainContent.lowercased().contains(query) ||
            note.location.displayTitle.lowercased().contains(query) ||
            note.location.book.lowercased().contains(query) ||
            note.location.parshan.lowercased().contains(query)
        }
    }

    private var headerCountText: String {
        let label = AppLocalization.text("notes.count_label", "הערות")
        return "\(filteredNotes.count) \(label)"
    }

    var body: some View {
        NavigationView {
            Group {
                if dataStore.notes.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            AppLocalization.text("notes.empty.title", "אין הערות"),
                            systemImage: "note.text",
                            description: Text(sessionStore.isLoggedIn
                                              ? AppLocalization.text("notes.empty.detail", "הערות אישיות (גליונות) שתוסיף יופיעו כאן.")
                                              : AppLocalization.text("notes.empty.login_detail", "התחבר לחשבון על־התורה כדי לסנכרן את ההערות שלך."))
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "note.text")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(AppLocalization.text("notes.empty.title", "אין הערות"))
                                .font(.title3.weight(.bold))
                            Text(sessionStore.isLoggedIn
                                 ? AppLocalization.text("notes.empty.detail", "הערות אישיות (גליונות) שתוסיף יופיעו כאן.")
                                 : AppLocalization.text("notes.empty.login_detail", "התחבר לחשבון על־התורה כדי לסנכרן את ההערות שלך."))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                } else {
                    List {
                        Section {
                            ForEach(filteredNotes) { note in
                                NavigationLink {
                                    NoteDetailView(note: note)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(note.title.isEmpty ? note.location.displayTitle : note.title)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Spacer()
                                        }

                                        Text(note.location.displayTitle)
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(.accentColor)

                                        if !note.plainContent.isEmpty {
                                            Text(note.plainContent)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        noteToDelete = note
                                        showingDeleteAlert = true
                                    } label: {
                                        Label(AppLocalization.text("common.delete", "מחיקה"), systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            if !filteredNotes.isEmpty {
                                Text(headerCountText)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(AppLocalization.text("tabs.notes", "הערות"))
            .searchable(text: $searchText, prompt: AppLocalization.text("notes.search_prompt", "חיפוש בהערות"))
            .refreshable {
                await dataStore.syncAll()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                NoteEditorSheet(mode: .create(initialLocation: nil, initialText: nil))
            }
            .confirmationDialog(
                AppLocalization.text("notes.delete_confirm_title", "מחיקת הערה"),
                isPresented: $showingDeleteAlert,
                titleVisibility: .visible,
                presenting: noteToDelete
            ) { note in
                Button(AppLocalization.text("common.delete", "מחק הערה"), role: .destructive) {
                    Task {
                        try? await dataStore.deleteNote(id: note.id)
                    }
                }
                Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
            } message: { note in
                Text(note.title.isEmpty ? note.location.displayTitle : note.title)
            }
        }
        .navigationViewStyle(.stack)
    }
}
