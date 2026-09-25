import XCTest
@testable import MoneyCity

#if DEBUG && !SWIFT_PACKAGE
/// Covers the space's own monthly target: that it round-trips, that a space which
/// predates the field still decodes, that minor units respect the space's currency, and
/// that a space without a target reports no numbers instead of a zero.
@MainActor
final class SharedBudgetTests: XCTestCase {

    // MARK: - Data

    /// The exact payload a space created before the target existed would have carried.
    /// Decoding it must succeed and report no target — not fail, and not invent one.
    func testSpaceWithoutTargetDecodesFromLegacyPayload() throws {
        let legacy = """
        {"id":"3F2504E0-4F89-41D3-9A0C-0305E82C3301","name":"Our home","currencyCode":"ILS",\
        "timeZoneID":"Asia/Jerusalem","mapStyle":"urban","createdAt":700000000}
        """
        let space = try JSONDecoder().decode(SharedSpace.self, from: Data(legacy.utf8))
        XCTAssertNil(space.monthlyBudgetMinor, "A space with no stored target must not gain one")
        XCTAssertEqual(space.name, "Our home")
        XCTAssertEqual(space.currencyCode, "ILS")
    }

    func testSpaceWithTargetRoundTrips() throws {
        let space = SharedSpace(id: UUID(), name: "Our home", currencyCode: "ILS",
                                timeZoneID: "Asia/Jerusalem", mapStyle: "urban", createdAt: Date(),
                                monthlyBudgetMinor: 800_000)
        let decoded = try JSONDecoder().decode(SharedSpace.self, from: JSONEncoder().encode(space))
        XCTAssertEqual(decoded.monthlyBudgetMinor, 800_000)
        XCTAssertEqual(decoded, space)
    }

    func testTargetOfZeroIsStoredButNotTreatedAsATarget() {
        let space = SharedSpace(id: UUID(), name: "x", currencyCode: "ILS",
                                timeZoneID: "UTC", mapStyle: "urban", createdAt: Date(), monthlyBudgetMinor: 0)
        XCTAssertFalse(space.progress(spentMinor: 0).hasTarget)
    }

    // MARK: - Currency

    /// The target is minor units of the space's currency, so the same typed amount has to
    /// scale with the currency's own digits.
    func testTargetMinorUnitsRespectCurrencyDigits() throws {
        XCTAssertEqual(try SharedMoney.minor("8000", currency: "ILS"), 800_000)
        XCTAssertEqual(try SharedMoney.minor("8000", currency: "JPY"), 8_000)
        XCTAssertEqual(SharedMoney.major(800_000, currency: "ILS"), 8_000, accuracy: 0.001)
        XCTAssertEqual(SharedMoney.major(8_000, currency: "JPY"), 8_000, accuracy: 0.001)
    }

    // MARK: - Progress

    func testProgressReportsRemainingAndFraction() {
        let space = SharedSpace(id: UUID(), name: "x", currencyCode: "ILS",
                                timeZoneID: "UTC", mapStyle: "urban", createdAt: Date(), monthlyBudgetMinor: 800_000)
        let onTarget = space.progress(spentMinor: 200_000)
        XCTAssertTrue(onTarget.hasTarget)
        XCTAssertEqual(onTarget.remainingMinor, 600_000)
        XCTAssertEqual(onTarget.fraction ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertFalse(onTarget.isOverTarget)
    }

    /// Overspending is information the product needs, so it is reported rather than clamped.
    func testProgressKeepsOverspendingVisible() {
        let space = SharedSpace(id: UUID(), name: "x", currencyCode: "ILS",
                                timeZoneID: "UTC", mapStyle: "urban", createdAt: Date(), monthlyBudgetMinor: 800_000)
        let over = space.progress(spentMinor: 842_000)
        XCTAssertEqual(over.remainingMinor, -42_000)
        XCTAssertTrue(over.isOverTarget)
        XCTAssertEqual(over.fraction ?? 0, 1.0525, accuracy: 0.0001)
    }

    /// A space without a target reports nothing at all. Zero would read as a finished month.
    func testProgressWithoutTargetReportsNoNumbers() {
        let space = SharedSpace(id: UUID(), name: "x", currencyCode: "ILS",
                                timeZoneID: "UTC", mapStyle: "urban", createdAt: Date(), monthlyBudgetMinor: nil)
        let progress = space.progress(spentMinor: 200_000)
        XCTAssertFalse(progress.hasTarget)
        XCTAssertNil(progress.remainingMinor)
        XCTAssertNil(progress.fraction)
        XCTAssertFalse(progress.isOverTarget)
    }

    // MARK: - Create

    /// A bad target is rejected before any zone, record or member exists, so it costs the
    /// user nothing and cannot leave a half-built space behind.
    func testCreateRejectsNonPositiveTargetBeforeTouchingCloudKit() async {
        let store = SharedWorkspaceStore()
        for bad in [Int64(0), -1, -800_000] {
            do {
                try await store.create(name: "x", memberName: "y", currency: "ILS",
                                       mapStyle: "urban", monthlyBudgetMinor: bad)
                XCTFail("Target \(bad) should have been rejected")
            } catch {
                guard case SharedLedgerError.invalidAmount = error else {
                    return XCTFail("Expected invalidAmount for \(bad), got \(error)")
                }
            }
            XCTAssertNil(store.activeSpaceID, "A rejected target must not leave a space behind")
            XCTAssertTrue(store.spaces.isEmpty)
        }
    }

    // MARK: - Scope isolation

    /// Two spaces keep their own targets. A shared target is never a personal one, and
    /// never another space's.
    func testTargetsAreIndependentPerSpace() {
        func space(_ budget: Int64?) -> SharedSpace {
            SharedSpace(id: UUID(), name: "x", currencyCode: "ILS", timeZoneID: "UTC",
                        mapStyle: "urban", createdAt: Date(), monthlyBudgetMinor: budget)
        }
        let a = space(500_000), b = space(900_000), c = space(nil)
        XCTAssertEqual(a.monthlyBudgetMinor, 500_000)
        XCTAssertEqual(b.monthlyBudgetMinor, 900_000)
        XCTAssertNil(c.monthlyBudgetMinor)
        XCTAssertNotEqual(a.monthlyBudgetMinor, b.monthlyBudgetMinor)
    }

    /// The space's target is a field on the space. Nothing about it may be sourced from the
    /// personal budget, so the model must not grow a dependency on it.
    func testSharedTargetDoesNotReadPersonalBudget() {
        UserDefaults.standard.set(Double(1_234_567), forKey: "monthly_budget")
        defer { UserDefaults.standard.removeObject(forKey: "monthly_budget") }
        let space = SharedSpace(id: UUID(), name: "x", currencyCode: "ILS", timeZoneID: "UTC",
                                mapStyle: "urban", createdAt: Date(), monthlyBudgetMinor: 800_000)
        // The personal value is deliberately absurd. If it ever leaked in, the assertion fails.
        XCTAssertEqual(space.monthlyBudgetMinor, 800_000)
        XCTAssertEqual(space.progress(spentMinor: 0).remainingMinor, 800_000)
    }
}
#endif
