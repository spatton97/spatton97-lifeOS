import Foundation
import SwiftData

// MARK: - Account type

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case checking
    case savings
    case credit
    case cash

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checking: return "Checking"
        case .savings: return "Savings"
        case .credit: return "Credit"
        case .cash: return "Cash"
        }
    }
}

// MARK: - Note

@Model
final class Note {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String = "", body: String = "", createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Habit

@Model
final class Habit {
    var id: UUID
    var name: String
    var isActive: Bool
    var sortOrder: Int
    /// Dates (start of day) when this habit was completed.
    var completedDayTimestamps: [Date]

    init(name: String, isActive: Bool = true, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.completedDayTimestamps = []
    }

    func isCompleted(on day: Date, calendar: Calendar = .current) -> Bool {
        let start = calendar.startOfDay(for: day)
        return completedDayTimestamps.contains { calendar.isDate($0, inSameDayAs: start) }
    }

    func toggleCompletion(on day: Date, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: day)
        if let idx = completedDayTimestamps.firstIndex(where: { calendar.isDate($0, inSameDayAs: start) }) {
            completedDayTimestamps.remove(at: idx)
        } else {
            completedDayTimestamps.append(start)
        }
    }

    /// Consecutive completed days ending today, or yesterday if today is not completed yet.
    func currentStreak(calendar: Calendar = .current, asOf day: Date = .now) -> Int {
        let today = calendar.startOfDay(for: day)
        var cursor = today
        if !isCompleted(on: today, calendar: calendar) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            cursor = yesterday
            if !isCompleted(on: cursor, calendar: calendar) { return 0 }
        }
        var count = 0
        while isCompleted(on: cursor, calendar: calendar) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// Longest run of consecutive completed days in history.
    func bestStreak(calendar: Calendar = .current) -> Int {
        let days = Set(completedDayTimestamps.map { calendar.startOfDay(for: $0) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var run = 1
        for i in 1..<days.count {
            let prev = days[i - 1]
            let cur = days[i]
            if let expected = calendar.date(byAdding: .day, value: 1, to: prev), calendar.isDate(expected, inSameDayAs: cur) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }
}

// MARK: - Account

@Model
final class Account {
    var id: UUID
    var name: String
    var typeRaw: String
    var currentBalance: Decimal
    var createdAt: Date

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .checking }
        set { typeRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .nullify, inverse: \Bill.linkedAccount)
    var bills: [Bill]?

    @Relationship(deleteRule: .cascade, inverse: \BalanceSnapshot.account)
    var snapshots: [BalanceSnapshot]?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction]?

    init(name: String, type: AccountType = .checking, currentBalance: Decimal = 0) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.currentBalance = currentBalance
        self.createdAt = .now
        self.bills = []
        self.snapshots = []
        self.transactions = []
    }
}

// MARK: - BalanceSnapshot

@Model
final class BalanceSnapshot {
    var id: UUID
    var amount: Decimal
    var date: Date
    var note: String
    var account: Account?

    init(amount: Decimal, date: Date = .now, note: String = "", account: Account? = nil) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.note = note
        self.account = account
    }
}

// MARK: - Bill

@Model
final class Bill {
    var id: UUID
    var name: String
    var amount: Decimal
    var dueDate: Date
    var isPaid: Bool
    var paidAt: Date?
    var linkedAccount: Account?
    /// Transaction created when this bill was marked paid (for undo).
    @Relationship(deleteRule: .nullify, inverse: \Transaction.relatedBill)
    var paymentTransaction: Transaction?

    init(
        name: String,
        amount: Decimal,
        dueDate: Date,
        isPaid: Bool = false,
        linkedAccount: Account? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.isPaid = isPaid
        self.paidAt = nil
        self.linkedAccount = linkedAccount
        self.paymentTransaction = nil
    }
}

// MARK: - Transaction

@Model
final class Transaction {
    var id: UUID
    var title: String
    var amount: Decimal
    /// Negative = money out / debit; positive = credit / income.
    var date: Date
    var account: Account?
    var relatedBill: Bill?
    var isUndone: Bool

    init(
        title: String,
        amount: Decimal,
        date: Date = .now,
        account: Account? = nil,
        relatedBill: Bill? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.date = date
        self.account = account
        self.relatedBill = relatedBill
        self.isUndone = false
    }
}

// MARK: - ScheduleItem

@Model
final class ScheduleItem {
    var id: UUID
    var title: String
    var start: Date
    var end: Date?
    var notes: String
    var isAllDay: Bool

    init(
        title: String,
        start: Date,
        end: Date? = nil,
        notes: String = "",
        isAllDay: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.start = start
        self.end = end
        self.notes = notes
        self.isAllDay = isAllDay
    }
}

// MARK: - AppSettings (singleton-style via query)

@Model
final class AppSettings {
    var id: UUID
    /// "system" | "light" | "dark"
    var themeRaw: String
    var colorBlindMode: Bool
    /// When true, require Face ID / device passcode before showing the app.
    var requireUnlock: Bool = false

    var themeMode: ThemeMode {
        get { ThemeMode(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    init(theme: ThemeMode = .system, colorBlindMode: Bool = false, requireUnlock: Bool = false) {
        self.id = UUID()
        self.themeRaw = theme.rawValue
        self.colorBlindMode = colorBlindMode
        self.requireUnlock = requireUnlock
    }
}
