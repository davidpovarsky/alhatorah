import SwiftUI

struct NoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataStore: AlHaTorahDataStore = .shared

    enum Mode {
        case create(initialLocation: AlHaTorahLocation?, initialText: String?)
        case edit(note: AlHaTorahNote)
    }

    private let mode: Mode
    private let targetLocation: AlHaTorahLocation

    @State private var title: String
    @State private var content: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let loc, let text):
            let location = loc ?? AlHaTorahLocation(book: "Bereshit", unit: "1", subUnit: 1)
            self.targetLocation = location
            _title = State(initialValue: "")
            _content = State(initialValue: text ?? "")
        case .edit(let note):
            self.targetLocation = note.location
            _title = State(initialValue: note.title)
            _content = State(initialValue: note.plainContent)
        }
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var humanReadableLocation: String {
        targetLocation.displayTitle
    }

    var body: some View {
        NavigationView {
            Form {
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }

                Section(header: Text(AppLocalization.text("notes.editor.location_header", "מיקום"))) {
                    HStack {
                        Text(AppLocalization.text("notes.editor.location", "מקור בתורה"))
                        Spacer()
                        Text(humanReadableLocation)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if !isEditMode {
                    Section(header: Text(AppLocalization.text("notes.editor.title_header", "כותרת (אופציונלי)"))) {
                        TextField(humanReadableLocation, text: $title)
                    }
                }

                Section(header: Text(AppLocalization.text("notes.editor.content_header", "תוכן ההערה"))) {
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                }
            }
            .navigationTitle(isEditMode
                             ? AppLocalization.text("notes.editor.edit_title", "עריכת הערה")
                             : AppLocalization.text("notes.editor.new_title", "הערה חדשה"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.text("common.cancel", "ביטול")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(AppLocalization.text("common.save", "שמור")) {
                            saveNote()
                        }
                        .font(.body.weight(.bold))
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func saveNote() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                switch mode {
                case .create(let initialLoc, _):
                    var loc = targetLocation
                    if let initialLoc = initialLoc {
                        loc.paragraph = initialLoc.paragraph
                        loc.begin = initialLoc.begin
                        loc.end = initialLoc.end
                    }
                    let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? loc.displayTitle : title
                    _ = try await dataStore.createNote(
                        title: finalTitle,
                        content: content,
                        location: loc,
                        paragraph: loc.paragraph,
                        begin: loc.begin ?? 0,
                        end: loc.end ?? 0
                    )
                case .edit(let existingNote):
                    try await dataStore.editNote(id: existingNote.id, content: content)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
