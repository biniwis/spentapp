import Foundation

/// Sources of currency resolution, ordered from strongest structured evidence to conservative fallback.
public enum CurrencyResolutionSource: String, Codable, Sendable {
    case structuredWalletCurrency      // IntentCurrencyAmount or structured Wallet parameter
    case explicitIntentCurrency        // Explicit currency parameter passed to App Intent / Shortcut
    case structuredPayload             // JSON/dictionary payload keys (currency, currencyCode, etc.)
    case explicitISOCodeInText         // Explicit 3-letter ISO code in raw text ("45.90 EUR", "20 USD")
    case explicitUniqueSymbol          // Unique currency symbol in text ("€", "£", "₪", "₺", "¥")
    case legacyBaseCurrencyFallback    // No strong foreign evidence; safely use user's configured base currency
    case userConfirmed                 // Explicit user selection in UI (Quick Add or Edit)
}

/// The result of resolving a transaction's currency.
public struct CurrencyResolution: Equatable, Sendable {
    public let currencyCode: String                  // Normalized ISO 4217 code (e.g. "ILS", "USD", "EUR")
    public let source: CurrencyResolutionSource
    public let confidence: Double
    public let isForeignExplicitlyDetected: Bool

    public init(
        currencyCode: String,
        source: CurrencyResolutionSource,
        confidence: Double,
        isForeignExplicitlyDetected: Bool
    ) {
        self.currencyCode = currencyCode
        self.source = source
        self.confidence = confidence
        self.isForeignExplicitlyDetected = isForeignExplicitlyDetected
    }
}

/// Centralized, conservative currency resolution engine.
///
/// PRODUCT PRIORITY:
/// SPENT is primarily used in Israel. Preserving the existing automatic domestic capture
/// (where Apple Pay / Shortcuts passes currency = nil) is far more important than aggressive
/// foreign guessing.
///
/// Missing currency is NOT an error — it means "use the user's base currency".
/// Location, timezone, locale, and international merchant names must NEVER independently
/// override the base currency without explicit transaction-level evidence.
public enum CurrencyResolutionService {

    /// Normalizes currency symbols, Hebrew terms, and common aliases into canonical ISO 4217 codes.
    public static func normalizeToISOCode(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch trimmed.uppercased() {
        case "₪", "ILS", "NIS", "ש״ח", "ש\"ח", "שח", "שקלים", "שקל":
            return "ILS"
        case "€", "EUR", "EURO", "אירו":
            return "EUR"
        case "£", "GBP", "POUND", "פאונד", "ליש״ט":
            return "GBP"
        case "$", "USD", "DOLLAR", "דולר":
            return "USD"
        case "₺", "TRY", "TL", "לירה טורקית":
            return "TRY"
        case "¥", "JPY", "YEN", "ין יפני":
            return "JPY"
        case "CHF":
            return "CHF"
        case "CAD":
            return "CAD"
        case "AUD":
            return "AUD"
        case "AED":
            return "AED"
        case "THB", "฿":
            return "THB"
        case "PLN", "ZŁ":
            return "PLN"
        case "CZK", "KČ":
            return "CZK"
        case "HUF", "FT":
            return "HUF"
        case "SEK":
            return "SEK"
        case "NOK":
            return "NOK"
        case "DKK":
            return "DKK"
        case "CNY":
            return "CNY"
        case "HKD":
            return "HKD"
        case "SGD":
            return "SGD"
        case "KRW", "₩":
            return "KRW"
        default:
            // Valid ISO 4217 3-letter ASCII alphabetic code
            if trimmed.count == 3 && trimmed.allSatisfy({ $0.isASCII && $0.isLetter }) {
                return trimmed.uppercased()
            }
            return nil
        }
    }

    /// Known ISO 4217 codes recognized in raw text.
    public static let recognizedISOCodes: Set<String> = [
        "ILS", "USD", "EUR", "GBP", "TRY", "JPY", "CHF", "CAD", "AUD", "AED",
        "THB", "PLN", "CZK", "HUF", "SEK", "NOK", "DKK", "CNY", "HKD", "SGD",
        "KRW", "BRL", "INR", "MXN", "ZAR", "NZD", "SAR", "QAR", "BGN", "RON"
    ]

