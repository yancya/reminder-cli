@preconcurrency import EventKit
import Foundation

enum ReminderStoreError: LocalizedError {
    case accessDenied
    case reminderNotFound(String)
    case ambiguousIdentifier(String, [EKReminder])
    case listNotFound(String)
    case noAvailableLists
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
                let fullID = reminder.calendarItemIdentifier
                let shortID = String(fullID.prefix(8))
                message += "  [\(shortID)] \(fullID) - \(title)\n"
            }
            message += "\nPlease use a longer prefix (e.g., 9+ characters) or the full ID."
            return message
        case .listNotFound(let name):
            return "List not found: \(name)"
        case .noAvailableLists:
            return "No reminder lists are available. Please create a list in Reminders.app."
        case .invalidDateFormat(let format):
            return "Invalid date format: \(format). Use YYYY-MM-DD or YYYY-MM-DD HH:MM"
        case .invalidPriority(let priority):
            return "Invalid priority: \(priority). Use 0-9 (0=none, 1-4=high, 5=medium, 6-9=low)"
        }
    }
}

class ReminderStore {
    private let eventStore = EKEventStore()

    // MARK: - Reminder Status

    enum ReminderStatus: Equatable {
        case completed
        case overdue
        case dueToday
        case scheduled
        case pending

        var icon: String {
            switch self {
            case .completed: return "✅"
            case .overdue: return "🔥"
            case .dueToday: return "⚠️"
            case .scheduled: return "📅"
            case .pending: return "⏳"
            }
        }

        var label: String {
            switch self {
            case .completed: return "Completed"
            case .overdue: return "Overdue"
            case .dueToday: return "Due today"
            case .scheduled: return "Scheduled"
            case .pending: return "Pending"
            }
        }
    }

    private func getReminderStatus(_ reminder: EKReminder) -> ReminderStatus {
        switch ReminderSorting.status(isCompleted: reminder.isCompleted, dueDate: reminder.dueDateComponents?.date) {
        case .completed: return .completed
        case .overdue: return .overdue
        case .dueToday: return .dueToday
        case .scheduled: return .scheduled
        case .pending: return .pending
        }
    }

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

    // MARK: - Helper for Completion

    func getAllReminders() async throws -> [EKReminder] {
        let calendars = eventStore.calendars(for: .reminder)
        var allReminders: [EKReminder] = []

        for calendar in calendars {
            let predicate = eventStore.predicateForReminders(in: [calendar])
            let reminders = try await fetchReminders(matching: predicate)
            allReminders.append(contentsOf: reminders)
        }

        return allReminders
    }

    // MARK: - List Operations

    func listAllReminders(showCompleted: Bool, format: OutputFormat = .text, sortBy: SortOption = .dueDate) async throws {
        let calendars = eventStore.calendars(for: .reminder)

        if format == .text {
            for calendar in calendars {
                print("\n📋 \(calendar.title)")
                print("─────────────────────────────────────")
                try await listReminders(in: calendar, showCompleted: showCompleted, format: format, sortBy: sortBy)
            }
        } else {
            // For structured formats, collect all reminders
            var allReminders: [EKReminder] = []
            for calendar in calendars {
                let predicate = eventStore.predicateForReminders(in: [calendar])
                let reminders = try await fetchReminders(matching: predicate)
                let filteredReminders = showCompleted ? reminders : reminders.filter { !$0.isCompleted }
                allReminders.append(contentsOf: filteredReminders.sorted(by: sortReminders(by: sortBy)))
            }

            let formatter = OutputFormatter(format: format)
            let outputs = allReminders.map { formatter.convertReminder($0) }
            try formatter.output(reminders: outputs)
        }
    }

    func listReminders(in listName: String, showCompleted: Bool, format: OutputFormat = .text, sortBy: SortOption = .dueDate) async throws {
        guard let calendar = findCalendar(named: listName) else {
            throw ReminderStoreError.listNotFound(listName)
        }

        if format == .text {
            print("\n📋 \(calendar.title)")
            print("─────────────────────────────────────")
        }
        try await listReminders(in: calendar, showCompleted: showCompleted, format: format, sortBy: sortBy)
    }

    private func listReminders(in calendar: EKCalendar, showCompleted: Bool, format: OutputFormat = .text, sortBy: SortOption = .dueDate) async throws {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = try await fetchReminders(matching: predicate)

        let filteredReminders = showCompleted ? reminders : reminders.filter { !$0.isCompleted }

        if format == .text {
            if filteredReminders.isEmpty {
                print("  (no reminders)")
                return
            }

            for reminder in filteredReminders.sorted(by: sortReminders(by: sortBy)) {
                printReminderSummary(reminder)
            }
        } else {
            let formatter = OutputFormatter(format: format)
            let outputs = filteredReminders.sorted(by: sortReminders(by: sortBy)).map { formatter.convertReminder($0) }
            try formatter.output(reminders: outputs)
        }
    }

