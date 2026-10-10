import XCTest
@testable import reminder_cli

final class ReminderStoreErrorTests: XCTestCase {
    func testAmbiguousIdentifierListsEachMatchWithShortAndFullID() {
        let error = ReminderStoreError.ambiguousIdentifier("ABC", [
            .init(id: "ABCDEF12-0000-0000-0000-000000000001", title: "Buy milk"),
            .init(id: "ABCDEF34-0000-0000-0000-000000000002", title: nil),
        ])

        let message = error.errorDescription ?? ""

        XCTAssertTrue(message.hasPrefix("Ambiguous identifier 'ABC' matches 2 reminders:\n"))
        XCTAssertTrue(message.contains("  [ABCDEF12] ABCDEF12-0000-0000-0000-000000000001 - Buy milk\n"))
        XCTAssertTrue(message.contains("  [ABCDEF34] ABCDEF34-0000-0000-0000-000000000002 - (no title)\n"))
        XCTAssertTrue(message.hasSuffix("Please use a longer prefix (e.g., 9+ characters) or the full ID."))
    }
}
