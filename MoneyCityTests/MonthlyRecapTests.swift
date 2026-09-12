import XCTest
import SwiftUI
import SwiftData
@testable import MoneyCity

final class MonthlyRecapTests: XCTestCase {
    
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
    
    // MARK: - 1. Baseline Deterministic Recap
    func testMonthlyRecapExactCalculations() {
        let augTxs = [
            Transaction(amount: 120, merchant: "Shufersal", category: .food, timestamp: date(year: 2026, month: 8, day: 2)),
            Transaction(amount: 45, merchant: "Wolt", category: .food, timestamp: date(year: 2026, month: 8, day: 5)),
            Transaction(amount: 35, merchant: "Falafel", category: .food, timestamp: date(year: 2026, month: 8, day: 10)),
            Transaction(amount: 80, merchant: "Super Yuda", category: .food, timestamp: date(year: 2026, month: 8, day: 14)),
            
            Transaction(amount: 3200, merchant: "Rent Landlord", category: .housing, timestamp: date(year: 2026, month: 8, day: 1)),
            
            Transaction(amount: 150, merchant: "Zara", category: .shopping, timestamp: date(year: 2026, month: 8, day: 8)),
            Transaction(amount: 1850, merchant: "IKEA", category: .shopping, timestamp: date(year: 2026, month: 8, day: 14)),
            
            Transaction(amount: 18, merchant: "Aroma", category: .food, timestamp: date(year: 2026, month: 8, day: 3)),
            Transaction(amount: 18, merchant: "Aroma", category: .food, timestamp: date(year: 2026, month: 8, day: 7)),
            Transaction(amount: 18, merchant: "Aroma", category: .food, timestamp: date(year: 2026, month: 8, day: 12))
        ]
        
        let julTxs = [
            Transaction(amount: 6000, merchant: "July Total", category: .housing, timestamp: date(year: 2026, month: 7, day: 15))
        ]
        
        let all = augTxs + julTxs
        let targetMonth = date(year: 2026, month: 8, day: 1)
        
        let recap = MonthlyRecapService.generateRecap(for: targetMonth, allTransactions: all, monthlyBudget: 8000)
        
        XCTAssertEqual(recap.totalSpent, 5534)
        XCTAssertEqual(recap.transactionCount, 10)
        XCTAssertEqual(recap.remainingBudget, 8000 - 5534)
        
        XCTAssertNotNil(recap.biggestDistrict)
        XCTAssertEqual(recap.biggestDistrict?.category, .housing)
        XCTAssertEqual(recap.biggestDistrict?.amount, 3200)
        
        XCTAssertNotNil(recap.tallestBuilding)
        XCTAssertEqual(recap.tallestBuilding?.merchantName, "IKEA")
        XCTAssertEqual(recap.tallestBuilding?.amount, 1850)
        
        XCTAssertNotNil(recap.busiestDistrict)
        XCTAssertEqual(recap.busiestDistrict?.category, .food)
        XCTAssertEqual(recap.busiestDistrict?.transactionCount, 7)
        
        XCTAssertNotNil(recap.mostRepeatedStop)
        XCTAssertEqual(recap.mostRepeatedStop?.merchantName, "Aroma")
        XCTAssertEqual(recap.mostRepeatedStop?.visitCount, 3)
        XCTAssertEqual(recap.mostRepeatedStop?.totalAmount, 54)
        
        XCTAssertNotNil(recap.biggestSpendingDay)
        XCTAssertEqual(recap.biggestSpendingDay?.amount, 3200)
        
        XCTAssertNotNil(recap.comparisonVsPrevMonth)
        XCTAssertTrue(recap.comparisonVsPrevMonth?.isDecrease == true)
        XCTAssertEqual(recap.comparisonVsPrevMonth?.diffAmount, 466)
    }
    
    // MARK: - 2. Edge Case: Empty Month
    func testEmptyMonthYieldsQuietRecap() {
        let emptyDate = date(year: 2026, month: 5, day: 1)
        let recap = MonthlyRecapService.generateRecap(for: emptyDate, allTransactions: [], monthlyBudget: nil)
        
        XCTAssertEqual(recap.totalSpent, 0)
        XCTAssertEqual(recap.transactionCount, 0)
        XCTAssertNil(recap.remainingBudget)
        XCTAssertNil(recap.biggestDistrict)
        XCTAssertNil(recap.tallestBuilding)
        XCTAssertNil(recap.busiestDistrict)
        XCTAssertNil(recap.mostRepeatedStop)
        XCTAssertNil(recap.biggestSpendingDay)
        XCTAssertNil(recap.comparisonVsPrevMonth)
        XCTAssertEqual(recap.cityVibe.type, .quiet)
    }
    
