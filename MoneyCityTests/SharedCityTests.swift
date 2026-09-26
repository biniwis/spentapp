import XCTest
@testable import MoneyCity

/// Covers the shared month's reading of its own target: what the park says about the month,
/// and that a space without a target is reported as unmeasured rather than as a month that
/// passed. Pure values only, so none of this needs CloudKit or a signed-in account.
final class SharedCityTests: XCTestCase {

    // MARK: - Tiers

    func testTierBoundariesLandWhereTheProductSaysTheyDo() {
        XCTAssertEqual(SharedParkTier(fraction: 0), .early)
        XCTAssertEqual(SharedParkTier(fraction: 0.249), .early)
        XCTAssertEqual(SharedParkTier(fraction: 0.25), .comfortable)
        XCTAssertEqual(SharedParkTier(fraction: 0.499), .comfortable)
        XCTAssertEqual(SharedParkTier(fraction: 0.5), .even)
        XCTAssertEqual(SharedParkTier(fraction: 0.749), .even)
        XCTAssertEqual(SharedParkTier(fraction: 0.75), .close)
        XCTAssertEqual(SharedParkTier(fraction: 1.0), .close)
        XCTAssertEqual(SharedParkTier(fraction: 1.0001), .over)
    }

    func testNoTargetIsItsOwnTierAndNotAnEarlyMonth() {
        XCTAssertEqual(SharedParkTier(fraction: nil), .noTarget)
        XCTAssertEqual(SharedParkState(fraction: nil).tier, .noTarget)
        XCTAssertNil(SharedParkState(fraction: nil).parkHealth,
                     "A space with no target has no health to render. Zero would read as a perfect month.")
    }

    // MARK: - Health

    func testUnusedTargetOpensCalmAndTheTargetItselfSitsInTheActiveBand() {
        // The renderer's bands: >= 0.90 calm, >= 0.65 balanced, >= 0.38 active, below that busy.
        let untouched = SharedParkState(fraction: 0).parkHealth
        let half = SharedParkState(fraction: 0.5).parkHealth
        let onTarget = SharedParkState(fraction: 1.0).parkHealth
        XCTAssertEqual(untouched, 0.95)
        XCTAssertEqual(untouched ?? 0, 0.95, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(untouched ?? 0, 0.90)
        XCTAssertGreaterThanOrEqual(half ?? 0, 0.65)
        XCTAssertLessThan(half ?? 0, 0.90)
        XCTAssertGreaterThanOrEqual(onTarget ?? 0, 0.38)
        XCTAssertLessThan(onTarget ?? 0, 0.65)
    }

    func testGoingOverTheTargetThinsTheParkButNeverKillsIt() {
        let over = SharedParkState(fraction: 1.2).parkHealth ?? 0
        let farOver = SharedParkState(fraction: 9.0).parkHealth ?? 0
        XCTAssertLessThan(over, SharedParkState(fraction: 1.0).parkHealth ?? 0)
        XCTAssertLessThan(farOver, 0.38, "Past the target is a visible state, not a dead one")
        XCTAssertGreaterThan(farOver, 0, "The park must never be rendered as gone")
    }

    func testFractionIsNeverNegativeEvenWhenRefundsOutrunSpending() {
        let state = SharedParkState(fraction: -0.4)
        XCTAssertEqual(state.fraction, 0)
        XCTAssertEqual(state.tier, .early)
    }

    func testNonFiniteFractionIsTreatedAsNoTarget() {
        XCTAssertEqual(SharedParkState(fraction: .nan).tier, .noTarget)
        XCTAssertEqual(SharedParkState(fraction: .infinity).tier, .noTarget)
    }

    func testStateFollowsTheMonthItIsGivenAndNothingAccumulates() {
        // Same month, same reading. The ratio is not a running total, so a mid-month refresh
        // and a month-end refresh of the same ledger cannot drift apart.
        let first = SharedParkState(fraction: 0.6)
        let second = SharedParkState(fraction: 0.6)
        XCTAssertEqual(first, second)
        XCTAssertEqual(SharedParkState(fraction: 0.9), SharedParkState(fraction: 0.9))
        XCTAssertNotEqual(SharedParkState(fraction: 0.9), SharedParkState(fraction: 0.91))
    }

    // MARK: - Target conversion

    private func makeContext(targetMinor: Int64?,
                             currency: String = "ILS",
                             spentMinor: Int64 = 0) -> SharedCityContext {
        SharedCityContext(spaceID: UUID(),
                          currencyCode: currency,
                          mapStyle: "classic",
                          monthlyTargetMinor: targetMinor,
                          monthlySpentMinor: spentMinor,
                          park: SharedParkState(fraction: targetMinor.map { Double(spentMinor) / Double($0) }),
                          members: [])
    }

    func testTargetIsConvertedInTheSpacesOwnCurrency() {
        XCTAssertEqual(makeContext(targetMinor: 8_000, currency: "ILS").monthlyTargetMajor, 80)
        XCTAssertEqual(makeContext(targetMinor: 500, currency: "JPY").monthlyTargetMajor, 500,
                       "A zero-decimal currency has no minor unit to divide by")
        XCTAssertEqual(makeContext(targetMinor: 1_250, currency: "USD").monthlyTargetMajor, 12.5)
    }

    func testNoTargetStaysAbsentRatherThanBecomingZero() {
        XCTAssertNil(makeContext(targetMinor: nil).monthlyTargetMajor)
        XCTAssertNil(makeContext(targetMinor: 0).monthlyTargetMajor)
        XCTAssertNil(makeContext(targetMinor: -500).monthlyTargetMajor)
    }

    func testParkFollowsTheMonthsOwnUtilization() {
        let context = makeContext(targetMinor: 1_000, spentMinor: 1_000)
        XCTAssertEqual(context.park.tier, .close, "Spending exactly the target is still within it")
        XCTAssertEqual(context.monthlySpentMinor, 1_000)
    }

    func testNoTargetAsksTheRendererForANeutralParkAndSendsNoNumber() {
        let unmeasured = makeContext(targetMinor: nil)
        XCTAssertEqual(unmeasured.park.rendererMode, .neutral)
        XCTAssertNil(unmeasured.park.parkHealth, "No health may be invented for an unmeasured month")
        XCTAssertNil(unmeasured.monthlyTargetMajor)

        let measured = makeContext(targetMinor: 1_000, spentMinor: 400)
        XCTAssertNil(measured.park.rendererMode, "A month with a target keeps the renderer's own graded path")
        XCTAssertNotNil(measured.park.parkHealth)
    }

    func testPersonalCityNeverCarriesAParkMode() {
        // The personal city is built by the engine and never sets a mode, so every renderer
        // path it uses is byte-for-byte the one it used before.
        let personal = MonthlyCity(monthDate: Date(), totalSpent: 100, totalSavings: 0)
        XCTAssertNil(personal.parkMode)
        XCTAssertEqual(personal.parkHealth, CitySimulationEngine.healthyParkLevel)
    }
}

// MARK: - Member accents

/// Who is drawn on which building, and what it takes for a member to be drawn at all.
extension SharedCityTests {

