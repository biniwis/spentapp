import SwiftUI

// MARK: - App Language

public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case hebrew = "he"
    case english = "en"

    /// Resolves the device's preferred language when no explicit user preference is saved.
    /// Hebrew if device preferred language starts with "he", otherwise English (for English and all other languages).
    public static var deviceDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased()
            ?? Locale.current.language.languageCode?.identifier.lowercased()
            ?? ""
        return preferred.hasPrefix("he") ? .hebrew : .english
    }

    /// Readable from background ingestion and notification callbacks as well as the UI.
    public static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "app_language_pref"),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        return .deviceDefault
    }

    public static func localized(_ hebrew: String, _ english: String) -> String {
        current == .hebrew ? hebrew : english
    }

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

public struct CurrencyType: Hashable, Identifiable, Codable, Sendable, RawRepresentable {
    public let rawValue: String

    public var id: String { rawValue }
    public var code: String { rawValue }

    public init(rawValue: String) {
        let clean = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.rawValue = clean.isEmpty ? "ILS" : clean
    }

    public init(_ code: String) {
        self.init(rawValue: code)
    }

    // Standard static constants for backward-compatibility
    public static let ils = CurrencyType(rawValue: "ILS")
    public static let usd = CurrencyType(rawValue: "USD")
    public static let eur = CurrencyType(rawValue: "EUR")
    public static let gbp = CurrencyType(rawValue: "GBP")
    public static let `try` = CurrencyType(rawValue: "TRY")
    public static let jpy = CurrencyType(rawValue: "JPY")
    public static let chf = CurrencyType(rawValue: "CHF")
    public static let cad = CurrencyType(rawValue: "CAD")
    public static let aud = CurrencyType(rawValue: "AUD")
    public static let aed = CurrencyType(rawValue: "AED")
    public static let thb = CurrencyType(rawValue: "THB")
    public static let pln = CurrencyType(rawValue: "PLN")
    public static let czk = CurrencyType(rawValue: "CZK")
    public static let huf = CurrencyType(rawValue: "HUF")
    public static let sek = CurrencyType(rawValue: "SEK")
    public static let nok = CurrencyType(rawValue: "NOK")
    public static let dkk = CurrencyType(rawValue: "DKK")
    public static let cny = CurrencyType(rawValue: "CNY")
    public static let hkd = CurrencyType(rawValue: "HKD")
    public static let sgd = CurrencyType(rawValue: "SGD")
    public static let krw = CurrencyType(rawValue: "KRW")

    public static var allCases: [CurrencyType] {
        [
            .ils, .usd, .eur, .gbp, .try, .jpy, .chf, .cad, .aud, .aed,
            .thb, .pln, .czk, .huf, .sek, .nok, .dkk, .cny, .hkd, .sgd, .krw
        ]
    }

    public var symbol: String {
        switch rawValue {
        case "ILS": return "₪"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "TRY": return "₺"
        case "JPY": return "¥"
        case "CNY": return "¥"
        case "CHF": return "CHF"
        case "CAD": return "CA$"
        case "AUD": return "AU$"
        case "AED": return "AED"
        case "THB": return "฿"
        case "PLN": return "zł"
        case "CZK": return "Kč"
        case "HUF": return "Ft"
        case "SEK": return "kr"
        case "NOK": return "kr"
        case "DKK": return "kr"
        case "HKD": return "HK$"
        case "SGD": return "SG$"
        case "KRW": return "₩"
        default:
            let loc = Locale(identifier: "en_US@currency=\(rawValue)")
            return loc.currencySymbol ?? rawValue
        }
    }

