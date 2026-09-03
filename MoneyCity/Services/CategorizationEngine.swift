import Foundation

public struct ClassificationResult: Sendable {
    public let category: SpendingCategory
    public let buildingId: String
    public let confidence: Double
    
    public init(category: SpendingCategory, buildingId: String, confidence: Double) {
        self.category = category
        self.buildingId = buildingId
        self.confidence = confidence
    }
}

/// Fast keyword matching engine covering the 9 core categories with extensive Israeli & Global merchants and direct 3D building mapping.
public final class CategorizationEngine: Sendable {
    public static let shared = CategorizationEngine()
    private init() {}
    
    private let dictionary: [SpendingCategory: [String]] = [
        .housing: [
            "שכירות", "rent", "ארנונה", "ארנונת", "חברת חשמל", "חשמל", "אינטרנט",
            "מי אביבים", "מי כרמל", "מי תל אביב", "מי שבע", "מי גבעתיים", "תאגיד מים", "גינדי", "עזריאלי מגורים", "ועד בית",
            "עיריית גבעתיים", "עיריית תל אביב", "עיריית ירושלים", "עיריית חיפה", "עיריית רמת גן", "עירייה",
            "בזק", "bezeq", "hot", "הוט", "partner fiber", "cellcom fiber", "פזגז", "אמישראגז", "סופרגז"
        ],
        .food: [
            "שופרסל", "shufersal", "רמי לוי", "rami levy", "ויקטורי", "victory",
            "יוחננוף", "yohanof", "טיב טעם", "tiv taam", "am:pm", "סופר", "מכולת", "קרפור", "carrefour",
            "אושר עד", "osher ad", "מחסני השוק", "חצי חינם", "מגה", "mega",
            "wolt", "וולט", "10bis", "תן ביס", "tabit", "ארומה", "aroma", "arcaffe",
            "ארקפה", "landwer", "לנדוור", "קפה", "cafe", "coffee", "מסעדת", "פיצה", "pizza",
            "burger", "בורגר", "מקדונלדס", "מקדונלד'ס", "מקדונלד", "mcdonalds", "mcdonald's", "גולדה", "golda", "מאפיית", "מאפיה", "bakery", "בר",
            "דומינוס", "dominos", "bbb", "מוזס", "moses", "אגאדיר", "agadir", "פאפוד", "סושי", "sushi"
        ],
        .transport: [
            "pango", "פנגו", "cellopark", "סלופארק", "דלק", "פז", "paz", "סונול", "sonol",
            "דור אלון", "doralon", "טן", "ten", "gett", "גט", "uber", "אובר", "moovit", "מוביט",
            "רב קו", "rav kav", "רכבת ישראל", "israel railways", "אגד", "דן", "מטרופולין", "קווים", "מוסך", "טסט", "חניה"
        ],
        .shopping: [
            "zara", "זארה", "h&m", "pull&bear", "bershka", "asos", "אסוס", "amazon", "אמזון",
            "aliexpress", "ksp", "אייבורי", "ivory", "מחסני חשמל", "ikea", "איקאה", "באג", "bug",
            "fox", "פוקס", "terminal x", "טרמינל", "castro", "קסטרו", "דלתא", "delta", "רנואר", "renuar",
            "מנגו", "mango", "גולף", "golf", "שילב", "shilav", "הודיס", "hoodies", "אורבניקה", "urbanica"
        ],
        .entertainment: [
            "cinema city", "סינמה סיטי", "yes planet", "יס פלאנט", "rav hen", "רב חן", "hot cinema", "הוט סינמה",
            "zappa", "זאפה", "pub", "פאב", "הופעה", "כרטיסים", "eventim", "קופת בראבו",
            "playstation", "sony", "xbox", "steam", "nintendo", "קולנוע", "באולינג", "לונה פארק"
        ],
        .health: [
            "super-pharm", "סופר פארם", "be", "be פארם", "good pharm", "גוד פארם", "מכבי", "maccabi", "כללית", "clalit",
            "מאוחדת", "לאומית", "בית מרקחת", "pharmacy", "holmes place", "הולמס פלייס", "קאנטרי",
            "גרייט שייפ", "great shape", "space gym", "ספייס", "פרופיט", "profit", "שיניים", "dentist", "אופטיקה", "optica"
        ],
        .subscriptions: [
            "netflix", "נטפליקס", "spotify", "ספוטיפיי", "apple.com/bill", "itunes", "icloud",
            "youtube", "google storage", "chatgpt", "openai", "disney", "דיסני", "hbo",
            "סלקום", "cellcom", "פרטנר", "partner", "פלאפון", "pelephone", "012", "we4g", "גולן טלקום", "golan"
        ],
        .finance: [
            "עמלת", "עמלה", "דמי כרטיס", "ריבית", "interest", "הלוואה", "loan",
            "בנק הפועלים", "poalim", "בנק לאומי", "leumi", "דיסקונט", "discount", "מזרחי", "mizrahi",
            "ישראכרט", "isracard", "כאל", "cal", "max", "מקס", "מיטב", "אלטשולר", "הראל", "מגדל", "הפניקס"
        ],
        .savings: [
            "חיסכון", "savings", "קופת גמל", "קרן השתלמות", "s&p", "s&p500", "הפקדה", "deposit", "בורסה", "ibkr", "interactive"
        ],
        .miscellaneous: [
            "קנס חניה עיריית תל אביב", "קנס עיריית תל אביב", "דוח עיריית תל אביב",
            "קנס חניה עיריית ירושלים", "קנס עיריית גבעתיים", "קנס חניה", "קנס עירייה",
            "קנס", "דוח", "fine", "משטרה", "police",
            "מתנה", "gift", "פרחים", "flowers", "תרומה", "donation",
            "עורך דין", "lawyer", "נוטריון", "notary",
            "אגרה", "fee", "שונות", "misc", "כללי", "general", "וינטג'", "vintage",
            "מכירה פומבית", "auction"
        ]
    ]
    
