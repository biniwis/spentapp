import Foundation

/// A derived visual state, never a stored transaction or a second financial ledger.
/// Amount controls the anchor building; repetition controls street life and extra places.
public struct CityVenueState: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let amount: Double
    public let share: Double
    public let purchaseCount: Int
    public let activeDays: Int
    public let merchantCount: Int
    public let activity: Double
    public let presence: Double
    public let additionalPlaces: Int
}

/// A small value type keeps the rules independent of SwiftData, WebKit and rendering.
public struct CityLifeEvent: Sendable {
    public let id: String
    public let venueID: String
    public let amount: Double
    public let date: Date
    public let merchant: String

    public init(id: String, venueID: String, amount: Double, date: Date, merchant: String) {
        self.id = id
        self.venueID = venueID
        self.amount = amount
        self.date = date
        self.merchant = merchant
    }
}

public enum CityLifeEngine {
    /// Existing financial destination IDs; instances in the renderer reference these IDs.
    public static let venueIDs = [
        "food_bistro", "food_super", "food_coffee", "food_wolt",
        "shop_boutique", "shop_tech", "shop_travel", "shop_arcade",
        "house_tower", "house_util", "house_subs", "trans_station",
        "health_pharmacy", "finance_bank", "museum_curiosities", "city_sorting_hub"
    ]

    public static func states(
        for events: [CityLifeEvent], in month: Date, calendar: Calendar = .current
    ) -> [CityVenueState] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        var seen = Set<String>()
        var grouped: [String: [CityLifeEvent]] = [:]
        for event in events {
            guard event.amount.isFinite, event.date >= interval.start, event.date < interval.end,
                  venueIDs.contains(event.venueID), seen.insert(event.id).inserted else { continue }
            grouped[event.venueID, default: []].append(event)
        }
        let amounts = Dictionary(uniqueKeysWithValues: venueIDs.map { id in
            (id, max(0, (grouped[id] ?? []).reduce(0.0) { $0 + $1.amount }))
        })
        let total = amounts.values.reduce(0, +)
        return venueIDs.map { id in
            let purchases = (grouped[id] ?? []).filter { $0.amount > 0 }
            let days = Set(purchases.map { calendar.startOfDay(for: $0.date) }).count
            let merchants = Set(purchases.map {
                $0.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            }.filter { !$0.isEmpty }).count
            let amount = amounts[id] ?? 0
            let share = total > 0 ? amount / total : 0
            // No amount thresholds masquerading as visits. One expensive purchase can
            // have a prominent building while remaining a quiet, single-visit place.
            let repetition = 0.55 * (1 - exp(-Double(purchases.count) / 8))
                + 0.45 * (1 - exp(-Double(days) / 5))
            let activity = amount > 0 ? min(1, repetition) : 0
            let presence = amount > 0 ? min(1, activity * 0.78 + sqrt(share) * 0.22) : 0
            var extra = presence >= 0.78 ? 3 : presence >= 0.55 ? 2 : presence >= 0.32 ? 1 : 0
            // A single expensive purchase is not an established neighbourhood habit.
            if purchases.count < 3 || days < 2 { extra = 0 }
            // Recurring commitments say more about the neighbourhood than footfall.
            // They may add modest residential frontage, never a crowd of rent shoppers.
            if id == "house_tower" { extra = amount > 0 ? (share >= 0.40 ? 2 : share >= 0.20 ? 1 : 0) : 0 }
            if ["house_util", "house_subs", "finance_bank", "city_sorting_hub"].contains(id) { extra = 0 }
            return CityVenueState(id: id, amount: amount, share: share,
                purchaseCount: purchases.count, activeDays: days, merchantCount: merchants,
                activity: activity, presence: presence, additionalPlaces: extra)
        }
    }
}
