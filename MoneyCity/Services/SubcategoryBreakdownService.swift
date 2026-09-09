import SwiftUI

// MARK: - Subcategory Breakdown Item

public struct SubcategoryBreakdownItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let icon: MoneyIconType
    public let color: Color
    public let amount: Double
    public let fraction: Double
    public let count: Int

    public init(
        id: String,
        name: String,
        icon: MoneyIconType,
        color: Color,
        amount: Double,
        fraction: Double,
        count: Int
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.amount = amount
        self.fraction = fraction
        self.count = count
    }
}

// MARK: - Subcategory Breakdown Service

public final class SubcategoryBreakdownService: Sendable {
    public static let shared = SubcategoryBreakdownService()
    private init() {}

    /// Breaks down transactions of a specific category into sub-types or merchants
    public func breakdown(
        for category: SpendingCategory,
        transactions: [Transaction],
        isHebrew: Bool
    ) -> [SubcategoryBreakdownItem] {
        let catTxs = transactions.filter { $0.category.canonical == category.canonical }
        guard !catTxs.isEmpty else { return [] }

        let totalAmt = max(catTxs.reduce(0) { $0 + $1.amount }, 1.0)

        // 1. First, attempt subcategory breakdown by taxonomy
        var subTotals: [String: (name: String, icon: MoneyIconType, color: Color, amount: Double, count: Int)] = [:]

        for tx in catTxs {
            let info = subcategoryInfo(for: tx, category: category.canonical, isHebrew: isHebrew)
            if var existing = subTotals[info.id] {
                existing.amount += tx.amount
                existing.count += 1
                subTotals[info.id] = existing
            } else {
                subTotals[info.id] = (name: info.name, icon: info.icon, color: info.color, amount: tx.amount, count: 1)
            }
        }

        // 2. If there are at least 2 distinct subcategories, return them
        if subTotals.count >= 2 {
            return subTotals.values
                .sorted { $0.amount > $1.amount }
                .map { item in
                    SubcategoryBreakdownItem(
                        id: item.name,
                        name: item.name,
                        icon: item.icon,
                        color: item.color,
                        amount: item.amount,
                        fraction: item.amount / totalAmt,
                        count: item.count
                    )
                }
        }

        // 3. Fallback: If all transactions belong to only 1 subcategory, break down by Merchant!
        var merchantTotals: [String: (amount: Double, count: Int)] = [:]
        for tx in catTxs {
            let mName = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = mName.isEmpty ? (isHebrew ? "ללא שם" : "Unnamed") : mName
            let existing = merchantTotals[key, default: (amount: 0, count: 0)]
            merchantTotals[key] = (amount: existing.amount + tx.amount, count: existing.count + 1)
        }

        // Harmonic colors derived from category themeColor
        let palette = harmonicShades(for: category.canonical)

        let sortedMerchants = merchantTotals.sorted { $0.value.amount > $1.value.amount }
        return sortedMerchants.enumerated().map { idx, element in
            let color = palette[idx % palette.count]
            return SubcategoryBreakdownItem(
                id: element.key,
                name: element.key,
                icon: defaultIcon(for: category.canonical),
                color: color,
                amount: element.value.amount,
                fraction: element.value.amount / totalAmt,
                count: element.value.count
            )
        }
    }

    /// Returns the subcategory display name for a given transaction.
    public func subcategoryName(for tx: Transaction, isHebrew: Bool) -> String {
        subcategory(for: tx, isHebrew: isHebrew).name
    }

    /// Returns the MoneyCity signature icon type for a given transaction.
    public func subcategoryIcon(for tx: Transaction) -> MoneyIconType {
        subcategory(for: tx, isHebrew: true).icon
    }

