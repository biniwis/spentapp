import SwiftUI

/// A single row in a district's building list — used both by the top pill strip
/// and the bottom DistrictDeepDiveCard.
public struct BuildingPillItem: Identifiable {
    public let id: String
    public let title: String
    public let amount: Double
    public let info: DistrictBuildingInfo

    public init(id: String, title: String, amount: Double, info: DistrictBuildingInfo) {
        self.id = id
        self.title = title
        self.amount = amount
        self.info = info
    }
}

@ViewBuilder
public func buildingVectorIcon(_ id: String, size: CGFloat = 18) -> some View {
    switch id {
    case "food_bistro": MoneyIcon(.cutlery, size: size)
    case "food_super": MoneyIcon(.cart, size: size)
    case "food_coffee": MoneyIcon(.coffee, size: size)
    case "food_wolt": MoneyIcon(.car, size: size)
    case "shop_boutique": MoneyIcon(.shoppingBag, size: size)
    case "shop_tech": MoneyIcon(.gamepad, size: size)
    case "shop_travel": MoneyIcon(.airplane, size: size)
    case "shop_arcade": MoneyIcon(.gamepad, size: size)
    case "house_tower": MoneyIcon(.home, size: size)
    case "house_util": MoneyIcon(.lightning, size: size)
    case "house_subs": MoneyIcon(.refresh, size: size)
    case "savings_sanctuary": MoneyIcon(.leaf, size: size)
    case "city_sorting_hub": MoneyIcon(.mail, size: size)
    case "museum_curiosities": MoneyIcon(.gift, size: size)
    case "trans_station": MoneyIcon(.car, size: size)
    case "health_pharmacy": MoneyIcon(.medicalCross, size: size)
    case "finance_bank": MoneyIcon(.creditCard, size: size)
    default: MoneyIcon(.home, size: size)
    }
}

public func districtToCategory(_ dist: String) -> SpendingCategory {
    switch dist {
    case "food": return .food
    case "shopping": return .shopping
    case "housing": return .housing
    case "savings": return .savings
    case "transport": return .transport
    default: return .other
    }
}
