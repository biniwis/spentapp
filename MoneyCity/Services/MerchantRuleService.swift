import Foundation

/// Applies the user's own merchant→category corrections before falling back to keywords.
///
/// Kept pure and free of SwiftData so the matching rules are testable: a rule that fires
/// too eagerly silently misfiles every future transaction, which is worse than no rule.
public enum MerchantRuleService {

    /// Below this length a rule only matches an exact merchant, never a substring —
    /// otherwise a two-letter rule would swallow half the user's history.
    public static let minimumSubstringLength = 3

    /// Lowercased, trimmed, whitespace collapsed. Wallet pads and cases merchant names
    /// inconsistently between transactions at the same shop.
    public static func normalizedKey(_ merchant: String) -> String {
        merchant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// The rule that should win for this merchant.
    ///
    /// An exact match always beats a substring match, and among substring matches the
    /// longest key wins — "רמי לוי" must beat a broader "רמי" rule.
    public static func rule(for merchant: String, in rules: [MerchantRule]) -> MerchantRule? {
        let key = normalizedKey(merchant)
        guard !key.isEmpty else { return nil }

        if let exact = rules.first(where: { $0.merchantKey == key }) {
            return exact
        }

        return rules
            .filter { $0.merchantKey.count >= minimumSubstringLength && key.contains($0.merchantKey) }
            .max(by: { $0.merchantKey.count < $1.merchantKey.count })
    }

    /// Classification with the user's corrections applied first, keyword matching second.
    public static func classify(
        merchant: String,
        amount: Double,
        rules: [MerchantRule]
    ) -> ClassificationResult {
        if let rule = rule(for: merchant, in: rules) {
            let building = rule.buildingIdRaw ?? CategorizationEngine.shared.mapToBuildingId(
                category: rule.category,
                merchant: merchant
            )
            // The user told us directly, so this is not a guess and needs no confirmation.
            return ClassificationResult(category: rule.category, buildingId: building, confidence: 1.0)
        }
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

        if let match = existing.first(where: { $0.merchantKey == key }) {
            match.category = category
            match.buildingIdRaw = building
            match.displayName = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            return nil
        }

        return MerchantRule(
            merchantKey: key,
            displayName: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            buildingId: building
        )
    }
}
