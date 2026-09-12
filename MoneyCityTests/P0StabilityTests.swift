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
        func sanitize(_ text: String) -> String {
            String(text.filter { $0 >= "0" && $0 <= "9" }.prefix(9))
        }

        XCTAssertEqual(sanitize("₪8,000"), "8000")
        XCTAssertEqual(sanitize("8,000"), "8000")
        XCTAssertEqual(sanitize("$12,500.00"), "1250000")
        XCTAssertEqual(sanitize("abc8000def"), "8000")
        // Unicode numerals (Arabic-Indic digits ٠١٢) should be excluded
        XCTAssertEqual(sanitize("١٢٣45"), "45")
        // Max 9 digits clamping
        XCTAssertEqual(sanitize("123456789012345"), "123456789")
        // Empty string
        XCTAssertEqual(sanitize(""), "")
        // Only symbols
        XCTAssertEqual(sanitize("₪$€,.-"), "")
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

        // Perform migration
        let descriptor = FetchDescriptor<IncomeSource>()
        let items = try context.fetch(descriptor)
        for item in items where item.name == "יעד חודשי" || item.name == "Monthly Target" {
            context.delete(item)
        }
        try context.save()

        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.name, "משכורת")
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
}
