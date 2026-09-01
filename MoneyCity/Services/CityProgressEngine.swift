import Foundation
import SwiftUI

/// Available city enrichment / repair option offered to the user upon achieving positive progress.
public struct ProgressRewardOption: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: String
    public let type: EnrichmentType
    public let tier: String // "small", "medium", "large"
    public let actionType: String // "ADD" or "IMPROVE / REPAIR"
    public let districtId: String // "food", "shopping", "housing", "savings", "city"
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        type: EnrichmentType,
        tier: String,
        actionType: String,
        districtId: String = "city"
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.type = type
        self.tier = tier
        self.actionType = actionType
        self.districtId = districtId
    }
}

/// The computed result of the user's Week-over-Week personal progress.
public struct WeeklyProgressReport: Sendable {
    public let currentWeekTotal: Double
    public let previousWeekTotal: Double
    public let savedAmount: Double
    public let hasPositiveProgress: Bool
    public let progressTier: String // "small", "medium", "large", "none"
    public let availableOptions: [ProgressRewardOption]
    
    public init(
        currentWeekTotal: Double,
        previousWeekTotal: Double,
        savedAmount: Double,
        hasPositiveProgress: Bool,
        progressTier: String,
        availableOptions: [ProgressRewardOption]
    ) {
        self.currentWeekTotal = currentWeekTotal
        self.previousWeekTotal = previousWeekTotal
        self.savedAmount = savedAmount
        self.hasPositiveProgress = hasPositiveProgress
        self.progressTier = progressTier
        self.availableOptions = availableOptions
    }
}

/// Evaluates personal progress (Week-over-Week) independently from spending-driven city reality.
public final class CityProgressEngine: Sendable {
    public static let shared = CityProgressEngine()
    
    private init() {}
    
    /// Catalog of available progress additions and repairs across tiers
    public let allCatalogOptions: [ProgressRewardOption] = [
        // --- SMALL PROGRESS (₪30 - ₪200 less than previous week) ---
        ProgressRewardOption(
            id: "tree_sakura",
            title: "עץ סקורה פריחה ורודה",
            subtitle: "מוסיף צבע וטבע יפני לשדרת העיר",
            icon: "leaf.fill",
            type: .nature,
            tier: "small",
            actionType: "ADD",
            districtId: "savings"
        ),
        ProgressRewardOption(
            id: "flower_bed_plaza",
            title: "ערוגת פרחים ססגונית",
            subtitle: "פרחי נוי מסביב לשדרת הקניות",
            icon: "camera.macro",
            type: .nature,
            tier: "small",
            actionType: "ADD",
            districtId: "shopping"
        ),
        ProgressRewardOption(
            id: "repair_bench",
            title: "חידוש ספסל הפארק",
            subtitle: "ספסל עץ מחודש ומלוטש ליד האגם",
            icon: "chair.lounge.fill",
            type: .repair,
            tier: "small",
            actionType: "IMPROVE / REPAIR",
            districtId: "savings"
        ),
        ProgressRewardOption(
            id: "repair_lamp",
            title: "שדרוג פנס רחוב קלאסי",
            subtitle: "תאורה חמימה ונעימה בשדרה המרכזית",
            icon: "lamp.desk.fill",
            type: .repair,
            tier: "small",
            actionType: "IMPROVE / REPAIR",
            districtId: "food"
        ),
        
        // --- MEDIUM PROGRESS (₪201 - ₪500 less than previous week) ---
        ProgressRewardOption(
            id: "resident_artist",
            title: "תושבת חדשה: אמנית רחוב",
            subtitle: "מציירת על כן ציור ברחבת האוכל",
            icon: "paintpalette.fill",
            type: .resident,
            tier: "medium",
            actionType: "ADD",
            districtId: "food"
        ),
        ProgressRewardOption(
            id: "pet_cat_rooftop",
            title: "חתול עיר ג'ינג'י שובב",
            subtitle: "מטייל ורובץ בנחת על המעקות והמדרכות",
            icon: "pawprint.fill",
            type: .pet,
            tier: "medium",
            actionType: "ADD",
            districtId: "shopping"
        ),
        ProgressRewardOption(
            id: "bike_station",
            title: "עמדת אופניים ירוקה",
            subtitle: "אופניים עירוניים זמינים לרכיבה",
            icon: "bicycle",
            type: .decoration,
            tier: "medium",
            actionType: "ADD",
            districtId: "housing"
        ),
        ProgressRewardOption(
            id: "cafe_stand",
            title: "דוכן קפה ארטיזנלי",
            subtitle: "עגלת קפה עם ניחוח טרי בכיכר",
            icon: "cup.and.saucer.fill",
            type: .decoration,
            tier: "medium",
            actionType: "ADD",
            districtId: "food"
        ),
        ProgressRewardOption(
            id: "repair_sidewalk",
            title: "תיקון ריצוף מדרכה",
            subtitle: "מדרכת אבן מלוטשת ומושלמת להליכה",
            icon: "square.grid.2x2.fill",
            type: .repair,
            tier: "medium",
            actionType: "IMPROVE / REPAIR",
            districtId: "shopping"
        ),
        
        // --- LARGE PROGRESS (₪500+ less than previous week) ---
        ProgressRewardOption(
            id: "fountain_marble",
            title: "מזרקת שיש מרכזית",
            subtitle: "מזרקת מים מרהיבה עם מים זורמים בכיכר העיר",
            icon: "drop.fill",
            type: .landmark,
            tier: "large",
            actionType: "ADD",
            districtId: "city"
        ),
        ProgressRewardOption(
            id: "pet_golden_dog",
            title: "גור גולדן רטריבר עליז",
            subtitle: "מתרוצץ ומכשכש בזנב בשמורת החיסכון",
            icon: "pawprint.fill",
            type: .pet,
            tier: "large",
            actionType: "ADD",
            districtId: "savings"
        ),
        ProgressRewardOption(
            id: "park_bridge",
            title: "גשר עץ מעוצב מעל האגם",
            subtitle: "גשר יפני מסורתי המחבר את שבילי הפארק",
            icon: "building.2.fill",
            type: .landmark,
            tier: "large",
            actionType: "ADD",
            districtId: "savings"
        ),
        ProgressRewardOption(
            id: "public_art_sculpture",
            title: "פסל אמנות מודרנית",
            subtitle: "מונומנט גיאומטרי מרשים בכניסה לעיר",
            icon: "cube.transparent.fill",
            type: .decoration,
            tier: "large",
            actionType: "ADD",
            districtId: "shopping"
        )
    ]
    
