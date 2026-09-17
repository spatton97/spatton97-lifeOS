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
                            Text(netWorth, format: .currency(code: lifeOSCurrencyCode))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(
                                    netWorth >= 0
                                    ? LifeOSAccent.success(colorBlind: colorBlind)
                                    : LifeOSAccent.danger(colorBlind: colorBlind)
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
                                Text(account.currentBalance, format: .currency(code: lifeOSCurrencyCode))
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
                                HabitStreakCapsule(streak: habit.currentStreak(asOf: todayStart))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(unpaidBillsByUrgency) { bill in
                        UnpaidBillRow(
                            bill: bill,
                            urgency: billDueUrgency(bill.dueDate, calendar: calendar, todayStart: todayStart),
                            currencyCode: lifeOSCurrencyCode,
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image(systemName: "sun.max.fill")
                        .font(.title2)
                        .foregroundStyle(LifeOSAccent.warning(colorBlind: colorBlind))
                        .accessibilityLabel("Today")
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

#Preview {
    TodayView()
        .modelContainer(for: [
            Note.self, Habit.self, Account.self, BalanceSnapshot.self,
            Bill.self, Transaction.self, ScheduleItem.self, AppSettings.self
        ], inMemory: true)
}
