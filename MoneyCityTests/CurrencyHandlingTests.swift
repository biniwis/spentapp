import XCTest
import SwiftData
@testable import MoneyCity

final class CurrencyHandlingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")
    }

    override func tearDown() {
        UserDefaults.standard.set("ILS", forKey: "app_currency_pref")
        UserDefaults.standard.set(true, forKey: "auto_convert_fx")
        super.tearDown()
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
}
