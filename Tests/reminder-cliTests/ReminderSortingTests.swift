import XCTest
@testable import reminder_cli

private struct FakeReminder: ReminderSortable {
    var sortTitle: String?
    var sortIsCompleted: Bool
    var sortPriority: Int
    var sortHasDueDate: Bool
    var sortDueDate: Date?
    var sortCreationDate: Date?

    init(
        title: String? = "",
        isCompleted: Bool = false,
        priority: Int = 0,
        hasDueDate: Bool? = nil,
        dueDate: Date? = nil,
        creationDate: Date? = nil
    ) {
        self.sortTitle = title
        self.sortIsCompleted = isCompleted
        self.sortPriority = priority
        self.sortHasDueDate = hasDueDate ?? (dueDate != nil)
        self.sortDueDate = dueDate
        self.sortCreationDate = creationDate
    }
}

final class ReminderSortingTests: XCTestCase {
    private let day1 = Date(timeIntervalSince1970: 1_000_000)
    private let day2 = Date(timeIntervalSince1970: 2_000_000)

    func testCompletedAlwaysSortsLast() {
        let completed = FakeReminder(title: "A", isCompleted: true)
        let pending = FakeReminder(title: "Z", isCompleted: false)
        let comparator: (FakeReminder, FakeReminder) -> Bool = ReminderSorting.comparator(for: .title)
        XCTAssertTrue(comparator(pending, completed))
        XCTAssertFalse(comparator(completed, pending))
    }

    func testByDueDateOrdersEarlierFirstAndNilLast() {
        let earlier = FakeReminder(dueDate: day1)
        let later = FakeReminder(dueDate: day2)
        let none = FakeReminder(dueDate: nil)
        XCTAssertTrue(ReminderSorting.byDueDate(earlier, later))
        XCTAssertFalse(ReminderSorting.byDueDate(later, earlier))
        XCTAssertTrue(ReminderSorting.byDueDate(earlier, none))
        XCTAssertFalse(ReminderSorting.byDueDate(none, earlier))
    }

    func testByDueDateTreatsUnresolvableComponentsAsHavingADueDate() {
        // sortHasDueDate=true but sortDueDate=nil mirrors EKReminder having
        // dueDateComponents set but .date failing to resolve (e.g. invalid
        // components). The pre-refactor implementation checked
        // dueDateComponents != nil, not the resolved Date, for this branch.
        let unresolvable = FakeReminder(hasDueDate: true, dueDate: nil)
        let none = FakeReminder(hasDueDate: false, dueDate: nil)
        XCTAssertTrue(ReminderSorting.byDueDate(unresolvable, none))
        XCTAssertFalse(ReminderSorting.byDueDate(none, unresolvable))
    }

    func testByPriorityOrdersHighBeforeNoneAndZeroIsLowest() {
        let high = FakeReminder(priority: 1)
        let low = FakeReminder(priority: 9)
        let none = FakeReminder(priority: 0)
        XCTAssertTrue(ReminderSorting.byPriority(high, low))
        XCTAssertTrue(ReminderSorting.byPriority(low, none))
        XCTAssertFalse(ReminderSorting.byPriority(none, high))
    }

    func testByTitleIsCaseInsensitive() {
        let lower = FakeReminder(title: "apple")
        let upper = FakeReminder(title: "Banana")
        XCTAssertTrue(ReminderSorting.byTitle(lower, upper))
    }

    func testByCreatedOrdersNewerFirstAndNilLast() {
        let newer = FakeReminder(creationDate: day2)
        let older = FakeReminder(creationDate: day1)
        let none = FakeReminder(creationDate: nil)
        XCTAssertTrue(ReminderSorting.byCreated(newer, older))
        XCTAssertTrue(ReminderSorting.byCreated(older, none))
    }

    func testStatusOverdueWhenDueDateInPastAndNotToday() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let pastDueDate = Date(timeIntervalSince1970: 1_000_000)
        let status = ReminderSorting.status(isCompleted: false, dueDate: pastDueDate, now: now)
        XCTAssertEqual(status, .overdue)
    }

    func testStatusPendingWhenNoDueDate() {
        let status = ReminderSorting.status(isCompleted: false, dueDate: nil)
        XCTAssertEqual(status, .pending)
    }

    func testStatusCompletedTakesPrecedence() {
        let status = ReminderSorting.status(isCompleted: true, dueDate: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(status, .completed)
    }

    func testStatusDueTodayAndScheduled() {
        let calendar = Calendar.current
        let now = Date()
        let dueToday = calendar.startOfDay(for: now).addingTimeInterval(3600)
        let future = now.addingTimeInterval(60 * 60 * 24 * 7)

        XCTAssertEqual(ReminderSorting.status(isCompleted: false, dueDate: dueToday, now: now), .dueToday)
        XCTAssertEqual(ReminderSorting.status(isCompleted: false, dueDate: future, now: now), .scheduled)
    }

    func testByStatusOrdersOverdueBeforeDueTodayBeforeScheduledBeforePendingBeforeCompleted() {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let calendar = Calendar.current

        let overdue = FakeReminder(title: "overdue", dueDate: now.addingTimeInterval(-3600 * 48))
        let dueToday = FakeReminder(title: "dueToday", dueDate: calendar.startOfDay(for: now).addingTimeInterval(3600))
        let scheduled = FakeReminder(title: "scheduled", dueDate: now.addingTimeInterval(3600 * 48))
        let pending = FakeReminder(title: "pending", dueDate: nil)
        let completed = FakeReminder(title: "completed", isCompleted: true)

        let ordered = [pending, completed, scheduled, overdue, dueToday].sorted {
            ReminderSorting.byStatus($0, $1, now: now, calendar: calendar)
        }

        XCTAssertEqual(ordered.map { $0.sortTitle }, ["overdue", "dueToday", "scheduled", "pending", "completed"])
    }

    func testStatusComparatorUsesFreshNowOnEachComparison() {
        var callCount = 0
        let comparator: (FakeReminder, FakeReminder) -> Bool = ReminderSorting.comparator(
            for: .status,
            now: {
                callCount += 1
                return Date(timeIntervalSince1970: 10_000_000)
            }
        )
        let a = FakeReminder(title: "a", dueDate: Date(timeIntervalSince1970: 9_000_000))
        let b = FakeReminder(title: "b", dueDate: Date(timeIntervalSince1970: 11_000_000))
        _ = comparator(a, b)
        _ = comparator(b, a)
        XCTAssertEqual(callCount, 2)
    }
}
