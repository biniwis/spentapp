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

    public func subtitle(isHebrew: Bool) -> String {
        switch self {
        case .urban: return isHebrew ? "גורדי שחקים, שדרות וחיים אורבניים שוקקים" : "Skyscrapers, avenues, and vibrant urban life"
        case .medieval: return isHebrew ? "טירות אבן, שווקים עתיקים וסמטאות היסטוריות" : "Stone castles, ancient markets, and historic alleys"
        case .arctic: return isHebrew ? "כיפות קרח, גשרי שלג ואורות קוטב זוהרים" : "Ice domes, snow bridges, and glowing northern lights"
        case .israel: return isHebrew ? "בנייני באוהאוס, עצי דקל ושדרות חמימות" : "Bauhaus buildings, palm trees, and warm boulevards"
        case .future: return isHebrew ? "מגדלים מרחפים, רכבות מגנטיות ואורות ניאון" : "Floating towers, maglev transit, and neon lights"
        }
    }
}

// MARK: - Per-month world storage

/// Per-month world storage with two-phase lifecycle: *assigned* → *confirmed*.
///
/// **Lifecycle:**
/// 1. At the start of a new month, `ensureAssignedStyle(for:)` copies the previous
///    month's style (or `.urban`) and stores it as *unconfirmed* (`confirmed: false`).
/// 2. The picker shows the inherited style as its initial selection.
/// 3. When the user taps "Choose", `confirmWorldChoice(_:for:)` writes the final style
///    and sets `confirmed: true` — the picker is not shown again this month.
///
/// **Storage layout (v2):**
///   Key: `"spent.city.monthlyMapSelections.v2"`
///   Value: JSON-encoded `[String: MonthEntry]`
///   e.g. `{"2026-09": {"style":"medieval","confirmed":true}, "2026-10": {"style":"medieval","confirmed":false}}`
///
/// **Backward compatibility:**
///   Old format was `[String: String]`. `loadEntries` reads both formats and
///   treats any pre-existing String entry as confirmed (the user already chose it).
///   `.future` is never shown in the picker but is a valid `CityMapStyle` case.
enum CityMapSelection {

    // MARK: - Constants

    static let preferenceKey       = "spent.city.monthlyMapSelections.v2"
    static let legacyPreferenceKey = "spent.city.mapSelection"

    /// Worlds presented in the monthly picker. `.future` is kept as a Swift case
    /// but withheld from the picker until it is ready for release.
    static let pickerWorlds: [CityMapStyle] = [.urban, .medieval, .arctic, .israel]

    // MARK: - Internal entry type

    private struct MonthEntry: Codable {
        var style: String
        var confirmed: Bool
    }

    // MARK: - Month ID

    static func monthID(
        _ date: Date,
        calendar: Calendar = .current
    ) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    // MARK: - Private storage helpers

    private static func loadEntries(defaults: UserDefaults) -> [String: MonthEntry] {
        guard let data = defaults.data(forKey: preferenceKey) else { return [:] }

        // Try new format first
        if let decoded = try? JSONDecoder().decode([String: MonthEntry].self, from: data) {
            return decoded
        }

        // Fall back to legacy flat String format and upgrade in-place
        if let flat = try? JSONDecoder().decode([String: String].self, from: data) {
            var upgraded: [String: MonthEntry] = [:]
            for (k, v) in flat {
                upgraded[k] = MonthEntry(style: v, confirmed: true)
            }
            saveEntries(upgraded, defaults: defaults)
            return upgraded
        }

        return [:]
    }

