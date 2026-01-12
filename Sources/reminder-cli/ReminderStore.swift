@preconcurrency import EventKit
import Foundation

enum ReminderStoreError: LocalizedError {
    case accessDenied
    case reminderNotFound(String)
    case ambiguousIdentifier(String, [EKReminder])
    case listNotFound(String)
    case invalidDateFormat(String)
    case invalidPriority(Int)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to Reminders was denied. Please grant permission in System Settings."
        case .reminderNotFound(let identifier):
            return "Reminder not found: \(identifier)"
        case .ambiguousIdentifier(let identifier, let matches):
            var message = "Ambiguous identifier '\(identifier)' matches \(matches.count) reminders:\n"
            for reminder in matches {
                let title = reminder.title ?? "(no title)"
                message += "  \(reminder.calendarItemIdentifier) - \(title)\n"
            }
            message += "\nPlease use a longer prefix or the full ID."
            return message
        case .listNotFound(let name):
            return "List not found: \(name)"
        case .invalidDateFormat(let format):
            return "Invalid date format: \(format). Use YYYY-MM-DD or YYYY-MM-DD HH:MM"
        case .invalidPriority(let priority):
            return "Invalid priority: \(priority). Use 0-9 (0=none, 1-4=high, 5=medium, 6-9=low)"
        }
    }
}

class ReminderStore {
    private let eventStore = EKEventStore()

