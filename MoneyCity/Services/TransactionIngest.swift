import Foundation

/// Why an incoming Wallet transaction was rejected.
///
/// These are not theoretical. The Shortcuts "Transaction"/"Wallet" automation trigger has
/// two documented defects that reach a custom App Intent as garbage input:
///   1. merchant arrives as an empty string and amount as 0.0 (Apple developer forums, FB open)
///   2. the trigger also fires for *declined* transactions
/// Without these guards the app silently writes phantom ₪0 rows into the user's finances.
public enum TransactionIngestError: Error, Equatable {
    case missingMerchant
    case missingAmount
    case duplicate
}

/// Pure, testable ingestion logic shared by the App Intent and any future import path.
public enum TransactionIngest {

    /// Two identical payments inside this window are treated as one.
    /// A 15-second window prevents duplicate Shortcut automation fires without blocking rapid legitimate purchases.
    public static let duplicateWindow: TimeInterval = 15

    // MARK: - Amount parsing

    /// Recovers an amount from either the numeric parameter or its text fallback.
    ///
    /// The text fallback exists because Shortcuts intermittently delivers 0.0 for the
    /// `Double` parameter while the same transaction's text representation comes through
    /// intact. That text is not clean: it can carry a card suffix ("Visa 1234 - 45.90"),
    /// a refund sign, non-Latin digits, or grouping separators in either convention.
    ///
    /// The rule is deliberately conservative: when the text is genuinely ambiguous this
    /// returns nil so the caller refuses the payload, rather than guessing a number.
    /// A dropped transaction the user can re-enter beats a wrong one they never notice.
    public static func normalizedAmount(_ amount: Double?, _ amountText: String?) -> Double? {
        if let a = MoneyAmount.sanitized(amount) {
            return a
        }

        guard let raw = amountText else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // A credit or refund must never be booked as a charge.
        for marker in ["-", "\u{2212}", "\u{2013}", "("] where trimmed.hasPrefix(marker) {
            return nil
        }

        // Fold non-Latin decimal digits (Arabic-Indic, full-width) onto ASCII so a
        // perfectly valid amount is not thrown away for being written in another script.
        var folded = ""
        for ch in trimmed {
            if !ch.isASCII, ch.isNumber, let d = ch.wholeNumberValue, (0...9).contains(d) {
                folded.append(Character(String(d)))
            } else {
                folded.append(ch)
            }
        }

        // Collect every numeric run instead of deleting the characters between them —
        // deletion fuses a card suffix onto the amount ("Visa 1234 - 45.90" -> 123445.90).
        var tokens: [String] = []
        var cursor = folded.startIndex
        while cursor < folded.endIndex,
              let range = folded.range(
                of: "[0-9]+(?:[.,][0-9]+)+|[0-9]+",
                options: .regularExpression,
                range: cursor..<folded.endIndex
              ) {
            tokens.append(String(folded[range]))
            cursor = range.upperBound
        }
        guard !tokens.isEmpty else { return nil }

        // The amount is the one run carrying a separator. With no separator anywhere a
        // lone run is still unambiguous; anything else is a guess, so refuse it.
        let separated = tokens.filter { $0.contains(".") || $0.contains(",") }
        let token: String
        if separated.count == 1 {
            token = separated[0]
        } else if separated.isEmpty, tokens.count == 1 {
            token = tokens[0]
        } else {
            return nil
        }

        // The permissive text path is where "Kokpit 67" style noise arrives, so it gets the
        // same ceiling as every other entry point.
        guard let value = MoneyAmount.sanitized(parseGrouped(token)) else { return nil }
        return value
    }

