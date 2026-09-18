import SwiftUI
import SwiftData

@main
struct LifeOSApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            Habit.self,
            Account.self,
            BalanceSnapshot.self,
            Bill.self,
            Transaction.self,
            ScheduleItem.self,
            AppSettings.self,
            MailMailbox.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(ThemeController())
        }
        .modelContainer(sharedModelContainer)
    }
}
