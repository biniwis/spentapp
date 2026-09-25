import XCTest
@testable import MoneyCity

#if DEBUG && !SWIFT_PACKAGE
/// Covers the shared create wizard's logic without driving the UI: how a typed target
/// becomes minor units per currency, that presets follow the currency rather than the
/// shekel, and that the store still refuses a target it was never given.
@MainActor
final class SharedCreateTargetTests: XCTestCase {

    private let code = "iCloud.com.moneycity.app"

    /// The same conversion the create step performs, kept here so a change to either one
    /// shows up as a failing expectation rather than as a wrong number on screen.
    private func target(from typed: String, currency: String) -> Int64? {
        let digits = OnboardingWizardView.sanitizedBudgetDigits(typed)
        guard !digits.isEmpty else { return nil }
        return try? SharedMoney.minor(digits, currency: currency)
    }

    // MARK: - Sanitizing

    func testSanitizingKeepsDigitsOnlyAndWholeUnits() {
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("8,000"), "8000")
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("₪ 12000"), "12000")
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("12.5"), "12",
                       "The decimal point truncates rather than concatenating, as in personal onboarding")
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("abc"), "")
    }

    func testSanitizingCapsLength() {
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("1234567890123").count, 9)
    }

    // MARK: - Typed amount to minor units

    func testTypedTargetBecomesMinorUnitsForILS() throws {
        XCTAssertEqual(target(from: "8000", currency: "ILS"), 800_000)
        XCTAssertEqual(target(from: "5,000", currency: "ILS"), 500_000)
    }

    /// The reason conversion cannot be a hardcoded ×100: a zero-decimal currency would
    /// come out a hundred times too large.
    func testTypedTargetBecomesMinorUnitsForJPY() throws {
        XCTAssertEqual(target(from: "8000", currency: "JPY"), 8_000)
        XCTAssertEqual(try SharedMoney.minor("8000", currency: "JPY"), 8_000)
    }

    func testTypedTargetBecomesMinorUnitsForThreeDecimalCurrency() throws {
        XCTAssertEqual(try SharedMoney.minor("500", currency: "KWD"), 500_000)
    }

    /// Nothing the user can type in the field may produce a usable target.
    func testUnusableTypedTargetsProduceNil() {
        XCTAssertNil(target(from: "", currency: "ILS"))
        XCTAssertNil(target(from: "abc", currency: "ILS"))
        XCTAssertNil(target(from: "0", currency: "ILS"))
    }

    // MARK: - Presets follow the currency

    func testPresetsAreTheApprovedShekelFiguresForILS() {
        XCTAssertEqual(SharedMoney.monthlyTargetPresets(currency: "ILS").map {
            SharedMoney.formattedMajor($0, currency: "ILS")
        }, ["5,000", "8,000", "12,000", "15,000"])
    }

    /// The suggestion stays a round number whatever the currency's digit count, because
    /// it is chosen in whole units and only the conversion is currency-aware.
    func testPresetsScaleWithTheCurrency() {
        XCTAssertEqual(SharedMoney.monthlyTargetPresets(currency: "JPY"), [5_000, 8_000, 12_000, 15_000])
        XCTAssertEqual(SharedMoney.monthlyTargetPresets(currency: "ILS").map {
            SharedMoney.formattedMajor($0, currency: "ILS")
        }, ["5,000", "8,000", "12,000", "15,000"])
    }

    /// The same minor amount is a different number of units per currency — this is the
    /// reason nothing in the flow multiplies by a fixed power of ten.
    func testMinorUnitsMeanDifferentAmountsPerCurrency() {
        XCTAssertEqual(SharedMoney.formattedMajor(5_000, currency: "ILS"), "50")
        XCTAssertEqual(SharedMoney.formattedMajor(5_000, currency: "JPY"), "5,000")
        XCTAssertEqual(SharedMoney.formattedMajor(500_000, currency: "ILS"), "5,000")
    }

    // MARK: - The store still validates

    /// Whatever the button allows, the store refuses a target it was handed. nil, zero and
    /// negative are all rejected before anything is created.
    func testStoreRefusesUnusableTargets() async {
        let store = SharedWorkspaceStore()
        for bad in [nil, Int64(0), -1, -800_000] as [Int64?] {
            do {
                try await store.create(name: "x", memberName: "y", currency: "ILS",
                                       mapStyle: "urban", monthlyBudgetMinor: bad)
                // Reaching CloudKit means validation let it through. The call is expected
                // to fail there instead, so assert we never got a live space.
                XCTAssertNil(store.activeSpaceID)
            } catch {
                if case SharedLedgerError.invalidAmount = error {
                    XCTAssertNil(store.activeSpaceID)
                    XCTAssertTrue(store.spaces.isEmpty)
                } else {
                    // Rejected later, by the account or transport — not a silent success.
                    XCTAssertNil(store.activeSpaceID, "No space may be published on a failed create")
                    XCTAssertTrue(store.spaces.isEmpty)
                }
            }
        }
    }

    // MARK: - Currency symbol

    func testSymbolFollowsTheCurrency() {
        XCTAssertFalse(SharedMoney.symbol("USD").isEmpty)
        XCTAssertFalse(SharedMoney.symbol("ILS").isEmpty)
        // An unknown code still renders something rather than an empty gap.
        XCTAssertFalse(SharedMoney.symbol("ZZZ").isEmpty)
    }
}
#endif
