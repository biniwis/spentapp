import Foundation
import SwiftData

/// Central coordinator bridging explicit human merchant corrections and confirmations into:
/// 1. The user's personal `MerchantRule` (authoritative, synchronous, local first).
/// 2. Asynchronous pseudonymous community voting via CloudKit (best effort, non-blocking).
///
/// Principles:
/// - LOCAL SAVE ALWAYS COMES FIRST: Network problems or CloudKit failures never impact the user experience.
/// - One iCloud user = one vote per merchant: Handled deterministically by `CommunityMerchantService`.
/// - Never backfills or uploads inferred heuristic data; only invoked upon genuine human intent.
@MainActor
public final class MerchantLearningCoordinator {
    public static let shared = MerchantLearningCoordinator()

    public enum LearningSource: String, Sendable {
        case inlineHistoryConfirmation
        case contextMenuConfirmation
        case editTransactionSheet
        case merchantDetailSheet
    }

    /// Performs immediate synchronous local learning followed by asynchronous community contribution.
    public func confirm(
        merchant: String,
        category: SpendingCategory,
        buildingId: String? = nil,
        transaction: Transaction? = nil,
        context: ModelContext? = nil,
        source: LearningSource,
        allowCommunityVote: Bool = true
    ) {
        let cleanMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMerchant.isEmpty, category != .other else { return }

        // 1. Local personal rule first (authoritative, immediate)
        DatabaseService.shared.rememberCorrection(
            merchant: cleanMerchant,
            category: category,
            buildingId: buildingId
        )

        // 2. If a specific transaction was provided, mark it confirmed with full confidence
        if let tx = transaction {
            tx.category = category
            if let bId = buildingId {
                tx.buildingIdRaw = bId
            }
            tx.isConfirmed = true
            tx.confidenceScore = 1.0
            if let ctx = context {
                _ = DatabaseService.safeSave(ctx)
            } else {
                _ = DatabaseService.shared.save()
            }
        }

        Haptics.impact(.light)

        // 3. Asynchronous pseudonymized community contribution
        // STRICT RULE (Section 4): Manual transactions, refunds, and foreign unreviewed items
        // MUST NOT contribute to community learning V1.
        guard allowCommunityVote else { return }

        if let tx = transaction {
            if tx.isManual {
                MoneyCityLog.debug("[MerchantLearningCoordinator] Skipped community vote for manual transaction.")
                return
            }
            let isRefund = tx.amount < 0 || (tx.note?.contains("זיכוי") == true)
            if isRefund {
                MoneyCityLog.debug("[MerchantLearningCoordinator] Skipped community vote for refund.")
                return
            }
            if tx.isUnresolvedForeign {
                MoneyCityLog.debug("[MerchantLearningCoordinator] Skipped community vote for unresolved foreign transaction.")
                return
            }
        }

        let merchantHash = CommunityMerchantIdentity.merchantHash(for: cleanMerchant)
        guard !merchantHash.isEmpty else { return }

        Task {
            await CommunityMerchantService.shared.submitOrQueueVote(
                merchantHash: merchantHash,
                category: category
            )
        }
    }
}
