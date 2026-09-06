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
