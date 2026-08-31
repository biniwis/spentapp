import XCTest
@testable import MoneyCity

final class CategorizationEngineTests: XCTestCase {
    
    func testIsraeliMerchantExactAndPrefixMatching() {
        let engine = CategorizationEngine.shared
        
        // Whole-word short token vs substring
        let barMatch = engine.classify(merchant: "בר יין רוטשילד", amount: 180)
        XCTAssertEqual(barMatch.category, .food)
        XCTAssertEqual(barMatch.buildingId, "food_bistro")
        
        let danMatch = engine.classify(merchant: "דן אוטובוסים", amount: 12)
        XCTAssertEqual(danMatch.category, .transport)
        
        let gettMatch = engine.classify(merchant: "Gett נסיעה", amount: 45)
        XCTAssertEqual(gettMatch.category, .transport)
        
        // Supermarkets
        let shufersal = engine.classify(merchant: "שופרסל שלי סניף דיזנגוף", amount: 230)
        XCTAssertEqual(shufersal.category, .food)
        XCTAssertEqual(shufersal.buildingId, "food_super")
        
        // Wolt delivery
        let wolt = engine.classify(merchant: "Wolt משלוח פיצה", amount: 89)
        XCTAssertEqual(wolt.category, .food)
        XCTAssertEqual(wolt.buildingId, "food_wolt")
        
        // Coffee
        let aroma = engine.classify(merchant: "ארומה קפה קניון עזריאלי", amount: 24)
        XCTAssertEqual(aroma.category, .food)
        XCTAssertEqual(aroma.buildingId, "food_coffee")
        
        // Tech & Shopping
        let ksp = engine.classify(merchant: "KSP מחשבים וסלולר", amount: 450)
        XCTAssertEqual(ksp.category, .shopping)
        XCTAssertEqual(ksp.buildingId, "shop_tech")
        
        let zara = engine.classify(merchant: "זארה קניון רמת אביב", amount: 350)
        XCTAssertEqual(zara.category, .shopping)
        XCTAssertEqual(zara.buildingId, "shop_boutique")
    }
}
