import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var showingAdd = false
    @State private var editing: Note?

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Capture ideas, lists, and reminders. Everything stays on this device.")
                    )
                } else {
                    List {
                        ForEach(notes) { note in
                            Button {
                                editing = note
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title.isEmpty ? "Untitled" : note.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if !note.body.isEmpty {
                                        Text(note.body)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Text(note.updatedAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete(perform: deleteNotes)
                    }
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add note")
                }
            }
            .sheet(isPresented: $showingAdd) {
                NoteEditorSheet(note: nil)
            }
            .sheet(item: $editing) { note in
                NoteEditorSheet(note: note)
            }
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(notes[i])
        }
        try? modelContext.save()
    }
}

struct NoteEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let note: Note?

    @State private var title = ""
    @State private var bodyText = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Body", text: $bodyText, axis: .vertical)
                    .lineLimit(8...20)
            }
            .navigationTitle(note == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                if let note {
                    title = note.title
                    bodyText = note.body
                }
            }
        }
    }

    private func save() {
        if let note {
            note.title = title
            note.body = bodyText
            note.updatedAt = .now
        } else {
            modelContext.insert(Note(title: title, body: bodyText))
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NotesView()
        .modelContainer(for: [Note.self], inMemory: true)
}
