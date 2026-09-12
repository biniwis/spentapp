import SwiftUI

/// The definitive 9 core financial categories for V1 (based on standard financial taxonomy).
public enum SpendingCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case housing = "housing"               // בית (שכירות, חשמל, מים, אינטרנט, תחזוקה)
    case food = "food"                     // אוכל (סופר, מסעדות, משלוחים, קפה)
    case transport = "transport"           // תחבורה (דלק, חניה, אוטובוס/רכבת, Gett, תיקונים)
    case shopping = "shopping"             // קניות (בגדים, אלקטרוניקה, דברים לבית)
    case entertainment = "entertainment"   // בילויים (קולנוע, הופעות, ברים, משחקים, תחביבים)
    case health = "health"                 // בריאות (רופא, תרופות, שיניים, טיפוח, כושר)
    case subscriptions = "subscriptions"   // מנויים וחשבונות (Netflix, Spotify, אפליקציות, סלולר)
    case finance = "finance"               // כספים (עמלות, ריבית, החזרי חוב)
    case savings = "savings"               // חיסכון והשקעות (קרנות, S&P500, חיסכון חודשי)
    case miscellaneous = "miscellaneous"   // שונות — מוזיאון הדברים המשונים (מתנות, תרומות, קנסות, פריטים מיוחדים)
    case other = "other"                   // אחר — בית הדואר ומרכז המיון (עסקאות שממתינות למיון)
    
    // Legacy aliases for backward compatibility
    case groceries = "groceries"
    case coffee = "coffee"
    case misc = "misc"

    public var id: String { rawValue }
    
    /// Collapses legacy aliases onto their canonical representation.
    public var canonical: SpendingCategory {
        switch self {
        case .groceries, .coffee: return .food
        case .misc: return .miscellaneous
        default: return self
        }
    }

    /// Distinct primary categories for UI selectors (excludes legacy aliases)
    public static var primaryCategories: [SpendingCategory] {
        [.housing, .food, .transport, .shopping, .entertainment, .health, .subscriptions, .savings, .finance, .miscellaneous, .other]
    }
    
    /// User-facing localized category name (Hebrew or English)
    public func displayName(for language: AppLanguage) -> String {
        if language == .english {
            return displayNameEn
        }
        switch canonical {
        case .housing: return "דיור ובית"
        case .food, .groceries, .coffee: return "אוכל ומסעדות"
        case .transport: return "תחבורה ורכב"
        case .shopping: return "קניות ומוצרים"
        case .entertainment: return "בילויים ופנאי"
        case .health: return "בריאות וכושר"
        case .subscriptions: return "מנויים וחשבונות"
        case .finance: return "עמלות ובנקים"
        case .savings: return "חיסכון והשקעות"
        case .miscellaneous, .misc: return "שונות"
        case .other: return "לא מסווג"
        }
    }

    /// User-facing localized category name using current app preference
    public var displayName: String {
        let isEn = UserDefaults.standard.string(forKey: "app_language_pref") == AppLanguage.english.rawValue
        return displayName(for: isEn ? .english : .hebrew)
    }
    
    /// User-facing display name in English
    public var displayNameEn: String {
        switch canonical {
        case .housing: return "Housing & Home"
        case .food, .groceries, .coffee: return "Food & Dining"
        case .transport: return "Transportation"
        case .shopping: return "Shopping & Goods"
        case .entertainment: return "Entertainment & Leisure"
        case .health: return "Health & Fitness"
        case .subscriptions: return "Subscriptions & Bills"
        case .finance: return "Bank & Fees"
        case .savings: return "Savings & Investments"
        case .miscellaneous, .misc: return "Miscellaneous"
        case .other: return "Uncategorized"
        }
    }
    
    /// User-facing short name for compact badges & buttons in given language
    public func shortName(for language: AppLanguage) -> String {
        if language == .english {
            return shortNameEn
        }
        switch canonical {
        case .housing: return "דיור ובית"
        case .food, .groceries, .coffee: return "אוכל"
        case .transport: return "תחבורה"
        case .shopping: return "קניות"
        case .entertainment: return "בילויים"
        case .health: return "בריאות"
        case .subscriptions: return "מנויים"
        case .finance: return "בנק ועמלות"
        case .savings: return "חיסכון"
        case .miscellaneous, .misc: return "שונות"
        case .other: return "לא מסווג"
        }
    }

    /// User-facing short name for compact badges using current app preference
    public var shortName: String {
        let isEn = UserDefaults.standard.string(forKey: "app_language_pref") == AppLanguage.english.rawValue
        return shortName(for: isEn ? .english : .hebrew)
    }

    /// Short name in English
    public var shortNameEn: String {
        switch canonical {
        case .housing: return "Housing"
        case .food, .groceries, .coffee: return "Food"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .health: return "Health"
        case .subscriptions: return "Subscriptions"
        case .finance: return "Bank"
        case .savings: return "Savings"
        case .miscellaneous, .misc: return "Misc"
        case .other: return "Uncategorized"
        }
    }
    
    /// System icon representation
    public var emoji: String {
        return ""
    }
    
    /// Classification of expense behavior for City Diorama architectural morphology
    public var expenseType: ExpenseType {
        switch self {
        case .housing, .subscriptions:
            return .fixedRecurring       // מבנים גדולים וקבועים (מגדלי דיור ותשתיות)
        case .food, .shopping, .entertainment, .health, .groceries, .coffee:
            return .dailyLifestyle        // רחוב שוקק: חנויות, מסעדות, בתי קפה ובוטיק
        case .transport:
            return .mobilityMovement      // תנועה ורכבים: כבישים, מוניות, רכבים וקורקינטים
        case .other, .finance, .miscellaneous, .misc:
            return .occasionalSpecial     // מבנים ודוכנים מיוחדים (מוזיאון, דואר)
        case .savings:
            return .naturePreserve        // שטחים פתוחים, פארקים, אגמים ומזרקות
        }
    }
    
    public var floatingTag: String {
        switch self {
        case .housing: return "RESIDENCE"
        case .food, .groceries, .coffee: return "FOOD & DINING"
        case .transport: return "MOBILITY"
        case .shopping: return "SHOPPING"
        case .entertainment: return "ENTERTAINMENT"
        case .health: return "HEALTH & WELLNESS"
        case .subscriptions: return "SUBSCRIPTIONS"
        case .finance: return "FINANCE"
        case .savings: return "SAVINGS PARK"
        case .miscellaneous, .misc: return "MISCELLANEOUS"
        case .other: return "UNCATEGORIZED"
        }
    }
    
    public var sfSymbol: String {
        switch self {
        case .housing: return "building.fill"
        case .food, .groceries, .coffee: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .entertainment: return "gamecontroller.fill"
        case .health: return "heart.fill"
        case .subscriptions: return "play.tv.fill"
        case .finance: return "creditcard.fill"
        case .savings: return "tree.fill"
        case .miscellaneous, .misc: return "building.columns.fill"
        case .other: return "shippingbox.fill"
        }
    }
    
    public var themeColor: Color {
        switch canonical {
        case .housing: return MoneyCityTheme.orangeRed
        case .food, .groceries, .coffee: return MoneyCityTheme.orangeRed
        case .transport: return MoneyCityTheme.violetBlue
        case .shopping: return MoneyCityTheme.violetBlue
        case .entertainment: return MoneyCityTheme.violetBlue
        case .health: return MoneyCityTheme.orangeRed
        case .subscriptions: return MoneyCityTheme.violetBlue
        case .finance: return MoneyCityTheme.violetBlue
        case .savings: return MoneyCityTheme.luckyGreen
        case .miscellaneous, .misc: return MoneyCityTheme.neonLime
        case .other: return MoneyCityTheme.textMuted
        }
    }

    public var softBackgroundColor: Color {
        switch canonical {
        case .housing: return MoneyCityTheme.warmCream
        case .food, .groceries, .coffee: return MoneyCityTheme.warmCream
        case .transport: return MoneyCityTheme.babyBlue
        case .shopping: return MoneyCityTheme.babyBlue
        case .entertainment: return MoneyCityTheme.babyBlue
        case .health: return MoneyCityTheme.orangeRed.opacity(0.12)
        case .subscriptions: return MoneyCityTheme.babyBlue
        case .finance: return MoneyCityTheme.babyBlue
        case .savings: return MoneyCityTheme.luckyGreen.opacity(0.12)
        case .miscellaneous, .misc: return MoneyCityTheme.neonLime.opacity(0.25)
        case .other: return MoneyCityTheme.borderSubtle
        }
    }

    public var iconType: MoneyIconType {
        switch self.canonical {
        case .housing: return .home
        case .food, .groceries, .coffee: return .cutlery
        case .transport: return .car
        case .shopping: return .shoppingBag
        case .entertainment: return .gamepad
        case .health: return .medicalCross
        case .subscriptions: return .refresh
        case .savings: return .leaf
        case .finance: return .creditCard
        case .miscellaneous, .misc: return .gift
        case .other: return .mail
        }
    }
}

public enum ExpenseType: String, Sendable {
    case fixedRecurring       // הוצאות קבועות → בניינים גדולים וקבועים
    case dailyLifestyle        // הוצאות יומיומיות → חנויות/רחובות
    case mobilityMovement      // תחבורה ותנועה → כבישים ורכבים
    case occasionalSpecial     // הוצאות חד-פעמיות → מבנים מיוחדים
    case naturePreserve        // חיסכון → פארקים ושטחים פתוחים
}