    public var displayNameHebrew: String {
        switch rawValue {
        case "ILS": return "שקל ישראלי (₪)"
        case "USD": return "דולר ארה״ב ($)"
        case "EUR": return "אירו אירופי (€)"
        case "GBP": return "לירה שטרלינג (£)"
        case "TRY": return "לירה טורקית (₺)"
        case "JPY": return "ין יפני (¥)"
        case "CHF": return "פרנק שוויצרי (CHF)"
        case "CAD": return "דולר קנדי (CA$)"
        case "AUD": return "דולר אוסטרלי (AU$)"
        case "AED": return "דירהם איחוד האמירויות (AED)"
        case "THB": return "באט תאילנדי (฿)"
        case "PLN": return "זלוטי פולני (zł)"
        case "CZK": return "קורונה צ'כית (Kč)"
        case "HUF": return "פורינט הונגרי (Ft)"
        case "SEK": return "קרונה שוודית (kr)"
        case "NOK": return "קרונה נורווגית (kr)"
        case "DKK": return "קרונה דנית (kr)"
        case "CNY": return "יואן סיני (¥)"
        case "HKD": return "דולר הונג קונג (HK$)"
        case "SGD": return "דולר סינגפורי (SG$)"
        case "KRW": return "וון דרום קוריאני (₩)"
        default:
            let locName = Locale(identifier: "he_IL").localizedString(forCurrencyCode: rawValue) ?? rawValue
            return "\(locName) (\(symbol))"
        }
    }

    public var displayNameEnglish: String {
        switch rawValue {
        case "ILS": return "Israeli Shekel (₪)"
        case "USD": return "US Dollar ($)"
        case "EUR": return "Euro (€)"
        case "GBP": return "British Pound (£)"
        case "TRY": return "Turkish Lira (₺)"
        case "JPY": return "Japanese Yen (¥)"
        case "CHF": return "Swiss Franc (CHF)"
        case "CAD": return "Canadian Dollar (CA$)"
        case "AUD": return "Australian Dollar (AU$)"
        case "AED": return "UAE Dirham (AED)"
        case "THB": return "Thai Baht (฿)"
        case "PLN": return "Polish Zloty (zł)"
        case "CZK": return "Czech Koruna (Kč)"
        case "HUF": return "Hungarian Forint (Ft)"
        case "SEK": return "Swedish Krona (kr)"
        case "NOK": return "Norwegian Krone (kr)"
        case "DKK": return "Danish Krone (kr)"
        case "CNY": return "Chinese Yuan (¥)"
        case "HKD": return "Hong Kong Dollar (HK$)"
        case "SGD": return "Singapore Dollar (SG$)"
        case "KRW": return "South Korean Won (₩)"
        default:
            let locName = Locale(identifier: "en_US").localizedString(forCurrencyCode: rawValue) ?? rawValue
            return "\(locName) (\(symbol))"
        }
    }

    public init?(symbolOrCode: String) {
        guard let code = CurrencyResolutionService.normalizeToISOCode(symbolOrCode) else {
            return nil
        }
        self.init(rawValue: code)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func ~= (pattern: CurrencyType, value: CurrencyType) -> Bool {
        pattern.rawValue == value.rawValue
    }

    /// Rate relative to base ILS (1 unit of currency = X Shekels). Returns nil when no rate exists.
    public var rateToILS: Double? {
        FXService.rateToILS(for: self)
    }

    /// Converts `amount` from `from` to `to`. Returns `nil` when no verified/cached/default
    /// rate exists. A missing rate is an explicit failure — never a silent 1:1 pass-through.
    public static func convert(amount: Double, from: CurrencyType, to: CurrencyType) -> Double? {
        FXService.convert(amount: amount, from: from, to: to)
    }

    /// Canonical safe conversion path that exposes failure.
    ///
    /// Delegates to `FXService.convert(amount:from:to:)` and returns `nil` when the rate is
    /// unavailable. Financial persistence code must never fall back to the original amount
    /// when this returns `nil`.
    public static func convertIfAvailable(amount: Double, from: CurrencyType, to: CurrencyType) -> Double? {
        convert(amount: amount, from: from, to: to)
    }
}

// MARK: - Global Localization & Currency Manager

@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @AppStorage("app_language_pref") public var currentLanguageRaw: String = AppLanguage.deviceDefault.rawValue {
        didSet { objectWillChange.send() }
    }

    @AppStorage("app_currency_pref") public var baseCurrencyRaw: String = CurrencyType.ils.rawValue {
        didSet {
            UserDefaults(suiteName: "group.com.moneycity.app")?.set(baseCurrency.symbol, forKey: "widget_currency_symbol")
            objectWillChange.send()
        }
    }

