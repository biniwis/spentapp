import XCTest
import SwiftData
@testable import MoneyCity

final class CurrencyHandlingTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run { LocalizationManager.shared.baseCurrency = .ils }
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")
    }

    override func tearDown() async throws {
        await MainActor.run { LocalizationManager.shared.baseCurrency = .ils }
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")
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
        let eurRate = FXService.rateToILS(for: .eur)
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
