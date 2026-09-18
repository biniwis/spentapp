import Foundation

/// One shared canonical merchant identity system used everywhere across SPENT.
///
/// Distinguishes between:
/// - DISPLAY NAME: The readable merchant string shown to the user.
/// - CANONICAL KEY: The stable internal identity used for matching and learning.
public enum MerchantCanonicalizer {

    // MARK: - Canonical Key Generation

    /// The authoritative canonical key for matching and learning.
    ///
    /// Preserves business identity (including branch numbers, street numbers, and distinct names),
    /// while safely normalizing casing, Unicode characters, whitespace, harmless payment processor
    /// wrappers (e.g. `PAY*`, `GMF*`, `*IL`), and superficial punctuation differences.
    public static func canonicalKey(for merchant: String) -> String {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // 1. Unicode normalization and strip Hebrew niqqud / combining marks
        var text = stripCombiningMarks(trimmed.precomposedStringWithCanonicalMapping)

        // 2. Case folding
        text = text.lowercased()

        // 3. Strip common payment gateway/processor wrappers & prefixes
        text = stripProcessorNoise(text)

        // 4. Normalize quotes and apostrophes (straight vs smart vs Hebrew gershayim/geresh)
        text = normalizeQuotesAndApostrophes(text)

        // 5. Replace harmless separator symbols (*, #, _, ~, bullet, etc.) with spaces,
        // while preserving slashes between numbers (e.g. "24/7").
        let separatorChars = CharacterSet(charactersIn: "*#_~•|\\^+=`")
        text = text.components(separatedBy: separatorChars).joined(separator: " ")
        text = text.replacingOccurrences(of: #"(?<![0-9])\/|\/(?![0-9])"#, with: " ", options: .regularExpression)

        // 6. Collapse repeated whitespace and trim residual boundary punctuation
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,-:;.'\"״׳").union(.whitespacesAndNewlines))

        return collapsed
    }

    /// Legacy normalization used by older versions of SPENT. Kept for backward compatibility.
    public static func legacyNormalizedKey(_ merchant: String) -> String {
        merchant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Sanitizes and cleans a display merchant name for user-facing UI while preserving readability.
    public static func safeDisplayMerchant(_ raw: String) -> String {
        let sanitized = InputSanitizer.sanitizeSingleLine(raw, maxLength: InputSanitizer.maxMerchantLength)
        let trimmed = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: " ,-:;•*\"'״׳").union(.whitespacesAndNewlines))
        return trimmed.isEmpty ? AppLanguage.localized("לא זוהה", "Unknown") : trimmed
    }

    // MARK: - Internal Cleaners

    /// Removes Unicode combining marks (such as Hebrew niqqud or Latin accents).
    private static func stripCombiningMarks(_ str: String) -> String {
        str.unicodeScalars.filter { scalar in
            // Hebrew points/accents: U+0591 to U+05C7
            if scalar.value >= 0x0591 && scalar.value <= 0x05C7 {
                return false
            }
            // General combining diacritical marks: U+0300 to U+036F
            if scalar.value >= 0x0300 && scalar.value <= 0x036F {
                return false
            }
            return true
        }.map(String.init).joined()
    }

    /// Strips payment processor wrapper prefixes and suffixes without harming merchant names.
    private static func stripProcessorNoise(_ str: String) -> String {
        var result = str

        // Known payment gateway prefixes: e.g. "pay*", "gmf*", "z-", "iz*", "sq*", "pp*", "stripe*", "sumup*", "bit*", "paybox*"
        let prefixPattern = #"^(?:pay\s*\*|gmf\s*\*|z\s*[-–—]|iz\s*\*|sq\s*\*|pp\s*[\*:]|stripe\s*[\*:]|sumup\s*[\*:]|bit\s*[\*:\-–—]|paybox\s*[\*:\-–—]|paypal\s*[\*:]|google\s*[\*:]|tabit\s*[\*:])\s*"#
        result = result.replacingOccurrences(of: prefixPattern, with: "", options: .regularExpression)

        // Trailing processor noise like "*il", "*israel", trailing asterisks/dashes
        let suffixPattern = #"(?:\s*[\*]\s*(?:il|israel|isr)\b|\s*[\*]+$)"#
        result = result.replacingOccurrences(of: suffixPattern, with: "", options: .regularExpression)

        return result
    }

    /// Normalizes quotation marks and apostrophes across Latin and Hebrew.
    private static func normalizeQuotesAndApostrophes(_ str: String) -> String {
        var result = str
        // Replace typographic curly quotes with straight
        result = result.replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
        return result
    }

    // MARK: - Conservative Learned Aliases

    /// Checks if a candidate merchant string safely and conservatively matches a known user-learned merchant key.
    ///
    /// Rules:
    /// - Only auto-matches if unambiguous and structurally equivalent.
    /// - Never merges merchants with differing numbers (e.g. "Cafe 48" vs "Cafe 49").
    /// - Strips payment processor wrappers and harmless punctuation to compare against learned keys.
    public static func matchesLearnedAlias(candidate: String, learnedKey: String) -> Bool {
        let candKey = canonicalKey(for: candidate)
        if candKey.isEmpty || learnedKey.isEmpty { return false }
        if candKey == learnedKey { return true }

        // Check if digits differ: if both contain digits and the digits don't match, NEVER alias!
        let candDigits = candKey.filter { $0.isNumber }
        let learnedDigits = learnedKey.filter { $0.isNumber }
        if !candDigits.isEmpty || !learnedDigits.isEmpty {
            if candDigits != learnedDigits {
                return false
            }
        }

        // Substring check with word boundaries for known prefix/suffix variations:
        // E.g. "wolt" matches "wolt" inside "wolt delivery" or "wolt il" if learned is "wolt"
        // But rule length must be >= 3 characters to avoid false matches.
        if learnedKey.count >= 3 {
            // Check if candKey starts with learnedKey followed by a separator/space or ends with it
            if candKey.hasPrefix(learnedKey) {
                let remainder = candKey.dropFirst(learnedKey.count).trimmingCharacters(in: .whitespacesAndNewlines)
                // Harmless remainder (e.g. "il", "online", "ltd", "בעמ", "בע״מ")
                let safeRemainders: Set<String> = ["il", "israel", "isr", "online", "ltd", "בעמ", "בע\"מ", "בע״מ", "סניף"]
                if safeRemainders.contains(remainder) {
                    return true
                }
            }
        }

        return false
    }

    /// Discovers an unambiguous matching rule from existing learned rules using conservative aliasing.
    /// Returns nil if 0 or >1 matches exist.
    public static func findUnambiguousLearnedAlias(
        for merchant: String,
        in rules: [MerchantRule]
    ) -> MerchantRule? {
        let candKey = canonicalKey(for: merchant)
        guard !candKey.isEmpty else { return nil }

        var matchingRules: [MerchantRule] = []
        for rule in rules {
            if matchesLearnedAlias(candidate: merchant, learnedKey: rule.merchantKey) {
                matchingRules.append(rule)
            }
        }

        // If exactly one rule matched, it is unambiguous.
        if matchingRules.count == 1 {
            return matchingRules[0]
        }

        return nil
    }
}
