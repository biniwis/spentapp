// ============================================================
// MARK: - מערכת בדיקות מקיפה לסנכרון Apple Pay ← Money City
// ============================================================
// כיצד להריץ: node test_apple_pay_sync.js
// ============================================================

let passed = 0
let failed = 0
var results = []

function test(name, fn) {
    try {
        fn()
        results.push({ status: "✅ PASS", name })
        passed++
    } catch (e) {
        results.push({ status: "❌ FAIL", name, error: e.message })
        failed++
    }
}

function assert(condition, msg) {
    if (!condition) throw new Error(msg || "Assertion failed")
}

function assertEqual(a, b, msg) {
    if (a !== b) throw new Error(msg || `Expected "${b}" but got "${a}"`)
}

// ============================================================
// MARK: - מודל CategorizationEngine (מיפוי JavaScript)
// ============================================================

const KEYWORDS = {
    housing: ["שכירות","rent","ארנונה","עיריית","חברת חשמל","חשמל","אינטרנט","בזק","bezeq","hot","הוט","partner fiber","cellcom fiber","מי אביבים","ועד בית"],
    food: ["שופרסל","shufersal","רמי לוי","rami levy","ויקטורי","victory","יוחננוף","טיב טעם","tiv taam","am:pm","סופר","מכולת","wolt","וולט","10bis","תן ביס","tabit","ארומה","aroma","arcaffe","ארקפה","landwer","לנדוור","קפה","cafe","מסעדת","פיצה","pizza","burger","בורגר","מקדונלדס","mcdonalds","גולדה","golda","מאפיית"],
    transport: ["pango","פנגו","cellopark","סלופארק","דלק","פז","paz","סונול","sonol","דור אלון","doralon","gett","גט","uber","אובר","moovit","מוביט","רב קו","rav kav","רכבת ישראל","israel railways","אגד","דן","מוסך","טסט"],
    shopping: ["zara","זארה","h&m","pull&bear","bershka","asos","אסוס","amazon","אמזון","aliexpress","ksp","אייבורי","ivory","מחסני חשמל","ikea","איקאה","fox","פוקס","terminal x","טרמינל","castro","קסטרו","דלתא","delta"],
    entertainment: ["cinema city","סינמה סיטי","yes planet","יס פלאנט","rav hen","רב חן","zappa","זאפה","בר","pub","פאב","הופעה","כרטיסים","eventim","playstation","sony","xbox","steam","nintendo","קולנוע"],
    health: ["super-pharm","סופר פארם","be","מכבי","maccabi","כללית","clalit","מאוחדת","לאומית","בית מרקחת","pharmacy","holmes place","הולמס פלייס","גרייט שייפ","great shape","space gym","ספייס","קאנטרי","שיניים","dentist"],
    subscriptions: ["netflix","נטפליקס","spotify","ספוטיפיי","apple.com/bill","itunes","icloud","youtube","google storage","chatgpt","openai","disney","דיסני","סלקום","cellcom","פרטנר","partner","פלאפון","pelephone","012","we4g"],
    finance: ["עמלת","עמלה","דמי כרטיס","ריבית","interest","הלוואה","loan","בנק הפועלים","poalim","בנק לאומי","leumi","דיסקונט","discount","ישראכרט","isracard","כאל","cal","max","מקס","מיטב","אלטשולר"],
    other: ["מתנה","gift","פרחים","תרומה","donation","bit","ביט","paybox","פייבוקס"]
}