    /// Resolves "." and "," into a decimal point, handling both grouping conventions.
    /// A separator followed by exactly one or two digits is a decimal point; three digits
    /// (or repeated separators) is thousands grouping — "1.850" is 1850, not 1.85.
    private static func parseGrouped(_ token: String) -> Double? {
        let hasDot = token.contains(".")
        let hasComma = token.contains(",")
        var cleaned = token

        if hasDot && hasComma {
            // Whichever appears last is the decimal separator; the other groups thousands.
            if token.lastIndex(of: ".")! > token.lastIndex(of: ",")! {
                cleaned = token.replacingOccurrences(of: ",", with: "")
            } else {
                cleaned = token
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            }
        } else if hasDot || hasComma {
            let separator: Character = hasDot ? "." : ","
            let parts = token.split(separator: separator, omittingEmptySubsequences: false)
            let isDecimal = parts.count == 2
                && (1...2).contains(parts[1].count)
                || (parts.count == 2 && parts[0] == "0")
            if isDecimal {
                cleaned = token.replacingOccurrences(of: String(separator), with: ".")
            } else {
                cleaned = token.replacingOccurrences(of: String(separator), with: "")
            }
        }

        return Double(cleaned)
    }

    // MARK: - Guarding against the wrong field

    /// Accepts a currency only if it actually looks like one.
    ///
    /// Shortcuts hands whatever is mapped to a field straight through, so mapping the
    /// transaction input to the currency parameter delivers the entire description —
    /// "Chacoli ₪6.00" — which would then be stored and rendered as the currency itself.
    /// A currency is a symbol or a three-letter code, and never contains digits.
    public static func sanitizedCurrency(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let sanitized = InputSanitizer.sanitizeSingleLine(raw, maxLength: InputSanitizer.maxCurrencyLength)
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4 else { return nil }
        guard !trimmed.contains(where: { $0.isNumber }) else { return nil }
        return trimmed
    }

    /// Rejects a timestamp that cannot belong to this payment.
    ///
    /// A coerced date can land a charge in the wrong month — or the wrong year — which
    /// quietly corrupts every monthly total. Anything outside a year either side of now
    /// is an artefact, not a purchase.
    public static func sanitizedDate(_ raw: Date?, now: Date = Date()) -> Date? {
        guard let raw else { return nil }
        let oneYear: TimeInterval = 400 * 24 * 60 * 60
        guard abs(raw.timeIntervalSince(now)) <= oneYear else { return nil }
        return raw
    }

    // MARK: - Salvage

    /// Everything the payload could yield, ignoring which field it was labelled as.
    public struct Salvaged: Sendable, Equatable {
        public let amount: Double?
        public let merchant: String?
        public let isRefund: Bool

        public init(amount: Double?, merchant: String?, isRefund: Bool = false) {
            self.amount = amount
            self.merchant = merchant
            self.isRefund = isRefund
        }
    }

    /// Recovers an amount and a merchant from whichever fields actually carry them.
    ///
    /// The Shortcuts automation does not reliably fill the field it is mapped to: the
    /// amount can arrive inside the merchant text, the merchant inside the amount text,
    /// or a field can arrive empty while another holds the whole description. Trusting the
    /// labels is what produced "no merchant received" while the Wallet notification on the
    /// same screen clearly showed one.
    public static func salvage(
        amount: Double?,
        amountText: String?,
        merchant: String?
    ) -> Salvaged {
        var isRefund = false
        if let a = amount, a < 0 {
            isRefund = true
        }
        for txt in [amountText, merchant] {
            if let raw = txt?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if raw.hasPrefix("-") || raw.hasPrefix("\u{2212}") || raw.hasPrefix("\u{2013}") || raw.hasPrefix("(")
                    || raw.localizedCaseInsensitiveContains("זיכוי") || raw.localizedCaseInsensitiveContains("החזר")
                    || raw.localizedCaseInsensitiveContains("refund") || raw.localizedCaseInsensitiveContains("credit") {
                    isRefund = true
                }
            }
        }

