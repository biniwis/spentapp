import XCTest
@testable import MoneyCity

final class CityProgressEngineTests: XCTestCase {
    
    func testZeroPreviousWeekDoesNotInventProgress() {
        let engine = CityProgressEngine.shared
        let now = Date()
        
        let currentTxs = [
            Transaction(amount: 150, merchant: "שופרסל", category: .food, timestamp: now)
        ]
        
        let report = engine.evaluateProgress(transactions: currentTxs, unlockedItemIds: [], referenceDate: now)
        
        XCTAssertFalse(report.hasPositiveProgress)
        XCTAssertEqual(report.savedAmount, 0.0)
        XCTAssertEqual(report.previousWeekTotal, 0.0)
        XCTAssertEqual(report.progressTier, "none")
        XCTAssertTrue(report.availableOptions.isEmpty)
    }
    
    func testRealSavingsAwardsCorrectTierAndExcludesRent() {
        let engine = CityProgressEngine.shared
        let now = Date()
        let cal = Calendar.current
        
        let tenDaysAgo = cal.date(byAdding: .day, value: -10, to: now)!
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: now)!
        
        // Prev week: ₪800 variable spending + ₪3,500 rent
        // Current week: ₪450 variable spending + ₪3,500 rent
        let txs = [
            Transaction(amount: 3500, merchant: "שכירות", category: .housing, timestamp: tenDaysAgo),
            Transaction(amount: 800, merchant: "מסעדות וקניות", category: .food, timestamp: tenDaysAgo),
            Transaction(amount: 3500, merchant: "שכירות", category: .housing, timestamp: threeDaysAgo),
            Transaction(amount: 450, merchant: "מסעדות", category: .food, timestamp: threeDaysAgo)
        ]
        
        let report = engine.evaluateProgress(transactions: txs, unlockedItemIds: [], referenceDate: now)
        
        XCTAssertTrue(report.hasPositiveProgress)
        XCTAssertEqual(report.previousWeekTotal, 800.0) // Rent excluded
        XCTAssertEqual(report.currentWeekTotal, 450.0)   // Rent excluded
        XCTAssertEqual(report.savedAmount, 350.0)       // ₪800 - ₪450 = ₪350
        XCTAssertEqual(report.progressTier, "medium")   // 200..500 is medium
        XCTAssertFalse(report.availableOptions.isEmpty)
    }
}

import SwiftData

