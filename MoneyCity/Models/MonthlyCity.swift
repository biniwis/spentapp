import Foundation
import SwiftUI

/// Behavioral habits extracted from the transaction stream to drive the Living Map
public struct BehavioralHabits: Sendable, Equatable {
    public var woltDeliveryCount: Int
    /// Distinct calendar days on which at least one delivery transaction occurred.
    public var woltActiveDays: Int
    /// Total amount spent on delivery venues this month.
    public var woltTotalSpend: Double
    public var coffeeCount: Int
    public var onlinePackagesCount: Int
    public var hasTravelOrFlight: Bool
    public var activeSubscriptionsCount: Int
    public var totalGroceryBags: Int
    /// Computed delivery intensity — carries tier, frequency score and spend score.
    public var deliveryIntensity: DeliveryIntensity

    public init(
        woltDeliveryCount: Int = 0,
        woltActiveDays: Int = 0,
        woltTotalSpend: Double = 0,
        coffeeCount: Int = 0,
        onlinePackagesCount: Int = 0,
        hasTravelOrFlight: Bool = false,
        activeSubscriptionsCount: Int = 0,
        totalGroceryBags: Int = 0,
        deliveryIntensity: DeliveryIntensity = DeliveryIntensityEngine.compute(
            orderCount: 0, totalSpend: 0, activeDays: 0, elapsedDays: 1)
    ) {
        self.woltDeliveryCount = woltDeliveryCount
        self.woltActiveDays = woltActiveDays
        self.woltTotalSpend = woltTotalSpend
        self.coffeeCount = coffeeCount
        self.onlinePackagesCount = onlinePackagesCount
        self.hasTravelOrFlight = hasTravelOrFlight
        self.activeSubscriptionsCount = activeSubscriptionsCount
        self.totalGroceryBags = totalGroceryBags
        self.deliveryIntensity = deliveryIntensity
    }
}

/// The visual weight of a district in the living city. A district is always present;
/// spending only determines how active and prominent it becomes this month.
public enum CityDistrictProminence: String, Codable, Sendable {
    case quiet
    case active
    case developed
    case dominant
}

/// A presentation-ready reading of one financial category for the city renderer.
/// Keeping this derived state in Swift makes the city rules testable and prevents the
/// WebGL scene from having to invent financial meaning from raw transactions.
public struct CityDistrictState: Identifiable, Equatable, Sendable {
    public let id: String
    public let amount: Double
    public let share: Double
    public let activity: Double
    public let prominence: CityDistrictProminence

    public init(
        id: String,
        amount: Double,
        share: Double,
        activity: Double,
        prominence: CityDistrictProminence
    ) {
        self.id = id
        self.amount = amount
        self.share = share
        self.activity = activity
        self.prominence = prominence
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
    /// How the park looks, 0 parched to 1 lush. A normally-run month sits near 0.78.
    /// This is the month's verdict, and it resets with the month.
    public var parkHealth: Double
    /// Day-to-day spending this month — everything except rent, bills, subscriptions and
    /// savings. This is what the garden is measured on.
    public var everydaySpent: Double
    /// The part of the plan not already committed to fixed costs, which is what
    /// `everydaySpent` is compared against.
    public var everydayBaseline: Double
    public var categoryTotals: [SpendingCategory: Double]
    public var buildingTotals: [String: Double]
    public var districtStates: [CityDistrictState]
    public var venueStates: [CityVenueState]
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
        parkHealth: Double = CitySimulationEngine.healthyParkLevel,
        everydaySpent: Double = 0,
        everydayBaseline: Double = 0,
        categoryTotals: [SpendingCategory: Double] = [:],
        buildingTotals: [String: Double] = [:],
        districtStates: [CityDistrictState] = [],
        venueStates: [CityVenueState] = [],
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
        self.parkHealth = parkHealth
        self.everydaySpent = everydaySpent
        self.everydayBaseline = everydayBaseline
        self.categoryTotals = categoryTotals
        self.buildingTotals = buildingTotals
        self.districtStates = districtStates
        self.venueStates = venueStates
        self.tiles = tiles
        self.headlineStory = headlineStory
        self.habits = habits
    }
}
