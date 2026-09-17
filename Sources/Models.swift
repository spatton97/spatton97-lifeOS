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

// MARK: - Bill pay / undo helpers

enum BillPaymentService {
    /// Mark bill paid, debit linked account if present, create transaction.
    @MainActor
    static func markPaid(_ bill: Bill, in context: ModelContext) {
        guard !bill.isPaid else { return }
        bill.isPaid = true
        bill.paidAt = .now

        let debitAmount = -bill.amount
        let tx = Transaction(
            title: "Bill: \(bill.name)",
            amount: debitAmount,
            date: .now,
            account: bill.linkedAccount,
            relatedBill: bill
        )
        context.insert(tx)
        bill.paymentTransaction = tx

        if let account = bill.linkedAccount {
            // Credit accounts: paying a bill often increases available credit;
            // for simplicity, all account types: subtract amount (money leaving).
            account.currentBalance += debitAmount
        }
        try? context.save()
    }

    /// Undo payment: restore bill, reverse balance, mark/remove transaction.
    @MainActor
    static func undoPaid(_ bill: Bill, in context: ModelContext) {
        guard bill.isPaid else { return }
        if let tx = bill.paymentTransaction {
            if let account = tx.account {
                // Reverse the debit
                account.currentBalance -= tx.amount
            }
            tx.isUndone = true
            context.delete(tx)
            bill.paymentTransaction = nil
        }
        bill.isPaid = false
        bill.paidAt = nil
        try? context.save()
    }
}

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
