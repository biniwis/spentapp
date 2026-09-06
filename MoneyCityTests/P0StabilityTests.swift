import XCTest
import SwiftData
@testable import MoneyCity

final class P0StabilityTests: XCTestCase {

    func testUniqueBuildingIDsAcrossAllCategories() {
        var seenIDs = Set<String>()
        for cat in SpendingCategory.primaryCategories {
            let buildings = CityBuilding.buildings(for: cat)
            for b in buildings {
                XCTAssertFalse(
                    seenIDs.contains(b.id),
                    "Building ID '\(b.id)' in category \(cat) is duplicated! Building IDs must be strictly unique."
                )
                seenIDs.insert(b.id)
            }
        }
        XCTAssertTrue(seenIDs.contains("shop_boutique"))
        XCTAssertTrue(seenIDs.contains("health_pharmacy"))
        XCTAssertTrue(seenIDs.contains("finance_bank"))
        XCTAssertTrue(seenIDs.contains("city_sorting_hub"))
        XCTAssertTrue(seenIDs.contains("museum_curiosities"))
    }

    func testLegacyBuildingIDMigration() {
        // Legacy transactions stored with shop_boutique under health or finance
        let healthTx = Transaction(
            amount: 75.0,
            merchant: "סופר פארם",
            category: .health,
            buildingId: "shop_boutique"
        )
        XCTAssertEqual(healthTx.buildingId, "health_pharmacy", "Legacy shop_boutique in Health must normalize to health_pharmacy")

        let financeTx = Transaction(
            amount: 25.0,
            merchant: "עמלת שורה בנק לאומי",
            category: .finance,
            buildingId: "shop_boutique"
        )
        XCTAssertEqual(financeTx.buildingId, "finance_bank", "Legacy shop_boutique in Finance must normalize to finance_bank")

        let shoppingTx = Transaction(
            amount: 150.0,
            merchant: "זארה",
            category: .shopping,
            buildingId: "shop_boutique"
        )
        XCTAssertEqual(shoppingTx.buildingId, "shop_boutique", "Valid shop_boutique in Shopping must remain shop_boutique")
    }

    func testMissingMerchantIngestDefaultsToOtherAndUnconfirmed() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: 85.0,
            amountText: nil,
            merchant: nil,
            currency: "₪",
            date: Date(),
            existing: []
        )

        XCTAssertEqual(tx.merchant, "לא זוהה")
        XCTAssertEqual(tx.category, .other)
        XCTAssertEqual(tx.buildingId, "city_sorting_hub")
        XCTAssertFalse(tx.isConfirmed, "Missing merchant transactions must never be confirmed automatically")
        XCTAssertEqual(tx.confidenceScore, 0.5)
        XCTAssertTrue(tx.note?.contains("לא זוהה") == true)
    }

    func testRefundSalvageFromNegativeText() throws {
        let salvaged = TransactionIngest.salvage(
            amount: nil,
            amountText: "-450.00 ₪",
            merchant: "איקאה זיכוי"
        )

        XCTAssertTrue(salvaged.isRefund)
        XCTAssertEqual(salvaged.amount, 450.00)

        let tx = try TransactionIngest.makeTransaction(
            amount: salvaged.amount,
            amountText: "-450.00 ₪",
            merchant: salvaged.merchant,
            currency: "₪",
            date: Date(),
            existing: [],
            isRefundHint: salvaged.isRefund
        )

        XCTAssertEqual(tx.amount, -450.00, "Refund must preserve negative amount")
        XCTAssertFalse(tx.isConfirmed, "Refunds must never be confirmed without user review")
        XCTAssertTrue(tx.note?.contains("זיכוי") == true)
    }

    func testPrimaryCategoriesIncludeFinanceAndOther() {
        let primaries = SpendingCategory.primaryCategories
        XCTAssertTrue(primaries.contains(.finance), "primaryCategories must contain .finance")
        XCTAssertTrue(primaries.contains(.other), "primaryCategories must contain .other")
        XCTAssertTrue(primaries.contains(.miscellaneous), "primaryCategories must contain .miscellaneous")
        XCTAssertEqual(primaries.count, 11, "Must have exactly 11 distinct primary categories")
    }
}
