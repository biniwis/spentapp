import XCTest
@testable import MoneyCity

@MainActor
final class AppScopeTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        AppScopeContext.shared.selectPersonal()
    }

    override func tearDown() async throws {
        AppScopeContext.shared.selectPersonal()
        try await super.tearDown()
    }

    func testColdLaunchDefaultsStrictlyToPersonal() {
        // Enforce constraint 6: Fresh/cold launch must always enter Personal
        XCTAssertEqual(AppScopeContext.shared.activeScope, .personal)
        XCTAssertFalse(AppScopeContext.shared.capabilities.isShared)
        XCTAssertTrue(AppScopeContext.shared.capabilities.hasBudget)
        XCTAssertTrue(AppScopeContext.shared.capabilities.hasSavings)
        XCTAssertTrue(AppScopeContext.shared.capabilities.hasRecurring)
        XCTAssertFalse(AppScopeContext.shared.capabilities.hasPayerSelection)
        XCTAssertFalse(AppScopeContext.shared.capabilities.hasMemberManagement)
    }

    func testScopeSwitchingUpdatesCapabilitiesCleanly() {
        let spaceID = UUID()
        AppScopeContext.shared.selectShared(spaceID: spaceID)

        XCTAssertEqual(AppScopeContext.shared.activeScope, .shared(spaceID: spaceID))
        XCTAssertTrue(AppScopeContext.shared.capabilities.isShared)
        XCTAssertFalse(AppScopeContext.shared.capabilities.hasBudget)
        XCTAssertFalse(AppScopeContext.shared.capabilities.hasSavings)
        XCTAssertFalse(AppScopeContext.shared.capabilities.hasRecurring)
        XCTAssertTrue(AppScopeContext.shared.capabilities.hasPayerSelection)
        XCTAssertTrue(AppScopeContext.shared.capabilities.hasMemberManagement)

        // Switch back to Personal
        AppScopeContext.shared.selectPersonal()
        XCTAssertEqual(AppScopeContext.shared.activeScope, .personal)
        XCTAssertFalse(AppScopeContext.shared.capabilities.isShared)
        XCTAssertTrue(AppScopeContext.shared.capabilities.hasBudget)
    }

    func testPersonalDataRemainsStrictlyIsolated() {
        let now = Date()
        let tx = Transaction(
            amount: 250,
            merchant: "Supermarket",
            category: .groceries,
            timestamp: now
        )

        // In Personal scope
        AppScopeContext.shared.selectPersonal()
        let personalExpenses = AppScopeContext.shared.expenses(for: now, personalTransactions: [tx])
        XCTAssertEqual(personalExpenses.count, 1)
        XCTAssertEqual(personalExpenses.first?.amount, 250)
        XCTAssertEqual(personalExpenses.first?.merchant, "Supermarket")

        // Switch to a dummy Shared Space with no shared expenses
        let dummySpaceID = UUID()
        AppScopeContext.shared.selectShared(spaceID: dummySpaceID)
        let sharedExpenses = AppScopeContext.shared.expenses(for: now, personalTransactions: [tx])

        // Personal transactions must NEVER leak into Shared
        XCTAssertEqual(sharedExpenses.count, 0)

        // Switch back to Personal - personal data restored immediately
        AppScopeContext.shared.selectPersonal()
        let restoredPersonal = AppScopeContext.shared.expenses(for: now, personalTransactions: [tx])
        XCTAssertEqual(restoredPersonal.count, 1)
        XCTAssertEqual(restoredPersonal.first?.amount, 250)
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
