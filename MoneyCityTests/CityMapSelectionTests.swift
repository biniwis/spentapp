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

    // MARK: - Original suite (preserved)

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
        // Store using the new dict format with an unknown style
        CityMapSelection.confirmWorldChoice(.urban, for: makeDate(year: 2026, month: 9), defaults: testDefaults)
        // Manually corrupt the stored entry
        let dict = ["2026-09": ["style": "sci_fi_future_unknown", "confirmed": true]] as [String: [String: Any]]
        let data = try! JSONSerialization.data(withJSONObject: dict)
        testDefaults.set(data, forKey: CityMapSelection.preferenceKey)

        let date = makeDate(year: 2026, month: 9)
        XCTAssertNil(CityMapSelection.selectedStyle(for: date, defaults: testDefaults))
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: date, defaults: testDefaults), .urban)
    }

    // MARK: - New lifecycle scenarios

    // A. ensureAssignedStyle — new month inherits previous month's confirmed style
    func testEnsureAssignedStyleInheritsPreviousMonth() {
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)

        CityMapSelection.confirmWorldChoice(.arctic, for: sep, defaults: testDefaults)

        let result = CityMapSelection.ensureAssignedStyle(for: oct, defaults: testDefaults)

        XCTAssertEqual(result, .arctic, "October should inherit September's confirmed arctic style")
        XCTAssertEqual(CityMapSelection.assignedStyle(for: oct, defaults: testDefaults), .arctic)
    }

    // B. ensureAssignedStyle — very first month ever → fallback to .urban
    func testEnsureAssignedStyleFirstMonthFallsBackToUrban() {
        let jan = makeDate(year: 2026, month: 1)
        let result = CityMapSelection.ensureAssignedStyle(for: jan, defaults: testDefaults)
        XCTAssertEqual(result, .urban)
    }

    // C. isWorldChoicePending — before any confirmation → true
    func testWorldChoicePendingBeforeConfirm() {
        let now = makeDate(year: 2026, month: 10)
        // ensureAssignedStyle writes an unconfirmed entry
        CityMapSelection.ensureAssignedStyle(for: now, defaults: testDefaults)
        XCTAssertTrue(CityMapSelection.isWorldChoicePending(for: now, defaults: testDefaults))
    }

    // D. confirmWorldChoice → isWorldChoicePending becomes false
    func testConfirmWorldChoiceClearsPending() {
        let now = makeDate(year: 2026, month: 10)
        CityMapSelection.ensureAssignedStyle(for: now, defaults: testDefaults)
        XCTAssertTrue(CityMapSelection.isWorldChoicePending(for: now, defaults: testDefaults))

        CityMapSelection.confirmWorldChoice(.medieval, for: now, defaults: testDefaults)
        XCTAssertFalse(CityMapSelection.isWorldChoicePending(for: now, defaults: testDefaults))
        XCTAssertEqual(CityMapSelection.selectedStyle(for: now, defaults: testDefaults), .medieval)
    }

    // E. Changing current month does not touch previous confirmed month
    func testConfirmCurrentMonthDoesNotTouchPreviousMonth() {
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)

        CityMapSelection.confirmWorldChoice(.israel, for: sep, defaults: testDefaults)
        CityMapSelection.confirmWorldChoice(.arctic, for: oct, defaults: testDefaults)

        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .israel)
        XCTAssertEqual(CityMapSelection.selectedStyle(for: oct, defaults: testDefaults), .arctic)
    }

    // F. Historical month with confirmed=true is not overwritten by ensureAssignedStyle
    func testEnsureAssignedStyleDoesNotOverwriteConfirmed() {
        let sep = makeDate(year: 2026, month: 9)
        CityMapSelection.confirmWorldChoice(.medieval, for: sep, defaults: testDefaults)

        // Re-calling ensure should not change it
        let result = CityMapSelection.ensureAssignedStyle(for: sep, defaults: testDefaults)
        XCTAssertEqual(result, .medieval)
        XCTAssertFalse(CityMapSelection.isWorldChoicePending(for: sep, defaults: testDefaults))
    }

    // G. Migration: old flat [String: String] format is upgraded to confirmed=true
    func testOldFlatFormatUpgradedToConfirmed() {
        // Write old-format data directly
        let oldFormat = ["2026-09": "arctic"]
        let data = try! JSONEncoder().encode(oldFormat)
        testDefaults.set(data, forKey: CityMapSelection.preferenceKey)

        let sep = makeDate(year: 2026, month: 9)
        // Reading should upgrade automatically
        XCTAssertEqual(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults), .arctic)
        // And mark as confirmed so the picker doesn't re-show
        XCTAssertFalse(CityMapSelection.isWorldChoicePending(for: sep, defaults: testDefaults))
    }

    // H. assignedStyle inherits from two months back when one month is skipped
    func testAssignedStyleInheritsTwoMonthsBack() {
        let aug = makeDate(year: 2026, month: 8)
        let sep = makeDate(year: 2026, month: 9)
        let oct = makeDate(year: 2026, month: 10)

        // August is confirmed, September has no record, October asks for assignment
        CityMapSelection.confirmWorldChoice(.medieval, for: aug, defaults: testDefaults)

        // September has no entry at all
        XCTAssertNil(CityMapSelection.selectedStyle(for: sep, defaults: testDefaults))

        // October should inherit August (skipping September which has no confirmed entry)
        let result = CityMapSelection.assignedStyle(for: oct, defaults: testDefaults)
        XCTAssertEqual(result, .medieval)
    }

    // I. pickerWorlds does not contain .future
    func testPickerWorldsDoesNotContainFuture() {
        XCTAssertFalse(CityMapSelection.pickerWorlds.contains(.future),
                       ".future must not appear in the picker until it is released")
        XCTAssertTrue(CityMapSelection.pickerWorlds.count >= 4,
                      "Picker should have at least urban, medieval, arctic, israel")
    }

    // J. Corrupt data → graceful fallback for new format too
    func testCorruptNewFormatDataDoesNotCrash() {
        let corruptData = "{\"2026-09\": 42}".data(using: .utf8)! // invalid value type
        testDefaults.set(corruptData, forKey: CityMapSelection.preferenceKey)

        let date = makeDate(year: 2026, month: 9)
        XCTAssertNil(CityMapSelection.selectedStyle(for: date, defaults: testDefaults))
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: date, defaults: testDefaults), .urban)
    }

    // K. resolvedStyle backward compatibility — save() marks confirmed, resolvedStyle still works
    func testResolvedStyleBackwardCompatibility() {
        let date = makeDate(year: 2026, month: 9)
        CityMapSelection.save(.arctic, for: date, defaults: testDefaults)
        XCTAssertEqual(CityMapSelection.resolvedStyle(for: date, defaults: testDefaults), .arctic)
        XCTAssertFalse(CityMapSelection.isWorldChoicePending(for: date, defaults: testDefaults))
    }
}

// MARK: - Map resource contract tests

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
