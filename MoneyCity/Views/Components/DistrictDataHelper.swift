import Foundation
import SwiftUI

/// A structured presentation item representing a district/area row in the "All City" spending breakdown.
public struct ExpenseDistrictBreakdownItem: Identifiable, Sendable {
    public let id: String
    public let districtId: String?
    public let title: String
    public let amount: Double
    public let percentage: Int
    public let bgColor: Color
    public let iconType: MoneyIconType

    public init(
        id: String,
        districtId: String?,
        title: String,
        amount: Double,
        percentage: Int,
        bgColor: Color,
        iconType: MoneyIconType
    ) {
        self.id = id
        self.districtId = districtId
        self.title = title
        self.amount = amount
        self.percentage = percentage
        self.bgColor = bgColor
        self.iconType = iconType
    }
}

/// Pure functional helpers for calculating district names, totals, and building pills.
public enum DistrictDataHelper {
    public static func districtName(for dist: String, language: AppLanguage) -> String {
        let isHebrew = language == .hebrew
        switch dist {
        case "food": return isHebrew ? "רובע האוכל והמסעדות" : "Food & Dining District"
        case "shopping": return isHebrew ? "שדרת הקניות והאופנה" : "Shopping & Fashion Avenue"
        case "housing": return isHebrew ? "מתחם המגורים והחשבונות" : "Housing & Bills Quarter"
        case "transport": return isHebrew ? "מרכז התחבורה והרכב" : "Mobility & Transport Hub"
        case "savings": return isHebrew ? "שמורת הטבע" : "Nature Reserve"
        case "civic": return isHebrew ? "רובע השירותים והעירייה" : "Civic & Services Hub"
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
        case "civic":
            let health = currentCity.categoryTotals[.health] ?? 0
            let fin = currentCity.categoryTotals[.finance] ?? 0
            let misc = (currentCity.categoryTotals[.miscellaneous] ?? 0) + (currentCity.categoryTotals[.misc] ?? 0)
            let other = currentCity.categoryTotals[.other] ?? 0
            return health + fin + misc + other
        case "savings":
            return currentCity.totalSavings
        default:
            return 0
        }
    }

    public static func sortingHubTransactions(from transactions: [Transaction]) -> [Transaction] {
        transactions.filter(\.needsCategorization)
    }

    public static func sortingHubCount(from transactions: [Transaction]) -> Int {
        sortingHubTransactions(from: transactions).count
    }

    public static func sortingHubAmount(from transactions: [Transaction]) -> Double {
        sortingHubTransactions(from: transactions).reduce(0.0) { $0 + $1.amount }
    }