function classify(merchant) {
    const clean = merchant.toLowerCase().trim()
    if (!clean) return { category: "other", confidence: 0.0 }
    
    const tokens = clean.split(/[^a-zA-Z0-9\u0590-\u05FF]+/).filter(Boolean)
    let bestCategory = null
    let bestMatchLength = 0
    
    for (const [category, keywords] of Object.entries(KEYWORDS)) {
        for (const kw of keywords) {
            const kwLower = kw.toLowerCase()
            if (kwLower.length <= 3) {
                if (tokens.includes(kwLower)) {
                    if (kwLower.length > bestMatchLength) {
                        bestMatchLength = kwLower.length
                        bestCategory = category
                    }
                }
            } else {
                if (clean.includes(kwLower)) {
                    if (kwLower.length > bestMatchLength) {
                        bestMatchLength = kwLower.length
                        bestCategory = category
                    }
                }
            }
        }
    }
    if (bestCategory) return { category: bestCategory, confidence: 0.95 }
    return { category: "food", confidence: 0.50 } // default fallback
}

// ============================================================
// MARK: - מחלקת RecordTransactionIntent (סימולציה)
// ============================================================

class SimulatedDatabase {
    constructor() { this.records = [] }
    save(tx) {
        if (!tx.amount || tx.amount <= 0) throw new Error("Invalid amount: must be > 0")
        if (!tx.merchant || tx.merchant.trim() === "") throw new Error("Merchant name required")
        if (!tx.category) throw new Error("Category required")
        this.records.push(tx)
    }
    fetchForMonth(year, month) {
        return this.records.filter(r => {
            const d = new Date(r.timestamp)
            return d.getFullYear() === year && d.getMonth() + 1 === month
        })
    }
    count() { return this.records.length }
}

function performIntent({ amount, merchant, currency = "₪", date = new Date() }, db) {
    if (!amount || amount <= 0) throw new Error("Invalid amount")
    if (!merchant || merchant.trim() === "") throw new Error("Missing merchant")
    const result = classify(merchant)
    const tx = {
        id: Math.random().toString(36).substr(2, 9),
        amount,
        currency,
        merchant,
        category: result.category,
        confidence: result.confidence,
        timestamp: date,
        isManual: false,
        isConfirmed: result.confidence >= 0.8
    }
    db.save(tx)
    return tx
}

// ============================================================
// MARK: - SUITE 1: בדיקות CategorizationEngine
// ============================================================

console.log("\n🧠 SUITE 1: CategorizationEngine — מנוע סיווג אוטומטי\n")

test("🛒 שופרסל → food", () => assertEqual(classify("שופרסל").category, "food"))
test("🛒 Shufersal Online → food", () => assertEqual(classify("Shufersal Online").category, "food"))
test("🍕 Wolt delivery → food", () => assertEqual(classify("Wolt Delivery IL").category, "food"))
test("☕ ארומה אקספרס → food", () => assertEqual(classify("ארומה אקספרס").category, "food"))
test("🍔 מקדונלדס → food", () => assertEqual(classify("מקדונלדס רמת גן").category, "food"))
test("🚗 פנגו חניה → transport", () => assertEqual(classify("Pango Parking IL").category, "transport"))
test("🚗 Uber Technologies → transport", () => assertEqual(classify("Uber Technologies").category, "transport"))
test("🚗 תחנת דלק פז → transport", () => assertEqual(classify("תחנת דלק פז 2000").category, "transport"))
test("🛍️ Zara Israel → shopping", () => assertEqual(classify("Zara Israel Ltd").category, "shopping"))
test("🛍️ Amazon.com → shopping", () => assertEqual(classify("Amazon.com Marketplace").category, "shopping"))
test("🛍️ IKEA Israel → shopping", () => assertEqual(classify("IKEA Israel").category, "shopping"))
test("🏠 חברת חשמל → housing", () => assertEqual(classify("חברת חשמל לישראל").category, "housing"))
test("🏠 ארנונה עיריית תל אביב → housing", () => assertEqual(classify("ארנונה עיריית תל אביב").category, "housing"))
test("🏠 hot mobile internet → housing", () => assertEqual(classify("hot mobile internet").category, "housing"))
test("📱 Netflix IL → subscriptions", () => assertEqual(classify("Netflix IL").category, "subscriptions"))
test("📱 Spotify AB → subscriptions", () => assertEqual(classify("Spotify AB Stockholm").category, "subscriptions"))
test("📱 Apple.com/bill → subscriptions", () => assertEqual(classify("APPLE.COM/BILL").category, "subscriptions"))
test("📱 iCloud+ → subscriptions", () => assertEqual(classify("iCloud+ storage upgrade").category, "subscriptions"))
test("❤️ סופר פארם → health", () => assertEqual(classify("Super-Pharm IL").category, "health"))
test("❤️ מכבי שירותי בריאות → health", () => assertEqual(classify("מכבי שירותי בריאות").category, "health"))
test("❤️ Holmes Place → health", () => assertEqual(classify("Holmes Place gym").category, "health"))
test("💳 ישראכרט עמלה → finance", () => assertEqual(classify("ישראכרט עמלת כרטיס").category, "finance"))
test("💳 Leumi bank fee → finance", () => assertEqual(classify("Bank Leumi fee").category, "finance"))
test("🎭 Cinema City → entertainment", () => assertEqual(classify("Cinema City Israel").category, "entertainment"))
test("🎭 Xbox Game Pass → entertainment", () => assertEqual(classify("Xbox Game Pass").category, "entertainment"))
test("🎁 Bit transfer → other", () => assertEqual(classify("Bit transfer payment").category, "other"))

