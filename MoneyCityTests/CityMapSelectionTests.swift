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

    // MARK: - Test A — Current Explicit Selection
    func testCurrentExplicitSelection() {
        let sep = makeDate(year: 2026, month: 9)
        CityMapSelection.save(.medieval, for: sep, defaults: testDefaults)

        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertTrue(CityMapSelection.hasSelection(for: sep, defaults: testDefaults))
    }

    // MARK: - Test B — Next Month Inherits
    func testNextMonthInherits() {
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)

        CityMapSelection.save(.medieval, for: sep, defaults: testDefaults)

        // October has no explicit entry
        XCTAssertNil(CityMapSelection.selectedStyle(for: oct, defaults: testDefaults))
        XCTAssertFalse(CityMapSelection.hasSelection(for: oct, defaults: testDefaults))

        // But resolvedStyle inherits Medieval from September
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: oct, defaults: testDefaults), .medieval)
    }

    // MARK: - Test C — Inheritance Across Multiple Empty Months
    func testInheritanceAcrossMultipleEmptyMonths() {
        let aug = makeDate(year: 2026, month: 8)
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)
        let nov = makeDate(year: 2026, month: 11)

        CityMapSelection.save(.arctic, for: aug, defaults: testDefaults)

        XCTAssertNil(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults))
        XCTAssertNil(CityMapSelection.selectedStyle(for: oct, defaults: testDefaults))
        XCTAssertNil(CityMapSelection.selectedStyle(for: nov, defaults: testDefaults))

        XCTAssertEqual(CityMapSelection.resolvedStyle(for: sep, defaults: testDefaults), .arctic)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: oct, defaults: testDefaults), .arctic)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: nov, defaults: testDefaults), .arctic)
    }

    // MARK: - Test D — Later Override
    func testLaterOverride() {
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)
        let nov = makeDate(year: 2026, month: 11)

        CityMapSelection.save(.medieval, for: sep, defaults: testDefaults)
        CityMapSelection.save(.israel, for: oct, defaults: testDefaults)

        XCTAssertEqual(CityMapSelection.resolvedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: oct, defaults: testDefaults), .israel)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: nov, defaults: testDefaults), .israel)
    }

    // MARK: - Test E — Historical Isolation
    func testHistoricalIsolation() {
        let aug = makeDate(year: 2026, month: 8)
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)
        let nov = makeDate(year: 2026, month: 11)

        CityMapSelection.save(.urban, for: aug, defaults: testDefaults)
        CityMapSelection.save(.medieval, for: sep, defaults: testDefaults)
        CityMapSelection.save(.israel, for: nov, defaults: testDefaults)

        // Verify August, September, October (inherited September), November
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: aug, defaults: testDefaults), .urban)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: oct, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: nov, defaults: testDefaults), .israel)

        // Overriding a later month does not modify older months
        CityMapSelection.save(.arctic, for: nov, defaults: testDefaults)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: aug, defaults: testDefaults), .urban)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: oct, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: nov, defaults: testDefaults), .arctic)
    }

    // MARK: - Test F — First-Ever Install Fallback
    func testFirstEverInstallFallback() {
        let anyDate = makeDate(year: 2026, month: 9)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: anyDate, defaults: testDefaults), .urban)
        XCTAssertNil(CityMapSelection.selectedStyle(for: anyDate, defaults: testDefaults))
        XCTAssertFalse(CityMapSelection.hasSelection(for: anyDate, defaults: testDefaults))
        XCTAssertTrue(CityMapSelection.selections(defaults: testDefaults).isEmpty)
    }

    // MARK: - Test G — Corrupted Data
    func testCorruptDataDoesNotCrash() {
        let corruptData = "not a valid json".data(using: .utf8)!
        testDefaults.set(corruptData, forKey: CityMapSelection.preferenceKey)

        let date = makeDate(year: 2026, month: 9)
        XCTAssertNil(CityMapSelection.selectedStyle(for: date, defaults: testDefaults))
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: date, defaults: testDefaults), .urban)
        XCTAssertTrue(CityMapSelection.selections(defaults: testDefaults).isEmpty)
    }

    func testCorruptNewFormatDataDoesNotCrash() {
        let corruptData = "{\"2026-09\": 42}".data(using: .utf8)! // invalid value type
        testDefaults.set(corruptData, forKey: CityMapSelection.preferenceKey)

        let date = makeDate(year: 2026, month: 9)
        XCTAssertNil(CityMapSelection.selectedStyle(for: date, defaults: testDefaults))
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: date, defaults: testDefaults), .urban)
    }

    func testUnknownStyleRawValue() {
        let dict = ["2026-09": ["style": "sci_fi_future_unknown", "confirmed": true]] as [String: [String: Any]]
        let data = try! JSONSerialization.data(withJSONObject: dict)
        testDefaults.set(data, forKey: CityMapSelection.preferenceKey)

        let date = makeDate(year: 2026, month: 9)
        XCTAssertNil(CityMapSelection.selectedStyle(for: date, defaults: testDefaults))
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: date, defaults: testDefaults), .urban)
    }

    // MARK: - Test H — Legacy Storage
    func testOldFlatFormatUpgraded() {
        let oldFormat = ["2026-09": "arctic"]
        let data = try! JSONEncoder().encode(oldFormat)
        testDefaults.set(data, forKey: CityMapSelection.preferenceKey)

        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)

        // Reading should upgrade automatically and resolve correctly
        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .arctic)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: sep, defaults: testDefaults), .arctic)
        // October inherits from upgraded September
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: oct, defaults: testDefaults), .arctic)
    }

    func testLegacyMigrationSingleKey() {
        testDefaults.set("2026-09|medieval", forKey: CityMapSelection.legacyPreferenceKey)

        CityMapSelection.migrateLegacyIfNeeded(defaults: testDefaults)

        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)

        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .medieval)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: sep, defaults: testDefaults), .medieval)
        // October inherits
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: oct, defaults: testDefaults), .medieval)
    }

    // MARK: - Test I — .future Not in Picker Worlds
    func testPickerWorldsDoesNotContainFuture() {
        XCTAssertFalse(CityMapSelection.pickerWorlds.contains(.future),
                       ".future must not appear in the picker until it is released")
        XCTAssertTrue(CityMapSelection.pickerWorlds.count >= 4,
                      "Picker should have at least urban, medieval, arctic, israel")
        XCTAssertEqual(CityMapSelection.pickerWorlds, [.urban, .medieval, .arctic, .israel])
    }

    // MARK: - Test J — confirmWorldChoice Alias Compatibility
    func testConfirmWorldChoiceAlias() {
        let sep = makeDate(year: 2026, month: 9)
        CityMapSelection.confirmWorldChoice(.israel, for: sep, defaults: testDefaults)

        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .israel)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: sep, defaults: testDefaults), .israel)
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
