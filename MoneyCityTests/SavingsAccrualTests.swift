import XCTest
@testable import MoneyCity

/// The city used to credit the whole monthly budget as savings the instant a month began,
/// so a brand-new user with nothing recorded opened the app to a full savings park and a
/// five-figure number they had not earned. Unspent budget now accrues by completed day.
final class SavingsAccrualTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func fraction(month: Date, now: Date) -> Double {
        CitySimulationEngine.budgetAccruedFraction(for: month, now: now, calendar: calendar)
    }

    func testNothingHasAccruedOnTheFirstOfTheMonth() {
        let d = date(2026, 8, 1)
        XCTAssertEqual(fraction(month: d, now: d), 0.0, accuracy: 0.0001)
    }

    func testOneDayHasAccruedOnTheSecond() {
        let d = date(2026, 8, 2)
        XCTAssertEqual(fraction(month: d, now: d), 1.0 / 31.0, accuracy: 0.0001)
    }

    func testAboutHalfHasAccruedMidMonth() {
        let d = date(2026, 8, 16)
        XCTAssertEqual(fraction(month: d, now: d), 15.0 / 31.0, accuracy: 0.0001)
    }

    func testAMonthNeverOverAccruesOnItsLastDay() {
        let d = date(2026, 8, 31)
        XCTAssertLessThan(fraction(month: d, now: d), 1.0)
    }

    func testAPastMonthIsFullyAccrued() {
        XCTAssertEqual(fraction(month: date(2026, 7, 10), now: date(2026, 8, 15)), 1.0, accuracy: 0.0001)
    }

    func testAFutureMonthHasAccruedNothing() {
        XCTAssertEqual(fraction(month: date(2026, 9, 10), now: date(2026, 8, 15)), 0.0, accuracy: 0.0001)
    }

    func testShortMonthUsesItsOwnLength() {
        // February 2026 has 28 days, so a completed day is worth more of the budget.
        let d = date(2026, 2, 15)
        XCTAssertEqual(fraction(month: d, now: d), 14.0 / 28.0, accuracy: 0.0001)
    }

    func testLeapFebruaryUsesTwentyNineDays() {
        let d = date(2028, 2, 15)
        XCTAssertEqual(fraction(month: d, now: d), 14.0 / 29.0, accuracy: 0.0001)
    }

    func testFractionIsAlwaysInRange() {
        for month in 1...12 {
            for day in [1, 2, 14, 28] {
                let d = date(2026, month, day)
                let f = fraction(month: d, now: d)
                XCTAssertGreaterThanOrEqual(f, 0.0)
                XCTAssertLessThanOrEqual(f, 1.0)
            }
        }
    }
}
