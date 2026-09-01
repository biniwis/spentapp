import Foundation
import SwiftData

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
    public let highlights: [String]
    
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
    }
}

public enum MonthlyRecapService {
    
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
            monthInterval.contains(tx.timestamp)
        }
        
        // Spending transactions (exclude savings transfers and 0 amount txs)
        let spendingTxs = thisMonthTxs.filter { $0.category.canonical != .savings && $0.amount > 0 }
        let totalSpent = spendingTxs.reduce(0.0) { $0 + $1.amount }
        
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
        let topCategory = categoryTotals.max(by: { $0.value < $1.value })
        let biggestDistrict: MonthlyRecap.DistrictHighlight? = topCategory.map { cat, amt in
            MonthlyRecap.DistrictHighlight(
                nameHe: cat.displayName,
                nameEn: cat.displayNameEn,
                amount: amt,
                category: cat
            )
        }
        
        // 2. Tallest Building (Single largest positive transaction)
        let maxTx = spendingTxs.max(by: { $0.amount < $1.amount })
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
        let topCountCategory = categoryCounts.max(by: { $0.value < $1.value })
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
        var merchantCounts: [String: (count: Int, total: Double, category: SpendingCategory)] = [:]
        for tx in thisMonthTxs where tx.amount > 0 {
            let name = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let curr = merchantCounts[name, default: (0, 0, tx.category.canonical)]
            merchantCounts[name] = (curr.count + 1, curr.total + tx.amount, tx.category.canonical)
        }
        let topMerchant = merchantCounts.filter({ $0.value.count > 1 }).max(by: { $0.value.count < $1.value.count })
            ?? merchantCounts.max(by: { $0.value.count < $1.value.count })
        
        let mostRepeatedStop: MonthlyRecap.MerchantHighlight? = topMerchant.map { name, val in
            MonthlyRecap.MerchantHighlight(
                merchantName: name,
                visitCount: val.count,
                totalAmount: val.total,
                category: val.category
            )
        }
        
        // 5. Biggest Spending Day
        var dailyTotals: [Date: Double] = [:]
        for tx in spendingTxs {
            let day = cal.startOfDay(for: tx.timestamp)
            dailyTotals[day, default: 0] += tx.amount
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
                amount: amt
            )
        }
        
        // 6. Month-over-Month Comparison
        var comparisonVsPrevMonth: MonthlyRecap.MonthComparison? = nil
        if let prevMonthDate = cal.date(byAdding: .month, value: -1, to: startOfMonth),
           let prevInterval = cal.dateInterval(of: .month, for: prevMonthDate) {
            
            let prevTxs = allTransactions.filter { prevInterval.contains($0.timestamp) && $0.category.canonical != .savings && $0.amount > 0 }
            let prevTotal = prevTxs.reduce(0.0) { $0 + $1.amount }
            
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
        
        var highlights: [String] = []
        if let b = biggestDistrict {
            highlights.append("רובע \(b.nameHe) היה הרובע הגדול ביותר (₪\(Int(b.amount)))")
        }
        if let t = tallestBuilding {
            highlights.append("המבנה הגבוה ביותר: \(t.merchantName) (₪\(Int(t.amount)))")
        }
        if let r = mostRepeatedStop {
            highlights.append("העצירה החוזרת: \(r.merchantName) (\(r.visitCount) ביקורים)")
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
            highlights: highlights
        )
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
            highlights: []
        )
    }
}
