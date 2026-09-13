import XCTest
@testable import MoneyCity

final class CitySpendingBreakdownTests: XCTestCase {

    private func makeCity(transactions: [Transaction]) -> MonthlyCity {
        CitySimulationEngine.shared.generateCity(for: Date(), transactions: transactions)
    }

    private func makeTx(category: SpendingCategory, amount: Double, buildingId: String = "") -> Transaction {
        let bId = buildingId.isEmpty ? CityBuilding.defaultBuildingId(for: category) : buildingId
        return Transaction(
            amount: amount,
            merchant: "TestMerchant",
            category: category,
            timestamp: Date(),
            buildingId: bId
        )
    }

    // 1. Food only → Food = 100%, no Park row.
    func testFoodOnly() {
        let txs = [makeTx(category: .food, amount: 250)]
        let city = makeCity(transactions: txs)
        let breakdown = DistrictDataHelper.expenseBreakdown(for: city, language: .hebrew)

        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown.first?.id, "food")
        XCTAssertEqual(breakdown.first?.amount, 250)
        XCTAssertEqual(breakdown.first?.percentage, 100)
        XCTAssertFalse(breakdown.contains { $0.id == "savings" })
    }

    // 2. Transport only → Transport = 100%.
    func testTransportOnly() {
        let txs = [makeTx(category: .transport, amount: 180)]
        let city = makeCity(transactions: txs)
        let breakdown = DistrictDataHelper.expenseBreakdown(for: city, language: .hebrew)

        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown.first?.id, "transport")
        XCTAssertEqual(breakdown.first?.amount, 180)
        XCTAssertEqual(breakdown.first?.percentage, 100)
    }

    // 3. Food + coffee → Food includes both correctly.
    func testFoodAndCoffeeAggregateIntoFood() {
        let txs = [
            makeTx(category: .food, amount: 150),
            makeTx(category: .coffee, amount: 35)
        ]
        let city = makeCity(transactions: txs)
        let breakdown = DistrictDataHelper.expenseBreakdown(for: city, language: .hebrew)

        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown.first?.id, "food")
        XCTAssertEqual(breakdown.first?.amount, 185)
        XCTAssertEqual(breakdown.first?.percentage, 100)
    }

    // 4. Shopping + entertainment → both contribute to the correct district.
    func testShoppingAndEntertainmentAggregateIntoShopping() {
        let txs = [
            makeTx(category: .shopping, amount: 300),
            makeTx(category: .entertainment, amount: 100)
        ]
        let city = makeCity(transactions: txs)
        let breakdown = DistrictDataHelper.expenseBreakdown(for: city, language: .hebrew)

        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown.first?.id, "shopping")
        XCTAssertEqual(breakdown.first?.amount, 400)
        XCTAssertEqual(breakdown.first?.percentage, 100)
    }

    // 5. Housing + subscription → both contribute correctly.
    func testHousingAndSubscriptionAggregateIntoHousing() {
        let txs = [
            makeTx(category: .housing, amount: 2000),
            makeTx(category: .subscriptions, amount: 50)
        ]
        let city = makeCity(transactions: txs)
        let breakdown = DistrictDataHelper.expenseBreakdown(for: city, language: .hebrew)

        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown.first?.id, "housing")
        XCTAssertEqual(breakdown.first?.amount, 2050)
        XCTAssertEqual(breakdown.first?.percentage, 100)
    }

    // 6. Positive savings + expenses → savings does not affect expense percentages.
    func testSavingsDoesNotAffectExpensePercentages() {
        let txsWithSavings = [
            makeTx(category: .food, amount: 300),
            makeTx(category: .transport, amount: 100),
            makeTx(category: .savings, amount: 1000)
        ]
        let cityWithSavings = makeCity(transactions: txsWithSavings)
        let breakdownWith = DistrictDataHelper.expenseBreakdown(for: cityWithSavings, language: .hebrew)

        let txsWithoutSavings = [
            makeTx(category: .food, amount: 300),
            makeTx(category: .transport, amount: 100)
        ]
        let cityWithout = makeCity(transactions: txsWithoutSavings)
        let breakdownWithout = DistrictDataHelper.expenseBreakdown(for: cityWithout, language: .hebrew)

        XCTAssertFalse(breakdownWith.contains { $0.id == "savings" })
        XCTAssertEqual(breakdownWith.count, breakdownWithout.count)
        XCTAssertEqual(breakdownWith.map(\.amount), breakdownWithout.map(\.amount))
        XCTAssertEqual(breakdownWith.map(\.percentage), breakdownWithout.map(\.percentage))
        XCTAssertEqual(cityWithSavings.totalSpent, 400)
        XCTAssertEqual(cityWithSavings.totalSavings, 1000)
    }

    // 7. Positive savings + zero expenses → All City says no expenses; Park still works independently.
    func testPositiveSavingsAndZeroExpensesReturnsEmptyBreakdown() {
        let txs = [makeTx(category: .savings, amount: 500)]
        let city = makeCity(transactions: txs)
        let breakdown = DistrictDataHelper.expenseBreakdown(for: city, language: .hebrew)

        XCTAssertEqual(city.totalSpent, 0)
        XCTAssertEqual(city.totalSavings, 500)
        XCTAssertTrue(breakdown.isEmpty, "No expense rows should be produced when totalSpent <= 0")

        // Park still resolves independently
        let parkTotal = DistrictDataHelper.districtTotal(for: "savings", currentCity: city)
        XCTAssertEqual(parkTotal, 500)
        let parkPills = DistrictDataHelper.districtBuildingPills(for: "savings", currentCity: city, transactions: txs, language: .hebrew)
        XCTAssertEqual(parkPills.first?.amount, 500)
    }

    // 8. Health / Finance / Misc / Uncategorized transactions → amount must not disappear from All City breakdown.
    func testCivicCategoriesIncludedInBreakdown() {
        let txs = [
            makeTx(category: .health, amount: 120),
            makeTx(category: .finance, amount: 30),
            makeTx(category: .miscellaneous, amount: 75),
            makeTx(category: .other, amount: 45)
        ]
        let city = makeCity(transactions: txs)
        let breakdown = DistrictDataHelper.expenseBreakdown(for: city, language: .hebrew)

        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown.first?.id, "civic")
        let expectedCivicTotal = 120.0 + 30.0 + 75.0 + 45.0
        XCTAssertEqual(breakdown.first?.amount, expectedCivicTotal)
        XCTAssertEqual(breakdown.first?.amount, city.totalSpent)
        XCTAssertEqual(breakdown.first?.percentage, 100)
    }

    // 9. Total of expense rows matches currentCity.totalSpent, and sum(percentages) == 100.
    func testSumOfRowsMatchesTotalSpentAndPercentagesSumTo100() {
        let txs = [
            makeTx(category: .food, amount: 784),
            makeTx(category: .shopping, amount: 442),
            makeTx(category: .housing, amount: 1800),
            makeTx(category: .transport, amount: 212),
            makeTx(category: .savings, amount: 900)
        ]
        let city = makeCity(transactions: txs)
        let breakdown = DistrictDataHelper.expenseBreakdown(for: city, language: .hebrew)

        let sumAmounts = breakdown.reduce(0.0) { $0 + $1.amount }
        XCTAssertEqual(sumAmounts, city.totalSpent, accuracy: 0.001)
        XCTAssertEqual(city.totalSpent, 3238, accuracy: 0.001)

        let sumPercentages = breakdown.reduce(0) { $0 + $1.percentage }
        XCTAssertEqual(sumPercentages, 100)

        // Verify Transport is present and correctly calculated
        let transportItem = breakdown.first { $0.id == "transport" }
        XCTAssertNotNil(transportItem)
        XCTAssertEqual(transportItem?.amount, 212)

        // Savings must not be present
        XCTAssertFalse(breakdown.contains { $0.id == "savings" })
    }

    // 10. Selecting The Park from top selector still works exactly as before.
    func testTheParkTopSelectorIndependence() {
        let txs = [
            makeTx(category: .food, amount: 200),
            makeTx(category: .savings, amount: 650)
        ]
        let city = makeCity(transactions: txs)

        let parkNameHe = DistrictDataHelper.districtName(for: "savings", language: .hebrew)
        let parkNameEn = DistrictDataHelper.districtName(for: "savings", language: .english)
        XCTAssertEqual(parkNameHe, "הפארק")
        XCTAssertEqual(parkNameEn, "The Park")

        let parkTotal = DistrictDataHelper.districtTotal(for: "savings", currentCity: city)
        XCTAssertEqual(parkTotal, 650)

        let parkPills = DistrictDataHelper.districtBuildingPills(for: "savings", currentCity: city, transactions: txs, language: .hebrew)
        XCTAssertEqual(parkPills.count, 1)
        XCTAssertEqual(parkPills.first?.id, "savings_sanctuary")
        XCTAssertEqual(parkPills.first?.amount, 650)
    }
}