    // MARK: - 3. Edge Case: Single Transaction Month
    func testSingleTransactionMonth() {
        let tx = Transaction(amount: 42.5, merchant: "Coffee Shop", category: .food, timestamp: date(year: 2026, month: 8, day: 10))
        let recap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: [tx])
        
        XCTAssertEqual(recap.totalSpent, 42.5)
        XCTAssertEqual(recap.transactionCount, 1)
        XCTAssertEqual(recap.biggestDistrict?.category, .food)
        XCTAssertEqual(recap.biggestDistrict?.amount, 42.5)
        XCTAssertEqual(recap.tallestBuilding?.merchantName, "Coffee Shop")
        XCTAssertEqual(recap.tallestBuilding?.amount, 42.5)
        XCTAssertEqual(recap.busiestDistrict?.transactionCount, 1)
        XCTAssertNil(recap.mostRepeatedStop)
        XCTAssertEqual(recap.biggestSpendingDay?.amount, 42.5)
    }
    
    // MARK: - 4. Edge Case: Identical Amount Transactions
    func testIdenticalAmountTransactions() {
        let tx1 = Transaction(amount: 100, merchant: "Shop A", category: .shopping, timestamp: date(year: 2026, month: 8, day: 2))
        let tx2 = Transaction(amount: 100, merchant: "Shop B", category: .food, timestamp: date(year: 2026, month: 8, day: 4))
        
        let recap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: [tx1, tx2])
        
        XCTAssertEqual(recap.totalSpent, 200)
        XCTAssertEqual(recap.tallestBuilding?.amount, 100)
        XCTAssertTrue(["Shop A", "Shop B"].contains(recap.tallestBuilding?.merchantName))
    }
    
    // MARK: - 5. Edge Case: Blank or Whitespace-Only Merchant Name
    func testBlankOrWhitespaceMerchantName() {
        let tx1 = Transaction(amount: 50, merchant: "   ", category: .transport, timestamp: date(year: 2026, month: 8, day: 2))
        let tx2 = Transaction(amount: 80, merchant: "", category: .health, timestamp: date(year: 2026, month: 8, day: 5))
        
        let recap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: [tx1, tx2])
        
        XCTAssertEqual(recap.totalSpent, 130)
        XCTAssertEqual(recap.transactionCount, 2)
        // Tallest building falls back to category name if blank
        XCTAssertNotNil(recap.tallestBuilding)
        XCTAssertFalse(recap.tallestBuilding!.merchantName.trimmingCharacters(in: .whitespaces).isEmpty)
    }
    
    // MARK: - 6. Edge Case: Zero Amount and Decimal Precision
    func testZeroAmountAndDecimals() {
        let txZero = Transaction(amount: 0.0, merchant: "Promo Gift", category: .other, timestamp: date(year: 2026, month: 8, day: 2))
        let txDec1 = Transaction(amount: 19.99, merchant: "App Store", category: .subscriptions, timestamp: date(year: 2026, month: 8, day: 3))
        let txDec2 = Transaction(amount: 5.01, merchant: "Bakery", category: .food, timestamp: date(year: 2026, month: 8, day: 4))
        
        let recap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: [txZero, txDec1, txDec2])
        
        XCTAssertEqual(recap.totalSpent, 25.0)
        XCTAssertEqual(recap.transactionCount, 2) // Zero amount skipped from spending count
    }
    
    // MARK: - 7. Edge Case: 0% Change vs Previous Month
    func testZeroPercentMonthOverMonth() {
        let julTx = Transaction(amount: 500, merchant: "Rent", category: .housing, timestamp: date(year: 2026, month: 7, day: 10))
        let augTx = Transaction(amount: 500, merchant: "Rent", category: .housing, timestamp: date(year: 2026, month: 8, day: 10))
        
        let recap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: [julTx, augTx])
        
        XCTAssertNotNil(recap.comparisonVsPrevMonth)
        XCTAssertEqual(recap.comparisonVsPrevMonth?.diffAmount, 0.0)
        XCTAssertEqual(recap.comparisonVsPrevMonth?.percentChange, 0.0)
    }
    
    // MARK: - 8. Edge Case: Midnight and Month Boundary Timestamps
    func testMidnightAndBoundaryTransactions() {
        let txStart = Transaction(amount: 100, merchant: "Midnight Tx", category: .food, timestamp: date(year: 2026, month: 8, day: 1, hour: 0, minute: 0, second: 0))
        let txEnd = Transaction(amount: 200, merchant: "End of Month Tx", category: .shopping, timestamp: date(year: 2026, month: 8, day: 31, hour: 23, minute: 59, second: 59))
        let txOutside = Transaction(amount: 300, merchant: "September Tx", category: .food, timestamp: date(year: 2026, month: 9, day: 1, hour: 0, minute: 0, second: 1))
        
        let recap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: [txStart, txEnd, txOutside])
        
        XCTAssertEqual(recap.totalSpent, 300)
        XCTAssertEqual(recap.transactionCount, 2)
    }
    
    // MARK: - 9. Category Canonicalization Collapses Aliases
    func testCategoryCanonicalization() {
        let txFood = Transaction(amount: 100, merchant: "Restaurant", category: .food, timestamp: date(year: 2026, month: 8, day: 2))
        let txGroc = Transaction(amount: 200, merchant: "Supermarket", category: .groceries, timestamp: date(year: 2026, month: 8, day: 3))
        let txCoffee = Transaction(amount: 50, merchant: "Cafe", category: .coffee, timestamp: date(year: 2026, month: 8, day: 4))
        
        let recap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: [txFood, txGroc, txCoffee])
        
        XCTAssertEqual(recap.biggestDistrict?.category, .food)
        XCTAssertEqual(recap.biggestDistrict?.amount, 350)
        XCTAssertEqual(recap.busiestDistrict?.transactionCount, 3)
    }
    
    // MARK: - 10. City Vibe Priority Engine
    func testCityVibePriorityEngine() {
        // Record High Month
        let m1 = Transaction(amount: 2000, merchant: "A", category: .housing, timestamp: date(year: 2026, month: 6, day: 1))
        let m2 = Transaction(amount: 3000, merchant: "B", category: .housing, timestamp: date(year: 2026, month: 7, day: 1))
        let m3 = Transaction(amount: 9000, merchant: "C", category: .housing, timestamp: date(year: 2026, month: 8, day: 1))
        
        let recordRecap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: [m1, m2, m3])
        XCTAssertEqual(recordRecap.cityVibe.type, .recordMetropolis)
        
        // Green Month (20%+ drop vs prev month)
        let greenAug = Transaction(amount: 1500, merchant: "A", category: .housing, timestamp: date(year: 2026, month: 8, day: 1))
        let greenRecap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: [m2, greenAug]) // 3000 -> 1500 (-50%)
        XCTAssertEqual(greenRecap.cityVibe.type, .greenMonth)
    }
    
    // MARK: - 11. "Recap Never Lies" Invariant Property Tests (Fuzz Test with 100 Transactions)
    func testRecapInvariantsNeverLie() {
        var txs: [MoneyCity.Transaction] = []
        var expectedTotal: Double = 0.0
        
        let categories: [SpendingCategory] = [.food, .housing, .transport, .shopping, .entertainment, .health, .subscriptions, .finance, .other]
        let merchants = ["Aroma", "Super Yuda", "Wolt", "Zara", "Rent", "Electric Co", "Gett", "Cinema", "Pharmacy"]
        
        for i in 1...100 {
            let day = (i % 28) + 1
            let cat = categories[i % categories.count]
            let merchant = merchants[i % merchants.count]
            let amount = Double(i * 10) + 0.50
            expectedTotal += amount
            
            txs.append(Transaction(amount: amount, merchant: merchant, category: cat, timestamp: date(year: 2026, month: 8, day: day)))
        }
        
        let recap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1), allTransactions: txs)
        
        // Invariant 1: Total spent matches exact sum of transactions
        XCTAssertEqual(recap.totalSpent, expectedTotal, accuracy: 0.001)
        XCTAssertEqual(recap.transactionCount, 100)
        
        // Invariant 2: Biggest district is less than or equal to total spend
        XCTAssertNotNil(recap.biggestDistrict)
        XCTAssertLessThanOrEqual(recap.biggestDistrict!.amount, recap.totalSpent)
        
        // Invariant 3: Tallest building is less than or equal to total spend
        XCTAssertNotNil(recap.tallestBuilding)
        XCTAssertLessThanOrEqual(recap.tallestBuilding!.amount, recap.totalSpent)
        
        // Invariant 4: Biggest day is less than or equal to total spend
        XCTAssertNotNil(recap.biggestSpendingDay)
        XCTAssertLessThanOrEqual(recap.biggestSpendingDay!.amount, recap.totalSpent)
        
        // Invariant 5: Most repeated stop count <= total transaction count
        XCTAssertNotNil(recap.mostRepeatedStop)
        XCTAssertLessThanOrEqual(recap.mostRepeatedStop!.visitCount, recap.transactionCount)
    }

    func testFixedOnlyMonthDoesNotInventStandoutPurchase() {
        let fixed = [
            Transaction(amount: 4200, merchant: "בעל הדירה", category: .housing,
                        timestamp: date(year: 2026, month: 8, day: 1), note: "הוצאה קבועה"),
            Transaction(amount: 59.9, merchant: "Netflix", category: .subscriptions,
                        timestamp: date(year: 2026, month: 8, day: 2), note: "הוצאה קבועה")
        ]
        let recap = MonthlyRecapService.generateRecap(
            for: date(year: 2026, month: 8, day: 1), allTransactions: fixed)
        XCTAssertNil(recap.tallestBuilding)
    }

    func testRepeatedMerchantNormalizesCaseAndWhitespace() {
        let txs = [
            Transaction(amount: 18, merchant: " Aroma ", category: .food, timestamp: date(year: 2026, month: 8, day: 2)),
            Transaction(amount: 22, merchant: "aroma", category: .food, timestamp: date(year: 2026, month: 8, day: 4)),
            Transaction(amount: 20, merchant: "AROMA", category: .food, timestamp: date(year: 2026, month: 8, day: 8))
        ]
        let recap = MonthlyRecapService.generateRecap(
            for: date(year: 2026, month: 8, day: 1), allTransactions: txs)
        XCTAssertEqual(recap.mostRepeatedStop?.visitCount, 3)
        XCTAssertEqual(recap.mostRepeatedStop?.totalAmount, 60)
    }

    func testPeakDayIncludesTransactionCount() {
        let txs = [
            Transaction(amount: 60, merchant: "A", category: .food, timestamp: date(year: 2026, month: 8, day: 5)),
            Transaction(amount: 50, merchant: "B", category: .shopping, timestamp: date(year: 2026, month: 8, day: 5)),
            Transaction(amount: 80, merchant: "C", category: .transport, timestamp: date(year: 2026, month: 8, day: 8))
        ]
        let recap = MonthlyRecapService.generateRecap(
            for: date(year: 2026, month: 8, day: 1), allTransactions: txs)
        XCTAssertEqual(recap.biggestSpendingDay?.amount, 110)
        XCTAssertEqual(recap.biggestSpendingDay?.transactionCount, 2)
    }

    func testCitySnapshotUsesTheRecapMonthOnly() {
        let july = Transaction(amount: 900, merchant: "Old", category: .shopping,
                               timestamp: date(year: 2026, month: 7, day: 2))
        let august = Transaction(amount: 75, merchant: "Wolt", category: .food,
                                 timestamp: date(year: 2026, month: 8, day: 2), buildingId: "food_wolt")
        let recap = MonthlyRecapService.generateRecap(
            for: date(year: 2026, month: 8, day: 1), allTransactions: [july, august])
        XCTAssertEqual(recap.city.buildingTotals["food_wolt"], 75)
        XCTAssertEqual(recap.city.categoryTotals[.shopping], 0)
        XCTAssertEqual(recap.city.venueStates.first { $0.id == "food_wolt" }?.purchaseCount, 1)
    }

    // MARK: - 12. Recap Celebration Window Tests
    func testRecapCelebrationWindow() {
        let cal = Calendar(identifier: .gregorian)

        // 1. Last day of month (August 31) -> Active for August
        let aug31 = date(year: 2026, month: 8, day: 31)
        let statusAug31 = MonthlyRecapService.checkRecapWindow(now: aug31, calendar: cal)
        XCTAssertTrue(statusAug31.isActive)
        XCTAssertTrue(statusAug31.isFinalDayOfCurrentMonth)
        XCTAssertEqual(statusAug31.monthId, "2026-08")

        // 2. Day 1 of next month (Sept 1) -> Active for August (previous month)
        let sep1 = date(year: 2026, month: 9, day: 1)
        let statusSep1 = MonthlyRecapService.checkRecapWindow(now: sep1, calendar: cal)
        XCTAssertTrue(statusSep1.isActive)
        XCTAssertFalse(statusSep1.isFinalDayOfCurrentMonth)
        XCTAssertEqual(statusSep1.monthId, "2026-08")

        // 3. Day 2 of next month (Sept 2) -> Active for August
        let sep2 = date(year: 2026, month: 9, day: 2)
        let statusSep2 = MonthlyRecapService.checkRecapWindow(now: sep2, calendar: cal)
        XCTAssertTrue(statusSep2.isActive)
        XCTAssertFalse(statusSep2.isFinalDayOfCurrentMonth)
        XCTAssertEqual(statusSep2.monthId, "2026-08")

        // 4. Day 3 of month (Sept 3) -> Inactive
        let sep3 = date(year: 2026, month: 9, day: 3)
        let statusSep3 = MonthlyRecapService.checkRecapWindow(now: sep3, calendar: cal)
        XCTAssertFalse(statusSep3.isActive)
        XCTAssertNil(statusSep3.targetMonthDate)

        // 5. Mid month (Sept 15) -> Inactive
        let sep15 = date(year: 2026, month: 9, day: 15)
        let statusSep15 = MonthlyRecapService.checkRecapWindow(now: sep15, calendar: cal)
        XCTAssertFalse(statusSep15.isActive)

        // 6. Day before last (Sept 29 in 30-day month) -> Inactive
        let sep29 = date(year: 2026, month: 9, day: 29)
        let statusSep29 = MonthlyRecapService.checkRecapWindow(now: sep29, calendar: cal)
        XCTAssertFalse(statusSep29.isActive)

        // 7. Last day in 30-day month (Sept 30) -> Active for September
        let sep30 = date(year: 2026, month: 9, day: 30)
        let statusSep30 = MonthlyRecapService.checkRecapWindow(now: sep30, calendar: cal)
        XCTAssertTrue(statusSep30.isActive)
        XCTAssertTrue(statusSep30.isFinalDayOfCurrentMonth)
        XCTAssertEqual(statusSep30.monthId, "2026-09")

        // 8. Leap year February 29 (2024-02-29) -> Active for February
        let feb29 = date(year: 2024, month: 2, day: 29)
        let statusFeb29 = MonthlyRecapService.checkRecapWindow(now: feb29, calendar: cal)
        XCTAssertTrue(statusFeb29.isActive)
        XCTAssertTrue(statusFeb29.isFinalDayOfCurrentMonth)
        XCTAssertEqual(statusFeb29.monthId, "2024-02")
    }
}

final class MonthlyRecapEditorialTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ d: Int, month: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: 12))!
    }
    private func tx(_ amount: Double, _ merchant: String, _ category: SpendingCategory = .food, _ d: Int = 1, month: Int = 8) -> MoneyCity.Transaction {
        Transaction(amount: amount, merchant: merchant, category: category, timestamp: day(d, month: month))
    }
    func testEditorialAnchorsAndSparseMonthDoNotInventStories() {
        for input in [[], [tx(20, "Coffee")]] {
            let recap = MonthlyRecapService.generateRecap(for: day(1), allTransactions: input)
            XCTAssertTrue(recap.dynamicInsights.isEmpty)
            XCTAssertEqual(RecapEditorialShot.sequence(for: recap), [.opening, .total, .activity, .district, .portrait])
        }
    }
    func testSelectsDominantMerchantAndDistinctMonthChange() {
        let data = (1...7).map { tx(20, $0.isMultiple(of: 2) ? " AROMA " : "Aroma", .food, $0) }
            + [tx(40, "Bus", .transport, 9), tx(30, "Book", .shopping, 10), tx(60, "Cinema", .entertainment, 12), tx(500, "Old", .food, 10, month: 7)]
        let result = MonthlyRecapInsightSelector.select(for: day(1), transactions: data, now: day(1, month: 9))
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(Set(result.map(\.type)), Set([.merchantRepeat, .monthChange]))
        XCTAssertEqual(result.first(where: { $0.type == .merchantRepeat })?.count, 7)
        XCTAssertEqual(Set(result.map(\.visualTheme)).count, 2)
        XCTAssertEqual(result, MonthlyRecapInsightSelector.select(for: day(1), transactions: data.reversed(), now: day(1, month: 9)))
    }
    func testNoMonthComparisonForPartialMonthOrSmallChange() {
        let current = (1...10).map { tx(10, "Shop\($0)", .food, $0) }
        let previous = [tx(200, "Old", .food, 10, month: 7)]
        let partial = MonthlyRecapInsightSelector.select(for: day(1), transactions: current + previous, now: day(15))
        XCTAssertFalse(partial.contains { $0.type == .monthChange || $0.type == .categoryChange })
        let stable = MonthlyRecapInsightSelector.select(for: day(1), transactions: current + [tx(103, "Old", .food, 10, month: 7)], now: day(1, month: 9))
        XCTAssertFalse(stable.contains { $0.type == .monthChange })
    }
    func testLargeFixedBillsAndSavingsAreNeverPurchaseStories() {
        let regular = (1...8).map { tx(20, "Cafe\($0)", .food, $0) }
        let data = regular + [tx(5000, "Landlord", .housing), tx(7000, "Savings", .savings), tx(1000, "Insurance", .finance)]
        let selected = MonthlyRecapInsightSelector.select(for: day(1), transactions: data, now: day(1, month: 9))
        XCTAssertFalse(selected.contains { $0.type == .biggestPurchase || $0.type == .merchantRepeat })
    }
    func testOneBigPurchaseIsNotRetoldAsItsDay() {
        let data = (1...12).map { tx(20, "Cafe\($0)", .food, $0) } + [tx(900, "IKEA", .shopping, 5), tx(50, "Taxi", .transport, 5)]
        let selected = MonthlyRecapInsightSelector.select(for: day(1), transactions: data, now: day(1, month: 9))
        XCTAssertTrue(selected.contains { $0.type == .biggestPurchase })
        XCTAssertFalse(selected.contains { $0.type == .biggestDay })
    }
    func testCategoryChangeDoesNotRepeatTopDistrict() {
        let data = (1...8).map { tx(100, "Meal\($0)", .food, $0) } + [tx(20, "Bus", .transport, 13), tx(800, "OldFood", .food, 10, month: 7), tx(250, "OldBus", .transport, 10, month: 7)]
        let selected = MonthlyRecapInsightSelector.select(for: day(1), transactions: data, now: day(1, month: 9))
        XCTAssertFalse(selected.contains { $0.type == .categoryChange && $0.category == .food })
        XCTAssertLessThanOrEqual(selected.filter { $0.type == .categoryChange || $0.type == .monthChange }.count, 1)
    }
    func testExactNextMonthBoundaryIsExcluded() {
        let recap = MonthlyRecapService.generateRecap(for: day(1), allTransactions: [tx(20, "Coffee"), Transaction(amount: 800, merchant: "Next", category: .food, timestamp: calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!)])
        XCTAssertEqual(recap.totalSpent, 20)
        XCTAssertEqual(recap.transactionCount, 1)
    }
}


