import SwiftUI
import SwiftData

struct FinanceViews: View {
    enum Segment: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case bills = "Bills"
        case activity = "Activity"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .overview

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $segment) {
                    ForEach(Segment.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch segment {
                case .overview:
                    FinanceOverviewView()
                case .bills:
                    FinanceBillsView()
                case .activity:
                    FinanceActivityView()
                }
            }
            .navigationTitle("Finance")
        }
    }
}

// MARK: - Overview

private struct FinanceOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorBlindMode) private var colorBlind
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \BalanceSnapshot.date, order: .reverse) private var snapshots: [BalanceSnapshot]

    @State private var showingAddAccount = false
    @State private var editingAccount: Account?
    @State private var snapshotAccount: Account?

    private var netWorth: Decimal {
        accounts.reduce(0) { $0 + $1.currentBalance }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net position")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(netWorth, format: .currency(code: currencyCode))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(
                            netWorth >= 0
                            ? LifeOSAccent.success(colorBlind: colorBlind)
                            : LifeOSAccent.danger(colorBlind: colorBlind)
                        )
                }
                .padding(.vertical, 4)
            }

            Section {
                if accounts.isEmpty {
                    Text("No accounts yet — add one to track balances manually.")
                        .foregroundStyle(.secondary)
                }
                ForEach(accounts) { account in
                    Button {
                        editingAccount = account
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                    .foregroundStyle(.primary)
                                Text(account.type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(account.currentBalance, format: .currency(code: currencyCode))
                                .foregroundStyle(.primary)
                                .fontWeight(.medium)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Snapshot") {
                            snapshotAccount = account
                        }
                        .tint(LifeOSAccent.primary(colorBlind: colorBlind))
                    }
                }
                .onDelete(perform: deleteAccounts)
            } header: {
                HStack {
                    Text("Accounts")
                    Spacer()
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("No bank login. Update balances manually or record a snapshot.")
            }

            Section("Recent snapshots") {
                let recent = Array(snapshots.prefix(8))
                if recent.isEmpty {
                    Text("No snapshots yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recent) { snap in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(snap.account?.name ?? "Account")
                                Text(snap.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(snap.amount, format: .currency(code: currencyCode))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AccountEditorSheet(account: nil)
        }
        .sheet(item: $editingAccount) { account in
            AccountEditorSheet(account: account)
        }
        .sheet(item: $snapshotAccount) { account in
            BalanceSnapshotSheet(account: account)
        }
    }

    private func deleteAccounts(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(accounts[i])
        }
        try? modelContext.save()
    }
}

// MARK: - Bills

private struct FinanceBillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorBlindMode) private var colorBlind
    @Query(sort: \Bill.dueDate) private var bills: [Bill]

    @State private var showingAdd = false
    @State private var editing: Bill?

    var body: some View {
        List {
            Section {
                if bills.isEmpty {
                    Text("No bills — add rent, utilities, subscriptions…")
                        .foregroundStyle(.secondary)
                }
                ForEach(bills) { bill in
                    Button {
                        editing = bill
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(bill.name)
                                        .foregroundStyle(.primary)
                                    if bill.isPaid {
                                        Text("Paid")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(LifeOSAccent.success(colorBlind: colorBlind).opacity(0.2), in: Capsule())
                                    }
                                }
                                Text(bill.dueDate, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let acct = bill.linkedAccount {
                                    Text("Linked: \(acct.name)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Text(bill.amount, format: .currency(code: currencyCode))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .onDelete(perform: deleteBills)
            } header: {
                HStack {
                    Text("All bills")
                    Spacer()
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            BillEditorSheet(bill: nil)
        }
        .sheet(item: $editing) { bill in
            BillEditorSheet(bill: bill)
        }
    }

    private func deleteBills(at offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(bills[i])
        }
        try? modelContext.save()
    }
}

// MARK: - Activity

private struct FinanceActivityView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(\.colorBlindMode) private var colorBlind

    var body: some View {
        List {
            if transactions.isEmpty {
                Text("No transactions yet. Paying a bill on Today creates one.")
                    .foregroundStyle(.secondary)
            }
            ForEach(transactions.filter { !$0.isUndone }) { tx in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tx.title)
                        HStack(spacing: 6) {
                            Text(tx.date, style: .date)
                            if let name = tx.account?.name {
                                Text("· \(name)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(tx.amount, format: .currency(code: currencyCode))
                        .foregroundStyle(
                            tx.amount < 0
                            ? LifeOSAccent.danger(colorBlind: colorBlind)
                            : LifeOSAccent.success(colorBlind: colorBlind)
                        )
                        .fontWeight(.medium)
                }
            }
        }
    }
}

// MARK: - Sheets

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
        if let account {
            account.name = trimmed
            account.type = type
            account.currentBalance = balance
        } else {
            modelContext.insert(Account(name: trimmed, type: type, currentBalance: balance))
        }
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

private var currencyCode: String {
    Locale.current.currency?.identifier ?? "USD"
}

#Preview {
    FinanceViews()
        .modelContainer(for: [
            Note.self, Habit.self, Account.self, BalanceSnapshot.self,
            Bill.self, Transaction.self, ScheduleItem.self, AppSettings.self
        ], inMemory: true)
}
