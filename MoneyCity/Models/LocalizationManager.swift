import SwiftUI

// MARK: - App Language

public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case hebrew = "he"
    case english = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hebrew: return "עברית"
        case .english: return "English"
        }
    }

    public var flagEmoji: String {
        return ""
    }

    public var isRTL: Bool {
        self == .hebrew
    }

    public var layoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }
}

// MARK: - Currency Types & Rates

public enum CurrencyType: String, CaseIterable, Identifiable, Codable, Sendable {
    case ils = "ILS"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .ils: return "₪"
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        }
    }

    public var displayNameHebrew: String {
        switch self {
        case .ils: return "שקל ישראלי (₪)"
        case .usd: return "דולר ארה״ב ($)"
        case .eur: return "אירו אירופי (€)"
        case .gbp: return "לירה שטרלינג (£)"
        }
    }

    public var displayNameEnglish: String {
        switch self {
        case .ils: return "Israeli Shekel (₪)"
        case .usd: return "US Dollar ($)"
        case .eur: return "Euro (€)"
        case .gbp: return "British Pound (£)"
        }
    }

    public init?(symbolOrCode: String) {
        let clean = symbolOrCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch clean {
        case "₪", "ILS", "NIS", "ש״ח", "שח": self = .ils
        case "$", "USD", "DOLLAR", "דולר": self = .usd
        case "€", "EUR", "EURO", "אירו": self = .eur
        case "£", "GBP", "POUND", "פאונד", "ליש״ט": self = .gbp
        default: return nil
        }
    }

    /// Rate relative to base ILS (1 unit of currency = X Shekels)
    public var rateToILS: Double {
        FXService.rateToILS(for: self)
    }

    public static func convert(amount: Double, from: CurrencyType, to: CurrencyType) -> Double {
        FXService.convert(amount: amount, from: from, to: to)
    }
}

// MARK: - Global Localization & Currency Manager

