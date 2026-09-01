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
        let gid = UUID()
        let tx = SavingsGoalService.makeDepositTransaction(goalId: gid, goalName: "טיול ליפן", amount: 500, currency: "₪")
        XCTAssertEqual(tx.category, SpendingCategory.savings)
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


/// A deposit used to write the goal's total and a transaction independently, with nothing
/// linking them, so deleting the transfer from history left the goal claiming money that no
/// longer existed. Progress is now derived from the transfers that still exist.
final class SavingsGoalReconciliationTests: XCTestCase {

    private func deposit(_ amount: Double, to goal: SavingsGoal) -> Transaction {
        SavingsGoalService.makeDepositTransaction(
            goalId: goal.id, goalName: goal.name, amount: amount, currency: "₪"
        )
    }

    func testDepositCarriesTheGoalId() {
        let goal = SavingsGoal(name: "טיול", targetAmount: 4000)
        XCTAssertEqual(deposit(500, to: goal).savingsGoalId, goal.id)
    }

    func testReconciledAmountIsBaselinePlusSurvivingDeposits() {
        XCTAssertEqual(SavingsGoalService.reconciledAmount(baseline: 0, linkedDeposits: [500, 250]), 750)
        XCTAssertEqual(SavingsGoalService.reconciledAmount(baseline: 1200, linkedDeposits: [300]), 1500)
        XCTAssertEqual(SavingsGoalService.reconciledAmount(baseline: 0, linkedDeposits: []), 0)
    }

    func testNegativeBaselineCannotDragAGoalBelowZero() {
        XCTAssertEqual(SavingsGoalService.reconciledAmount(baseline: -900, linkedDeposits: [100]), 100)
    }

    func testDeletingADepositLowersTheGoalByExactlyThatDeposit() {
        let goal = SavingsGoal(name: "מחשב", targetAmount: 6000)
        let first = deposit(500, to: goal)
        let second = deposit(250, to: goal)
        goal.savedAmount = 750
        goal.baselineCaptured = true
        goal.unlinkedBaseline = 0

        // The user deletes the ₪500 row from History.
        SavingsGoalService.reconcile(goals: [goal], transactions: [second])
        XCTAssertEqual(goal.savedAmount, 250, accuracy: 0.001)
        XCTAssertNotNil(first) // silence unused warning; the deleted row is simply absent
    }

    func testEditingADepositMovesTheGoalByTheDifference() {
        let goal = SavingsGoal(name: "חופשה", targetAmount: 3000)
        let tx = deposit(400, to: goal)
        goal.savedAmount = 400
        goal.baselineCaptured = true

        tx.amount = 650
        SavingsGoalService.reconcile(goals: [goal], transactions: [tx])
        XCTAssertEqual(goal.savedAmount, 650, accuracy: 0.001)
    }

    func testAGoalFromBeforeTheLinkKeepsItsMoney() {
        // Its deposits predate the goal id and can never be found again, so the first pass
        // banks the total instead of wiping the goal to zero.
        let legacy = SavingsGoal(name: "ישן", targetAmount: 5000, savedAmount: 1800)
        SavingsGoalService.reconcile(goals: [legacy], transactions: [])
        XCTAssertEqual(legacy.savedAmount, 1800, accuracy: 0.001)
        XCTAssertTrue(legacy.baselineCaptured)
        XCTAssertEqual(legacy.unlinkedBaseline, 1800, accuracy: 0.001)
    }

    func testALegacyGoalStillGrowsWithNewLinkedDeposits() {
        let legacy = SavingsGoal(name: "ישן", targetAmount: 5000, savedAmount: 1800)
        SavingsGoalService.reconcile(goals: [legacy], transactions: [])
        let fresh = deposit(700, to: legacy)
        legacy.savedAmount += 700
        SavingsGoalService.reconcile(goals: [legacy], transactions: [fresh])
        XCTAssertEqual(legacy.savedAmount, 2500, accuracy: 0.001)
    }

    func testReconcilingTwiceDoesNotDoubleCount() {
        let goal = SavingsGoal(name: "יעד", targetAmount: 2000)
        let tx = deposit(300, to: goal)
        SavingsGoalService.reconcile(goals: [goal], transactions: [tx])
        let once = goal.savedAmount
        SavingsGoalService.reconcile(goals: [goal], transactions: [tx])
        XCTAssertEqual(goal.savedAmount, once, accuracy: 0.001)
    }

    func testDepositsForOtherGoalsAreIgnored() {
        let mine = SavingsGoal(name: "שלי", targetAmount: 1000)
        let other = SavingsGoal(name: "אחר", targetAmount: 1000)
        mine.baselineCaptured = true
        let hers = deposit(400, to: other)
        SavingsGoalService.reconcile(goals: [mine], transactions: [hers])
        XCTAssertEqual(mine.savedAmount, 0, accuracy: 0.001)
    }

    func testReconcileReportsWhetherAnythingMoved() {
        let goal = SavingsGoal(name: "יעד", targetAmount: 1000)
        goal.baselineCaptured = true
        let tx = deposit(100, to: goal)
        XCTAssertTrue(SavingsGoalService.reconcile(goals: [goal], transactions: [tx]))
        XCTAssertFalse(SavingsGoalService.reconcile(goals: [goal], transactions: [tx]))
    }
}