    /// Resolves the currency for an incoming transaction using the strict safety priority.
    public static func resolve(
        structuredCurrencyCode: String? = nil,
        explicitCurrencyParam: String? = nil,
        merchantText: String? = nil,
        amountText: String? = nil,
        payloadText: String? = nil,
        baseCurrencyCode: String = "ILS"
    ) -> CurrencyResolution {
        let baseISO = normalizeToISOCode(baseCurrencyCode) ?? "ILS"

        // 1. Structured currency directly supplied by Apple / Wallet (e.g. IntentCurrencyAmount)
        if let structCode = normalizeToISOCode(structuredCurrencyCode) {
            let isForeign = (structCode != baseISO)
            return CurrencyResolution(
                currencyCode: structCode,
                source: .structuredWalletCurrency,
                confidence: 1.0,
                isForeignExplicitlyDetected: isForeign
            )
        }

        // 2. Existing explicit currency parameter passed to App Intent
        if let explicit = explicitCurrencyParam?.trimmingCharacters(in: .whitespacesAndNewlines), !explicit.isEmpty {
            if let normalized = normalizeToISOCode(explicit) {
                let isForeign = (normalized != baseISO)
                return CurrencyResolution(
                    currencyCode: normalized,
                    source: .explicitIntentCurrency,
                    confidence: 1.0,
                    isForeignExplicitlyDetected: isForeign
                )
            }
        }

        // 3. Structured JSON payload keys (inspect before cleaning text)
        for candidate in [payloadText, merchantText, amountText] {
            if let text = candidate, text.contains("{") && text.contains("}") {
                if let data = text.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let rawPayloadCurrency = (dict["currency"] as? String)
                        ?? (dict["currencyCode"] as? String)
                        ?? (dict["currency_code"] as? String)
                        ?? (dict["Currency"] as? String)
                        ?? (dict["CurrencyCode"] as? String)
                    if let normalized = normalizeToISOCode(rawPayloadCurrency) {
                        let isForeign = (normalized != baseISO)
                        return CurrencyResolution(
                            currencyCode: normalized,
                            source: .structuredPayload,
                            confidence: 1.0,
                            isForeignExplicitlyDetected: isForeign
                        )
                    }
                }
            }
        }

        // 4. Explicit currency information inside raw text (MUST be inspected BEFORE merchant cleanup)
        let textSources = [merchantText, amountText, payloadText].compactMap { $0 }
        for text in textSources where !text.isEmpty {
            // 4a. Explicit ISO code in text (e.g. "45.90 EUR", "EUR 45.90", "20 USD", "USD 20", "₪42.90")
            if let isoCode = extractISOCodeFromText(text) {
                let isForeign = (isoCode != baseISO)
                return CurrencyResolution(
                    currencyCode: isoCode,
                    source: .explicitISOCodeInText,
                    confidence: 0.95,
                    isForeignExplicitlyDetected: isForeign
                )
            }

            // 4b. Explicit unambiguous currency symbols (e.g. "€20", "£15", "₪42.90", "120 ש״ח")
            if let symbolCode = extractUnambiguousSymbolFromText(text) {
                let isForeign = (symbolCode != baseISO)
                return CurrencyResolution(
                    currencyCode: symbolCode,
                    source: .explicitUniqueSymbol,
                    confidence: 0.95,
                    isForeignExplicitlyDetected: isForeign
                )
            }

            // 4c. Ambiguous dollar symbol policy:
            // Do NOT automatically assume every `$` means USD in every possible context.
            // If user's base currency is USD, `$` is base.
            // If base currency is NOT USD (e.g. ILS), require explicit ISO "USD" (handled in 4a above)
            // or explicit USD keyword. Bare `$` in free text alone is deliberately treated
            // conservatively to protect domestic capture from false positives.
        }

        // 5. BASE CURRENCY FALLBACK (Fundamental Product Requirement)
        // If no strong explicit foreign-currency evidence was found:
        // Use user's configured base currency, exactly as SPENT does today.
        return CurrencyResolution(
            currencyCode: baseISO,
            source: .legacyBaseCurrencyFallback,
            confidence: 1.0,
            isForeignExplicitlyDetected: false
        )
    }

    // MARK: - Text Extraction Helpers

    /// Extracts an unambiguous 3-letter ISO code if present in the text (e.g. "45.90 EUR", "20 USD", "AM:PM ₪42.90 ILS").
    private static func extractISOCodeFromText(_ text: String) -> String? {
        // Look for recognized 3-letter ISO codes bordered by whitespace, digits, or boundaries
        for code in recognizedISOCodes {
            let patterns = [
                #"[0-9]+(?:[.,][0-9]+)?\s*"# + code + #"(?![A-Za-z])"#,
                #"(?<![A-Za-z])"# + code + #"\s*[0-9]+(?:[.,][0-9]+)?"#,
                #"(?:^|[\s,;:\(\)\-])"# + code + #"(?:$|[\s,;:\(\)\-])"#
            ]
            for pattern in patterns {
                if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    return code
                }
            }
        }
        return nil
    }

    /// Extracts unique, unambiguous currency symbols from text.
    /// Deliberately excludes `$` because of ambiguity across currencies and noise.
    private static func extractUnambiguousSymbolFromText(_ text: String) -> String? {
        if text.contains("€") { return "EUR" }
        if text.contains("£") { return "GBP" }
        if text.contains("₪") || text.contains("ש״ח") || text.contains("ש\"ח") { return "ILS" }
        if text.contains("₺") { return "TRY" }
        if text.contains("฿") { return "THB" }
        if text.contains("₩") { return "KRW" }
        return nil
    }
}
