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

    // MARK: - 1. Default Classic for New User
    func testDefaultClassicForNewUser() {
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .urban)
        XCTAssertFalse(CityMapSelection.hasCustomStyle(defaults: testDefaults))
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: Date(), defaults: testDefaults), .urban)
    }

    // MARK: - 2. Global Style Selection & Change
    func testGlobalStyleSelectionAndImmediateChange() {
        CityMapSelection.save(.medieval, defaults: testDefaults)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .medieval)
        XCTAssertTrue(CityMapSelection.hasCustomStyle(defaults: testDefaults))

        // No month dependency: past, present, and future dates return the user's global style
        let pastDate = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let futureDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: pastDate, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: futureDate, defaults: testDefaults), .medieval)

        // Change to another style
        CityMapSelection.save(.israel, defaults: testDefaults)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .israel)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: pastDate, defaults: testDefaults), .israel)
    }

    // MARK: - 3. Persistence
    func testPersistenceAcrossDefaultsReload() {
        CityMapSelection.save(.arctic, defaults: testDefaults)
        XCTAssertEqual(testDefaults.string(forKey: CityMapSelection.preferenceKey), "arctic")
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .arctic)
    }

    // MARK: - 4. Corrupt Data Fallback
    func testCorruptDataFallsBackToUrban() {
        testDefaults.set(Data([0xFF, 0xFE, 0xFD]), forKey: CityMapSelection.preferenceKey)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .urban)
    }

    // MARK: - 5. Unknown Raw Value Fallback
    func testUnknownRawValueFallsBackToUrban() {
        testDefaults.set("cyberpunk_neon_future", forKey: CityMapSelection.preferenceKey)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .urban)
    }

    // MARK: - 6. Migration from v2 Monthly Selections Dictionary
    func testMigrationFromV2MonthlySelections() {
        let entries: [String: CityMapSelection.MonthEntry] = [
            "2026-08": CityMapSelection.MonthEntry(style: "urban", confirmed: true),
            "2026-09": CityMapSelection.MonthEntry(style: "medieval", confirmed: true)
        ]
        let data = try! JSONEncoder().encode(entries)
        testDefaults.set(data, forKey: CityMapSelection.legacyMonthlyKey)

        // Reading currentStyle should migrate to the latest valid selection (medieval)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .medieval)
        // Global key must now be persisted
        XCTAssertEqual(testDefaults.string(forKey: CityMapSelection.preferenceKey), "medieval")
    }

    func testMigrationFromV2MonthlySelectionsFlatStringFormat() {
        let flat: [String: String] = [
            "2026-08": "arctic"
        ]
        let data = try! JSONEncoder().encode(flat)
        testDefaults.set(data, forKey: CityMapSelection.legacyMonthlyKey)

        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .arctic)
        XCTAssertEqual(testDefaults.string(forKey: CityMapSelection.preferenceKey), "arctic")
    }

    // MARK: - 7. Migration from Legacy Onboarding Key
    func testMigrationFromOnboardingMapStyle() {
        testDefaults.set("israel", forKey: CityMapSelection.legacyOnboardingKey)

        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .israel)
        XCTAssertEqual(testDefaults.string(forKey: CityMapSelection.preferenceKey), "israel")
    }

    // MARK: - 8. Migration from Legacy Pipe-Delimited Single Key
    func testMigrationFromLegacySingleKey() {
        testDefaults.set("2026-09|medieval", forKey: CityMapSelection.legacyPreferenceKey)

        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .medieval)
        XCTAssertEqual(testDefaults.string(forKey: CityMapSelection.preferenceKey), "medieval")
    }

    // MARK: - 9. Picker Worlds Specification
    func testPickerWorldsDoesNotContainFuture() {
        XCTAssertFalse(CityMapSelection.pickerWorlds.contains(.future),
                       ".future must not appear in the picker until it is released")
        XCTAssertEqual(CityMapSelection.pickerWorlds, [.urban, .medieval, .arctic, .israel])
    }

    // MARK: - 10. Compatibility aliases
    func testCompatibilityAliases() {
        CityMapSelection.confirmWorldChoice(.arctic, defaults: testDefaults)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .arctic)
        XCTAssertEqual(CityMapSelection.selectedStyle(defaults: testDefaults), .arctic)
        XCTAssertTrue(CityMapSelection.hasSelection(defaults: testDefaults))
    }
}


// MARK: - Map resource contract tests

final class CityMapContractTests: XCTestCase {

    // Verify each map HTML resource contains finance_bank, no city_hall, and no demo payload
    func testEachMapCompliesWithWorldContract() throws {
        for style in CityMapStyle.allCases {
            guard let url = Bundle.main.url(forResource: style.resourceName, withExtension: "html") else {
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

    // Verify that diorama.html and diorama_medieval.html actually exist in the bundle
    func testDioramaResourcesExist() {
        let requiredResources = [
            ("diorama", "html"),
            ("diorama_medieval", "html")
        ]
        for (name, ext) in requiredResources {
            let url = Bundle.main.url(forResource: name, withExtension: ext)
            XCTAssertNotNil(url, "\(name).\(ext) must exist in the main bundle")
        }
    }
}
