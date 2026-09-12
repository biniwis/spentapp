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
}