final class MonthlyRecapPortraitTests: XCTestCase {
    @MainActor func testPortraitExportsAtShareResolutionForBothLanguages() throws {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let recap = MonthlyRecapService.generateRecap(for: date, allTransactions: [])
        for he in [true, false] {
            let content = RecapSceneFrame(shot: .portrait, recap: recap, time: 6.2, he: he, currency: "₪", export: true)
                .frame(width: 390, height: 650)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 3
            renderer.isOpaque = true
            let image = try XCTUnwrap(renderer.uiImage)
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(cgImage.width, 1170)
            XCTAssertEqual(cgImage.height, 1950)
            XCTAssertNotNil(image.pngData())
        }
    }
}

final class MonthlyRecapArchiveVisualTests: XCTestCase {
    @MainActor
    func testMonthlyRecapArchiveRendersPostcardsAndSavesVisuals() throws {
        let schema = Schema([Transaction.self, CategoryBudget.self, RecapSnapshot.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        
        let cal = Calendar(identifier: .gregorian)
        func makeDate(year: Int, month: Int, day: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }
        
        // Current month: September 2026
        context.insert(Transaction(amount: 50, merchant: "Aroma", category: .food, timestamp: makeDate(year: 2026, month: 9, day: 5)))
        context.insert(Transaction(amount: 120, merchant: "Super", category: .food, timestamp: makeDate(year: 2026, month: 9, day: 8)))
        
        // August 2026
        context.insert(Transaction(amount: 3200, merchant: "Rent", category: .housing, timestamp: makeDate(year: 2026, month: 8, day: 1)))
        context.insert(Transaction(amount: 450, merchant: "Zara", category: .shopping, timestamp: makeDate(year: 2026, month: 8, day: 14)))
        
        // July 2026
        context.insert(Transaction(amount: 2200, merchant: "Hotels", category: .entertainment, timestamp: makeDate(year: 2026, month: 7, day: 10)))
        context.insert(Transaction(amount: 600, merchant: "Dinner", category: .food, timestamp: makeDate(year: 2026, month: 7, day: 20)))
        
        // June 2026
        context.insert(Transaction(amount: 8500, merchant: "Agency", category: .finance, timestamp: makeDate(year: 2026, month: 6, day: 15)))
        
        // May 2026
        context.insert(Transaction(amount: 300, merchant: "Books", category: .shopping, timestamp: makeDate(year: 2026, month: 5, day: 12)))

        try context.save()
        
        func renderToDisk(view: some View, filename: String) {
            let hosting = UIHostingController(rootView: view)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
            window.rootViewController = hosting
            window.makeKeyAndVisible()
            hosting.view.frame = window.bounds
            
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
            hosting.view.layoutIfNeeded()
            
            let renderer = UIGraphicsImageRenderer(bounds: hosting.view.bounds)
            let image = renderer.image { ctx in
                hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
            }
            if let data = image.pngData() {
                let path = "/Users/bnymynwysmn/.gemini/antigravity/brain/0b66d33b-b50a-4abf-bf18-87bef410dacc/\(filename)"
                try? data.write(to: URL(fileURLWithPath: path))
            }
            window.isHidden = true
        }

        let l10n = LocalizationManager.shared
        
        // Render Hebrew RTL
        l10n.language = .hebrew
        let hebrewView = MonthlyRecapArchiveView()
            .environmentObject(l10n)
            .environment(\.layoutDirection, .rightToLeft)
            .modelContainer(container)
        renderToDisk(view: hebrewView, filename: "archive_hebrew.png")
        
        // Render English LTR
        l10n.language = .english
        let englishView = MonthlyRecapArchiveView()
            .environmentObject(l10n)
            .environment(\.layoutDirection, .leftToRight)
            .modelContainer(container)
        renderToDisk(view: englishView, filename: "archive_english.png")
        
        // Restore language
        l10n.language = .hebrew
    }
}

/// Phase 10 visual QA: render every shot of the seven curated presets in Hebrew and English,
/// assert the shot-count contracts (max 9, sparse exactly 5), and dump the export/share
/// portrait exactly as `share()` composes it.
final class RecapVisualQATests: XCTestCase {
    private static let outDir = "/Users/bnymynwysmn/.gemini/antigravity/brain/0b66d33b-b50a-4abf-bf18-87bef410dacc/recap_qa"

    @MainActor
    private func renderPNG(_ view: some View) -> Data? {
        let content = view.frame(width: 390, height: 844)
        let renderer = ImageRenderer(content: content)
        renderer.isOpaque = true
        return renderer.uiImage?.pngData()
    }

    @MainActor
    func testAllPresetsRenderEveryShotInBothLanguages() throws {
        beforeEachRender: do {
            try? FileManager.default.createDirectory(atPath: Self.outDir, withIntermediateDirectories: true)
        }
        for kind in RecapLabKind.allCases {
            let recap = RecapPreviewData.recap(kind: kind)
            let shots = RecapEditorialShot.sequence(for: recap)
            XCTAssertLessThanOrEqual(shots.count, 9, "\(kind.rawValue) must never exceed 9 shots")
            if kind == .minimalData {
                XCTAssertEqual(shots.count, 5, "minimalData must stay exactly 5 shots")
            }
            if case .noticed? = shots.last(where: { if case .noticed = $0 { return true }; return false }) {
                XCTAssertFalse(recap.noticedInsights.isEmpty)
            } else {
                XCTAssertTrue(recap.noticedInsights.isEmpty)
            }
            XCTAssertTrue(shots.contains { if case .portrait = $0 { return true }; return false })

            for (i, shot) in shots.enumerated() {
                for he in [true, false] {
                    let frame = RecapSceneFrame(shot: shot, recap: recap, time: max(shot.duration * 0.9, 0.2), he: he, currency: "₪")
                        .environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
                    let data = try XCTUnwrap(renderPNG(frame), "\(kind.rawValue) shot \(i) \(he ? "he" : "en")")
                    try data.write(to: URL(fileURLWithPath: "\(Self.outDir)/\(kind.rawValue)_shot\(i)_\(he ? "he" : "en").png"))
                }
            }

            // Export/share portrait exactly as MonthlyRecapSheet.share() produces it.
            let export = RecapSceneFrame(shot: .portrait, recap: recap, time: 7.9, he: true, currency: "₪", export: true)
                .frame(width: 390, height: 844)
            let exportData = try XCTUnwrap(renderPNG(export), "\(kind.rawValue) export")
            try exportData.write(to: URL(fileURLWithPath: "\(Self.outDir)/\(kind.rawValue)_export.png"))
            if kind == .richNoticed {
                XCTAssertTrue(
                    recap.noticedInsights.count >= 2 && recap.noticedInsights.count <= 4,
                    "richNoticed must carry 2–4 noticed rows, got \(recap.noticedInsights.count)"
                )
                XCTAssertTrue(shots.contains { if case .noticed = $0 { return true }; return false })
            }
        }
    }

    /// The rich preset must produce a REAL noticed shot through the untouched pipeline —
    /// preset transactions → `RecapInsightEngine` → `RecapInsightCurator` → `.noticed` rows.
    /// No injection, no threshold changes; the curator's own `debugCuratorReport` is printed
    /// so the selected families and scores are visible in the test log.
    @MainActor
    func testRichNoticedPresetProducesNaturalNoticedStoryThroughRealPipeline() {
        let transactions = RecapPreviewData.transactions(kind: .richNoticed)
        let recap = RecapPreviewData.recap(kind: .richNoticed)
        let month = recap.date

        let curated = RecapInsightCurator.curate(for: month, allTransactions: transactions)
        XCTAssertGreaterThanOrEqual(curated.noticed.count, 2, "engine+curator must surface ≥2 noticed rows")
        XCTAssertLessThanOrEqual(curated.noticed.count, RecapInsightCurator.maxNoticedRows)
        XCTAssertEqual(
            recap.noticedInsights.count, curated.noticed.count,
            "recap must wire the curator's noticed rows without injection"
        )
        let shots = RecapEditorialShot.sequence(for: recap)
        XCTAssertTrue(shots.contains { if case .noticed = $0 { return true }; return false })
        XCTAssertGreaterThanOrEqual(shots.count, 5)
        XCTAssertLessThanOrEqual(shots.count, 9)

        print(RecapInsightCurator.debugCuratorReport(for: month, allTransactions: transactions))
        for row in recap.noticedInsights {
            print("  noticed row: family=\(row.family ?? "—") score=\(String(format: "%.3f", row.score))")
        }
    }

    /// Forced-render QA of the "Things We Noticed" and dynamic-insight layouts. The curated
    /// presets rarely pass the `≥2 diverse rows` bar, so the noticed shot is exercised with
    /// the same rows the flow would compose (`MonthlyRecapSheet` builds `.noticed` from
    /// `noticedInsights`); the dynamic `.insight` shot is exercised on the strongest insight.
    @MainActor
    func testNoticedAndInsightLayoutsRenderInBothLanguages() throws {
        try? FileManager.default.createDirectory(atPath: Self.outDir, withIntermediateDirectories: true)
        let recap = RecapPreviewData.recap(kind: .delivery)
        let rows = Array(recap.dynamicInsights.prefix(4))
        XCTAssertFalse(rows.isEmpty)

        for he in [true, false] {
            let noticed = RecapSceneFrame(shot: .noticed(rows), recap: recap, time: 6.0, he: he, currency: "₪")
                .environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
            let data = try XCTUnwrap(renderPNG(noticed))
            try data.write(to: URL(fileURLWithPath: "\(Self.outDir)/noticed_forced_\(he ? "he" : "en").png"))

            if let strongest = rows.first, let insight = RecapEditorialShot.insight(strongest) as RecapEditorialShot? {
                let frame = RecapSceneFrame(shot: insight, recap: recap, time: 4.6, he: he, currency: "₪")
                    .environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
                let insightData = try XCTUnwrap(renderPNG(frame))
                try insightData.write(to: URL(fileURLWithPath: "\(Self.outDir)/insight_curated_\(he ? "he" : "en").png"))
            }
        }
    }
}
