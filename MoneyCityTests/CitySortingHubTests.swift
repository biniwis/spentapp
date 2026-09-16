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
        XCTAssertEqual(engine.mapToBuildingId(category: .miscellaneous, merchant: "מתנה לחג"), "museum_curiosities")
    }

    func testMiscellaneousCategoryMapsToMuseumOfCuriosities() {
        let engine = CategorizationEngine.shared
        let buildingId = engine.mapToBuildingId(category: .miscellaneous, merchant: "תרומה לקהילה")
        XCTAssertEqual(buildingId, "museum_curiosities", "Miscellaneous expenses must be assigned to the Museum of Curiosities")

        let gift = engine.classify(merchant: "מתנה ליום הולדת", amount: 200)
        XCTAssertEqual(gift.category, .miscellaneous)
        XCTAssertEqual(gift.buildingId, "museum_curiosities")

        let fine = engine.classify(merchant: "קנס חניה עיריית תל אביב", amount: 100)
        XCTAssertEqual(fine.category, .miscellaneous)
        XCTAssertEqual(fine.buildingId, "museum_curiosities")
    }

    // MARK: - Regression Tests: Dashboard & Quick Categorization State Alignment

    func testSingleUncategorizedTransactionDashboardAndSortingHubStayInSync() {
        let engine = CategorizationEngine.shared
        let tx = Transaction(
            amount: 45.0,
            merchant: "חנות חדשה",
            category: .other,
            timestamp: Date(),
            buildingId: "city_sorting_hub"
        )
        let list = [tx]

        // 1. Initial State: exactly 1 uncategorized transaction, ₪45
        XCTAssertTrue(tx.needsCategorization, "Transaction must need categorization")
        let hubTxs = DistrictDataHelper.sortingHubTransactions(from: list)
        XCTAssertEqual(hubTxs.count, 1, "Quick Categorization list must contain exactly 1 transaction")
        XCTAssertEqual(hubTxs.first?.id, tx.id, "Quick Categorization list must contain the exact same transaction")
        XCTAssertEqual(DistrictDataHelper.sortingHubCount(from: list), 1, "Dashboard count must be 1")
        XCTAssertEqual(DistrictDataHelper.sortingHubAmount(from: list), 45.0, "Dashboard amount must be ₪45")
        XCTAssertEqual(DistrictDataHelper.buildingVisitCount(for: "city_sorting_hub", transactions: list), 1)

        // 2. User classifies it to .food
        tx.category = .food
        tx.buildingIdRaw = engine.mapToBuildingId(category: .food, merchant: tx.merchant)

        // 3. Post-classification: both list and dashboard count drop to 0 immediately
        XCTAssertFalse(tx.needsCategorization, "Transaction must no longer need categorization")
        let updatedHubTxs = DistrictDataHelper.sortingHubTransactions(from: list)
        XCTAssertTrue(updatedHubTxs.isEmpty, "Quick Categorization list must now be empty")
        XCTAssertEqual(DistrictDataHelper.sortingHubCount(from: list), 0, "Dashboard count must drop to 0")
        XCTAssertEqual(DistrictDataHelper.sortingHubAmount(from: list), 0.0, "Dashboard amount must drop to 0")
        XCTAssertEqual(DistrictDataHelper.buildingVisitCount(for: "city_sorting_hub", transactions: list), 0)
    }

    func testTransactionWithSortingHubBuildingIdIsIncludedInSortingHub() {
        let tx = Transaction(
            amount: 75.0,
            merchant: "עסק מוזר",
            category: .other,
            timestamp: Date(),
            buildingId: "city_sorting_hub"
        )
        XCTAssertTrue(tx.needsCategorization)
        XCTAssertEqual(DistrictDataHelper.sortingHubCount(from: [tx]), 1)
        XCTAssertEqual(DistrictDataHelper.sortingHubAmount(from: [tx]), 75.0)
        XCTAssertEqual(DistrictDataHelper.sortingHubTransactions(from: [tx]).count, 1)
    }

    func testCategorizedTransactionDoesNotRetainSortingHubBuildingId() {
        let tx = Transaction(
            amount: 30.0,
            merchant: "פיצה שכונתית",
            category: .food,
            timestamp: Date(),
            buildingId: "city_sorting_hub"
        )
        // Even if buildingId was city_sorting_hub when category is .food, normalization resolves to default for food
        XCTAssertEqual(tx.buildingId, CityBuilding.defaultBuildingId(for: .food), "Categorized expense must not retain sorting hub buildingId")
        XCTAssertFalse(tx.needsCategorization, "Categorized expense must not need categorization")
        XCTAssertEqual(DistrictDataHelper.sortingHubCount(from: [tx]), 0)
    }
}
