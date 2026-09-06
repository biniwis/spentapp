import Foundation

/// Gift cadence is independent of spending totals; eligibility also requires real weekly
/// progress. Legacy decorations remain saved, but are no longer offered.
public enum CityCompanions {
    public static let ids: Set<String> = ["pet_cat_rooftop", "pet_golden_dog", "resident_artist", "resident_skater", "resident_musician", "resident_balloon"]
    public static func nextDate(firstUse: Date, lastReward: Date?, calendar: Calendar = .current) -> Date {
        let start = max(firstUse, lastReward ?? firstUse)
        return calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86400)
    }
    public static func isEligible(now: Date, firstUse: Date, lastReward: Date?, calendar: Calendar = .current) -> Bool {
        now >= nextDate(firstUse: firstUse, lastReward: lastReward, calendar: calendar)
    }
    public struct Expense {
        public let id: String
        public let amount: Double
        public let date: Date
        public let category: String
        public init(id: String, amount: Double, date: Date, category: String) {
            self.id = id; self.amount = amount; self.date = date; self.category = category
        }
    }
    public static func weeklyTotals(_ events: [Expense], now: Date, calendar: Calendar = .current) -> (current: Double, previous: Double) {
        let currentStart = calendar.date(byAdding: .day, value: -7, to: now)!
        let previousStart = calendar.date(byAdding: .day, value: -14, to: now)!
        let excluded: Set<String> = ["housing", "subscriptions", "health", "finance", "savings"]
        var seen = Set<String>(), current = 0.0, previous = 0.0
        for event in events {
            guard event.amount.isFinite, event.amount > 0, event.date <= now,
                  event.date >= previousStart, !excluded.contains(event.category),
                  seen.insert(event.id).inserted else { continue }
            if event.date >= currentStart { current += event.amount } else { previous += event.amount }
        }
        return (current, previous)
    }
}

/// Inventory placement rules are independent of SwiftData and can be tested directly.
public struct CityPlacement: Sendable {
    public let itemId: String
    public let slotId: String?
    public let isApplied: Bool
    public init(itemId: String, slotId: String?, isApplied: Bool) {
        self.itemId = itemId; self.slotId = slotId; self.isApplied = isApplied
    }
}

/// Curated stable locations; legacy IDs resolve without changing the saved inventory.
public struct CitySlot: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let districtId: String
    public let icon: String
    public let defaultItemId: String
    public init(id: String, name: String, subtitle: String, districtId: String, icon: String, defaultItemId: String) {
        self.id = id; self.name = name; self.subtitle = subtitle
        self.districtId = districtId; self.icon = icon; self.defaultItemId = defaultItemId
    }
    public static let allSlots: [CitySlot] = [
        CitySlot(id: "slot_tree_sakura", name: "גן הפריחה", subtitle: "פינת טבע בקצה השמורה", districtId: "savings", icon: "leaf.fill", defaultItemId: "tree_sakura"),
        CitySlot(id: "slot_pet_golden_dog", name: "שביל האגם", subtitle: "פינה שקטה לצד המים", districtId: "savings", icon: "pawprint.fill", defaultItemId: "pet_golden_dog"),
        CitySlot(id: "slot_repair_bench", name: "פינת המנוחה", subtitle: "רחבת ישיבה ליד השמורה", districtId: "savings", icon: "chair.lounge.fill", defaultItemId: "repair_bench"),
        CitySlot(id: "slot_park_bridge", name: "גשר האגם", subtitle: "שדרוג הגשר הקיים מעל המים", districtId: "savings", icon: "building.2.fill", defaultItemId: "park_bridge"),
        CitySlot(id: "slot_fountain_marble", name: "מזרקת הכיכר", subtitle: "שדרוג המזרקה המרכזית", districtId: "city", icon: "drop.fill", defaultItemId: "fountain_marble"),
        CitySlot(id: "slot_cafe_stand", name: "רחבת הקפה", subtitle: "בין המסעדות לבתי הקפה", districtId: "food", icon: "cup.and.saucer.fill", defaultItemId: "cafe_stand"),
        CitySlot(id: "slot_resident_artist", name: "פינת האמנית", subtitle: "אמנות לצד כיכר העיר", districtId: "city", icon: "paintpalette.fill", defaultItemId: "resident_artist"),
        CitySlot(id: "slot_repair_lamp", name: "טיילת האוכל", subtitle: "פינת רחוב לצד השוק", districtId: "food", icon: "lamp.desk.fill", defaultItemId: "repair_lamp"),
        CitySlot(id: "slot_pet_cat_rooftop", name: "סמטת החתול", subtitle: "שביל שקט מאחורי החנויות", districtId: "shopping", icon: "pawprint.fill", defaultItemId: "pet_cat_rooftop"),
        CitySlot(id: "slot_bike_station", name: "רחבת האופניים", subtitle: "תחנת רכיבה לצד שדרת הקניות", districtId: "shopping", icon: "bicycle", defaultItemId: "bike_station"),
        CitySlot(id: "slot_flower_bed_plaza", name: "גן הפרחים", subtitle: "ערוגות לצד גן המשחקים", districtId: "shopping", icon: "camera.macro", defaultItemId: "flower_bed_plaza"),
        CitySlot(id: "slot_public_art_sculpture", name: "רחבת הפסל", subtitle: "אמנות במדרחוב הקניות", districtId: "shopping", icon: "cube.transparent.fill", defaultItemId: "public_art_sculpture"),
        CitySlot(id: "slot_repair_sidewalk", name: "שביל המגורים", subtitle: "ריצוף משודרג בכניסה לשכונה", districtId: "housing", icon: "square.grid.2x2.fill", defaultItemId: "repair_sidewalk")
    ]
    public static let legacyAliases: [String: String] = [
        "slot_park_center": "slot_tree_sakura",
        "slot_park_overlook": "slot_pet_golden_dog",
        "slot_food_plaza": "slot_cafe_stand",
        "slot_shop_promenade": "slot_pet_cat_rooftop",
        "slot_housing_terrace": "slot_repair_sidewalk",
        "slot_tech_plaza": "slot_bike_station"
    ]
    public static func canonicalID(_ id: String) -> String { legacyAliases[id] ?? id }
    public static func slot(for id: String) -> CitySlot? { allSlots.first { $0.id == canonicalID(id) } }
    public func accepts(_ itemId: String) -> Bool {
        let anchored = ["park_bridge", "fountain_marble", "repair_sidewalk"]
        if anchored.contains(defaultItemId) || anchored.contains(itemId) { return defaultItemId == itemId }
        return Self.allSlots.contains { $0.defaultItemId == itemId }
    }
    /// Explicit placements precede legacy/default fallbacks. Collisions use another free
    /// compatible location; earned items are never silently overwritten in the view.
    public static func resolvedPlacements(_ inventory: [CityPlacement]) -> [String: String] {
        let active = inventory.filter { $0.isApplied }
        var result: [String: String] = [:], placed = Set<String>()
        for entry in active {
            guard !placed.contains(entry.itemId), let raw = entry.slotId,
                  let slot = slot(for: raw), slot.accepts(entry.itemId), result[slot.id] == nil else { continue }
            result[slot.id] = entry.itemId; placed.insert(entry.itemId)
        }
        for entry in active where !placed.contains(entry.itemId) {
            let candidates = allSlots.filter { $0.accepts(entry.itemId) && result[$0.id] == nil }
            guard let slot = candidates.first(where: { $0.defaultItemId == entry.itemId }) ?? candidates.first else { continue }
            result[slot.id] = entry.itemId; placed.insert(entry.itemId)
        }
        return result
    }
}
