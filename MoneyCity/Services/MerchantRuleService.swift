import Foundation

/// Applies the user's own merchant→category corrections before falling back to keywords.
///
/// Kept pure and free of SwiftData so the matching rules are testable: a rule that fires
/// too eagerly silently misfiles every future transaction, which is worse than no rule.
public enum MerchantRuleService {

    /// Below this length a rule only matches an exact merchant, never a substring —
    /// otherwise a two-letter rule would swallow half the user's history.
    public static let minimumSubstringLength = 3

    /// Canonical internal key for matching and learning.
    public static func normalizedKey(_ merchant: String) -> String {
        MerchantCanonicalizer.canonicalKey(for: merchant)
    }

    /// Checks if a rule key matches text respecting word boundaries.
    public static func matchesKey(ruleKey: String, in text: String) -> Bool {
        guard let range = text.range(of: ruleKey) else { return false }
        let validStart = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
        let validEnd = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
        return validStart && validEnd
    }

    /// The rule that should win for this merchant.
    ///
    /// Resolution Order:
    /// 1. Exact match by canonical key
    /// 2. Compatible legacy rule match (with lazy backfill)
    /// 3. Conservative learned alias match
    /// 4. Substring match for compound names (longest key wins)
    public static func rule(for merchant: String, in rules: [MerchantRule]) -> MerchantRule? {
        let key = normalizedKey(merchant)
        guard !key.isEmpty else { return nil }

        // 1. Exact canonical match
        if let exact = rules.first(where: { $0.merchantKey == key }) {
            return exact
        }

        // 2. Legacy compatibility match
        let legacyKey = MerchantCanonicalizer.legacyNormalizedKey(merchant)
        if let legacyMatch = rules.first(where: { rule in
            rule.merchantKey == legacyKey
                || MerchantCanonicalizer.canonicalKey(for: rule.displayName) == key
                || MerchantCanonicalizer.canonicalKey(for: rule.merchantKey) == key
        }) {
            // Lazy migration: update rule's merchantKey to canonicalKey
            legacyMatch.merchantKey = key
            return legacyMatch
        }

        // 3. Conservative learned alias match
        if let aliasMatch = MerchantCanonicalizer.findUnambiguousLearnedAlias(for: merchant, in: rules) {
            return aliasMatch
        }

        // 4. Substring match (longest key wins; numbers must match if present)
        let keyDigits = key.filter { $0.isNumber }
        let candidates = rules.filter { rule in
            guard rule.merchantKey.count >= minimumSubstringLength else { return false }
            let ruleDigits = rule.merchantKey.filter { $0.isNumber }
            if !ruleDigits.isEmpty && ruleDigits != keyDigits {
                return false
            }
            return matchesKey(ruleKey: rule.merchantKey, in: key)
        }

        return candidates.max(by: { $0.merchantKey.count < $1.merchantKey.count })
    }

    /// Classification with:
    /// 1. User's own learned rule always wins (confidence: 1.0)
    /// 2. Previously confirmed manual history recovery (confidence: 1.0)
    /// 3. Global Remote Merchant Overrides applied third (confidence: 0.98)
    /// 4. Built-in keyword categorization engine fourth
    /// 5. Unknown / requires review fallback
    public static func classify(
        merchant: String,
        amount: Double,
        rules: [MerchantRule],
        remoteConfig: RemoteConfigService = .shared,
        historyFallback: ((String) -> (category: SpendingCategory, buildingId: String)?)? = nil
    ) -> ClassificationResult {
        // 1. User's own rule always wins
        if let rule = rule(for: merchant, in: rules) {
            let building = rule.buildingIdRaw ?? CategorizationEngine.shared.mapToBuildingId(
                category: rule.category,
                merchant: merchant
            )
            // Determine source for diagnostics
            let canonical = normalizedKey(merchant)
            let source: ClassificationSource
            if rule.merchantKey == canonical {
                source = .userRule
            } else if MerchantCanonicalizer.matchesLearnedAlias(candidate: merchant, learnedKey: rule.merchantKey) {
                source = .learnedAlias
            } else {
                source = .legacyUserRule
            }
            return ClassificationResult(category: rule.category, buildingId: building, confidence: 1.0, source: source)
        }

        // 2. Safe Historical Confirmation Recovery
        if let history = historyFallback?(merchant) {
            return ClassificationResult(category: history.category, buildingId: history.buildingId, confidence: 1.0, source: .historyRecovery)
        }

        // 3. Global Remote Merchant Override
        if let remoteCategory = remoteConfig.merchantOverride(for: merchant) {
            let building = CategorizationEngine.shared.mapToBuildingId(
                category: remoteCategory,
                merchant: merchant
            )
            return ClassificationResult(category: remoteCategory, buildingId: building, confidence: 0.98, source: .remoteOverride)
        }

        // 4. Built-in Categorization Engine
        return CategorizationEngine.shared.classify(merchant: merchant, amount: amount)
    }

    /// Creates or updates the rule implied by a correction. Returns the rule to insert,
    /// or nil when an existing one was updated in place.
    public static func ruleAfterCorrection(
        merchant: String,
        category: SpendingCategory,
        buildingId: String? = nil,
        existing: [MerchantRule]
    ) -> MerchantRule? {
        let key = normalizedKey(merchant)
        guard !key.isEmpty else { return nil }

        let building = buildingId ?? CategorizationEngine.shared.mapToBuildingId(category: category, merchant: merchant)
        let legacyKey = MerchantCanonicalizer.legacyNormalizedKey(merchant)

        // Check if an existing rule matches by canonical key, legacy key, display name, or alias
        if let match = existing.first(where: {
            $0.merchantKey == key
                || $0.merchantKey == legacyKey
                || MerchantCanonicalizer.canonicalKey(for: $0.displayName) == key
                || MerchantCanonicalizer.canonicalKey(for: $0.merchantKey) == key
                || MerchantCanonicalizer.matchesLearnedAlias(candidate: merchant, learnedKey: $0.merchantKey)
        }) {
            match.category = category
            match.buildingIdRaw = building
            match.displayName = MerchantCanonicalizer.safeDisplayMerchant(merchant)
            match.merchantKey = key // migrate to canonical
            return nil
        }

        return MerchantRule(
            merchantKey: key,
            displayName: MerchantCanonicalizer.safeDisplayMerchant(merchant),
            category: category,
            buildingId: building
        )
    }
}
