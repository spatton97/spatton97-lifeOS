import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorBlindMode) private var colorBlind

    @Query(sort: \ScheduleItem.start) private var scheduleItems: [ScheduleItem]
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query(sort: \Bill.dueDate) private var bills: [Bill]
    @Query(sort: \BalanceSnapshot.date, order: .reverse) private var snapshots: [BalanceSnapshot]
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var showingAddSchedule = false
    @State private var showingBalanceCheckIn = false

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }

    private var hasTodaySnapshot: Bool {
        snapshots.contains { calendar.isDate($0.date, inSameDayAs: todayStart) }
    }

    private var netWorth: Decimal {
        accounts.reduce(0) { $0 + $1.currentBalance }
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private var todaysSchedule: [ScheduleItem] {
        scheduleItems.filter { calendar.isDate($0.start, inSameDayAs: todayStart) }
            .sorted { $0.start < $1.start }
    }

    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    private var unpaidBills: [Bill] {
        bills.filter { !$0.isPaid }
    }

    /// Unpaid bills sorted by due urgency: overdue → due today → soon (7d) → later.
    private var unpaidBillsByUrgency: [Bill] {
        unpaidBills.sorted { lhs, rhs in
            let l = dueUrgency(for: lhs)
            let r = dueUrgency(for: rhs)
            if l != r { return l.rawValue < r.rawValue }
            let ld = calendar.startOfDay(for: lhs.dueDate)
            let rd = calendar.startOfDay(for: rhs.dueDate)
            if ld != rd { return ld < rd }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var recentlyPaidToday: [Bill] {
        bills.filter { bill in
            guard bill.isPaid, let paidAt = bill.paidAt else { return false }
            return calendar.isDate(paidAt, inSameDayAs: todayStart)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if accounts.isEmpty {
                        Text("No accounts yet — add one in Finance.")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("Net position")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(netWorth, format: .currency(code: currencyCode))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(
                                    netWorth >= 0
                                    ? LifeOSAccent.success(colorBlind: colorBlind)
                                    : LifeOSAccent.warning(colorBlind: colorBlind)
                                )
                                .monospacedDigit()
                        }
                        ForEach(accounts) { account in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                    Text(account.type.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(account.currentBalance, format: .currency(code: currencyCode))
                                    .monospacedDigit()
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Balances")
                        Spacer()
                        if !accounts.isEmpty {
                            Button("Update") {
                                showingBalanceCheckIn = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(LifeOSAccent.success(colorBlind: colorBlind))
                            .accessibilityLabel("Update balances")
                        }
                    }
                } footer: {
                    balancesFooter
                }

                Section {
                    if todaysSchedule.isEmpty {
                        Text("Nothing scheduled")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(todaysSchedule) { item in
                            ScheduleRow(item: item)
                        }
                        .onDelete(perform: deleteSchedule)
                    }
                } header: {
                    HStack {
                        Text("Schedule")
                        Spacer()
                        Button {
                            showingAddSchedule = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add schedule item")
                    }
                }

                Section("Checklist") {
                    if activeHabits.isEmpty && unpaidBills.isEmpty {
                        Text("No habits or unpaid bills")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(activeHabits) { habit in
                        Button {
                            habit.toggleCompletion(on: todayStart)
                            try? modelContext.save()
                        } label: {
                            HStack {
                                Image(systemName: habit.isCompleted(on: todayStart) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(
                                        habit.isCompleted(on: todayStart)
                                        ? LifeOSAccent.success(colorBlind: colorBlind)
                                        : .secondary
                                    )
                                Text(habit.name)
                                    .foregroundStyle(.primary)
                                    .strikethrough(habit.isCompleted(on: todayStart))
                                Spacer()
                                Text("Habit")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(unpaidBillsByUrgency) { bill in
                        UnpaidBillRow(
                            bill: bill,
                            urgency: billDueUrgency(bill.dueDate, calendar: calendar, todayStart: todayStart),
                            currencyCode: currencyCode,
                            colorBlind: colorBlind
                        ) {
                            BillPaymentService.markPaid(bill, in: modelContext)
                        }
                    }

                    ForEach(recentlyPaidToday) { bill in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(LifeOSAccent.success(colorBlind: colorBlind))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bill.name)
                                    .strikethrough()
                                Text("Paid today")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Undo") {
                                BillPaymentService.undoPaid(bill, in: modelContext)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Image(systemName: "sun.max.fill")
                            .font(.title2)
                            .foregroundStyle(LifeOSAccent.warning(colorBlind: colorBlind))
                        Text("Today")
                            .font(.caption.weight(.semibold))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                ScheduleEditorSheet(item: nil)
            }
            .sheet(isPresented: $showingBalanceCheckIn) {
                DailyBalanceCheckInSheet(accounts: accounts)
            }
        }
    }

    @ViewBuilder
    private var balancesFooter: some View {
        if accounts.isEmpty {
            Text("Add an account in Finance, then Update here each day.")
        } else if !hasTodaySnapshot {
            Text("Tap Update to lock today's balances.")
        } else {
            Text("Balances checked in for today.")
        }
    }

    private func dueUrgency(for bill: Bill) -> BillDueUrgency {
        billDueUrgency(bill.dueDate, calendar: calendar, todayStart: todayStart)
    }

    private func deleteSchedule(at offsets: IndexSet) {

        for index in offsets {
            modelContext.delete(todaysSchedule[index])
        }
        try? modelContext.save()
    }
}

private enum BillDueUrgency: Int, Comparable {
    case overdue = 0
    case dueToday = 1
    case soon = 2
    case later = 3

    var isElevated: Bool { self == .overdue || self == .dueToday }

    static func < (lhs: BillDueUrgency, rhs: BillDueUrgency) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private func billDueUrgency(_ date: Date, calendar: Calendar, todayStart: Date) -> BillDueUrgency {
    let due = calendar.startOfDay(for: date)
    if due < todayStart { return .overdue }
    if due == todayStart { return .dueToday }
    let days = calendar.dateComponents([.day], from: todayStart, to: due).day ?? 0
    if days <= 7 { return .soon }
    return .later
}

private func billDueCaption(_ date: Date, urgency: BillDueUrgency, calendar: Calendar, todayStart: Date) -> String {
    let due = calendar.startOfDay(for: date)
    switch urgency {
    case .overdue:
        let days = calendar.dateComponents([.day], from: due, to: todayStart).day ?? 0
        if days <= 1 { return "Overdue · 1 day" }
        return "Overdue · \(days) days"
    case .dueToday:
        return "Due today"
    case .soon:
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Due \(formatter.localizedString(for: date, relativeTo: .now))"
    case .later:
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Due \(formatter.string(from: date))"
    }
}

private struct UnpaidBillRow: View {
    let bill: Bill
    let urgency: BillDueUrgency
    let currencyCode: String
    let colorBlind: Bool
    let onPay: () -> Void

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                Text(billDueCaption(bill.dueDate, urgency: urgency, calendar: calendar, todayStart: todayStart))
                    .font(.caption.weight(urgency.isElevated ? .semibold : .regular))
                    .foregroundStyle(captionColor)
            }
            Spacer()
            Text(bill.amount, format: .currency(code: currencyCode))
                .fontWeight(.medium)
            Button("Pay", action: onPay)
                .buttonStyle(.borderedProminent)
                .tint(LifeOSAccent.success(colorBlind: colorBlind))
                .controlSize(.small)
        }
    }

    private var captionColor: Color {
        switch urgency {
        case .overdue, .dueToday:
            return LifeOSAccent.warning(colorBlind: colorBlind)
        case .soon, .later:
            return .secondary
        }
    }
}

private struct ScheduleRow: View {
    let item: ScheduleItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.body.weight(.medium))
            HStack(spacing: 6) {
                if item.isAllDay {
                    Text("All day")
                } else {
                    Text(item.start, style: .time)
                    if let end = item.end {
                        Text("–")
                        Text(end, style: .time)
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct ScheduleEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: ScheduleItem?

    @State private var title: String = ""
    @State private var start: Date = .now
    @State private var end: Date = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
    @State private var hasEnd: Bool = true
    @State private var isAllDay: Bool = false
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Toggle("All day", isOn: $isAllDay)
                DatePicker("Starts", selection: $start, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                Toggle("End time", isOn: $hasEnd)
                if hasEnd {
                    DatePicker("Ends", selection: $end, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                }
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle(item == nil ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let item {
                    title = item.title
                    start = item.start
                    end = item.end ?? start
                    hasEnd = item.end != nil
                    isAllDay = item.isAllDay
                    notes = item.notes
                }
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item {
            item.title = trimmed
            item.start = start
            item.end = hasEnd ? end : nil
            item.isAllDay = isAllDay
            item.notes = notes
        } else {
            modelContext.insert(
                ScheduleItem(
                    title: trimmed,
                    start: start,
                    end: hasEnd ? end : nil,
                    notes: notes,
                    isAllDay: isAllDay
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }
}


struct DailyBalanceCheckInSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let accounts: [Account]

    @State private var drafts: [UUID: String] = [:]

    private var todayStart: Date {
        Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(accounts) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                Text(account.type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            TextField(
                                "0",
                                text: Binding(
                                    get: { drafts[account.id] ?? "" },
                                    set: { drafts[account.id] = $0 }
                                )
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                        }
                    }
                } header: {
                    Text("Today's balances")
                } footer: {
                    Text("Save updates each account and records a snapshot for today.")
                }
            }
            .navigationTitle("Update Balances")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(accounts.isEmpty)
                }
            }
            .onAppear {
                for account in accounts {
                    drafts[account.id] = NSDecimalNumber(decimal: account.currentBalance).stringValue
                }
            }
        }
    }

    private func save() {
        for account in accounts {
            let raw = (drafts[account.id] ?? "")
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let amount = Decimal(string: raw) ?? account.currentBalance
            account.currentBalance = amount
            modelContext.insert(
                BalanceSnapshot(
                    amount: amount,
                    date: todayStart,
                    note: "Daily check-in",
                    account: account
                )
            )
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [
            Note.self, Habit.self, Account.self, BalanceSnapshot.self,
            Bill.self, Transaction.self, ScheduleItem.self, AppSettings.self
        ], inMemory: true)
}
