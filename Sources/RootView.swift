import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeController
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsList: [AppSettings]
    @StateObject private var appLock = AppLockController()

    private var settings: AppSettings? { settingsList.first }
    private var lockEnabled: Bool { settings?.requireUnlock == true }

    var body: some View {
        ZStack {
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

                FinanceView()
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
            .disabled(lockEnabled && !appLock.isUnlocked)

            if lockEnabled && !appLock.isUnlocked {
                LockScreenView(message: appLock.statusMessage) {
                    Task { await appLock.authenticate() }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            ensureSettings()
            theme.sync(from: settings)
            Task { await appLock.apply(enabled: lockEnabled) }
        }
        .onChange(of: settingsList.first?.themeRaw) { _, _ in
            theme.sync(from: settings)
        }
        .onChange(of: settingsList.first?.colorBlindMode) { _, _ in
            theme.sync(from: settings)
        }
        .onChange(of: settingsList.first?.requireUnlock) { _, newValue in
            Task { await appLock.apply(enabled: newValue == true) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, lockEnabled {
                appLock.lock()
            }
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
