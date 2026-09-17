import SwiftUI
import SwiftData

struct FinanceView: View {
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

#Preview {
    FinanceView()
        .modelContainer(for: [
            Note.self, Habit.self, Account.self, BalanceSnapshot.self,
            Bill.self, Transaction.self, ScheduleItem.self, AppSettings.self
        ], inMemory: true)
}
