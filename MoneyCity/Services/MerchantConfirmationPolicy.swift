import Foundation

/// Pure policy governing eligibility and grouping for inline merchant category confirmations in History.
///
/// Rules (Section 27 & 28):
/// - Feature flag `communityMerchantLearning` must be enabled.
/// - Eligible only for automatic, non-refund, non-FX-review transactions with a valid merchant and non-.other category.
/// - Suppressed if the user already has a personal MerchantRule, if a Remote Config curated override exists,
///   or if the merchant is already community-confirmed.
/// - Visible History deduplication: exactly one confirmation affordance (✓) per canonical merchant identity,
///   placed on the newest eligible transaction.
public enum MerchantConfirmationPolicy {

    /// Checks if a single transaction is eligible for category confirmation.
    public static func isEligible(
        transaction: Transaction,
        rules: [MerchantRule],
        remoteConfig: RemoteConfigService = .shared,
        communityCache: CommunityMerchantCache = .shared
    ) -> Bool {
        // 0. Feature flag check
        guard remoteConfig.isFeatureEnabled("communityMerchantLearning", default: false) else {
            return false
        }

        // 1. Merchant text is non-empty and valid
        let merchant = transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchant.isEmpty else { return false }
        let canonical = MerchantCanonicalizer.canonicalKey(for: merchant)
        guard !canonical.isEmpty else { return false }
        if canonical == "לא זוהה" || canonical == "unknown" { return false }

        // 2. Transaction is not manual
        guard !transaction.isManual else { return false }

        // 3. Transaction is not a refund
        let isRefund = transaction.amount < 0 || (transaction.note?.contains("זיכוי") == true)
        guard !isRefund else { return false }

        // 4. Transaction does not have unresolved foreign-currency review
        guard !transaction.isUnresolvedForeign else { return false }

        // 5. Transaction category is not .other
        guard transaction.category != .other else { return false }

        // 6. User does not already have a matching personal MerchantRule
        if MerchantRuleService.rule(for: merchant, in: rules) != nil {
            return false
        }

        // 7. No Remote Config / curated trusted rule exists
        if remoteConfig.merchantOverride(for: merchant) != nil {
            return false
        }

        // 8. No community-confirmed rule exists
        if let cached = communityCache.entry(forMerchant: merchant), cached.status == .confirmed {
            return false
        }

        // 9. Merchant knowledge is heuristic or community suggestion (not trusted)
        // 10. The category visible in this row is safely confirmable
        return true
    }

    /// Computes the set of Transaction IDs that should display the inline ✓ affordance.
    /// Only the newest eligible transaction per canonical merchant identity shows the affordance.
    public static func eligibleTransactionIDs(
        in transactions: [Transaction],
        rules: [MerchantRule],
        remoteConfig: RemoteConfigService = .shared,
        communityCache: CommunityMerchantCache = .shared
    ) -> Set<UUID> {
        guard remoteConfig.isFeatureEnabled("communityMerchantLearning", default: false) else {
            return []
        }

        // Sort by timestamp descending (newest first)
        let sorted = transactions.sorted { $0.timestamp > $1.timestamp }
        var seenCanonicalKeys = Set<String>()
        var eligibleIDs = Set<UUID>()

        for tx in sorted {
            let key = MerchantCanonicalizer.canonicalKey(for: tx.merchant)
            guard !key.isEmpty else { continue }

            if isEligible(transaction: tx, rules: rules, remoteConfig: remoteConfig, communityCache: communityCache) {
                if !seenCanonicalKeys.contains(key) {
                    seenCanonicalKeys.insert(key)
                    eligibleIDs.insert(tx.id)
                }
            }
        }

        return eligibleIDs
    }
}