    private func makeMemberTotal(id: String, name: String = "m", color: String = "#7C5CFF",
                                 minor: Int64 = 0) -> SharedMemberTotal {
        SharedMemberTotal(memberID: id, name: name, colorHex: color, amountMinor: minor)
    }

    private func makeExpense(minor: Double, venue: String, paidBy: String?,
                             unresolved: Bool = false) -> ExpenseSnapshot {
        ExpenseSnapshot(id: UUID(), amount: minor, merchant: "T", category: .food,
                        timestamp: Date(), buildingId: venue,
                        isUnresolvedForeign: unresolved, paidBy: paidBy, note: "")
    }

    private func venue(_ id: String) -> CityVenueState {
        CityVenueState(id: id, amount: 0, share: 0, purchaseCount: 0, activeDays: 0,
                       merchantCount: 0, activity: 0, presence: 0, additionalPlaces: 0)
    }

    private func shares(_ venues: [CityVenueState], _ id: String) -> [CityMemberShare]? {
        venues.first { $0.id == id }?.memberShares
    }

    func testTwoMembersAreDrawnAsSharesOfWhatTheyActuallyPaid() {
        let members = [makeMemberTotal(id: "a", color: "#FF6446"), makeMemberTotal(id: "b", color: "#7C5CFF")]
        let expenses = [makeExpense(minor: 300, venue: "food_bistro", paidBy: "a"),
                        makeExpense(minor: 100, venue: "food_bistro", paidBy: "b")]
        let result = SharedCityMemberShares.applying(to: [venue("food_bistro")], members: members, expenses: expenses)
        let drawn = try? XCTUnwrap(shares(result, "food_bistro"))
        XCTAssertEqual(drawn?.count, 2)
        XCTAssertEqual(drawn?.first(where: { $0.memberID == "a" })?.share ?? 0, 0.75, accuracy: 0.0001)
        XCTAssertEqual(drawn?.first(where: { $0.memberID == "b" })?.share ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertEqual(drawn?.reduce(0) { $0 + $1.share } ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(drawn?.first(where: { $0.memberID == "a" })?.color, "#FF6446",
                       "A member is drawn in their own colour, as an accent on a shared building")
    }

    func testRefundComesOffWhoeverPaidIt() {
        let members = [makeMemberTotal(id: "a"), makeMemberTotal(id: "b")]
        let expenses = [makeExpense(minor: 500, venue: "food_bistro", paidBy: "a"),
                        makeExpense(minor: -200, venue: "food_bistro", paidBy: "a"),
                        makeExpense(minor: 100, venue: "food_bistro", paidBy: "b")]
        let result = SharedCityMemberShares.applying(to: [venue("food_bistro")], members: members, expenses: expenses)
        let drawn = try? XCTUnwrap(shares(result, "food_bistro"))
        XCTAssertEqual(drawn?.first(where: { $0.memberID == "a" })?.share ?? 0, 300.0 / 400.0, accuracy: 0.0001)
        XCTAssertEqual(drawn?.first(where: { $0.memberID == "b" })?.share ?? 0, 0.25, accuracy: 0.0001)
    }

    func testMemberRefundedPastWhatTheyPaidIsNotDrawnAtAll() {
        let members = [makeMemberTotal(id: "a"), makeMemberTotal(id: "b")]
        let expenses = [makeExpense(minor: 100, venue: "food_bistro", paidBy: "a"),
                        makeExpense(minor: -400, venue: "food_bistro", paidBy: "a"),
                        makeExpense(minor: 250, venue: "food_bistro", paidBy: "b")]
        let result = SharedCityMemberShares.applying(to: [venue("food_bistro")], members: members, expenses: expenses)
        let drawn = try? XCTUnwrap(shares(result, "food_bistro"))
        XCTAssertEqual(drawn?.count, 1, "A negative net is not a small contribution and not a colour")
        XCTAssertEqual(drawn?.first?.memberID, "b")
        XCTAssertEqual(drawn?.first?.share ?? 0, 1, accuracy: 0.0001,
                       "What is left of the month belongs to whoever is still in it")
    }

    func testUnresolvedForeignMoneyNeverReachesTheWeights() {
        let members = [makeMemberTotal(id: "a"), makeMemberTotal(id: "b")]
        let expenses = [makeExpense(minor: 100, venue: "food_bistro", paidBy: "a"),
                        makeExpense(minor: 900, venue: "food_bistro", paidBy: "b", unresolved: true)]
        let result = SharedCityMemberShares.applying(to: [venue("food_bistro")], members: members, expenses: expenses)
        let drawn = try? XCTUnwrap(shares(result, "food_bistro"))
        XCTAssertEqual(drawn?.count, 1)
        XCTAssertEqual(drawn?.first?.memberID, "a", "A record with no honest value in the space's currency draws nothing")
    }

    func testAVenueWithNoPositiveContributionsGetsNoMemberColours() {
        let members = [makeMemberTotal(id: "a"), makeMemberTotal(id: "b")]
        let expenses = [makeExpense(minor: -100, venue: "food_bistro", paidBy: "a"),
                        makeExpense(minor: -250, venue: "food_bistro", paidBy: "b")]
        let result = SharedCityMemberShares.applying(to: [venue("food_bistro")], members: members, expenses: expenses)
        XCTAssertNil(shares(result, "food_bistro"), "A share of nothing is not a share")
    }

    func testNoMembersMeansNoColoursAndNoCrash() {
        let expenses = [makeExpense(minor: 100, venue: "food_bistro", paidBy: "a")]
        let result = SharedCityMemberShares.applying(to: [venue("food_bistro")], members: [], expenses: expenses)
        XCTAssertNil(shares(result, "food_bistro"))
    }

    func testUnknownPayerIsIgnoredRatherThanInvented() {
        let members = [makeMemberTotal(id: "a")]
        let expenses = [makeExpense(minor: 100, venue: "food_bistro", paidBy: "someone-else"),
                        makeExpense(minor: 40, venue: "food_bistro", paidBy: nil),
                        makeExpense(minor: 60, venue: "food_bistro", paidBy: "a")]
        let result = SharedCityMemberShares.applying(to: [venue("food_bistro")], members: members, expenses: expenses)
        let drawn = try? XCTUnwrap(shares(result, "food_bistro"))
        XCTAssertEqual(drawn?.count, 1)
        XCTAssertEqual(drawn?.first?.memberID, "a")
        XCTAssertEqual(drawn?.first?.share ?? 0, 1, accuracy: 0.0001)
    }

}

// MARK: - Scope

/// What happens to the city's reading of a month when the scope changes underneath it.
/// Backed by a real offline store, because a scope switch is a store question, not a pure
/// one — the failure this guards against is one space's numbers surviving into another's.
@MainActor
final class SharedCityScopeTests: XCTestCase {
    private var store: SharedWorkspaceStore!
    private var scope: AppScopeContext!

    override func setUp() async throws {
        try await super.setUp()
        store = SharedWorkspaceStore()
        scope = AppScopeContext(store: store)
    }

    override func tearDown() async throws {
        scope = nil
        store = nil
        try await super.tearDown()
    }

    func testPersonalScopeHasNoSharedCityAtAll() {
        XCTAssertNil(scope.sharedCityContext(for: Date()),
                     "The personal city is not a shared city with the numbers left off")
    }

    func testSharedSpaceIsReadFromTheSpaceNotThePersonalSelection() async throws {
        try await store.startDemo()
        let context = try XCTUnwrap(scope.sharedCityContext(for: Date()))
        let space = try XCTUnwrap(store.activeSpace)
        XCTAssertEqual(context.spaceID, space.id)
        XCTAssertEqual(context.mapStyle, space.mapStyle,
                       "The world comes from the space, never from the personal map choice")
    }

    func testSharedMapStyleIsTheSpacesOwnNotThePersonalSelection() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SharedCityScopeTestsMapStyle"))
        defer { defaults.removePersistentDomain(forName: "SharedCityScopeTestsMapStyle") }
        defaults.set(CityMapStyle.israel.rawValue, forKey: CityMapSelection.preferenceKey)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: defaults), .israel,
                       "Sanity: the personal selection really is a different world")

