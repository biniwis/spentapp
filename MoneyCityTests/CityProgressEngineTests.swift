import XCTest
@testable import MoneyCity

final class CityProgressEngineTests: XCTestCase {
    
    func testZeroPreviousWeekDoesNotInventProgress() {
        let engine = CityProgressEngine.shared
        let now = Date()
        
        let currentTxs = [
            Transaction(amount: 150, merchant: "שופרסל", category: .food, timestamp: now)
        ]
        
        let report = engine.evaluateProgress(transactions: currentTxs, unlockedItemIds: [], referenceDate: now)
        
        XCTAssertFalse(report.hasPositiveProgress)
        XCTAssertEqual(report.savedAmount, 0.0)
        XCTAssertEqual(report.previousWeekTotal, 0.0)
        XCTAssertEqual(report.progressTier, "none")
        XCTAssertTrue(report.availableOptions.isEmpty)
    }
    
    func testRealSavingsAwardsCorrectTierAndExcludesRent() {
        let engine = CityProgressEngine.shared
        let now = Date()
        let cal = Calendar.current
        
        let tenDaysAgo = cal.date(byAdding: .day, value: -10, to: now)!
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: now)!
        
        // Prev week: ₪800 variable spending + ₪3,500 rent
        // Current week: ₪450 variable spending + ₪3,500 rent
        let txs = [
            Transaction(amount: 3500, merchant: "שכירות", category: .housing, timestamp: tenDaysAgo),
            Transaction(amount: 800, merchant: "מסעדות וקניות", category: .food, timestamp: tenDaysAgo),
            Transaction(amount: 3500, merchant: "שכירות", category: .housing, timestamp: threeDaysAgo),
            Transaction(amount: 450, merchant: "מסעדות", category: .food, timestamp: threeDaysAgo)
        ]
        
        let report = engine.evaluateProgress(transactions: txs, unlockedItemIds: [], referenceDate: now)
        
        XCTAssertTrue(report.hasPositiveProgress)
        XCTAssertEqual(report.previousWeekTotal, 800.0) // Rent excluded
        XCTAssertEqual(report.currentWeekTotal, 450.0)   // Rent excluded
        XCTAssertEqual(report.savedAmount, 350.0)       // ₪800 - ₪450 = ₪350
        XCTAssertEqual(report.progressTier, "medium")   // 200..500 is medium
        XCTAssertFalse(report.availableOptions.isEmpty)
    }
}
