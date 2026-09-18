import SwiftUI
import SwiftData

struct FinanceActivityView: View {
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
                    Text(tx.amount, format: .currency(code: lifeOSCurrencyCode))
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
