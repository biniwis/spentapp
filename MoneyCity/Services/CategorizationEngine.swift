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

/// Fast, comprehensive bilingual (Hebrew & English) keyword matching engine
/// covering the 9 core categories with extensive Israeli & Global merchants,
/// gateway prefix stripping, Hebrew prefix stemming, and direct 3D building mapping.
public final class CategorizationEngine: Sendable {
    public static let shared = CategorizationEngine()
    private init() {}
    
    private let dictionary: [SpendingCategory: [String]] = [
        .housing: [
            // Hebrew Utilities & Municipalities
            "שכירות", "שכר דירה", "ארנונה", "ארנונת", "ועד בית", "דמי ועד", "ניהול מבנים", "אחזקת מבנים",
            "חברת חשמל", "חשמל", "חשבון חשמל", "פזגז", "אמישראגז", "סופרגז", "דורגז", "גז",
            "תאגיד מים", "מי אביבים", "מי כרמל", "מי תל אביב", "מי שבע", "מי גבעתיים", "מי רמת גן", "מי מודיעין",
            "מי הוד השרון", "מניב", "הגיחון", "פלגי שרון", "מי תקווה", "מי שקמה",
            "עיריית תל אביב", "עיריית ירושלים", "עיריית חיפה", "עיריית ראשון לציון", "עיריית פתח תקווה",
            "עיריית חולון", "עיריית בני ברק", "עיריית רמת גן", "עיריית גבעתיים", "עיריית הרצליה",
            "עיריית כפר סבא", "עיריית רעננה", "עיריית נתניה", "עיריית אשדוד", "עיריית באר שבע",
            "עיריית מודיעין", "עיריית רמת השרון", "עיריית הוד השרון", "עיריית בת ים", "עירייה", "עיריית",
            "מועצה אזורית", "מועצה מקומית",
            "גינדי", "עזריאלי מגורים", "שיכון ובינוי", "אפריקה ישראל", "אזורים",
            "אינסטלטור", "חשמלאי", "מנעולן", "טכנאי מיזוג", "מיזוג אוויר", "תיקון מזגנים", "שיפוצים", "צבעי", "דוד שמש", "כרומגן", "הדברה",
            // English Utilities & Housing
            "rent", "arnona", "municipality", "city hall", "electric company", "iec", "electricity", "power", "energy",
            "gas", "pazgaz", "amisragas", "supergaz", "water", "mei avivim", "mei carmel", "building committee",
            "property management", "plumber", "electrician", "locksmith", "handyman", "maintenance", "pest control"
        ],
        
        .food: [
            // Hebrew Supermarkets & Groceries
            "שופרסל", "שופרסל שלי", "שופרסל דיל", "שופרסל אקספרס", "יש חסד", "יש בשכונה",
            "רמי לוי", "ויקטורי", "יוחננוף", "טיב טעם", "טיב מרקט", "קרפור", "אושר עד",
            "מחסני השוק", "חצי חינם", "מגה", "מגה בעיר", "יינות ביתן", "פרשמרקט", "מחסני להב",
            "סופר ברקת", "נתיב החסד", "מעיין 2000", "קינג סטור", "סטופ מרקט", "סאלח דבאח", "שוק העיר",
            "מעדני מזרע", "מעדני מניה", "זול ובגדול", "סופר יודה", "שוק מהדרין", "קואופ", "סופרמרקט", "סופר",
            "מינימרקט", "מכולת", "ירקן", "ירקניה", "פירות וירקות", "פירות", "ירקות", "קצב", "קצביה", "אטליז", "דגים",
            "מעדניה", "בית טבע", "אניס", "ניצת הדובדבן", "שקדיה", "שקד ומריר", "טבע קסטל", "טבע בריא",
            // Hebrew Delivery & Food Apps
            "וולט", "wolt", "10bis", "תן ביס", "tabit", "טאביט", "משלוחה", "סיבוס", "cibus", "sodexo", "יאנגו דלי", "גודיז", "קוויק", "quik",
            // Hebrew Coffee, Bakeries & Ice Cream
            "ארומה", "aroma", "arcaffe", "ארקפה", "landwer", "לנדוור", "קפה קפה", "גרג", "קפה גרג", "ביגה",
            "קפה לואיז", "קפה נמרוד", "אילנס", "קפאין", "קפה", "cafe", "coffee",
            "רולדין", "roladin", "מאפיית", "מאפיה", "קונדיטוריה", "לחמים", "לה מולאן", "טאבון", "בורקס", "קרואסון",
            "בוטיק סנטרל", "שמו", "קונדיטוריית שמו", "דודו אוטמזגין", "מימי", "mimi",
            "גולדה", "golda", "וניליה", "vaniglia", "אניטה", "anita", "לגנדה", "legenda", "אוטלו", "otello",
            "אייסברג", "דלי קרים", "ריבר", "rebar", "בי פראש", "b-fresh", "שייק", "מיצים", "גלידה", "גלידריה",
            // Hebrew Restaurants & Fast Food
            "מקדונלדס", "מקדונלד'ס", "מקדונלד", "mcdonalds", "mcdonald's", "mcdonald", "בורגר ראנץ'", "בורגרים", "burgerim",
            "bbb", "מוזס", "moses", "אגאדיר", "agadir", "פאט קאו", "גרינברג", "ג'ירף", "giraffe", "זוזוברה",
            "מינה טומיי", "טאיזו", "משייה", "שילה", "מחניודה",
            "דומינוס", "דומינו'ס", "dominos", "פיצה האט", "pizza hut", "פאפא ג'ונס", "papa johns", "פיצה", "pizza", "פיצריה",
            "שווארמה", "שוורמה", "שווארמת", "פלאפל", "חומוס", "חומוסיה", "שיפודים", "שיפודי", "גריל", "בשרים", "בורגר", "burger",
            "מסעדה", "מסעדת", "ביסטרו", "סושי", "sushi", "נודלס", "אסייתי", "תאילנדית", "מקסיקני", "טאקו", "ראמן", "שניצל", "פסטה",
            "בר", "פאב", "pub", "דיינר", "קנטינה", "קיוסק", "פיצוציה", "ילו", "yellow", "סוגוד", "sogood", "מנטה", "אלונית", "טמפו", "משקאות",
            // English Food, Supermarket & Dining
            "shufersal", "rami levy", "victory", "yohanof", "yohananof", "tiv taam", "carrefour", "osher ad", "am:pm", "mega",
            "starbucks", "dunkin", "subway", "kfc", "pizzeria", "burgers", "bakery", "boulangerie", "patisserie", "pastry",
            "deli", "delicatessen", "supermarket", "market", "minimarket", "grocery", "groceries", "roastery", "espresso",
            "restaurant", "steakhouse", "shawarma", "falafel", "hummus", "tacos", "ice cream", "gelato", "brewery", "winery",
            "liquor", "convenience", "butcher", "fishmonger", "dining", "eats", "takeaway", "food"
        ],
        
        .transport: [
            // Hebrew Parking, Gas & Transit
            "פנגו", "pango", "cellopark", "סלופארק", "חניה", "חניון", "אחוזות החוף", "סנטרל פארק",
            "דלק", "פז", "paz", "סונול", "sonol", "דור אלון", "doralon", "dor alon", "טן", "ten", "מיקה", "mika",
            "תדלוק", "דלקן", "טעינה", "עמדת טעינה", "טסלה סופרצ'רג'ר", "אפקון", "ev edge",
            "גט", "gett", "אובר", "uber", "יאנגו", "yango", "מוניות", "מונית", "מונית שירות",
            "רב קו", "רב-קו", "rav kav", "moovit", "מוביט", "הופאון", "hopon",
            "רכבת ישראל", "israel railways", "רכבת", "אגד", "egged", "דן", "dan", "מטרופולין", "קווים", "אפיקים", "סופרבוס", "נתיב אקספרס",
            "כרמלית", "רק״ל", "כפיר",
            "כביש 6", "דרך ארץ", "מנהרות הכרמל", "הנתיב המהיר",
            "ליים", "lime", "בירד", "bird", "ווינד", "wind", "דוט", "dott", "טיר", "tier", "קורקינט", "אופניים", "תל אופן",
            "מוסך", "מכון רישוי", "טסט", "צמיגים", "פנצ'ריה", "שטיפת רכב", "רחיצה", "שטיפומט", "אוטודיפו", "autodepot",
            "שלמה סיקסט", "הרץ", "אוויס", "אלדן", "באדג'ט", "השכרת רכב", "שיתוף רכב", "סיטי קאר", "car2go",
            "אל על", "ארקיע", "ישראייר", "ריינאייר", "וויז אייר", "איזיג'ט", "לופטהנזה", "פליי דובאי", "טיסה", "טיסות", "כרטיס טיסה", "נתב״ג", "נמל תעופה",
            // English Transport, Fuel, Flights & Transit
            "transit", "railway", "train", "metro", "bus", "taxi", "cab", "petrol", "gas station", "fuel", "charging",
            "scooter", "highway", "toll", "parking", "garage", "mechanic", "tires", "car wash", "sixt", "hertz", "avis",
            "eldan", "budget", "car rental", "rent a car", "el al", "arkia", "israir", "wizz", "wizz air", "ryanair",
            "easyjet", "lufthansa", "flydubai", "emirates", "airline", "airways", "flight", "airport"
        ],
        
        .shopping: [
            // Hebrew & Global Fashion & Apparel
            "זארה", "zara", "h&m", "pull&bear", "pull and bear", "פול אנד בר", "bershka", "ברשקה",
            "stradivarius", "שטראדיוואריוס", "massimo dutti", "מסימו דוטי", "oysho", "אוישו",
            "מנגו", "mango", "asos", "אסוס", "shein", "שיין", "next", "נקסט",
            "קסטרו", "castro", "פוקס", "fox", "טרמינל איקס", "טרמינל x", "terminal x", "רנואר", "renuar",
            "דלתא", "delta", "הודיס", "hoodies", "אורבניקה", "urbanica", "תמנון", "tamnoon", "יאנגה", "yanga",
            "עדיקה", "adika", "טוונטי פור סבן", "twentyfourseven", "גולף", "golf", "גולברי", "golbary", "קרייזי ליין",
            "עונות", "לי קופר", "lee cooper", "ליוויס", "levi's", "levis", "דיזל", "diesel", "טומי הילפיגר", "tommy hilfiger",
            "קלווין קליין", "calvin klein", "נאוטיקה", "nautica", "פולו", "polo", "אמריקן איגל", "american eagle",
            // Shoes & Accessories
            "אלדו", "aldo", "ספרינג", "spring", "טוגו", "to go", "סקופ", "scoop", "סטיב מאדן", "steve madden", "קרוקס", "crocs", "בילבונג", "billabong",
            "אופטיקנה", "opticana", "קרולינה למקה", "carolina lemke", "אירוקה", "erroca",
            // Online Marketplaces & Tech
            "אמזון", "amazon", "עליאקספרס", "aliexpress", "איביי", "ebay", "טימו", "temu", "אטסי", "etsy", "אייהרב", "iherb",
            "קיי אס פי", "ksp", "אייבורי", "ivory", "באג", "bug", "איידיגיטל", "idigital", "אייסטור", "istore", "דינמיקה", "dynamica",
            "בסט מובייל", "best mobile", "מחסני חשמל", "payngo", "שקם אלקטריק", "shekem electric", "אפל סטור", "apple store",
            "מחשבים וסלולר", "מחשבים", "מחשב", "אלקטרוניקה", "סמארטפון", "סלולרי",
            // Home, Hardware, Books & Toys
            "איקאה", "ikea", "אייס", "ace", "הום סנטר", "home center", "שז״ר", "טמבור", "tambur", "טמבוריה", "כתר", "keter",
            "ביתילי", "betili", "זאגה", "zaga", "שמרת הזורע", "סולתם", "soltam", "נעמן", "naaman", "ארקוסטיל", "arcosteel",
            "ורדינון", "vardinon", "כיתן", "kitan", "פוקס הום", "fox home", "גולף אנד קו", "golf & co",
            "שילב", "shilav", "מוצצים", "motzetzim", "בייבי סטאר", "טויס אר אס", "toys r us", "הפיראט האדום", "כפר השעשועים", "לגו", "lego",
            "קרביץ", "kravitz", "סטימצקי", "stimatzky", "צומת ספרים", "tzomet sfarim", "ארטא", "arta",
            // Sports
            "דקטלון", "decathlon", "נייקי", "nike", "אדידס", "adidas", "פומה", "puma", "אנדר ארמור", "under armour",
            "מגה ספורט", "mega sport", "ספורט ורטהיימר", "אליטל", "פוט לוקר", "foot locker", "jd sports",
            // Cosmetics & Care
            "ללין", "laline", "סבון", "sabon", "בודי שופ", "body shop", "מאק", "mac cosmetics", "איל מקיאג'", "il makiage",
            "קיקו", "kiko milano", "ספורה", "sephora", "אפריל", "april",
            // English Retail & General
            "boutique", "store", "shop", "fashion", "clothing", "apparel", "shoes", "footwear", "eyewear", "optics",
            "jewelry", "electronics", "gadgets", "furniture", "hardware", "duty free", "duty-free", "cosmetics", "perfume"
        ],
        
        .entertainment: [
            // Cinema, Shows & Events
            "סינמה סיטי", "cinema city", "יס פלאנט", "yes planet", "פלאנט", "רב חן", "rav hen", "הוט סינמה", "hot cinema",
            "מובילנד", "movieland", "סינמטק", "cinematheque", "קולנוע", "cinema", "movies",
            "הבימה", "habima", "הקאמרי", "cameri", "בית ליסין", "תיאטרון גשר", "תיאטרון", "theatre", "theater", "היכל התרבות",
            "זאפה", "zappa", "גריי", "בארבי", "barby", "שוני", "אמפי", "קיסריה",
            "טיקטמאסטר", "ticketmaster", "איוונטים", "eventim", "קופת בראבו", "קופת תל אביב", "לאן", "lean", "טיקצ'אק", "tickchak",
            "כרטיסים", "כרטיס", "הופעה", "מופע", "הצגה", "פסטיבל", "סטנדאפ", "standup", "comedy",
            // Gaming & Attractions
            "playstation", "sony", "xbox", "steam", "nintendo", "game", "gaming", "arcade",
            "באולינג", "bowling", "קארטינג", "karting", "לייזר טאג", "laser tag", "חדר בריחה", "escape room", "אסקייפ רום",
            "לונה פארק", "סופרלנד", "superland", "מימדיון", "ימית 2000", "שפיים", "גן חיות", "ספארי", "אקווריום",
            "מוזיאון", "museum", "מוזיאון ישראל", "מוזיאון תל אביב", "תערוכה", "גלריה", "gallery"
        ],
        
        .health: [
            // Pharmacies & HMOs
            "סופר-פארם", "סופר פארם", "super-pharm", "super pharm", "בי פארם", "be פארם", "be", "גוד פארם", "good pharm",
            "בית מרקחת", "pharmacy", "drugstore",
            "מכבי", "maccabi", "מכבי פארם", "כללית", "clalit", "כללית מושלם", "מאוחדת", "meuhedet", "לאומית", "leumit",
            "טרם", "terem", "אסותא", "assuta", "מדיקל סנטר", "ביקור רופא", "ביקורופא",
            "איכילוב", "ichilov", "שיבא", "sheba", "תל השומר", "הדסה", "hadassah", "רמב״ם", "rambam", "בילינסון", "beilinson",
            "סורוקה", "soroka", "וולפסון", "אסף הרופא", "קפלן", "שניידר", "בית חולים", "hospital",
            "מרפאה", "מרפאת", "קופת חולים", "clinic", "רופא שיניים", "שיניים", "מרפאת שיניים", "דנטל", "dentist", "dental", "רופא", "doctor",
            // Fitness & Wellbeing
            "הולמס פלייס", "holmes place", "גרייט שייפ", "great shape", "ספייס", "space gym", "פרופיט", "profit",
            "גו אקטיב", "go active", "קאנטרי", "country club", "חדר כושר", "מכון כושר", "gym", "fitness", "workout",
            "פילאטיס", "pilates", "יוגה", "yoga", "סטודיו", "קרוספיט", "crossfit", "בריכה", "swimming pool",
            "פסיכולוג", "פסיכותרפיה", "פיזיותרפיה", "physiotherapy", "כירופרקט", "מסאז'", "ספא", "spa", "טיפוח", "wellness"
        ],
        
        .subscriptions: [
            // Streaming Video, Music & Apps
            "netflix", "נטפליקס", "spotify", "ספוטיפיי", "apple tv", "apple music", "apple.com/bill", "itunes", "icloud",
            "youtube", "יוטיוב", "youtube premium", "disney", "דיסני", "disney+", "hbo", "hbo max", "amazon prime", "prime video",
            "yes", "יס", "hot", "הוט", "sting tv", "סטינג", "סטינג tv", "next tv", "נקסט tv", "free tv", "פרי tv",
            "cellcom tv", "סלקום tv", "partner tv", "פרטנר tv",
            "chatgpt", "openai", "claude", "anthropic", "midjourney", "google storage", "google one", "dropbox",
            "onedrive", "microsoft 365", "office 365", "adobe", "canva", "zoom", "github", "notion", "figma", "patreon", "substack", "linkedin",
            // Mobile Telecom
            "סלקום", "cellcom", "פרטנר", "partner", "פלאפון", "pelephone", "הוט מובייל", "hot mobile",
            "גולן טלקום", "golan telecom", "golan", "וויקום", "wecom", "we4g", "012", "019", "רמי לוי תקשורת", "cellular", "telecom"
        ],
        
        .finance: [
            // Banks
            "בנק הפועלים", "פועלים", "poalim", "בנק לאומי", "לאומי", "leumi", "דיסקונט", "discount", "בנק דיסקונט",
            "מזרחי טפחות", "מזרחי", "mizrahi", "הבינלאומי", "fibi", "בנק יהב", "יהב", "yahav", "אוצר החייל", "בנק מסד",
            "פפר", "pepper", "וואן זירו", "one zero", "בנק", "bank",
            // Credit Cards & Processors
            "ישראכרט", "isracard", "כאל", "cal", "מקס", "max", "לאומי קארד", "ויזה", "visa", "מאסטרקארד", "mastercard",
            "אמריקן אקספרס", "american express", "amex", "דיינרס", "diners",
            // Insurance & Loans
            "הראל", "harel", "הפניקס", "phoenix", "מגדל", "migdal", "כלל ביטוח", "כלל", "clal", "מנורה מבטחים", "מנורה", "menora",
            "ביטוח ישיר", "איידיאיי", "idi", "ליברה", "libra", "וובי", "wobi", "aig",
            "ביטוח", "insurance", "פנסיה", "קרן פנסיה", "pension",
            "דמי כרטיס", "עמלה", "עמלת", "עמלות", "ריבית", "interest", "הלוואה", "loan", "משכנתא", "משכנתה", "mortgage", "מימון ישיר", "fee"
        ],
        
        .savings: [
            "חיסכון", "savings", "הפקדה", "deposit", "השקעה", "investment", "קופת גמל", "קרן השתלמות",
            "בורסה", "stock exchange", "s&p", "s&p500", "nasdaq", "מדד", "etf",
            "אינטראקטיב", "ibkr", "interactive brokers", "interactive", "מיטב", "meitav",
            "אלטשולר שחם", "אלטשולר", "altshuler", "ילין לפידות", "מור", "אנליסט", "קסם", "פסגות", "אקסלנס", "ibi",
            "בייננס", "binance", "קריפטו", "crypto", "ביטקוין", "bitcoin"
        ],
        
        .miscellaneous: [
            // Mail & Couriers
            "דואר ישראל", "דואר", "israel post", "post office", "צ'יטה", "בוקסיט", "boxit", "dhl", "fedex", "ups", "שליח", "courier",
            // Professional & Municipal Services
            "מכבסה", "ניקוי יבש", "laundry", "dry clean", "צילום", "דפוס", "printing",
            "עורך דין", "lawyer", "נוטריון", "notary", "רואה חשבון", "cpa", "accountant",
            "משרד הפנים", "רשות האוכלוסין", "משרד הרישוי", "אגרה", "דמי חבר",
            // Fines & Police
            "קנס חניה עיריית תל אביב", "קנס עיריית תל אביב", "דוח עיריית תל אביב",
            "קנס חניה עיריית ירושלים", "קנס עיריית גבעתיים", "קנס חניה", "קנס עירייה",
            "קנס", "דוח חניה", "דוח", "fine", "parking ticket", "משטרה", "police", "בית משפט",
            // Pets, Flowers & Gifts
            "וטרינר", "veterinarian", "vet", "מרפאה וטרינרית", "אניפט", "anipet", "זולו", "zooloo", "פט ביי", "pet buy", "חיות מחמד", "pets", "pet shop",
            "מתנה", "gift", "gifts", "פרחים", "flowers", "זר פור יו", "zer4u", "תרומה", "donation", "charity",
            "שונות", "misc", "כללי", "general", "וינטג'", "vintage", "מכירה פומבית", "auction"
        ]
    ]
    