@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @AppStorage("app_language_pref") public var currentLanguageRaw: String = AppLanguage.hebrew.rawValue {
        didSet { objectWillChange.send() }
    }

    @AppStorage("app_currency_pref") public var baseCurrencyRaw: String = CurrencyType.ils.rawValue {
        didSet { objectWillChange.send() }
    }

    @AppStorage("auto_convert_fx") public var autoConvertForeign: Bool = true {
        didSet { objectWillChange.send() }
    }

    nonisolated public var language: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: "app_language_pref") ?? AppLanguage.hebrew.rawValue
            return AppLanguage(rawValue: raw) ?? .hebrew
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "app_language_pref")
        }
    }

    public var baseCurrency: CurrencyType {
        get { CurrencyType(rawValue: baseCurrencyRaw) ?? .ils }
        set { baseCurrencyRaw = newValue.rawValue }
    }

    public var layoutDirection: LayoutDirection {
        language.layoutDirection
    }

    public init() {}

    // MARK: - Currency Formatting

    /// The single place money becomes text.
    ///
    /// Amounts used to be assembled by string concatenation — the symbol glued to `Int(value)` —
    /// which had three consequences. Wherever a ₪ was written literally the user's chosen
    /// currency was ignored. There were never thousands separators, so five figures ran together.
    /// And a negative amount produced a mixed-direction run inside right-to-left text, where the
    /// minus is a neutral character that bidi resolution can move to the other side of the
    /// number; a sign that wanders is not a cosmetic bug in a finance app.
    ///
    /// The symbol still leads, as the app's layouts expect. What changed is that the digits are
    /// grouped by a real formatter and the whole amount is wrapped in a first-strong isolate so
    /// it stays one unit whichever direction the text around it runs.
    public func format(amount: Double, currency: CurrencyType? = nil, showDecimals: Bool = false) -> String {
        let cur = currency ?? baseCurrency
        let converted = currency == nil ? amount : CurrencyType.convert(amount: amount, from: currency!, to: baseCurrency)
        let safe = converted.isFinite ? converted : 0
        let digits = Self.groupingFormatter(decimals: showDecimals)
            .string(from: NSNumber(value: abs(safe))) ?? "0"
        let sign = safe < 0 ? "-" : ""
        return "\u{2068}" + sign + cur.symbol + digits + "\u{2069}"
    }

    private static let formatterCache = NSCache<NSString, NumberFormatter>()

    private static func groupingFormatter(decimals: Bool) -> NumberFormatter {
        let key = (decimals ? "d2" : "d0") as NSString
        if let cached = formatterCache.object(forKey: key) { return cached }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        f.minimumFractionDigits = decimals ? 2 : 0
        f.maximumFractionDigits = decimals ? 2 : 0
        f.roundingMode = .halfUp
        formatterCache.setObject(f, forKey: key)
        return f
    }

    // MARK: - Localized String Translation Engine

    public func text(for key: String) -> String {
        let isHebrew = language == .hebrew
        switch key {
        // Main Navigation Tabs
        case "tab_city": return isHebrew ? "עיר" : "City"
        case "tab_analytics": return isHebrew ? "ניתוח" : "Analytics"
        case "tab_history": return isHebrew ? "היסטוריה" : "History"
        case "tab_profile": return isHebrew ? "פרופיל" : "Profile"

        // Headers
        case "city_title": return isHebrew ? "עיר ההוצאות שלי" : "My SPENT City"
        case "analytics_title": return isHebrew ? "ניתוח הוצאות" : "Spending Analytics"
        case "analytics_subtitle": return isHebrew ? "פירוט החודש הנוכחי" : "Current Month Breakdown"
        case "history_title": return isHebrew ? "היסטוריה" : "History"
        case "profile_title": return isHebrew ? "פרופיל והגדרות" : "Profile & Settings"

        // Stats & Cards
        case "total_this_month": return isHebrew ? "סה״כ החודש" : "Total This Month"
        case "total_this_year": return isHebrew ? "הוצאות השנה" : "Spent This Year"
        case "transactions_count": return isHebrew ? "עסקאות" : "Transactions"
        case "enrichments_count": return isHebrew ? "שדרוגים" : "Upgrades"
        case "weekly_expenses": return isHebrew ? "הוצאות שבועיות" : "Weekly Expenses"
        case "by_category": return isHebrew ? "לפי קטגוריה" : "By Category"
        case "quick_settings": return isHebrew ? "הגדרות מהירות" : "Quick Settings"
        case "all_settings": return isHebrew ? "כל ההגדרות" : "All Settings"
        case "city_upgrades": return isHebrew ? "שדרוגי העיר שלך" : "Your City Upgrades"
        case "yearly_breakdown": return isHebrew ? "שבירת הוצאות השנה" : "Yearly Spending Breakdown"

        // Quick Add
        case "quick_add_title": return isHebrew ? "הוספה מהירה (מזומן / ביט)" : "Quick Add (Cash / Transfer)"
        case "choose_category_tap": return isHebrew ? "בחר קטגוריה לשמירה בטאפ אחד:" : "Choose category to save in 1-tap:"
        case "cancel": return isHebrew ? "ביטול" : "Cancel"
        case "close": return isHebrew ? "סגור" : "Close"
        case "note_placeholder": return isHebrew ? "הערה / שם בית עסק (אופציונלי)" : "Note / Merchant name (optional)"

        // Settings Modal
        case "settings_header": return isHebrew ? "הגדרות" : "Settings"
        case "user_and_city": return isHebrew ? "פרטי העיר והמשתמש" : "User & City Info"
        case "city_name": return isHebrew ? "שם העיר:" : "City Name:"
        case "base_currency": return isHebrew ? "מטבע ראשי:" : "Base Currency:"
        case "language_pref": return isHebrew ? "שפת הממשק:" : "App Language:"
        case "fx_auto_convert": return isHebrew ? "חישוב והמרת מט״ח אוטומטית" : "Auto Foreign Currency (FX) Conversion"
        case "fx_explanation": return isHebrew ? "עסקאות במטבע זר ($, €, £) יומרו אוטומטית לפי שער יציג." : "Foreign purchases ($, €, £) are automatically converted using current exchange rates."
        case "sync_and_automation": return isHebrew ? "סנכרון ואוטומציות" : "Sync & Automations"
        case "apple_pay_sync": return isHebrew ? "קיצור דרך Apple Pay" : "Apple Pay Shortcut"
        case "active": return isHebrew ? "פעיל" : "Active"
        case "not_configured": return isHebrew ? "לא הוגדר" : "Not set up"
        case "apple_pay_setup_hint": return isHebrew ? "עדיין לא נקלטה עסקה אוטומטית. הגדר את האוטומציה ב-Shortcuts." : "No automatic transaction captured yet. Set up the Shortcuts automation."
        case "apple_pay_info": return isHebrew ? "תשלום בחנות (הצמדת הטלפון) נקלט אוטומטית, משויך לקטגוריה ובונה את השכונה המתאימה. רכישות אונליין יש להזין ידנית — iOS לא מאפשר לקלוט אותן." : "In-store tap payments are logged automatically, categorized, and shape their district. Online purchases must be added manually — iOS does not expose them."
        case "notifications": return isHebrew ? "התראות ותזכורות שבועיות" : "Weekly Notifications & Status"
        case "haptics": return isHebrew ? "משוב רטט ומגע (Haptics)" : "Haptic & Tactile Feedback"
        case "data_management": return isHebrew ? "ניהול נתונים וייצוא" : "Data Management & Export"
        case "ingest_log": return isHebrew ? "יומן קליטה (אבחון)" : "Ingest Log (diagnostics)"
        case "ingest_log_hint": return isHebrew ? "מה בדיוק Wallet העביר בכל הפעלה של האוטומציה." : "Exactly what Wallet passed on each automation run."
        case "savings_goals": return isHebrew ? "יעדי חיסכון" : "Savings Goals"
        case "savings_goals_hint": return isHebrew ? "יעד עם התקדמות — וכשהוא מושלם, מונומנט חדש בעיר." : "A goal with progress — and a new landmark in the city when you reach it."
        case "budget_and_income": return isHebrew ? "תקציב והכנסות" : "Budget & Income"
        case "budget_and_income_hint": return isHebrew ? "הכנסה חודשית ותקרה לכל קטגוריה — הבסיס לכל מה שהאפליקציה מחשבת." : "Monthly income and a ceiling per category — the basis for everything the app calculates."
        case "recurring_expenses": return isHebrew ? "הוצאות קבועות" : "Fixed Expenses"
        case "recurring_expenses_hint": return isHebrew ? "שכר דירה, ארנונה, מנויים — הגדרה אחת, נרשמות לבד כל חודש." : "Rent, bills, subscriptions — set once, posted automatically every month."
        case "export_csv": return isHebrew ? "ייצוא עסקאות לקובץ CSV / Excel" : "Export Transactions to CSV / Excel"
        case "reset_city": return isHebrew ? "איפוס כל נתוני העיר וההוצאות" : "Reset All City & Expense Data"
        case "privacy_note": return isHebrew ? "כל הנתונים הכספיים נשמרים מקומית על המכשיר שלך בלבד ומאובטחים לחלוטין." : "All financial data is strictly stored locally on your device with SwiftData and is 100% private."

        default:
            return key
        }
    }
}

// MARK: - Category Name Localizer Extension

public extension SpendingCategory {
    func localizedName(for language: AppLanguage = .hebrew) -> String {
        if language == .english {
            switch self {
            case .housing: return "Housing"
            case .food, .groceries, .coffee: return "Food & Dining"
            case .transport: return "Transport"
            case .shopping: return "Shopping"
            case .entertainment: return "Entertainment"
            case .health: return "Health & Wellness"
            case .subscriptions: return "Subscriptions"
            case .other: return "Other"
            case .finance: return "Finance & Fees"
            case .savings: return "Savings & Reserve"
            }
        } else {
            return self.displayName
        }
    }

    func localizedShortName(for language: AppLanguage = .hebrew) -> String {
        if language == .english {
            switch self {
            case .housing: return "Housing"
            case .food, .groceries, .coffee: return "Food"
            case .transport: return "Transport"
            case .shopping: return "Shopping"
            case .entertainment: return "Fun"
            case .health: return "Health"
            case .subscriptions: return "Subs"
            case .other: return "Other"
            case .finance: return "Finance"
            case .savings: return "Savings"
            }
        } else {
            return self.shortName
        }
    }
}

