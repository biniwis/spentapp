import XCTest
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
        XCTAssertEqual(recap.tallestBuilding?.merchantName, "Rent Landlord")
        XCTAssertEqual(recap.tallestBuilding?.amount, 3200)
        
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
        XCTAssertEqual(recap.mostRepeatedStop?.merchantName, "Coffee Shop")
        XCTAssertEqual(recap.mostRepeatedStop?.visitCount, 1)
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
        var txs: [Transaction] = []
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
}
