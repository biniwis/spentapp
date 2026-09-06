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
        case .housing: return Color(red: 2/255, green: 132/255, blue: 199/255)       // Sky Blue #0284C7
        case .food, .groceries, .coffee: return Color(red: 249/255, green: 115/255, blue: 22/255) // Warm Orange #F97316
        case .transport: return Color(red: 34/255, green: 197/255, blue: 94/255)    // Fresh Green #22C55E
        case .shopping: return Color(red: 236/255, green: 72/255, blue: 153/255)    // Soft Pink #EC4899
        case .entertainment: return Color(red: 168/255, green: 85/255, blue: 247/255)// Purple #A855F7
        case .health: return Color(red: 244/255, green: 63/255, blue: 94/255)       // Soft Rose #F43F5E
        case .subscriptions: return Color(red: 59/255, green: 130/255, blue: 246/255) // Royal Blue #3B82F6
        case .finance: return Color(red: 139/255, green: 92/255, blue: 246/255)     // Lavender Violet #8B5CF6
        case .savings: return Color(red: 16/255, green: 185/255, blue: 129/255)      // Mint Green #10B981
        case .miscellaneous, .misc: return Color(red: 99/255, green: 102/255, blue: 241/255) // Indigo #6366F1
        case .other: return Color(red: 100/255, green: 116/255, blue: 139/255)        // Neutral Slate #64748B
        }
    }

    public var softBackgroundColor: Color {
        switch self {
        case .housing: return Color(red: 224/255, green: 242/255, blue: 254/255)     // #E0F2FE
        case .food, .groceries, .coffee: return Color(red: 255/255, green: 237/255, blue: 213/255) // #FFEDD5 Warm Peach
        case .transport: return Color(red: 220/255, green: 252/255, blue: 231/255)    // #DCFCE7 Mint Soft
        case .shopping: return Color(red: 252/255, green: 231/255, blue: 243/255)     // #FCE7F3 Pink Soft
        case .entertainment: return Color(red: 243/255, green: 232/255, blue: 255/255)// #F3E8FF Lavender Soft
        case .health: return Color(red: 255/255, green: 228/255, blue: 230/255)        // #FFE4E6 Rose Soft
        case .subscriptions: return Color(red: 219/255, green: 234/255, blue: 254/255)// #DBEAFE Periwinkle Soft
        case .finance: return Color(red: 237/255, green: 233/255, blue: 254/255)       // #EDE9FE Violet Soft
        case .savings: return Color(red: 209/255, green: 250/255, blue: 229/255)       // #D1FAE5 Sage Soft
        case .miscellaneous, .misc: return Color(red: 238/255, green: 242/255, blue: 255/255) // #EEF2FF
        case .other: return Color(red: 241/255, green: 245/255, blue: 249/255)         // #F1F5F9 Neutral Soft
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