    private static func saveEntries(_ entries: [String: MonthEntry], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: preferenceKey)
    }

    // MARK: - Read (backward-compatible surface)

    /// Flat `[String: String]` view for callers that only need the style rawValue.
    static func selections(defaults: UserDefaults = .standard) -> [String: String] {
        loadEntries(defaults: defaults).mapValues { $0.style }
    }

    /// Returns the explicitly saved style for this month, or nil if none has been stored.
    /// Use `resolvedStyle(for:)` for a value that always has an answer.
    static func selectedStyle(
        for date: Date,
        defaults: UserDefaults = .standard
    ) -> CityMapStyle? {
        let entries = loadEntries(defaults: defaults)
        guard let entry = entries[monthID(date)],
              let style = CityMapStyle(rawValue: entry.style) else { return nil }
        return style
    }

    /// Returns the saved style for this month, or `.urban` for months with no record.
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

    // MARK: - Lifecycle API

    /// Returns the style assigned to this month (inherited or confirmed).
    /// Does **not** write anything.
    static func assignedStyle(
        for date: Date,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) -> CityMapStyle {
        let entries = loadEntries(defaults: defaults)
        let key = monthID(date)
        if let entry = entries[key],
           let style = CityMapStyle(rawValue: entry.style) {
            return style
        }
        return mostRecentConfirmedStyle(before: date, entries: entries, calendar: calendar)
    }

    /// Ensures this month has a stored entry, inheriting from the previous confirmed month
    /// if needed. Writes the entry as *unconfirmed* so the picker will still be presented.
    /// If a confirmed entry already exists, it is left untouched.
    @discardableResult
    static func ensureAssignedStyle(
        for date: Date,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) -> CityMapStyle {
        var entries = loadEntries(defaults: defaults)
        let key = monthID(date)
        if let existing = entries[key],
           let style = CityMapStyle(rawValue: existing.style) {
            return style
        }
        let inherited = mostRecentConfirmedStyle(before: date, entries: entries, calendar: calendar)
        entries[key] = MonthEntry(style: inherited.rawValue, confirmed: false)
        saveEntries(entries, defaults: defaults)
        return inherited
    }

    /// Returns `true` when the user has not yet confirmed a world choice for this month.
    /// A month that was auto-inherited (via `ensureAssignedStyle`) is still pending.
    static func isWorldChoicePending(
        for date: Date,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let entries = loadEntries(defaults: defaults)
        guard let entry = entries[monthID(date)] else { return true }
        return !entry.confirmed
    }

    /// Saves the user's explicit world choice for a specific month and marks it confirmed.
    /// Never touches any other month's record.
    static func confirmWorldChoice(
        _ style: CityMapStyle,
        for date: Date,
        defaults: UserDefaults = .standard
    ) {
        var entries = loadEntries(defaults: defaults)
        entries[monthID(date)] = MonthEntry(style: style.rawValue, confirmed: true)
        saveEntries(entries, defaults: defaults)
    }

    // MARK: - Write (backward-compatible)

    /// Saves a style for a specific month and marks it confirmed.
    /// Prefer `confirmWorldChoice(_:for:)` for explicit user selections.
    static func save(
        _ style: CityMapStyle,
        for date: Date,
        defaults: UserDefaults = .standard
    ) {
        confirmWorldChoice(style, for: date, defaults: defaults)
    }

    // MARK: - Private helpers

    private static func mostRecentConfirmedStyle(
        before date: Date,
        entries: [String: MonthEntry],
        calendar: Calendar
    ) -> CityMapStyle {
        var candidate = date
        for _ in 0 ..< 24 {
            guard let prev = calendar.date(byAdding: .month, value: -1, to: candidate) else { break }
            candidate = prev
            let key = monthID(prev, calendar: calendar)
            if let entry = entries[key],
               entry.confirmed,
               let style = CityMapStyle(rawValue: entry.style) {
                return style
            }
        }
        return .urban
    }

    // MARK: - Legacy Migration

    /// Runs once: if the user has an old "YYYY-MM|style" preference and no v2 data,
    /// migrates that single explicit month as confirmed. Does NOT propagate to future months.
    static func migrateLegacyIfNeeded(defaults: UserDefaults = .standard) {
        guard
            selections(defaults: defaults).isEmpty,
            let legacy = defaults.string(forKey: legacyPreferenceKey),
            !legacy.isEmpty
        else { return }
        let parts = legacy.split(separator: "|")
        guard
            parts.count == 2,
            let style = CityMapStyle(rawValue: String(parts[1]))
        else { return }
        var entries = loadEntries(defaults: defaults)
        entries[String(parts[0])] = MonthEntry(style: style.rawValue, confirmed: true)
        saveEntries(entries, defaults: defaults)
    }
}