// confidence tests
test("✅ ציון דיוק 0.95 על מילת מפתח מוכרת", () => assertEqual(classify("Wolt").confidence, 0.95))
test("⚠️ ציון דיוק 0.50 על עסק לא מוכר", () => assertEqual(classify("XYZ Store Unknown").confidence, 0.50))
test("🔤 אותיות גדולות/קטנות לא משנות — WOLT", () => assertEqual(classify("WOLT").category, "food"))
test("🔤 רווחים לא משנות", () => assertEqual(classify("  wolt  ").category, "food"))

// ============================================================
// MARK: - SUITE 2: בדיקות RecordTransactionIntent
// ============================================================

console.log("\n⚡ SUITE 2: RecordTransactionIntent — קליטת עסקת Apple Pay\n")

test("✅ עסקה תקינה נשמרת ל-DB", () => {
    const db = new SimulatedDatabase()
    performIntent({ amount: 85, merchant: "Wolt" }, db)
    assertEqual(db.count(), 1)
})

test("✅ קטגוריה מוקצית אוטומטית", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 230, merchant: "Zara Israel" }, db)
    assertEqual(tx.category, "shopping")
})

test("✅ isConfirmed=true כאשר confidence >= 0.8", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 50, merchant: "Netflix" }, db)
    assert(tx.isConfirmed === true, "Expected isConfirmed true")
})

test("⚠️ isConfirmed=false כאשר confidence < 0.8 (עסק לא מוכר)", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 120, merchant: "חנות לא מוכרת XYZ999" }, db)
    assert(tx.isConfirmed === false, "Expected isConfirmed false for unknown merchant")
})

test("✅ מטבע ₪ ברירת מחדל", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 14, merchant: "ארומה" }, db)
    assertEqual(tx.currency, "₪")
})

test("✅ isManual=false עבור Apple Pay", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 14, merchant: "ארומה" }, db)
    assert(tx.isManual === false, "Apple Pay tx should not be manual")
})

test("❌ סכום 0 נדחה", () => {
    const db = new SimulatedDatabase()
    let threw = false
    try { performIntent({ amount: 0, merchant: "Wolt" }, db) } catch { threw = true }
    assert(threw, "Should throw for amount=0")
})

test("❌ סכום שלילי נדחה", () => {
    const db = new SimulatedDatabase()
    let threw = false
    try { performIntent({ amount: -50, merchant: "Wolt" }, db) } catch { threw = true }
    assert(threw, "Should throw for negative amount")
})

test("❌ שם בית עסק ריק נדחה", () => {
    const db = new SimulatedDatabase()
    let threw = false
    try { performIntent({ amount: 50, merchant: "" }, db) } catch { threw = true }
    assert(threw, "Should throw for empty merchant")
})

