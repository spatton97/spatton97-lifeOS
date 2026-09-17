import Foundation

enum BillDueUrgency: Int, Comparable {
    case overdue = 0
    case dueToday = 1
    case soon = 2
    case later = 3

    var isElevated: Bool { self == .overdue || self == .dueToday }

    static func < (lhs: BillDueUrgency, rhs: BillDueUrgency) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

func billDueUrgency(_ date: Date, calendar: Calendar, todayStart: Date) -> BillDueUrgency {
    let due = calendar.startOfDay(for: date)
    if due < todayStart { return .overdue }
    if due == todayStart { return .dueToday }
    let days = calendar.dateComponents([.day], from: todayStart, to: due).day ?? 0
    if days <= 7 { return .soon }
    return .later
}

func billDueCaption(_ date: Date, urgency: BillDueUrgency, calendar: Calendar, todayStart: Date) -> String {
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
