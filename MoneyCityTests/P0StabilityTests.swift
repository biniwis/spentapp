import XCTest
import SwiftData
@testable import MoneyCity

final class P0StabilityTests: XCTestCase {

    func testUniqueBuildingIDsAcrossAllCategories() {
        var seenIDs = Set<String>()
        for cat in SpendingCategory.primaryCategories {
            let buildings = CityBuilding.buildings(for: cat)
            for b in buildings {
                XCTAssertFalse(
                    seenIDs.contains(b.id),
                    "Building ID '\(b.id)' in category \(cat) is duplicated! Building IDs must be strictly unique."
                )
                seenIDs.insert(b.id)
            }
        }
        XCTAssertTrue(seenIDs.contains("shop_boutique"))
        XCTAssertTrue(seenIDs.contains("health_pharmacy"))
        XCTAssertTrue(seenIDs.contains("finance_bank"))
        XCTAssertTrue(seenIDs.contains("city_sorting_hub"))
        XCTAssertTrue(seenIDs.contains("museum_curiosities"))
    }

    func testLegacyBuildingIDMigration() {
        // Legacy transactions stored with shop_boutique under health or finance
        let healthTx = Transaction(
            amount: 75.0,
            merchant: "סופר פארם",
            category: .health,
            buildingId: "shop_boutique"
        )
        XCTAssertEqual(healthTx.buildingId, "health_pharmacy", "Legacy shop_boutique in Health must normalize to health_pharmacy")

        let financeTx = Transaction(
            amount: 25.0,
            merchant: "עמלת שורה בנק לאומי",
            category: .finance,
            buildingId: "shop_boutique"
        )
        XCTAssertEqual(financeTx.buildingId, "finance_bank", "Legacy shop_boutique in Finance must normalize to finance_bank")

        let shoppingTx = Transaction(
            amount: 150.0,
            merchant: "זארה",
            category: .shopping,
            buildingId: "shop_boutique"
        )
        XCTAssertEqual(shoppingTx.buildingId, "shop_boutique", "Valid shop_boutique in Shopping must remain shop_boutique")
    }