    /// Returns the complete subcategory metadata (name, icon, thematic color) for a transaction.
    public func subcategory(for tx: Transaction, isHebrew: Bool) -> (name: String, icon: MoneyIconType, color: Color) {
        // 1. If explicit buildingIdRaw is set and matches CityBuilding, use its display name & icon
        if let raw = tx.buildingIdRaw, !raw.isEmpty, let b = CityBuilding.find(id: raw) {
            let info = subcategoryInfo(for: tx, category: tx.category.canonical, isHebrew: isHebrew)
            return (name: b.displayName(for: isHebrew ? .hebrew : .english), icon: b.iconType, color: info.color)
        }

        // 2. Otherwise determine subcategory via taxonomy and merchant/notes
        let info = subcategoryInfo(for: tx, category: tx.category.canonical, isHebrew: isHebrew)
        return (name: info.name, icon: info.icon, color: info.color)
    }

    // MARK: - Subcategory Classification Rules

    private func subcategoryInfo(
        for tx: Transaction,
        category: SpendingCategory,
        isHebrew: Bool
    ) -> (id: String, name: String, icon: MoneyIconType, color: Color) {
        let bId = (tx.buildingIdRaw ?? tx.buildingId).lowercased()
        let m = "\(tx.merchant) \(tx.note ?? "")".lowercased()

        switch category {
        case .food, .groceries, .coffee:
            if bId == "food_wolt" || m.contains("wolt") || m.contains("וולט") || m.contains("10bis") || m.contains("תן ביס") || m.contains("tabit") || m.contains("משלוח") {
                return (
                    "food_wolt",
                    isHebrew ? "משלוחי אוכל" : "Food Delivery",
                    .paperPlane,
                    Color(red: 249/255, green: 115/255, blue: 22/255) // Warm Orange
                )
            }
            if bId == "food_coffee" || category == .coffee || m.contains("קפה") || m.contains("cafe") || m.contains("coffee") || m.contains("aroma") || m.contains("ארומה") || m.contains("גולדה") || m.contains("golda") || m.contains("arcaffe") || m.contains("ארקפה") || m.contains("landwer") || m.contains("לנדוור") || m.contains("מאפיה") || m.contains("מאפיית") || m.contains("bakery") {
                return (
                    "food_coffee",
                    isHebrew ? "בתי קפה" : "Cafes",
                    .coffee,
                    Color(red: 245/255, green: 158/255, blue: 11/255) // Warm Amber
                )
            }
            if bId == "food_super" || category == .groceries || m.contains("סופר") || m.contains("super") || m.contains("שופרסל") || m.contains("shufersal") || m.contains("רמי לוי") || m.contains("rami levy") || m.contains("ויקטורי") || m.contains("victory") || m.contains("יוחננוף") || m.contains("טיב טעם") || m.contains("am:pm") || m.contains("מכולת") || m.contains("אושר עד") || m.contains("קרפור") || m.contains("carrefour") {
                return (
                    "food_super",
                    isHebrew ? "סופר ומכולת" : "Supermarket",
                    .cart,
                    Color(red: 234/255, green: 88/255, blue: 12/255) // Deep Tangerine
                )
            }
            return (
                "food_bistro",
                isHebrew ? "מסעדות" : "Restaurants",
                .cutlery,
                Color(red: 251/255, green: 146/255, blue: 60/255) // Coral Peach
            )

        case .shopping:
            if bId == "shop_tech" || m.contains("ksp") || m.contains("ivory") || m.contains("אייבורי") || m.contains("חשמל") || m.contains("באג") || m.contains("bug") || m.contains("amazon") || m.contains("אמזון") || m.contains("aliexpress") || m.contains("עליאקספרס") || m.contains("idigital") || m.contains("istore") || m.contains("מחשב") {
                return (
                    "shop_tech",
                    isHebrew ? "טכנולוגיה וחשמל" : "Tech & Electronics",
                    .lightning,
                    Color(red: 219/255, green: 39/255, blue: 119/255) // Hot Pink
                )
            }
            if bId == "shop_travel" || m.contains("flight") || m.contains("טיסה") || m.contains("טיסות") || m.contains("el al") || m.contains("אל על") || m.contains("airbnb") || m.contains("booking") || m.contains("hotel") || m.contains("מלון") || m.contains("איסתא") || m.contains("wizz") || m.contains("ryanair") || m.contains("arkia") || m.contains("ארקיע") {
                return (
                    "shop_travel",
                    isHebrew ? "חופשות וטיסות" : "Travel & Vacations",
                    .airplane,
                    Color(red: 244/255, green: 114/255, blue: 182/255) // Soft Rose Pink
                )
            }
            return (
                "shop_boutique",
                isHebrew ? "ביגוד ואופנה" : "Clothing & Fashion",
                .tshirt,
                Color(red: 236/255, green: 72/255, blue: 153/255) // Category Pink
            )

        case .housing:
            if bId == "house_util" || m.contains("חשמל") || m.contains("ארנונה") || m.contains("עיריית") || m.contains("עירייה") || m.contains("מים") || m.contains("מי אביבים") || m.contains("מי כרמל") || m.contains("גז") || m.contains("פזגז") || m.contains("gas") || m.contains("ועד בית") {
                return (
                    "house_util",
                    isHebrew ? "חשבונות הבית" : "Utilities & Bills",
                    .lightning,
                    Color(red: 14/255, green: 165/255, blue: 233/255) // Cyan
                )
            }
            return (
                "house_tower",
                isHebrew ? "שכירות ודיור" : "Rent & Housing",
                .home,
                Color(red: 2/255, green: 132/255, blue: 199/255) // Sky Blue
            )

        case .transport:
            if m.contains("דלק") || m.contains("פז") || m.contains("paz") || m.contains("סונול") || m.contains("sonol") || m.contains("דור אלון") || m.contains("doralon") || m.contains("טן") || m.contains("ten") {
                return (
                    "trans_fuel",
                    isHebrew ? "דלק" : "Fuel",
                    .gasPump,
                    Color(red: 22/255, green: 163/255, blue: 74/255) // Forest Green
                )
            }
            if m.contains("רב קו") || m.contains("rav kav") || m.contains("רכבת") || m.contains("railway") || m.contains("אגד") || m.contains("דן") || m.contains("מטרופולין") || m.contains("מוביט") || m.contains("moovit") {
                return (
                    "trans_transit",
                    isHebrew ? "תחבורה ציבורית" : "Public Transit",
                    .bus,
                    Color(red: 34/255, green: 197/255, blue: 94/255) // Fresh Green
                )
            }
            if m.contains("gett") || m.contains("גט") || m.contains("uber") || m.contains("אובר") || m.contains("מונית") || m.contains("taxi") || m.contains("yango") {
                return (
                    "trans_taxi",
                    isHebrew ? "מוניות" : "Taxis",
                    .car,
                    Color(red: 74/255, green: 222/255, blue: 128/255) // Light Green
                )
            }
            if bId == "trans_parking" || m.contains("חניה") || m.contains("חניון") || m.contains("פנגו") || m.contains("pango") || m.contains("סלופארק") || m.contains("כביש 6") {
                return (
                    "trans_parking",
                    isHebrew ? "חניה ואגרות" : "Parking & Tolls",
                    .ticket,
                    Color(red: 16/255, green: 185/255, blue: 129/255) // Emerald
                )
            }
            return (
                "trans_station",
                isHebrew ? "תחבורה ורכב" : "Transport & Fuel",
                .car,
                Color(red: 22/255, green: 163/255, blue: 74/255)
            )

        case .subscriptions:
            if m.contains("netflix") || m.contains("נטפליקס") || m.contains("spotify") || m.contains("ספוטיפיי") || m.contains("disney") || m.contains("דיסני") || m.contains("hbo") || m.contains("apple.com/bill") || m.contains("itunes") || m.contains("youtube") {
                return (
                    "subs_stream",
                    isHebrew ? "סטרימינג וטלוויזיה" : "Streaming & TV",
                    .star,
                    Color(red: 37/255, green: 99/255, blue: 235/255) // Deep Royal
                )
            }
            if m.contains("סלקום") || m.contains("cellcom") || m.contains("פרטנר") || m.contains("partner") || m.contains("פלאפון") || m.contains("pelephone") || m.contains("012") || m.contains("we4g") || m.contains("גולן") || m.contains("בזק") || m.contains("הוט") {
                return (
                    "subs_telecom",
                    isHebrew ? "סלולר ואינטרנט" : "Mobile & Internet",
                    .phone,
                    Color(red: 59/255, green: 130/255, blue: 246/255) // Royal Blue
                )
            }
            return (
                "subs_cloud",
                isHebrew ? "ענן ותוכנות" : "Cloud & Software",
                .cloud,
                Color(red: 96/255, green: 165/255, blue: 250/255) // Sky Light
            )

        case .health:
            if m.contains("super-pharm") || m.contains("סופר פארם") || m.contains("be") || m.contains("pharmacy") || m.contains("בית מרקחת") || m.contains("תרופות") {
                return (
                    "health_pharmacy",
                    isHebrew ? "פארם ותרופות" : "Pharmacy & Care",
                    .medicalCross,
                    Color(red: 225/255, green: 29/255, blue: 72/255) // Deep Rose
                )
            }
            if m.contains("holmes place") || m.contains("הולמס פלייס") || m.contains("קאנטרי") || m.contains("גרייט שייפ") || m.contains("space") || m.contains("פרופיט") || m.contains("כושר") {
                return (
                    "health_fitness",
                    isHebrew ? "כושר וספורט" : "Fitness & Gym",
                    .dumbbell,
                    Color(red: 244/255, green: 63/255, blue: 94/255) // Rose
                )
            }
            return (
                "health_medical",
                isHebrew ? "רפואה וטיפולים" : "Medical & Doctors",
                .heart,
                Color(red: 251/255, green: 113/255, blue: 133/255) // Soft Rose
            )

        case .entertainment:
            if m.contains("cinema") || m.contains("קולנוע") || m.contains("סינמה סיטי") || m.contains("yes planet") || m.contains("הופעה") || m.contains("כרטיסים") || m.contains("זאפה") {
                return (
                    "ent_cinema",
                    isHebrew ? "קולנוע והופעות" : "Cinema & Shows",
                    .ticket,
                    Color(red: 147/255, green: 51/255, blue: 234/255) // Deep Purple
                )
            }
            if m.contains("playstation") || m.contains("sony") || m.contains("xbox") || m.contains("steam") || m.contains("nintendo") || m.contains("משחק") || m.contains("גיימינג") {
                return (
                    "ent_gaming",
                    isHebrew ? "גיימינג ומשחקים" : "Gaming",
                    .gamepad,
                    Color(red: 168/255, green: 85/255, blue: 247/255) // Purple
                )
            }
            return (
                "ent_nightlife",
                isHebrew ? "בילויים וחיי לילה" : "Nightlife & Leisure",
                .star,
                Color(red: 192/255, green: 132/255, blue: 252/255) // Light Purple
            )

        case .finance:
            if m.contains("עמלת") || m.contains("עמלה") || m.contains("דמי כרטיס") {
                return (
                    "fin_fees",
                    isHebrew ? "עמלות ודמי כרטיס" : "Card & Bank Fees",
                    .coins,
                    Color(red: 124/255, green: 58/255, blue: 237/255)
                )
            }
            return (
                "fin_banks",
                isHebrew ? "בנקים ואשראי" : "Banks & Credit",
                .creditCard,
                Color(red: 139/255, green: 92/255, blue: 246/255)
            )

        case .miscellaneous, .misc:
            if m.contains("קנס") || m.contains("דוח") || m.contains("fine") {
                return (
                    "misc_fines",
                    isHebrew ? "קנסות ודוחות" : "Fines & Reports",
                    .receipt,
                    Color(red: 79/255, green: 70/255, blue: 229/255)
                )
            }
            if m.contains("מתנה") || m.contains("gift") || m.contains("פרחים") || m.contains("תרומה") {
                return (
                    "misc_gifts",
                    isHebrew ? "מתנות ותרומות" : "Gifts & Donations",
                    .gift,
                    Color(red: 99/255, green: 102/255, blue: 241/255)
                )
            }
            return (
                "misc_general",
                isHebrew ? "שונות וכללי" : "Miscellaneous",
                .document,
                Color(red: 129/255, green: 140/255, blue: 248/255)
            )

        case .savings:
            return (
                "savings_general",
                isHebrew ? "חיסכון והשקעות" : "Savings & Funds",
                .leaf,
                Color(red: 16/255, green: 185/255, blue: 129/255)
            )

        case .other:
            return (
                "other_general",
                isHebrew ? "אחר (למיון)" : "Unsorted",
                .folder,
                Color(red: 100/255, green: 116/255, blue: 139/255)
            )
        }
    }

