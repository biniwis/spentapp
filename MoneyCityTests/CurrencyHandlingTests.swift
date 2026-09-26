import XCTest
import SwiftData
import AppIntents
@testable import MoneyCity

final class CurrencyHandlingTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run { LocalizationManager.shared.baseCurrency = .ils }
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")
        UserDefaults.standard.removeObject(forKey: "monthly_budget")
    }

    override func tearDown() async throws {
        await MainActor.run { LocalizationManager.shared.baseCurrency = .ils }
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")
        UserDefaults.standard.removeObject(forKey: "monthly_budget")
        try await super.tearDown()
    }

    // MARK: - 1. Existing domestic behavior (CRITICAL PRODUCT PRIORITY)

    func testExistingDomesticBehaviorWithNilCurrency() throws {
        // Base = ILS, amount = 42.90, merchant = "AM:PM", currency = nil
        let tx = try TransactionIngest.makeTransaction(
            amount: 42.90,
            amountText: nil,
            merchant: "AM:PM",
            currency: nil,
            date: Date(),
            existing: []
        )

        // Must remain ILS 42.90
        XCTAssertEqual(tx.amount, 42.90)
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertNil(tx.originalAmount)
        XCTAssertNil(tx.originalCurrency)
        XCTAssertNil(tx.exchangeRate)
        XCTAssertFalse(tx.isUnresolvedForeign)
        XCTAssertTrue(tx.isConfirmed)

        // Must count toward budget
        let total = BudgetService.totalSpent([tx])
        XCTAssertEqual(total, 42.90)

        // Must count toward city simulation
        let citySpent = CitySimulationEngine.shared.generateCity(for: Date(), transactions: [tx]).totalSpent
        XCTAssertEqual(citySpent, 42.90)
    }

    // MARK: - 2. Explicit ILS

    func testExplicitILSFromSymbolAndHebrew() throws {
        let tx1 = try TransactionIngest.makeTransaction(
            amount: nil,
            amountText: "₪42.90",
            merchant: "AM:PM",
            currency: nil,
            date: Date(),
            existing: []
        )
        XCTAssertEqual(tx1.amount, 42.90)
        XCTAssertEqual(tx1.currency, "₪")
        XCTAssertNil(tx1.originalCurrency)

        let tx2 = try TransactionIngest.makeTransaction(
            amount: nil,
            amountText: "120 ש״ח",
            merchant: "סופר פארם",
            currency: nil,
            date: Date(),
            existing: []
        )
        XCTAssertEqual(tx2.amount, 120.0)
        XCTAssertEqual(tx2.currency, "₪")
    }

    // MARK: - 3. Explicit EUR

    func testExplicitEURConversionAndOriginalPreservation() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: 20.0,
            amountText: "€20",
            merchant: "Boulangerie",
            currency: "€",
            date: Date(),
            existing: []
        )

        // Foreign currency EUR must be recognized, original amount preserved, and converted to base ILS
        XCTAssertEqual(tx.originalAmount, 20.0)
        XCTAssertEqual(tx.originalCurrency, "EUR")
        XCTAssertEqual(tx.currency, "₪")
        // Rate for EUR is converted to ILS
        let eurRate = FXService.rateToILS(for: "EUR") ?? 3.95
        XCTAssertEqual(tx.amount, (20.0 * eurRate * 100).rounded() / 100, accuracy: 0.1)
        XCTAssertFalse(tx.isUnresolvedForeign)

        let total = BudgetService.totalSpent([tx])
        XCTAssertEqual(total, tx.amount)
    }

    // MARK: - 4. Explicit ISO Code in Text

    func testExplicitISOCodeInText() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: nil,
            amountText: "45.90 EUR",
            merchant: "ZARA",
            currency: nil,
            date: Date(),
            existing: []
        )

        XCTAssertEqual(tx.originalAmount, 45.90)
        XCTAssertEqual(tx.originalCurrency, "EUR")
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertNotNil(tx.exchangeRate)
        XCTAssertFalse(tx.isUnresolvedForeign)
    }

    // MARK: - 5. GBP Symbol

    func testExplicitGBPSymbol() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: 15.0,
            amountText: "£15",
            merchant: "Tesco",
            currency: nil,
            date: Date(),
            existing: []
        )

        XCTAssertEqual(tx.originalAmount, 15.0)
        XCTAssertEqual(tx.originalCurrency, "GBP")
        XCTAssertEqual(tx.currency, "₪")
        // Rate for GBP is ~4.65, so 15 GBP ~ 69.75 ILS
        XCTAssertGreaterThan(tx.amount, 60.0)
    }

    // MARK: - 6. USD Code in Text

    func testExplicitUSDCodeInText() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: nil,
            amountText: "20 USD",
            merchant: "Coffee Shop",
            currency: nil,
            date: Date(),
            existing: []
        )

        XCTAssertEqual(tx.originalAmount, 20.0)
        XCTAssertEqual(tx.originalCurrency, "USD")
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertGreaterThan(tx.amount, 60.0)
    }

    // MARK: - 7. Ambiguous Dollar Policy

    func testAmbiguousDollarConservativeFallback() throws {
        // Base = ILS. Free text contains "$20" with NO structured currency and NO explicit "USD" code.
        // Deliberately conservative policy must favor NOT breaking normal base-currency behavior.
        let tx = try TransactionIngest.makeTransaction(
            amount: 20.0,
            amountText: "$20",
            merchant: "Local Store",
            currency: nil,
            date: Date(),
            existing: []
        )

        // Must conservatively fall back to base currency
        XCTAssertEqual(tx.amount, 20.0)
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertNil(tx.originalAmount)
        XCTAssertFalse(tx.isUnresolvedForeign)
    }

    // MARK: - 8. Structured Payload

    func testStructuredPayloadWithCurrency() throws {
        let jsonPayload = """
        {"amount": 20, "merchant": "Starbucks", "currency": "USD"}
        """
        let tx = try TransactionIngest.makeTransaction(
            amount: 20.0,
            amountText: nil,
            merchant: jsonPayload,
            currency: nil,
            date: Date(),
            existing: []
        )

        XCTAssertEqual(tx.merchant, "Starbucks")
        XCTAssertEqual(tx.originalAmount, 20.0)
        XCTAssertEqual(tx.originalCurrency, "USD")
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertGreaterThan(tx.amount, 60.0)
    }

    // MARK: - 9. Legacy Current Shortcut (no currency field)

    func testLegacyShortcutWithoutCurrencyField() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: 88.50,
            amountText: nil,
            merchant: "Shufersal",
            currency: nil,
            date: Date(),
            existing: []
        )

        XCTAssertEqual(tx.amount, 88.50)
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertNil(tx.originalCurrency)
        XCTAssertTrue(tx.isConfirmed)
    }

    // MARK: - 10. Travel Edge Case (Paris Timezone / France Context)

    func testTravelEdgeCaseDoesNotOverrideBaseCurrency() throws {
        // Base = ILS, Amount = 20, Merchant = Starbucks, Currency = nil
        // Timezone or location signals must NEVER independently turn transaction into EUR
        let resolution = CurrencyResolutionService.resolve(
            structuredCurrencyCode: nil,
            explicitCurrencyParam: nil,
            merchantText: "Starbucks Paris",
            amountText: nil,
            payloadText: nil,
            baseCurrencyCode: "ILS"
        )

        XCTAssertEqual(resolution.currencyCode, "ILS")
        XCTAssertEqual(resolution.source, .legacyBaseCurrencyFallback)
        XCTAssertFalse(resolution.isForeignExplicitlyDetected)
    }

    // MARK: - 11. Locale Edge Case (US Locale)

    func testLocaleEdgeCaseDoesNotOverrideBaseCurrency() throws {
        // Base = ILS, Locale is US, Currency = nil
        let resolution = CurrencyResolutionService.resolve(
            structuredCurrencyCode: nil,
            explicitCurrencyParam: nil,
            merchantText: "Best Buy",
            amountText: nil,
            payloadText: nil,
            baseCurrencyCode: "ILS"
        )

        XCTAssertEqual(resolution.currencyCode, "ILS")
        XCTAssertEqual(resolution.source, .legacyBaseCurrencyFallback)
        XCTAssertFalse(resolution.isForeignExplicitlyDetected)
    }

    // MARK: - 12. Foreign Conversion Unavailable

    func testForeignConversionUnavailableDoesNotConvert1To1() throws {
        // Explicit foreign currency with NO conversion rate (e.g. hypothetical UNK)
        let tx = try TransactionIngest.makeTransaction(
            amount: 100.0,
            amountText: nil,
            merchant: "Boutique",
            currency: "UNK",
            date: Date(),
            existing: []
        )

        // Must NOT silently convert 1:1 to ₪100
        XCTAssertEqual(tx.amount, 100.0)
        XCTAssertEqual(tx.currency, "UNK")
        XCTAssertEqual(tx.originalCurrency, "UNK")
        XCTAssertNil(tx.exchangeRate)
        XCTAssertTrue(tx.isUnresolvedForeign)
        XCTAssertFalse(tx.isConfirmed)

        // Must NOT contaminate budget totals
        let budgetTotal = BudgetService.totalSpent([tx])
        XCTAssertEqual(budgetTotal, 0.0)

        // Must NOT contaminate city simulation totals
        let cityTotal = CitySimulationEngine.shared.generateCity(for: Date(), transactions: [tx]).totalSpent
        XCTAssertEqual(cityTotal, 0.0)
    }

    // MARK: - 13. Edit Transaction Preserves Currency Metadata

    func testEditTransactionPreservesForeignCurrencyMetadata() {
        let tx = Transaction(
            amount: 73.40,
            currency: "₪",
            merchant: "Original Shop",
            category: .food,
            originalAmount: 20.0,
            originalCurrency: "USD",
            exchangeRate: 3.67
        )

        // Changing merchant name must NOT destroy foreign-currency metadata
        tx.merchant = "Renamed Shop"

        XCTAssertEqual(tx.amount, 73.40)
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertEqual(tx.originalAmount, 20.0)
        XCTAssertEqual(tx.originalCurrency, "USD")
        XCTAssertEqual(tx.exchangeRate, 3.67)
        XCTAssertEqual(tx.displayOriginalText, "$20.00")
    }

    // MARK: - 14. Deduplication on Foreign Transaction

    func testDeduplicationMatchesOnOriginalCurrencyAndAmount() {
        let now = Date()
        let existing = [
            Transaction(
                amount: 73.40,
                currency: "₪",
                merchant: "Apple Store",
                category: .shopping,
                timestamp: now,
                originalAmount: 20.0,
                originalCurrency: "USD",
                exchangeRate: 3.67
            )
        ]

        // Repeated payment event in original currency (20 USD) within duplicate window
        let isDup = TransactionIngest.isDuplicate(
            merchant: "Apple Store",
            amount: 20.0,
            currency: "USD",
            originalAmount: 20.0,
            originalCurrency: "USD",
            date: now.addingTimeInterval(5),
            in: existing
        )
        XCTAssertTrue(isDup, "Second USD 20 transaction within duplicate window must be recognized as duplicate")
    }

    // MARK: - 15. Base Currency Change

    @MainActor
    func testBaseCurrencyChangeDoesNotRelabelHistoricalAmounts() throws {
        let schema = Schema([Transaction.self, CategoryBudget.self, IncomeSource.self, RecurringExpense.self, InstallmentPlan.self, SavingsGoal.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let tx = Transaction(
            amount: 10_000.0,
            currency: "₪",
            merchant: "Rent",
            category: .housing
        )
        context.insert(tx)
        try context.save()

        // Migrate base currency from ILS to EUR
        try BaseCurrencyMigrationService.migrateBaseCurrency(
            from: .ils,
            to: .eur,
            context: context
        )

        // The transaction amount must NOT remain 10,000 when currency becomes EUR
        XCTAssertEqual(tx.currency, "€")
        XCTAssertNotEqual(tx.amount, 10_000.0, "10,000 ILS must not be relabeled as €10,000")
        let eurRate = FXService.rateToILS(for: "EUR") ?? 3.95
        let expectedAmount = (10_000.0 / eurRate * 100).rounded() / 100
        XCTAssertEqual(tx.amount, expectedAmount, accuracy: 1.0)
    }

    // MARK: - 16. FX safety: unavailable rate must never become a 1:1 conversion

    func testUnavailableRateNeverFallsBackToOneToOne() {
        // An unsupported currency ("XYZ") has no verified/cached/default rate. Converting it
        // must FAIL (nil), never return the original amount as if the rate were 1.0.
        let unknown = CurrencyType(rawValue: "XYZ")
        XCTAssertNil(CurrencyType.convertIfAvailable(amount: 1000, from: unknown, to: .ils))
        XCTAssertNil(CurrencyType.convert(amount: 1000, from: unknown, to: .ils))
        XCTAssertNil(FXService.convert(amount: 1000, from: unknown, to: .ils))

        // The raw FX path must also refuse a code with no bundled or cached rate.
        XCTAssertNil(FXService.rateToILS(for: "XYZ"))

        // Same-currency conversion is trivially valid and needs no external rate.
        XCTAssertEqual(CurrencyType.convertIfAvailable(amount: 1000, from: .ils, to: .ils), 1000)
    }

    // MARK: - 17. Migration failure leaves financial data AND base preference unchanged

    @MainActor
    func testBaseCurrencyMigrationWithUnavailableRateLeavesDataAndPreferenceUnchanged() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext

        let tx = Transaction(amount: 10_000.0, currency: "₪", merchant: "Rent", category: .housing)
        context.insert(tx)
        let scheduled = ScheduledExpense(merchant: "Migration Test", amount: 500.0, currency: "₪", category: .housing, scheduledFor: Self.futureDate())
        context.insert(scheduled)
        try context.save()

        // Attempt migration to a currency with no available rate.
        do {
            try BaseCurrencyMigrationService.migrateBaseCurrency(
                from: .ils,
                to: CurrencyType(rawValue: "XYZ"),
                context: context,
                rateProvider: { _, _ in nil }
            )
            XCTFail("Migration to a route with no rate must throw")
        } catch BaseCurrencyMigrationService.MigrationError.rateUnavailable {
            // Expected.
        }

        // Nothing was relabeled and the base-currency preference was not written.
        XCTAssertEqual(tx.amount, 10_000.0)
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertEqual(scheduled.amount, 500.0)
        XCTAssertEqual(scheduled.currency, "₪")
        XCTAssertEqual(LocalizationManager.shared.baseCurrency, .ils)
    }

    // MARK: - 18. ScheduledExpense counts as financial data for migration

    @MainActor
    func testScheduledExpenseCountsAsFinancialDataForBaseCurrencyMigration() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext

        // A store containing ONLY a scheduled expense is not empty.
        XCTAssertFalse(try BaseCurrencyMigrationService.hasFinancialData(context: context))

        let scheduled = ScheduledExpense(merchant: "Migration Test", amount: 500.0, currency: "₪", category: .housing, scheduledFor: Self.futureDate())
        context.insert(scheduled)
        try context.save()

        XCTAssertTrue(try BaseCurrencyMigrationService.hasFinancialData(context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ScheduledExpense>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Transaction>()), 0)
    }

    // MARK: - 19. Base currency migration converts an unmaterialized ScheduledExpense

    @MainActor
    func testBaseCurrencyMigrationConvertsScheduledExpense() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext

        let future = Self.futureDate()
        let upcoming = ScheduledExpense(merchant: "Migration Test", amount: 500.0, currency: "₪", category: .housing, scheduledFor: future)
        context.insert(upcoming)
        let materialized = ScheduledExpense(merchant: "Migration Test", amount: 400.0, currency: "₪", category: .food, scheduledFor: Self.pastDate())
        materialized.materializedAt = Self.pastDate()
        context.insert(materialized)
        try context.save()

        // Inject a deterministic rate: 1 ILS = 0.25 EUR.
        try BaseCurrencyMigrationService.migrateBaseCurrency(
            from: .ils,
            to: .eur,
            context: context,
            rateProvider: { _, _ in 0.25 }
        )

        XCTAssertEqual(upcoming.amount, 125.0, accuracy: 0.01)
        XCTAssertEqual(upcoming.currency, "€")
        // Materialized records stay untouched: the linked Transaction is authoritative.
        XCTAssertEqual(materialized.amount, 400.0)
        XCTAssertEqual(materialized.currency, "₪")
        XCTAssertEqual(LocalizationManager.shared.baseCurrency, .eur)
    }

    // MARK: - 20. Restore exact original value when scheduled was entered in destination currency

    @MainActor
    func testBaseCurrencyMigrationRestoresOriginalValueForScheduledExpense() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext

        // Entered in EUR originally; migration to EUR must restore the exact original value.
        let scheduled = ScheduledExpense(
            merchant: "Migration Test",
            amount: 650.0,
            currency: "₪",
            category: .housing,
            scheduledFor: Self.futureDate(),
            originalAmount: 200.0,
            originalCurrency: "EUR",
            exchangeRate: 3.25
        )
        context.insert(scheduled)
        try context.save()

        try BaseCurrencyMigrationService.migrateBaseCurrency(
            from: .ils,
            to: .eur,
            context: context,
            rateProvider: { _, _ in 0.25 }
        )

        XCTAssertEqual(scheduled.amount, 200.0, accuracy: 0.01)
        XCTAssertEqual(scheduled.currency, "€")
        XCTAssertNil(scheduled.originalAmount)
        XCTAssertNil(scheduled.originalCurrency)
        XCTAssertNil(scheduled.exchangeRate)
    }

    // MARK: - 21. Migration atomicity with a failure injected mid-flow

    @MainActor
    func testMigrationAtomicityLeavesNoPartialMutation() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext

        let tx = Transaction(amount: 1000.0, currency: "₪", merchant: "Rent", category: .housing)
        context.insert(tx)
        let scheduled = ScheduledExpense(merchant: "Migration Test", amount: 300.0, currency: "₪", category: .food, scheduledFor: Self.futureDate())
        context.insert(scheduled)
        let budget = CategoryBudget(category: .food, monthlyLimit: 200.0)
        context.insert(budget)
        try context.save()

        // Supply a rate that advertises availability then the fetch phase has nothing to fail —
        // instead force the failure at the conversion gate itself (nil rate) and confirm the
        // whole data set stays untouched.
        do {
            try BaseCurrencyMigrationService.migrateBaseCurrency(
                from: .ils,
                to: .eur,
                context: context,
                rateProvider: { _, _ in nil }
            )
            XCTFail("Expected migration to fail")
        } catch BaseCurrencyMigrationService.MigrationError.rateUnavailable {
            // Expected.
        }

        XCTAssertEqual(tx.amount, 1000.0)
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertEqual(scheduled.amount, 300.0)
        XCTAssertEqual(scheduled.currency, "₪")
        XCTAssertEqual(budget.monthlyLimit, 200.0)
        XCTAssertEqual(LocalizationManager.shared.baseCurrency, .ils)

        // After a successful migration every model is consistently converted — nothing half-done.
        try BaseCurrencyMigrationService.migrateBaseCurrency(
            from: .ils,
            to: .eur,
            context: context,
            rateProvider: { _, _ in 0.5 }
        )
        XCTAssertEqual(tx.amount, 500.0, accuracy: 0.01)
        XCTAssertEqual(tx.currency, "€")
        XCTAssertEqual(scheduled.amount, 150.0, accuracy: 0.01)
        XCTAssertEqual(scheduled.currency, "€")
        XCTAssertEqual(budget.monthlyLimit, 100.0, accuracy: 0.01)
        XCTAssertEqual(LocalizationManager.shared.baseCurrency, .eur)
    }

    // MARK: - 22. Monthly budget migrates with the base currency

    @MainActor
    func testMonthlyBudgetMigratesWithBaseCurrency() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext
        UserDefaults.standard.set(8000.0, forKey: "monthly_budget")

        try BaseCurrencyMigrationService.migrateBaseCurrency(
            from: .ils,
            to: .eur,
            context: context,
            rateProvider: { _, _ in 0.25 }
        )

        XCTAssertEqual(UserDefaults.standard.double(forKey: "monthly_budget"), 2000.0, accuracy: 0.01)
        XCTAssertEqual(LocalizationManager.shared.baseCurrency, .eur)
    }

    // MARK: - 23. Monthly budget alone counts as financial data

    @MainActor
    func testMonthlyBudgetOnlyCountsAsFinancialData() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext
        XCTAssertFalse(try BaseCurrencyMigrationService.hasFinancialData(context: context))

        UserDefaults.standard.set(8000.0, forKey: "monthly_budget")
        XCTAssertTrue(try BaseCurrencyMigrationService.hasFinancialData(context: context))
    }

    // MARK: - 24. Monthly budget restored untouched when migration fails

    @MainActor
    func testMonthlyBudgetRestoredWhenMigrationFails() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext
        UserDefaults.standard.set(8000.0, forKey: "monthly_budget")
        let tx = Transaction(amount: 10_000.0, currency: "₪", merchant: "Rent", category: .housing)
        context.insert(tx)
        try context.save()

        do {
            try BaseCurrencyMigrationService.migrateBaseCurrency(
                from: .ils,
                to: CurrencyType(rawValue: "XYZ"),
                context: context,
                rateProvider: { _, _ in nil }
            )
            XCTFail("Migration with no rate must throw")
        } catch BaseCurrencyMigrationService.MigrationError.rateUnavailable {
            // Expected.
        }

        XCTAssertEqual(UserDefaults.standard.double(forKey: "monthly_budget"), 8000.0)
        XCTAssertEqual(tx.amount, 10_000.0)
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertEqual(LocalizationManager.shared.baseCurrency, .ils)
    }

    // MARK: - 25. Unresolved foreign converts from its own currency during migration

    @MainActor
    func testUnresolvedForeignUsesOriginalCurrencyDuringBaseMigration() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")

        // A TRY transaction that entered with no usable rate is still sitting in ₺.
        let tx = Transaction(
            amount: 500.0,
            currency: "₺",
            merchant: "Taxi Bodrum",
            category: .transport,
            originalAmount: 500.0,
            originalCurrency: "TRY",
            exchangeRate: nil
        )
        context.insert(tx)
        try context.save()
        XCTAssertTrue(tx.isUnresolvedForeign)

        // TRY -> EUR has a direct rate; the old-base (ILS -> EUR) rate must NOT be applied
        // to an unresolved transaction as a stand-in.
        try BaseCurrencyMigrationService.migrateBaseCurrency(
            from: .ils,
            to: .eur,
            context: context,
            rateProvider: { from, to in
                if from == "TRY" && to == "EUR" { return 1.0 }
                if from == "ILS" { return 0.25 }
                return nil
            }
        )

        XCTAssertEqual(tx.currency, "€")
        XCTAssertEqual(tx.amount, 500.0, accuracy: 0.01)
        XCTAssertNotNil(tx.exchangeRate)
        XCTAssertEqual(tx.originalAmount, 500.0)
        XCTAssertEqual(tx.originalCurrency, "TRY")
        XCTAssertFalse(tx.isUnresolvedForeign)
        XCTAssertEqual(LocalizationManager.shared.baseCurrency, .eur)
    }

    // MARK: - 26. Unresolved foreign with no direct rate aborts the whole migration

    @MainActor
    func testUnresolvedForeignBlocksBaseMigrationWhenDirectRateUnavailable() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")

        let tx = Transaction(
            amount: 500.0,
            currency: "₺",
            merchant: "Taxi Bodrum",
            category: .transport,
            originalAmount: 500.0,
            originalCurrency: "TRY",
            exchangeRate: nil
        )
        context.insert(tx)
        let scheduled = ScheduledExpense(
            merchant: "Hotel Bodrum",
            amount: 200.0,
            currency: "₺",
            category: .housing,
            scheduledFor: Self.futureDate(),
            originalAmount: 200.0,
            originalCurrency: "TRY",
            exchangeRate: nil
        )
        context.insert(scheduled)
        try context.save()

        // The direct TRY -> EUR leg has no rate: the migration must abort rather than apply
        // an invented or stand-in conversion.
        do {
            try BaseCurrencyMigrationService.migrateBaseCurrency(
                from: .ils,
                to: .eur,
                context: context,
                rateProvider: { from, to in
                    if from == "ILS" { return 0.25 }
                    return nil
                }
            )
            XCTFail("Migration with an unresolved foreign row lacking a direct rate must abort")
        } catch BaseCurrencyMigrationService.MigrationError.rateUnavailable {
            // Expected.
        }

        XCTAssertEqual(tx.amount, 500.0)
        XCTAssertEqual(tx.currency, "₺")
        XCTAssertEqual(scheduled.amount, 200.0)
        XCTAssertEqual(scheduled.currency, "₺")
        XCTAssertEqual(LocalizationManager.shared.baseCurrency, .ils)
    }

    // MARK: - 27. Resolve a stored foreign transaction once a rate becomes available

    @MainActor
    func testResolveStoredForeignTransactionWhenRateBecomesAvailable() throws {
        let schema = Schema([Transaction.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let tx = Transaction(
            amount: 500.0,
            currency: "₺",
            merchant: "Taxi Bodrum",
            category: .transport,
            confidenceScore: 0.4,
            isConfirmed: false,
            originalAmount: 500.0,
            originalCurrency: "TRY",
            exchangeRate: nil
        )
        context.insert(tx)
        try context.save()

        let outcome = CurrencyResolutionService.resolveStoredForeignTransactionIfPossible(
            tx,
            context: context,
            baseCurrency: .eur,
            rateProvider: { from, to in
                if from == "TRY" && to == "EUR" { return 1.0 }
                return nil
            }
        )

        XCTAssertEqual(outcome, .resolved)
        XCTAssertEqual(tx.amount, 500.0, accuracy: 0.01)
        XCTAssertEqual(tx.currency, "€")
        XCTAssertNotNil(tx.exchangeRate)
        XCTAssertFalse(tx.isUnresolvedForeign)
        XCTAssertTrue(tx.isConfirmed)
    }

    // MARK: - 28. Resolution leaves data untouched when the rate is still missing

    @MainActor
    func testResolveStoredForeignTransactionLeavesDataUntouchedWhenRateMissing() throws {
        let schema = Schema([Transaction.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let tx = Transaction(
            amount: 500.0,
            currency: "₺",
            merchant: "Taxi Bodrum",
            category: .transport,
            confidenceScore: 0.4,
            isConfirmed: false,
            originalAmount: 500.0,
            originalCurrency: "TRY",
            exchangeRate: nil
        )
        context.insert(tx)
        try context.save()

        let outcome = CurrencyResolutionService.resolveStoredForeignTransactionIfPossible(
            tx,
            context: context,
            baseCurrency: .eur,
            rateProvider: { _, _ in nil }
        )

        XCTAssertEqual(outcome, .rateUnavailable)
        XCTAssertEqual(tx.amount, 500.0)
        XCTAssertEqual(tx.currency, "₺")
        XCTAssertNil(tx.exchangeRate)
        XCTAssertEqual(tx.originalCurrency, "TRY")
        XCTAssertFalse(tx.isConfirmed)
        XCTAssertTrue(tx.isUnresolvedForeign)
    }

    // MARK: - 29. CurrencyType rate must never fall back to 1.0

    func testCurrencyTypeRateDoesNotFallbackToOne() {
        let unknown = CurrencyType(rawValue: "XYZ")
        XCTAssertNil(unknown.rateToILS, "An unknown currency must not report a rate of 1.0")
        XCTAssertNil(FXService.rateToILS(for: unknown))
        XCTAssertNil(FXService.rateToILS(for: "XYZ"))
        // USD always carries a bundled default rate — it is a real currency, not the 1.0 bug.
        XCTAssertNotNil(FXService.rateToILS(for: "USD"))
    }

    // MARK: - 30. Successful migration marks the backup dirty; failed migration does not

    @MainActor
    func testSuccessfulMigrationMarksBackupDirty() throws {
        let container = try Self.migrationContainer()
        let context = container.mainContext

        let tx = Transaction(amount: 10_000.0, currency: "₪", merchant: "Rent", category: .housing)
        context.insert(tx)
        try context.save()

        var dirtyCalls = 0
        try BaseCurrencyMigrationService.migrateBaseCurrency(
            from: .ils,
            to: .eur,
            context: context,
            rateProvider: { _, _ in 0.25 },
            markBackupDirty: { dirtyCalls += 1 }
        )
        XCTAssertEqual(dirtyCalls, 1)

        dirtyCalls = 0
        do {
            try BaseCurrencyMigrationService.migrateBaseCurrency(
                from: .eur,
                to: .ils,
                context: context,
                rateProvider: { _, _ in nil },
                markBackupDirty: { dirtyCalls += 1 }
            )
            XCTFail("Expected migration to fail")
        } catch BaseCurrencyMigrationService.MigrationError.rateUnavailable {
            // Expected.
        }
        XCTAssertEqual(dirtyCalls, 0, "A failed migration must not mark the backup dirty")
    }

    // MARK: - 31. Hotfix: RecordTransactionIntent ignores synthetic USD from Shortcuts

    @MainActor
    func testRecordTransactionIntentIgnoresSyntheticUSDInCurrencyAmount() async throws {
        // Test A: Base ILS, amount 34.50, RecordTransactionIntent with currency USD.
        // Assert amount == 34.50, currency == "₪", originalAmount == nil, originalCurrency == nil.
        LocalizationManager.shared.baseCurrency = .ils
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")

        let testMerchant = "TestMerchantA_\(UUID().uuidString)"
        let intent = RecordTransactionIntent(
            amount: 34.50,
            merchant: testMerchant,
            currency: "USD"
        )

        _ = try await intent.perform()

        let context = DatabaseService.shared.context
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.merchant == testMerchant })
        guard let savedTx = try context.fetch(descriptor).first else {
            XCTFail("Transaction was not saved by RecordTransactionIntent")
            return
        }

        XCTAssertEqual(savedTx.amount, 34.50, accuracy: 0.001)
        XCTAssertEqual(savedTx.currency, "₪")
        XCTAssertNil(savedTx.originalAmount)
        XCTAssertNil(savedTx.originalCurrency)
        XCTAssertNil(savedTx.exchangeRate)

        context.delete(savedTx)
        try? context.save()
    }

    @MainActor
    func testRecordTransactionIntentWith150AmountAndMisleadingUSDDoesNotConvert() async throws {
        // Test B: Base ILS, amount 150.0, RecordTransactionIntent with misleading USD metadata.
        // Assert amount == 150.0, no foreign metadata (not ₪450+).
        LocalizationManager.shared.baseCurrency = .ils
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")

        let testMerchant = "TestMerchantB_\(UUID().uuidString)"
        let intent = RecordTransactionIntent(
            amount: 150.0,
            merchant: testMerchant,
            currency: "USD"
        )

        _ = try await intent.perform()

        let context = DatabaseService.shared.context
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.merchant == testMerchant })
        guard let savedTx = try context.fetch(descriptor).first else {
            XCTFail("Transaction was not saved by RecordTransactionIntent")
            return
        }

        XCTAssertEqual(savedTx.amount, 150.0, accuracy: 0.001)
        XCTAssertEqual(savedTx.currency, "₪")
        XCTAssertNil(savedTx.originalAmount)
        XCTAssertNil(savedTx.originalCurrency)
        XCTAssertNil(savedTx.exchangeRate)

        context.delete(savedTx)
        try? context.save()
    }

    @MainActor
    func testRecordTransactionIntentWithExplicitUSDCurrencyParameterFallsBackToBaseCurrency() async throws {
        // Test C: Base ILS, RecordTransactionIntent with currency = "USD".
        // Assert base currency wins (₪34.50, no conversion).
        LocalizationManager.shared.baseCurrency = .ils
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")

        let testMerchant = "TestMerchantC_\(UUID().uuidString)"
        let intent = RecordTransactionIntent(
            amount: 34.50,
            merchant: testMerchant,
            currency: "USD"
        )

        _ = try await intent.perform()

        let context = DatabaseService.shared.context
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.merchant == testMerchant })
        guard let savedTx = try context.fetch(descriptor).first else {
            XCTFail("Transaction was not saved by RecordTransactionIntent")
            return
        }

        XCTAssertEqual(savedTx.amount, 34.50, accuracy: 0.001)
        XCTAssertEqual(savedTx.currency, "₪")
        XCTAssertNil(savedTx.originalAmount)
        XCTAssertNil(savedTx.originalCurrency)
        XCTAssertNil(savedTx.exchangeRate)

        context.delete(savedTx)
        try? context.save()
    }

    func testDirectIngestWithExplicitTrustedForeignCurrencyStillWorks() throws {
        // Test D: Direct call to TransactionIngest.makeTransaction with explicit trusted foreign currency (e.g. 20.0 EUR).
        // Assert foreign conversion still works as intended.
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")

        let tx = try TransactionIngest.makeTransaction(
            amount: 20.0,
            amountText: "€20",
            merchant: "Boulangerie Paris",
            currency: "EUR",
            date: Date(),
            existing: []
        )

        XCTAssertEqual(tx.originalAmount, 20.0)
        XCTAssertEqual(tx.originalCurrency, "EUR")
        XCTAssertEqual(tx.currency, "₪")
        let eurRate = FXService.rateToILS(for: "EUR") ?? 3.95
        XCTAssertEqual(tx.amount, (20.0 * eurRate * 100).rounded() / 100, accuracy: 0.1)
        XCTAssertNotNil(tx.exchangeRate)
    }

    @MainActor
    func testRecordTransactionIntentAmountFallbackFromAmountText() async throws {
        // Verifies that when numeric amount is 0/nil, amountText is safely used as fallback
        LocalizationManager.shared.baseCurrency = .ils
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")

        let testMerchant = "TestMerchantFallback_\(UUID().uuidString)"
        let intent = RecordTransactionIntent(
            amount: 0.0,
            merchant: testMerchant,
            amountText: "45.0"
        )

        _ = try await intent.perform()

        let context = DatabaseService.shared.context
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.merchant == testMerchant })
        guard let savedTx = try context.fetch(descriptor).first else {
            XCTFail("Transaction was not saved by RecordTransactionIntent")
            return
        }

        XCTAssertEqual(savedTx.amount, 45.0, accuracy: 0.001)
        XCTAssertEqual(savedTx.currency, "₪")
        XCTAssertNil(savedTx.originalAmount)
        XCTAssertNil(savedTx.originalCurrency)

        context.delete(savedTx)
        try? context.save()
    }

    // MARK: - Helpers

    @MainActor
    private static func migrationContainer() throws -> ModelContainer {
        let schema = Schema([
            Transaction.self,
            CategoryBudget.self,
            IncomeSource.self,
            RecurringExpense.self,
            InstallmentPlan.self,
            SavingsGoal.self,
            ScheduledExpense.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func futureDate() -> Date {
        Date(timeIntervalSinceNow: 60 * 60 * 24 * 30)
    }

    private static func pastDate() -> Date {
        Date(timeIntervalSinceNow: -60 * 60 * 24 * 30)
    }
}