        try await store.startDemo()
        let space = try XCTUnwrap(store.activeSpace)
        let context = try XCTUnwrap(scope.sharedCityContext(for: Date()))
        XCTAssertEqual(context.mapStyle, space.mapStyle)
        XCTAssertNotEqual(context.mapStyle, CityMapSelection.currentStyle(defaults: defaults).rawValue,
                          "Choosing a personal world must not change what a shared space looks like")
        XCTAssertEqual(CityMapStyle(rawValue: context.mapStyle), .urban, "The space's own world, not the personal one")
    }

    func testTargetAndParkFollowTheSpaceAfterSwitchingBackAndForth() async throws {
        try await store.startDemo()
        let spaceID = try XCTUnwrap(store.activeSpaceID)
        let before = try XCTUnwrap(scope.sharedCityContext(for: Date()))

        scope.selectPersonal()
        XCTAssertNil(scope.sharedCityContext(for: Date()),
                     "Going back to Personal leaves no shared target, park or world behind")
        XCTAssertEqual(scope.activeScope, .personal)

        scope.selectShared(spaceID: spaceID)
        let after = try XCTUnwrap(scope.sharedCityContext(for: Date()))
        XCTAssertEqual(after, before, "The same space read again is the same city, whatever came before it")
    }

    func testSwitchingToASpaceWithNoTargetNeutralisesTheParkInsteadOfBorrowingOne() async throws {
        try await store.startDemo()
        let spaceID = try XCTUnwrap(store.activeSpaceID)
        let measured = try XCTUnwrap(scope.sharedCityContext(for: Date()))
        XCTAssertNotNil(measured.park.parkHealth, "The demo space sets a target, so it is measured")
        XCTAssertNil(measured.park.rendererMode)

        try store.setMonthlyBudget(nil, for: spaceID)
        let unmeasured = try XCTUnwrap(scope.sharedCityContext(for: Date()))
        XCTAssertNil(unmeasured.park.parkHealth)
        XCTAssertEqual(unmeasured.park.rendererMode, .neutral)
        XCTAssertNil(unmeasured.monthlyTargetMajor, "The old target is gone with the setting, not remembered")
    }
}

