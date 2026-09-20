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
    /// How the park looks this month, from stressed/dry to healthy/lush.
    /// 0 = parched, 1 = lush. A normally-run month sits near 0.78.
    /// This is visual financial-state information and resets with the month.
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

/// Presentation choice only; all worlds consume the same financial simulation.
public enum CityMapStyle: String, CaseIterable, Identifiable, Sendable {
    case urban, medieval, arctic, israel, future
    public var id: String { rawValue }
    public var resourceName: String { self == .medieval ? "diorama_medieval" : "diorama" }

    public func title(isHebrew: Bool) -> String {
        switch self {
        case .urban: return isHebrew ? "עיר מודרנית" : "Modern city"
        case .medieval: return isHebrew ? "עיר ימי הביניים" : "Medieval city"
        case .arctic: return isHebrew ? "עיר הקרח" : "Arctic city"
        case .israel: return isHebrew ? "עיר ישראלית" : "Israeli city"
        case .future: return isHebrew ? "עיר העתיד" : "Future city"
        }
    }
}

/// Per-month world storage.
///
/// Each month can have a different visual world. The choice is saved in a JSON dictionary
/// keyed by "YYYY-MM" so changing October never touches September.
///
/// Storage layout (v2):
///   Key: "spent.city.monthlyMapSelections.v2"
///   Value: JSON-encoded [String: String] e.g. {"2026-09": "medieval", "2026-10": "urban"}
///
/// Historical months with no saved record fall back to .urban, preserving old city history.
enum CityMapSelection {
    static let preferenceKey = "spent.city.monthlyMapSelections.v2"
    static let legacyPreferenceKey = "spent.city.mapSelection"

    // MARK: - Month ID

    static func monthID(
        _ date: Date,
        calendar: Calendar = .current
    ) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(
            format: "%04d-%02d",
            parts.year ?? 0,
            parts.month ?? 0
        )
    }

    // MARK: - Read

    static func selections(
        defaults: UserDefaults = .standard
    ) -> [String: String] {
        guard
            let data = defaults.data(forKey: preferenceKey),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    /// Returns the explicitly saved style for this month, or nil if none has been chosen.
    /// Use `resolvedStyle(for:)` for a value that always has an answer.
    static func selectedStyle(
        for date: Date,
        defaults: UserDefaults = .standard
    ) -> CityMapStyle? {
        let values = selections(defaults: defaults)
        guard
            let raw = values[monthID(date)],
            let style = CityMapStyle(rawValue: raw)
        else {
            return nil
        }
        return style
    }

    /// Returns the saved style for this month, or .urban for months with no record.
    /// This is the right call site for the city renderer — it always returns something.
    static func resolvedStyle(
        for date: Date,
        defaults: UserDefaults = .standard
    ) -> CityMapStyle {
        selectedStyle(for: date, defaults: defaults) ?? .urban
    }

    static func hasSelection(
        for date: Date,
        defaults: UserDefaults = .standard
    ) -> Bool {
        selectedStyle(for: date, defaults: defaults) != nil
    }

    // MARK: - Write

    /// Saves the user's world choice for a specific month only.
    /// Never touches any other month's record.
    static func save(
        _ style: CityMapStyle,
        for date: Date,
        defaults: UserDefaults = .standard
    ) {
        var values = selections(defaults: defaults)
        values[monthID(date)] = style.rawValue
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: preferenceKey)
    }

    // MARK: - Legacy Migration

    /// Runs once: if the user has an old "YYYY-MM|style" preference and no v2 data,
    /// migrates that single explicit month. Does NOT propagate to future months.
    static func migrateLegacyIfNeeded(defaults: UserDefaults = .standard) {
        guard
            selections(defaults: defaults).isEmpty,
            let legacy = defaults.string(forKey: legacyPreferenceKey),
            !legacy.isEmpty
        else {
            return
        }
        let parts = legacy.split(separator: "|")
        guard
            parts.count == 2,
            let style = CityMapStyle(rawValue: String(parts[1]))
        else {
            return
        }
        var values: [String: String] = [:]
        values[String(parts[0])] = style.rawValue
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: preferenceKey)
    }
}
