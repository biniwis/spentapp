import XCTest
@testable import MoneyCity

#if DEBUG && !SWIFT_PACKAGE
@MainActor
final class AppScopeTests: XCTestCase {
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

    func testColdLaunchDefaultsStrictlyToPersonal() {
        // Enforce constraint 6: Fresh/cold launch must always enter Personal
        XCTAssertEqual(scope.activeScope, .personal)
        XCTAssertFalse(scope.capabilities.isShared)
        XCTAssertTrue(scope.capabilities.hasBudget)
        XCTAssertTrue(scope.capabilities.hasSavings)
        XCTAssertTrue(scope.capabilities.hasRecurring)
        XCTAssertFalse(scope.capabilities.hasPayerSelection)
        XCTAssertFalse(scope.capabilities.hasMemberManagement)
    }

    func testScopeSwitchingUpdatesCapabilitiesCleanly() async throws {
        try await store.startDemo()
        let spaceID = try XCTUnwrap(store.activeSpaceID)

        XCTAssertEqual(scope.activeScope, .shared(spaceID: spaceID))
        XCTAssertTrue(scope.capabilities.isShared)
        XCTAssertFalse(scope.capabilities.hasBudget)
        XCTAssertFalse(scope.capabilities.hasSavings)
        XCTAssertFalse(scope.capabilities.hasRecurring)
        XCTAssertTrue(scope.capabilities.hasPayerSelection)
        XCTAssertTrue(scope.capabilities.hasMemberManagement)

        // Switch back to Personal
        scope.selectPersonal()
        XCTAssertEqual(scope.activeScope, .personal)
        XCTAssertFalse(scope.capabilities.isShared)
        XCTAssertTrue(scope.capabilities.hasBudget)
    }

    func testPersonalDataRemainsStrictlyIsolated() async throws {
        try await store.startDemo()
        let sharedID = try XCTUnwrap(store.activeSpaceID)
        let now = Date()
        let tx = Transaction(
            amount: 250,
            merchant: "Supermarket",
            category: .groceries,
            timestamp: now
        )

        // In Personal scope
        scope.selectPersonal()
        let personalExpenses = scope.expenses(for: now, personalTransactions: [tx])
        XCTAssertEqual(personalExpenses.count, 1)
        XCTAssertEqual(personalExpenses.first?.amount, 250)
        XCTAssertEqual(personalExpenses.first?.merchant, "Supermarket")

        // Switch to the in-memory shared ledger
        let dummySpaceID = sharedID
        scope.selectShared(spaceID: dummySpaceID)
        let sharedExpenses = scope.expenses(for: now, personalTransactions: [tx])

        // Personal transactions must NEVER leak into Shared
        XCTAssertFalse(sharedExpenses.isEmpty)
        XCTAssertFalse(sharedExpenses.contains { $0.id == tx.id })

        // Switch back to Personal - personal data restored immediately
        scope.selectPersonal()
        let restoredPersonal = scope.expenses(for: now, personalTransactions: [tx])
        XCTAssertEqual(restoredPersonal.count, 1)
        XCTAssertEqual(restoredPersonal.first?.amount, 250)
    }

    func testUnknownSpaceCannotChangeSelection() {
        scope.selectShared(spaceID: UUID())
        XCTAssertEqual(scope.activeScope, .personal)
        XCTAssertNil(store.activeSpaceID)
    }

    func testDerivedCacheResetOnScopeSwitch() {
        let cache = CityDerivedCache()
        let now = Date()
        let city = CitySimulationEngine.shared.generateCity(for: now, expenses: [])
        
        let cached = cache.city(key: 123) { city }
        XCTAssertEqual(cached.totalSpent, city.totalSpent)

        // Reset clears cached city calculations
        cache.reset()
        var calledNewBuild = false
        _ = cache.city(key: 123) {
            calledNewBuild = true
            return city
        }
        XCTAssertTrue(calledNewBuild, "Derived cache must invalidate its city upon reset so calculations never leak across scopes.")
    }
}

#endif