// MARK: - A member who left mid-month

/// The one case the Phase 5 report has to answer honestly: somebody paid, then left the
/// space. Pure, because that is exactly what the summary and the weights are given.
extension SharedCityTests {

    private func makeSharedSpace(id: UUID = UUID(), targetMinor: Int64? = 10_000) -> SharedSpace {
        SharedSpace(id: id, name: "s", currencyCode: "ILS", timeZoneID: "Asia/Jerusalem",
                    mapStyle: "urban", createdAt: Date(), monthlyBudgetMinor: targetMinor)
    }

    private func makeSharedExpense(spaceID: UUID, minor: Int64, venue: String, paidBy: String) -> SharedExpense {
        SharedExpense(id: UUID(), spaceID: spaceID, amountMinor: minor, currencyCode: "ILS",
                      merchant: "T", category: .food, buildingID: venue, date: Date(), note: "",
                      paidBy: paidBy, createdBy: paidBy, updatedBy: paidBy)
    }

    func testAMemberWhoLeftMidMonthKeepsTheirColourInTheCity() {
        let space = makeSharedSpace()
        // The ledger, exactly as the store holds it, and the city reading of it.
        let records = [makeSharedExpense(spaceID: space.id, minor: 100_00, venue: "food_bistro", paidBy: "a"),
                       makeSharedExpense(spaceID: space.id, minor: 1_000_00, venue: "food_bistro", paidBy: "b")]
        let snapshots = records.map(ExpenseSnapshot.init)
        let members = [SharedMember(id: "a", spaceID: space.id, name: "A", colorHex: "#FF6446", isActive: true),
                       SharedMember(id: "b", spaceID: space.id, name: "מאיה", colorHex: "#7C5CFF", isActive: false)]

        let summary = SharedMonthlySummary.month(of: space, expenses: records, members: members, now: Date())
        XCTAssertEqual(summary.memberTotals.map(\.memberID), ["a", "b"],
                       "A member who paid and then left is still a participant of that month")
        XCTAssertEqual(summary.memberTotals.first { $0.memberID == "b" }?.colorHex, "#7C5CFF")

        let city = CitySimulationEngine.shared.generateCity(for: Date(), expenses: snapshots)
        XCTAssertEqual(city.buildingTotals["food_bistro"] ?? 0, 1_100, accuracy: 0.001)

        let drawn = shares(SharedCityMemberShares.applying(to: city.venueStates,
                                                            members: summary.memberTotals,
                                                            expenses: snapshots), "food_bistro")
        XCTAssertEqual(drawn?.count, 2, "Both of them are drawn, in their own colours")
        XCTAssertEqual(drawn?.first(where: { $0.memberID == "a" })?.color, "#FF6446")
        XCTAssertEqual(drawn?.first(where: { $0.memberID == "b" })?.color, "#7C5CFF")
        XCTAssertEqual(drawn?.first(where: { $0.memberID == "b" })?.share ?? 0, 1_000.0 / 1_100.0, accuracy: 0.0001,
                       "And in the proportion they actually paid")
    }

