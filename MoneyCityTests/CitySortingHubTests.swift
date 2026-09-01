import XCTest
@testable import MoneyCity

final class CitySortingHubTests: XCTestCase {
    
    func testOtherCategoryMapsToCitySortingHub() {
        let engine = CategorizationEngine.shared
        let buildingId = engine.mapToBuildingId(category: .other, merchant: "כללי דואר")
        XCTAssertEqual(buildingId, "city_sorting_hub", "Other expenses must be assigned to the standalone sorting hub")
    }
    
    func testUnknownMerchantWithoutKeywordsDefaultsToOtherAndSortingHub() {
        let engine = CategorizationEngine.shared
        let res = engine.classify(merchant: "עסק חדש לגמרי ללא שם מוכר 123", amount: 150)
        XCTAssertEqual(res.category, .other)
        XCTAssertEqual(res.buildingId, "city_sorting_hub")
    }
    
    func testSortingTransactionMovesToNewDistrictAndBuilding() {
        let engine = CategorizationEngine.shared
        let tx = Transaction(
            amount: 45,
            merchant: "חנות אקראית",
            category: .other,
            timestamp: Date(),
            buildingId: "city_sorting_hub"
        )
        
        XCTAssertEqual(tx.category, .other)
        XCTAssertEqual(tx.buildingIdRaw, "city_sorting_hub")
        
        // Reclassify to food
        tx.category = .food
        tx.buildingIdRaw = engine.mapToBuildingId(category: .food, merchant: tx.merchant)
        
        XCTAssertEqual(tx.category, .food)
        XCTAssertEqual(tx.buildingIdRaw, "food_bistro")
    }
    
    func testKnownCategoriesDoNotGetMisclassifiedToSortingHub() {
        let engine = CategorizationEngine.shared
        XCTAssertEqual(engine.mapToBuildingId(category: .food, merchant: "ארומה"), "food_coffee")
        XCTAssertEqual(engine.mapToBuildingId(category: .food, merchant: "שופרסל"), "food_super")
        XCTAssertEqual(engine.mapToBuildingId(category: .shopping, merchant: "זארה"), "shop_boutique")
        XCTAssertEqual(engine.mapToBuildingId(category: .housing, merchant: "שכירות"), "house_tower")
        XCTAssertEqual(engine.mapToBuildingId(category: .transport, merchant: "פנגו"), "trans_station")
    }
}