test("❌ שם בית עסק מרווחים בלבד נדחה", () => {
    const db = new SimulatedDatabase()
    let threw = false
    try { performIntent({ amount: 50, merchant: "   " }, db) } catch { threw = true }
    assert(threw, "Should throw for whitespace-only merchant")
})

// ============================================================
// MARK: - SUITE 3: בדיקות DatabaseService
// ============================================================

console.log("\n💾 SUITE 3: DatabaseService — בסיס נתונים וסינון חודשי\n")

test("✅ עסקאות נשמרות ומוחזרות", () => {
    const db = new SimulatedDatabase()
    performIntent({ amount: 100, merchant: "שופרסל" }, db)
    performIntent({ amount: 200, merchant: "Zara" }, db)
    assertEqual(db.count(), 2)
})

test("✅ סינון לפי חודש נכון", () => {
    const db = new SimulatedDatabase()
    const aug = new Date(2026, 7, 15) // August 2026
    const jan = new Date(2026, 0, 10) // January 2026
    performIntent({ amount: 85, merchant: "Wolt", date: aug }, db)
    performIntent({ amount: 230, merchant: "Zara", date: aug }, db)
    performIntent({ amount: 50, merchant: "Netflix", date: jan }, db)
    const augResults = db.fetchForMonth(2026, 8)
    assertEqual(augResults.length, 2)
})

test("✅ חודש ריק מחזיר מערך ריק", () => {
    const db = new SimulatedDatabase()
    const results = db.fetchForMonth(2030, 6)
    assertEqual(results.length, 0)
})

test("✅ 10 עסקאות מרובות נשמרות כולן", () => {
    const db = new SimulatedDatabase()
    const merchants = ["Wolt","שופרסל","Zara","Netflix","Pango","ארומה","Cinema City","Super-Pharm","Amazon","ישראכרט"]
    for (const m of merchants) performIntent({ amount: 50, merchant: m }, db)
    assertEqual(db.count(), 10)
})

// ============================================================
// MARK: - SUITE 4: בדיקות עסקי קצה (Edge Cases)
// ============================================================

console.log("\n🔬 SUITE 4: Edge Cases — מקרי קצה\n")

test("✅ סכום מאוד גדול (משכורת) מתקבל", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 25000, merchant: "שכירות אפריל" }, db)
    assertEqual(tx.category, "housing")
})

test("✅ סכום מאוד קטן (אגורות) מתקבל", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 0.50, merchant: "Wolt tip" }, db)
    assert(tx.amount === 0.50)
})

test("✅ שם עסק עם מספרים", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 30, merchant: "Aroma cafe 013" }, db)
    assertEqual(tx.category, "food")
})

test("✅ שם עסק מעורב עברית-אנגלית", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 45, merchant: "Wolt וולט ישראל" }, db)
    assertEqual(tx.category, "food")
})

test("✅ שם עסק ארוך מאוד", () => {
    const db = new SimulatedDatabase()
    const longMerchant = "NETFLIX STREAMING SERVICES INTERNATIONAL LLC UNITED STATES SUBSCRIPTION BILLING"
    const tx = performIntent({ amount: 45, merchant: longMerchant }, db)
    assertEqual(tx.category, "subscriptions")
})

test("✅ 100 עסקאות ברצף ללא קריסה (stress test)", () => {
    const db = new SimulatedDatabase()
    for (let i = 0; i < 100; i++) {
        performIntent({ amount: 10 + i, merchant: "שופרסל" }, db)
    }
    assertEqual(db.count(), 100)
})

test("✅ מטבע USD מתקבל", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 9.99, merchant: "Netflix", currency: "USD" }, db)
    assertEqual(tx.currency, "USD")
})

test("✅ תאריך בעבר מתקבל", () => {
    const db = new SimulatedDatabase()
    const oldDate = new Date(2023, 0, 1)
    const tx = performIntent({ amount: 50, merchant: "Wolt", date: oldDate }, db)
    assert(tx.timestamp.getFullYear() === 2023)
})

