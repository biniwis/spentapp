import XCTest
@testable import MoneyCity

final class SavingsGoalTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testProgressIsClampedAtBothEnds() {
        XCTAssertEqual(SavingsGoalService.fraction(saved: 0, target: 4000), 0)
        XCTAssertEqual(SavingsGoalService.fraction(saved: 1000, target: 4000), 0.25)
        // Overshooting a goal does not produce 140% of a progress bar.
        XCTAssertEqual(SavingsGoalService.fraction(saved: 5600, target: 4000), 1.0)
        // A goal with no target has no progress rather than infinite progress.
        XCTAssertEqual(SavingsGoalService.fraction(saved: 500, target: 0), 0)
    }

    func testRemainingNeverGoesNegative() {
        XCTAssertEqual(SavingsGoalService.remaining(saved: 5600, target: 4000), 0)
        XCTAssertEqual(SavingsGoalService.remaining(saved: 1000, target: 4000), 3000)
    }

    func testMonthsRemainingCountsTheCurrentMonth() {
        // May to August inclusive is four months to put money aside.
        XCTAssertEqual(
            SavingsGoalService.monthsRemaining(until: date(2026, 8, 1), from: date(2026, 5, 20), calendar: cal),
            4
        )
    }

    func testADeadlineThatHasArrivedStillLeavesOneMonth() {
        // "You need the rest this month" beats dividing by zero.
        XCTAssertEqual(
            SavingsGoalService.monthsRemaining(until: date(2026, 5, 1), from: date(2026, 5, 20), calendar: cal),
            1
        )
        XCTAssertEqual(
            SavingsGoalService.monthsRemaining(until: date(2026, 1, 1), from: date(2026, 5, 20), calendar: cal),
            1
        )
    }

    func testNoDeadlineMeansNoMonthlyTarget() {
        XCTAssertNil(SavingsGoalService.monthsRemaining(until: nil, from: date(2026, 5, 20), calendar: cal))
        XCTAssertNil(SavingsGoalService.monthlyContributionNeeded(
            saved: 0, target: 4000, targetDate: nil, from: date(2026, 5, 20), calendar: cal
        ))
    }

    func testMonthlyContributionSplitsWhatIsLeftAcrossTheMonthsLeft() {
        let needed = SavingsGoalService.monthlyContributionNeeded(
            saved: 1000, target: 5000, targetDate: date(2026, 8, 1), from: date(2026, 5, 20), calendar: cal
        )
        XCTAssertNotNil(needed)
        XCTAssertEqual(needed!, 1000, accuracy: 0.0001) // ₪4,000 over 4 months
    }

    func testAMetGoalNeedsNothingMore() {
        XCTAssertNil(SavingsGoalService.monthlyContributionNeeded(
            saved: 5000, target: 5000, targetDate: date(2026, 8, 1), from: date(2026, 5, 20), calendar: cal
        ))
    }

    func testDepositIsRecordedAsARealSavingsTransfer() {
        let tx = SavingsGoalService.makeDepositTransaction(goalName: "טיול ליפן", amount: 500, currency: "₪")
        XCTAssertEqual(tx.category, .savings)
        XCTAssertEqual(tx.amount, 500)
        XCTAssertEqual(tx.buildingId, "savings_sanctuary")
        XCTAssertTrue(tx.isConfirmed)
        // It must not count as spending anywhere.
        XCTAssertEqual(BudgetService.totalSpent([tx]), 0)
        XCTAssertEqual(BudgetService.totalSavedToSavings([tx]), 500)
    }

    func testCompletedGoalBecomesACityLandmark() {
        let goal = SavingsGoal(name: "טיול ליפן", icon: "✈️", targetAmount: 4000, savedAmount: 4000)
        XCTAssertTrue(goal.isComplete)
        let enrichment = SavingsGoalService.makeCompletionEnrichment(for: goal)
        XCTAssertEqual(enrichment.type, .landmark)
        XCTAssertEqual(enrichment.districtId, "savings")
        XCTAssertEqual(enrichment.icon, "✈️")
    }

    func testAGoalIsNotCompleteWithoutATarget() {
        let goal = SavingsGoal(name: "x", targetAmount: 0, savedAmount: 100)
        XCTAssertFalse(goal.isComplete)
    }
}
