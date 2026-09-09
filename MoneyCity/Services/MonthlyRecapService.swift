import Foundation
import SwiftData
import SwiftUI

/// Represents a completed month's structured recap and architectural story.
public struct MonthlyRecap: Identifiable, Sendable, Equatable {
    public var id: String { monthId }
    public let monthId: String // e.g. "2026-08"
    public let date: Date
    public let monthNameHe: String
    public let monthNameEn: String
    public let totalSpent: Double
    public let transactionCount: Int
    public let remainingBudget: Double? // nil if no explicit budget configured
    
    public let biggestDistrict: DistrictHighlight? // Category with highest total spend
    public let tallestBuilding: BuildingHighlight? // Single largest transaction
    public let busiestDistrict: DistrictCountHighlight? // Category with most transactions
    public let mostRepeatedStop: MerchantHighlight? // Merchant visited most often
    public let biggestSpendingDay: DayHighlight? // Single day with highest spend
    public let comparisonVsPrevMonth: MonthComparison?
    public let cityVibe: CityVibe
    public let oneThingToKnow: String
    public let highlights: [Insight]
    public var dynamicInsights: [MonthlyRecapDynamicInsight] = []
    public let city: CitySnapshot
    
    public struct DistrictHighlight: Sendable, Equatable {
        public let nameHe: String
        public let nameEn: String
        public let amount: Double
        public let category: SpendingCategory
    }
    
    public struct BuildingHighlight: Sendable, Equatable {
        public let merchantName: String
        public let amount: Double
        public let category: SpendingCategory
        public let date: Date
    }
    
    public struct DistrictCountHighlight: Sendable, Equatable {
        public let nameHe: String
        public let nameEn: String
        public let transactionCount: Int
        public let totalAmount: Double
        public let category: SpendingCategory
    }
    
    public struct MerchantHighlight: Sendable, Equatable {
        public let merchantName: String
        public let visitCount: Int
        public let totalAmount: Double
        public let category: SpendingCategory
    }
    
    public struct DayHighlight: Sendable, Equatable {
        public let date: Date
        public let formattedDateHe: String
        public let formattedDateEn: String
        public let amount: Double
        public let transactionCount: Int
    }

    public struct Insight: Sendable, Equatable, Identifiable {
        public let id: String
        public let textHe: String
        public let textEn: String
    }

    /// Monthly city facts shared with the main city engine. The editorial recap uses
    /// native illustrations rather than embedding the live diorama.
    public struct CitySnapshot: Sendable, Equatable {
        public let totalSavings: Double
        public let savingsTarget: Double
        public let parkHealth: Double
        public let categoryTotals: [SpendingCategory: Double]
        public let buildingTotals: [String: Double]
        public let districtStates: [CityDistrictState]
        public let venueStates: [CityVenueState]
        public let habits: BehavioralHabits
    }
    
    public struct MonthComparison: Sendable, Equatable {
        public let prevMonthNameHe: String
        public let prevMonthNameEn: String
        public let diffAmount: Double
        public let percentChange: Double
        public let isDecrease: Bool // True if spent less than previous month
    }
    
    public enum VibeType: String, Sendable, Equatable {
        case quiet = "quiet"
        case growing = "growing"
        case busy = "busy"
        case recordMetropolis = "recordMetropolis"
        case greenMonth = "greenMonth"
    }
    
    public struct CityVibe: Sendable, Equatable {
        public let type: VibeType
        public let titleHe: String
        public let titleEn: String
        public let subtitleHe: String
        public let subtitleEn: String
        public let badgeIcon: String

        public var moneyIcon: MoneyIconName {
            switch badgeIcon {
            case "leaf.fill", "leaf": return .leaf
            case "building.2.fill", "building": return .home
            case "tree.fill", "tree": return .island
            case "flame.fill", "flame": return .flame
            default: return .star
            }
        }
    }
}

public enum MonthlyRecapService {
    public static func monthId(for date: Date = Date()) -> String {
        monthId(for: date, calendar: .current)
    }

