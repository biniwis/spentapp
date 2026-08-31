import XCTest
@testable import MoneyCity

/// Budgets are the numbers the user makes decisions on, so the arithmetic has to be exact
/// and the legacy category aliases must never split one category into two rows.
final class BudgetServiceTests: XCTestCase {

    private func tx(_ amount: Double, _ category: SpendingCategory, merchant: String = "x") -> Transaction {
        Transaction(amount: amount, merchant: merchant, category: category)
    }

    // MARK: - Spending

    func testLegacyAliasesCollapseOntoFood() {
        let spend = BudgetService.spentByCategory([
            tx(100, .food),
            tx(250, .groceries),
            tx(30, .coffee)
        ])
        // One "אוכל" row, not three.
        XCTAssertEqual(spend.count, 1)
        XCTAssertEqual(spend[.food], 380)
    }

    func testSavingsTransfersAreNotSpending() {
        let rows = [tx(500, .food), tx(1800, .savings)]
        XCTAssertEqual(BudgetService.totalSpent(rows), 500)
        XCTAssertEqual(BudgetService.totalSavedToSavings(rows), 1800)
        XCTAssertNil(BudgetService.spentByCategory(rows)[.savings])
    }

    // MARK: - Usage and status

    func testStatusThresholds() {
        XCTAssertEqual(BudgetUsage(category: .food, limit: 1000, spent: 500).status, .under)
        XCTAssertEqual(BudgetUsage(category: .food, limit: 1000, spent: 800).status, .approaching)
        XCTAssertEqual(BudgetUsage(category: .food, limit: 1000, spent: 1000).status, .approaching)
        XCTAssertEqual(BudgetUsage(category: .food, limit: 1000, spent: 1001).status, .over)
        // No ceiling means no verdict — not "you are fine".
        XCTAssertEqual(BudgetUsage(category: .food, limit: 0, spent: 500).status, .noBudget)
    }

    func testRemainderNeverGoesNegativeAndOverspendIsReportedSeparately() {
        let usage = BudgetUsage(category: .food, limit: 1000, spent: 1250)
        XCTAssertEqual(usage.remaining, 0)
        XCTAssertEqual(usage.overspend, 250)
        XCTAssertEqual(usage.fraction, 1.0)
    }

    func testFractionIsSafeWithoutALimit() {
        XCTAssertEqual(BudgetUsage(category: .food, limit: 0, spent: 500).fraction, 0)
    }

    func testUsagesPutOverspentCategoriesFirst() {
        let budgets = [
            CategoryBudget(category: .food, monthlyLimit: 1000),
            CategoryBudget(category: .transport, monthlyLimit: 500),
            CategoryBudget(category: .shopping, monthlyLimit: 800)
        ]
        let rows = [
            tx(300, .food),        // 30%
            tx(600, .transport),   // over
            tx(700, .shopping)     // 87.5%, approaching
        ]
        let usages = BudgetService.usages(budgets: budgets, transactions: rows)
        XCTAssertEqual(usages.first?.category, .transport)
        XCTAssertEqual(usages.first?.status, .over)
        XCTAssertEqual(usages.last?.category, .food)
    }

    func testDuplicateBudgetsForOneCategoryCollapseToTheLargerCeiling() {
        // Legacy data could hold a `groceries` budget alongside a `food` one.
        let budgets = [
            CategoryBudget(category: .food, monthlyLimit: 900),
            CategoryBudget(category: .groceries, monthlyLimit: 1200)
        ]
        let usages = BudgetService.usages(budgets: budgets, transactions: [tx(100, .food)])
        XCTAssertEqual(usages.count, 1)
        XCTAssertEqual(usages.first?.limit, 1200)
    }

    func testNeedingAttentionPicksOnlyTheWarningAndOverRows() {
        let usages = [
            BudgetUsage(category: .food, limit: 1000, spent: 100),
            BudgetUsage(category: .transport, limit: 500, spent: 450),
            BudgetUsage(category: .shopping, limit: 300, spent: 400)
        ]
        let flagged = BudgetService.needingAttention(usages).map(\.category)
        XCTAssertEqual(Set(flagged), Set([.transport, .shopping]))
    }

    // MARK: - Income and cash flow

    func testOnlyActiveIncomeSourcesCount() {
        let sources = [
            IncomeSource(name: "משכורת", amount: 12000),
            IncomeSource(name: "פרילנס", amount: 3000, isActive: false)
        ]
        XCTAssertEqual(BudgetService.expectedMonthlyIncome(sources), 12000)
    }

    func testLeftoverSubtractsSavingsTransfersTooSoItIsNotDoubleCounted() {
        let flow = BudgetService.cashFlow(
            income: 10000,
            transactions: [tx(5590, .food), tx(1800, .savings)]
        )
        XCTAssertEqual(flow.spent, 5590)
        XCTAssertEqual(flow.savedToSavings, 1800)
        XCTAssertEqual(flow.leftover, 2610)
    }

    func testLeftoverNeverGoesNegative() {
        let flow = BudgetService.cashFlow(income: 1000, transactions: [tx(4000, .housing)])
        XCTAssertEqual(flow.leftover, 0)
    }

    // MARK: - Forecast

    func testForecastRefusesToExtrapolateFromTooFewDays() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        let thirdOfMonth = cal.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 12))!
        // Three days of data times thirty is a number that would only mislead.
        XCTAssertNil(BudgetService.projectedMonthEnd(spentSoFar: 300, now: thirdOfMonth, calendar: cal))
    }

    func testForecastScalesThePaceToTheWholeMonth() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        // 10 days into a 31-day month, ₪1,000 spent.
        let tenth = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let projected = BudgetService.projectedMonthEnd(spentSoFar: 1000, now: tenth, calendar: cal)
        XCTAssertNotNil(projected)
        XCTAssertEqual(projected!, 3100, accuracy: 0.01)
    }

    func testForecastIsNilWithNoSpending() {
        XCTAssertNil(BudgetService.projectedMonthEnd(spentSoFar: 0))
    }
}
