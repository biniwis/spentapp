import Foundation
import SwiftUI

/// Behavioral habits extracted from the transaction stream to drive the Living Map
public struct BehavioralHabits: Sendable {
    public var woltDeliveryCount: Int
    public var coffeeCount: Int
    public var onlinePackagesCount: Int
    public var hasTravelOrFlight: Bool
    public var activeSubscriptionsCount: Int
    public var totalGroceryBags: Int
    
    public init(
        woltDeliveryCount: Int = 0,
        coffeeCount: Int = 0,
        onlinePackagesCount: Int = 0,
        hasTravelOrFlight: Bool = false,
        activeSubscriptionsCount: Int = 0,
        totalGroceryBags: Int = 0
    ) {
        self.woltDeliveryCount = woltDeliveryCount
        self.coffeeCount = coffeeCount
        self.onlinePackagesCount = onlinePackagesCount
        self.hasTravelOrFlight = hasTravelOrFlight
        self.activeSubscriptionsCount = activeSubscriptionsCount
        self.totalGroceryBags = totalGroceryBags
    }
}

/// Computed model for a specific month's diorama state and living city simulation.
public struct MonthlyCity: Identifiable, Sendable {
    public let id: String // Format: "YYYY-MM"
    public let monthDate: Date
    public var totalSpent: Double
    public var totalSavings: Double
    /// The amount that fills the savings park completely — a fifth of the user's monthly
    /// baseline. Zero when there is no baseline yet.
    public var savingsTarget: Double
    /// What the savings figure is actually measuring, so the UI can explain it.
    public var savingsBasis: CitySimulationEngine.SavingsBasis
    /// How the park looks, 0 parched to 1 lush. A normally-run month sits near 0.78.
    /// This is the month's verdict, and it resets with the month.
    public var parkHealth: Double
    /// Everything put aside since the user started, across every month. Unlike every other
    /// figure here this one does not reset — it is what gives the reserve its size.
    public var lifetimeSavings: Double
    public var categoryTotals: [SpendingCategory: Double]
    public var buildingTotals: [String: Double]
    public var tiles: [BuildingTile]
    public var headlineStory: String
    public var habits: BehavioralHabits
    
    public var monthDisplayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: monthDate)
    }
    
    public init(
        monthDate: Date,
        totalSpent: Double,
        totalSavings: Double,
        savingsTarget: Double = 0,
        savingsBasis: CitySimulationEngine.SavingsBasis = .noBaseline,
        parkHealth: Double = CitySimulationEngine.healthyParkLevel,
        lifetimeSavings: Double = 0,
        categoryTotals: [SpendingCategory: Double] = [:],
        buildingTotals: [String: Double] = [:],
        tiles: [BuildingTile] = [],
        headlineStory: String = "",
        habits: BehavioralHabits = BehavioralHabits()
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.id = formatter.string(from: monthDate)
        self.monthDate = monthDate
        self.totalSpent = totalSpent
        self.totalSavings = totalSavings
        self.savingsTarget = savingsTarget
        self.savingsBasis = savingsBasis
        self.parkHealth = parkHealth
        self.lifetimeSavings = lifetimeSavings
        self.categoryTotals = categoryTotals
        self.buildingTotals = buildingTotals
        self.tiles = tiles
        self.headlineStory = headlineStory
        self.habits = habits
    }
}