    func requestAccess() async throws {
        if #available(macOS 14.0, *) {
            let granted = try await eventStore.requestFullAccessToReminders()
            guard granted else {
                throw ReminderStoreError.accessDenied
            }
        } else {
            let granted = try await eventStore.requestAccess(to: .reminder)
            guard granted else {
                throw ReminderStoreError.accessDenied
            }
        }
    }

    // MARK: - List Operations

    func listAllReminders(showCompleted: Bool, format: OutputFormat = .text) async throws {
        let calendars = eventStore.calendars(for: .reminder)

        if format == .text {
            for calendar in calendars {
                print("\n📋 \(calendar.title)")
                print("─────────────────────────────────────")
                try await listReminders(in: calendar, showCompleted: showCompleted, format: format)
            }
        } else {
            // For structured formats, collect all reminders
            var allReminders: [EKReminder] = []
            for calendar in calendars {
                let predicate = eventStore.predicateForReminders(in: [calendar])
                let reminders = try await fetchReminders(matching: predicate)
                let filteredReminders = showCompleted ? reminders : reminders.filter { !$0.isCompleted }
                allReminders.append(contentsOf: filteredReminders.sorted(by: sortReminders))
            }

            let formatter = OutputFormatter(format: format)
            let outputs = allReminders.map { formatter.convertReminder($0) }
            try formatter.output(reminders: outputs)
        }
    }

    func listReminders(in listName: String, showCompleted: Bool, format: OutputFormat = .text) async throws {
        guard let calendar = findCalendar(named: listName) else {
            throw ReminderStoreError.listNotFound(listName)
        }

        if format == .text {
            print("\n📋 \(calendar.title)")
            print("─────────────────────────────────────")
        }
        try await listReminders(in: calendar, showCompleted: showCompleted, format: format)
    }

    private func listReminders(in calendar: EKCalendar, showCompleted: Bool, format: OutputFormat = .text) async throws {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = try await fetchReminders(matching: predicate)

        let filteredReminders = showCompleted ? reminders : reminders.filter { !$0.isCompleted }

        if format == .text {
            if filteredReminders.isEmpty {
                print("  (no reminders)")
                return
            }

            for reminder in filteredReminders.sorted(by: sortReminders) {
                printReminderSummary(reminder)
            }
        } else {
            let formatter = OutputFormatter(format: format)
            let outputs = filteredReminders.sorted(by: sortReminders).map { formatter.convertReminder($0) }
            try formatter.output(reminders: outputs)
        }
    }

    // MARK: - Show Operation

    func showReminder(identifier: String, format: OutputFormat = .text) async throws {
        let reminder = try await findReminder(identifier: identifier)

        if format == .text {
            printReminderDetails(reminder)
        } else {
            let formatter = OutputFormatter(format: format)
            let output = formatter.convertReminder(reminder)
            try formatter.output(reminder: output)
        }
    }

    // MARK: - Create Operation

    func createReminder(
        title: String,
        listName: String?,
        notes: String?,
        startDate: String?,
        dueDate: String?,
        priority: Int?,
        flagged: Bool?,
        url: String?
    ) async throws {
        let calendar: EKCalendar
        if let listName = listName {
            guard let found = findCalendar(named: listName) else {
                throw ReminderStoreError.listNotFound(listName)
            }
            calendar = found
        } else {
            calendar = eventStore.defaultCalendarForNewReminders() ?? eventStore.calendars(for: .reminder).first!
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = calendar
        reminder.notes = notes

        if let startDateString = startDate {
            reminder.startDateComponents = try parseDateComponents(from: startDateString)
        }

        if let dueDateString = dueDate {
            reminder.dueDateComponents = try parseDateComponents(from: dueDateString)
        }

        if let priority = priority {
            guard (0...9).contains(priority) else {
                throw ReminderStoreError.invalidPriority(priority)
            }
            reminder.priority = priority
        }

        // TODO: EventKit doesn't support isFlagged directly
        // if let flagged = flagged {
        //     reminder.isFlagged = flagged
        // }

        if let urlString = url, let url = URL(string: urlString) {
            reminder.url = url
        }

        try eventStore.save(reminder, commit: true)

        print("✅ Created reminder: \(title)")
        print("   ID: \(reminder.calendarItemIdentifier)")
        if let list = reminder.calendar?.title {
            print("   List: \(list)")
        }
    }

    // MARK: - Update Operation

    func updateReminder(
        identifier: String,
        title: String?,
        notes: String?,
        startDate: String?,
        dueDate: String?,
        priority: Int?,
        flagged: Bool?,
        url: String?
    ) async throws {
        let reminder = try await findReminder(identifier: identifier)

        if let title = title {
            reminder.title = title
        }

        if let notes = notes {
            reminder.notes = notes
        }

        if let startDateString = startDate {
            reminder.startDateComponents = try parseDateComponents(from: startDateString)
        }

        if let dueDateString = dueDate {
            reminder.dueDateComponents = try parseDateComponents(from: dueDateString)
        }

        if let priority = priority {
            guard (0...9).contains(priority) else {
                throw ReminderStoreError.invalidPriority(priority)
            }
            reminder.priority = priority
        }

        // TODO: EventKit doesn't support isFlagged directly
        // if let flagged = flagged {
        //     reminder.isFlagged = flagged
        // }

        if let urlString = url, let url = URL(string: urlString) {
            reminder.url = url
        }

        try eventStore.save(reminder, commit: true)

        print("✅ Updated reminder: \(reminder.title ?? "(no title)")")
    }

    // MARK: - Delete Operation

    func deleteReminder(identifier: String, force: Bool) async throws {
        let reminder = try await findReminder(identifier: identifier)

        if !force {
            print("Are you sure you want to delete '\(reminder.title ?? "(no title)")'? [y/N]: ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("Cancelled.")
                return
            }
        }

        try eventStore.remove(reminder, commit: true)
        print("🗑️  Deleted reminder: \(reminder.title ?? "(no title)")")
    }

    // MARK: - Complete Operation

    func completeReminder(identifier: String) async throws {
        let reminder = try await findReminder(identifier: identifier)

        reminder.isCompleted = true
        try eventStore.save(reminder, commit: true)

        print("✅ Completed reminder: \(reminder.title ?? "(no title)")")
    }

    // MARK: - Helper Methods

    private func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    // Create a copy to avoid data race warnings
                    let remindersCopy = Array(reminders)
                    continuation.resume(returning: remindersCopy)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func findCalendar(named name: String) -> EKCalendar? {
        let calendars = eventStore.calendars(for: .reminder)
        return calendars.first { $0.title.lowercased() == name.lowercased() }
    }

    private func findReminder(identifier: String) async throws -> EKReminder {
        // Try to find by exact calendar item identifier first
        if let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder {
            return reminder
        }

        // Try prefix matching (short ID support, like git commit hashes)
        let normalizedIdentifier = identifier.uppercased().replacingOccurrences(of: "-", with: "")

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)
        let reminders = try await fetchReminders(matching: predicate)

        let matches = reminders.filter { reminder in
            let reminderID = reminder.calendarItemIdentifier.uppercased().replacingOccurrences(of: "-", with: "")
            return reminderID.hasPrefix(normalizedIdentifier)
        }

        if matches.count == 1 {
            return matches[0]
        } else if matches.count > 1 {
            throw ReminderStoreError.ambiguousIdentifier(identifier, matches)
        }

        throw ReminderStoreError.reminderNotFound(identifier)
    }

    private func parseDateComponents(from string: String) throws -> DateComponents {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try with time first
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: string) {
            return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        }

        // Try date only
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: string) {
            return Calendar.current.dateComponents([.year, .month, .day], from: date)
        }

        throw ReminderStoreError.invalidDateFormat(string)
    }

    private func sortReminders(_ lhs: EKReminder, _ rhs: EKReminder) -> Bool {
        // Sort by completion status first
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        // Then by due date
        if let lhsDate = lhs.dueDateComponents?.date, let rhsDate = rhs.dueDateComponents?.date {
            return lhsDate < rhsDate
        }
        if lhs.dueDateComponents != nil {
            return true
        }
        if rhs.dueDateComponents != nil {
            return false
        }

        // Finally by title
        return (lhs.title ?? "") < (rhs.title ?? "")
    }

    private func printReminderSummary(_ reminder: EKReminder) {
        let checkbox = reminder.isCompleted ? "☑" : "☐"
        let priorityMark = priorityIndicator(for: reminder.priority)
        let title = reminder.title ?? "(no title)"

        // Extract short ID (first 8 characters of UUID without hyphens)
        let fullID = reminder.calendarItemIdentifier
        let shortID = String(fullID.prefix(8))

        var line = "  [\(shortID)] \(checkbox) \(priorityMark)\(title)"

        if let dueDate = reminder.dueDateComponents?.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            line += " (due: \(formatter.string(from: dueDate)))"
        }

        print(line)
    }

    private func printReminderDetails(_ reminder: EKReminder) {
        print("\n📝 Reminder Details")
        print("─────────────────────────────────────")
        print("ID:         \(reminder.calendarItemIdentifier)")
        print("Title:      \(reminder.title ?? "(no title)")")
        print("Status:     \(reminder.isCompleted ? "Completed ✅" : "Pending ⏳")")

        // TODO: EventKit doesn't support isFlagged directly
        // if reminder.isFlagged {
        //     print("Flagged:    ⚑")
        // }

        if let list = reminder.calendar?.title {
            print("List:       \(list)")
        }

        if let url = reminder.url {
            print("URL:        \(url.absoluteString)")
        }

        if let notes = reminder.notes, !notes.isEmpty {
            print("Notes:      \(notes)")
        }

        if let startDate = reminder.startDateComponents?.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            print("Start:      \(formatter.string(from: startDate))")
        }

        if let dueDate = reminder.dueDateComponents?.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            print("Due:        \(formatter.string(from: dueDate))")
        }

        if reminder.priority > 0 {
            let priorityName = priorityName(for: reminder.priority)
            print("Priority:   \(reminder.priority) (\(priorityName))")
        }

        if let completionDate = reminder.completionDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            print("Completed:  \(formatter.string(from: completionDate))")
        }

        if let creationDate = reminder.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            print("Created:    \(formatter.string(from: creationDate))")
        }

        if let recurrenceRules = reminder.recurrenceRules, !recurrenceRules.isEmpty {
            print("Recurrence: \(recurrenceRules.count) rule(s)")
            for (index, rule) in recurrenceRules.enumerated() {
                print("  [\(index + 1)] \(formatRecurrenceRule(rule))")
            }
        }

        if let alarms = reminder.alarms, !alarms.isEmpty {
            print("Alarms:     \(alarms.count)")
            for (index, alarm) in alarms.enumerated() {
                var alarmInfo = "  [\(index + 1)] "

                if let location = alarm.structuredLocation {
                    alarmInfo += "📍 "
                    if let title = location.title {
                        alarmInfo += title
                    }
                    if alarm.proximity == .enter {
                        alarmInfo += " (arriving)"
                    } else if alarm.proximity == .leave {
                        alarmInfo += " (leaving)"
                    }
                } else if let absoluteDate = alarm.absoluteDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .short
                    alarmInfo += formatter.string(from: absoluteDate)
                } else {
                    let offset = alarm.relativeOffset
                    let minutes = Int(offset / 60)
                    if minutes == 0 {
                        alarmInfo += "At time of event"
                    } else if minutes < 0 {
                        alarmInfo += "\(abs(minutes)) minutes before"
                    } else {
                        alarmInfo += "\(minutes) minutes after"
                    }
                }

                print(alarmInfo)
            }
        }

        // TODO: EKReminder doesn't expose attachments property directly
        // The parent class EKCalendarItem has it, but it's not accessible on EKReminder
        // if let attachments = reminder.attachments, !attachments.isEmpty {
        //     print("Attachments: \(attachments.count)")
        //     for (index, attachment) in attachments.enumerated() {
        //         if let url = attachment.url {
        //             print("  [\(index + 1)] \(url.lastPathComponent)")
        //             print("      \(url.absoluteString)")
        //         }
        //     }
        // }

        print()
    }

    private func priorityIndicator(for priority: Int) -> String {
        switch priority {
        case 1...4: return "‼️ "
        case 5: return "❗ "
        case 6...9: return "❕ "
        default: return ""
        }
    }

    private func priorityName(for priority: Int) -> String {
        switch priority {
        case 1...4: return "High"
        case 5: return "Medium"
        case 6...9: return "Low"
        default: return "None"
        }
    }

    private func formatRecurrenceRule(_ rule: EKRecurrenceRule) -> String {
        var result = ""

        // Frequency
        let frequencyText: String
        switch rule.frequency {
        case .daily:
            frequencyText = rule.interval == 1 ? "Daily" : "Every \(rule.interval) days"
        case .weekly:
            frequencyText = rule.interval == 1 ? "Weekly" : "Every \(rule.interval) weeks"
        case .monthly:
            frequencyText = rule.interval == 1 ? "Monthly" : "Every \(rule.interval) months"
        case .yearly:
            frequencyText = rule.interval == 1 ? "Yearly" : "Every \(rule.interval) years"
        @unknown default:
            frequencyText = "Unknown frequency"
        }
        result += frequencyText

        // Days of the week (for weekly recurrence)
        if let daysOfWeek = rule.daysOfTheWeek, !daysOfWeek.isEmpty {
            let dayNames = daysOfWeek.compactMap { dayOfWeek -> String? in
                switch dayOfWeek.dayOfTheWeek {
                case .sunday: return "Sun"
                case .monday: return "Mon"
                case .tuesday: return "Tue"
                case .wednesday: return "Wed"
                case .thursday: return "Thu"
                case .friday: return "Fri"
                case .saturday: return "Sat"
                @unknown default: return nil
                }
            }
            if !dayNames.isEmpty {
                result += " on \(dayNames.joined(separator: ", "))"
            }
        }

        // Recurrence end
        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                result += " (until \(formatter.string(from: endDate)))"
            } else if end.occurrenceCount > 0 {
                result += " (\(end.occurrenceCount) times)"
            }
        }

        return result
    }
}
