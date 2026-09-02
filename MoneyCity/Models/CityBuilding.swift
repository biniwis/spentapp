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

    /// All buildings available for a given spending category
    public static func buildings(for category: SpendingCategory) -> [CityBuilding] {
        switch category.canonical {
        case .food:
            return [
                CityBuilding(
                    id: "food_super",
                    category: .food,
                    nameHe: "סופרמרקט ומכולת",
                    nameEn: "Supermarket & Groceries",
                    emoji: "🛒",
                    sfSymbol: "cart.fill",
                    descriptionHe: "סופר, מכולת ומוצרי מזון",
                    descriptionEn: "Groceries & supermarket"
                ),
                CityBuilding(
                    id: "food_coffee",
                    category: .food,
                    nameHe: "בית קפה ומאפייה",
                    nameEn: "Cafe & Bakery",
                    emoji: "☕",
                    sfSymbol: "cup.and.saucer.fill",
                    descriptionHe: "קפה, מאפיות וגלידות",
                    descriptionEn: "Coffee shops & bakeries"
                ),
                CityBuilding(
                    id: "food_wolt",
                    category: .food,
                    nameHe: "מרכז משלוחים (Wolt)",
                    nameEn: "Food Delivery (Wolt)",
                    emoji: "🛵",
                    sfSymbol: "bicycle",
                    descriptionHe: "Wolt, תן ביס ומשלוחי אוכל",
                    descriptionEn: "Wolt, 10bis & food delivery"
                ),
                CityBuilding(
                    id: "food_bistro",
                    category: .food,
                    nameHe: "מסעדה וביסטרו",
                    nameEn: "Restaurant & Bistro",
                    emoji: "🍽️",
                    sfSymbol: "fork.knife",
                    descriptionHe: "מסעדות, ברים, פיצות והמבורגר",
                    descriptionEn: "Dining, bars & restaurants"
                )
            ]
        case .shopping:
            return [
                CityBuilding(
                    id: "shop_boutique",
                    category: .shopping,
                    nameHe: "בוטיק אופנה וביגוד",
                    nameEn: "Fashion & Boutique",
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
                    nameEn: "Arcade & Entertainment",
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
                    nameHe: "מגדל מגורים",
                    nameEn: "Residential Tower",
                    emoji: "🏢",
                    sfSymbol: "building.2.fill",
                    descriptionHe: "שכירות, משכנתא ודיור",
                    descriptionEn: "Rent & housing costs"
                ),
                CityBuilding(
                    id: "house_util",
                    category: .housing,
                    nameHe: "חשבונות ותשתיות",
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
                    id: "shop_boutique",
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
                    nameHe: "שמורת חיסכון והשקעות",
                    nameEn: "Savings Sanctuary",
                    emoji: "🌳",
                    sfSymbol: "leaf.fill",
                    descriptionHe: "קרנות, השקעות וחיסכון חודשי",
                    descriptionEn: "Investments & savings funds"
                )
            ]
        case .finance, .other:
            return [
                CityBuilding(
                    id: "city_sorting_hub",
                    category: category,
                    nameHe: "מרכז מיון ושונות",
                    nameEn: "Sorting Hub & Other",
                    emoji: "📦",
                    sfSymbol: "shippingbox.fill",
                    descriptionHe: "עמלות, בנקים ושונות",
                    descriptionEn: "Fees, banking & miscellaneous"
                )
            ]
        @unknown default:
            return []
        }
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
