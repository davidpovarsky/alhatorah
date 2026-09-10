import SwiftUI

struct NoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataStore: AlHaTorahDataStore = .shared

    enum Mode {
        case create(initialLocation: AlHaTorahLocation?, initialText: String?)
        case edit(note: AlHaTorahNote)
    }

    private let mode: Mode

    @State private var title: String
    @State private var content: String
    @State private var book: String
    @State private var unit: String
    @State private var subUnit: String
    @State private var parshan: String
    @State private var corpus: String

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let loc, let text):
            _title = State(initialValue: text?.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines).description ?? "")
            _content = State(initialValue: text ?? "")
            _book = State(initialValue: loc?.book ?? "Bereshit")
            _unit = State(initialValue: loc?.unit ?? "1")
            _subUnit = State(initialValue: String(loc?.subUnit ?? 1))
            _parshan = State(initialValue: loc?.parshan ?? "_mainVerse")
            _corpus = State(initialValue: loc?.mg ?? "Tanakh")
        case .edit(let note):
            _title = State(initialValue: note.title)
            _content = State(initialValue: note.plainContent)
            _book = State(initialValue: note.location.book)
            _unit = State(initialValue: note.location.unit)
            _subUnit = State(initialValue: String(note.location.subUnit))
            _parshan = State(initialValue: note.location.parshan)
            _corpus = State(initialValue: note.location.mg)
        }
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
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

                Section(header: Text(AppLocalization.text("notes.editor.title_header", "כותרת"))) {
                    TextField(AppLocalization.text("notes.editor.title_placeholder", "כותרת ההערה"), text: $title)
                }

                if !isEditMode {
                    Section(header: Text(AppLocalization.text("notes.editor.location_header", "מיקום בתורה / מפרש"))) {
                        HStack {
                            Text(AppLocalization.text("notes.editor.book", "ספר"))
                            Spacer()
                            TextField("Shemot", text: $book)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text(AppLocalization.text("notes.editor.chapter", "פרק / דף"))
                            Spacer()
                            TextField("1", text: $unit)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.asciiCapable)
                        }

                        HStack {
                            Text(AppLocalization.text("notes.editor.verse", "פסוק / קטע"))
                            Spacer()
                            TextField("1", text: $subUnit)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                        }

                        HStack {
                            Text(AppLocalization.text("notes.editor.parshan", "מפרש / מקור"))
                            Spacer()
                            TextField("_mainVerse", text: $parshan)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section(header: Text(AppLocalization.text("notes.editor.content_header", "תוכן ההערה"))) {
                    TextEditor(text: $content)
                        .frame(minHeight: 160)
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
                    let subUnitInt = Int(subUnit) ?? 1
                    let location = AlHaTorahLocation(
                        type: initialLoc?.type ?? "mg-full",
                        mg: corpus,
                        book: book,
                        unit: unit,
                        subUnit: subUnitInt,
                        parshan: parshan,
                        paragraph: initialLoc?.paragraph,
                        begin: initialLoc?.begin ?? 0,
                        end: initialLoc?.end ?? 0
                    )
                    _ = try await dataStore.createNote(
                        title: title.isEmpty ? location.displayTitle : title,
                        content: content,
                        location: location,
                        paragraph: location.paragraph,
                        begin: location.begin ?? 0,
                        end: location.end ?? 0
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
