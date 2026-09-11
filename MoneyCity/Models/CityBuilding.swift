import SwiftUI

/// Represents a specific 3D architectural building in the MoneyCity diorama.
public struct CityBuilding: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: SpendingCategory
    public let nameHe: String
    public let nameEn: String
    public let emoji: String
    public let sfSymbol: String
    public let descriptionHe: String
    public let descriptionEn: String

    public func displayName(for language: AppLanguage) -> String {
        language == .english ? nameEn : nameHe
    }

    public func description(for language: AppLanguage) -> String {
        language == .english ? descriptionEn : descriptionHe
    }

    public func shortName(for language: AppLanguage) -> String {
        let isHebrew = language == .hebrew
        switch id {
        case "food_super": return isHebrew ? "סופרמרקט" : "Supermarket"
        case "food_coffee": return isHebrew ? "בתי קפה" : "Cafes"
        case "food_wolt": return isHebrew ? "משלוחי אוכל" : "Delivery"
        case "food_bistro": return isHebrew ? "מסעדות" : "Restaurants"
        case "shop_boutique": return isHebrew ? "ביגוד" : "Fashion"
        case "shop_tech": return isHebrew ? "טכנולוגיה" : "Tech"
        case "shop_travel": return isHebrew ? "חופשות" : "Travel"
        case "shop_arcade": return isHebrew ? "בילויים" : "Arcade"
        case "trans_station": return isHebrew ? "תחבורה" : "Transit"
        case "health_pharmacy": return isHebrew ? "פארם" : "Pharmacy"
        case "house_tower": return isHebrew ? "דיור" : "Housing"
        case "house_util": return isHebrew ? "חשבונות" : "Bills"
        case "house_subs": return isHebrew ? "מנויים" : "Subs"
        case "finance_bank": return isHebrew ? "עמלות" : "Fees"
        case "savings_sanctuary": return isHebrew ? "חיסכון" : "Savings"
        default: return displayName(for: language)
        }
    }

    /// MoneyCity signature icon type matching this architectural building
    public var iconType: MoneyIconType {
        switch id {
        case "food_super": return .cart
        case "food_coffee": return .coffee
        case "food_wolt": return .paperPlane
        case "food_bistro": return .cutlery
        case "shop_boutique": return .tshirt
        case "shop_tech": return .lightning
        case "shop_travel": return .airplane
        case "shop_arcade": return .gamepad
        case "house_tower": return .home
        case "house_util": return .lightning
        case "house_subs": return .refresh
        case "trans_station": return .car
        case "health_pharmacy": return .medicalCross
        case "savings_sanctuary": return .leaf
        case "finance_bank": return .creditCard
        case "museum_curiosities": return .gift
        case "city_sorting_hub": return .mail
        default: return .home
        }
    }

    /// All buildings available for a given spending category
    public static func buildings(for category: SpendingCategory) -> [CityBuilding] {
        switch category.canonical {
        case .food:
            return [
                CityBuilding(
                    id: "food_super",
                    category: .food,
                    nameHe: "סופר ומכולת",
                    nameEn: "Supermarket & Groceries",
                    emoji: "🛒",
                    sfSymbol: "cart.fill",
                    descriptionHe: "סופר, מכולת ומוצרי מזון",
                    descriptionEn: "Groceries & supermarket"
                ),
                CityBuilding(
                    id: "food_coffee",
                    category: .food,
                    nameHe: "בתי קפה",
                    nameEn: "Cafe & Bakery",
                    emoji: "☕",
                    sfSymbol: "cup.and.saucer.fill",
                    descriptionHe: "קפה, מאפיות וגלידות",
                    descriptionEn: "Coffee shops & bakeries"
                ),
                CityBuilding(
                    id: "food_wolt",
                    category: .food,
                    nameHe: "משלוחי אוכל",
                    nameEn: "Food Delivery",
                    emoji: "🛵",
                    sfSymbol: "bicycle",
                    descriptionHe: "Wolt, תן ביס ומשלוחי אוכל",
                    descriptionEn: "Wolt, 10bis & food delivery"
                ),
                CityBuilding(
                    id: "food_bistro",
                    category: .food,
                    nameHe: "מסעדות",
                    nameEn: "Restaurants",
                    emoji: "🍽️",
                    sfSymbol: "fork.knife",
                    descriptionHe: "מסעדות, פיצות, המבורגר ואוכל בחוץ",
                    descriptionEn: "Dining & restaurants"
                )
            ]
        case .shopping:
            return [
                CityBuilding(
                    id: "shop_boutique",
                    category: .shopping,
                    nameHe: "ביגוד ואופנה",
                    nameEn: "Clothing & Fashion",
                    emoji: "👗",
                    sfSymbol: "tshirt.fill",
                    descriptionHe: "בגדים, הנעלה וסטייל",
                    descriptionEn: "Clothing & fashion"
                ),
                CityBuilding(
                    id: "shop_tech",
                    category: .shopping,
                    nameHe: "טכנולוגיה וחשמל",
                    nameEn: "Tech & Electronics",
                    emoji: "💻",
                    sfSymbol: "laptopcomputer",
                    descriptionHe: "מחשבים, גאדג'טים וחשמל",
                    descriptionEn: "Electronics & tech gear"
                ),
                CityBuilding(
                    id: "shop_travel",
                    category: .shopping,
                    nameHe: "חופשות וטיסות",
                    nameEn: "Travel & Hotels",
                    emoji: "✈️",
                    sfSymbol: "airplane",
                    descriptionHe: "טיסות, מלונות וחופשות",
                    descriptionEn: "Flights, hotels & vacations"
                )
            ]
        case .entertainment:
            return [
                CityBuilding(
                    id: "shop_arcade",
                    category: .entertainment,
                    nameHe: "ארקייד, קולנוע ובידור",
                    nameEn: "Entertainment",
                    emoji: "🎮",
                    sfSymbol: "gamecontroller.fill",
                    descriptionHe: "קולנוע, הופעות, גיימינג ובילויים",
                    descriptionEn: "Cinema, concerts & gaming"
                )
            ]
        case .housing:
            return [
                CityBuilding(
                    id: "house_tower",
                    category: .housing,
                    nameHe: "שכירות ודיור",
                    nameEn: "Housing",
                    emoji: "🏢",
                    sfSymbol: "building.2.fill",
                    descriptionHe: "שכירות, משכנתא ודיור",
                    descriptionEn: "Rent & housing costs"
                ),
                CityBuilding(
                    id: "house_util",
                    category: .housing,
                    nameHe: "חשבונות הבית",
                    nameEn: "Utilities & Bills",
                    emoji: "⚡",
                    sfSymbol: "bolt.fill",
                    descriptionHe: "חשמל, מים, גז וארנונה",
                    descriptionEn: "Electricity, water & taxes"
                )
            ]
        case .subscriptions:
            return [
                CityBuilding(
                    id: "house_subs",
                    category: .subscriptions,
                    nameHe: "מנויים דיגיטליים",
                    nameEn: "Digital Subscriptions",
                    emoji: "📱",
                    sfSymbol: "play.tv.fill",
                    descriptionHe: "Netflix, Spotify, סלולר וענן",
                    descriptionEn: "Streaming & mobile subscriptions"
                )
            ]
        case .transport:
            return [
                CityBuilding(
                    id: "trans_station",
                    category: .transport,
                    nameHe: "תחבורה, דלק וחניה",
                    nameEn: "Transport & Fuel",
                    emoji: "🚗",
                    sfSymbol: "car.fill",
                    descriptionHe: "דלק, חניה, תחב״צ ומוניות",
                    descriptionEn: "Fuel, parking & transit"
                )
            ]
        case .health:
            return [
                CityBuilding(
                    id: "health_pharmacy",
                    category: .health,
                    nameHe: "פארם ובריאות",
                    nameEn: "Health & Pharmacy",
                    emoji: "💊",
                    sfSymbol: "heart.fill",
                    descriptionHe: "בתי מרקחת, כושר וטיפוח",
                    descriptionEn: "Pharmacy, gym & wellness"
                )
            ]
        case .savings:
            return [
                CityBuilding(
                    id: "savings_sanctuary",
                    category: .savings,
                    nameHe: "חיסכון והשקעות",
                    nameEn: "Savings & Investments",
                    emoji: "🌳",
                    sfSymbol: "leaf.fill",
                    descriptionHe: "קרנות, השקעות וחיסכון חודשי",
                    descriptionEn: "Savings goals, funds & investments"
                )
            ]
        case .finance:
            return [
                CityBuilding(
                    id: "finance_bank",
                    category: .finance,
                    nameHe: "עמלות ובנקים",
                    nameEn: "Banking & Fees",
                    emoji: "💳",
                    sfSymbol: "creditcard.fill",
                    descriptionHe: "עמלות, ריביות ודמי ניהול",
                    descriptionEn: "Banking fees & charges"
                )
            ]
        case .miscellaneous, .misc:
            return [
                CityBuilding(
                    id: "museum_curiosities",
                    category: .miscellaneous,
                    nameHe: "שונות",
                    nameEn: "Miscellaneous",
                    emoji: "🏛️",
                    sfSymbol: "building.columns.fill",
                    descriptionHe: "מתנות, תרומות, פריטים מיוחדים ושונות",
                    descriptionEn: "Gifts, donations and one-off miscellaneous expenses"
                )
            ]
        case .other:
            return [
                CityBuilding(
                    id: "city_sorting_hub",
                    category: .other,
                    nameHe: "לא מסווג",
                    nameEn: "Uncategorized",
                    emoji: "📮",
                    sfSymbol: "shippingbox.fill",
                    descriptionHe: "עסקאות שממתינות לסיווג",
                    descriptionEn: "Transactions waiting to be categorized"
                )
            ]
        case .groceries, .coffee:
            return buildings(for: .food)
        @unknown default:
            return []
        }
    }

    /// Normalizes a legacy or ambiguous building ID based on transaction category.
    /// Ensures backward compatibility with existing user stores where Health and Finance
    /// previously stored "shop_boutique".
    public static func normalizeBuildingId(_ id: String?, for category: SpendingCategory) -> String {
        guard let id = id, !id.isEmpty else {
            return defaultBuildingId(for: category)
        }
        if id == "shop_boutique" {
            if category == .health { return "health_pharmacy" }
            if category == .finance { return "finance_bank" }
        }
        return id
    }

    public static func defaultBuildingId(for category: SpendingCategory) -> String {
        buildings(for: category).first?.id ?? "city_sorting_hub"
    }

    /// Finds the building by its unique ID
    public static func find(id: String?) -> CityBuilding? {
        guard let id = id else { return nil }
        for cat in SpendingCategory.primaryCategories {
            if let found = buildings(for: cat).first(where: { $0.id == id }) {
                return found
            }
        }
        return nil
    }
}
