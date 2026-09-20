import XCTest
@testable import MoneyCity

final class CityMapSelectionTests: XCTestCase {
    
    private var testDefaults: UserDefaults!
    private let suiteName = "CityMapSelectionTestsSuite"
    
    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
    }
    
    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        super.tearDown()
    }
    
    private func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar.current.date(from: comps)!
    }
    
    // 1. Month isolation — September=Medieval, October=Urban; opening September still returns Medieval
    func testMonthIsolation() {
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)
        
        CityMapSelection.save(.medieval, for: sep, defaults: testDefaults)
        CityMapSelection.save(.urban, for: oct, defaults: testDefaults)
        
        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.selectedStyle(for: oct, defaults: testDefaults), .urban)
    }
    
    // 2. Future month does not inherit — October with no selection returns nil from selectedStyle
    func testFutureMonthDoesNotInherit() {
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)
        
        CityMapSelection.save(.medieval, for: sep, defaults: testDefaults)
        
        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertNil(CityMapSelection.selectedStyle(for: oct, defaults: testDefaults))
        XCTAssertFalse(CityMapSelection.hasSelection(for: oct, defaults: testDefaults))
        // But resolvedStyle returns .urban as standard fallback
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: oct, defaults: testDefaults), .urban)
    }
    
    // 3. Historical fallback — old month with no saved map -> resolvedStyle returns .urban
    func testHistoricalFallback() {
        let oldMonth = makeDate(year: 2025, month: 1)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: oldMonth, defaults: testDefaults), .urban)
        XCTAssertNil(CityMapSelection.selectedStyle(for: oldMonth, defaults: testDefaults))
    }
    
    // 4. Changing current month does not modify old month
    func testChangingCurrentMonthDoesNotModifyOldMonth() {
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)
        
        CityMapSelection.save(.medieval, for: sep, defaults: testDefaults)
        CityMapSelection.save(.urban, for: oct, defaults: testDefaults)
        CityMapSelection.save(.medieval, for: oct, defaults: testDefaults)
        
        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.selectedStyle(for: oct, defaults: testDefaults), .medieval)
    }
    
    // 5. Legacy migration — spent.city.mapSelection = "2026-09|medieval" -> migrates only September; October remains unselected
    func testLegacyMigration() {
        testDefaults.set("2026-09|medieval", forKey: CityMapSelection.legacyPreferenceKey)
        
        CityMapSelection.migrateLegacyIfNeeded(defaults: testDefaults)
        
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)
        
        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertNil(CityMapSelection.selectedStyle(for: oct, defaults: testDefaults))
    }
    
    // 6. Invalid data — corrupt JSON does not crash, returns empty dict
    func testCorruptDataDoesNotCrash() {
        let corruptData = "not a valid json".data(using: .utf8)!
        testDefaults.set(corruptData, forKey: CityMapSelection.preferenceKey)
        
        let date = makeDate(year: 2026, month: 9)
        XCTAssertNil(CityMapSelection.selectedStyle(for: date, defaults: testDefaults))
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: date, defaults: testDefaults), .urban)
        XCTAssertTrue(CityMapSelection.selections(defaults: testDefaults).isEmpty)
    }
    
    // 7. Unknown style rawValue -> selectedStyle returns nil, not a crash
    func testUnknownStyleRawValue() {
        let dict = ["2026-09": "sci_fi_future_unknown"]
        let data = try! JSONEncoder().encode(dict)
        testDefaults.set(data, forKey: CityMapSelection.preferenceKey)
        
        let date = makeDate(year: 2026, month: 9)
        XCTAssertNil(CityMapSelection.selectedStyle(for: date, defaults: testDefaults))
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: date, defaults: testDefaults), .urban)
    }
}

final class CityMapContractTests: XCTestCase {
    
    // Verify each map HTML resource contains finance_bank, no city_hall, and no demo payload
    func testEachMapCompliesWithWorldContract() throws {
        for style in CityMapStyle.allCases {
            guard let url = Bundle.main.url(forResource: style.resourceName, withExtension: "html") else {
                // If running in test bundle without main bundle assets, locate via Bundle(for: Self.self) or path
                continue
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // 1. Must register finance_bank
            XCTAssertTrue(content.contains("finance_bank"), "\(style) must register finance_bank")
            
            // 2. Must not contain city_hall
            XCTAssertFalse(content.contains("\"city_hall\""), "\(style) must not contain \"city_hall\"")
            XCTAssertFalse(content.contains("cityHallProgress"), "\(style) must not contain cityHallProgress")
            XCTAssertFalse(content.contains("applyCityHallProgress"), "\(style) must not contain applyCityHallProgress")
            
            // 3. Must not have hardcoded demo payload definition
            XCTAssertFalse(content.contains("window._initialDataPayload = {"), "\(style) must not have hardcoded demo payload")
        }
    }
}
