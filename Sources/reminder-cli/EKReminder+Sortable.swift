@preconcurrency import EventKit
import Foundation

extension EKReminder: ReminderSortable {
    var sortTitle: String? { title }
    var sortIsCompleted: Bool { isCompleted }
    var sortPriority: Int { priority }
    var sortHasDueDate: Bool { dueDateComponents != nil }
    var sortDueDate: Date? { dueDateComponents?.date }
    var sortCreationDate: Date? { creationDate }
}
