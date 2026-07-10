import XCTest
@testable import reminder_cli

final class DateParsingTests: XCTestCase {
    func testParsesDateOnly() {
        let components = DateParsing.parse("2026-03-05")
        XCTAssertEqual(components?.year, 2026)
        XCTAssertEqual(components?.month, 3)
        XCTAssertEqual(components?.day, 5)
        XCTAssertNil(components?.hour)
    }

    func testParsesDateWithTime() {
        let components = DateParsing.parse("2026-03-05 14:30")
        XCTAssertEqual(components?.year, 2026)
        XCTAssertEqual(components?.month, 3)
        XCTAssertEqual(components?.day, 5)
        XCTAssertEqual(components?.hour, 14)
        XCTAssertEqual(components?.minute, 30)
    }

    func testRejectsInvalidFormat() {
        XCTAssertNil(DateParsing.parse("not-a-date"))
        XCTAssertNil(DateParsing.parse(""))
    }
}
