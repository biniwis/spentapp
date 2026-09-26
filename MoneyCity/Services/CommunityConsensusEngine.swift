import Foundation

/// High-level merchant recognition and trust state, distinct from transaction review state.
public enum MerchantRecognitionState: String, Sendable, Codable, Equatable {
    /// Merchant knowledge is established and trusted (personal rule, curated remote override, or community confirmed).
    /// Classified silently with no inline confirmation affordance.
    case trusted

    /// Merchant has a reasonable category guess (heuristic or community suggestion), but has not yet earned merchant-level trust.
    /// Shows optional inline confirmation affordance (✓).
    case suggested

    /// Merchant has no confident category suggestion. Falls back to `.other` / "Set category".
    case unknown
}

/// Status of aggregated community consensus for a merchant.
public enum CommunityConsensusStatus: String, Sendable, Codable, Equatable {
    /// Insufficient votes to form any consensus (< 2 votes).
    case none

    /// Clear winning category with at least 2 votes, but not yet meeting the confirmation threshold.
    case suggestion

    /// Unanimous (>= 3 votes, 0 conflicts) or strongly confirmed (>= 5 votes, >= 80% agreement).
    case confirmed

    /// Competing categories tied for the top vote count.
    case disputed
}

/// A pseudonymous community vote for a merchant category.
public struct CommunityVote: Sendable, Codable, Equatable {
    public let voterId: String
    public let merchantHash: String
    public let categoryRawValue: String
    public let identityVersion: Int64
    public let schemaVersion: Int64
    public let updatedAt: Date?

    public init(
        voterId: String,
        merchantHash: String,
        categoryRawValue: String,
        identityVersion: Int64 = 1,
        schemaVersion: Int64 = 1,
        updatedAt: Date? = nil
    ) {
        self.voterId = voterId
        self.merchantHash = merchantHash
        self.categoryRawValue = categoryRawValue
        self.identityVersion = identityVersion
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
    }

    public var category: SpendingCategory? {
        SpendingCategory(rawValue: categoryRawValue)
    }
}

/// Result of evaluating consensus among community votes for a merchant.
public struct CommunityConsensusResult: Sendable, Codable, Equatable {
    public let merchantHash: String
    public let status: CommunityConsensusStatus
    public let winnerCategory: SpendingCategory?
    public let winningVotes: Int
    public let totalVotes: Int
    public let agreementRatio: Double
    public let uniqueVotersCount: Int

    public init(
        merchantHash: String,
        status: CommunityConsensusStatus,
        winnerCategory: SpendingCategory?,
        winningVotes: Int,
        totalVotes: Int,
        agreementRatio: Double,
        uniqueVotersCount: Int
    ) {
        self.merchantHash = merchantHash
        self.status = status
        self.winnerCategory = winnerCategory
        self.winningVotes = winningVotes
        self.totalVotes = totalVotes
        self.agreementRatio = agreementRatio
        self.uniqueVotersCount = uniqueVotersCount
    }

    public static func empty(merchantHash: String) -> CommunityConsensusResult {
        CommunityConsensusResult(
            merchantHash: merchantHash,
            status: .none,
            winnerCategory: nil,
            winningVotes: 0,
            totalVotes: 0,
            agreementRatio: 0.0,
            uniqueVotersCount: 0
        )
    }
}

/// Pure, testable consensus calculation engine.
///
/// Consensus Thresholds (V1):
/// - 0 votes: .none
/// - 1 vote: .none (insufficient to influence global classification)
/// - 2 votes, 0 conflicts: .suggestion
/// - 3 votes, 0 conflicts: .confirmed
/// - Conflicts:
///   - If >= 5 unique votes exist and winnerVotes / totalVotes >= 0.80: .confirmed
///   - Otherwise if clear winner with >= 2 votes: .suggestion
///   - Tie for top vote count: .disputed
public enum CommunityConsensusEngine {

    public static let supportedSchemaVersion: Int64 = 1
    public static let minVotesForSuggestion = 2
    public static let minVotesForUnanimousConfirmation = 3
    public static let minVotesForConflictedConfirmation = 5
    public static let conflictedConfirmationRatio = 0.80

