@preconcurrency import EventKit
import XCTest
@testable import reminder_cli

final class OutputFormatterTests: XCTestCase {
    private func makeReminder(
        id: String = "TEST-ID",
        title: String? = "Buy milk",
        notes: String? = nil,
        list: String? = "Groceries",
        priority: Int = 0,
        priorityName: String = "None",
        startDate: String? = nil,
        dueDate: String? = nil,
        isCompleted: Bool = false,
        completionDate: String? = nil,
        url: String? = nil,
        creationDate: String? = nil,
        alarms: [AlarmOutput]? = nil,
        recurrenceRules: [RecurrenceRuleOutput]? = nil
    ) -> ReminderOutput {
        ReminderOutput(
            id: id,
            title: title,
            notes: notes,
            list: list,
            priority: priority,
            priorityName: priorityName,
            startDate: startDate,
            dueDate: dueDate,
            isCompleted: isCompleted,
            completionDate: completionDate,
            url: url,
            creationDate: creationDate,
            alarms: alarms,
            recurrenceRules: recurrenceRules
        )
    }

    // MARK: - JSON

    func testJSONOutputContainsIdAndTitle() throws {
        let formatter = OutputFormatter(format: .json)
        let reminder = makeReminder()

        let output = try captureStdout {
            try formatter.output(reminder: reminder)
        }
        let data = output.data(using: .utf8)!
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["id"] as? String, "TEST-ID")
        XCTAssertEqual(object?["title"] as? String, "Buy milk")
    }

    func testJSONOutputIsSingleLine() throws {
        let formatter = OutputFormatter(format: .json)
        let output = try captureStdout {
            try formatter.output(reminder: makeReminder())
        }
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").count, 1)
    }

    // MARK: - pretty-json

    func testPrettyJSONOutputIsMultiLineAndSortedKeys() throws {
        let formatter = OutputFormatter(format: .prettyJson)
        let output = try captureStdout {
            try formatter.output(reminder: makeReminder())
        }
        XCTAssertGreaterThan(output.split(separator: "\n").count, 1)

        let data = output.data(using: .utf8)!
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["id"] as? String, "TEST-ID")

        // Keys must appear in the output in alphabetical order (the
        // .sortedKeys encoder option), not merely be present.
        let keyLines = output.split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("\""), let colonIndex = trimmed.firstIndex(of: ":") else { return nil }
                return String(trimmed[trimmed.index(after: trimmed.startIndex)..<colonIndex]).replacingOccurrences(of: "\"", with: "")
            }
        XCTAssertEqual(keyLines, keyLines.sorted())
    }

    func testPrettyJSONOutputForRemindersArray() throws {
        let formatter = OutputFormatter(format: .prettyJson)
        let output = try captureStdout {
            try formatter.output(reminders: [makeReminder(id: "A"), makeReminder(id: "B")])
        }
        let data = output.data(using: .utf8)!
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(array?.map { $0["id"] as? String }, ["A", "B"])
    }

    // MARK: - yaml

    func testYAMLOutputContainsFields() throws {
        let formatter = OutputFormatter(format: .yaml)
        let output = try captureStdout {
            try formatter.output(reminder: makeReminder())
        }
        XCTAssertTrue(output.contains("id: TEST-ID"))
        XCTAssertTrue(output.contains("title: Buy milk"))
    }

    func testYAMLOutputForRemindersArrayIsAList() throws {
        let formatter = OutputFormatter(format: .yaml)
        let output = try captureStdout {
            try formatter.output(reminders: [makeReminder(id: "A"), makeReminder(id: "B")])
        }
        XCTAssertTrue(output.contains("- id: A"))
        XCTAssertTrue(output.contains("- id: B"))
    }

    // MARK: - text (single reminder)

    func testTextOutputForSingleReminderIncludesDetails() throws {
        let formatter = OutputFormatter(format: .text)
        let reminder = makeReminder(notes: "2% milk", priority: 1, priorityName: "High")
        let output = try captureStdout {
            try formatter.output(reminder: reminder)
        }
        XCTAssertTrue(output.contains("Title:      Buy milk"))
        XCTAssertTrue(output.contains("List:       Groceries"))
        XCTAssertTrue(output.contains("Notes:      2% milk"))
        XCTAssertTrue(output.contains("Priority:   1 (High)"))
    }

    func testTextOutputForSingleReminderOmitsNilFields() throws {
        let formatter = OutputFormatter(format: .text)
        let reminder = makeReminder(notes: nil, list: nil)
        let output = try captureStdout {
            try formatter.output(reminder: reminder)
        }
        XCTAssertFalse(output.contains("Notes:"))
        XCTAssertFalse(output.contains("List:"))
    }

    // MARK: - text (list)

    func testTextOutputForListShowsPriorityIndicatorAndDueDate() throws {
        let formatter = OutputFormatter(format: .text)
        let reminders = [
            makeReminder(title: "High priority", priority: 1, dueDate: "March 5, 2026"),
            makeReminder(title: "No priority", priority: 0)
        ]
        let output = try captureStdout {
            try formatter.output(reminders: reminders)
        }
        XCTAssertTrue(output.contains("‼️ High priority (due: March 5, 2026)"))
        XCTAssertTrue(output.contains("No priority"))
        XCTAssertFalse(output.contains("‼️ No priority"))
    }

    func testTextOutputForListShowsCompletionCheckbox() throws {
        let formatter = OutputFormatter(format: .text)
        let reminders = [
            makeReminder(title: "Done", isCompleted: true),
            makeReminder(title: "Not done", isCompleted: false)
        ]
        let output = try captureStdout {
            try formatter.output(reminders: reminders)
        }
        XCTAssertTrue(output.contains("☑ Done"))
        XCTAssertTrue(output.contains("☐ Not done"))
    }

    // MARK: - alarms in text output

    func testTextOutputIncludesAlarms() throws {
        let formatter = OutputFormatter(format: .text)
        let reminder = makeReminder(alarms: [
            AlarmOutput(type: "relative", value: "10 minutes before", proximity: nil),
            AlarmOutput(type: "location", value: "Home", proximity: "arriving")
        ])
        let output = try captureStdout {
            try formatter.output(reminder: reminder)
        }
        XCTAssertTrue(output.contains("Alarms:     2"))
        XCTAssertTrue(output.contains("10 minutes before"))
        XCTAssertTrue(output.contains("📍 Home (arriving)"))
    }

    // MARK: - delete confirmation

    func testDeleteConfirmationJSONOutput() throws {
        let formatter = OutputFormatter(format: .json)
        let confirmation = DeleteConfirmationOutput(deleted: true, id: "TEST-ID", title: "Buy milk")
        let output = try captureStdout {
            try formatter.output(deleteConfirmation: confirmation)
        }
        let data = output.data(using: .utf8)!
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["deleted"] as? Bool, true)
        XCTAssertEqual(object?["id"] as? String, "TEST-ID")
        XCTAssertEqual(object?["title"] as? String, "Buy milk")
    }

    func testDeleteConfirmationYAMLOutput() throws {
        let formatter = OutputFormatter(format: .yaml)
        let confirmation = DeleteConfirmationOutput(deleted: true, id: "TEST-ID", title: "Buy milk")
        let output = try captureStdout {
            try formatter.output(deleteConfirmation: confirmation)
        }
        XCTAssertTrue(output.contains("deleted: true"))
        XCTAssertTrue(output.contains("id: TEST-ID"))
    }

    // MARK: - lists

    func testListsJSONOutput() throws {
        let formatter = OutputFormatter(format: .json)
        let lists = [
            ListOutput(name: "Shopping", calendarIdentifier: "CAL-1", color: "#FF0000", reminderCount: 3),
            ListOutput(name: "Work", calendarIdentifier: "CAL-2", color: nil, reminderCount: nil)
        ]
        let output = try captureStdout {
            try formatter.output(lists: lists)
        }
        let data = output.data(using: .utf8)!
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(array?.map { $0["name"] as? String }, ["Shopping", "Work"])
        XCTAssertEqual(array?[0]["reminderCount"] as? Int, 3)
        XCTAssertNil(array?[1]["reminderCount"])
    }

    func testListsTextOutputShowsCountOnlyWhenPresent() throws {
        let formatter = OutputFormatter(format: .text)
        let lists = [
            ListOutput(name: "Shopping", calendarIdentifier: "CAL-1", color: nil, reminderCount: 3),
            ListOutput(name: "Work", calendarIdentifier: "CAL-2", color: nil, reminderCount: nil)
        ]
        let output = try captureStdout {
            try formatter.output(lists: lists)
        }
        XCTAssertTrue(output.contains("Shopping (3)"))
        XCTAssertTrue(output.contains("Work"))
        XCTAssertFalse(output.contains("Work ("))
    }

    func testListsTextOutputForEmptyList() throws {
        let formatter = OutputFormatter(format: .text)
        let output = try captureStdout {
            try formatter.output(lists: [])
        }
        XCTAssertTrue(output.contains("(no lists)"))
    }

    // MARK: - hexColor

    // Exercises hexColor directly with synthetic CGColor values rather than
    // going through a real EKCalendar: constructing/mutating EKCalendar
    // properties needs EventKit permissions that aren't granted on CI
    // runners (see README's Testing section), so cgColor round-trips
    // through EKCalendar aren't reliable there.

    func testHexColorFromRGBColorspace() {
        let formatter = OutputFormatter(format: .json)
        let rgbSpace = CGColorSpaceCreateDeviceRGB()
        let color = CGColor(colorSpace: rgbSpace, components: [1.0, 0.0, 0.0, 1.0])!

        XCTAssertEqual(formatter.hexColor(from: color), "#FF0000")
    }

    func testHexColorFromGrayscaleColorspace() {
        let formatter = OutputFormatter(format: .json)
        let graySpace = CGColorSpaceCreateDeviceGray()
        let color = CGColor(colorSpace: graySpace, components: [0.5, 1.0])!

        XCTAssertEqual(formatter.hexColor(from: color), "#808080")
    }

    func testHexColorFromNilReturnsNil() {
        let formatter = OutputFormatter(format: .json)
        XCTAssertNil(formatter.hexColor(from: nil))
    }
}
