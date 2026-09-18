import SwiftUI
import SwiftData

struct FinanceOverviewView: View {
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
                    Text(netWorth, format: .currency(code: lifeOSCurrencyCode))
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
                            Text(account.currentBalance, format: .currency(code: lifeOSCurrencyCode))
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
                            Text(snap.amount, format: .currency(code: lifeOSCurrencyCode))
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
