import SwiftUI
import SwiftData

struct FinanceBillsView: View {
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
                            Text(bill.amount, format: .currency(code: lifeOSCurrencyCode))
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
