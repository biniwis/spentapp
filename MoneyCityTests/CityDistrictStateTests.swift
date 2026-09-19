import XCTest
@testable import MoneyCity

final class CityDistrictStateTests: XCTestCase {
    func testEmptyMonthKeepsEveryDistrictQuiet() {
        let states = CitySimulationEngine.districtStates(for: [:])

        XCTAssertEqual(states.count, SpendingCategory.primaryCategories.count - 1)
        XCTAssertTrue(states.allSatisfy { $0.prominence == .quiet && $0.amount == 0 && $0.share == 0 })
    }

    func testHousingAndFoodProfilesProduceDifferentDominantDistricts() {
        let housingCity = CitySimulationEngine.districtStates(for: [
            .housing: 4_500,
            .food: 800,
            .transport: 250
        ])
        let foodCity = CitySimulationEngine.districtStates(for: [
            .housing: 700,
            .food: 3_000,
            .entertainment: 900
        ])

        XCTAssertEqual(housingCity.first(where: { $0.id == SpendingCategory.housing.rawValue })?.prominence, .dominant)
        XCTAssertEqual(foodCity.first(where: { $0.id == SpendingCategory.food.rawValue })?.prominence, .dominant)
        XCTAssertEqual(housingCity.first(where: { $0.id == SpendingCategory.food.rawValue })?.prominence, .developed)
        XCTAssertEqual(foodCity.first(where: { $0.id == SpendingCategory.housing.rawValue })?.prominence, .developed)
    }

    func testLegacyFoodRowsJoinTheFoodDistrict() {
        let states = CitySimulationEngine.districtStates(for: [
            .groceries: 700,
            .coffee: 200,
            .transport: 100
        ])

        let food = states.first(where: { $0.id == SpendingCategory.food.rawValue })
        XCTAssertEqual(food?.amount, 900)
        XCTAssertEqual(food?.prominence, .dominant)
    }
}

final class CitySimulationEngineTests: XCTestCase {
    func testCityHallProgressUsesBudgetThenHistoryAndExcludesSavings() {
        let date = Date()
        let transactions = [
            Transaction(amount: 1_000, merchant: "Food", category: .food, timestamp: date),
            Transaction(amount: 9_000, merchant: "Savings", category: .savings, timestamp: date)
        ]
        func progress(budget: Double, history: Double) -> Double {
            CitySimulationEngine.shared.generateCity(for: date, transactions: transactions,
                estimatedMonthlyBudget: budget, typicalMonthlySpend: history).cityHallProgress
        }
        XCTAssertEqual(progress(budget: 4_000, history: 20_000), 0.25)
        XCTAssertEqual(progress(budget: 0, history: 2_000), 0.5)
        XCTAssertEqual(progress(budget: 0, history: 0), 0)
    }

    func testCityHallProgressBoundariesAndRefunds() {
        let date = Date()
        for (amount, expected) in [(0.0, 0.0), (600, 0.15), (1_600, 0.4), (3_000, 0.75), (8_000, 1), (-100, 0)] {
            let city = CitySimulationEngine.shared.generateCity(for: date,
                transactions: [Transaction(amount: amount, merchant: "Food", category: .food, timestamp: date)],
                estimatedMonthlyBudget: 4_000)
            XCTAssertEqual(city.cityHallProgress, expected, accuracy: 0.000001)
        }
    }
}
