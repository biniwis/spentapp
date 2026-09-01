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
    public var icon: String = "building.columns.fill"
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
        case "tree_sakura": return "leaf.fill"
        case "flower_bed_plaza": return "camera.macro"
        case "repair_bench": return "chair.lounge.fill"
        case "repair_lamp": return "lamp.desk.fill"
        case "resident_artist": return "paintpalette.fill"
        case "pet_cat_rooftop": return "pawprint.fill"
        case "bike_station": return "bicycle"
        case "cafe_stand": return "cup.and.saucer.fill"
        case "repair_sidewalk": return "square.grid.2x2.fill"
        case "fountain_marble": return "drop.fill"
        case "pet_golden_dog": return "pawprint.fill"
        case "park_bridge": return "building.2.fill"
        case "public_art_sculpture": return "cube.transparent.fill"
        default: break
        }
        
        // 2. Fallback to enrichment type
        switch type {
        case .nature: return "leaf.fill"
        case .resident: return "person.fill"
        case .pet: return "pawprint.fill"
        case .decoration: return "building.columns.fill"
        case .repair: return "hammer.fill"
        case .landmark: return "building.2.fill"
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
