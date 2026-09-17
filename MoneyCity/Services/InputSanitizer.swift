import Foundation

/// Centralized sanitizer for external and untrusted text inputs.
///
/// Prevents control characters, NUL bytes, unbounded payloads, and abnormal Unicode,
/// while fully preserving legitimate text in any language (Hebrew, English, Arabic, etc.),
/// emojis, and common punctuation without naive character stripping.
public enum InputSanitizer {
    public static let maxMerchantLength = 200
    public static let maxNoteLength = 1000
    public static let maxIdentifierLength = 64
    public static let maxCurrencyLength = 8

    /// Checks if a UnicodeScalar is a dangerous ISO C0 or C1 control character.
    /// Preserves Unicode category 'Cf' (Format characters such as ZWJ U+200D for compound emojis,
    /// ZWNJ U+200C, and LRM/RLM U+200E/U+200F for bidirectional Hebrew/Arabic layout).
    private static func isDisallowedControlScalar(_ scalar: UnicodeScalar, allowNewlines: Bool) -> Bool {
        let value = scalar.value
        // C0 control characters (0x00...0x1F)
        if value <= 0x1F {
            if allowNewlines && (value == 0x0A || value == 0x0D || value == 0x09) {
                return false // Allowed: LF, CR, Tab
            }
            return true
        }
        // DEL (0x7F)
        if value == 0x7F {
            return true
        }
        // C1 control characters (0x80...0x9F)
        if value >= 0x80 && value <= 0x9F {
            return true
        }
        return false
    }

    /// Normalizes and cleans single-line user/external strings (e.g. merchant names, titles, categories).
    ///
    /// - Performs Unicode NFC canonical decomposition-then-composition normalization.
    /// - Strips ISO control characters (including NUL, escape sequences, newlines, tabs).
    /// - Trims leading and trailing whitespace.
    /// - Safely truncates to `maxLength` grapheme clusters without breaking multi-byte or emoji sequences.
    public static func sanitizeSingleLine(_ text: String, maxLength: Int = maxMerchantLength) -> String {
        guard !text.isEmpty else { return "" }
        let normalized = text.precomposedStringWithCanonicalMapping
        
        let filteredScalars = normalized.unicodeScalars.filter { scalar in
            !isDisallowedControlScalar(scalar, allowNewlines: false)
        }
        let cleaned = String(String.UnicodeScalarView(filteredScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(maxLength))
    }

    /// Normalizes and cleans multiline user/external strings (e.g. notes, descriptions).
    ///
    /// - Preserves legitimate newlines (`\n`, `\r`) and tabs (`\t`).
    /// - Strips NUL and dangerous control characters.
    /// - Performs Unicode NFC normalization.
    /// - Truncates to `maxLength` grapheme clusters.
    public static func sanitizeMultiline(_ text: String, maxLength: Int = maxNoteLength) -> String {
        guard !text.isEmpty else { return "" }
        let normalized = text.precomposedStringWithCanonicalMapping
        
        let filteredScalars = normalized.unicodeScalars.filter { scalar in
            !isDisallowedControlScalar(scalar, allowNewlines: true)
        }
        let cleaned = String(String.UnicodeScalarView(filteredScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(maxLength))
    }

    /// Sanitizes identifiers coming from external or bridge sources (e.g. IDs in JSON, messages, URLs).
    public static func sanitizeIdentifier(_ text: String, maxLength: Int = maxIdentifierLength) -> String {
        return sanitizeSingleLine(text, maxLength: maxLength)
    }

    /// General sanitizer utility.
    public static func sanitize(_ text: String, allowNewlines: Bool = false, maxLength: Int? = nil) -> String {
        if allowNewlines {
            return sanitizeMultiline(text, maxLength: maxLength ?? maxNoteLength)
        } else {
            return sanitizeSingleLine(text, maxLength: maxLength ?? maxMerchantLength)
        }
    }

    /// Convenience for merchant names and short titles.
    public static func sanitizeMerchant(_ text: String) -> String {
        return sanitizeSingleLine(text, maxLength: maxMerchantLength)
    }

    /// Convenience for user notes and descriptions.
    public static func sanitizeNote(_ text: String) -> String {
        return sanitizeMultiline(text, maxLength: maxNoteLength)
    }

    /// Convenience for currency codes/symbols.
    public static func sanitizeCurrency(_ text: String) -> String {
        return sanitizeSingleLine(text, maxLength: maxCurrencyLength)
    }

    /// Validates numeric monetary amounts: guards against NaN, Infinities, and excessive magnitudes.
    public static func sanitizeAmount(_ amount: Double, allowNegative: Bool = false, maxMagnitude: Double = 1_000_000_000.0) -> Double {
        guard amount.isFinite else { return 0.0 }
        var clean = amount
        if !allowNegative && clean < 0 {
            clean = 0.0
        }
        if clean > maxMagnitude {
            clean = maxMagnitude
        } else if clean < -maxMagnitude {
            clean = -maxMagnitude
        }
        return clean
    }
}