    /// Calculates community consensus from an array of community votes.
    public static func computeConsensus(
        merchantHash: String,
        votes: [CommunityVote]
    ) -> CommunityConsensusResult {
        guard !merchantHash.isEmpty else {
            return .empty(merchantHash: "")
        }

        // 1. Filter to valid schema version and recognized categories
        let validVotes = votes.filter { vote in
            guard vote.schemaVersion == supportedSchemaVersion else { return false }
            guard SpendingCategory(rawValue: vote.categoryRawValue) != nil else { return false }
            return !vote.voterId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !validVotes.isEmpty else {
            return .empty(merchantHash: merchantHash)
        }

        // 2. Deduplicate by voterId: keep the newest vote per voter
        var voterMap: [String: CommunityVote] = [:]
        for vote in validVotes {
            if let existing = voterMap[vote.voterId] {
                let existingDate = existing.updatedAt ?? .distantPast
                let newDate = vote.updatedAt ?? .distantPast
                if newDate >= existingDate {
                    voterMap[vote.voterId] = vote
                }
            } else {
                voterMap[vote.voterId] = vote
            }
        }

        let dedupedVotes = Array(voterMap.values)
        let totalUniqueVoters = dedupedVotes.count

        guard totalUniqueVoters > 0 else {
            return .empty(merchantHash: merchantHash)
        }

        // 3. Count votes per category
        var counts: [SpendingCategory: Int] = [:]
        for vote in dedupedVotes {
            if let cat = SpendingCategory(rawValue: vote.categoryRawValue) {
                counts[cat, default: 0] += 1
            }
        }

        guard let maxCount = counts.values.max() else {
            return .empty(merchantHash: merchantHash)
        }

        // Check for ties at the top count
        let topCategories = counts.filter { $0.value == maxCount }
        if topCategories.count > 1 {
            return CommunityConsensusResult(
                merchantHash: merchantHash,
                status: .disputed,
                winnerCategory: nil,
                winningVotes: maxCount,
                totalVotes: totalUniqueVoters,
                agreementRatio: Double(maxCount) / Double(totalUniqueVoters),
                uniqueVotersCount: totalUniqueVoters
            )
        }

        guard let winner = topCategories.first else {
            return .empty(merchantHash: merchantHash)
        }

        let winningCategory = winner.key
        let winningVotes = winner.value
        let agreementRatio = Double(winningVotes) / Double(totalUniqueVoters)
        let hasConflicts = winningVotes < totalUniqueVoters

        // 0 or 1 vote: insufficient to influence global classification
        if totalUniqueVoters < minVotesForSuggestion {
            return CommunityConsensusResult(
                merchantHash: merchantHash,
                status: .none,
                winnerCategory: winningCategory,
                winningVotes: winningVotes,
                totalVotes: totalUniqueVoters,
                agreementRatio: agreementRatio,
                uniqueVotersCount: totalUniqueVoters
            )
        }

        // 3 matching unique votes, 0 conflicts: confirmed
        if !hasConflicts && winningVotes >= minVotesForUnanimousConfirmation {
            return CommunityConsensusResult(
                merchantHash: merchantHash,
                status: .confirmed,
                winnerCategory: winningCategory,
                winningVotes: winningVotes,
                totalVotes: totalUniqueVoters,
                agreementRatio: agreementRatio,
                uniqueVotersCount: totalUniqueVoters
            )
        }

        // 2 matching unique votes, 0 conflicts: suggestion
        if !hasConflicts && winningVotes >= minVotesForSuggestion {
            return CommunityConsensusResult(
                merchantHash: merchantHash,
                status: .suggestion,
                winnerCategory: winningCategory,
                winningVotes: winningVotes,
                totalVotes: totalUniqueVoters,
                agreementRatio: agreementRatio,
                uniqueVotersCount: totalUniqueVoters
            )
        }

        // Has conflicts:
        // If >= 5 unique votes and agreement ratio >= 80%: confirmed
        if totalUniqueVoters >= minVotesForConflictedConfirmation && agreementRatio >= conflictedConfirmationRatio {
            return CommunityConsensusResult(
                merchantHash: merchantHash,
                status: .confirmed,
                winnerCategory: winningCategory,
                winningVotes: winningVotes,
                totalVotes: totalUniqueVoters,
                agreementRatio: agreementRatio,
                uniqueVotersCount: totalUniqueVoters
            )
        }

        // If >= 2 winning votes: remains suggestion
        if winningVotes >= minVotesForSuggestion {
            return CommunityConsensusResult(
                merchantHash: merchantHash,
                status: .suggestion,
                winnerCategory: winningCategory,
                winningVotes: winningVotes,
                totalVotes: totalUniqueVoters,
                agreementRatio: agreementRatio,
                uniqueVotersCount: totalUniqueVoters
            )
        }

        return CommunityConsensusResult(
            merchantHash: merchantHash,
            status: .none,
            winnerCategory: winningCategory,
            winningVotes: winningVotes,
            totalVotes: totalUniqueVoters,
            agreementRatio: agreementRatio,
            uniqueVotersCount: totalUniqueVoters
        )
    }
}
