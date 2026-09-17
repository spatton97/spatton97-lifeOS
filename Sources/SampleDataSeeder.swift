import Foundation
import SwiftData

enum SampleDataSeeder {
    @MainActor
    static func seed(in context: ModelContext) {
        let checking = Account(name: "Everyday Checking", type: .checking, currentBalance: 2_450.00)
        let savings = Account(name: "Emergency Savings", type: .savings, currentBalance: 8_000.00)
        let credit = Account(name: "Rewards Card", type: .credit, currentBalance: -320.50)
        context.insert(checking)
        context.insert(savings)
        context.insert(credit)

        let today = Calendar.current.startOfDay(for: .now)
        context.insert(BalanceSnapshot(amount: checking.currentBalance, date: today, note: "Opening", account: checking))

        let rentDue = Calendar.current.date(byAdding: .day, value: 3, to: today) ?? today
        let electricDue = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        context.insert(Bill(name: "Rent", amount: 1_450, dueDate: rentDue, linkedAccount: checking))
        context.insert(Bill(name: "Electric", amount: 85.40, dueDate: electricDue, linkedAccount: checking))

        context.insert(Habit(name: "Morning stretch", sortOrder: 0))
        context.insert(Habit(name: "Read 20 min", sortOrder: 1))
        context.insert(Habit(name: "No late caffeine", sortOrder: 2))

        let meetingStart = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
        let meetingEnd = Calendar.current.date(byAdding: .hour, value: 1, to: meetingStart)
        context.insert(ScheduleItem(title: "Team standup", start: meetingStart, end: meetingEnd))
        context.insert(ScheduleItem(title: "Focus block", start: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: .now) ?? .now, end: nil))

        context.insert(Note(title: "Welcome to LifeOS", body: "Local-first life OS. Add notes, track bills, and own your day.\n\nWorking name: 2do4you"))
        context.insert(Transaction(title: "Coffee", amount: -4.75, account: checking))

        try? context.save()
    }
}