    public static func buildingVisitCount(for bId: String, transactions: [Transaction]) -> Int {
        if bId == "city_sorting_hub" {
            return sortingHubCount(from: transactions)
        }
        return transactions.filter { $0.buildingId == bId }.count
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
                BuildingPillItem(id: "savings_sanctuary", title: isHe ? "שמורת הטבע" : "Nature Reserve", amount: sav, info: DistrictBuildingInfo(id: "savings_sanctuary", districtId: "savings", name: isHe ? "שמורת הטבע" : "Nature Reserve", amount: sav, visitCount: savVisits, trendText: sav > 0 ? (isHe ? "צמיחה ירוקה החודש" : "Growing green this month") : (isHe ? "התחל לחסוך כדי להצמיח את שמורת הטבע" : "Start saving to grow the Nature Reserve")))
            ]
        case "transport":
            let tr = currentCity.categoryTotals[.transport] ?? 0
            let transVisits = transactions.filter { $0.category == .transport }.count
            return [
                BuildingPillItem(id: "trans_station", title: isHe ? "תחבורה ודלק" : "Transit & Fuel", amount: tr, info: DistrictBuildingInfo(id: "trans_station", districtId: "transport", name: isHe ? "תחבורה וחניה" : "Transit & Parking", amount: tr, visitCount: transVisits, trendText: transVisits == 0 ? (isHe ? "טרם נרשמו עסקאות החודש" : "No visits this month") : (isHe ? "\(transVisits) עסקאות החודש" : "\(transVisits) visits this month")))
            ]
        case "civic":
            let health = currentCity.buildingTotals["health_pharmacy"] ?? (currentCity.categoryTotals[.health] ?? 0)
            let fin = currentCity.buildingTotals["finance_bank"] ?? (currentCity.categoryTotals[.finance] ?? 0)
            let misc = currentCity.buildingTotals["museum_curiosities"] ?? ((currentCity.categoryTotals[.miscellaneous] ?? 0) + (currentCity.categoryTotals[.misc] ?? 0))
            let hubTxs = sortingHubTransactions(from: transactions)
            let otherAmount = hubTxs.reduce(0.0) { $0 + $1.amount }
            let otherCount = hubTxs.count
            return [
                BuildingPillItem(id: "health_pharmacy", title: isHe ? "פארם ובריאות" : "Pharmacy", amount: health, info: DistrictBuildingInfo(id: "health_pharmacy", districtId: "civic", name: isHe ? "פארם ובריאות" : "Health & Pharmacy", amount: health, visitCount: buildingVisitCount(for: "health_pharmacy", transactions: transactions), trendText: buildingTrendText(for: "health_pharmacy", transactions: transactions, language: language))),
                BuildingPillItem(id: "finance_bank", title: isHe ? "עמלות ובנקים" : "Banking", amount: fin, info: DistrictBuildingInfo(id: "finance_bank", districtId: "civic", name: isHe ? "עמלות ובנקים" : "Banking & Fees", amount: fin, visitCount: buildingVisitCount(for: "finance_bank", transactions: transactions), trendText: buildingTrendText(for: "finance_bank", transactions: transactions, language: language))),
                BuildingPillItem(id: "museum_curiosities", title: isHe ? "שונות" : "Miscellaneous", amount: misc, info: DistrictBuildingInfo(id: "museum_curiosities", districtId: "civic", name: isHe ? "שונות" : "Miscellaneous", amount: misc, visitCount: buildingVisitCount(for: "museum_curiosities", transactions: transactions), trendText: buildingTrendText(for: "museum_curiosities", transactions: transactions, language: language))),
                BuildingPillItem(id: "city_sorting_hub", title: isHe ? "לא מסווג" : "Uncategorized", amount: otherAmount, info: DistrictBuildingInfo(id: "city_sorting_hub", districtId: "civic", name: isHe ? "לא מסווג" : "Uncategorized", amount: otherAmount, visitCount: otherCount, trendText: buildingTrendText(for: "city_sorting_hub", transactions: transactions, language: language)))
            ]
        default:
            return []
        }
    }

    /// Builds the structured expense breakdown rows for the "All City" card.
    ///
    /// - Strictly excludes Savings / Nature Reserve (savings is not an expense).
    /// - Includes all non-savings spending: Food, Shopping, Housing, Transport, and Civic
    ///   (Health, Finance, Misc, Other).
    /// - Filters out zero-spending rows to show where money actually went.
    /// - Guarantees: sum(amounts) == currentCity.totalSpent.
    /// - Guarantees: sum(percentages) == 100% whenever totalSpent > 0.
    public static func expenseBreakdown(
        for currentCity: MonthlyCity,
        language: AppLanguage
    ) -> [ExpenseDistrictBreakdownItem] {
        let totalSpent = currentCity.totalSpent
        guard totalSpent > 0 else { return [] }

        let isHe = language == .hebrew

        struct Candidate {
            let id: String
            let districtId: String?
            let title: String
            let amount: Double
            let bgColor: Color
            let iconType: MoneyIconType
        }

        let candidates: [Candidate] = [
            Candidate(
                id: "food",
                districtId: "food",
                title: isHe ? "רובע האוכל" : "Food District",
                amount: districtTotal(for: "food", currentCity: currentCity),
                bgColor: Color(red: 254/255, green: 242/255, blue: 232/255),
                iconType: .cutlery
            ),
            Candidate(
                id: "shopping",
                districtId: "shopping",
                title: isHe ? "שדרת הקניות" : "Shopping District",
                amount: districtTotal(for: "shopping", currentCity: currentCity),
                bgColor: Color(red: 253/255, green: 238/255, blue: 244/255),
                iconType: .shoppingBag
            ),
            Candidate(
                id: "housing",
                districtId: "housing",
                title: isHe ? "מתחם המגורים" : "Housing District",
                amount: districtTotal(for: "housing", currentCity: currentCity),
                bgColor: Color(red: 238/255, green: 245/255, blue: 254/255),
                iconType: .home
            ),
            Candidate(
                id: "transport",
                districtId: "transport",
                title: isHe ? "מרכז התחבורה" : "Transport Hub",
                amount: districtTotal(for: "transport", currentCity: currentCity),
                bgColor: Color(red: 235/255, green: 248/255, blue: 255/255),
                iconType: .car
            ),
            Candidate(
                id: "civic",
                districtId: "civic",
                title: isHe ? "רובע השירותים והעירייה" : "Civic & Services Hub",
                amount: districtTotal(for: "civic", currentCity: currentCity),
                bgColor: Color(red: 243/255, green: 244/255, blue: 246/255),
                iconType: .citySkyline
            )
        ]

        // Keep only active rows with positive spend
        let active = candidates.filter { $0.amount > 0 }
        guard !active.isEmpty else { return [] }

        // Compute exact percentages and distribute integer shares via Largest Remainder Method
        let exactPcts = active.map { ($0.amount / totalSpent) * 100.0 }
        var integerPcts = exactPcts.map { Int(floor($0)) }
        var deficit = 100 - integerPcts.reduce(0, +)

        let remainders = exactPcts.enumerated().map { (index: $0.offset, rem: $0.element - floor($0.element)) }
        let sortedRemainders = remainders.sorted { $0.rem > $1.rem }

        for item in sortedRemainders where deficit > 0 {
            integerPcts[item.index] += 1
            deficit -= 1
        }

        return active.enumerated().map { index, cand in
            ExpenseDistrictBreakdownItem(
                id: cand.id,
                districtId: cand.districtId,
                title: cand.title,
                amount: cand.amount,
                percentage: integerPcts[index],
                bgColor: cand.bgColor,
                iconType: cand.iconType
            )
        }
    }
}
