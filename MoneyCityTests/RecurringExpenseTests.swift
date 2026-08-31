import XCTest
@testable import MoneyCity

/// Fixed expenses post themselves without anyone watching, so the scheduling maths has to be
/// right in the awkward cases: short months, a phone left closed for a season, a month the
/// user already typed in by hand.
final class RecurringExpenseTests: XCTestCase {

    /// Fixed calendar so these assertions do not depend on where the test runs.
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return cal.date(from: comps)!
    }

    // MARK: - Period keys

    func testPeriodKeyIsZeroPaddedAndSortable() {
        XCTAssertEqual(RecurringExpenseService.periodKey(for: date(2026, 3, 9), calendar: cal), "2026-03")
        XCTAssertEqual(RecurringExpenseService.periodKey(for: date(2026, 12, 31), calendar: cal), "2026-12")
        // Assert the property through the production function, not two literals.
        XCTAssertTrue(
            RecurringExpenseService.periodKey(for: date(2026, 3, 9), calendar: cal)
                < RecurringExpenseService.periodKey(for: date(2026, 12, 1), calendar: cal)
        )
    }

    // MARK: - Short months

    func testDay31ClampsToTheLastDayOfAShortMonth() {
        let feb = RecurringExpenseService.occurrenceDate(period: "2026-02", dayOfMonth: 31, calendar: cal)
        XCTAssertNotNil(feb)
        XCTAssertEqual(cal.component(.day, from: feb!), 28) // 2026 is not a leap year

        let apr = RecurringExpenseService.occurrenceDate(period: "2026-04", dayOfMonth: 31, calendar: cal)
        XCTAssertEqual(cal.component(.day, from: apr!), 30)
    }

    func testLeapFebruaryKeepsItsExtraDay() {
        let feb = RecurringExpenseService.occurrenceDate(period: "2028-02", dayOfMonth: 31, calendar: cal)
        XCTAssertEqual(cal.component(.day, from: feb!), 29)
    }

    // MARK: - What is owed

    func testNothingIsOwedBeforeTheChargeDayArrives() {
        // Template created on the 3rd, charges on the 10th, today is the 5th.
        let due = RecurringExpenseService.duePeriods(
            lastGeneratedPeriod: nil,
            createdAt: date(2026, 5, 3),
            dayOfMonth: 10,
            now: date(2026, 5, 5),
            calendar: cal
        )
        XCTAssertTrue(due.isEmpty)
    }

    func testCurrentMonthIsOwedOnceTheDayHasPassed() {
        let due = RecurringExpenseService.duePeriods(
            lastGeneratedPeriod: nil,
            createdAt: date(2026, 5, 1),
            dayOfMonth: 10,
            now: date(2026, 5, 11),
            calendar: cal
        )
        XCTAssertEqual(due, ["2026-05"])
    }

    func testCreationMonthIsBackfilledEvenWhenSetUpAfterTheChargeDay() {
        // Set up on the 20th for rent that goes out on the 1st — that rent was still paid.
        let due = RecurringExpenseService.duePeriods(
            lastGeneratedPeriod: nil,
            createdAt: date(2026, 5, 20),
            dayOfMonth: 1,
            now: date(2026, 5, 20),
            calendar: cal
        )
        XCTAssertEqual(due, ["2026-05"])
    }

    func testMonthsMissedWhileTheAppWasClosedAreCaughtUp() {
        let due = RecurringExpenseService.duePeriods(
            lastGeneratedPeriod: "2026-01",
            createdAt: date(2026, 1, 1),
            dayOfMonth: 5,
            now: date(2026, 5, 6),
            calendar: cal
        )
        XCTAssertEqual(due, ["2026-02", "2026-03", "2026-04", "2026-05"])
    }

    func testAlreadyGeneratedMonthIsNotOwedAgain() {
        let due = RecurringExpenseService.duePeriods(
            lastGeneratedPeriod: "2026-05",
            createdAt: date(2026, 1, 1),
            dayOfMonth: 5,
            now: date(2026, 5, 28),
            calendar: cal
        )
        XCTAssertTrue(due.isEmpty)
    }

    func testCatchUpIsCappedSoADormantTemplateCannotFloodTheCity() {
        let due = RecurringExpenseService.duePeriods(
            lastGeneratedPeriod: "2020-01",
            createdAt: date(2020, 1, 1),
            dayOfMonth: 1,
            now: date(2026, 5, 15),
            calendar: cal
        )
        XCTAssertEqual(due.count, RecurringExpenseService.maxCatchUpMonths)
        // Pin both ends — asserting only the count and the tail let a wrong 12-month
        // window (off by a year) pass.
        XCTAssertEqual(due.first, "2025-06")
        XCTAssertEqual(due.last, "2026-05")
    }

    func testYearBoundaryIsCrossedCorrectly() {
        let due = RecurringExpenseService.duePeriods(
            lastGeneratedPeriod: "2025-11",
            createdAt: date(2025, 11, 1),
            dayOfMonth: 1,
            now: date(2026, 1, 15),
            calendar: cal
        )
        XCTAssertEqual(due, ["2025-12", "2026-01"])
    }

    // MARK: - Not stepping on a manual entry

    func testAMonthTheUserAlreadyTypedInIsNotDuplicated() {
        let manualRent = Transaction(
            amount: 1850,
            merchant: "שכר דירה",
            category: .housing,
            timestamp: date(2026, 5, 1)
        )
        XCTAssertTrue(
            RecurringExpenseService.alreadyRecorded(
                merchant: "שכר דירה",
                amount: 1850,
                period: "2026-05",
                in: [manualRent],
                calendar: cal
            )
        )
        // A different month is still owed.
        XCTAssertFalse(
            RecurringExpenseService.alreadyRecorded(
                merchant: "שכר דירה",
                amount: 1850,
                period: "2026-06",
                in: [manualRent],
                calendar: cal
            )
        )
    }

    func testMerchantMatchIgnoresCaseAndPadding() {
        let tx = Transaction(amount: 54.90, merchant: "  Netflix ", category: .subscriptions, timestamp: date(2026, 5, 4))
        XCTAssertTrue(
            RecurringExpenseService.alreadyRecorded(merchant: "netflix", amount: 54.90, period: "2026-05", in: [tx], calendar: cal)
        )
    }

    /// A one-off purchase at the same merchant must NOT cancel that month's subscription.
    /// Matching on the merchant name alone silently dropped the real charge, for good.
    func testUnrelatedPurchaseAtTheSameMerchantDoesNotCancelTheSubscription() {
        let giftCard = Transaction(
            amount: 75,
            merchant: "Netflix",
            category: .subscriptions,
            timestamp: date(2026, 5, 2)
        )
        XCTAssertFalse(
            RecurringExpenseService.alreadyRecorded(
                merchant: "Netflix", amount: 54.90, period: "2026-05", in: [giftCard], calendar: cal
            )
        )

        let template = RecurringExpense(
            merchant: "Netflix", amount: 54.90, category: .subscriptions,
            dayOfMonth: 4, createdAt: date(2026, 5, 1)
        )
        XCTAssertNotNil(
            RecurringExpenseService.makeTransaction(
                for: template, period: "2026-05", existing: [giftCard], calendar: cal
            )
        )
    }

    /// A marker left in the future must not silence the template until that month arrives.
    func testAMarkerInTheFutureRecoversInsteadOfWedging() {
        let due = RecurringExpenseService.duePeriods(
            lastGeneratedPeriod: "2027-03",
            createdAt: date(2026, 1, 1),
            dayOfMonth: 1,
            now: date(2026, 9, 15),
            calendar: cal
        )
        XCTAssertEqual(due, ["2026-09"])
    }

    func testGeneratedTransactionCarriesTemplateValues() throws {
        let template = RecurringExpense(
            merchant: "נטפליקס",
            amount: 54.90,
            category: .subscriptions,
            dayOfMonth: 4,
            createdAt: date(2026, 5, 1)
        )
        let tx = try XCTUnwrap(
            RecurringExpenseService.makeTransaction(
                for: template, period: "2026-05", existing: [], calendar: cal
            )
        )
        XCTAssertEqual(tx.amount, 54.90)
        XCTAssertEqual(tx.category, .subscriptions)
        XCTAssertEqual(tx.buildingId, "house_subs")
        XCTAssertTrue(tx.isConfirmed)
        XCTAssertEqual(cal.component(.day, from: tx.timestamp), 4)
    }

    func testDayIsClampedIntoRangeOnCreation() {
        XCTAssertEqual(RecurringExpense(merchant: "x", amount: 1, category: .other, dayOfMonth: 99).dayOfMonth, 31)
        XCTAssertEqual(RecurringExpense(merchant: "x", amount: 1, category: .other, dayOfMonth: 0).dayOfMonth, 1)
    }
}
