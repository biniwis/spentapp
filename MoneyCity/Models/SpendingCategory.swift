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
        case .other: return "אחר (למיון)"
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
        case .other: return "Unsorted (Post Office)"
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
        case .other: return "דואר"
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
        case .entertainment: return "Fun"
        case .health: return "Health"
        case .subscriptions: return "Bills"
        case .finance: return "Bank"
        case .savings: return "Savings"
        case .miscellaneous, .misc: return "Misc"
        case .other: return "Unsorted"
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
        case .miscellaneous, .misc: return "MUSEUM OF CURIOSITIES"
        case .other: return "POST OFFICE"
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
        switch self {
        case .housing: return Color(red: 37/255, green: 60/255, blue: 196/255)       // Royal Blue #253CC4
        case .food, .groceries, .coffee: return Color(red: 53/255, green: 174/255, blue: 183/255) // Turquoise #35AEB7
        case .transport: return Color(red: 244/255, green: 122/255, blue: 40/255)    // Warm Orange #F47A28
        case .shopping: return Color(red: 124/255, green: 114/255, blue: 255/255)    // Lavender #7C72FF
        case .entertainment: return Color(red: 245/255, green: 158/255, blue: 11/255)// Soft Amber #F59E0B
        case .health: return Color(red: 236/255, green: 72/255, blue: 153/255)       // Soft Pink #EC4899
        case .subscriptions: return Color(red: 59/255, green: 130/255, blue: 246/255) // Ocean Blue #3B82F6
        case .finance: return Color(red: 100/255, green: 116/255, blue: 139/255)     // Slate Navy #64748B
        case .savings: return Color(red: 16/255, green: 185/255, blue: 129/255)      // Mint Green #10B981
        case .miscellaneous, .misc: return Color(red: 139/255, green: 92/255, blue: 246/255) // Royal Violet #8B5CF6
        case .other: return Color(red: 249/255, green: 115/255, blue: 22/255)        // Postal Amber Orange #F97316
        }
    }

    public var softBackgroundColor: Color {
        switch self {
        case .housing: return Color(red: 238/255, green: 237/255, blue: 254/255)     // #EEEDFE
        case .food, .groceries, .coffee: return Color(red: 230/255, green: 247/255, blue: 248/255) // #E6F7F8
        case .transport: return Color(red: 254/255, green: 242/255, blue: 232/255)    // #FEF2E8
        case .shopping: return Color(red: 232/255, green: 229/255, blue: 255/255)     // #E8E5FF
        case .entertainment: return Color(red: 255/255, green: 240/255, blue: 199/255)// #FFF0C7
        case .health: return Color(red: 249/255, green: 225/255, blue: 232/255)        // #F9E1E8
        case .subscriptions: return Color(red: 239/255, green: 246/255, blue: 255/255)// #EFF6FF
        case .finance: return Color(red: 241/255, green: 245/255, blue: 249/255)       // #F1F5F9
        case .savings: return Color(red: 221/255, green: 243/255, blue: 234/255)       // #DDF3EA
        case .miscellaneous, .misc: return Color(red: 245/255, green: 243/255, blue: 255/255) // #F5F3FF
        case .other: return Color(red: 255/255, green: 247/255, blue: 237/255)         // #FFF7ED
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