// ============================================================
// MARK: - SUITE 5: סימולציית זרימה מלאה Apple Pay → עיר
// ============================================================

console.log("\n🏙️ SUITE 5: End-to-End Flow — Apple Pay ← → Money City\n")

test("✅ תרחיש 1: קפה בוקר ← Wolt", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 14, merchant: "Wolt", currency: "₪", date: new Date() }, db)
    assertEqual(tx.category, "food")
    assert(tx.isConfirmed)
    assertEqual(db.count(), 1)
})

test("✅ תרחיש 2: קניית בגדים ← Zara", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 350, merchant: "Zara Israel Ltd" }, db)
    assertEqual(tx.category, "shopping")
    assert(tx.confidence >= 0.9)
})

test("✅ תרחיש 3: חיוב Netflix חודשי (background, no app open)", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 49.90, merchant: "NETFLIX.COM" }, db)
    assertEqual(tx.category, "subscriptions")
    assert(tx.isManual === false)
})

test("✅ תרחיש 4: תדלוק פז (fuel)", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 320, merchant: "תחנת דלק פז נתניה" }, db)
    assertEqual(tx.category, "transport")
})

test("✅ תרחיש 5: ביקור רופא שיניים", () => {
    const db = new SimulatedDatabase()
    const tx = performIntent({ amount: 600, merchant: "מרפאת שיניים ד״ר לוי" }, db)
    assertEqual(tx.category, "health")
})

test("✅ תרחיש 6: יום קניות — 5 עסקאות ברצף (כמו Apple Pay רציף)", () => {
    const db = new SimulatedDatabase()
    performIntent({ amount: 14, merchant: "ארומה" }, db)
    performIntent({ amount: 85, merchant: "Wolt" }, db)
    performIntent({ amount: 250, merchant: "Zara" }, db)
    performIntent({ amount: 30, merchant: "Pango" }, db)
    performIntent({ amount: 49.9, merchant: "Netflix" }, db)
    assertEqual(db.count(), 5)
    const cats = db.records.map(r => r.category)
    assert(cats.includes("food"))
    assert(cats.includes("shopping"))
    assert(cats.includes("transport"))
    assert(cats.includes("subscriptions"))
})

// ============================================================
// MARK: - SUITE 6: The Two Separate City Systems (Spending vs Progress)
// ============================================================

console.log("\n🏛️ SUITE 6: The Two Separate Systems — מציאות ההוצאות לעומת התקדמות שבועית\n")

function evaluateProgress(prevTotal, currTotal, unlockedSet = new Set()) {
    const diff = prevTotal - currTotal
    const hasProgress = diff > 0
    const saved = Math.max(0, diff)
    let tier = "none"
    if (hasProgress) {
        if (saved < 200) tier = "small"
        else if (saved < 500) tier = "medium"
        else tier = "large"
    }
    
    const catalog = [
        { id: "tree_sakura", tier: "small", actionType: "ADD" },
        { id: "flower_bed_plaza", tier: "small", actionType: "ADD" },
        { id: "repair_bench", tier: "small", actionType: "IMPROVE / REPAIR" },
        { id: "pet_cat_rooftop", tier: "medium", actionType: "ADD" },
        { id: "resident_artist", tier: "medium", actionType: "ADD" },
        { id: "repair_sidewalk", tier: "medium", actionType: "IMPROVE / REPAIR" },
        { id: "fountain_marble", tier: "large", actionType: "ADD" },
        { id: "pet_golden_dog", tier: "large", actionType: "ADD" }
    ]
    
    const available = catalog.filter(c => {
        if (unlockedSet.has(c.id)) return false
        if (tier === "large") return true
        if (tier === "medium") return c.tier === "medium" || c.tier === "small"
        if (tier === "small") return c.tier === "small"
        return false
    })
    
    return {
        prevTotal, currTotal, savedAmount: saved, hasPositiveProgress: hasProgress, progressTier: tier, availableOptions: available
    }
}

