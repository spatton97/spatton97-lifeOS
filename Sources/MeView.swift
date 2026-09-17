import SwiftUI
import SwiftData

struct MeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeController
    @Environment(\.colorBlindMode) private var colorBlind

    @Query private var settingsList: [AppSettings]
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var showingAddHabit = false
    @State private var editingHabit: Habit?
    @State private var sampleConfirm = false

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habits") {
                    if habits.isEmpty {
                        Text("No habits yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(habits) { habit in
                        Button {
                            editingHabit = habit
                        } label: {
                            HStack {
                                Text(habit.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if !habit.isActive {
                                    Text("Paused")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteHabits)
                    .onMove(perform: moveHabits)

                    Button {
                        showingAddHabit = true
                    } label: {
                        Label("Add Habit", systemImage: "plus.circle")
                    }
                }

                Section {
                    Picker("Appearance", selection: themeModeBinding) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    Toggle("Color-blind friendly accents", isOn: colorBlindBinding)
                } header: {
                    Text("Theme")
                } footer: {
                    Text("Uses system light/dark unless overridden. Color-blind mode swaps accent hues for stronger contrast.")
                }

                Section {
                    Toggle("Require Face ID / Passcode", isOn: requireUnlockBinding)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("When on, LifeOS asks for Face ID or your device passcode on launch and after the app goes to the background. Off by default.")
                }

                Section("Data") {
                    Button {
                        sampleConfirm = true
                    } label: {
                        Label("Add sample data", systemImage: "square.and.arrow.down")
                    }
                }

                Section {
                    LabeledContent("App", value: "LifeOS")
                    LabeledContent("Working name", value: "2do4you")
                    LabeledContent("Storage", value: "On-device SwiftData")
                } header: {
                    Text("About")
                } footer: {
                    Text("Local-first. No Plaid, no IAP, no mail OAuth in v1.")
                }
            }
            .navigationTitle("Me")
            .toolbar {
                EditButton()
            }
            .sheet(isPresented: $showingAddHabit) {
                HabitEditorSheet(habit: nil, nextSortOrder: (habits.map(\.sortOrder).max() ?? -1) + 1)
            }
            .sheet(item: $editingHabit) { habit in
                HabitEditorSheet(habit: habit, nextSortOrder: habit.sortOrder)
            }
            .confirmationDialog(
                "Add sample accounts, bills, habits, and a note?",
                isPresented: $sampleConfirm,
                titleVisibility: .visible
            ) {
                Button("Add sample data") {
                    SampleDataSeeder.seed(in: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { ensureSettings() }
        }
    }

    private var themeModeBinding: Binding<ThemeMode> {
        Binding(
            get: { theme.mode },
            set: { newValue in
                theme.mode = newValue
                persistTheme()
            }
        )
    }

    private var colorBlindBinding: Binding<Bool> {
        Binding(
            get: { theme.colorBlindMode },
            set: { newValue in
                theme.colorBlindMode = newValue
                persistTheme()
            }
        )
    }

    private var requireUnlockBinding: Binding<Bool> {
        Binding(
            get: { settings?.requireUnlock ?? false },
            set: { newValue in
                ensureSettings()
                settings?.requireUnlock = newValue
                try? modelContext.save()
            }
        )
    }

    private func ensureSettings() {
        if settingsList.isEmpty {
            let s = AppSettings()
            modelContext.insert(s)
            try? modelContext.save()
            theme.sync(from: s)
        } else {
            theme.sync(from: settings)
        }
    }

    private func persistTheme() {
        ensureSettings()
        if let settings {
            theme.apply(to: settings)
            try? modelContext.save()
        }
    }

    private func deleteHabits(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(habits[i])
        }
        try? modelContext.save()
    }

    private func moveHabits(from source: IndexSet, to destination: Int) {
        var ordered = habits
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in ordered.enumerated() {
            habit.sortOrder = index
        }
        try? modelContext.save()
    }
}

struct HabitEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let habit: Habit?
    let nextSortOrder: Int

    @State private var name = ""
    @State private var isActive = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Toggle("Active on Today", isOn: $isActive)
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let habit {
                    name = habit.name
                    isActive = habit.isActive
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let habit {
            habit.name = trimmed
            habit.isActive = isActive
        } else {
            modelContext.insert(Habit(name: trimmed, isActive: isActive, sortOrder: nextSortOrder))
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    MeView()
        .modelContainer(for: [
            Note.self, Habit.self, Account.self, BalanceSnapshot.self,
            Bill.self, Transaction.self, ScheduleItem.self, AppSettings.self
        ], inMemory: true)
        .environmentObject(ThemeController())
}
