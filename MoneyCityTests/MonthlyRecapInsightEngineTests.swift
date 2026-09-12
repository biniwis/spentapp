import XCTest
import SwiftData
@testable import MoneyCity

final class MonthlyRecapInsightEngineTests: XCTestCase {

    private func date(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0, second: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.second = second
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func tx(_ amount: Double, _ merchant: String, _ category: SpendingCategory,
                    day: Int, month: Int = 8, year: Int = 2026) -> Transaction {
        Transaction(amount: amount, merchant: merchant, category: category,
                    timestamp: date(year: year, month: month, day: day))
    }

    // MARK: - Determinism

    func testDeterminismSameInputAndReversedOrder() {
        let all = [
            tx(120, "Shufersal", .food, day: 2),
            tx(45, "Wolt", .food, day: 5),
            tx(35, "Falafel", .food, day: 10),
            tx(18, "Aroma", .food, day: 3),
            tx(18, "Aroma", .food, day: 7),
            tx(18, "Aroma", .food, day: 12),
            tx(18, "Aroma", .food, day: 15),
            tx(150, "Zara", .shopping, day: 8),
            tx(3200, "Rent Landlord", .housing, day: 1),
            tx(80, "Super Yuda", .food, day: 14),
            tx(60, "Pharm", .health, day: 9),
            tx(60, "Pharm", .health, day: 16),
        ]
        let month = date(year: 2026, month: 8, day: 1)

        let first = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        let second = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        XCTAssertEqual(first, second)

        let reversed = RecapInsightEngine.generateCandidates(for: month, allTransactions: all.reversed())
        XCTAssertEqual(first.map { $0.id }, reversed.map { $0.id })
    }

    // MARK: - Generators

    func testSmallPurchasesAccumulation() {
        let all = (1...20).map { i -> Transaction in
            let merchants = ["Cafe A", "Bakery", "Bus", "Market", "News", "Yoga", "Parking", "Shoes", "Gift", "Snack"]
            return tx(Double(12 + (i * 7) % 25), merchants[i % merchants.count],
                      [.food, .transport, .shopping][i % 3], day: 1 + (i % 27))
        }
        let month = date(year: 2026, month: 8, day: 1)

        let candidates = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        XCTAssertTrue(candidates.contains { $0.kind == .smallPurchasesAccumulation })
    }

    func testRepeatedMerchant() {
        var all: [Transaction] = []
        for i in 0..<8 {
            all.append(tx(55, "SuperTech", .shopping, day: 2 + i * 3))
        }
        all.append(tx(120, "Shufersal", .food, day: 5))
        all.append(tx(90, "Shufersal", .food, day: 15))
        all.append(tx(40, "Falafel", .food, day: 20))
        let month = date(year: 2026, month: 8, day: 1)

        let candidates = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        XCTAssertTrue(candidates.contains { $0.kind == .repeatedMerchant && $0.merchant == "SuperTech" })
    }

    func testDeliveryHabit() {
        var all: [Transaction] = []
        for i in 0..<10 {
            all.append(tx(48, "Wolt", .food, day: 2 + i * 2))
        }
        all.append(tx(150, "Shufersal", .food, day: 6))
        all.append(tx(60, "Pharm", .health, day: 10))
        all.append(tx(60, "Pharm", .health, day: 17))
        all.append(tx(60, "Pharm", .health, day: 24))
        let month = date(year: 2026, month: 8, day: 1)

        let candidates = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        XCTAssertTrue(candidates.contains { $0.kind == .deliveryHabit })
    }

    func testSparseMonthProducesNoCandidates() {
        // Only two transactions, both on a Tuesday, in a month with no previous data.
        let all = [
            tx(40, "Falafel", .food, day: 3, month: 1),
            tx(25, "Bus", .transport, day: 17, month: 1),
        ]
        let month = date(year: 2026, month: 1, day: 1)
        let now = date(year: 2026, month: 1, day: 31)

        let candidates = RecapInsightEngine.generateCandidates(for: month, allTransactions: all, now: now)
        XCTAssertTrue(candidates.isEmpty)
    }

    func testCategoryChangeOnlyForCompletedMonthWithPreviousData() {
        let month = date(year: 2026, month: 8, day: 1)
        let now = date(year: 2026, month: 9, day: 15)

        // No previous month data → even a complete month must produce no category story.
        let noHistory = [
            tx(3200, "Rent Landlord", .housing, day: 1),
            tx(700, "Shufersal", .food, day: 5),
        ]
        let withoutHistory = RecapInsightEngine.generateCandidates(for: month, allTransactions: noHistory, now: now)
        XCTAssertFalse(withoutHistory.contains { $0.kind == .categoryChange })

        // July: food is small, shopping large. August: food spikes, shopping collapses.
        let july: [Transaction] = [
            tx(100, "Shufersal", .food, day: 5, month: 7),
            tx(100, "Falafel", .food, day: 12, month: 7),
            tx(100, "Wolt", .food, day: 20, month: 7),
            tx(200, "Zara", .shopping, day: 8, month: 7),
            tx(200, "IKEA", .shopping, day: 14, month: 7),
            tx(200, "H&M", .shopping, day: 21, month: 7),
            tx(200, "Super Pharm", .shopping, day: 27, month: 7),
        ]
        let august: [Transaction] = [
            tx(3200, "Rent Landlord", .housing, day: 1),
            tx(1200, "Restaurant", .food, day: 5),
            tx(50, "Zara", .shopping, day: 10),
            tx(50, "H&M", .shopping, day: 12),
        ]
        let withHistory = RecapInsightEngine.generateCandidates(for: month, allTransactions: july + august, now: now)

        let changes = withHistory.filter { $0.kind == .categoryChange }
        XCTAssertEqual(changes.count, 2)
        XCTAssertEqual(changes[0].category, .food)
        XCTAssertTrue(changes[0].direction! > 0)
        XCTAssertEqual(changes[1].category, .shopping)
        XCTAssertTrue(changes[1].direction! < 0)
    }

    func testOutlierPurchase() {
        let all = [
            tx(20, "Falafel", .food, day: 2),
            tx(25, "Shufersal", .food, day: 6),
            tx(30, "Aroma", .food, day: 10),
            tx(22, "Market", .food, day: 14),
            tx(300, "Fine Dining", .food, day: 18),
            tx(60, "Pharm", .health, day: 9),
        ]
        let month = date(year: 2026, month: 8, day: 1)

        let candidates = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        let outlier = candidates.first { $0.kind == .outlierPurchase }
        XCTAssertNotNil(outlier)
        XCTAssertEqual(outlier?.totalAmount, 300)
    }

    // MARK: - Overlap resolution (evidence-based, pre-scoring)

    func testOverlapRemovesMerchantSubsumedByCategoryPattern() {
        let all = [
            tx(18, "Aroma", .food, day: 3),
            tx(18, "Aroma", .food, day: 7),
            tx(18, "Aroma", .food, day: 12),
            tx(18, "Aroma", .food, day: 15),
            tx(45, "Wolt", .food, day: 5),
            tx(35, "Falafel", .food, day: 10),
            tx(120, "Shufersal", .food, day: 2),
            tx(80, "Super Yuda", .food, day: 14),
            tx(150, "Zara", .shopping, day: 8),
            tx(60, "Pharm", .health, day: 9),
            tx(60, "Pharm", .health, day: 16),
            tx(3200, "Rent Landlord", .housing, day: 1),
        ]
        let month = date(year: 2026, month: 8, day: 1)

        let kept = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        // The single-outlier story and the category-wide food pattern coexist...
        XCTAssertNotNil(kept.first { $0.kind == .outlierPurchase })
        XCTAssertNotNil(kept.first { $0.kind == .repeatedCategory })
        // ...but the Aroma merchant story is the same underlying Aroma transactions as the
        // food pattern, so only one of the two may survive.
        XCTAssertFalse(kept.contains { $0.kind == .repeatedMerchant && $0.merchant == "Aroma" })

        let report = RecapInsightEngine.debugReport(for: month, allTransactions: all)
        XCTAssertTrue(report.contains("rejected: overlaps 100% with repeatedCategory:food"))
        XCTAssertTrue(report.contains("scores:"))
    }

    func testOverlapRemovesWoltMerchantVsDeliveryHabit() {
        var all: [Transaction] = []
        for i in 0..<10 { all.append(tx(48, "Wolt", .food, day: 2 + i * 2)) }
        all.append(tx(150, "Shufersal", .food, day: 6))
        all.append(tx(60, "Pharm", .health, day: 10))
        let month = date(year: 2026, month: 8, day: 1)

        let kept = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        let survival = kept.compactMap { $0.merchant }
        XCTAssertTrue(kept.contains { $0.kind == .deliveryHabit })
        XCTAssertFalse(kept.contains { $0.kind == .repeatedMerchant && $0.merchant?.lowercased().contains("wolt") == true })

        let report = RecapInsightEngine.debugReport(for: month, allTransactions: all)
        XCTAssertTrue(report.contains("rejected: overlaps 100% with deliveryHabit"))
    }

    func testDistinctMerchantStoriesCoexist() {
        // Two different merchants, same category, no shared transactions: both stay.
        var all: [Transaction] = []
        for i in 0..<5 { all.append(tx(50, "Martha Market", .shopping, day: 1 + i * 5)) }
        for i in 0..<5 { all.append(tx(70, "Blake Store", .shopping, day: 3 + i * 5)) }
        all.append(tx(120, "Shufersal", .food, day: 9))
        let month = date(year: 2026, month: 8, day: 1)

        let kept = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        let merchants = kept.compactMap { $0.merchant }
        XCTAssertTrue(merchants.contains("Martha Market"))
        XCTAssertTrue(merchants.contains("Blake Store"))
    }

    // MARK: - Scoring (Phase 4)

    func testScoringDeterministicAndWithinRange() {
        let all = [
            tx(120, "Shufersal", .food, day: 2),
            tx(45, "Wolt", .food, day: 5),
            tx(35, "Falafel", .food, day: 10),
            tx(18, "Aroma", .food, day: 3),
            tx(18, "Aroma", .food, day: 7),
            tx(18, "Aroma", .food, day: 12),
            tx(18, "Aroma", .food, day: 15),
            tx(150, "Zara", .shopping, day: 8),
            tx(3200, "Rent Landlord", .housing, day: 1),
            tx(80, "Super Yuda", .food, day: 14),
            tx(60, "Pharm", .health, day: 9),
            tx(60, "Pharm", .health, day: 16),
        ]
        let month = date(year: 2026, month: 8, day: 1)

        let first = RecapInsightEngine.generateCandidates(for: month, allTransactions: all)
        let second = RecapInsightEngine.generateCandidates(for: month, allTransactions: all.reversed())
        XCTAssertEqual(first.map(\.id), second.map(\.id))

        for candidate in first {
            let s = candidate.scores
            XCTAssertTrue((0...1).contains(s.surprise))
            XCTAssertTrue((0...1).contains(s.relevance))
            XCTAssertTrue((0...1).contains(s.contrast))
            XCTAssertTrue((0...1).contains(s.confidence))
            XCTAssertTrue((0...1).contains(s.total))
            XCTAssertEqual(s.novelty, 0)
        }

        let outlier = first.first { $0.kind == .outlierPurchase }?.scores.total ?? 0
        let pattern = first.first { $0.kind == .repeatedCategory }?.scores.total ?? 0
        XCTAssertGreaterThan(outlier, 0)
        XCTAssertGreaterThan(pattern, 0)
    }

    // MARK: - Phase 4 review report on mock months

    func testPhase3DebugReport() {
        let month = date(year: 2026, month: 8, day: 1)

        let normal: [Transaction] = [
            tx(120, "Shufersal", .food, day: 2),
            tx(45, "Wolt", .food, day: 5),
            tx(35, "Falafel", .food, day: 10),
            tx(18, "Aroma", .food, day: 3),
            tx(18, "Aroma", .food, day: 7),
            tx(18, "Aroma", .food, day: 12),
            tx(18, "Aroma", .food, day: 15),
            tx(150, "Zara", .shopping, day: 8),
            tx(3200, "Rent Landlord", .housing, day: 1),
            tx(80, "Super Yuda", .food, day: 14),
            tx(60, "Pharm", .health, day: 9),
            tx(60, "Pharm", .health, day: 16),
        ]
        let smallPurchases = (1...20).map { i -> Transaction in
            let merchants = ["Cafe A", "Bakery", "Bus", "Market", "News", "Yoga", "Parking", "Shoes", "Gift", "Snack"]
            return tx(Double(12 + (i * 7) % 25), merchants[i % merchants.count],
                      [.food, .transport, .shopping][i % 3], day: 1 + (i % 27))
        }
        var delivery: [Transaction] = []
        for i in 0..<10 { delivery.append(tx(48, "Wolt", .food, day: 2 + i * 2)) }
        delivery.append(contentsOf: [tx(150, "Shufersal", .food, day: 6), tx(60, "Pharm", .health, day: 10)])

        let july: [Transaction] = [
            tx(100, "Shufersal", .food, day: 5, month: 7),
            tx(100, "Falafel", .food, day: 12, month: 7),
            tx(100, "Wolt", .food, day: 20, month: 7),
            tx(200, "Zara", .shopping, day: 8, month: 7),
            tx(200, "IKEA", .shopping, day: 14, month: 7),
            tx(200, "H&M", .shopping, day: 21, month: 7),
            tx(200, "Super Pharm", .shopping, day: 27, month: 7),
        ]
        let categoryShift: [Transaction] = july + [
            tx(3200, "Rent Landlord", .housing, day: 1),
            tx(1200, "Restaurant", .food, day: 5),
            tx(50, "Zara", .shopping, day: 10),
            tx(50, "H&M", .shopping, day: 12),
        ]

        let reports = [
            ("NORMAL MONTH", RecapInsightEngine.debugReport(for: month, allTransactions: normal)),
            ("SMALL PURCHASES MONTH", RecapInsightEngine.debugReport(for: month, allTransactions: smallPurchases)),
            ("DELIVERY-HEAVY MONTH", RecapInsightEngine.debugReport(for: month, allTransactions: delivery)),
            ("CATEGORY-SHIFT MONTH", RecapInsightEngine.debugReport(for: month, allTransactions: categoryShift, now: date(year: 2026, month: 9, day: 15))),
        ]

        for (label, report) in reports {
            print("\n===== \(label) =====")
            print(report)
            XCTAssertFalse(report.isEmpty)
        }
    }
}