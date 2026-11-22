import ArgumentParser
import XCTest
@testable import reminder_cli

final class ListsCommandParsingTests: XCTestCase {
    func testBareListsStillRunsListing() throws {
        let command = try ReminderCLI.parseAsRoot(["lists"])
        let listAll = try XCTUnwrap(command as? ReminderCLI.Lists.ListAll)
        XCTAssertFalse(listAll.count)
        XCTAssertEqual(listAll.format, .text)
    }

    func testListsOptionsAreForwardedToListingForBackwardCompatibility() throws {
        let command = try ReminderCLI.parseAsRoot(["lists", "--count", "-f", "json"])
        let listAll = try XCTUnwrap(command as? ReminderCLI.Lists.ListAll)
        XCTAssertTrue(listAll.count)
        XCTAssertEqual(listAll.format, .json)
    }

    func testListsCreateParsesNameAndFormat() throws {
        let command = try ReminderCLI.parseAsRoot(["lists", "create", "Groceries", "-f", "yaml"])
        let create = try XCTUnwrap(command as? ReminderCLI.Lists.Create)
        XCTAssertEqual(create.name, "Groceries")
        XCTAssertEqual(create.format, .yaml)
    }

    func testListsDeleteUsesShortFForForceAndLongOnlyFormat() throws {
        let command = try ReminderCLI.parseAsRoot(["lists", "delete", "Groceries", "-f", "--format", "json"])
        let delete = try XCTUnwrap(command as? ReminderCLI.Lists.Delete)
        XCTAssertEqual(delete.list, "Groceries")
        XCTAssertTrue(delete.force)
        XCTAssertEqual(delete.format, .json)
    }

    func testListsDeleteDefaultsToConfirmation() throws {
        let command = try ReminderCLI.parseAsRoot(["lists", "delete", "Groceries"])
        let delete = try XCTUnwrap(command as? ReminderCLI.Lists.Delete)
        XCTAssertFalse(delete.force)
        XCTAssertEqual(delete.format, .text)
    }
}

final class ListMatcherTests: XCTestCase {
    private let lists: [ListMatcher.Candidate] = [
        .init(id: "CAL-1", title: "Work"),
        .init(id: "CAL-2", title: "Groceries"),
        .init(id: "CAL-3", title: "work"),
    ]

    func testExactIdentifierWinsOverTitle() throws {
        let candidates: [ListMatcher.Candidate] = [
            .init(id: "Groceries", title: "Oddly named"),
            .init(id: "CAL-2", title: "Groceries"),
        ]
        XCTAssertEqual(try ListMatcher.resolve("Groceries", in: candidates).id, "Groceries")
    }

    func testTitleMatchIsCaseInsensitive() throws {
        XCTAssertEqual(try ListMatcher.resolve("GROCERIES", in: lists).id, "CAL-2")
    }

    func testAmbiguousTitleThrowsWithAllMatches() {
        XCTAssertThrowsError(try ListMatcher.resolve("WORK", in: lists)) { error in
            guard case ReminderStoreError.ambiguousListName(let name, let matches) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(name, "WORK")
            XCTAssertEqual(matches.map(\.id), ["CAL-1", "CAL-3"])
        }
    }

    func testUnknownListThrowsListNotFound() {
        XCTAssertThrowsError(try ListMatcher.resolve("Nope", in: lists)) { error in
            guard case ReminderStoreError.listNotFound("Nope") = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testValidateNewNameTrimsWhitespace() throws {
        XCTAssertEqual(try ListMatcher.validateNewName("  Shopping \n", existing: lists), "Shopping")
    }

    func testValidateNewNameRejectsBlank() {
        XCTAssertThrowsError(try ListMatcher.validateNewName("   ", existing: lists)) { error in
            guard case ReminderStoreError.invalidListName = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testValidateNewNameRejectsCaseInsensitiveDuplicate() {
        XCTAssertThrowsError(try ListMatcher.validateNewName("groceries", existing: lists)) { error in
            guard case ReminderStoreError.listAlreadyExists("Groceries") = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }
}

final class ListErrorMessageTests: XCTestCase {
    func testAmbiguousListNameSuggestsCalendarIdentifier() {
        let message = ReminderStoreError.ambiguousListName("work", [
            .init(id: "CAL-1", title: "Work"),
            .init(id: "CAL-3", title: "work"),
        ]).errorDescription ?? ""
        XCTAssertTrue(message.hasPrefix("Ambiguous list name 'work' matches 2 lists:\n"))
        XCTAssertTrue(message.contains("  CAL-1 - Work\n"))
        XCTAssertTrue(message.contains("  CAL-3 - work\n"))
        XCTAssertTrue(message.hasSuffix("Please specify the list by its calendarIdentifier (see `reminder-cli lists --format json`)."))
    }

    func testListAlreadyExistsMessage() {
        XCTAssertEqual(ReminderStoreError.listAlreadyExists("Groceries").errorDescription, "List already exists: Groceries")
    }

    func testListNotDeletableMessage() {
        XCTAssertEqual(
            ReminderStoreError.listNotDeletable("Inbox").errorDescription,
            "List cannot be deleted (it is read-only or managed by its account): Inbox"
        )
    }

    func testInvalidListNameMessage() {
        XCTAssertEqual(ReminderStoreError.invalidListName.errorDescription, "List name must not be empty")
    }
}
