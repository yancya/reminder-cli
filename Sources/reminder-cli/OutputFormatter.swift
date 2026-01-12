import ArgumentParser
@preconcurrency import EventKit
import Foundation
import Yams

// MARK: - Output Format

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case json
    case prettyJson = "pretty-json"
    case yaml
}

// MARK: - Codable Models

struct ReminderOutput: Codable {
    let id: String
    let title: String?
    let notes: String?
    let list: String?
    let priority: Int
    let priorityName: String
    let startDate: String?
    let dueDate: String?
    let isCompleted: Bool
    let completionDate: String?
    let url: String?
    let creationDate: String?
    let alarms: [AlarmOutput]?
    let recurrenceRules: [RecurrenceRuleOutput]?
}

struct AlarmOutput: Codable {
    let type: String // "absolute", "relative", "location"
    let value: String
    let proximity: String? // "arriving", "leaving" for location-based alarms
}

struct RecurrenceRuleOutput: Codable {
    let frequency: String
    let interval: Int
    let daysOfWeek: [String]?
    let endDate: String?
    let occurrenceCount: Int?
}

// MARK: - Output Formatter

struct OutputFormatter {
    let format: OutputFormat

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    // MARK: - Convert EKReminder to ReminderOutput

    func convertReminder(_ reminder: EKReminder) -> ReminderOutput {
        ReminderOutput(
            id: reminder.calendarItemIdentifier,
            title: reminder.title,
            notes: reminder.notes,
            list: reminder.calendar?.title,
            priority: reminder.priority,
            priorityName: priorityName(for: reminder.priority),
            startDate: reminder.startDateComponents?.date.map { dateFormatter.string(from: $0) },
            dueDate: reminder.dueDateComponents?.date.map { dateFormatter.string(from: $0) },
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate.map { dateFormatter.string(from: $0) },
            url: reminder.url?.absoluteString,
            creationDate: reminder.creationDate.map { dateFormatter.string(from: $0) },
            alarms: reminder.alarms.map { $0.map(convertAlarm) },
            recurrenceRules: reminder.recurrenceRules.map { $0.map(convertRecurrenceRule) }
        )
    }

