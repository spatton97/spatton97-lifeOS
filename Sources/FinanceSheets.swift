import SwiftUI
import SwiftData

struct AccountEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: Account?

    @State private var name = ""
    @State private var type: AccountType = .checking
    @State private var balanceText = "0"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                TextField("Balance", text: $balanceText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle(account == nil ? "New Account" : "Edit Account")
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
                if let account {
                    name = account.name
                    type = account.type
                    balanceText = NSDecimalNumber(decimal: account.currentBalance).stringValue
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let balance = Decimal(string: balanceText.replacingOccurrences(of: ",", with: "")) ?? 0
        let saved: Account
        if let account {
            account.name = trimmed
            account.type = type
            account.currentBalance = balance
            saved = account
        } else {
            let created = Account(name: trimmed, type: type, currentBalance: balance)
            modelContext.insert(created)
            saved = created
        }
        // Keep Today in sync: account save counts as today's balance check-in.
        modelContext.insert(
            BalanceSnapshot(
                amount: balance,
                date: Calendar.current.startOfDay(for: .now),
                note: "Account update",
                account: saved
            )
        )
        try? modelContext.save()
        dismiss()
    }
}

struct BillEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    let bill: Bill?

    @State private var name = ""
    @State private var amountText = ""
    @State private var dueDate = Date()
    @State private var linkedAccountID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                Picker("Linked account", selection: $linkedAccountID) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(accounts) { acct in
                        Text(acct.name).tag(Optional(acct.id))
                    }
                }
            }
            .navigationTitle(bill == nil ? "New Bill" : "Edit Bill")
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
                if let bill {
                    name = bill.name
                    amountText = NSDecimalNumber(decimal: bill.amount).stringValue
                    dueDate = bill.dueDate
                    linkedAccountID = bill.linkedAccount?.id
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        let linked = accounts.first { $0.id == linkedAccountID }
        if let bill {
            bill.name = trimmed
            bill.amount = amount
            bill.dueDate = dueDate
            bill.linkedAccount = linked
        } else {
            modelContext.insert(Bill(name: trimmed, amount: amount, dueDate: dueDate, linkedAccount: linked))
        }
        try? modelContext.save()
        dismiss()
    }
}

struct BalanceSnapshotSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: Account

    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Account", value: account.name)
                TextField("Balance", text: $amountText)
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Note", text: $note)
            }
            .navigationTitle("Record Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                amountText = NSDecimalNumber(decimal: account.currentBalance).stringValue
            }
        }
    }

    private func save() {
        let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) ?? account.currentBalance
        account.currentBalance = amount
        modelContext.insert(BalanceSnapshot(amount: amount, date: date, note: note, account: account))
        try? modelContext.save()
        dismiss()
    }
}
