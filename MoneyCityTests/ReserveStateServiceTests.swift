import XCTest
@testable import MoneyCity

final class ReserveStateServiceTests: XCTestCase {

    func testNoBudgetReturnsNoBudgetState() {
        let snapshot = ReserveStateService.computeSnapshot(
            monthlyBudget: 0,
            monthlySpent: 1200,
            monthProgressRatio: 0.40
        )
        XCTAssertEqual(snapshot.state, .noBudget)
        XCTAssertFalse(snapshot.hasBudget)
        XCTAssertEqual(snapshot.budgetUsageRatio, 0)
        XCTAssertEqual(snapshot.remainingBudget, 0)
        XCTAssertEqual(snapshot.state.visualHealthLevel, 0.70)
    }

    func testCalmStateWhenSpendingRunsLow() {
        // 40% of the month elapsed, only 20% of budget spent (2,000 / 10,000)
        let snapshot = ReserveStateService.computeSnapshot(
            monthlyBudget: 10000,
            monthlySpent: 2000,
            monthProgressRatio: 0.40
        )
        XCTAssertEqual(snapshot.state, .calm)
        XCTAssertEqual(snapshot.budgetUsageRatio, 0.20)
        XCTAssertEqual(snapshot.remainingBudget, 8000)
        XCTAssertEqual(snapshot.state.visualHealthLevel, 1.00)
    }

    func testBalancedStateWhenSpendingMatchesProgress() {
        // 40% of the month elapsed, 38% of budget spent (3,800 / 10,000)
        let snapshot = ReserveStateService.computeSnapshot(
            monthlyBudget: 10000,
            monthlySpent: 3800,
            monthProgressRatio: 0.40
        )
        XCTAssertEqual(snapshot.state, .balanced)
        XCTAssertEqual(snapshot.budgetUsageRatio, 0.38)
        XCTAssertEqual(snapshot.remainingBudget, 6200)
        XCTAssertEqual(snapshot.state.visualHealthLevel, 0.78)
    }

    func testActiveStateWhenSpendingSlightlyAhead() {
        // 40% of the month elapsed, 52% of budget spent (5,200 / 10,000)
        let snapshot = ReserveStateService.computeSnapshot(
            monthlyBudget: 10000,
            monthlySpent: 5200,
            monthProgressRatio: 0.40
        )
        XCTAssertEqual(snapshot.state, .active)
        XCTAssertEqual(snapshot.budgetUsageRatio, 0.52)
        XCTAssertEqual(snapshot.remainingBudget, 4800)
        XCTAssertEqual(snapshot.state.visualHealthLevel, 0.50)
    }

    func testBusyStateWhenSpendingAccelerated() {
        // 40% of the month elapsed, 75% of budget spent (7,500 / 10,000)
        let snapshot = ReserveStateService.computeSnapshot(
            monthlyBudget: 10000,
            monthlySpent: 7500,
            monthProgressRatio: 0.40
        )
        XCTAssertEqual(snapshot.state, .busy)
        XCTAssertEqual(snapshot.budgetUsageRatio, 0.75)
        XCTAssertEqual(snapshot.remainingBudget, 2500)
        XCTAssertEqual(snapshot.state.visualHealthLevel, 0.22)
    }

    func testEarlyMonthGracePeriodAvoidsShock() {
        // Day 1 (progress <= 0.05), a modest spend of 500 on 10,000 budget (5%) stays balanced
        let snapshot = ReserveStateService.computeSnapshot(
            monthlyBudget: 10000,
            monthlySpent: 500,
            monthProgressRatio: 0.03
        )
        XCTAssertEqual(snapshot.state, .balanced)
    }
}