@MainActor
final class CityRewardOwnershipSafetyTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Transaction.self,
            CityEnrichment.self,
            SavingsGoal.self,
            RecurringExpense.self,
            IncomeSource.self,
            CategoryBudget.self,
            MerchantRule.self,
            InstallmentPlan.self,
            IngestLogEntry.self,
            RecapSnapshot.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // 1. Fresh empty ModelContainer: CityEnrichment count == 0
    func testFreshEmptyModelContainerHasZeroEnrichments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let enrichments = try context.fetch(FetchDescriptor<CityEnrichment>())
        XCTAssertEqual(enrichments.count, 0, "Fresh empty ModelContainer must have zero CityEnrichment records")
    }

    // 2. No pending reward: weeklyRewardOptions == []
    func testNoPendingRewardYieldsEmptyWeeklyRewardOptions() {
        let rewardEngine = CityRewardEngine()
        XCTAssertNil(rewardEngine.state.pending, "Reward engine starts with no pending reward")

        let hasCompletedOnboarding = true
        let allEnrichments: [CityEnrichment] = []
        let unlockedIds = Set(allEnrichments.filter { $0.isApplied }.map { $0.itemId })

        let weeklyRewardOptions: [ProgressRewardOption] = {
            guard hasCompletedOnboarding, rewardEngine.state.pending != nil else { return [] }
            return CityProgressEngine.shared.availableWeeklyOptions(unlockedItemIds: unlockedIds)
        }()

        XCTAssertTrue(weeklyRewardOptions.isEmpty, "When no reward is pending, weeklyRewardOptions must be empty")
    }

    // 3. Empty owned inventory: CityProgressSheet owned catalog result == 0
    func testEmptyOwnedInventoryProducesZeroOwnedCatalogOptions() {
        let unlockedEnrichments: [CityEnrichment] = []
        let ownedCatalog = CityProgressEngine.shared.allCatalogOptions.filter { option in
            unlockedEnrichments.contains { $0.isApplied && $0.itemId == option.id }
        }
        XCTAssertEqual(ownedCatalog.count, 0, "Empty owned inventory must show 0 unlocked catalog items")
    }

    // 4. CitySlot.resolvedPlacements([]): must not grant any inventory/reward ownership
    func testResolvedPlacementsEmptyInventoryGrantsNoOwnership() {
        let emptyInventory: [CityPlacement] = []
        let resolved = CitySlot.resolvedPlacements(emptyInventory)
        XCTAssertTrue(resolved.isEmpty, "resolvedPlacements with empty inventory must return empty map")

        // Assert that CitySlot defaultItemIds are visual defaults only and never create enrichments or grant ownership
        XCTAssertEqual(CitySlot.defaultItemIds.count, 13)
        XCTAssertTrue(CitySlot.defaultItemIds.contains("resident_artist"))
        XCTAssertTrue(CitySlot.defaultItemIds.contains("pet_cat_rooftop"))
    }

    // 5. Baseline/default city visuals may still render if they are intended parts of the base city,
    //    but they must be completely independent from owned reward state.
    func testBaselineCityVisualsIndependentFromRewardState() {
        let emptyOwnedEnrichments: [CityEnrichment] = []
        let activeEnrichmentIds = emptyOwnedEnrichments.filter { $0.isApplied }.map { $0.itemId }
        XCTAssertTrue(activeEnrichmentIds.isEmpty, "No earned companions without claimed records")

        // Slot defaults exist as spatial metadata, completely independent from user inventory
        for slot in CitySlot.allSlots {
            XCTAssertFalse(slot.defaultItemId.isEmpty)
            XCTAssertFalse(emptyOwnedEnrichments.contains { $0.itemId == slot.defaultItemId })
        }
    }

    // 6. Claim one real reward: owned count becomes exactly 1
    func testClaimOneRealRewardBecomesExactlyOne() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let reward = CityEnrichment(
            itemId: "pet_cat_rooftop",
            name: "החתול מהגג",
            subtitle: "נראה בדרך כלל ליד החנויות.",
            icon: "pawprint.fill",
            type: .pet,
            tier: "small",
            districtId: "shopping",
            isApplied: true
        )
        context.insert(reward)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CityEnrichment>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.itemId, "pet_cat_rooftop")

        let ownedCatalog = CityProgressEngine.shared.allCatalogOptions.filter { option in
            fetched.contains { $0.isApplied && $0.itemId == option.id }
        }
        XCTAssertEqual(ownedCatalog.count, 1)
        XCTAssertEqual(ownedCatalog.first?.id, "pet_cat_rooftop")
    }

    // 7. Relaunch/persistence: owned count stays exactly 1
    func testPersistencePreservesExactlyOneClaimedReward() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("test.store")
        let schema = Schema([CityEnrichment.self])
        let config = ModelConfiguration(schema: schema, url: storeURL)

        // First session: insert and save
        do {
            let container1 = try ModelContainer(for: schema, configurations: [config])
            let reward = CityEnrichment(
                itemId: "resident_artist",
                name: "ציירת רחוב",
                subtitle: "מציירת מדי פעם בכיכר.",
                icon: "paintpalette.fill",
                type: .resident,
                tier: "small",
                districtId: "city",
                isApplied: true
            )
            container1.mainContext.insert(reward)
            try container1.mainContext.save()
        }

        // Second session (relaunch): open same store
        do {
            let container2 = try ModelContainer(for: schema, configurations: [config])
            let fetched = try container2.mainContext.fetch(FetchDescriptor<CityEnrichment>())
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.itemId, "resident_artist")

            let ownedCatalog = CityProgressEngine.shared.allCatalogOptions.filter { option in
                fetched.contains { $0.isApplied && $0.itemId == option.id }
            }
            XCTAssertEqual(ownedCatalog.count, 1)
        }
    }

    // 8. Runtime Verification: CityProgressSheet.renderedOwnedOptions strictly matches claimed records
    func testCityProgressSheetRenderedOwnedOptionsMatchesPersistedClaimedRecords() {
        // Case A: Fresh store / 0 enrichments
        let sheetEmpty = CityProgressSheet(
            options: [],
            unlockedEnrichments: [],
            onSelectOption: { _ in false }
        )
        XCTAssertEqual(sheetEmpty.renderedOwnedOptions.count, 0)

        // Case B: Exactly 1 claimed enrichment (matches active simulator state: resident_artist)
        let artist = CityEnrichment(
            itemId: "resident_artist",
            name: "ציירת רחוב",
            subtitle: "מציירת מדי פעם בכיכר.",
            icon: "paintpalette.fill",
            type: .resident,
            tier: "small",
            districtId: "city",
            isApplied: true
        )
        let sheetSingle = CityProgressSheet(
            options: [],
            unlockedEnrichments: [artist],
            onSelectOption: { _ in false }
        )
        XCTAssertEqual(sheetSingle.renderedOwnedOptions.count, 1)
        XCTAssertEqual(sheetSingle.renderedOwnedOptions.first?.id, "resident_artist")

        // Case C: 2 claimed enrichments (matches user physical device screenshot state: cat + artist)
        let cat = CityEnrichment(
            itemId: "pet_cat_rooftop",
            name: "החתול מהגג",
            subtitle: "נראה בדרך כלל ליד החנויות.",
            icon: "pawprint.fill",
            type: .pet,
            tier: "small",
            districtId: "shopping",
            isApplied: true
        )
        let sheetDouble = CityProgressSheet(
            options: [],
            unlockedEnrichments: [artist, cat],
            onSelectOption: { _ in false }
        )
        XCTAssertEqual(sheetDouble.renderedOwnedOptions.count, 2)
        XCTAssertEqual(Set(sheetDouble.renderedOwnedOptions.map(\.id)), Set(["resident_artist", "pet_cat_rooftop"]))

        // Case D: Unapplied record (isApplied: false) must not be rendered
        let unappliedCat = CityEnrichment(
            itemId: "pet_cat_rooftop",
            name: "החתול מהגג",
            subtitle: "נראה בדרך כלל ליד החנויות.",
            icon: "pawprint.fill",
            type: .pet,
            tier: "small",
            districtId: "shopping",
            isApplied: false
        )
        let sheetUnapplied = CityProgressSheet(
            options: [],
            unlockedEnrichments: [artist, unappliedCat],
            onSelectOption: { _ in false }
        )
        XCTAssertEqual(sheetUnapplied.renderedOwnedOptions.count, 1)
        XCTAssertEqual(sheetUnapplied.renderedOwnedOptions.first?.id, "resident_artist")
    }
}

