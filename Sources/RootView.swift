import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeController
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        TabView {
            MailPlaceholderView()
                .tabItem {
                    Label("Mail", systemImage: "envelope")
                }

            NotesView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }

            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }

            FinanceViews()
                .tabItem {
                    Label("Finance", systemImage: "dollarsign.circle")
                }

            MeView()
                .tabItem {
                    Label("Me", systemImage: "person.crop.circle")
                }
        }
        .lifeOSTheme(mode: theme.mode, colorBlind: theme.colorBlindMode)
        .tint(LifeOSAccent.primary(colorBlind: theme.colorBlindMode))
        .onAppear {
            ensureSettings()
            theme.sync(from: settings)
        }
        .onChange(of: settingsList.first?.themeRaw) { _, _ in
            theme.sync(from: settings)
        }
        .onChange(of: settingsList.first?.colorBlindMode) { _, _ in
            theme.sync(from: settings)
        }
    }

    private func ensureSettings() {
        guard settingsList.isEmpty else { return }
        let s = AppSettings()
        modelContext.insert(s)
        try? modelContext.save()
        theme.sync(from: s)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [
            Note.self, Habit.self, Account.self, BalanceSnapshot.self,
            Bill.self, Transaction.self, ScheduleItem.self, AppSettings.self
        ], inMemory: true)
        .environmentObject(ThemeController())
}
