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
    /// The automation is known to retry, and nobody buys the same thing twice in 90 seconds.
    public static let duplicateWindow: TimeInterval = 90

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
        if let a = amount, a > 0, a.isFinite {
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

        guard let value = parseGrouped(token), value > 0, value.isFinite else { return nil }
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
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
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
        // The merchant field is only a last resort for the amount, and only when the text
        // actually looks like money. "Kokpit 67" is a shop with a number in its name, not a
        // ₪67 charge — guessing there would invent a wrong amount instead of asking.
        let recoveredAmount = normalizedAmount(amount, amountText)
            ?? amountLikeValue(in: merchant)

        var recoveredMerchant = normalizedMerchant(merchant).flatMap(nameWithoutAmount)
        if recoveredMerchant == nil {
            recoveredMerchant = normalizedMerchant(amountText).flatMap(nameWithoutAmount)
        }

        return Salvaged(amount: recoveredAmount, merchant: recoveredMerchant)
    }

    /// An amount embedded in free text, accepted only when it is marked as money — by a
    /// currency symbol or by decimal digits. A bare integer inside a shop name is not money.
    public static func amountLikeValue(in text: String?) -> Double? {
        guard let text, !text.isEmpty else { return nil }

        let hasCurrencyMark = ["₪", "$", "€", "£", "ILS", "USD", "EUR", "GBP"]
            .contains { text.contains($0) }
        let hasDecimalRun = text.range(
            of: "[0-9]+[.,][0-9]{1,2}(?![0-9])",
            options: .regularExpression
        ) != nil

        guard hasCurrencyMark || hasDecimalRun else { return nil }
        return normalizedAmount(nil, text)
    }

    /// Strips currency symbols and numeric runs so "Chacoli ₪6.00" yields "Chacoli".
    /// Returns nil when nothing but digits and punctuation was there to begin with.
    public static func nameWithoutAmount(_ text: String) -> String? {
        var stripped = text.replacingOccurrences(
            of: "[0-9\u{0660}-\u{0669}]+(?:[.,][0-9]+)*",
            with: " ",
            options: .regularExpression
        )
        for symbol in ["₪", "$", "€", "£", "ILS", "USD", "EUR", "GBP"] {
            stripped = stripped.replacingOccurrences(of: symbol, with: " ")
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
        if let range = text.range(of: #"[\s,\-]+(?:₪|\$|€|NIS|ILS|ש״ח|ש\"ח|שח)?\s*[0-9]+(?:[.,][0-9]{1,2})?\s*(?:₪|\$|€|NIS|ILS|ש״ח|ש\"ח|שח)?\s*$"#, options: .regularExpression) {
            text.removeSubrange(range)
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
        date: Date,
        in existing: [Transaction]
    ) -> Bool {
        let key = merchant.lowercased()
        return existing.contains { tx in
            tx.merchant.lowercased() == key
                && abs(tx.amount - amount) < 0.01
                && abs(tx.timestamp.timeIntervalSince(date)) < duplicateWindow
        }
    }

    // MARK: - Entry point

    /// Validates a Wallet payload and builds a classified transaction, or explains the refusal.
    public static func makeTransaction(
        amount: Double?,
        amountText: String?,
        merchant: String?,
        currency: String,
        date: Date,
        existing: [Transaction],
        allowZeroFallback: Bool = false,
        rules: [MerchantRule] = []
    ) throws -> Transaction {
        // 1. Recover amount from numeric parameter, text parameter, or embedded within merchant string
        var cleanAmount = normalizedAmount(amount, amountText)
        if cleanAmount == nil, let rawM = merchant {
            cleanAmount = normalizedAmount(nil, rawM)
        }

        guard let finalParsedAmount = cleanAmount ?? (allowZeroFallback ? 0.0 : nil) else {
            throw TransactionIngestError.missingAmount
        }

        // 2. Recover merchant name
        let cleanMerchant = normalizedMerchant(merchant) ?? "Apple Pay (לא זוהה)"

        if finalParsedAmount > 0 {
            guard !isDuplicate(merchant: cleanMerchant, amount: finalParsedAmount, date: date, in: existing) else {
                throw TransactionIngestError.duplicate
            }
        }

        // The user's own corrections win over keyword guessing — a rule the user set is
        // knowledge, not a guess, so it also lands at full confidence.
        let classification = MerchantRuleService.classify(
            merchant: cleanMerchant,
            amount: finalParsedAmount,
            rules: rules
        )

        let isRecognized = (finalParsedAmount > 0) && (normalizedMerchant(merchant) != nil) && (classification.confidence >= 0.8)

        // Currency FX conversion
        var finalAmount = finalParsedAmount
        let defaults = UserDefaults.standard
        let baseRaw = defaults.string(forKey: "app_currency_pref") ?? CurrencyType.ils.rawValue
        let baseCurrType = CurrencyType(rawValue: baseRaw) ?? .ils
        var finalCurrency = baseCurrType.symbol
        var originalAmount: Double? = nil
        var originalCurrency: String? = nil
        var exchangeRate: Double? = nil

        let autoConvert = defaults.object(forKey: "auto_convert_fx") as? Bool ?? true

        if let rawCurrType = CurrencyType(symbolOrCode: currency),
           rawCurrType != baseCurrType,
           autoConvert {
            finalAmount = FXService.convert(amount: finalParsedAmount, from: rawCurrType, to: baseCurrType)
            finalCurrency = baseCurrType.symbol
            originalAmount = finalParsedAmount
            originalCurrency = currency
            exchangeRate = FXService.rateToILS(for: rawCurrType)
        } else {
            finalCurrency = currency
        }

        return Transaction(
            amount: finalAmount,
            currency: finalCurrency,
            merchant: cleanMerchant,
            category: classification.category,
            timestamp: date,
            confidenceScore: isRecognized ? classification.confidence : 0.0,
            isManual: false,
            // Anything missing a merchant, amount, or with low confidence is parked for the user to review.
            isConfirmed: isRecognized,
            buildingId: classification.buildingId,
            originalAmount: originalAmount,
            originalCurrency: originalCurrency,
            exchangeRate: exchangeRate
        )
    }
}
