import Foundation
import SwiftData

/// The category of city enrichment/improvement chosen by the user.
public enum EnrichmentType: String, Codable, CaseIterable, Sendable {
    case resident       // New citizen (artist, reader, musician)
    case pet            // Dog, cat
    case nature         // Cherry tree, flower garden, oak
    case decoration     // Public art, fountain, street detail
    case repair         // Repaired bench, fixed sidewalk, street lamp
    case landmark       // Bridge, pavilion, special monument
}

/// A specific enrichment, addition, or repair unlocked through personal progress and chosen by the user.
@Model
public final class CityEnrichment: Identifiable {
    public var id: UUID = UUID()
    public var itemId: String = "" // Unique ID e.g. "fountain_plaza", "cat_rooftop"
    public var name: String = ""
    public var subtitle: String = ""
    public var icon: String = "🏛️"
    public var typeRawValue: String = EnrichmentType.nature.rawValue
    public var tierRawValue: String = "small" // "small", "medium", "large"
    public var unlockedDate: Date = Date()
    public var savedAmount: Double = 0.0
    public var districtId: String = "city"
    public var isApplied: Bool = true
    public var placedSlotId: String? = nil
    
    public var type: EnrichmentType {
        get { EnrichmentType(rawValue: typeRawValue) ?? .nature }
        set { typeRawValue = newValue.rawValue }
    }
    
    public var resolvedIcon: String {
        // 1. Match by itemId first
        switch itemId {
        case "tree_sakura": return "🌸"
        case "flower_bed_plaza": return "🌷"
        case "repair_bench": return "🪑"
        case "repair_lamp": return "🏮"
        case "resident_artist": return "🎨"
        case "pet_cat_rooftop": return "🐱"
        case "bike_station": return "🚲"
        case "cafe_stand": return "☕"
        case "repair_sidewalk": return "🧱"
        case "fountain_marble": return "⛲"
        case "pet_golden_dog": return "🐕"
        default: break
        }
        
        // 2. Match by Hebrew/English name keywords
        let lowerName = name.lowercased()
        if lowerName.contains("פרח") || lowerName.contains("flower") { return "🌷" }
        if lowerName.contains("סקורה") || lowerName.contains("sakura") || lowerName.contains("עץ") || lowerName.contains("tree") { return "🌸" }
        if lowerName.contains("אמנית") || lowerName.contains("artist") || lowerName.contains("ציור") { return "🎨" }
        if lowerName.contains("ספסל") || lowerName.contains("bench") { return "🪑" }
        if lowerName.contains("פנס") || lowerName.contains("lamp") { return "🏮" }
        if lowerName.contains("חתול") || lowerName.contains("cat") { return "🐱" }
        if lowerName.contains("אופניים") || lowerName.contains("bike") { return "🚲" }
        if lowerName.contains("קפה") || lowerName.contains("cafe") || lowerName.contains("coffee") { return "☕" }
        if lowerName.contains("מדרכה") || lowerName.contains("sidewalk") || lowerName.contains("ריצוף") { return "🧱" }
        if lowerName.contains("מזרקה") || lowerName.contains("fountain") { return "⛲" }
        if lowerName.contains("כלב") || lowerName.contains("dog") { return "🐕" }

        // 3. Check if stored icon is a valid clean emoji
        if !icon.isEmpty && !icon.contains("?") && !icon.contains("\u{FFFD}") && icon != "✨" && icon.count <= 2 {
            return icon
        }

        // 4. Fallback to enrichment type
        switch type {
        case .nature: return "🌸"
        case .resident: return "🎨"
        case .pet: return "🐱"
        case .decoration: return "☕"
        case .repair: return "🪑"
        case .landmark: return "⛲"
        }
    }
    
    public init(
        id: UUID = UUID(),
        itemId: String,
        name: String,
        subtitle: String = "",
        icon: String,
        type: EnrichmentType,
        tier: String = "small",
        unlockedDate: Date = Date(),
        savedAmount: Double = 0.0,
        districtId: String = "city",
        isApplied: Bool = true,
        placedSlotId: String? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.name = name
        self.subtitle = subtitle
        self.icon = icon
        self.typeRawValue = type.rawValue
        self.tierRawValue = tier
        self.unlockedDate = unlockedDate
        self.savedAmount = savedAmount
        self.districtId = districtId
        self.isApplied = isApplied
        self.placedSlotId = placedSlotId
    }
}