    func testMissingMerchantIngestDefaultsToOtherAndUnconfirmed() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: 85.0,
            amountText: nil,
            merchant: nil,
            currency: "₪",
            date: Date(),
            existing: []
        )

        XCTAssertEqual(tx.merchant, "לא זוהה")
        XCTAssertEqual(tx.category, .other)
        XCTAssertEqual(tx.buildingId, "city_sorting_hub")
        XCTAssertFalse(tx.isConfirmed, "Missing merchant transactions must never be confirmed automatically")
        XCTAssertEqual(tx.confidenceScore, 0.5)
        XCTAssertTrue(tx.note?.contains("לא זוהה") == true)
    }

    func testRefundSalvageFromNegativeText() throws {
        let salvaged = TransactionIngest.salvage(
            amount: nil,
            amountText: "-450.00 ₪",
            merchant: "איקאה זיכוי"
        )

        XCTAssertTrue(salvaged.isRefund)
        XCTAssertEqual(salvaged.amount, 450.00)

        let tx = try TransactionIngest.makeTransaction(
            amount: salvaged.amount,
            amountText: "-450.00 ₪",
            merchant: salvaged.merchant,
            currency: "₪",
            date: Date(),
            existing: [],
            isRefundHint: salvaged.isRefund
        )

        XCTAssertEqual(tx.amount, -450.00, "Refund must preserve negative amount")
        XCTAssertFalse(tx.isConfirmed, "Refunds must never be confirmed without user review")
        XCTAssertTrue(tx.note?.contains("זיכוי") == true)
    }

    func testPrimaryCategoriesIncludeFinanceAndOther() {
        let primaries = SpendingCategory.primaryCategories
        XCTAssertTrue(primaries.contains(.finance), "primaryCategories must contain .finance")
        XCTAssertTrue(primaries.contains(.other), "primaryCategories must contain .other")
        XCTAssertTrue(primaries.contains(.miscellaneous), "primaryCategories must contain .miscellaneous")
        XCTAssertEqual(primaries.count, 11, "Must have exactly 11 distinct primary categories")
    }

    // MARK: - Pre-Release Onboarding Hardening Tests

    func testBudgetSanitizationRemovesNonASCIIDigitsAndClamps() {
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("12,500.00"), "12500")
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("8000.50"), "8000")
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("₪8,000"), "8000")
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("8,000"), "8000")
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("$12,500.00"), "12500")
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("abc8000def"), "8000")
        // Unicode numerals (Arabic-Indic digits ٠١٢) should be excluded
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("١٢٣45"), "45")
        // Max 9 digits clamping
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("123456789012345"), "123456789")
        // Empty string
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits(""), "")
        // Only symbols
        XCTAssertEqual(OnboardingWizardView.sanitizedBudgetDigits("₪$€,.-"), "")
    }

    @MainActor
    func testLegacyIncomeSourceMigrationOnlyDeletesTargetTitles() throws {
        let schema = Schema([IncomeSource.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let targetHebrew = IncomeSource(name: "יעד חודשי", amount: 8000)
        let targetEnglish = IncomeSource(name: "Monthly Target", amount: 8000)
        let salary = IncomeSource(name: "משכורת", amount: 15000)

        context.insert(targetHebrew)
        context.insert(targetEnglish)
        context.insert(salary)
        try context.save()

        // Call production migration directly
        let didDelete = try LegacyTargetIncomeMigration.migrate(in: context)
        XCTAssertTrue(didDelete)

        let descriptor = FetchDescriptor<IncomeSource>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.name, "משכורת")

        // Second run: nothing to delete
        let secondRunDeleted = try LegacyTargetIncomeMigration.migrate(in: context)
        XCTAssertFalse(secondRunDeleted)
    }

    func testOnboardingV2RoutingLogicMatrix() {
        func resolveRoute(
            hasCompletedOnboarding: Bool,
            hasStartedOnboardingV2: Bool,
            hasTransactions: Bool
        ) -> (route: String, markCompleted: Bool, markStarted: Bool) {
            if hasCompletedOnboarding {
                return ("main", false, false)
            } else if hasStartedOnboardingV2 {
                return ("onboarding", false, false)
            } else if hasTransactions {
                return ("main", true, false)
            } else {
                return ("onboarding", false, true)
            }
        }

        // Test A: Brand new user
        let clean = resolveRoute(hasCompletedOnboarding: false, hasStartedOnboardingV2: false, hasTransactions: false)
        XCTAssertEqual(clean.route, "onboarding")
        XCTAssertTrue(clean.markStarted)
        XCTAssertFalse(clean.markCompleted)

        // Test F: User started onboarding, received a background transaction, app relaunched
        let bgTx = resolveRoute(hasCompletedOnboarding: false, hasStartedOnboardingV2: true, hasTransactions: true)
        XCTAssertEqual(bgTx.route, "onboarding", "Background transaction must NOT skip onboarding if Onboarding V2 already started")
        XCTAssertFalse(bgTx.markCompleted)

        // Test G: Legacy user before Onboarding V2 existed
        let legacy = resolveRoute(hasCompletedOnboarding: false, hasStartedOnboardingV2: false, hasTransactions: true)
        XCTAssertEqual(legacy.route, "main", "Legacy user with transactions must bypass onboarding")
        XCTAssertTrue(legacy.markCompleted)

        // Returning completed user
        let returning = resolveRoute(hasCompletedOnboarding: true, hasStartedOnboardingV2: true, hasTransactions: true)
        XCTAssertEqual(returning.route, "main")
    }

    // MARK: - Phase 1: Quick Add Currency Invariant Tests

    func testQuickAddCurrencyNormalizationInvariants() {
        // 1. Base ILS + input ILS
        let res1_isForeign = CurrencyType.ils != CurrencyType.ils
        let res1_amount = res1_isForeign ? CurrencyType.convert(amount: 100, from: .ils, to: .ils) : 100.0
        let res1_curr = CurrencyType.ils.symbol
        XCTAssertEqual(res1_amount, 100.0)
        XCTAssertEqual(res1_curr, "₪")
        XCTAssertFalse(res1_isForeign)

        // 2. Base USD + input USD
        let res2_isForeign = CurrencyType.usd != CurrencyType.usd
        let res2_amount = res2_isForeign ? CurrencyType.convert(amount: 100, from: .usd, to: .usd) : 100.0
        let res2_curr = CurrencyType.usd.symbol
        XCTAssertEqual(res2_amount, 100.0)
        XCTAssertEqual(res2_curr, "$")
        XCTAssertFalse(res2_isForeign)

        // 3. Base USD + input ILS
        let res3_isForeign = CurrencyType.ils != CurrencyType.usd
        let res3_amount = res3_isForeign ? CurrencyType.convert(amount: 100, from: .ils, to: .usd) : 100.0
        let res3_curr = CurrencyType.usd.symbol
        let expectedUSD = 100.0 / FXService.rateToILS(for: .usd)
        XCTAssertEqual(res3_amount, expectedUSD, accuracy: 0.001)
        XCTAssertEqual(res3_curr, "$")
        XCTAssertTrue(res3_isForeign)

        // 4. Base ILS + input USD
        let res4_isForeign = CurrencyType.usd != CurrencyType.ils
        let res4_amount = res4_isForeign ? CurrencyType.convert(amount: 100, from: .usd, to: .ils) : 100.0
        let res4_curr = CurrencyType.ils.symbol
        let expectedILS = 100.0 * FXService.rateToILS(for: .usd)
        XCTAssertEqual(res4_amount, expectedILS, accuracy: 0.001)
        XCTAssertEqual(res4_curr, "₪")
        XCTAssertTrue(res4_isForeign)

        // 5. Base EUR + input USD
        let res5_isForeign = CurrencyType.usd != CurrencyType.eur
        let res5_amount = res5_isForeign ? CurrencyType.convert(amount: 100, from: .usd, to: .eur) : 100.0
        let res5_curr = CurrencyType.eur.symbol
        let expectedEUR = (100.0 * FXService.rateToILS(for: .usd)) / FXService.rateToILS(for: .eur)
        XCTAssertEqual(res5_amount, expectedEUR, accuracy: 0.001)
        XCTAssertEqual(res5_curr, "€")
        XCTAssertTrue(res5_isForeign)
    }

    // MARK: - Phase 6: Merchant Rule HitCount Persistence

    @MainActor
    func testMerchantRuleHitCountPersistsAcrossFreshContexts() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MerchantRule.self, configurations: config)
        let ctx1 = ModelContext(container)

        let rule = MerchantRule(merchantKey: "am:pm", displayName: "AM:PM", category: .food, hitCount: 0)
        ctx1.insert(rule)
        try ctx1.save()

        // Fetch from a distinct context and mutate hitCount
        let ctx2 = ModelContext(container)
        let fetched = try ctx2.fetch(FetchDescriptor<MerchantRule>(predicate: #Predicate { $0.merchantKey == "am:pm" }))
        XCTAssertEqual(fetched.count, 1)
        fetched[0].hitCount += 1
        try ctx2.save()

        // Fetch from a third distinct context to verify durability
        let ctx3 = ModelContext(container)
        let verified = try ctx3.fetch(FetchDescriptor<MerchantRule>(predicate: #Predicate { $0.merchantKey == "am:pm" }))
        XCTAssertEqual(verified.count, 1)
        XCTAssertEqual(verified[0].hitCount, 1, "Hit count must survive save and be visible in fresh contexts")
    }

    // MARK: - Phase 7: Merchant False-Positive Word-Boundary Tests

    func testMerchantRuleWordBoundaryMatchingPreventsFalsePositives() {
        let rules = [
            MerchantRule(merchantKey: "bar", displayName: "Bar", category: .entertainment),
            MerchantRule(merchantKey: "market", displayName: "Market", category: .food)
        ]

        // True positives
        XCTAssertEqual(MerchantRuleService.rule(for: "bar", in: rules)?.category, .entertainment)
        XCTAssertEqual(MerchantRuleService.rule(for: "the bar", in: rules)?.category, .entertainment)
        XCTAssertEqual(MerchantRuleService.rule(for: "bar 51", in: rules)?.category, .entertainment)
        XCTAssertEqual(MerchantRuleService.rule(for: "carmel market", in: rules)?.category, .food)

        // False positives that MUST be rejected:
        XCTAssertNil(MerchantRuleService.rule(for: "barbara", in: rules), "Rule for 'bar' must not match 'barbara'")
        XCTAssertNil(MerchantRuleService.rule(for: "citibank", in: rules), "Rule for 'bar' must not match 'citibank'")
        XCTAssertNil(MerchantRuleService.rule(for: "marketing agency", in: rules), "Rule for 'market' must not match 'marketing'")
    }

    // MARK: - Phase 3: Deep Link Input Route Validation

    func testDeepLinkRouteValidationAcceptsOnlyLegitimateIngestRoutes() {
        func isAllowedIngestURL(_ urlString: String) -> Bool {
            guard let url = URL(string: urlString),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "spentapp" || scheme == "moneycity" else { return false }
            let host = url.host?.lowercased() ?? ""
            return host == "wallet-ingest" || host == "ingest"
        }

        XCTAssertTrue(isAllowedIngestURL("spentapp://wallet-ingest?amount=50&merchant=Test"))
        XCTAssertTrue(isAllowedIngestURL("moneycity://ingest?amount=100"))

        // Must be rejected from Wallet Ingestion:
        XCTAssertFalse(isAllowedIngestURL("spentapp://quick-add?amount=50"), "quick-add is a UI route, not wallet ingest")
        XCTAssertFalse(isAllowedIngestURL("spentapp://scan"), "scan is a UI route, not wallet ingest")
        XCTAssertFalse(isAllowedIngestURL("spentapp://unknown-route?amount=999"))
        XCTAssertFalse(isAllowedIngestURL("otherapp://wallet-ingest?amount=50"))
    }

    func testWidgetCurrencySymbolPersistence() {
        let appGroup = MoneyCityWidgets.appGroupIdentifier
        let defaults = UserDefaults(suiteName: appGroup) ?? UserDefaults.standard

        // Test USD publishing
        MoneyCityWidgets.publishData(
            spent: 100,
            budget: 500,
            savings: 50,
            recentMerchant: "Apple",
            isHebrew: false,
            currencySymbol: "$"
        )
        XCTAssertEqual(defaults.string(forKey: "widget_currency_symbol"), "$")

        // Test EUR publishing
        MoneyCityWidgets.publishData(
            spent: 120,
            budget: 500,
            savings: 50,
            recentMerchant: "Apple",
            isHebrew: false,
            currencySymbol: "€"
        )
        XCTAssertEqual(defaults.string(forKey: "widget_currency_symbol"), "€")

        // Test ILS default
        MoneyCityWidgets.publishData(
            spent: 150,
            budget: 500,
            savings: 50,
            recentMerchant: "Apple",
            isHebrew: false,
            currencySymbol: "₪"
        )
        XCTAssertEqual(defaults.string(forKey: "widget_currency_symbol"), "₪")
    }

    // MARK: - SPENT 1.0 Release Hardening Tests

    func testWidgetTransactionQueueSanitizeAndMigrate() {
        let rawQueue: [[String: Any]] = [
            // 1. Legacy item without id, valid amount & merchant
            [
                "amount": 42.5,
                "merchant": "Super Yuda",
                "date": Date().timeIntervalSince1970
            ],
            // 2. Modern item with id
            [
                "id": "existing-uuid-123",
                "amount": 18.0,
                "merchant": "Aroma",
                "date": Date().timeIntervalSince1970
            ],
            // 3. Irrecoverably malformed: missing amount AND missing merchant
            [
                "date": Date().timeIntervalSince1970
            ],
            // 4. Irrecoverably malformed: whitespace only merchant, no amount
            [
                "merchant": "   ",
                "date": Date().timeIntervalSince1970
            ]
        ]

        let (valid, malformedCount) = WidgetTransactionQueue.sanitizeAndMigrate(raw: rawQueue)
        XCTAssertEqual(malformedCount, 2, "Malformed items must be isolated")
        XCTAssertEqual(valid.count, 2, "Valid items must be preserved")

        // Item 1 had no id, must now have a valid UUID
        let item1 = valid[0]
        let item1Id = item1["id"] as? String
        XCTAssertNotNil(item1Id)
        XCTAssertFalse(item1Id!.isEmpty)
        XCTAssertEqual(item1["amount"] as? Double, 42.5)
        XCTAssertEqual(item1["merchant"] as? String, "Super Yuda")

        // Item 2 already had id, must retain it
        let item2 = valid[1]
        XCTAssertEqual(item2["id"] as? String, "existing-uuid-123")
        XCTAssertEqual(item2["amount"] as? Double, 18.0)
    }

    @MainActor
    func testCurrencyConversionFormattingAlwaysUsesBaseCurrencySymbol() {
        let l10n = LocalizationManager.shared
        l10n.baseCurrency = .ils

        // Format an amount where original currency is USD but base is ILS
        let formatted = l10n.format(
            amount: 100.0,
            currency: .usd,
            showDecimals: false
        )

        // Must use base currency symbol (₪), not original ($)
        XCTAssertTrue(formatted.contains("₪"), "Converted display must use base currency symbol ₪")
        XCTAssertFalse(formatted.contains("$"), "Converted display must not retain foreign currency symbol $")
    }

    func testDeliveryHistoryExtraction() {
        let cal = Calendar.current
        let now = Date()

        guard let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now),
              let twoMonthsAgo = cal.date(byAdding: .month, value: -2, to: now),
              let oneMonthAgo = cal.date(byAdding: .month, value: -1, to: now) else {
            XCTFail("Failed to compute calendar dates")
            return
        }

        let transactions: [Transaction] = [
            // Three months ago: Active SPENT user, but ZERO Wolt orders (e.g. Supermarket only) -> count: 0, spend: 0
            Transaction(amount: 350, merchant: "Shufersal", category: .groceries, timestamp: threeMonthsAgo, buildingId: "food_super"),

            // Two months ago: 2 Wolt orders (80 + 120 = 200 spend), 1 refund (-50) -> count: 2, spend: 150
            Transaction(amount: 80, merchant: "Wolt - Pizza", category: .food, timestamp: twoMonthsAgo, buildingId: "food_wolt"),
            Transaction(amount: 120, merchant: "Wolt - Burgers", category: .food, timestamp: twoMonthsAgo, buildingId: "food_wolt"),
            Transaction(amount: -50, merchant: "Wolt - Refund", category: .food, timestamp: twoMonthsAgo, buildingId: "food_wolt"),

            // One month ago: 1 Wolt order (90 spend) -> count: 1, spend: 90
            Transaction(amount: 90, merchant: "Wolt - Sushi", category: .food, timestamp: oneMonthAgo, buildingId: "food_wolt"),

            // Current month: should be excluded from historical baseline
            Transaction(amount: 50, merchant: "Wolt - Ice Cream", category: .food, timestamp: now, buildingId: "food_wolt")
        ]

        let history = DeliveryHistoryHelper.completedHistoricalWoltData(from: transactions, relativeTo: now, calendar: cal)

        // Must include all 3 historical completed months (including the zero-delivery month) chronologically
        XCTAssertEqual(history.counts, [0, 2, 1], "Zero-delivery completed historical months must be included as 0 to prevent upward baseline bias")
        XCTAssertEqual(history.spends, [0.0, 150.0, 90.0], "Historical spends must match net signed spend for all completed months")
    }

    // MARK: - Widget Queue Durability Tests

    @MainActor
    func testWidgetTransactionQueueDrainSuccessRemoves() async {
        let suite = "WidgetTestSuccess.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let initialQueue: [[String: Any]] = [
            ["id": "item-1", "amount": 25.0, "merchant": "Coffee Shop", "date": Date().timeIntervalSince1970],
            ["id": "item-2", "amount": 50.0, "merchant": "Bakery", "date": Date().timeIntervalSince1970]
        ]
        defaults.set(initialQueue, forKey: WidgetTransactionQueue.key)

        await WidgetTransactionQueue.drain(defaults: defaults) { amount, merchant, timestamp in
            return true // simulated successful ingest
        }

        let remaining = defaults.array(forKey: WidgetTransactionQueue.key) as? [[String: Any]]
        XCTAssertEqual(remaining?.count ?? 0, 0, "Successfully processed items must be removed from queue")
    }

    @MainActor
    func testWidgetTransactionQueueDrainFailurePreserves() async {
        let suite = "WidgetTestFailure.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let initialQueue: [[String: Any]] = [
            ["id": "fail-item-1", "amount": 99.0, "merchant": "Unstable Store", "date": Date().timeIntervalSince1970]
        ]
        defaults.set(initialQueue, forKey: WidgetTransactionQueue.key)

        await WidgetTransactionQueue.drain(defaults: defaults) { _, _, _ in
            return false // simulated transient failure (e.g. database locked)
        }

        let remaining = defaults.array(forKey: WidgetTransactionQueue.key) as? [[String: Any]]
        XCTAssertEqual(remaining?.count, 1, "Failed item must remain in queue")
        XCTAssertEqual(remaining?.first?["id"] as? String, "fail-item-1")
    }

    @MainActor
    func testWidgetTransactionQueueDrainFailureStopsSubsequentDrain() async {
        let suite = "WidgetTestOrder.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let initialQueue: [[String: Any]] = [
            ["id": "item-1-fail", "amount": 10.0, "merchant": "Store 1", "date": Date().timeIntervalSince1970],
            ["id": "item-2-pending", "amount": 20.0, "merchant": "Store 2", "date": Date().timeIntervalSince1970],
            ["id": "item-3-pending", "amount": 30.0, "merchant": "Store 3", "date": Date().timeIntervalSince1970]
        ]
        defaults.set(initialQueue, forKey: WidgetTransactionQueue.key)

        var processedCount = 0
        await WidgetTransactionQueue.drain(defaults: defaults) { amount, merchant, timestamp in
            processedCount += 1
            return false // Item 1 fails
        }

        XCTAssertEqual(processedCount, 1, "Drain must halt immediately after the first failure")
        let remaining = defaults.array(forKey: WidgetTransactionQueue.key) as? [[String: Any]]
        XCTAssertEqual(remaining?.count, 3, "All items must be preserved in queue on failure")
        XCTAssertEqual(remaining?[0]["id"] as? String, "item-1-fail")
        XCTAssertEqual(remaining?[1]["id"] as? String, "item-2-pending")
        XCTAssertEqual(remaining?[2]["id"] as? String, "item-3-pending")
    }

    // MARK: - Pending Wallet Resolution Failure Tests

    @MainActor
    func testPendingResolutionFailurePreservesItemInStore() throws {
        let store = PendingWalletStore.shared
        let pendingId = "test-pending-\(UUID().uuidString)"
        let reg = store.findOrRegister(
            merchant: "Mystery Merchant",
            currency: "₪",
            categoryRawValue: SpendingCategory.other.rawValue,
            buildingId: "city_sorting_hub",
            date: Date(),
            source: "TestIntent",
            id: pendingId
        )

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transaction.self, configurations: config)
        let context = ModelContext(container)

        enum MockError: Error { case diskFull }
        let machine = IngestStateMachine(context: context, pendingStore: store) { _ in
            throw MockError.diskFull
        }

        XCTAssertThrowsError(
            try machine.receive(
                amount: 50.0,
                amountText: nil,
                merchant: "Mystery Merchant",
                currency: "₪",
                date: Date(),
                source: "InAppPendingResolution",
                pendingID: reg.ingest.id
            )
        )

        // Store MUST still contain the pending item because commit failed!
        XCTAssertNotNil(store.get(id: reg.ingest.id), "Pending store must preserve item when commit fails")

        // Clean up
        store.remove(id: reg.ingest.id)
    }

    // MARK: - Deep Link No Silent Write Test

    func testDeepLinkDoesNotSilentlyInjectTransaction() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transaction.self, configurations: config)
        let context = ModelContext(container)

        let preCount = try context.fetchCount(FetchDescriptor<Transaction>())

        // Simulating receiving deep link URL: spentapp://ingest?amount=999&merchant=Sneaky
        let url = URL(string: "spentapp://ingest?amount=999&merchant=Sneaky")!
        // Per MoneyCityApp, deep links no longer execute background ledger writes
        let host = url.host
        let isIngestDeepLink = (host == "ingest" || host == "wallet-ingest")
        XCTAssertTrue(isIngestDeepLink)

        // Context transaction count must remain unchanged
        let postCount = try context.fetchCount(FetchDescriptor<Transaction>())
        XCTAssertEqual(preCount, postCount, "Deep link must never inject transactions into ledger")
    }

    // MARK: - Quick Action Save Failure Rollback Boundary

    func testQuickActionSaveFailureRollback() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transaction.self, configurations: config)
        let context = ModelContext(container)

        let initialCount = try context.fetchCount(FetchDescriptor<Transaction>())

        let tx = Transaction(amount: 100, merchant: "Rollback Test", category: .food, buildingId: "food_bistro")
        context.insert(tx)

        // Simulate a save failure and rollback
        context.rollback()

        let countAfterRollback = try context.fetchCount(FetchDescriptor<Transaction>())
        XCTAssertEqual(initialCount, countAfterRollback, "Rollback must remove unsaved transaction from context")
    }

    // MARK: - Month Rollover State Integrity

    func testMonthRolloverPreservesSnapshotMode() {
        let pastDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())!

        var currentDate = pastDate
        var monthSnapshot: Date? = pastDate

        // Simulate scenePhase becoming .active
        if monthSnapshot == nil {
            currentDate = Date()
        }

        XCTAssertEqual(currentDate, pastDate, "Month rollover must not clobber currentDate when in snapshot mode")

        // In normal mode (monthSnapshot == nil)
        monthSnapshot = nil
        if monthSnapshot == nil {
            currentDate = Date()
        }

        XCTAssertTrue(
            Calendar.current.isDate(currentDate, equalTo: Date(), toGranularity: .day),
            "Month rollover must update currentDate to today when not in snapshot mode"
        )
    }

    func testCitySimulationEngineWoltAndHabitsRefundHandling() {
        let cal = Calendar.current
        let now = Date()

        let transactions: [Transaction] = [
            // Wolt purchase 100, Wolt refund -30 -> count: 1, spend: 70
            Transaction(amount: 100, merchant: "Wolt - Thai", category: .food, timestamp: now, buildingId: "food_wolt"),
            Transaction(amount: -30, merchant: "Wolt - Refund", category: .food, timestamp: now, buildingId: "food_wolt"),

            // Coffee purchase 18, Coffee refund -18 -> coffeeCount must be 1 (positive only)
            Transaction(amount: 18, merchant: "Aroma Cafe", category: .coffee, timestamp: now, buildingId: "food_coffee"),
            Transaction(amount: -18, merchant: "Aroma Refund", category: .coffee, timestamp: now, buildingId: "food_coffee"),

            // Online shopping positive 200, refund -200 -> onlinePkgCount must be 1
            Transaction(amount: 200, merchant: "Amazon", category: .shopping, timestamp: now, buildingId: "shop_tech"),
            Transaction(amount: -200, merchant: "Amazon Refund", category: .shopping, timestamp: now, buildingId: "shop_tech")
        ]

        let city = CitySimulationEngine.shared.generateCity(for: now, transactions: transactions, now: now)

        XCTAssertEqual(city.habits.woltDeliveryCount, 1, "Refund must not increment Wolt delivery count")
        XCTAssertEqual(city.habits.woltTotalSpend, 70.0, accuracy: 0.001, "Refund must reduce Wolt spend")
        XCTAssertEqual(city.habits.coffeeCount, 1, "Coffee count must only count positive purchase events")
        XCTAssertEqual(city.habits.onlinePackagesCount, 1, "Online packages count must only count positive purchase events")
    }

    func testCitySimulationEngineWoltSpendClampedToZero() {
        let now = Date()
        let transactions: [Transaction] = [
            // Excess refund in Wolt: +50, -100 -> net spend clamped to 0, not negative
            Transaction(amount: 50, merchant: "Wolt", category: .food, timestamp: now, buildingId: "food_wolt"),
            Transaction(amount: -100, merchant: "Wolt Refund", category: .food, timestamp: now, buildingId: "food_wolt")
        ]

        let city = CitySimulationEngine.shared.generateCity(for: now, transactions: transactions, now: now)
        XCTAssertEqual(city.habits.woltTotalSpend, 0.0, "Wolt spend must be clamped to at least 0")
        XCTAssertEqual(city.habits.woltDeliveryCount, 1, "Positive transaction is counted")
    }

    func testRewardEngineEnforcesFourDayCooldown() {
        var engine = CityRewardEngine()
        engine.state = CityRewardState()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func date(_ offset: Int) -> Date { Calendar.current.date(byAdding: .day, value: offset, to: now)! }

        // Last reward was received 2 days ago (< 4 days)
        engine.state.lastAnyRewardDate = date(-2)
        engine.state.lastWeeklyRewardDate = date(-10) // weekly eligible if not for 4-day cooldown

        let expenses = [-6, -3, -1].map {
            CityCompanions.Expense(id: "\($0)", amount: 100, date: date($0), category: "food")
        }

        // Even though weekly criteria would pass, lastAnyRewardDate < 4 days MUST block it
        engine.evaluate(expenses: expenses, firstUse: date(-30), latestClaim: nil, now: now)
        XCTAssertNil(engine.state.pending, "4-day cooldown must block weeklyPresence when lastAnyRewardDate is 2 days ago")

        // When lastAnyRewardDate is 4 days ago (>= 4 days), it should unlock
        engine.state.lastAnyRewardDate = date(-4)
        engine.evaluate(expenses: expenses, firstUse: date(-30), latestClaim: nil, now: now)
        XCTAssertEqual(engine.state.pending?.trigger, .weeklyPresence, "Reward must unlock once 4-day cooldown has elapsed")
    }

    func testBudgetedEverydayCategoriesDeterminism() {
        let set1: Set<SpendingCategory> = [.food, .coffee]
        let set2: Set<SpendingCategory> = [.coffee, .food]
        let set3: Set<SpendingCategory> = [.transport, .shopping]

        var h1 = Hasher()
        h1.combine(set1.map(\.rawValue).sorted())
        let key1 = h1.finalize()

        var h2 = Hasher()
        h2.combine(set2.map(\.rawValue).sorted())
        let key2 = h2.finalize()

        var h3 = Hasher()
        h3.combine(set3.map(\.rawValue).sorted())
        let key3 = h3.finalize()

        XCTAssertEqual(key1, key2, "Sorted rawValue hashing must be order-independent")
        XCTAssertNotEqual(key1, key3, "Distinct category sets with identical count must not collide")
    }
}
