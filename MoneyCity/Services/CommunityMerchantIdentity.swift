import Foundation
import CryptoKit

/// Shared deterministic hashing and identity generation for Community Merchant Learning.
///
/// Principles:
/// - Generates pseudonymous merchant identities using the canonical merchant key and a versioned namespace.
/// - Never includes amounts, timestamps, currencies, user notes, location, or transaction identifiers.
/// - Produces deterministic vote record names tied to the current iCloud user ID so each user
///   can have at most one current vote per merchant.
public enum CommunityMerchantIdentity {

    /// Namespace prefix for merchant identity hashes.
    public static let merchantNamespace = "merchant-v1"

    /// Namespace prefix for deterministic per-user vote record names.
    public static let voteNamespace = "vote-v1"

    /// Computes deterministic SHA-256 hash for a merchant string.
    ///
    /// Formula: `SHA-256("merchant-v1|" + canonicalKey)`
    public static func merchantHash(for merchant: String) -> String {
        let canonical = MerchantCanonicalizer.canonicalKey(for: merchant)
        guard !canonical.isEmpty else { return "" }
        let payload = "\(merchantNamespace)|\(canonical)"
        return sha256Hex(payload)
    }

    /// Computes deterministic stable voter identity from the user's CloudKit user record name.
    ///
    /// Formula: `SHA-256("spent-community-v1|" + cloudKitUserRecordName)`
    /// This identity is stable across app relaunches, reinstalls, and devices signed into the same iCloud account,
    /// without relying on device UUIDs, random salts, or local storage.
    public static func stableVoterIdentity(cloudKitUserRecordName: String) -> String {
        let cleanUser = cloudKitUserRecordName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUser.isEmpty else { return "" }
        let payload = "spent-community-v1|\(cleanUser)"
        return sha256Hex(payload)
    }

    /// Computes deterministic CloudKit vote record name from a stable voter identity and merchant hash.
    ///
    /// Formula: `SHA-256("vote-v1|" + stableVoterIdentity + "|" + merchantHash)`
    public static func voteRecordName(stableVoterIdentity: String, merchantHash: String) -> String {
        let cleanVoter = stableVoterIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHash = merchantHash.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanVoter.isEmpty, !cleanHash.isEmpty else { return "" }
        let payload = "\(voteNamespace)|\(cleanVoter)|\(cleanHash)"
        return sha256Hex(payload)
    }

    /// Convenience wrapper computing vote record name directly from CloudKit user record name and merchant hash.
    public static func voteRecordName(userRecordName: String, merchantHash: String) -> String {
        let voterId = stableVoterIdentity(cloudKitUserRecordName: userRecordName)
        guard !voterId.isEmpty else { return "" }
        return voteRecordName(stableVoterIdentity: voterId, merchantHash: merchantHash)
    }

    private static func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
