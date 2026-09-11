import Foundation

/// Pure functional helpers for calculating district names, totals, and building pills.
public enum DistrictDataHelper {
    public static func districtName(for dist: String, language: AppLanguage) -> String {
        let isHebrew = language == .hebrew
        switch dist {
        case "food": return isHebrew ? "רובע האוכל והמסעדות" : "Food & Dining District"
        case "shopping": return isHebrew ? "שדרת הקניות והאופנה" : "Shopping & Fashion Avenue"
        case "housing": return isHebrew ? "מתחם המגורים והחשבונות" : "Housing & Bills Quarter"
        case "transport": return isHebrew ? "מרכז התחבורה והרכב" : "Mobility & Transport Hub"
        case "savings": return isHebrew ? "הפארק" : "The Park"
        default: return isHebrew ? "רובע בעיר" : "City District"
        }
    }

    public static func districtTotal(for dist: String, currentCity: MonthlyCity) -> Double {
        switch dist {
        case "food":
            let r = currentCity.categoryTotals[.food] ?? 0
            let g = currentCity.categoryTotals[.groceries] ?? 0
            let c = currentCity.categoryTotals[.coffee] ?? 0
            return r + g + c
        case "shopping":
            let s = currentCity.categoryTotals[.shopping] ?? 0
            let e = currentCity.categoryTotals[.entertainment] ?? 0
            return s + e
        case "housing":
            let h = currentCity.categoryTotals[.housing] ?? 0
            let subs = currentCity.categoryTotals[.subscriptions] ?? 0
            return h + subs
        case "transport":
            return currentCity.categoryTotals[.transport] ?? 0
        case "savings":
            return currentCity.totalSavings
        default:
            return 0
        }
    }

    public static func buildingVisitCount(for bId: String, transactions: [Transaction]) -> Int {
        transactions.filter { $0.buildingId == bId }.count
    }

    public static func buildingTrendText(for bId: String, transactions: [Transaction], language: AppLanguage) -> String {
        let count = buildingVisitCount(for: bId, transactions: transactions)
        if count == 0 {
            return language == .hebrew ? "טרם נרשמו עסקאות החודש" : "No visits this month"
        } else {
            return language == .hebrew ? "\(count) עסקאות החודש" : "\(count) visits this month"
        }
    }