    public func categorize(merchant: String, amount: Double) -> SpendingCategory {
        return classify(merchant: merchant, amount: amount).category
    }
    
    public func classify(merchant: String, amount: Double) -> ClassificationResult {
        let clean = merchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return ClassificationResult(category: .other, buildingId: "city_sorting_hub", confidence: 0.0)
        }
        
        // Tokenize merchant into distinct words
        let tokens = clean.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        
        var bestCategory: SpendingCategory? = nil
        var bestMatchLength: Int = 0
        
        // Match longer/more specific phrases first
        for (category, keywords) in dictionary {
            for kw in keywords {
                let kwLower = kw.lowercased()
                if kwLower.count <= 3 {
                    // Short keywords (e.g. 'בר', 'pub', 'גט', 'דן') must match as a standalone word token
                    if tokens.contains(kwLower) {
                        if kwLower.count > bestMatchLength {
                            bestMatchLength = kwLower.count
                            bestCategory = category
                        }
                    }
                } else {
                    // Longer keywords and multi-word phrases can match as substrings
                    if clean.contains(kwLower) {
                        if kwLower.count > bestMatchLength {
                            bestMatchLength = kwLower.count
                            bestCategory = category
                        }
                    }
                }
            }
        }
        
        // An unknown merchant defaults honestly to .other (Post Office / Sorting Hub)
        // with low confidence so the user can easily route it in the sorting hub.
        let finalCat = bestCategory ?? .other
        let confidence = bestCategory != nil ? 0.95 : 0.50
        let buildingId = mapToBuildingId(category: finalCat, merchant: clean)
        
        return ClassificationResult(category: finalCat, buildingId: buildingId, confidence: confidence)
    }
    
    /// Deterministically maps any transaction (by category and merchant) to one of the 12 precise 3D buildings.
    public func mapToBuildingId(category: SpendingCategory, merchant: String) -> String {
        let m = merchant.lowercased()
        
        switch category {
        case .food, .groceries, .coffee:
            if m.contains("wolt") || m.contains("וולט") || m.contains("10bis") || m.contains("תן ביס") || m.contains("tabit") || m.contains("משלוח") {
                return "food_wolt"
            }
            if category == .coffee || m.contains("קפה") || m.contains("cafe") || m.contains("coffee") || m.contains("aroma") || m.contains("ארומה") || m.contains("גולדה") || m.contains("golda") || m.contains("arcaffe") || m.contains("ארקפה") || m.contains("landwer") || m.contains("לנדוור") || m.contains("מאפיה") || m.contains("מאפיית") || m.contains("bakery") {
                return "food_coffee"
            }
            if category == .groceries || m.contains("סופר") || m.contains("super") || m.contains("שופרסל") || m.contains("shufersal") || m.contains("רמי לוי") || m.contains("rami levy") || m.contains("ויקטורי") || m.contains("victory") || m.contains("יוחננוף") || m.contains("טיב טעם") || m.contains("am:pm") || m.contains("מכולת") || m.contains("אושר עד") || m.contains("קרפור") || m.contains("carrefour") {
                return "food_super"
            }
            return "food_bistro"
            
        case .shopping:
            if m.contains("ksp") || m.contains("ivory") || m.contains("אייבורי") || m.contains("חשמל") || m.contains("באג") || m.contains("bug") || m.contains("amazon") || m.contains("אמזון") || m.contains("aliexpress") || m.contains("עליאקספרס") || m.contains("idigital") || m.contains("istore") || m.contains("מחשב") {
                return "shop_tech"
            }
            if m.contains("flight") || m.contains("טיסה") || m.contains("טיסות") || m.contains("el al") || m.contains("אל על") || m.contains("airbnb") || m.contains("booking") || m.contains("hotel") || m.contains("מלון") || m.contains("איסתא") || m.contains("wizz") || m.contains("ryanair") || m.contains("arkia") || m.contains("ארקיע") {
                return "shop_travel"
            }
            return "shop_boutique"
            
        case .entertainment:
            return "shop_arcade"
            
        case .housing:
            if m.contains("חשמל") || m.contains("ארנונה") || m.contains("עיריית") || m.contains("עירייה") || m.contains("מים") || m.contains("מי אביבים") || m.contains("מי כרמל") || m.contains("גז") || m.contains("פזגז") || m.contains("gas") {
                return "house_util"
            }
            return "house_tower"
            
        case .subscriptions:
            return "house_subs"
            
        case .savings:
            return "savings_sanctuary"
            
        case .transport:
            return "trans_station"
            
        case .miscellaneous, .misc:
            return "museum_curiosities"
            
        case .other:
            return "city_sorting_hub"
            
        case .health, .finance:
            return "shop_boutique"
        }
    }
}
