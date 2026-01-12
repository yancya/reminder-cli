import ArgumentParser
@preconcurrency import EventKit
import Foundation

@main
struct ReminderCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reminder-cli",
        abstract: "A CLI tool to manage iCloud Reminders",
        version: "0.1.1",
        subcommands: [
            List.self,
            Show.self,
            Create.self,
            Update.self,
            Delete.self,
            Complete.self
        ]
    )
}

// MARK: - List Command
extension ReminderCLI {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all reminders or reminders in a specific list"
        )

        @Argument(help: "The name of the list to show reminders from")
        var listName: String?

        @Flag(name: .shortAndLong, help: "Show completed reminders")
        var completed: Bool = false

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()

            if let listName = listName {
                try await store.listReminders(in: listName, showCompleted: completed)
            } else {
                try await store.listAllReminders(showCompleted: completed)
            }
        }
    }
}

// MARK: - Show Command
extension ReminderCLI {
    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show details of a specific reminder"
        )

        @Argument(help: "The ID or title of the reminder to show")
        var identifier: String

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.showReminder(identifier: identifier)
        }
    }
}

// MARK: - Create Command
extension ReminderCLI {
    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new reminder"
        )

        @Argument(help: "The title of the reminder")
        var title: String

        @Option(name: .shortAndLong, help: "The list to add the reminder to")
        var list: String?

        @Option(name: .shortAndLong, help: "Notes for the reminder")
        var notes: String?

        @Option(help: "Start date (format: YYYY-MM-DD or YYYY-MM-DD HH:MM)")
        var startDate: String?

        @Option(help: "Due date (format: YYYY-MM-DD or YYYY-MM-DD HH:MM)")
        var dueDate: String?

        @Option(name: .shortAndLong, help: "Priority (0-9, where 0=none, 1-4=high, 5=medium, 6-9=low)")
        var priority: Int?

        @Flag(name: .shortAndLong, help: "Mark as flagged")
        var flagged: Bool = false

        @Option(name: .shortAndLong, help: "URL associated with the reminder")
        var url: String?

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.createReminder(
                title: title,
                listName: list,
                notes: notes,
                startDate: startDate,
                dueDate: dueDate,
                priority: priority,
                flagged: flagged ? true : nil,
                url: url
            )
        }
    }
}

// MARK: - Update Command
extension ReminderCLI {
    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Update an existing reminder"
        )

        @Argument(help: "The ID or title of the reminder to update")
        var identifier: String

        @Option(name: .shortAndLong, help: "New title")
        var title: String?

        @Option(name: .shortAndLong, help: "New notes")
        var notes: String?

        @Option(help: "New start date (format: YYYY-MM-DD or YYYY-MM-DD HH:MM)")
        var startDate: String?

        @Option(help: "New due date (format: YYYY-MM-DD or YYYY-MM-DD HH:MM)")
        var dueDate: String?

        @Option(name: .shortAndLong, help: "New priority (0-9)")
        var priority: Int?

        @Option(name: .long, help: "Set flagged status (true/false)")
        var flagged: Bool?

        @Option(name: .shortAndLong, help: "New URL")
        var url: String?

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.updateReminder(
                identifier: identifier,
                title: title,
                notes: notes,
                startDate: startDate,
                dueDate: dueDate,
                priority: priority,
                flagged: flagged,
                url: url
            )
        }
    }
}

// MARK: - Delete Command
extension ReminderCLI {
    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a reminder"
        )

        @Argument(help: "The ID or title of the reminder to delete")
        var identifier: String

        @Flag(name: .shortAndLong, help: "Skip confirmation")
        var force: Bool = false

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.deleteReminder(identifier: identifier, force: force)
        }
    }
}

// MARK: - Complete Command
extension ReminderCLI {
    struct Complete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Mark a reminder as completed"
        )

        @Argument(help: "The ID or title of the reminder to complete")
        var identifier: String

        mutating func run() async throws {
            let store = ReminderStore()
            try await store.requestAccess()
            try await store.completeReminder(identifier: identifier)
        }
    }
}