        // 0. Support structured JSON payloads (e.g. {"amount": 45.9, "merchant": "AM:PM"})
        for candidate in [merchant, amountText] {
            if let text = candidate, text.contains("{") && text.contains("}") {
                if let data = text.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let jsonAmount = (dict["amount"] as? Double)
                        ?? (dict["Amount"] as? Double)
                        ?? (dict["amount"] as? String).flatMap(Double.init)
                        ?? (dict["Amount"] as? String).flatMap(Double.init)
                    let jsonMerchant = (dict["merchant"] as? String)
                        ?? (dict["name"] as? String)
                        ?? (dict["Merchant"] as? String)
                        ?? (dict["Name"] as? String)
                    if jsonAmount != nil || jsonMerchant != nil {
                        let finalJsonAmt = jsonAmount.map { abs($0) }
                        let finalIsRefund = isRefund || (jsonAmount.map { $0 < 0 } ?? false)
                        return Salvaged(amount: finalJsonAmt, merchant: jsonMerchant, isRefund: finalIsRefund)
                    }
                }
            }
        }

        // The merchant field is only a last resort for the amount, and only when the text
        // actually looks like money. "Kokpit 67" is a shop with a number in its name, not a
        // ₪67 charge — guessing there would invent a wrong amount instead of asking.
        var recoveredAmount = normalizedAmount(amount, amountText)
        if recoveredAmount == nil && isRefund {
            if let a = amount, a < 0, a.isFinite {
                recoveredAmount = abs(a)
            } else if let raw = amountText?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let stripped = raw.trimmingCharacters(in: CharacterSet(charactersIn: "-–—() \t\n\u{2212}\u{2013}"))
                recoveredAmount = normalizedAmount(nil, stripped)
            }
        }

        if recoveredAmount == nil {
            recoveredAmount = amountLikeValue(in: merchant)
        }

        var recoveredMerchant = normalizedMerchant(merchant).flatMap(nameWithoutAmount)
        if recoveredMerchant == nil {
            recoveredMerchant = normalizedMerchant(amountText).flatMap(nameWithoutAmount)
        }

        return Salvaged(amount: recoveredAmount, merchant: recoveredMerchant, isRefund: isRefund)
    }

    /// An amount embedded in free text, accepted only when it is marked as money — by a
    /// currency symbol, Hebrew money term, or by decimal digits.
    public static func amountLikeValue(in text: String?) -> Double? {
        guard let text, !text.isEmpty else { return nil }

        let currencyKeywords = [
            "₪", "$", "€", "£", "ils", "usd", "eur", "gbp", "nis",
            "ש״ח", "ש\"ח", "שח", "שקלים", "שקל", "בסך", "ע״ס", "בסכום של"
        ]
        let lower = text.lowercased()
        let hasCurrencyMark = currencyKeywords.contains { lower.contains($0) }
        let hasDecimalRun = text.range(
            of: "[0-9]+[.,][0-9]{1,2}(?![0-9])",
            options: .regularExpression
        ) != nil

        guard hasCurrencyMark || hasDecimalRun else { return nil }
        
        if let direct = normalizedAmount(nil, text) {
            return direct
        }
        
        // Fallback: extract the first valid numeric run
        if let range = text.range(of: "[0-9]+(?:[.,][0-9]+)?", options: .regularExpression) {
            let numStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
            if let val = Double(numStr), val > 0 {
                return val
            }
        }
        
        return nil
    }

    /// Strips currency symbols, Hebrew currency terms, transaction prefixes, and amount runs while preserving digits in merchant names (e.g. "Kokpit 67 ₪115.00" yields "Kokpit 67").
    /// Returns nil when nothing but digits and punctuation was there to begin with.
    public static func nameWithoutAmount(_ text: String) -> String? {
        var stripped = text
        
        // Remove common transaction notification prefixes
        let prefixesToRemove = [
            "עסקה ב-", "עסקה ב", "רכישה ב-", "רכישה ב", "חיוב ב-", "חיוב ב",
            "תשלום ב-", "תשלום ב", "הודעת חיוב:", "חיוב כרטיס ב-",
            "Transaction at ", "Payment to ", "Purchase at ", "Transaction: ", "Payment: "
        ]
        for p in prefixesToRemove {
            if stripped.hasPrefix(p) {
                stripped = String(stripped.dropFirst(p.count))
            }
        }
        
        // Strip amounts accompanied by currency symbols or money keywords
        let amountWithCurrencyPatterns = [
            #"(?:₪|\$|€|£|ILS|USD|EUR|GBP|NIS|nis|ש״ח|ש"ח|שח|שקלים|שקל)\s*[0-9]+(?:[.,][0-9]{1,2})?"#,
            #"[0-9]+(?:[.,][0-9]{1,2})?\s*(?:₪|\$|€|£|ILS|USD|EUR|GBP|NIS|nis|ש״ח|ש"ח|שח|שקלים|שקל)"#,
            #"(?:בסך|ע״ס|סך)\s*[0-9]+(?:[.,][0-9]{1,2})?(?:\s*(?:₪|\$|€|£|ILS|USD|EUR|GBP|NIS|nis|ש״ח|ש"ח|שח|שקלים|שקל))?"#
        ]
        for pattern in amountWithCurrencyPatterns {
            stripped = stripped.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }

        // Strip standalone trailing or leading decimal currency amounts (e.g. " 50.00" or "42.90 ")
        stripped = stripped.replacingOccurrences(of: #"(?:^|[\s,\-–—])[0-9]+[.,][0-9]{2}(?=$|[\s,\-–—])"#, with: " ", options: .regularExpression)

        // Strip residual currency symbols and terms
        for symbol in ["₪", "$", "€", "£", "ILS", "USD", "EUR", "GBP", "NIS", "nis", "ש״ח", "ש\"ח", "שח", "שקלים", "שקל", "בסך", "ע״ס", "סך"] {
            stripped = stripped.replacingOccurrences(of: symbol, with: " ", options: .caseInsensitive)
        }
        stripped = stripped
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t\n-–—,.·:;|/\\"))
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")

        // A name needs at least one letter; "- ." is not a merchant.
        guard stripped.contains(where: { $0.isLetter }) else { return nil }

        // Israeli card notifications read "district, merchant" or "merchant, city, district"
        // keeping the whole string would make every shop share a district or city name.
        if stripped.contains(",") {
            let parts = stripped
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            let knownCities = [
                "גבעתיים", "תל אביב", "תל אביב-יפו", "תל-אביב", "רמת גן", "רמת-גן",
                "ירושלים", "חיפה", "ראשון לציון", "פתח תקווה", "הרצליה", "חולון",
                "בת ים", "נתניה", "כפר סבא", "רעננה", "הוד השרון", "אשדוד", "באר שבע",
                "מודיעין", "רחובות", "בני ברק", "רמת השרון", "קרית אונו"
            ]
            
            let nonLocationParts = parts.filter { part in
                let lower = part.lowercased()
                if lower.hasPrefix("מחוז") || lower.contains("מחוז ") { return false }
                if knownCities.contains(where: { lower == $0 || lower == "\($0)-יפו" }) { return false }
                return true
            }
            
            if let chosen = nonLocationParts.first(where: { $0.contains(where: { $0.isLetter }) }), !chosen.isEmpty {
                return chosen
            }

            let nonDistrict = parts.filter { part in
                let lower = part.lowercased()
                return !lower.hasPrefix("מחוז") && !lower.contains("מחוז ")
            }
            
            if let chosen = nonDistrict.first(where: { $0.contains(where: { $0.isLetter }) }), !chosen.isEmpty {
                return chosen
            }

            let tail = parts.last(where: { $0.contains(where: { $0.isLetter }) })
            if let tail, !tail.isEmpty { return tail }
        }

        return stripped
    }

    // MARK: - Merchant cleanup

    /// Cleans Wallet and Shortcuts merchant strings, stripping payment processor prefixes,
    /// Israeli district/location metadata, card headers, and trailing currency amounts.
    public static func normalizedMerchant(_ merchant: String?) -> String? {
        guard let raw = merchant else { return nil }
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // 1. If multi-line (e.g. "Isracard\nמחוז תל אביב, Chacoli, ₪ 6.00"), pick content lines
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if lines.count > 1 {
            // If first line is just the card company name, discard it
            let cardNames = ["isracard", "ישראכרט", "cal", "כאל", "max", "מקס", "visa", "mastercard", "apple pay", "ארנק", "wallet", "לאומי", "פועלים", "דיסקונט", "מזרחי"]
            if let first = lines.first, cardNames.contains(first.lowercased()) {
                text = lines.dropFirst().joined(separator: ", ")
            } else {
                text = lines.joined(separator: ", ")
            }
        }
        text = InputSanitizer.sanitizeSingleLine(text, maxLength: InputSanitizer.maxMerchantLength)

        // 2. Strip Israeli district/location prefixes first (e.g. "מחוז תל אביב תל אביב-יפו, ", "מחוז... גבעתיים, ", "מחוז מרכז, ")
        if let range = text.range(of: #"^מחוז[\s\.\u{2026}]*[^,]+,\s*"#, options: .regularExpression) {
            text.removeSubrange(range)
        }

        // 3. Strip leading card company prefix if single line (e.g. "Isracard: ", "כאל - ", "Max: ", "לאומי: ")
        if let range = text.range(of: #"^(?:isracard|ישראכרט|cal|כאל|max|מקס|visa|mastercard|apple\s*pay|ארנק|לאומי|פועלים|דיסקונט|מזרחי)[\s\:\-\•\,]+"#, options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
        }

        // 4. Extract merchant name from Israeli bank/card sentence formats (e.g. "עסקה בסך 58 ש״ח ב-AM:PM", "חויב בסך 120 ₪ בבית העסק ZARA")
        if let match = text.range(of: #"(?:(?:\s+|^)ב-|בבית העסק\s+|בבית עסק\s+|עבור\s+|לכבוד\s+)(.+)$"#, options: .regularExpression) {
            let extracted = String(text[match]).replacingOccurrences(of: #"^(?:\s*ב-|בבית העסק\s+|בבית עסק\s+|עבור\s+|לכבוד\s+)"#, with: "", options: .regularExpression)
            if !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = extracted
            }
        }

        // 5. Strip trailing amount strings (e.g. ", ₪ 6.00", " - ₪22.00", ", 9.90 ₪", " ₪ 13.00", " 45.00 ש״ח")
        // NOTE: Must require either a currency mark OR decimal digits so house numbers / store numbers (e.g. "Kokpit 67", "Cafe 48") are never stripped.
        let trailingAmountPatterns = [
            #"[\s,\-]+(?:₪|\$|€|NIS|ILS|nis|ils|ש״ח|ש"ח|שח)\s*[0-9]+(?:[.,][0-9]{1,2})?\s*$"#,
            #"[\s,\-]+[0-9]+(?:[.,][0-9]{1,2})?\s*(?:₪|\$|€|NIS|ILS|nis|ils|ש״ח|ש"ח|שח)\s*$"#,
            #"[\s,\-]+[0-9]+[.,][0-9]{1,2}\s*$"#
        ]
        for pattern in trailingAmountPatterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                text.removeSubrange(range)
                break
            }
        }

        // 6. Trim residual punctuation and whitespace
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " ,-:;•*\"'״׳").union(.whitespacesAndNewlines))

        return text.isEmpty ? nil : text
    }

    // MARK: - Duplicate detection

    /// True when `existing` already holds the same payment within `duplicateWindow`.
    public static func isDuplicate(
        merchant: String,
        amount: Double,
        currency: String = "₪",
        originalAmount: Double? = nil,
        originalCurrency: String? = nil,
        date: Date,
        in existing: [Transaction]
    ) -> Bool {
        let key = MerchantCanonicalizer.canonicalKey(for: merchant)
        return existing.contains { tx in
            guard MerchantCanonicalizer.canonicalKey(for: tx.merchant) == key else { return false }
            guard abs(tx.timestamp.timeIntervalSince(date)) <= duplicateWindow else { return false }

            // 1. If both have original foreign currency/amount, match on those
            if let txOrigAmt = tx.originalAmount, let txOrigCurr = tx.originalCurrency,
               let inOrigAmt = originalAmount, let inOrigCurr = originalCurrency {
                let txSignedOrig = tx.amount < 0 ? -abs(txOrigAmt) : abs(txOrigAmt)
                let inSignedOrig = amount < 0 ? -abs(inOrigAmt) : abs(inOrigAmt)
                if currencyKey(txOrigCurr) == currencyKey(inOrigCurr) && abs(txSignedOrig - inSignedOrig) < 0.005 {
                    return true
                }
            }

            // 2. Compare incoming against stored original if incoming currency matches original
            if let txOrigAmt = tx.originalAmount, let txOrigCurr = tx.originalCurrency {
                let txSignedOrig = tx.amount < 0 ? -abs(txOrigAmt) : abs(txOrigAmt)
                if currencyKey(txOrigCurr) == currencyKey(currency) && abs(txSignedOrig - amount) < 0.005 {
                    return true
                }
            }

            // 3. Stored amount vs incoming amount
            let storedAmount = tx.originalAmount.map { tx.amount < 0 ? -abs($0) : abs($0) } ?? tx.amount
            let storedCurrency = tx.originalCurrency ?? tx.currency
            if currencyKey(storedCurrency) == currencyKey(currency) && abs(storedAmount - amount) < 0.005 {
                return true
            }

            // 4. Base converted amount comparison
            if currencyKey(tx.currency) == currencyKey(currency) && abs(tx.amount - amount) < 0.005 {
                return true
            }

            return false
        }
    }

    public static func currencyKey(_ value: String) -> String {
        CurrencyResolutionService.normalizeToISOCode(value)
            ?? CurrencyType(symbolOrCode: value)?.rawValue
            ?? value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    // MARK: - Entry point

    /// Validates a Wallet payload and builds a classified transaction, or explains the refusal.
    public static func makeTransaction(
        amount: Double?,
        amountText: String?,
        merchant: String?,
        currency: String?,
        date: Date,
        existing: [Transaction],
        allowZeroFallback: Bool = false,
        isRefundHint: Bool = false,
        rules: [MerchantRule] = [],
        structuredCurrency: String? = nil
    ) throws -> Transaction {
        // 1. Recover amount and merchant using salvage
        let salvaged = salvage(amount: amount, amountText: amountText, merchant: merchant)
        let cleanAmount = salvaged.amount
        let isRefund = isRefundHint || salvaged.isRefund

        guard let finalParsedAmount = cleanAmount ?? (allowZeroFallback ? 0.0 : nil) else {
            throw TransactionIngestError.missingAmount
        }

        // 2. Recover merchant name
        let hasExplicitMerchant = (salvaged.merchant != nil)
        let cleanMerchant = salvaged.merchant ?? "לא זוהה"

        // 3. Centralized safe currency resolution
        let defaults = UserDefaults.standard
        let baseRaw = defaults.string(forKey: "app_currency_pref") ?? CurrencyType.ils.rawValue
        let baseCurrType = CurrencyType(rawValue: baseRaw)

        let currencyResolution = CurrencyResolutionService.resolve(
            structuredCurrencyCode: structuredCurrency,
            explicitCurrencyParam: currency,
            merchantText: merchant,
            amountText: amountText,
            payloadText: nil,
            baseCurrencyCode: baseCurrType.rawValue
        )

        var finalAmount = finalParsedAmount
        var finalCurrency = baseCurrType.symbol
        var originalAmount: Double? = nil
        var originalCurrency: String? = nil
        var exchangeRate: Double? = nil
        var needsCurrencyReview = false

        let autoConvert = defaults.object(forKey: "auto_convert_fx") as? Bool ?? true

        if currencyResolution.isForeignExplicitlyDetected {
            let foreignISO = currencyResolution.currencyCode
            if let converted = FXService.convert(amount: finalParsedAmount, from: foreignISO, to: baseCurrType.rawValue) {
                if autoConvert {
                    finalAmount = (converted * 100).rounded() / 100
                    finalCurrency = baseCurrType.symbol
                    originalAmount = finalParsedAmount
                    originalCurrency = foreignISO
                    exchangeRate = finalParsedAmount > 0 ? finalAmount / finalParsedAmount : nil
                    needsCurrencyReview = false
                } else {
                    finalAmount = finalParsedAmount
                    finalCurrency = foreignISO
                    originalAmount = finalParsedAmount
                    originalCurrency = foreignISO
                    exchangeRate = nil
                    needsCurrencyReview = true
                }
            } else {
                // FX FAILURE POLICY:
                // If an explicitly identified foreign currency has no usable conversion rate:
                // Do NOT invent a rate. Do NOT convert 1:1.
                // Do NOT silently turn: 100 TRY into ₪100 just because conversion failed.
                finalAmount = finalParsedAmount
                finalCurrency = foreignISO
                originalAmount = finalParsedAmount
                originalCurrency = foreignISO
                exchangeRate = nil
                needsCurrencyReview = true
            }
        } else {
            // Normal base currency (domestic ILS or base fallback)
            finalAmount = finalParsedAmount
            finalCurrency = baseCurrType.symbol
            originalAmount = nil
            originalCurrency = nil
            exchangeRate = nil
            needsCurrencyReview = false
        }

        // 4. Duplicate check with original currency and amount support
        if finalParsedAmount > 0 {
            let dupAmount = isRefund ? -finalAmount : finalAmount
            guard !isDuplicate(
                merchant: cleanMerchant,
                amount: dupAmount,
                currency: finalCurrency,
                originalAmount: originalAmount.map { isRefund ? -abs($0) : abs($0) },
                originalCurrency: originalCurrency,
                date: date,
                in: existing
            ) else {
                throw TransactionIngestError.duplicate
            }
        }

        // 5. Merchant classification
        let classification: ClassificationResult
        if hasExplicitMerchant {
            classification = MerchantRuleService.classify(
                merchant: cleanMerchant,
                amount: finalParsedAmount,
                rules: rules
            )
        } else {
            classification = ClassificationResult(
                category: .other,
                buildingId: "city_sorting_hub",
                confidence: 0.0,
                source: .unknown
            )
        }

        let isLearnedRule = classification.source == .userRule
            || classification.source == .legacyUserRule
            || classification.source == .learnedAlias
            || classification.source == .historyRecovery

        let isRecognized = (finalParsedAmount > 0) && hasExplicitMerchant && (classification.confidence >= 0.8)

        let isConfirmed = (isRefund || needsCurrencyReview || !hasExplicitMerchant) ? false : (isLearnedRule ? true : isRecognized)
        let confidenceScore: Double = (isRefund || needsCurrencyReview || !hasExplicitMerchant) ? 0.5 : (isLearnedRule ? 1.0 : (isRecognized ? classification.confidence : 0.0))
        let note: String? = isRefund
            ? "זיכוי / החזר מ-Apple Pay (ממתין לבדיקתך)"
            : (needsCurrencyReview
                ? "עסקה במטבע זר (\(originalCurrency ?? finalCurrency)) — ממתינה לאישור המרה"
                : (!hasExplicitMerchant ? "Apple Pay (בית עסק לא זוהה - ממתין למיון)" : nil))

        return Transaction(
            amount: isRefund ? -finalAmount : finalAmount,
            currency: finalCurrency,
            merchant: cleanMerchant,
            category: classification.category,
            timestamp: date,
            confidenceScore: confidenceScore,
            isManual: false,
            isConfirmed: isConfirmed,
            note: note,
            buildingId: classification.buildingId,
            originalAmount: originalAmount,
            originalCurrency: originalCurrency,
            exchangeRate: exchangeRate
        )
    }
}