    /// Evaluates personal week-over-week progress accurately, excluding fixed costs (rent, subscriptions, savings)
    public func evaluateProgress(
        transactions: [Transaction],
        unlockedItemIds: Set<String>,
        referenceDate: Date = Date()
    ) -> WeeklyProgressReport {
        let calendar = Calendar.current
        
        let currentWeekStart = calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        let previousWeekStart = calendar.date(byAdding: .day, value: -14, to: referenceDate) ?? referenceDate
        
        // Exclude fixed housing, subscriptions, finance, and savings to focus purely on variable daily behavior
        let isVariableExpense: (Transaction) -> Bool = { tx in
            tx.category != .savings && tx.category != .housing && tx.category != .subscriptions && tx.category != .finance
        }
        
        let currentWeekTxs = transactions.filter {
            $0.timestamp >= currentWeekStart && $0.timestamp <= referenceDate && isVariableExpense($0)
        }
        let prevWeekTxs = transactions.filter {
            $0.timestamp >= previousWeekStart && $0.timestamp < currentWeekStart && isVariableExpense($0)
        }
        
        let currentTotal = currentWeekTxs.reduce(0.0) { $0 + $1.amount }
        let prevTotal = prevWeekTxs.reduce(0.0) { $0 + $1.amount }
        
        // If there are no past week transactions, we do not invent fake baseline
        guard prevTotal > 0 else {
            return WeeklyProgressReport(
                currentWeekTotal: currentTotal,
                previousWeekTotal: 0.0,
                savedAmount: 0.0,
                hasPositiveProgress: false,
                progressTier: "none",
                availableOptions: []
            )
        }
        
        let diff = prevTotal - currentTotal
        let hasProgress = diff > 10.0 // At least ₪10 real reduction
        let saved = max(0.0, diff)
        
        let tier: String
        if !hasProgress {
            tier = "none"
        } else if saved < 200.0 {
            tier = "small"
        } else if saved < 500.0 {
            tier = "medium"
        } else {
            tier = "large"
        }
        
        // Filter options suitable for the tier that haven't been unlocked yet
        let tierFiltered = allCatalogOptions.filter { opt in
            if unlockedItemIds.contains(opt.id) { return false }
            if tier == "large" { return true }
            if tier == "medium" { return opt.tier == "medium" || opt.tier == "small" }
            if tier == "small" { return opt.tier == "small" }
            return false
        }
        
        let available = Array(tierFiltered.prefix(3))
        
        return WeeklyProgressReport(
            currentWeekTotal: currentTotal,
            previousWeekTotal: prevTotal,
            savedAmount: saved,
            hasPositiveProgress: hasProgress,
            progressTier: tier,
            availableOptions: available
        )
    }
}
