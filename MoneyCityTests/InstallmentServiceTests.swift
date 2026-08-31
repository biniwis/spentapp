import XCTest
@testable import MoneyCity

/// Splitting a purchase across months has two silent failure modes: the parts not adding
/// back up to the total, and a charge landing in the wrong month.
final class InstallmentServiceTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: - The split must be exact

    func testEvenSplit() {
        XCTAssertEqual(InstallmentService.paymentAmounts(total: 3000, count: 6), Array(repeating: 500.0, count: 6))
    }

    func testRemainderGoesToTheFirstPaymentAndTheTotalIsPreserved() {
        let parts = InstallmentService.paymentAmounts(total: 100, count: 3)
        XCTAssertEqual(parts, [33.34, 33.33, 33.33])
        XCTAssertEqual(parts.reduce(0, +), 100, accuracy: 0.0001)
    }

    func testAwkwardTotalsStillSumBackExactly() {
        for (total, count) in [(999.99, 7), (2500.0, 12), (49.90, 2), (10000.0, 36), (0.05, 3), (1.0, 3)] {
            let parts = InstallmentService.paymentAmounts(total: total, count: count)
            XCTAssertEqual(parts.count, count)
            XCTAssertEqual(parts.reduce(0, +), total, accuracy: 0.0001, "\(total) over \(count) payments")
        }
    }

    func testInvalidInputProducesNoPayments() {
        XCTAssertTrue(InstallmentService.paymentAmounts(total: 0, count: 6).isEmpty)
        XCTAssertTrue(InstallmentService.paymentAmounts(total: 100, count: 0).isEmpty)
        XCTAssertTrue(InstallmentService.paymentAmounts(total: -100, count: 3).isEmpty)
    }

    // MARK: - Dates

    func testChargeDayClampsIntoShortMonths() {
        let dates = InstallmentService.chargeDates(firstCharge: date(2026, 1, 31), count: 4, calendar: cal)
        XCTAssertEqual(dates.map { cal.component(.day, from: $0) }, [31, 28, 31, 30])
    }

    func testChargesCrossIntoTheNextYear() {
        let dates = InstallmentService.chargeDates(firstCharge: date(2026, 11, 15), count: 4, calendar: cal)
        let last = dates.last!
        XCTAssertEqual(cal.component(.year, from: last), 2027)
        XCTAssertEqual(cal.component(.month, from: last), 2)
    }

    // MARK: - Transactions

    func testPlanProducesOneTransactionPerPaymentThatSumsToTheTotal() {
        let plan = InstallmentPlan(
            merchant: "KSP מחשב נייד",
            totalAmount: 6000,
            numberOfPayments: 6,
            firstChargeDate: date(2026, 3, 10),
            category: .shopping
        )
        let txs = InstallmentService.makeTransactions(for: plan, calendar: cal)
        XCTAssertEqual(txs.count, 6)
        XCTAssertEqual(txs.reduce(0) { $0 + $1.amount }, 6000, accuracy: 0.0001)
        XCTAssertTrue(txs.allSatisfy { $0.category == .shopping })
        XCTAssertTrue(txs.allSatisfy { $0.isConfirmed })
        // Each charge is dated when it will actually hit, not all on purchase day.
        XCTAssertEqual(cal.component(.month, from: txs[0].timestamp), 3)
        XCTAssertEqual(cal.component(.month, from: txs[5].timestamp), 8)
    }

    // MARK: - Progress

    func testProgressCountsOnlyChargesThatHaveHappened() {
        let plan = InstallmentPlan(
            merchant: "ריהוט",
            totalAmount: 6000,
            numberOfPayments: 6,
            firstChargeDate: date(2026, 1, 10),
            category: .housing
        )
        // Mid-March: January, February and March have been charged.
        let progress = InstallmentService.progress(for: plan, asOf: date(2026, 3, 15), calendar: cal)
        XCTAssertEqual(progress.paid, 3)
        XCTAssertEqual(progress.remainingPayments, 3)
        XCTAssertEqual(progress.paidAmount, 3000, accuracy: 0.0001)
        XCTAssertEqual(progress.remainingAmount, 3000, accuracy: 0.0001)
        XCTAssertFalse(progress.isComplete)
    }

    func testAFinishedPlanOwesNothing() {
        let plan = InstallmentPlan(
            merchant: "ריהוט",
            totalAmount: 6000,
            numberOfPayments: 6,
            firstChargeDate: date(2026, 1, 10),
            category: .housing
        )
        let progress = InstallmentService.progress(for: plan, asOf: date(2027, 1, 1), calendar: cal)
        XCTAssertTrue(progress.isComplete)
        XCTAssertEqual(progress.remainingAmount, 0, accuracy: 0.0001)
    }

    func testOutstandingSumsAcrossPlans() {
        let a = InstallmentPlan(merchant: "A", totalAmount: 6000, numberOfPayments: 6,
                                firstChargeDate: date(2026, 1, 10), category: .shopping)
        let b = InstallmentPlan(merchant: "B", totalAmount: 1200, numberOfPayments: 4,
                                firstChargeDate: date(2026, 2, 10), category: .shopping)
        // Mid-March: A has paid 3 of 6 (₪3,000 left), B has paid 2 of 4 (₪600 left).
        let owed = InstallmentService.totalOutstanding(plans: [a, b], asOf: date(2026, 3, 15), calendar: cal)
        XCTAssertEqual(owed, 3600, accuracy: 0.0001)
    }
}