    private func convertAlarm(_ alarm: EKAlarm) -> AlarmOutput {
        if let location = alarm.structuredLocation {
            let proximityText: String?
            if alarm.proximity == .enter {
                proximityText = "arriving"
            } else if alarm.proximity == .leave {
                proximityText = "leaving"
            } else {
                proximityText = nil
            }

            return AlarmOutput(
                type: "location",
                value: location.title ?? "Unknown location",
                proximity: proximityText
            )
        } else if let absoluteDate = alarm.absoluteDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return AlarmOutput(
                type: "absolute",
                value: formatter.string(from: absoluteDate),
                proximity: nil
            )
        } else {
            let offset = alarm.relativeOffset
            let minutes = Int(offset / 60)
            let valueText: String
            if minutes == 0 {
                valueText = "At time of event"
            } else if minutes < 0 {
                valueText = "\(abs(minutes)) minutes before"
            } else {
                valueText = "\(minutes) minutes after"
            }
            return AlarmOutput(
                type: "relative",
                value: valueText,
                proximity: nil
            )
        }
    }

    private func convertRecurrenceRule(_ rule: EKRecurrenceRule) -> RecurrenceRuleOutput {
        let frequencyText: String
        switch rule.frequency {
        case .daily:
            frequencyText = "daily"
        case .weekly:
            frequencyText = "weekly"
        case .monthly:
            frequencyText = "monthly"
        case .yearly:
            frequencyText = "yearly"
        @unknown default:
            frequencyText = "unknown"
        }

        let daysOfWeek = rule.daysOfTheWeek?.compactMap { dayOfWeek -> String? in
            switch dayOfWeek.dayOfTheWeek {
            case .sunday: return "Sunday"
            case .monday: return "Monday"
            case .tuesday: return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday: return "Thursday"
            case .friday: return "Friday"
            case .saturday: return "Saturday"
            @unknown default: return nil
            }
        }

        let end = rule.recurrenceEnd
        let endDate = end?.endDate.map { dateFormatter.string(from: $0) }
        let occurrenceCount = end?.occurrenceCount

        return RecurrenceRuleOutput(
            frequency: frequencyText,
            interval: rule.interval,
            daysOfWeek: daysOfWeek,
            endDate: endDate,
            occurrenceCount: occurrenceCount
        )
    }

    private func priorityName(for priority: Int) -> String {
        switch priority {
        case 1...4: return "High"
        case 5: return "Medium"
        case 6...9: return "Low"
        default: return "None"
        }
    }

    // MARK: - Output Methods

    func output(reminder: ReminderOutput) throws {
        switch format {
        case .text:
            outputText(reminder: reminder)
        case .json:
            try outputJSON(reminder: reminder, pretty: false)
        case .prettyJson:
            try outputJSON(reminder: reminder, pretty: true)
        case .yaml:
            try outputYAML(reminder: reminder)
        }
    }

    func output(reminders: [ReminderOutput]) throws {
        switch format {
        case .text:
            outputText(reminders: reminders)
        case .json:
            try outputJSON(reminders: reminders, pretty: false)
        case .prettyJson:
            try outputJSON(reminders: reminders, pretty: true)
        case .yaml:
            try outputYAML(reminders: reminders)
        }
    }

    private func outputText(reminder: ReminderOutput) {
        print("\n📝 Reminder Details")
        print("─────────────────────────────────────")
        print("ID:         \(reminder.id)")
        print("Title:      \(reminder.title ?? "(no title)")")
        print("Status:     \(reminder.isCompleted ? "Completed ✅" : "Pending ⏳")")

        if let list = reminder.list {
            print("List:       \(list)")
        }

        if let url = reminder.url {
            print("URL:        \(url)")
        }

        if let notes = reminder.notes, !notes.isEmpty {
            print("Notes:      \(notes)")
        }

        if let startDate = reminder.startDate {
            print("Start:      \(startDate)")
        }

        if let dueDate = reminder.dueDate {
            print("Due:        \(dueDate)")
        }

        if reminder.priority > 0 {
            print("Priority:   \(reminder.priority) (\(reminder.priorityName))")
        }

        if let completionDate = reminder.completionDate {
            print("Completed:  \(completionDate)")
        }

        if let creationDate = reminder.creationDate {
            print("Created:    \(creationDate)")
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
                if alarm.type == "location" {
                    alarmInfo += "📍 \(alarm.value)"
                    if let proximity = alarm.proximity {
                        alarmInfo += " (\(proximity))"
                    }
                } else {
                    alarmInfo += alarm.value
                }
                print(alarmInfo)
            }
        }

        print()
    }

    private func outputText(reminders: [ReminderOutput]) {
        for reminder in reminders {
            let checkbox = reminder.isCompleted ? "☑" : "☐"
            let priorityMark = priorityIndicator(for: reminder.priority)
            let title = reminder.title ?? "(no title)"

            var line = "  \(checkbox) \(priorityMark)\(title)"

            if let dueDate = reminder.dueDate {
                line += " (due: \(dueDate))"
            }

            print(line)
        }
    }

    private func outputJSON<T: Encodable>(data: T, pretty: Bool) throws {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let jsonData = try encoder.encode(data)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func outputJSON(reminder: ReminderOutput, pretty: Bool) throws {
        try outputJSON(data: reminder, pretty: pretty)
    }

    private func outputJSON(reminders: [ReminderOutput], pretty: Bool) throws {
        try outputJSON(data: reminders, pretty: pretty)
    }

    private func outputYAML<T: Encodable>(data: T) throws {
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(data)
        print(yamlString)
    }

    private func outputYAML(reminder: ReminderOutput) throws {
        try outputYAML(data: reminder)
    }

    private func outputYAML(reminders: [ReminderOutput]) throws {
        try outputYAML(data: reminders)
    }

    // MARK: - Helper Methods

    private func priorityIndicator(for priority: Int) -> String {
        switch priority {
        case 1...4: return "‼️ "
        case 5: return "❗ "
        case 6...9: return "❕ "
        default: return ""
        }
    }

    private func formatRecurrenceRule(_ rule: RecurrenceRuleOutput) -> String {
        var result = ""

        let frequencyText: String
        switch rule.frequency {
        case "daily":
            frequencyText = rule.interval == 1 ? "Daily" : "Every \(rule.interval) days"
        case "weekly":
            frequencyText = rule.interval == 1 ? "Weekly" : "Every \(rule.interval) weeks"
        case "monthly":
            frequencyText = rule.interval == 1 ? "Monthly" : "Every \(rule.interval) months"
        case "yearly":
            frequencyText = rule.interval == 1 ? "Yearly" : "Every \(rule.interval) years"
        default:
            frequencyText = "Unknown frequency"
        }
        result += frequencyText

        if let daysOfWeek = rule.daysOfWeek, !daysOfWeek.isEmpty {
            let dayAbbrevs = daysOfWeek.map { day in
                switch day {
                case "Sunday": return "Sun"
                case "Monday": return "Mon"
                case "Tuesday": return "Tue"
                case "Wednesday": return "Wed"
                case "Thursday": return "Thu"
                case "Friday": return "Fri"
                case "Saturday": return "Sat"
                default: return day
                }
            }
            result += " on \(dayAbbrevs.joined(separator: ", "))"
        }

        if let endDate = rule.endDate {
            result += " (until \(endDate))"
        } else if let occurrenceCount = rule.occurrenceCount, occurrenceCount > 0 {
            result += " (\(occurrenceCount) times)"
        }

        return result
    }
}
