import Foundation
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Result of scanning and parsing a payment confirmation screenshot or receipt.
public struct ReceiptScanResult: Sendable, Equatable {
    public let amount: Double
    public let merchant: String
    public let date: Date?
    public let category: SpendingCategory
    public let buildingId: String
    public let confidence: Double
    public let rawText: String

    public init(
        amount: Double,
        merchant: String,
        date: Date?,
        category: SpendingCategory,
        buildingId: String,
        confidence: Double,
        rawText: String
    ) {
        self.amount = amount
        self.merchant = merchant
        self.date = date
        self.category = category
        self.buildingId = buildingId
        self.confidence = confidence
        self.rawText = rawText
    }
}

/// Advanced On-Device Apple Vision OCR service tailored for Israeli payment screens, Bit & PayBox transfers,
/// Wolt receipts, supermarket bills, credit card notifications, and printed store invoices.
public enum ReceiptOCRService {

    public enum OCRError: LocalizedError {
        case imageProcessingFailed
        case noTextFound
        case parsingFailed

        public var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Failed to process the receipt image."
            case .noTextFound:
                return "No readable text was found in the image."
            case .parsingFailed:
                return "Could not detect a valid amount or merchant in the receipt."
            }
        }
    }

    /// Scans an image payload (JPEG/PNG/HEIC data), performs on-device OCR, and extracts payment details.
    public static func scanImage(data: Data, rules: [MerchantRule] = []) async throws -> ReceiptScanResult {
        let recognizedLines = try await recognizeTextLines(from: data)
        guard !recognizedLines.isEmpty else {
            throw OCRError.noTextFound
        }

        guard let result = parseReceipt(from: recognizedLines, rules: rules) else {
            throw OCRError.parsingFailed
        }

        return result
    }

    /// Performs Apple Vision OCR recognition on image data with Hebrew and English language support,
    /// spatially ordered from top to bottom.
    public static func recognizeTextLines(from data: Data) async throws -> [String] {
        #if canImport(Vision) && canImport(CoreGraphics)
        return try await withCheckedThrowingContinuation { continuation in
            // perform() invokes the request completion with the error *and* throws, so without a
            // latch a corrupt image resumes the continuation twice and traps the process.
            let resumed = OCRResumeLatch()
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    if resumed.claim() { continuation.resume(throwing: error) }
                    return
                }

                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    if resumed.claim() { continuation.resume(returning: []) }
                    return
                }

                // Sort spatially from top to bottom (Y descending), then left to right (X ascending)
                let sortedObs = observations.sorted { a, b in
                    if abs(a.boundingBox.origin.y - b.boundingBox.origin.y) > 0.02 {
                        return a.boundingBox.origin.y > b.boundingBox.origin.y
                    }
                    return a.boundingBox.origin.x < b.boundingBox.origin.x
                }

                let lines = sortedObs.compactMap { obs -> String? in
                    obs.topCandidates(1).first?.string
                }
                if resumed.claim() { continuation.resume(returning: lines) }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["he-IL", "en-US"]

            let handler = VNImageRequestHandler(data: data, options: [:])
            do {
                try handler.perform([request])
            } catch {
                if resumed.claim() { continuation.resume(throwing: error) }
            }
        }
        #else
        return []
        #endif
    }

    /// Parses raw recognized lines into structured transaction details.
    public static func parseReceipt(from lines: [String], rules: [MerchantRule] = []) -> ReceiptScanResult? {
        let cleanedLines = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedLines.isEmpty else { return nil }
        let fullText = cleanedLines.joined(separator: "\n")

        // 1. Extract Amount via Multi-Tier Weighted Scoring
        guard let extractedAmount = extractAmount(from: cleanedLines) else {
            return nil
        }

        // 2. Extract Merchant via Regex & Domain Knowledge
        let extractedMerchant = extractMerchant(from: cleanedLines) ?? "הוצאה מצילום מסך"

        // 3. Extract Date
        let extractedDate = extractDate(from: cleanedLines)

        // 4. Categorize with Learned Rules & Categorization Engine
        let classification = MerchantRuleService.classify(
            merchant: extractedMerchant,
            amount: extractedAmount,
            rules: rules
        )

        return ReceiptScanResult(
            amount: extractedAmount,
            merchant: extractedMerchant,
            date: extractedDate,
            category: classification.category,
            buildingId: classification.buildingId,
            confidence: classification.confidence,
            rawText: fullText
        )
    }

    // MARK: - Amount Extraction

    private struct AmountCandidate {
        let value: Double
        let lineIndex: Int
        let score: Int
    }

    /// Identifies the grand total / charged amount using a multi-factor scoring model.
    public static func extractAmount(from lines: [String]) -> Double? {
        var candidates: [AmountCandidate] = []

        // Primary total keywords (highest confidence)
        let primaryTotalKeywords = [
            "סה\"כ לתשלום", "סה״כ לתשלום", "סך הכל לתשלום", "סך-הכל לתשלום",
            "סך הכל", "סה\"כ", "סה״כ", "סך-הכל", "סהכ",
            "סכום לתשלום", "סכום החיוב", "סכום העסקה", "סכום שחויב", "סכום ההעברה",
            "סכום סופי", "סך לתשלום", "לתשלום", "חויב", "חוייב", "חויבת בסך",
            "total amount", "grand total", "amount paid", "amount due",
            "total paid", "total due", "charged", "total"
        ]

        // Secondary payment keywords
        let secondaryPaymentKeywords = [
            "אשראי", "כרטיס", "שולם ב-", "שולם באמצעות", "העברת", "סכום",
            "ע\"ס", "ע״ס", "בסך", "בסכום", "paid with", "visa", "mastercard"
        ]

        // Negative keywords that penalize the candidate
        let negativeKeywords = [
            "הנחה", "discount", "מע\"מ", "מע״מ", "מעמ", "vat", "tax",
            "דמי משלוח", "משלוח", "delivery", "טיפ", "tip",
            "סכום ביניים", "ביניים", "subtotal",
            "עודף", "change", "יתרה", "balance",
            "מספר אישור", "אישור", "קוד אישור", "מספר קופה", "קופה",
            "צברת", "נקודות", "מועדון", "מועדון לקוחות"
        ]

        for (idx, line) in lines.enumerated() {
            let lower = line.lowercased()

            // Skip lines that are purely metadata / card last digits / phone numbers / dates
            if isNoiseLine(lower) {
                continue
            }

            // Extract numeric values from line
            let numbers = extractNumbersFromLine(line)
            guard !numbers.isEmpty else { continue }

            var lineScore = 0

            // Check primary keywords on same line
            if primaryTotalKeywords.contains(where: { lower.contains($0) }) {
                lineScore += 200
            } else if secondaryPaymentKeywords.contains(where: { lower.contains($0) }) {
                lineScore += 90
            }

            // Check if adjacent line (above or below) contains total keyword
            if idx > 0 {
                let prevLower = lines[idx - 1].lowercased()
                if primaryTotalKeywords.contains(where: { prevLower.contains($0) }) {
                    lineScore += 160
                }
            }
            if idx < lines.count - 1 {
                let nextLower = lines[idx + 1].lowercased()
                if primaryTotalKeywords.contains(where: { nextLower.contains($0) }) {
                    lineScore += 140
                }
            }

            // Currency symbol presence
            if lower.contains("₪") || lower.contains("ש״ח") || lower.contains("ש\"ח") || lower.contains("שח") || lower.contains("ils") || lower.contains("nis") || lower.contains("$") || lower.contains("€") {
                lineScore += 70
            }

            // Position weighting: Totals are usually in the lower 60% of lines on receipts
            let positionFraction = Double(idx) / Double(max(lines.count, 1))
            if positionFraction >= 0.35 {
                lineScore += Int(positionFraction * 40)
            }

            // Negative keyword penalties
            if negativeKeywords.contains(where: { lower.contains($0) }) {
                lineScore -= 120
            }

            for num in numbers {
                var candidateScore = lineScore

                // Penalize integers > 5000 that have no currency symbol (often loyalty points / barcodes / IDs)
                if num.truncatingRemainder(dividingBy: 1) == 0 && num > 4000 && !lower.contains("₪") && !lower.contains("ש״ח") {
                    candidateScore -= 150
                }

                // Reasonable transaction range bonus (₪5 to ₪25,000)
                if num >= 5 && num <= 25_000 {
                    candidateScore += 20
                }

                candidates.append(AmountCandidate(value: num, lineIndex: idx, score: candidateScore))
            }
        }

        // Return candidate with the highest score
        guard let bestCandidate = candidates.max(by: { $0.score < $1.score }), bestCandidate.score > 20 else {
            // Fallback: Check lines with currency symbols
            for line in lines.reversed() {
                let lower = line.lowercased()
                if (lower.contains("₪") || lower.contains("ש״ח") || lower.contains("ש\"ח")) && !isNoiseLine(lower) {
                    if let val = extractNumbersFromLine(line).last {
                        return val
                    }
                }
            }
            return nil
        }

        return bestCandidate.value
    }

    private static func isNoiseLine(_ lower: String) -> Bool {
        // Discard phone numbers
        if lower.contains("טלפון") || lower.contains("פקס") || lower.contains("phone") || lower.contains("tel:") {
            return true
        }
        // Discard pure date/time lines
        if lower.range(of: #"^\s*(?:\d{1,2}[./\-]\d{1,2}[./\-]\d{2,4}|\d{1,2}:\d{2}(?::\d{2})?)\s*$"#, options: .regularExpression) != nil {
            return true
        }
        // Discard card last 4 digits patterns like "XXXX-1234"
        if lower.range(of: #"[x*]{3,}\s*[-]?\s*\d{4}"#, options: .regularExpression) != nil && !lower.contains("סה") && !lower.contains("סך") {
            return true
        }
        return false
    }

    private static func extractNumbersFromLine(_ text: String) -> [Double] {
        // Matches numbers like "140.00", "140,00", "1,450.50", "32.90", "140".
        //
        // The comma group is `+`, not `*`, and that is the whole point. With `*` the first
        // alternative matched any 1-3 digits on its own, and since alternation is
        // leftmost-first it always won before the second alternative was ever tried — so
        // "1450.50" came back as 145 (and then 0.50), "3200.00" as 320, "8500" as 850.
        // Every scanned receipt over ₪999 without a thousands comma — which is nearly all
        // of them, OCR rarely produces one — was silently divided by ten and still looked
        // like a plausible amount. Requiring at least one ",ddd" group means the first
        // alternative only claims genuinely grouped numbers and everything else falls
        // through to the second, which takes the digit run whole.
        let pattern = #"(?:₪|\$|€|ILS|NIS)?\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        var results: [Double] = []
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            var raw = nsString.substring(with: match.range(at: 1))
            // Remove thousands separators if followed by 3 digits
            if raw.contains(",") && raw.contains(".") {
                raw = raw.replacingOccurrences(of: ",", with: "")
            } else if raw.contains(",") {
                // If comma is used as decimal (e.g. 140,50)
                let parts = raw.split(separator: ",")
                if parts.count == 2 && parts[1].count <= 2 {
                    raw = raw.replacingOccurrences(of: ",", with: ".")
                } else {
                    raw = raw.replacingOccurrences(of: ",", with: "")
                }
            }

            if let val = Double(raw), val > 0, val < 500_000 {
                results.append(val)
            }
        }
        return results
    }

    // MARK: - Merchant Extraction

    /// Discovers the merchant or recipient name from the receipt text using regex, bank patterns, and knowledge base.
    public static func extractMerchant(from lines: [String]) -> String? {
        let genericBoilerplate = [
            "חשבונית מס", "חשבונית עסקה", "קבלה", "מקור", "העתק", "אישור תשלום",
            "פרטי העסקה", "סיכום הזמנה", "פרטי תשלום", "תודה שקניתם", "ברוכים הבאים",
            "מספר עוסק", "ח.פ", "ע.מ", "טלפון", "פקס", "כתובת", "תאריך", "שעה",
            "כרטיס אשראי", "מספר אישור", "סך הכל", "תשלומים", "receipt", "invoice",
            "tax invoice", "payment confirmation", "order summary", "thank you",
            "הודעה מאת", "אושרה בתאריך", "כרטיס מסתיים", "בכרטיס", "עסקה חדשה"
        ]

        let fullText = lines.joined(separator: "\n")

        // 1. Check for Bit / PayBox transfer pattern
        for line in lines {
            if let range = line.range(of: #"(?:העברת ל|העברה ל|העברה אל|שילמת ל|שולם ל)\s*([^\d\n\r,.:;]+)"#, options: .regularExpression) {
                let match = String(line[range])
                    .replacingOccurrences(of: #"^(?:העברת ל|העברה ל|העברה אל|שילמת ל|שולם ל)\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if match.count >= 2 {
                    return match
                }
            }
        }

        // 2. Check for Israeli Bank / Card SMS patterns
        let smsPatterns = [
            #"(?:עסקתך ב-|עסקה ב-|רכשת ב-|שילמת ב-|חיוב מ-|הזמנה מ-|הזמנה ב-|חויבת ב-)\s*([^\d\n\r,;]{2,30}?)(?:\s+ע[״\"][ס|ש]|\s+בסך|\s+בסכום|\s+בכרטיס|\s+באמצעות|\s+בתאריך|\s+ב-|\s+₪|\s+\d|$)"#,
            #"(?:ב-|מ-)([A-Za-z0-9א-ת\s\-&']{2,25}?)(?:\s+ע[״\"][ס|ש]|\s+בסך|\s+על סך|\s+בסכום)"#
        ]

        for pattern in smsPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                for line in lines {
                    let ns = line as NSString
                    if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges > 1 {
                        let extracted = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                        if extracted.count >= 2 && !genericBoilerplate.contains(where: { extracted.lowercased().contains($0) }) {
                            return normalizeMerchantName(extracted)
                        }
                    }
                }
            }
        }

        // 3. Check for Known Israeli & Global Merchants anywhere in receipt
        if let known = matchKnownMerchant(in: fullText) {
            return known
        }

        // 4. Header inspection: take the first clean non-boilerplate line from top 6 lines
        for line in lines.prefix(6) {
            let lower = line.lowercased()
            let isBoilerplate = genericBoilerplate.contains { lower.contains($0) }
            if !isBoilerplate && line.contains(where: { $0.isLetter }) {
                let cleaned = TransactionIngest.nameWithoutAmount(line) ?? line
                let candidate = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n-–—,.·:;|/\\\"'״׳*#0123456789"))
                if candidate.count >= 2 && !genericBoilerplate.contains(where: { candidate.lowercased().contains($0) }) {
                    return candidate
                }
            }
        }

        return nil
    }

    private static func matchKnownMerchant(in text: String) -> String? {
        let lower = text.lowercased()

        let dictionary: [(key: String, name: String)] = [
            // Supermarkets & Groceries
            ("שופרסל", "שופרסל"),
            ("רמי לוי", "רמי לוי"),
            ("ויקטורי", "ויקטורי"),
            ("יוחננוף", "יוחננוף"),
            ("אושר עד", "אושר עד"),
            ("טיב טעם", "טיב טעם"),
            ("חצי חינם", "חצי חינם"),
            ("מחסני השוק", "מחסני השוק"),
            ("am:pm", "AM:PM"),
            ("ampm", "AM:PM"),
            ("סופר יודה", "סופר יודה"),
            ("קארפור", "Carrefour"),
            ("carrefour", "Carrefour"),
            ("מגה בעיר", "מגה בעיר"),
            ("שוק העיר", "שוק העיר"),
            ("מעדני מזרע", "מעדני מזרע"),

            // Delivery & Dining
            ("wolt", "Wolt"),
            ("וולט", "Wolt"),
            ("10bis", "10bis תן ביס"),
            ("תן ביס", "10bis תן ביס"),
            ("cibus", "Cibus סיבוס"),
            ("סיבוס", "Cibus סיבוס"),
            ("מקדונלד", "מקדונלד'ס"),
            ("mcdonald", "McDonald's"),
            ("ארומה", "ארומה"),
            ("aroma", "ארומה"),
            ("קפה גרג", "קפה גרג"),
            ("לנדוור", "קפה לנדוור"),
            ("קפה קפה", "קפה קפה"),
            ("ארקפה", "ארקפה"),
            ("arcaffe", "ארקפה"),
            ("רולדין", "רולדין"),
            ("roladin", "רולדין"),
            ("גולדה", "גולדה"),
            ("golda", "גולדה"),
            ("rebar", "rebar ריבר"),
            ("ריבר", "rebar ריבר"),
            ("bbb", "BBB"),
            ("מוזס", "מוזס"),
            ("moses", "מוזס"),
            ("אגאדיר", "אגאדיר"),
            ("agadir", "אגאדיר"),
            ("ג'פניקה", "ג'פניקה"),
            ("japanika", "ג'פניקה"),
            ("דומינוס", "דומינו'ס פיצה"),
            ("domino", "Domino's Pizza"),
            ("פיצה האט", "פיצה האט"),
            ("pizza hut", "Pizza Hut"),

            // Pharmacies & Health
            ("סופר-פארם", "סופר-פארם"),
            ("סופר פארם", "סופר-פארם"),
            ("סופרפארם", "סופר-פארם"),
            ("super-pharm", "Super-Pharm"),
            ("super pharm", "Super-Pharm"),
            ("superpharm", "Super-Pharm"),
            ("be פארם", "Be"),
            ("ניו פארם", "Be"),
            ("כללית", "שירותי בריאות כללית"),
            ("מכבי", "מכבי שירותי בריאות"),

            // Shopping, Fashion & Home
            ("zara", "ZARA"),
            ("זארה", "ZARA"),
            ("h&m", "H&M"),
            ("pull&bear", "Pull&Bear"),
            ("bershka", "Bershka"),
            ("mango", "Mango"),
            ("מנגו", "Mango"),
            ("קסטרו", "קסטרו"),
            ("castro", "קסטרו"),
            ("פוקס", "FOX"),
            ("fox", "FOX"),
            ("טרמינל איקס", "Terminal X"),
            ("terminal x", "Terminal X"),
            ("asos", "ASOS"),
            ("אסוס", "ASOS"),
            ("shein", "SHEIN"),
            ("שיין", "SHEIN"),
            ("amazon", "Amazon"),
            ("אמזון", "Amazon"),
            ("אמאזון", "Amazon"),
            ("aliexpress", "AliExpress"),
            ("עלי אקספרס", "AliExpress"),
            ("איקאה", "IKEA"),
            ("ikea", "IKEA"),
            ("אייס", "ACE"),
            ("ace", "ACE"),
            ("הום סנטר", "הום סנטר"),
            ("home center", "הום סנטר"),
            ("דקטלון", "Decathlon"),
            ("decathlon", "Decathlon"),
            ("פקטורי 54", "Factory 54"),
            ("factory 54", "Factory 54"),
            ("נייקי", "Nike"),
            ("nike", "Nike"),
            ("אדידס", "Adidas"),
            ("adidas", "Adidas"),

            // Tech & Electronics
            ("ksp", "KSP"),
            ("קיי אס פי", "KSP"),
            ("אייבורי", "אייבורי מחשבים"),
            ("ivory", "אייבורי מחשבים"),
            ("באג", "BUG"),
            ("bug", "BUG"),
            ("מחסני חשמל", "מחסני חשמל"),
            ("שקם אלקטריק", "שקם אלקטריק"),
            ("idigital", "iDigital"),
            ("אידיגיטל", "iDigital"),
            ("istore", "iStore"),
            ("apple.com", "Apple"),

            // Fuel & Transportation
            ("פז", "פז"),
            ("סונול", "סונול"),
            ("דלק", "דלק"),
            ("דור אלון", "דור אלון"),
            ("dor alon", "דור אלון"),
            ("yellow", "Yellow פז"),
            ("ילו", "Yellow פז"),
            ("טן", "Ten"),
            ("סוגוד", "Sogood סונול"),
            ("פנגו", "פנגו Pango"),
            ("pango", "פנגו Pango"),
            ("סלו", "Cello"),
            ("cello", "Cello"),
            ("רב קו", "רב-קו"),
            ("rav-kav", "רב-קו"),
            ("moovit", "Moovit"),
            ("מוביט", "Moovit"),
            ("רכבת ישראל", "רכבת ישראל"),
            ("israel railways", "רכבת ישראל"),
            ("אגד", "אגד"),
            ("egged", "אגד"),
            ("דן", "דן תחבורה"),
            ("gett", "Gett"),
            ("גט", "Gett"),
            ("yango", "Yango"),
            ("יאנגו", "Yango"),

            // Subscriptions & Utilities
            ("netflix", "Netflix"),
            ("נטפליקס", "Netflix"),
            ("spotify", "Spotify"),
            ("ספוטיפיי", "Spotify"),
            ("youtube", "YouTube"),
            ("disney+", "Disney+"),
            ("דיסני", "Disney+"),
            ("הוט", "HOT"),
            ("hot", "HOT"),
            ("יס", "YES"),
            ("yes", "YES"),
            ("פרטנר", "Partner"),
            ("partner", "Partner"),
            ("סלקום", "Cellcom"),
            ("cellcom", "Cellcom"),
            ("פלאפון", "Pelephone"),
            ("pelephone", "Pelephone"),
            ("בזק", "בזק"),
            ("bezeq", "בזק"),
            ("חברת החשמל", "חברת החשמל"),
            ("מי אביבים", "מי אביבים"),
            ("ארנונה", "עירייה - ארנונה")
        ]

        // Longest key first, so a specific entry is not stolen by a shorter one that
        // happens to sit higher in the table.
        for (key, display) in dictionary.sorted(by: { $0.0.count > $1.0.count }) {
            if containsMerchantToken(lower, key: key) {
                return display
            }
        }

        return nil
    }

    /// Whether `key` appears as a standalone token rather than inside a longer word.
    ///
    /// The table holds keys as short as two Hebrew letters — "יס" for YES, "דן", "גט" —
    /// and a plain `contains` over the entire receipt text made them match almost anything.
    /// "כרטיס אשראי" appears on essentially every Israeli card slip and contains "יס", so
    /// receipt after receipt was filed under a TV provider. That is worse than a wrong
    /// label: the merchant name is what MerchantRuleService keys its learned rules on, so
    /// one user correction taught a rule that mislabelled every future scan the same way.
    private static func containsMerchantToken(_ text: String, key: String) -> Bool {
        // Long, distinctive keys stay plain substrings — that is what lets them survive
        // Hebrew prefixes like "בסופרפארם". Short keys have to stand on their own.
        if key.count >= 4 { return text.contains(key) }
        let escaped = NSRegularExpression.escapedPattern(for: key)
        let bounded = "(?<![\\p{L}\\p{N}])" + escaped + "(?![\\p{L}\\p{N}])"
        return text.range(of: bounded, options: .regularExpression) != nil
    }

    private static func normalizeMerchantName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n-–—,.·:;|/\\\"'״׳"))
        if let match = matchKnownMerchant(in: trimmed) {
            return match
        }
        return trimmed
    }

    // MARK: - Date Extraction

    /// Extracts date from receipt text lines if available.
    public static func extractDate(from lines: [String]) -> Date? {
        let datePatterns = [
            #"[0-3]?[0-9][./\-][0-1]?[0-9][./\-](?:20)?[0-9]{2}"#,
            #"[0-9]{4}[./\-][0-1]?[0-9][./\-][0-3]?[0-9]"#
        ]

        let formats = [
            "dd/MM/yyyy", "dd.MM.yyyy", "dd-MM-yyyy",
            "dd/MM/yy", "dd.MM.yy", "dd-MM-yy",
            "yyyy-MM-dd", "yyyy/MM/dd"
        ]

        for line in lines {
            for pattern in datePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let nsString = line as NSString
                if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                    let dateStr = nsString.substring(with: match.range)
                    for fmt in formats {
                        let df = DateFormatter()
                        df.dateFormat = fmt
                        df.locale = Locale(identifier: "en_US_POSIX")
                        df.timeZone = TimeZone(secondsFromGMT: 0)
                        if let d = df.date(from: dateStr) {
                            return TransactionIngest.sanitizedDate(d)
                        }
                    }
                }
            }
        }

        return nil
    }
}

/// Guarantees a checked continuation is resumed exactly once. Vision can report a failure through
/// both the request completion and a thrown error for the same image.
private final class OCRResumeLatch {
    private let lock = NSLock()
    private var used = false

    /// Returns true exactly once, for the first caller.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