    public static func monthId(for date: Date, calendar: Calendar = .current) -> String {
        guard let start = calendar.dateInterval(of: .month, for: date)?.start else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: start)
    }

    /// Convenience overload accepting `transactions:` parameter name
    public static func generateRecap(
        for monthDate: Date,
        transactions: [Transaction],
        monthlyBudget: Double? = nil
    ) -> MonthlyRecap {
        generateRecap(for: monthDate, allTransactions: transactions, monthlyBudget: monthlyBudget)
    }
    
    /// Generates a deterministic recap for a target month from the transaction log.
    public static func generateRecap(
        for monthDate: Date,
        allTransactions: [Transaction],
        monthlyBudget: Double? = nil
    ) -> MonthlyRecap {
        let cal = Calendar(identifier: .gregorian)
        guard let monthInterval = cal.dateInterval(of: .month, for: monthDate) else {
            return fallbackEmptyRecap(for: monthDate)
        }
        let startOfMonth = monthInterval.start
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        let monthId = monthFormatter.string(from: startOfMonth)
        
        let nameFormatterHe = DateFormatter()
        nameFormatterHe.locale = Locale(identifier: "he_IL")
        nameFormatterHe.dateFormat = "MMMM yyyy"
        let monthNameHe = nameFormatterHe.string(from: startOfMonth)
        
        let nameFormatterEn = DateFormatter()
        nameFormatterEn.locale = Locale(identifier: "en_US")
        nameFormatterEn.dateFormat = "MMMM yyyy"
        let monthNameEn = nameFormatterEn.string(from: startOfMonth)
        
        // Filter transactions strictly for this month [startOfMonth, endOfMonth)
        let thisMonthTxs = allTransactions.filter { tx in
            tx.timestamp >= monthInterval.start && tx.timestamp < monthInterval.end
        }
        
        // Spending transactions (exclude savings transfers and 0 amount txs)
        let spendingTxs = thisMonthTxs.filter { $0.category.canonical != .savings && $0.amount > 0 }
        let totalSpent = spendingTxs.reduce(0.0) { $0 + $1.amount }
        let renderedCity = CitySimulationEngine.shared.generateCity(
            for: startOfMonth,
            transactions: thisMonthTxs,
            estimatedMonthlyBudget: monthlyBudget ?? 0,
            now: monthInterval.end
        )
        let citySnapshot = MonthlyRecap.CitySnapshot(
            totalSavings: renderedCity.totalSavings,
            savingsTarget: renderedCity.savingsTarget,
            parkHealth: renderedCity.parkHealth,
            categoryTotals: renderedCity.categoryTotals,
            buildingTotals: renderedCity.buildingTotals,
            districtStates: renderedCity.districtStates,
            venueStates: renderedCity.venueStates,
            habits: renderedCity.habits
        )
        
        let remainingBudget: Double?
        if let b = monthlyBudget, b > 0 {
            remainingBudget = max(0, b - totalSpent)
        } else {
            remainingBudget = nil
        }
        
        // 1. Biggest District (Category with highest total spend - canonicalized)
        var categoryTotals: [SpendingCategory: Double] = [:]
        for tx in spendingTxs {
            let cat = tx.category.canonical
            categoryTotals[cat, default: 0] += tx.amount
        }
        let topCategory = categoryTotals.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }.first
        let biggestDistrict: MonthlyRecap.DistrictHighlight? = topCategory.map { cat, amt in
            MonthlyRecap.DistrictHighlight(
                nameHe: cat.displayName,
                nameEn: cat.displayNameEn,
                amount: amt,
                category: cat
            )
        }
        
        // 2. Tallest Building (Largest non-recurring purchase / ההוצאה הבולטת ביותר שאינה קבועה)
        // Prefer explicit recurring metadata, then fall back to conservative category and name rules.
        let nonRecurringTxs = spendingTxs.filter { !isLikelyRecurringOrFixed($0) }
        let maxTx = nonRecurringTxs.max(by: { $0.amount < $1.amount })
        let tallestBuilding: MonthlyRecap.BuildingHighlight? = maxTx.map { tx in
            let cleanMerchant = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let merchantName = cleanMerchant.isEmpty ? tx.category.canonical.displayName : cleanMerchant
            return MonthlyRecap.BuildingHighlight(
                merchantName: merchantName,
                amount: tx.amount,
                category: tx.category.canonical,
                date: tx.timestamp
            )
        }
        
        // 3. Busiest District (Category with highest transaction count - canonicalized)
        var categoryCounts: [SpendingCategory: Int] = [:]
        for tx in thisMonthTxs where tx.category.canonical != .savings && tx.amount > 0 {
            let cat = tx.category.canonical
            categoryCounts[cat, default: 0] += 1
        }
        let topCountCategory = categoryCounts.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }.first
        let busiestDistrict: MonthlyRecap.DistrictCountHighlight? = topCountCategory.map { cat, count in
            MonthlyRecap.DistrictCountHighlight(
                nameHe: cat.displayName,
                nameEn: cat.displayNameEn,
                transactionCount: count,
                totalAmount: categoryTotals[cat] ?? 0,
                category: cat
            )
        }
        
        // 4. Most Repeated Stop (Merchant with most visits)
        var merchantCounts: [String: (name: String, count: Int, total: Double, category: SpendingCategory)] = [:]
        for tx in spendingTxs {
            let name = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = MerchantRuleService.normalizedKey(name)
            let curr = merchantCounts[key, default: (name, 0, 0, tx.category.canonical)]
            merchantCounts[key] = (curr.name, curr.count + 1, curr.total + tx.amount, curr.category)
        }
        let repeatThreshold = spendingTxs.count < 8 ? 2 : 3
        let topMerchant = merchantCounts.values
            .filter { $0.count >= repeatThreshold }
            .max { lhs, rhs in lhs.count == rhs.count ? lhs.total < rhs.total : lhs.count < rhs.count }
        
        let mostRepeatedStop: MonthlyRecap.MerchantHighlight? = topMerchant.map { val in
            MonthlyRecap.MerchantHighlight(
                merchantName: val.name,
                visitCount: val.count,
                totalAmount: val.total,
                category: val.category
            )
        }
        
        // 5. Biggest Spending Day
        var dailyTotals: [Date: Double] = [:]
        var dailyCounts: [Date: Int] = [:]
        for tx in spendingTxs {
            let day = cal.startOfDay(for: tx.timestamp)
            dailyTotals[day, default: 0] += tx.amount
            dailyCounts[day, default: 0] += 1
        }
        let topDay = dailyTotals.max(by: { $0.value < $1.value })
        let dayFormatterHe = DateFormatter()
        dayFormatterHe.locale = Locale(identifier: "he_IL")
        dayFormatterHe.dateFormat = "EEEE, d בMMMM"
        let dayFormatterEn = DateFormatter()
        dayFormatterEn.locale = Locale(identifier: "en_US")
        dayFormatterEn.dateFormat = "EEEE, MMM d"
        
        let biggestSpendingDay: MonthlyRecap.DayHighlight? = topDay.map { date, amt in
            MonthlyRecap.DayHighlight(
                date: date,
                formattedDateHe: dayFormatterHe.string(from: date),
                formattedDateEn: dayFormatterEn.string(from: date),
                amount: amt,
                transactionCount: dailyCounts[date] ?? 0
            )
        }
        
        // 6. Month-over-Month Comparison
        var comparisonVsPrevMonth: MonthlyRecap.MonthComparison? = nil
        var previousCategoryTotals: [SpendingCategory: Double] = [:]
        if let prevMonthDate = cal.date(byAdding: .month, value: -1, to: startOfMonth),
           let prevInterval = cal.dateInterval(of: .month, for: prevMonthDate) {
            
            let prevTxs = allTransactions.filter { $0.timestamp >= prevInterval.start && $0.timestamp < prevInterval.end && $0.category.canonical != .savings && $0.amount > 0 }
            let prevTotal = prevTxs.reduce(0.0) { $0 + $1.amount }
            for tx in prevTxs {
                previousCategoryTotals[tx.category.canonical, default: 0] += tx.amount
            }
            
            if prevTotal > 0 {
                let diff = totalSpent - prevTotal
                let pct = (abs(diff) / prevTotal) * 100.0
                let isDec = diff < 0
                
                let prevNameFormatterHe = DateFormatter()
                prevNameFormatterHe.locale = Locale(identifier: "he_IL")
                prevNameFormatterHe.dateFormat = "MMMM"
                let prevNameFormatterEn = DateFormatter()
                prevNameFormatterEn.locale = Locale(identifier: "en_US")
                prevNameFormatterEn.dateFormat = "MMMM"
                
                comparisonVsPrevMonth = MonthlyRecap.MonthComparison(
                    prevMonthNameHe: prevNameFormatterHe.string(from: prevInterval.start),
                    prevMonthNameEn: prevNameFormatterEn.string(from: prevInterval.start),
                    diffAmount: abs(diff),
                    percentChange: pct,
                    isDecrease: isDec
                )
            }
        }
        
        // 7. Deterministic City Vibe Priority Hierarchy (Ordered: 1. Quiet -> 2. Record -> 3. Green -> 4. Busy -> 5. Growing)
        var allMonthlyTotals: [String: Double] = [:]
        for tx in allTransactions where tx.category.canonical != .savings && tx.amount > 0 {
            let mId = monthFormatter.string(from: tx.timestamp)
            allMonthlyTotals[mId, default: 0] += tx.amount
        }
        let historicalMax = allMonthlyTotals.values.max() ?? 0
        let isRecordHigh = totalSpent > 0 && totalSpent >= historicalMax && allMonthlyTotals.count > 1
        
        let cityVibe: MonthlyRecap.CityVibe
        if thisMonthTxs.isEmpty || totalSpent == 0 {
            cityVibe = MonthlyRecap.CityVibe(
                type: .quiet,
                titleHe: "עיר שקטה",
                titleEn: "Quiet City",
                subtitleHe: "העיר שלך נשארה קטנה וירוקה ללא הוצאות",
                subtitleEn: "Your city stayed small and green with zero spend",
                badgeIcon: "leaf.fill"
            )
        } else if isRecordHigh {
            cityVibe = MonthlyRecap.CityVibe(
                type: .recordMetropolis,
                titleHe: "המטרופולין הגדול ביותר",
                titleEn: "Biggest Metropolis Yet",
                subtitleHe: "חודש שיא עם הפעילות האדריכלית הענפה ביותר",
                subtitleEn: "Record month with the highest architectural activity",
                badgeIcon: "building.2.fill"
            )
        } else if let comp = comparisonVsPrevMonth, comp.isDecrease && comp.percentChange >= 20 {
            cityVibe = MonthlyRecap.CityVibe(
                type: .greenMonth,
                titleHe: "חודש ירוק",
                titleEn: "Green Month",
                subtitleHe: "העיר הצטמצמה עם ירידה של \(Int(comp.percentChange))% בהוצאות",
                subtitleEn: "The city consolidated with a \(Int(comp.percentChange))% drop in spending",
                badgeIcon: "tree.fill"
            )
        } else if spendingTxs.count >= 30 {
            cityVibe = MonthlyRecap.CityVibe(
                type: .busy,
                titleHe: "עיר פעילה ותוססת",
                titleEn: "Busy City",
                subtitleHe: "\(spendingTxs.count) עסקאות הזינו את העיר לאורך החודש",
                subtitleEn: "\(spendingTxs.count) purchases fueled the city throughout the month",
                badgeIcon: "flame.fill"
            )
        } else {
            cityVibe = MonthlyRecap.CityVibe(
                type: .growing,
                titleHe: "עיר צומחת",
                titleEn: "Growing City",
                subtitleHe: "התפתחות יציבה ומאוזנת של מבני העיר",
                subtitleEn: "Steady and balanced growth across city buildings",
                badgeIcon: "leaf.fill"
            )
        }
        
        // 8. "One Thing to Know" & Highlights
        let oneThingToKnow: String
        if let comp = comparisonVsPrevMonth {
            if comp.isDecrease {
                oneThingToKnow = "הוצאת ₪\(Int(comp.diffAmount)) פחות מחודש \(comp.prevMonthNameHe) (ירידה של \(Int(comp.percentChange))%)"
            } else if comp.diffAmount == 0 {
                oneThingToKnow = "סך ההוצאות זהה בדיוק לחודש \(comp.prevMonthNameHe)"
            } else {
                oneThingToKnow = "ההוצאות גדלו ב-₪\(Int(comp.diffAmount)) ביחס לחודש \(comp.prevMonthNameHe)"
            }
        } else if let b = biggestDistrict {
            oneThingToKnow = "רובע \(b.nameHe) היה המרכיב הדומיננטי בעיר עם ₪\(Int(b.amount))"
        } else {
            oneThingToKnow = "העיר נבנתה מ-\(spendingTxs.count) עסקאות החודש"
        }
        
        // Human insights describe change or rhythm; they do not repeat the headline cards.
        var highlights: [MonthlyRecap.Insight] = []
        let categoryChanges = Set(categoryTotals.keys).union(previousCategoryTotals.keys).compactMap { category -> (SpendingCategory, Double)? in
            let previous = previousCategoryTotals[category] ?? 0
            let current = categoryTotals[category] ?? 0
            guard previous >= 20 else { return nil }
            let percent = ((current - previous) / previous) * 100
            guard abs(percent) >= 20 else { return nil }
            return (category, percent)
        }.sorted { abs($0.1) > abs($1.1) }
        for (category, percent) in categoryChanges.prefix(2) {
            let directionHe = percent < 0 ? "פחות" : "יותר"
            let directionEn = percent < 0 ? "less" : "more"
            highlights.append(.init(
                id: "category-\(category.rawValue)",
                textHe: "\(Int(abs(percent)))% \(directionHe) ב\(category.shortName) לעומת החודש הקודם.",
                textEn: "\(Int(abs(percent)))% \(directionEn) on \(category.shortNameEn) than last month."
            ))
        }
        let weekendCount = spendingTxs.filter {
            let weekday = cal.component(.weekday, from: $0.timestamp)
            return weekday == 6 || weekday == 7
        }.count
        if spendingTxs.count >= 4, Double(weekendCount) / Double(spendingTxs.count) >= 0.55, highlights.count < 3 {
            highlights.append(.init(
                id: "weekend-rhythm",
                textHe: "רוב הפעילות בעיר התרחשה בסוף השבוע.",
                textEn: "Most of the city's activity happened over the weekend."
            ))
        }
        
        return MonthlyRecap(
            monthId: monthId,
            date: startOfMonth,
            monthNameHe: monthNameHe,
            monthNameEn: monthNameEn,
            totalSpent: totalSpent,
            transactionCount: spendingTxs.count,
            remainingBudget: remainingBudget,
            biggestDistrict: biggestDistrict,
            tallestBuilding: tallestBuilding,
            busiestDistrict: busiestDistrict,
            mostRepeatedStop: mostRepeatedStop,
            biggestSpendingDay: biggestSpendingDay,
            comparisonVsPrevMonth: comparisonVsPrevMonth,
            cityVibe: cityVibe,
            oneThingToKnow: oneThingToKnow,
            highlights: highlights,
            dynamicInsights: MonthlyRecapInsightSelector.select(for: monthDate, transactions: allTransactions),
            city: citySnapshot
        )
    }
    
    static func isLikelyRecurringOrFixed(_ tx: Transaction) -> Bool {
        let cat = tx.category.canonical
        if tx.note == "הוצאה קבועה" || tx.installmentPlanId != nil { return true }
        if cat == .housing || cat == .subscriptions { return true }
        let lower = (tx.merchant + " " + (tx.note ?? "")).lowercased()
        let fixedKeywords = [
            "שכירות", "משכנתא", "ארנונה", "ועד בית", "ביטוח", "מנוי", "שכר דירה",
            "rent", "mortgage", "insurance", "subscription"
        ]
        return fixedKeywords.contains(where: { lower.contains($0) })
    }


    /// Returns all available past months that have transactions or recaps.
    public static func availableRecapMonths(from allTransactions: [Transaction]) -> [Date] {
        let cal = Calendar(identifier: .gregorian)
        var monthSet: Set<Date> = []
        for tx in allTransactions {
            if let monthInterval = cal.dateInterval(of: .month, for: tx.timestamp) {
                monthSet.insert(monthInterval.start)
            }
        }
        if let currentInterval = cal.dateInterval(of: .month, for: Date()) {
            monthSet.insert(currentInterval.start)
        }
        return monthSet.sorted(by: { $0 > $1 })
    }
    
    private static func fallbackEmptyRecap(for date: Date) -> MonthlyRecap {
        MonthlyRecap(
            monthId: "current",
            date: date,
            monthNameHe: "חודש נוכחי",
            monthNameEn: "Current Month",
            totalSpent: 0,
            transactionCount: 0,
            remainingBudget: nil,
            biggestDistrict: nil,
            tallestBuilding: nil,
            busiestDistrict: nil,
            mostRepeatedStop: nil,
            biggestSpendingDay: nil,
            comparisonVsPrevMonth: nil,
            cityVibe: MonthlyRecap.CityVibe(
                type: .quiet,
                titleHe: "עיר שקטה",
                titleEn: "Quiet City",
                subtitleHe: "העיר פנויה ומוכנה לצמיחה",
                subtitleEn: "City is ready to grow",
                badgeIcon: "leaf.fill"
            ),
            oneThingToKnow: "העיר שלך ממתינה לעסקה הראשונה",
            highlights: [],
            city: MonthlyRecap.CitySnapshot(
                totalSavings: 0,
                savingsTarget: 0,
                parkHealth: CitySimulationEngine.healthyParkLevel,
                categoryTotals: [:],
                buildingTotals: [:],
                districtStates: CitySimulationEngine.districtStates(for: [:]),
                venueStates: [],
                habits: BehavioralHabits()
            )
        )
    }
}

