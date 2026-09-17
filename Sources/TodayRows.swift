import SwiftUI

struct HabitStreakCapsule: View {
    let streak: Int

    var body: some View {
        if streak > 0 {
            Text(streak == 1 ? "1 day" : "\(streak) days")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
                .accessibilityLabel(streak == 1 ? "1 day streak" : "\(streak) day streak")
        } else {
            EmptyView()
        }
    }
}

struct UnpaidBillRow: View {
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

struct ScheduleRow: View {
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