    private func defaultIcon(for category: SpendingCategory) -> MoneyIconType {
        switch category {
        case .food, .groceries, .coffee: return .cutlery
        case .shopping: return .shoppingBag
        case .housing: return .home
        case .transport: return .car
        case .subscriptions: return .star
        case .health: return .heart
        case .entertainment: return .ticket
        case .finance: return .creditCard
        case .savings: return .leaf
        case .miscellaneous, .misc: return .gift
        case .other: return .document
        }
    }

    private func harmonicShades(for category: SpendingCategory) -> [Color] {
        switch category {
        case .food, .groceries, .coffee:
            return [
                Color(red: 234/255, green: 88/255, blue: 12/255),
                Color(red: 249/255, green: 115/255, blue: 22/255),
                Color(red: 245/255, green: 158/255, blue: 11/255),
                Color(red: 251/255, green: 146/255, blue: 60/255),
                Color(red: 217/255, green: 119/255, blue: 6/255)
            ]
        case .shopping:
            return [
                Color(red: 219/255, green: 39/255, blue: 119/255),
                Color(red: 236/255, green: 72/255, blue: 153/255),
                Color(red: 244/255, green: 114/255, blue: 182/255),
                Color(red: 190/255, green: 24/255, blue: 93/255),
                Color(red: 249/255, green: 168/255, blue: 212/255)
            ]
        case .transport:
            return [
                Color(red: 22/255, green: 163/255, blue: 74/255),
                Color(red: 34/255, green: 197/255, blue: 94/255),
                Color(red: 74/255, green: 222/255, blue: 128/255),
                Color(red: 16/255, green: 185/255, blue: 129/255),
                Color(red: 5/255, green: 150/255, blue: 105/255)
            ]
        case .housing:
            return [
                Color(red: 2/255, green: 132/255, blue: 199/255),
                Color(red: 14/255, green: 165/255, blue: 233/255),
                Color(red: 56/255, green: 189/255, blue: 248/255),
                Color(red: 3/255, green: 105/255, blue: 161/255)
            ]
        case .entertainment:
            return [
                Color(red: 147/255, green: 51/255, blue: 234/255),
                Color(red: 168/255, green: 85/255, blue: 247/255),
                Color(red: 192/255, green: 132/255, blue: 252/255),
                Color(red: 126/255, green: 34/255, blue: 206/255)
            ]
        case .subscriptions:
            return [
                Color(red: 37/255, green: 99/255, blue: 235/255),
                Color(red: 59/255, green: 130/255, blue: 246/255),
                Color(red: 96/255, green: 165/255, blue: 250/255),
                Color(red: 29/255, green: 78/255, blue: 216/255)
            ]
        case .health:
            return [
                Color(red: 225/255, green: 29/255, blue: 72/255),
                Color(red: 244/255, green: 63/255, blue: 94/255),
                Color(red: 251/255, green: 113/255, blue: 133/255),
                Color(red: 190/255, green: 18/255, blue: 60/255)
            ]
        default:
            return [
                category.themeColor,
                category.themeColor.opacity(0.8),
                category.themeColor.opacity(0.6),
                category.themeColor.opacity(0.4)
            ]
        }
    }
}
