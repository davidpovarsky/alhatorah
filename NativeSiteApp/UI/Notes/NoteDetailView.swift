import SwiftUI

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataStore: AlHaTorahDataStore = .shared
    @ObservedObject var coordinator: AppCoordinator = .shared

    let note: AlHaTorahNote

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    init(note: AlHaTorahNote) {
        self.note = note
    }

    private var currentNote: AlHaTorahNote {
        dataStore.notes.first(where: { $0.id == note.id }) ?? note
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header location card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(currentNote.location.displayTitle)
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        Spacer()
                        if currentNote.location.isCommentary {
                            Text(currentNote.location.parshan)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }

                    if !currentNote.location.displayTitleEn.isEmpty &&
                        currentNote.location.displayTitleEn != currentNote.location.displayTitle {
                        Text(currentNote.location.displayTitleEn)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(12)

                // Note Content
                VStack(alignment: .leading, spacing: 10) {
                    Text(currentNote.title)
                        .font(.title2.weight(.bold))

                    Divider()

                    Text(currentNote.plainContent)
                        .font(.body)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 4)

                Spacer(minLength: 24)

                // Open in reader action button
                Button {
                    coordinator.openInReader(location: currentNote.location)
                } label: {
                    Label(AppLocalization.text("notes.open_in_reader", "פתח בקורא על־התורה"), systemImage: "book.pages")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle(AppLocalization.text("notes.detail_title", "הערה"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label(AppLocalization.text("common.edit", "ערוך"), systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label(AppLocalization.text("common.delete", "מחק"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NoteEditorSheet(mode: .edit(note: currentNote))
        }
        .confirmationDialog(
            AppLocalization.text("notes.delete_confirm_title", "מחיקת הערה"),
            isPresented: $showingDeleteAlert,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("common.delete", "מחק הערה"), role: .destructive) {
                Task {
                    try? await dataStore.deleteNote(id: currentNote.id)
                    dismiss()
                }
            }
            Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
        } message: {
            Text(AppLocalization.text("notes.delete_confirm_message", "האם למחוק הערה זו לצמיתות?"))
        }
    }
}
