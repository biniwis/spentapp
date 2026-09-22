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
        case .urban: return isHebrew ? "קלאסית" : "Classic"
        case .medieval: return isHebrew ? "ימי הביניים" : "Medieval"
        case .arctic: return isHebrew ? "אסקימואים" : "Eskimo"
        case .israel: return isHebrew ? "ישראלית" : "Israeli"
        case .future: return isHebrew ? "עתידנית" : "Future"
        }
    }

    public func subtitle(isHebrew: Bool) -> String {
        switch self {
        case .urban: return isHebrew ? "בתי קפה, שדרות נעימות ואדריכלות עירונית מודרנית" : "Charming boulevards, cafes, and modern architecture"
        case .medieval: return isHebrew ? "טירות אבן, שווקים עתיקים וסמטאות היסטוריות" : "Stone castles, ancient markets, and historic alleys"
        case .arctic: return isHebrew ? "איגלו, שלג ואורות קוטב זוהרים" : "Snow igloos, frost domes, and glowing northern lights"
        case .israel: return isHebrew ? "בנייני באוהאוס, עצי דקל ושדרות חמימות" : "Bauhaus buildings, palm trees, and warm boulevards"
        case .future: return isHebrew ? "מגדלים מרחפים, רכבות מגנטיות ואורות ניאון" : "Floating towers, maglev transit, and neon lights"
        }
    }
}

// MARK: - Global Map Style Storage

/// Global map style user preference, functioning like Theme:
/// - New users automatically default to Classic (`.urban`).
/// - Map style is a persistent global display preference, independent of months.
/// - Changing the map style updates the city display immediately across all screens.
/// - Existing users with legacy monthly or onboarding selections are migrated seamlessly.
public enum CityMapSelection {

    // MARK: - Constants

    /// Global preference key storing the user's selected map style rawValue.
    public static let preferenceKey       = "spent.city.mapStyle"
    public static let legacyMonthlyKey    = "spent.city.monthlyMapSelections.v2"
    public static let legacyPreferenceKey = "spent.city.mapSelection"
    public static let legacyOnboardingKey = "spent.onboarding.mapStyle"

    /// Worlds presented in the map style picker. `.future` is kept as a Swift case
    /// but withheld from the picker until it is ready for release.
    public static let pickerWorlds: [CityMapStyle] = [.urban, .medieval, .arctic, .israel]

    // MARK: - Legacy compatibility entry type

    public struct MonthEntry: Codable, Equatable {
        public var style: String
        public var confirmed: Bool

        public init(style: String, confirmed: Bool = true) {
            self.style = style
            self.confirmed = confirmed
        }
    }

    // MARK: - Read

    /// Returns the user's current global map style.
    /// If no style has been set yet, migrates any legacy monthly or onboarding selection,
    /// or defaults to `.urban` (Classic) for new users.
    public static func currentStyle(defaults: UserDefaults = .standard) -> CityMapStyle {
        if let raw = defaults.string(forKey: preferenceKey),
           let style = CityMapStyle(rawValue: raw) {
            return style
        }

        // Migrate legacy data if available
        if let migrated = migrateLegacy(defaults: defaults) {
            save(migrated, defaults: defaults)
            return migrated
        }

        return .urban
    }

    /// Whether the user has an explicitly chosen map style (or legacy selection).
    public static func hasCustomStyle(defaults: UserDefaults = .standard) -> Bool {
        if let raw = defaults.string(forKey: preferenceKey), CityMapStyle(rawValue: raw) != nil {
            return true
        }
        if defaults.data(forKey: legacyMonthlyKey) != nil {
            return true
        }
        if defaults.string(forKey: legacyOnboardingKey) != nil {
            return true
        }
        if defaults.string(forKey: legacyPreferenceKey) != nil {
            return true
        }
        return false
    }

    // MARK: - Write

    /// Saves the user's global map style preference.
    public static func save(_ style: CityMapStyle, defaults: UserDefaults = .standard) {
        defaults.set(style.rawValue, forKey: preferenceKey)
    }

    // MARK: - Migration from legacy systems

    /// Migrates existing user's selection from legacy monthly or onboarding storage.
    @discardableResult
    public static func migrateLegacy(defaults: UserDefaults = .standard) -> CityMapStyle? {
        // 1. Check v2 monthly selections dictionary
        if let data = defaults.data(forKey: legacyMonthlyKey) {
            if let entries = try? JSONDecoder().decode([String: MonthEntry].self, from: data), !entries.isEmpty {
                // Find entry for current month or latest sorted key
                let nowKey = monthID(Date())
                if let currentEntry = entries[nowKey], let style = CityMapStyle(rawValue: currentEntry.style) {
                    return style
                }
                let sortedKeys = entries.keys.sorted(by: >)
                for key in sortedKeys {
                    if let entry = entries[key], let style = CityMapStyle(rawValue: entry.style) {
                        return style
                    }
                }
            } else if let flat = try? JSONDecoder().decode([String: String].self, from: data), !flat.isEmpty {
                let nowKey = monthID(Date())
                if let currentVal = flat[nowKey], let style = CityMapStyle(rawValue: currentVal) {
                    return style
                }
                let sortedKeys = flat.keys.sorted(by: >)
                for key in sortedKeys {
                    if let val = flat[key], let style = CityMapStyle(rawValue: val) {
                        return style
                    }
                }
            }
        }

        // 2. Check onboarding map style
        if let onboardingRaw = defaults.string(forKey: legacyOnboardingKey),
           let style = CityMapStyle(rawValue: onboardingRaw) {
            return style
        }

        // 3. Check oldest single key "YYYY-MM|style"
        if let legacy = defaults.string(forKey: legacyPreferenceKey), !legacy.isEmpty {
            let parts = legacy.split(separator: "|")
            if parts.count == 2, let style = CityMapStyle(rawValue: String(parts[1])) {
                return style
            }
        }

        return nil
    }

    public static func migrateLegacyIfNeeded(defaults: UserDefaults = .standard) {
        _ = currentStyle(defaults: defaults)
    }

    // MARK: - Helpers

    private static func monthID(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    // MARK: - Backward Compatibility Surface

    public static func resolvedStyle(
        for date: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> CityMapStyle {
        currentStyle(defaults: defaults)
    }

    public static func selectedStyle(
        for date: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> CityMapStyle? {
        currentStyle(defaults: defaults)
    }

    public static func hasSelection(
        for date: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> Bool {
        hasCustomStyle(defaults: defaults)
    }

    public static func save(
        _ style: CityMapStyle,
        for date: Date,
        defaults: UserDefaults = .standard
    ) {
        save(style, defaults: defaults)
    }

    public static func confirmWorldChoice(
        _ style: CityMapStyle,
        for date: Date = Date(),
        defaults: UserDefaults = .standard
    ) {
        save(style, defaults: defaults)
    }
}

