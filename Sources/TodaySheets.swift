import SwiftUI
import SwiftData

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