    // MARK: - Lists Operation

    func listCalendars(includeCount: Bool, format: OutputFormat = .text) async throws {
        let calendars = eventStore.calendars(for: .reminder)
        let formatter = OutputFormatter(format: format)

        var outputs: [ListOutput] = []
        for calendar in calendars {
            var count: Int?
            if includeCount {
                let predicate = eventStore.predicateForReminders(in: [calendar])
                count = try await fetchReminders(matching: predicate).count
            }
            outputs.append(formatter.convertCalendar(calendar, reminderCount: count))
        }

        if format == .text {
            print("\n📋 Lists")
            print("─────────────────────────────────────")
        }
        try formatter.output(lists: outputs)
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
        url: String?,
        format: OutputFormat = .text
    ) async throws {
        let calendar: EKCalendar
        if let listName = listName {
            guard let found = findCalendar(named: listName) else {
                throw ReminderStoreError.listNotFound(listName)
            }
            calendar = found
        } else {
            if let defaultCalendar = eventStore.defaultCalendarForNewReminders() {
                calendar = defaultCalendar
            } else if let firstCalendar = eventStore.calendars(for: .reminder).first {
                calendar = firstCalendar
            } else {
                throw ReminderStoreError.noAvailableLists
            }
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

        if let urlString = url, let url = URL(string: urlString) {
            reminder.url = url
        }

        try eventStore.save(reminder, commit: true)

        if format == .text {
            print("✅ Created reminder: \(title)")
            print("   ID: \(reminder.calendarItemIdentifier)")
            if let list = reminder.calendar?.title {
                print("   List: \(list)")
            }
        } else {
            let formatter = OutputFormatter(format: format)
            try formatter.output(reminder: formatter.convertReminder(reminder))
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
        url: String?,
        format: OutputFormat = .text
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

        if let urlString = url, let url = URL(string: urlString) {
            reminder.url = url
        }

        try eventStore.save(reminder, commit: true)

        if format == .text {
            print("✅ Updated reminder: \(reminder.title ?? "(no title)")")
        } else {
            let formatter = OutputFormatter(format: format)
            try formatter.output(reminder: formatter.convertReminder(reminder))
        }
    }

    // MARK: - Delete Operation

    func deleteReminder(identifier: String, force: Bool, format: OutputFormat = .text) async throws {
        let reminder = try await findReminder(identifier: identifier)
        let title = reminder.title ?? "(no title)"
        let id = reminder.calendarItemIdentifier

        if !force {
            print("Are you sure you want to delete '\(title)'? [y/N]: ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("Cancelled.")
                return
            }
        }

        try eventStore.remove(reminder, commit: true)

        if format == .text {
            print("🗑️  Deleted reminder: \(title)")
        } else {
            let formatter = OutputFormatter(format: format)
            try formatter.output(deleteConfirmation: DeleteConfirmationOutput(deleted: true, id: id, title: title))
        }
    }

    // MARK: - Complete Operation

    func completeReminder(identifier: String, format: OutputFormat = .text) async throws {
        let reminder = try await findReminder(identifier: identifier)

        reminder.isCompleted = true
        try eventStore.save(reminder, commit: true)

        if format == .text {
            print("✅ Completed reminder: \(reminder.title ?? "(no title)")")
        } else {
            let formatter = OutputFormatter(format: format)
            try formatter.output(reminder: formatter.convertReminder(reminder))
        }
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
        guard let components = DateParsing.parse(string) else {
            throw ReminderStoreError.invalidDateFormat(string)
        }
        return components
    }

    private func sortReminders(by sortOption: SortOption) -> (EKReminder, EKReminder) -> Bool {
        return ReminderSorting.comparator(for: sortOption)
    }

    private func printReminderSummary(_ reminder: EKReminder) {
        let checkbox = reminder.isCompleted ? "☑" : "☐"
        let priorityMark = priorityIndicator(for: reminder.priority)
        let title = reminder.title ?? "(no title)"

        // Extract short ID (first 8 characters of UUID without hyphens)
        let fullID = reminder.calendarItemIdentifier
        let shortID = String(fullID.prefix(8))

        // Get status
        let status = getReminderStatus(reminder)

        var line = "  [\(shortID)] \(checkbox) \(priorityMark)\(title)"

        if let dueDate = reminder.dueDateComponents?.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            line += " (due: \(formatter.string(from: dueDate)))"
        }

        // Add status icon for incomplete reminders (except pending without due date)
        if !reminder.isCompleted {
            line += " \(status.icon)"
        }

        print(line)
    }

    private func printReminderDetails(_ reminder: EKReminder) {
        print("\n📝 Reminder Details")
        print("─────────────────────────────────────")
        print("ID:         \(reminder.calendarItemIdentifier)")
        print("Title:      \(reminder.title ?? "(no title)")")

        let status = getReminderStatus(reminder)
        print("Status:     \(status.label) \(status.icon)")

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
