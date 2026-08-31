import SwiftUI

/// Transforms raw financial transactions into an isometric 3D living diorama based on Behavioral World Generation ("Living Map").
public final class CitySimulationEngine: Sendable {
    public static let shared = CitySimulationEngine()
    
    private init() {}
    
    /// Builds the MonthlyCity model with dynamic tile scaling, building breakdowns, and behavioral habit analysis.
    public func generateCity(
        for monthDate: Date,
        transactions: [Transaction],
        estimatedMonthlyBudget: Double = 8000.0
    ) -> MonthlyCity {
        var totals: [SpendingCategory: Double] = [:]
        for cat in SpendingCategory.allCases {
            totals[cat] = 0.0
        }
        
        var buildingTotals: [String: Double] = [
            "food_bistro": 0.0,
            "food_super": 0.0,
            "food_coffee": 0.0,
            "food_wolt": 0.0,
            "shop_boutique": 0.0,
            "shop_tech": 0.0,
            "shop_travel": 0.0,
            "shop_arcade": 0.0,
            "trans_station": 0.0,
            "house_tower": 0.0,
            "house_util": 0.0,
            "house_subs": 0.0,
            "savings_sanctuary": 0.0
        ]
        
        var woltCount = 0
        var coffeeCount = 0
        var onlinePkgCount = 0
        var hasTravel = false
        var activeSubs = 0
        var groceryBags = 0
        
        for t in transactions {
            totals[t.category, default: 0.0] += t.amount
            let bId = t.buildingId
            buildingTotals[bId, default: 0.0] += t.amount
            
            let m = t.merchant.lowercased()
            if bId == "food_wolt" || m.contains("wolt") || m.contains("וולט") || m.contains("10bis") || m.contains("תן ביס") {
                woltCount += 1
            }
            if bId == "food_coffee" || t.category == .coffee || m.contains("aroma") || m.contains("קפה") || m.contains("cafe") || m.contains("ארומה") {
                coffeeCount += 1
            }
            if bId == "shop_tech" || m.contains("amazon") || m.contains("אמזון") || m.contains("asos") || m.contains("ksp") || m.contains("aliexpress") {
                onlinePkgCount += 1
            }
            if bId == "shop_travel" || m.contains("flight") || m.contains("טיסה") || m.contains("el al") || m.contains("אל על") || m.contains("airbnb") || m.contains("booking") || m.contains("hotel") {
                hasTravel = true
            }
            if bId == "house_subs" || t.category == .subscriptions || m.contains("netflix") || m.contains("spotify") || m.contains("apple") {
                activeSubs += 1
            }
            if bId == "food_super" || t.category == .groceries || m.contains("שופרסל") || m.contains("רמי לוי") || m.contains("סופר") {
                groceryBags += max(1, Int(t.amount / 120))
            }
        }
        
        let totalSpent = transactions.filter { $0.category != .savings }.reduce(0.0) { $0 + $1.amount }
        let directSavings = totals[.savings] ?? 0.0
        // Money moved into savings has already left the budget, so it must be subtracted
        // before it is added back — otherwise every deposit is counted twice.
        let unspentBudget = max(0.0, estimatedMonthlyBudget - totalSpent - directSavings)
        let totalSavings = unspentBudget + directSavings
        buildingTotals["savings_sanctuary"] = totalSavings
        
        let highestCategory = totals.filter { $0.key != .savings && $0.key != .other }
            .max(by: { $0.value < $1.value })?.key ?? .food
        
        let habits = BehavioralHabits(
            woltDeliveryCount: woltCount,
            coffeeCount: coffeeCount,
            onlinePackagesCount: onlinePkgCount,
            hasTravelOrFlight: hasTravel,
            activeSubscriptionsCount: activeSubs,
            totalGroceryBags: groceryBags
        )
        
        var tiles: [BuildingTile] = []
        
        // Savings Park
        let safeBudget = max(1.0, estimatedMonthlyBudget)
        let savingsRatio = min(1.0, totalSavings / safeBudget)
        tiles.append(BuildingTile(
            id: 0,
            category: .savings,
            title: "שמורת חיסכון",
            spendingAmount: totalSavings,
            level: Int(savingsRatio * 4) + 1,
            heightScale: 0.4,
            gridX: 0,
            gridY: 0,
            floatingTag: "SAVINGS PARK"
        ))
        
        // Food District Tile
        let foodSpend = (totals[.food] ?? 0) + (totals[.groceries] ?? 0) + (totals[.coffee] ?? 0)
        tiles.append(BuildingTile(
            id: 1,
            category: .food,
            title: "רובע האוכל",
            spendingAmount: foodSpend,
            level: min(5, Int(foodSpend / 300) + 1),
            heightScale: foodSpend > 800 ? 2.2 : 1.2,
            gridX: 1,
            gridY: 0,
            floatingTag: "FOOD DISTRICT"
        ))
        
        // Transport Tile
        let transportSpend = totals[.transport] ?? 0.0
        tiles.append(BuildingTile(
            id: 2,
            category: .transport,
            title: "תחבורה ורכב",
            spendingAmount: transportSpend,
            level: 2,
            heightScale: 0.2,
            gridX: 2,
            gridY: 0,
            hasRoad: true,
            hasTaxi: true,
            floatingTag: "MOBILITY"
        ))
        
        // Shopping Tile
        let shopSpend = (totals[.shopping] ?? 0) + (totals[.entertainment] ?? 0)
        tiles.append(BuildingTile(
            id: 3,
            category: .shopping,
            title: "מסחר ובוטיק",
            spendingAmount: shopSpend,
            level: min(5, Int(shopSpend / 400) + 1),
            heightScale: shopSpend > 600 ? 1.8 : 1.0,
            gridX: 3,
            gridY: 0,
            floatingTag: "SHOPPING"
        ))
        
        // Housing / Residence Tile
        let houseSpend = (totals[.housing] ?? 0) + (totals[.subscriptions] ?? 0)
        tiles.append(BuildingTile(
            id: 4,
            category: .housing,
            title: "מגדל מגורים",
            spendingAmount: houseSpend,
            level: 4,
            heightScale: 2.2,
            gridX: 0,
            gridY: 1,
            floatingTag: "RESIDENCE"
        ))
        
        let story = generateHeadlineStory(highestCat: highestCategory, totalSpent: totalSpent, totalSavings: totalSavings, habits: habits)
        
        return MonthlyCity(
            monthDate: monthDate,
            totalSpent: totalSpent,
            totalSavings: totalSavings,
            categoryTotals: totals,
            buildingTotals: buildingTotals,
            tiles: tiles,
            headlineStory: story,
            habits: habits
        )
    }
    
    private func generateHeadlineStory(highestCat: SpendingCategory, totalSpent: Double, totalSavings: Double, habits: BehavioralHabits) -> String {
        if totalSpent == 0 {
            return "🌱 העיר פתוחה ורעננה — טרם נרשמו הוצאות החודש."
        }
        var highlights: [String] = []
        if habits.woltDeliveryCount >= 10 {
            highlights.append("🛵 \(habits.woltDeliveryCount) משלוחי Wolt ברחובות")
        }
        if habits.coffeeCount >= 8 {
            highlights.append("☕ \(habits.coffeeCount) כוסות קפה בבתי הקפה")
        }
        if habits.onlinePackagesCount >= 3 {
            highlights.append("📦 \(habits.onlinePackagesCount) חבילות בפתח המגדל")
        }
        
        let habitString = highlights.joined(separator: " • ")
        return habitString.isEmpty
            ? "🏙️ הוצאה מרכזית ב\(highestCat.displayName) לצד ₪\(Int(totalSavings)) שנשמרו בפארק החיסכון."
            : "\(habitString) • ₪\(Int(totalSavings)) נשמרו בטבע 🌱"
    }
}
