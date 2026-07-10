import Foundation

enum SortableStatus: Equatable {
    case completed
    case overdue
    case dueToday
    case scheduled
    case pending
}

protocol ReminderSortable {
    var sortTitle: String? { get }
    var sortIsCompleted: Bool { get }
    var sortPriority: Int { get }
    var sortHasDueDate: Bool { get }
    var sortDueDate: Date? { get }
    var sortCreationDate: Date? { get }
}

enum ReminderSorting {
    static func status(
        isCompleted: Bool,
        dueDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SortableStatus {
        if isCompleted {
            return .completed
        }
        guard let dueDate = dueDate else {
            return .pending
        }
        if dueDate < now && !calendar.isDateInToday(dueDate) {
            return .overdue
        }
        if calendar.isDateInToday(dueDate) {
            return .dueToday
        }
        return .scheduled
    }

    /// `now` is re-evaluated on every comparison (matching the pre-refactor
    /// behavior of calling `Date()` inside the comparator), not once at
    /// comparator construction time.
    static func comparator<T: ReminderSortable>(
        for sortOption: SortOption,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) -> (T, T) -> Bool {
        return { lhs, rhs in
            if lhs.sortIsCompleted != rhs.sortIsCompleted {
                return !lhs.sortIsCompleted
            }
            switch sortOption {
            case .dueDate:
                return byDueDate(lhs, rhs)
            case .priority:
                return byPriority(lhs, rhs)
            case .title:
                return byTitle(lhs, rhs)
            case .created:
                return byCreated(lhs, rhs)
            case .status:
                return byStatus(lhs, rhs, now: now(), calendar: calendar)
            }
        }
    }

    static func byDueDate<T: ReminderSortable>(_ lhs: T, _ rhs: T) -> Bool {
        if let lhsDate = lhs.sortDueDate, let rhsDate = rhs.sortDueDate {
            return lhsDate < rhsDate
        }
        if lhs.sortHasDueDate {
            return true
        }
        if rhs.sortHasDueDate {
            return false
        }
        return byTitle(lhs, rhs)
    }

    static func byPriority<T: ReminderSortable>(_ lhs: T, _ rhs: T) -> Bool {
        if lhs.sortPriority != rhs.sortPriority {
            if lhs.sortPriority == 0 { return false }
            if rhs.sortPriority == 0 { return true }
            return lhs.sortPriority < rhs.sortPriority
        }
        return byDueDate(lhs, rhs)
    }

    static func byTitle<T: ReminderSortable>(_ lhs: T, _ rhs: T) -> Bool {
        return (lhs.sortTitle ?? "").lowercased() < (rhs.sortTitle ?? "").lowercased()
    }

    static func byCreated<T: ReminderSortable>(_ lhs: T, _ rhs: T) -> Bool {
        if let lhsDate = lhs.sortCreationDate, let rhsDate = rhs.sortCreationDate {
            return lhsDate > rhsDate
        }
        if lhs.sortCreationDate != nil {
            return true
        }
        if rhs.sortCreationDate != nil {
            return false
        }
        return byTitle(lhs, rhs)
    }

    static func byStatus<T: ReminderSortable>(
        _ lhs: T,
        _ rhs: T,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let statusOrder: [SortableStatus] = [.overdue, .dueToday, .scheduled, .pending, .completed]
        let lhsStatus = status(isCompleted: lhs.sortIsCompleted, dueDate: lhs.sortDueDate, now: now, calendar: calendar)
        let rhsStatus = status(isCompleted: rhs.sortIsCompleted, dueDate: rhs.sortDueDate, now: now, calendar: calendar)

        if let lhsIndex = statusOrder.firstIndex(of: lhsStatus),
           let rhsIndex = statusOrder.firstIndex(of: rhsStatus),
           lhsIndex != rhsIndex {
            return lhsIndex < rhsIndex
        }
        return byDueDate(lhs, rhs)
    }
}