// MARK: - Editorial selection (data, never animation or view state)

public struct MonthlyRecapDynamicInsight: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable { case merchantRepeat, biggestPurchase, biggestDay, monthChange, categoryChange, weekendRhythm }
    public enum VisualTheme: String, Sendable { case storefronts, tower, street, skylines, road, park }
    public var id: String { type.rawValue + (category?.rawValue ?? "") }
    public let type: Kind
    public let primaryValue: Double
    public let secondaryValue: Double
    public let count: Int
    public let category: SpendingCategory?
    public let merchant: String?
    public let date: Date?
    public let score: Double
    public let copyVariant: String
    public var visualTheme: VisualTheme {
        switch type {
        case .merchantRepeat: .storefronts
        case .biggestPurchase: .tower
        case .biggestDay: .street
        case .monthChange: .skylines
        case .categoryChange: .road
        case .weekendRhythm: .park
        }
    }
}

public enum MonthlyRecapInsightSelector {
    /// At most two strong, distinct stories. Sparse months keep the five editorial anchors.
    /// Calendar-month comparisons are omitted for an unfinished month.
    public static func select(for month: Date, transactions: [Transaction], now: Date = Date()) -> [MonthlyRecapDynamicInsight] {
        let cal = Calendar(identifier: .gregorian)
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let spend = transactions.filter {
            $0.timestamp >= interval.start && $0.timestamp < interval.end &&
            $0.amount.isFinite && $0.amount > 0 && $0.category.canonical != .savings
        }
        guard spend.count >= 4 else { return [] }
        let total = spend.reduce(0) { $0 + $1.amount }
        let variable = spend.filter { !MonthlyRecapService.isLikelyRecurringOrFixed($0) }
        let average = total / Double(spend.count)
        var candidates: [MonthlyRecapDynamicInsight] = []
        func add(_ type: MonthlyRecapDynamicInsight.Kind, _ value: Double, secondary: Double = 0,
                 count: Int = 0, category: SpendingCategory? = nil, merchant: String? = nil,
                 date: Date? = nil, score: Double, variant: String = "default") {
            guard value.isFinite, secondary.isFinite, score.isFinite else { return }
            candidates.append(.init(type: type, primaryValue: value, secondaryValue: secondary,
                count: count, category: category, merchant: merchant, date: date, score: score, copyVariant: variant))
        }
        let groups = Dictionary(grouping: variable.filter { !$0.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            MerchantRuleService.normalizedKey($0.merchant)
        }.sorted { lhs, rhs in lhs.value.count == rhs.value.count ? lhs.key < rhs.key : lhs.value.count > rhs.value.count }
        if let winner = groups.first {
            let visits = winner.value.count
            let second = groups.dropFirst().first?.value.count ?? 0
            let share = Double(visits) / Double(spend.count)
            if visits >= 3 && (visits >= 5 || share >= 0.25) && Double(visits) >= Double(max(1, second)) * 1.5 {
                let representative = winner.value.sorted { $0.timestamp == $1.timestamp ? $0.merchant < $1.merchant : $0.timestamp < $1.timestamp }.first!
                add(.merchantRepeat, Double(visits), secondary: winner.value.reduce(0) { $0 + $1.amount },
                    count: visits, category: representative.category.canonical,
                    merchant: representative.merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                    score: 65 + min(20, Double(visits) * 2) + share * 15)
            }
        }
        if let largest = variable.sorted(by: {
            if $0.amount != $1.amount { return $0.amount > $1.amount }
            if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
            return $0.merchant + $0.category.rawValue < $1.merchant + $1.category.rawValue
        }).first {
            let ratio = largest.amount / average
            if ratio >= 3 {
                add(.biggestPurchase, largest.amount, secondary: ratio, category: largest.category.canonical,
                    merchant: largest.merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                    date: largest.timestamp, score: 62 + min(30, ratio * 3))
            }
        }
        let days = Dictionary(grouping: variable) { cal.startOfDay(for: $0.timestamp) }
        var dayTotals: [(day: Date, amount: Double, count: Int)] = []
        for (date, purchases) in days {
            let amount = purchases.reduce(0.0) { $0 + $1.amount }
            dayTotals.append((date, amount, purchases.count))
        }
        dayTotals.sort { $0.amount == $1.amount ? $0.day < $1.day : $0.amount > $1.amount }
        if days.count >= 3, let day = dayTotals.first, day.count >= 2 {
            let dayAverage = variable.reduce(0) { $0 + $1.amount } / Double(days.count)
            let ratio = day.amount / dayAverage
            if ratio >= 2.2 {
                add(.biggestDay, day.amount, secondary: ratio, count: day.count, date: day.day,
                    score: 60 + min(30, ratio * 5), variant: "variable-spend")
            }
        }
        if interval.end <= now,
           let previousDate = cal.date(byAdding: .month, value: -1, to: interval.start),
           let previousInterval = cal.dateInterval(of: .month, for: previousDate) {
            let previous = transactions.filter {
                $0.timestamp >= previousInterval.start && $0.timestamp < previousInterval.end &&
                $0.amount.isFinite && $0.amount > 0 && $0.category.canonical != .savings
            }
            let previousTotal = previous.reduce(0) { $0 + $1.amount }
            if previousTotal > 0 {
                let change = (total - previousTotal) / previousTotal * 100
                if abs(change) >= 15 {
                    add(.monthChange, change, secondary: previousTotal, date: previousInterval.start,
                        score: 65 + min(30, abs(change) * 0.4), variant: change < 0 ? "less" : "more")
                }
                let currentCategories = Dictionary(grouping: spend) { $0.category.canonical }.mapValues { $0.reduce(0) { $0 + $1.amount } }
                let previousCategories = Dictionary(grouping: previous) { $0.category.canonical }.mapValues { $0.reduce(0) { $0 + $1.amount } }
                let leading = currentCategories.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }.first?.key
                for (category, old) in previousCategories where category != leading {
                    let current = currentCategories[category] ?? 0
                    let change = (current - old) / old * 100
                    if old >= max(50, previousTotal * 0.02), abs(current - old) >= max(50, total * 0.05), abs(change) >= 40 {
                        add(.categoryChange, change, secondary: current, category: category,
                            date: previousInterval.start, score: 58 + min(28, abs(change) * 0.15),
                            variant: change < 0 ? "less" : "more")
                    }
                }
            }
        }
        let weekend = spend.filter { [6, 7].contains(cal.component(.weekday, from: $0.timestamp)) }.count
        if spend.count >= 8, Double(weekend) / Double(spend.count) >= 0.65 {
            add(.weekendRhythm, Double(weekend) / Double(spend.count) * 100, count: weekend, score: 62, variant: "friday-saturday")
        }
        let ranked = candidates.sorted { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }
        var selected: [MonthlyRecapDynamicInsight] = []
        for candidate in ranked {
            let overlaps = selected.contains { chosen in
                if chosen.visualTheme == candidate.visualTheme { return true }
                if let category = chosen.category, category == candidate.category { return true }
                // A single large purchase must not be retold as its unusually expensive day.
                if Set([chosen.type, candidate.type]) == Set([.biggestPurchase, .biggestDay]),
                   let a = chosen.date, let b = candidate.date, cal.isDate(a, inSameDayAs: b) { return true }
                if Set([chosen.type, candidate.type]) == Set([.monthChange, .categoryChange]) { return true }
                return false
            }
            if !overlaps { selected.append(candidate) }
            if selected.count == 2 { break }
        }
        return selected
    }
}