    func testAnInactiveMembersSpendingStaysAttributedToThem() {
        let space = makeSharedSpace()
        let stillHere = [SharedMember(id: "a", spaceID: space.id, name: "a", colorHex: "#111111", isActive: true),
                         SharedMember(id: "b", spaceID: space.id, name: "b", colorHex: "#222222", isActive: true)]
        let afterLeaving = stillHere + [SharedMember(id: "c", spaceID: space.id, name: "c", colorHex: "#333333", isActive: false)]
        let expenses = [makeSharedExpense(spaceID: space.id, minor: 1_000, venue: "food_bistro", paidBy: "a"),
                        makeSharedExpense(spaceID: space.id, minor: 900, venue: "food_bistro", paidBy: "c")]

        let before = SharedMonthlySummary.month(of: space, expenses: expenses, members: stillHere, now: Date())
        XCTAssertEqual(before.unattributedMinor, 900)

        let after = SharedMonthlySummary.month(of: space, expenses: expenses, members: afterLeaving, now: Date())
        XCTAssertEqual(after.spentMinor, before.spentMinor, "The month does not change when a member leaves")
        XCTAssertEqual(after.unattributedMinor, 0, "Their money is still theirs")
        XCTAssertEqual(after.memberTotals.map(\.memberID), ["a", "b", "c"])
        XCTAssertEqual(after.memberTotals.first { $0.memberID == "c" }?.amountMinor, 900)
        XCTAssertTrue(after.canShowMemberShares,
                      "One person leaving mid-month must not turn the member breakdown off for everybody")
    }
}