    public static func districtBuildingPills(
        for dist: String,
        currentCity: MonthlyCity,
        transactions: [Transaction],
        language: AppLanguage
    ) -> [BuildingPillItem] {
        let isHe = language == .hebrew
        switch dist {
        case "food":
            let r = currentCity.buildingTotals["food_bistro"] ?? 0
            let g = currentCity.buildingTotals["food_super"] ?? 0
            let c = currentCity.buildingTotals["food_coffee"] ?? 0
            let d = currentCity.buildingTotals["food_wolt"] ?? 0
            return [
                BuildingPillItem(id: "food_bistro", title: isHe ? "מסעדות" : "Restaurants", amount: r, info: DistrictBuildingInfo(id: "food_bistro", districtId: "food", name: isHe ? "מסעדות" : "Restaurants", amount: r, visitCount: buildingVisitCount(for: "food_bistro", transactions: transactions), trendText: buildingTrendText(for: "food_bistro", transactions: transactions, language: language))),
                BuildingPillItem(id: "food_super", title: isHe ? "סופר ומכולת" : "Groceries", amount: g, info: DistrictBuildingInfo(id: "food_super", districtId: "food", name: isHe ? "סופר ומכולת" : "Supermarket & Groceries", amount: g, visitCount: buildingVisitCount(for: "food_super", transactions: transactions), trendText: buildingTrendText(for: "food_super", transactions: transactions, language: language))),
                BuildingPillItem(id: "food_coffee", title: isHe ? "בתי קפה" : "Coffee", amount: c, info: DistrictBuildingInfo(id: "food_coffee", districtId: "food", name: isHe ? "בתי קפה" : "Cafes", amount: c, visitCount: buildingVisitCount(for: "food_coffee", transactions: transactions), trendText: buildingTrendText(for: "food_coffee", transactions: transactions, language: language))),
                BuildingPillItem(id: "food_wolt", title: isHe ? "משלוחים" : "Delivery", amount: d, info: DistrictBuildingInfo(id: "food_wolt", districtId: "food", name: isHe ? "משלוחי אוכל" : "Food Delivery", amount: d, visitCount: buildingVisitCount(for: "food_wolt", transactions: transactions), trendText: buildingTrendText(for: "food_wolt", transactions: transactions, language: language)))
            ]
        case "shopping":
            let f = currentCity.buildingTotals["shop_boutique"] ?? 0
            let t = currentCity.buildingTotals["shop_tech"] ?? 0
            let tr = currentCity.buildingTotals["shop_travel"] ?? 0
            let a = currentCity.buildingTotals["shop_arcade"] ?? 0
            return [
                BuildingPillItem(id: "shop_boutique", title: isHe ? "ביגוד" : "Fashion", amount: f, info: DistrictBuildingInfo(id: "shop_boutique", districtId: "shopping", name: isHe ? "בוטיק אופנה" : "Fashion Boutique", amount: f, visitCount: buildingVisitCount(for: "shop_boutique", transactions: transactions), trendText: buildingTrendText(for: "shop_boutique", transactions: transactions, language: language))),
                BuildingPillItem(id: "shop_tech", title: isHe ? "טכנולוגיה" : "Tech", amount: t, info: DistrictBuildingInfo(id: "shop_tech", districtId: "shopping", name: isHe ? "חנות אלקטרוניקה" : "Electronics Store", amount: t, visitCount: buildingVisitCount(for: "shop_tech", transactions: transactions), trendText: buildingTrendText(for: "shop_tech", transactions: transactions, language: language))),
                BuildingPillItem(id: "shop_travel", title: isHe ? "חופשות" : "Travel", amount: tr, info: DistrictBuildingInfo(id: "shop_travel", districtId: "shopping", name: isHe ? "סוכנות נסיעות" : "Travel Agency", amount: tr, visitCount: buildingVisitCount(for: "shop_travel", transactions: transactions), trendText: buildingTrendText(for: "shop_travel", transactions: transactions, language: language))),
                BuildingPillItem(id: "shop_arcade", title: isHe ? "פנאי ובידור" : "Arcade", amount: a, info: DistrictBuildingInfo(id: "shop_arcade", districtId: "shopping", name: isHe ? "מתחם ארקייד" : "Arcade Complex", amount: a, visitCount: buildingVisitCount(for: "shop_arcade", transactions: transactions), trendText: buildingTrendText(for: "shop_arcade", transactions: transactions, language: language)))
            ]
        case "housing":
            let rent = currentCity.buildingTotals["house_tower"] ?? 0
            let util = currentCity.buildingTotals["house_util"] ?? 0
            let subs = currentCity.buildingTotals["house_subs"] ?? 0
            return [
                BuildingPillItem(id: "house_tower", title: isHe ? "שכירות" : "Rent", amount: rent, info: DistrictBuildingInfo(id: "house_tower", districtId: "housing", name: isHe ? "מגדל מגורים" : "Residential Tower", amount: rent, visitCount: buildingVisitCount(for: "house_tower", transactions: transactions), trendText: buildingTrendText(for: "house_tower", transactions: transactions, language: language))),
                BuildingPillItem(id: "house_util", title: isHe ? "חשבונות" : "Utilities", amount: util, info: DistrictBuildingInfo(id: "house_util", districtId: "housing", name: isHe ? "חשמל ומים" : "Power & Water", amount: util, visitCount: buildingVisitCount(for: "house_util", transactions: transactions), trendText: buildingTrendText(for: "house_util", transactions: transactions, language: language))),
                BuildingPillItem(id: "house_subs", title: isHe ? "מנויים" : "Subscriptions", amount: subs, info: DistrictBuildingInfo(id: "house_subs", districtId: "housing", name: isHe ? "שירותי סטרימינג" : "Streaming & Subs", amount: subs, visitCount: buildingVisitCount(for: "house_subs", transactions: transactions), trendText: buildingTrendText(for: "house_subs", transactions: transactions, language: language)))
            ]
        case "savings":
            let sav = currentCity.totalSavings
            let savVisits = transactions.filter { $0.category == .savings }.count
            return [
                BuildingPillItem(id: "savings_sanctuary", title: isHe ? "הפארק" : "The Park", amount: sav, info: DistrictBuildingInfo(id: "savings_sanctuary", districtId: "savings", name: isHe ? "הפארק" : "The Park", amount: sav, visitCount: savVisits, trendText: sav > 0 ? (isHe ? "צמיחה ירוקה החודש" : "Growing green this month") : (isHe ? "התחל לחסוך כדי להצמיח את הפארק" : "Start saving to grow the park")))
            ]
        case "transport":
            let tr = currentCity.categoryTotals[.transport] ?? 0
            let transVisits = transactions.filter { $0.category == .transport }.count
            return [
                BuildingPillItem(id: "trans_station", title: isHe ? "תחבורה ודלק" : "Transit & Fuel", amount: tr, info: DistrictBuildingInfo(id: "trans_station", districtId: "transport", name: isHe ? "תחבורה וחניה" : "Transit & Parking", amount: tr, visitCount: transVisits, trendText: transVisits == 0 ? (isHe ? "טרם נרשמו עסקאות החודש" : "No visits this month") : (isHe ? "\(transVisits) עסקאות החודש" : "\(transVisits) visits this month")))
            ]
        default:
            return []
        }
    }
}
