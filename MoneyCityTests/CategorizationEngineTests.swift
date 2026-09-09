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
    
    func testEnglishMerchantsAndGateways() {
        let engine = CategorizationEngine.shared
        
        // English merchants with gateway prefixes
        let spotify = engine.classify(merchant: "PAYPAL *SPOTIFY", amount: 21.90)
        XCTAssertEqual(spotify.category, .subscriptions)
        
        let netflix = engine.classify(merchant: "NETFLIX.COM", amount: 54.90)
        XCTAssertEqual(netflix.category, .subscriptions)
        
        let amazon = engine.classify(merchant: "AMAZON EU SARL", amount: 120)
        XCTAssertEqual(amazon.category, .shopping)
        
        let mcd = engine.classify(merchant: "MCDONALDS TLV", amount: 48)
        XCTAssertEqual(mcd.category, .food)
        
        let pango = engine.classify(merchant: "PANGO PARKING", amount: 15)
        XCTAssertEqual(pango.category, .transport)
        
        let elal = engine.classify(merchant: "EL AL AIRWAYS", amount: 1200)
        XCTAssertEqual(elal.category, .transport)
        
        let superPharm = engine.classify(merchant: "SUPER-PHARM DIZENGOFF", amount: 85)
        XCTAssertEqual(superPharm.category, .health)
    }
    
    func testHebrewPrefixStemming() {
        let engine = CategorizationEngine.shared
        
        // Prefix ב-
        let inWolt = engine.classify(merchant: "בוולט", amount: 95)
        XCTAssertEqual(inWolt.category, .food)
        
        let inShufersal = engine.classify(merchant: "בשופרסל", amount: 200)
        XCTAssertEqual(inShufersal.category, .food)
        
        let inPango = engine.classify(merchant: "בפנגו", amount: 18)
        XCTAssertEqual(inPango.category, .transport)
        
        let inZara = engine.classify(merchant: "בזארה", amount: 250)
        XCTAssertEqual(inZara.category, .shopping)
        
        // Transaction phrases
        let dealIn = engine.classify(merchant: "עסקה ב-ארומה", amount: 22)
        XCTAssertEqual(dealIn.category, .food)
        
        let bit = engine.classify(merchant: "BIT-דומינוס פיצה", amount: 75)
        XCTAssertEqual(bit.category, .food)
    }
}