    public func categorize(merchant: String, amount: Double) -> SpendingCategory {
        return classify(merchant: merchant, amount: amount).category
    }
    
    public func classify(merchant: String, amount: Double) -> ClassificationResult {
        var clean = merchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return ClassificationResult(category: .other, buildingId: "city_sorting_hub", confidence: 0.0)
        }
        
        // 1. Strip common payment gateway/aggregator prefixes in both English & Hebrew
        clean = clean.replacingOccurrences(
            of: #"^(?:paypal\s*[\*\:]|pp\s*[\*\:]|google\s*[\*\:]|g\s*[\*\:]|sumup\s*[\*\:]|sq\s*[\*\:]|stripe\s*[\*\:]|gmf\s*[\*\:]|iz\s*[\*\:]|bit\s*[\*\-\:]|paybox\s*[\*\-\:]|wolt\s*[\*\:]|tabit\s*[\*\:])\s*"#,
            with: "",
            options: .regularExpression
        )
        
        // 2. Strip common Israeli transaction phrases (e.g. "עסקה ב-", "הו״ק -", "תשלום ל-", "חויב ב-")
        clean = clean.replacingOccurrences(
            of: #"^(?:עסקה\s*ב-|חויב\s*ב-|הוראת\s*קבע\s*-?|הו״ק\s*-?|תשלום\s*ל-|תשלום\s*עבור\s*)\s*"#,
            with: "",
            options: .regularExpression
        )
        
        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: " ,-:;•*\"'״׳").union(.whitespacesAndNewlines))
        if clean.isEmpty {
            return ClassificationResult(category: .other, buildingId: "city_sorting_hub", confidence: 0.0)
        }
        
        // 3. Tokenize merchant into distinct words
        let rawTokens = clean.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        
        // 4. Hebrew prefix stemming (support ב-, ל-, מ-, ה-, ו-, ש-)
        var effectiveTokens = Set(rawTokens)
        let hebrewPrefixes: [Character] = ["ב", "ל", "מ", "ה", "ו", "ש"]
        for token in rawTokens {
            if let first = token.first, hebrewPrefixes.contains(first), token.count >= 4 {
                let root = String(token.dropFirst())
                effectiveTokens.insert(root)
                if let second = root.first, hebrewPrefixes.contains(second), root.count >= 4 {
                    effectiveTokens.insert(String(root.dropFirst()))
                }
            }
        }
        
        var bestCategory: SpendingCategory? = nil
        var bestMatchLength: Int = 0
        
        // 5. Match longer / more specific phrases first across the entire bilingual dictionary
        for (category, keywords) in dictionary {
            for kw in keywords {
                let kwLower = kw.lowercased()
                if kwLower.count <= 3 {
                    // Short keywords (e.g. 'בר', 'pub', 'גט', 'דן', 'ksp', 'paz', 'bug', 'ace', 'vet')
                    // must match as a standalone word token to prevent false positive substring collisions
                    if effectiveTokens.contains(kwLower) {
                        if kwLower.count > bestMatchLength {
                            bestMatchLength = kwLower.count
                            bestCategory = category
                        }
                    }
                } else {
                    // Longer keywords and multi-word phrases can match either as substrings in clean or as tokens
                    if clean.contains(kwLower) || effectiveTokens.contains(kwLower) {
                        if kwLower.count > bestMatchLength {
                            bestMatchLength = kwLower.count
                            bestCategory = category
                        }
                    }
                }
            }
        }
        
        // 6. If no specific merchant matched, fall back to venue/mall descriptors (e.g. bare "קניון עזריאלי")
        if bestCategory == nil {
            for (category, keywords) in venueFallbackDictionary {
                for kw in keywords {
                    let kwLower = kw.lowercased()
                    if clean.contains(kwLower) || effectiveTokens.contains(kwLower) {
                        if kwLower.count > bestMatchLength {
                            bestMatchLength = kwLower.count
                            bestCategory = category
                        }
                    }
                }
            }
        }
        
        let finalCat = bestCategory ?? .other
        let confidence = bestCategory != nil ? 0.95 : 0.50
        let buildingId = mapToBuildingId(category: finalCat, merchant: clean)
        
        return ClassificationResult(category: finalCat, buildingId: buildingId, confidence: confidence)
    }
    
    private let venueFallbackDictionary: [SpendingCategory: [String]] = [
        .shopping: [
            "עזריאלי", "azrieli", "קניוני עופר", "ביג", "דיזנגוף סנטר", "שרונה מרקט", "קניון", "mall", "מתחם", "מרכז קניות", "outlet"
        ]
    ]
    
    /// Deterministically maps any transaction (by category and merchant) to one of the 12 precise 3D buildings.
    public func mapToBuildingId(category: SpendingCategory, merchant: String) -> String {
        let m = merchant.lowercased()
        
        switch category {
        case .food, .groceries, .coffee:
            if m.contains("wolt") || m.contains("וולט") || m.contains("10bis") || m.contains("תן ביס") || m.contains("tabit") || m.contains("טאביט") || m.contains("משלוח") || m.contains("delivery") || m.contains("cibus") || m.contains("סיבוס") {
                return "food_wolt"
            }
            if category == .coffee || m.contains("קפה") || m.contains("cafe") || m.contains("coffee") || m.contains("aroma") || m.contains("ארומה") || m.contains("גולדה") || m.contains("golda") || m.contains("arcaffe") || m.contains("ארקפה") || m.contains("landwer") || m.contains("לנדוור") || m.contains("מאפיה") || m.contains("מאפיית") || m.contains("bakery") || m.contains("roladin") || m.contains("רולדין") || m.contains("וניליה") || m.contains("vaniglia") || m.contains("אניטה") || m.contains("anita") || m.contains("rebar") || m.contains("ריבר") {
                return "food_coffee"
            }
            if category == .groceries || m.contains("סופר") || m.contains("super") || m.contains("market") || m.contains("שופרסל") || m.contains("shufersal") || m.contains("רמי לוי") || m.contains("rami levy") || m.contains("ויקטורי") || m.contains("victory") || m.contains("יוחננוף") || m.contains("yohanof") || m.contains("טיב טעם") || m.contains("tiv taam") || m.contains("am:pm") || m.contains("מכולת") || m.contains("grocery") || m.contains("אושר עד") || m.contains("קרפור") || m.contains("carrefour") || m.contains("מגה") || m.contains("mega") || m.contains("יינות ביתן") || m.contains("פרשמרקט") || m.contains("קצב") || m.contains("ירקן") {
                return "food_super"
            }
            return "food_bistro"
            
        case .shopping:
            if m.contains("ksp") || m.contains("ivory") || m.contains("אייבורי") || m.contains("חשמל") || m.contains("באג") || m.contains("bug") || m.contains("amazon") || m.contains("אמזון") || m.contains("aliexpress") || m.contains("עליאקספרס") || m.contains("temu") || m.contains("טימו") || m.contains("idigital") || m.contains("istore") || m.contains("מחשב") || m.contains("computer") || m.contains("electronics") {
                return "shop_tech"
            }
            if m.contains("flight") || m.contains("טיסה") || m.contains("טיסות") || m.contains("el al") || m.contains("אל על") || m.contains("arkia") || m.contains("ארקיע") || m.contains("israir") || m.contains("ישראייר") || m.contains("wizz") || m.contains("ryanair") || m.contains("easyjet") || m.contains("airbnb") || m.contains("booking") || m.contains("hotel") || m.contains("מלון") || m.contains("איסתא") || m.contains("duty free") || m.contains("דיוטי פרי") {
                return "shop_travel"
            }
            return "shop_boutique"
            
        case .entertainment:
            return "shop_arcade"
            
        case .housing:
            if m.contains("חשמל") || m.contains("electric") || m.contains("ארנונה") || m.contains("arnona") || m.contains("עיריית") || m.contains("עירייה") || m.contains("municipality") || m.contains("מים") || m.contains("water") || m.contains("מי אביבים") || m.contains("מי כרמל") || m.contains("מי שבע") || m.contains("תאגיד מים") || m.contains("גז") || m.contains("gas") || m.contains("פזגז") || m.contains("אמישראגז") || m.contains("סופרגז") {
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
            
        case .health:
            return "health_pharmacy"

        case .finance:
            return "finance_bank"
        }
    }
}