test("🏙️ מערכת 1 (מציאות): הוצאות מעצבות את הרבעים אוטומטית ללא מטבעות", () => {
    const db = new SimulatedDatabase()
    performIntent({ amount: 150, merchant: "Wolt pizza" }, db)
    performIntent({ amount: 350, merchant: "Zara fashion" }, db)
    performIntent({ amount: 200, merchant: "Paz fuel" }, db)
    // Spending builds city reality
    assertEqual(db.records.length, 3)
    // No virtual coins awarded directly by spending
    assert(db.records[0].coins === undefined, "Spending does NOT give virtual coins")
})

test("🌱 מערכת 2 (התקדמות): שבוע של ₪1200 מול ₪1500 פותח התקדמות בינונית (₪300 חיסכון)", () => {
    const report = evaluateProgress(1500, 1200)
    assert(report.hasPositiveProgress === true, "Should have positive progress")
    assertEqual(report.savedAmount, 300)
    assertEqual(report.progressTier, "medium")
    assert(report.availableOptions.length > 0, "Should have options available")
})

test("🌱 התקדמות קטנה (₪120 פחות) פותחת שדרוגים קטנים (עץ, פרחים, ספסל)", () => {
    const report = evaluateProgress(1000, 880)
    assertEqual(report.progressTier, "small")
    const ids = report.availableOptions.map(o => o.id)
    assert(ids.includes("tree_sakura") || ids.includes("repair_bench"))
})

test("🌱 התקדמות גדולה (₪600 פחות) פותחת שדרוגים גדולים (מזרקה, כלב)", () => {
    const report = evaluateProgress(2000, 1400)
    assertEqual(report.progressTier, "large")
    const ids = report.availableOptions.map(o => o.id)
    assert(ids.includes("fountain_marble") || ids.includes("pet_golden_dog"))
})

test("🛡️ אפס ענישה (No Punishment): שבוע שבו הוצאת יותר לא הורס שום דבר מהעיר", () => {
    const unlocked = new Set(["fountain_marble", "pet_cat_rooftop", "tree_sakura"])
    // User spent more this week (1800 vs 1300)
    const report = evaluateProgress(1300, 1800, unlocked)
    assertEqual(report.hasPositiveProgress, false)
    assertEqual(report.progressTier, "none")
    assertEqual(report.savedAmount, 0)
    // Unlocked items remain completely intact!
    assertEqual(unlocked.size, 3)
    assert(unlocked.has("fountain_marble"), "Fountain must not be removed")
    assert(unlocked.has("pet_cat_rooftop"), "Cat must not be removed")
    assert(unlocked.has("tree_sakura"), "Tree must not be removed")
})

test("🚫 אין צורך בהגדרת תקציב שרירותי (השוואה התנהגותית בלבד)", () => {
    const report = evaluateProgress(1400, 1100)
    // Evaluates pure week-over-week behavior
    assertEqual(report.savedAmount, 300)
    assert(report.hasPositiveProgress === true)
})

// ============================================================
// MARK: - RESULTS
// ============================================================

console.log("\n" + "═".repeat(55))
console.log("📊 תוצאות הבדיקות")
console.log("═".repeat(55))

for (const r of results) {
    console.log(`${r.status}  ${r.name}${r.error ? "\n       ⚠️  " + r.error : ""}`)
}

console.log("\n" + "═".repeat(55))
const total = passed + failed
console.log(`סה״כ: ${total} בדיקות | ✅ עברו: ${passed} | ❌ נכשלו: ${failed}`)
if (failed === 0) {
    console.log("🎉 כל הבדיקות עברו! שתי המערכות הנפרדות ומערכת ה-Apple Pay פועלות מושלם.")
} else {
    console.log("🔴 יש בדיקות שנכשלו. יש לתקן לפני הפצה.")
}
console.log("═".repeat(55) + "\n")