    @AppStorage("auto_convert_fx") public var autoConvertForeign: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Reloads language and currency properties from UserDefaults after a data restore.
    public func refresh() {
        let lang = UserDefaults.standard.string(forKey: "app_language_pref") ?? AppLanguage.deviceDefault.rawValue
        let curr = UserDefaults.standard.string(forKey: "app_currency_pref") ?? CurrencyType.ils.rawValue
        let fx = UserDefaults.standard.object(forKey: "auto_convert_fx") as? Bool ?? true
        self.currentLanguageRaw = lang
        self.baseCurrencyRaw = curr
        self.autoConvertForeign = fx
        UserDefaults(suiteName: "group.com.moneycity.app")?.set(baseCurrency.symbol, forKey: "widget_currency_symbol")
        objectWillChange.send()
    }

    nonisolated public var language: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: "app_language_pref") ?? AppLanguage.deviceDefault.rawValue
            return AppLanguage(rawValue: raw) ?? .deviceDefault
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "app_language_pref")
            Task { @MainActor in
                LocalizationManager.shared.currentLanguageRaw = newValue.rawValue
            }
        }
    }

    nonisolated public static var currentBaseCurrency: CurrencyType {
        let raw = UserDefaults.standard.string(forKey: "app_currency_pref") ?? CurrencyType.ils.rawValue
        return CurrencyType(rawValue: raw)
    }

    public var baseCurrency: CurrencyType {
        get { CurrencyType(rawValue: baseCurrencyRaw) }
        set { baseCurrencyRaw = newValue.rawValue }
    }

    public var layoutDirection: LayoutDirection {
        language.layoutDirection
    }

    public var isHebrew: Bool {
        language == .hebrew
    }

    /// Canonical user-facing name for the Nature Reserve / שמורת הטבע product concept.
    public static var natureReserveName: String {
        AppLanguage.localized("שמורת הטבע", "Nature Reserve")
    }

    public var natureReserveName: String {
        isHebrew ? "שמורת הטבע" : "Nature Reserve"
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
        let targetCurrency = baseCurrency
        let converted: Double
        let displayedSymbol: String
        if let sourceCurrency = currency, sourceCurrency != targetCurrency {
            guard let available = CurrencyType.convertIfAvailable(amount: amount, from: sourceCurrency, to: targetCurrency) else {
                // No usable rate. Never relabel the number under the base currency; show the
                // amount in the currency it was actually entered in instead of guessing a value.
                let safe = amount.isFinite ? amount : 0
                let digits = Self.groupingFormatter(decimals: showDecimals)
                    .string(from: NSNumber(value: abs(safe))) ?? "0"
                let sign = safe < 0 ? "-" : ""
                return "\u{2068}" + sign + sourceCurrency.symbol + digits + "\u{2069}"
            }
            converted = available
            displayedSymbol = targetCurrency.symbol
        } else {
            converted = amount
            displayedSymbol = targetCurrency.symbol
        }
        let safe = converted.isFinite ? converted : 0
        let digits = Self.groupingFormatter(decimals: showDecimals)
            .string(from: NSNumber(value: abs(safe))) ?? "0"
        let sign = safe < 0 ? "-" : ""
        return "\u{2068}" + sign + displayedSymbol + digits + "\u{2069}"
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
        case "enrichments_count": return isHebrew ? "תוספות" : "Additions"
        case "weekly_expenses": return isHebrew ? "הוצאות שבועיות" : "Weekly Expenses"
        case "by_category": return isHebrew ? "לפי קטגוריה" : "By Category"
        case "quick_settings": return isHebrew ? "הגדרות מהירות" : "Quick Settings"
        case "all_settings": return isHebrew ? "כל ההגדרות" : "All Settings"
        case "city_upgrades": return isHebrew ? "תוספות לעיר" : "City Additions"
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
        case "mayor_name": return isHebrew ? "שם ראש העיר:" : "Mayor Name:"
        case "base_currency": return isHebrew ? "מטבע ראשי:" : "Base Currency:"
        case "language_pref": return isHebrew ? "שפת הממשק:" : "App Language:"
        case "fx_auto_convert": return isHebrew ? "המרת מטבע אוטומטית" : "Automatic Currency Conversion"
        case "fx_explanation": return isHebrew ? "עסקאות במטבע זר ($, €, £) יומרו אוטומטית לפי שער יציג." : "Foreign purchases ($, €, £) are automatically converted using current exchange rates."
        case "sync_and_automation": return isHebrew ? "סנכרון וקליטה אוטומטית" : "Sync & Automatic Capture"
        case "apple_pay_sync": return isHebrew ? "קליטה אוטומטית" : "Automatic Capture"
        case "active": return isHebrew ? "פעיל" : "Active"
        case "not_configured": return isHebrew ? "לא הוגדר" : "Not set up"
        case "apple_pay_setup_hint": return isHebrew ? "עדיין לא נקלטה הוצאה אוטומטית. הגדר את הקליטה באפליקציית ״קיצורים״ של Apple." : "No automatic expense captured yet. Set it up in Apple's Shortcuts app."
        case "apple_pay_info": return isHebrew ? "אחרי תשלום, האייפון יכול להעביר ל-SPENT את הסכום ושם בית העסק. SPENT לא מקבלת גישה לכרטיס או לחשבון הבנק שלך." : "After a payment, your iPhone can pass SPENT the amount and merchant. SPENT doesn’t get access to your card or bank account."
        case "notifications": return isHebrew ? "התראות ותזכורות שבועיות" : "Weekly Notifications & Status"
        case "haptics": return isHebrew ? "משוב במגע" : "Haptic Feedback"
        case "data_management": return isHebrew ? "ניהול נתונים וייצוא" : "Data Management & Export"
        case "ingest_log": return isHebrew ? "יומן קליטה (אבחון)" : "Ingest Log (diagnostics)"
        case "ingest_log_hint": return isHebrew ? "מה בדיוק האייפון העביר בכל תשלום." : "Exactly what your iPhone passed on each payment."
        case "savings_goals": return isHebrew ? "יעדי חיסכון" : "Savings Goals"
        case "savings_goals_hint": return isHebrew ? "יעד עם התקדמות — וכשהוא מושלם, מונומנט חדש בעיר." : "A goal with progress — and a new landmark in the city when you reach it."
        case "budget_and_income": return isHebrew ? "תקציב והכנסות" : "Budget & Income"
        case "budget_and_income_hint": return isHebrew ? "הכנסה חודשית ותקרה לכל קטגוריה — הבסיס לכל מה שהאפליקציה מחשבת." : "Monthly income and a ceiling per category — the basis for everything the app calculates."
        case "recurring_expenses": return isHebrew ? "הוצאות קבועות" : "Fixed Expenses"
        case "recurring_expenses_hint": return isHebrew ? "שכר דירה, ארנונה, מנויים — הגדרה אחת, נרשמות לבד כל חודש." : "Rent, bills, subscriptions — set once, posted automatically every month."
        case "export_csv": return isHebrew ? "ייצוא עסקאות לקובץ CSV / Excel" : "Export Transactions to CSV / Excel"
        case "reset_city": return isHebrew ? "איפוס כל נתוני העיר וההוצאות" : "Reset All City & Expense Data"
        case "privacy_note": return isHebrew ? "כל הנתונים נשמרים מקומית על המכשיר שלך עם גיבוי פרטי ב־iCloud האישי שלך. אין שרתים או חשבונות של SPENT." : "All data is stored locally on your device with private backup to your personal iCloud. No SPENT servers or accounts."
        case "nature_reserve": return natureReserveName

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
            case .finance: return "Finance & Fees"
            case .savings: return "Savings & Investments"
            case .miscellaneous, .misc: return "Miscellaneous"
            case .other: return "Uncategorized"
            }
        } else {
            // `self.displayName` is the no-argument property, which decides the language for
            // itself by reading UserDefaults — so this function was quietly ignoring the
            // language it was handed. It happens to agree today only because both read the
            // same key; asking for a language and being given whichever one is currently
            // stored is a trap waiting for the first caller who needs the other one.
            return displayName(for: language)
        }
    }

    func localizedShortName(for language: AppLanguage = .hebrew) -> String {
        if language == .english {
            switch self {
            case .housing: return "Housing"
            case .food, .groceries, .coffee: return "Food"
            case .transport: return "Transport"
            case .shopping: return "Shopping"
            case .entertainment: return "Entertainment"
            case .health: return "Health"
            case .subscriptions: return "Subscriptions"
            case .finance: return "Finance"
            case .savings: return "Savings"
            case .miscellaneous, .misc: return "Misc"
            case .other: return "Uncategorized"
            }
        } else {
            // Same as above: honour the argument rather than re-reading global state.
            return shortName(for: language)
        }
    }
}

