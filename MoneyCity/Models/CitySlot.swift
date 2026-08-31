import Foundation

/// Defines a dedicated, curated spot in the 3D City Island where the user can choose to place their unlocked enrichments.
public struct CitySlot: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let districtId: String
    public let icon: String
    public let defaultItemId: String
    
    public init(id: String, name: String, subtitle: String, districtId: String, icon: String, defaultItemId: String) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.districtId = districtId
        self.icon = icon
        self.defaultItemId = defaultItemId
    }
    
    public static let allSlots: [CitySlot] = [
        CitySlot(
            id: "slot_park_center",
            name: "מרכז פארק השמורה",
            subtitle: "כיכר המים והטבע המרכזית בלב הירוק",
            districtId: "savings",
            icon: "🌲",
            defaultItemId: "fountain_marble"
        ),
        CitySlot(
            id: "slot_park_overlook",
            name: "מצפה גבעת האגם",
            subtitle: "נקודת תצפית פסטורלית מעל המים",
            districtId: "savings",
            icon: "🪵",
            defaultItemId: "pet_cat_rooftop"
        ),
        CitySlot(
            id: "slot_food_plaza",
            name: "רחבת רובע האוכל",
            subtitle: "כיכר הטיילת מול המסעדות ובתי הקפה",
            districtId: "food",
            icon: "🍽️",
            defaultItemId: "cafe_stand"
        ),
        CitySlot(
            id: "slot_shop_promenade",
            name: "שדרת הקניות והאופנה",
            subtitle: "מרכז המדרחוב לצד הבוטיקים וחלונות הראווה",
            districtId: "shopping",
            icon: "🛍️",
            defaultItemId: "tree_sakura"
        ),
        CitySlot(
            id: "slot_housing_terrace",
            name: "טרסת גן המגורים",
            subtitle: "רחבת הגן השלווה למרגלות מגדל המגורים",
            districtId: "housing",
            icon: "🏡",
            defaultItemId: "flower_bed_plaza"
        ),
        CitySlot(
            id: "slot_tech_plaza",
            name: "כיכר מתחם ההייטק",
            subtitle: "רחבה מודרנית ליד חלל החדשנות",
            districtId: "shopping",
            icon: "💻",
            defaultItemId: "public_art_sculpture"
        )
    ]
    
    public static func slot(for id: String) -> CitySlot? {
        allSlots.first(where: { $0.id == id })
    }
}
