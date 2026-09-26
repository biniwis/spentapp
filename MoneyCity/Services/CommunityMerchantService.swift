import Foundation
import CloudKit

/// Protocol abstracting CloudKit public database operations for testing and isolation.
public protocol CommunityCloudDatabaseProtocol: Sendable {
    func accountStatus() async throws -> CKAccountStatus
    func currentUserID() async throws -> String
    func saveVoteRecord(recordName: String, merchantHash: String, categoryRawValue: String) async throws
    func fetchVotes(merchantHash: String) async throws -> [CommunityVote]
}

/// Production CloudKit client implementation using the public database of `iCloud.com.moneycity.app`.
public final class CKCommunityDatabaseClient: CommunityCloudDatabaseProtocol, @unchecked Sendable {
    public static let containerIdentifier = "iCloud.com.moneycity.app"
    public static let recordType = "MerchantCommunityVote"

    /// Single authoritative container instance used for both voter identity and public database operations.
    public static let sharedContainer = CKContainer(identifier: containerIdentifier)

    private let container: CKContainer
    private let database: CKDatabase

    public init(container: CKContainer = sharedContainer) {
        self.container = container
        self.database = container.publicCloudDatabase
    }

    public func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    public func currentUserID() async throws -> String {
        let recordID = try await container.userRecordID()
        return recordID.recordName
    }

    public func saveVoteRecord(recordName: String, merchantHash: String, categoryRawValue: String) async throws {
        let recordID = CKRecord.ID(recordName: recordName)
        let recordToSave: CKRecord

        do {
            let existing = try await database.record(for: recordID)
            // Verify client-side ownership if existing record has a creator
            if let creator = existing.creatorUserRecordID, let current = try? await container.userRecordID() {
                guard creator.recordName == current.recordName else {
                    MoneyCityLog.error("[CKCommunityDatabaseClient] Ownership mismatch: cannot modify another creator's vote record.")
                    throw CKError(.permissionFailure)
                }
            }
            recordToSave = existing
        } catch let error as CKError where error.code == .unknownItem {
            recordToSave = CKRecord(recordType: Self.recordType, recordID: recordID)
        }

        recordToSave["merchantHash"] = merchantHash as CKRecordValue
        recordToSave["category"] = categoryRawValue as CKRecordValue
        recordToSave["categoryRawValue"] = categoryRawValue as CKRecordValue
        recordToSave["identityVersion"] = Int64(1) as CKRecordValue
        recordToSave["schemaVersion"] = CommunityConsensusEngine.supportedSchemaVersion as CKRecordValue

        let modifyOp = CKModifyRecordsOperation(recordsToSave: [recordToSave], recordIDsToDelete: nil)
        modifyOp.savePolicy = .changedKeys
        modifyOp.qualityOfService = .utility

        return try await withCheckedThrowingContinuation { continuation in
            modifyOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(modifyOp)
        }
    }

    public func fetchVotes(merchantHash: String) async throws -> [CommunityVote] {
        let predicate = NSPredicate(format: "merchantHash == %@", merchantHash)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)

        var fetchedVotes: [CommunityVote] = []

        return try await withCheckedThrowingContinuation { continuation in
            let queryOp = CKQueryOperation(query: query)
            queryOp.qualityOfService = .utility
            queryOp.resultsLimit = 100

            queryOp.recordMatchedBlock = { _, recordResult in
                if case .success(let record) = recordResult {
                    let hash = record["merchantHash"] as? String ?? ""
                    let cat = (record["category"] as? String) ?? (record["categoryRawValue"] as? String) ?? ""
                    let idVer = (record["identityVersion"] as? Int64) ?? 1
                    let sVer = (record["schemaVersion"] as? Int64) ?? 1
                    let rawVoter = record.creatorUserRecordID?.recordName ?? record.recordID.recordName
                    let voter = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: rawVoter)
                    let updateDate = record.modificationDate ?? record.creationDate

                    if !hash.isEmpty && !cat.isEmpty {
                        fetchedVotes.append(
                            CommunityVote(
                                voterId: voter.isEmpty ? rawVoter : voter,
                                merchantHash: hash,
                                categoryRawValue: cat,
                                identityVersion: idVer,
                                schemaVersion: sVer,
                                updatedAt: updateDate
                            )
                        )
                    }
                }
            }

            queryOp.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: fetchedVotes)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(queryOp)
        }
    }
}

/// Represents a single queued community vote waiting for upload.
public struct PendingCommunityVote: Codable, Equatable, Sendable {
    public let voterId: String
    public let merchantHash: String
    public let categoryRawValue: String
    public let queuedAt: Date

    public init(
        voterId: String,
        merchantHash: String,
        categoryRawValue: String,
        queuedAt: Date = Date()
    ) {
        self.voterId = voterId
        self.merchantHash = merchantHash
        self.categoryRawValue = categoryRawValue
        self.queuedAt = queuedAt
    }
}

/// Central coordinator for public CloudKit community voting, consensus derivation, and local cache synchronization.
///
/// Principles:
/// - One iCloud user = one vote per merchant (deterministic vote record ID replaces previous vote).
/// - Privacy-first: strictly pseudonymized merchant hash + category. Never transmits amounts, timestamps, notes, or IDs.
/// - Offline & account degradation: failures queue to a minimal local outbox or degrade gracefully without blocking local actions.
/// - Throttled queries: refreshes only missing/stale merchant candidates with a sensible TTL.
public final class CommunityMerchantService: @unchecked Sendable {
    public static let shared = CommunityMerchantService()

    public static let cacheTTL: TimeInterval = 6 * 3600 // 6 hours
    public static let maxCandidateRefreshBatch = 30

    private let client: CommunityCloudDatabaseProtocol
    private let cache: CommunityMerchantCache
    private let remoteConfig: RemoteConfigService
    private let outboxURL: URL?

    private let lock = NSLock()
    private var pendingOutbox: [String: PendingCommunityVote] = [:] // Keyed by merchantHash: replaces existing
    private var lastRefreshedTimestamps: [String: Date] = [:]

    public convenience init() {
        self.init(
            client: CKCommunityDatabaseClient(),
            cache: .shared,
            remoteConfig: .shared,
            outboxURL: Self.defaultOutboxURL()
        )
    }

    public init(
        client: CommunityCloudDatabaseProtocol,
        cache: CommunityMerchantCache = .shared,
        remoteConfig: RemoteConfigService = .shared,
        outboxURL: URL?
    ) {
        self.client = client
        self.cache = cache
        self.remoteConfig = remoteConfig
        self.outboxURL = outboxURL
        loadOutbox()
    }

    // MARK: - Vote Submission

    /// Submits a vote for a merchant category, or queues it in the outbox if transiently offline.
    public func submitOrQueueVote(merchantHash: String, category: SpendingCategory) async {
        guard remoteConfig.isFeatureEnabled("communityMerchantLearning", default: false) else {
            return
        }
        guard !merchantHash.isEmpty, category != .other else { return }

        do {
            let status = try await client.accountStatus()
            switch status {
            case .available:
                let rawUserID = try await client.currentUserID()
                let voterID = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: rawUserID)
                let recordName = CommunityMerchantIdentity.voteRecordName(
                    stableVoterIdentity: voterID,
                    merchantHash: merchantHash
                )

                try await client.saveVoteRecord(
                    recordName: recordName,
                    merchantHash: merchantHash,
                    categoryRawValue: category.rawValue
                )

                // Success: remove from outbox if previously pending
                removePendingVote(for: merchantHash)

                // Immediately refresh local consensus for this one merchant
                await refreshConsensus(for: merchantHash)

            case .noAccount, .restricted:
                // No iCloud account: local learning is authoritative, do not hold an indefinite queue
                MoneyCityLog.debug("[CommunityMerchantService] iCloud account not available (\(status.rawValue)). Skipped community vote.")
                return

            case .couldNotDetermine, .temporarilyUnavailable:
                MoneyCityLog.debug("[CommunityMerchantService] Transient iCloud status (\(status.rawValue)). Queuing vote.")
                if let rawUserID = try? await client.currentUserID() {
                    let voterID = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: rawUserID)
                    queuePendingVote(voterId: voterID, merchantHash: merchantHash, categoryRawValue: category.rawValue)
                }
                return

            @unknown default:
                return
            }
        } catch let ckError as CKError {
            if isTransientCloudKitError(ckError) {
                if let rawUserID = try? await client.currentUserID() {
                    let voterID = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: rawUserID)
                    queuePendingVote(voterId: voterID, merchantHash: merchantHash, categoryRawValue: category.rawValue)
                }
            } else {
                MoneyCityLog.error("[CommunityMerchantService] Permanent CloudKit error on vote: \(ckError)")
            }
        } catch {
            MoneyCityLog.error("[CommunityMerchantService] Vote upload failed, queuing to outbox: \(error.localizedDescription)")
            if let rawUserID = try? await client.currentUserID() {
                let voterID = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: rawUserID)
                queuePendingVote(voterId: voterID, merchantHash: merchantHash, categoryRawValue: category.rawValue)
            }
        }
    }

    // MARK: - Outbox & Retry

    /// Drains any pending outbox votes during maintenance.
    public func drainOutbox() async {
        guard remoteConfig.isFeatureEnabled("communityMerchantLearning", default: false) else { return }

        lock.lock()
        let pending = pendingOutbox
        lock.unlock()

        guard !pending.isEmpty else { return }

        do {
            let status = try await client.accountStatus()
            guard status == .available else { return }
            let rawUserID = try await client.currentUserID()
            let currentVoterID = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: rawUserID)

            for (merchantHash, pendingVote) in pending {
                // Ensure the pending vote matches the current CloudKit account!
                guard pendingVote.voterId == currentVoterID else {
                    MoneyCityLog.debug("[CommunityMerchantService] Stale outbox vote discarded due to account mismatch.")
                    removePendingVote(for: merchantHash)
                    continue
                }

                let recordName = CommunityMerchantIdentity.voteRecordName(
                    stableVoterIdentity: currentVoterID,
                    merchantHash: merchantHash
                )

                do {
                    try await client.saveVoteRecord(
                        recordName: recordName,
                        merchantHash: merchantHash,
                        categoryRawValue: pendingVote.categoryRawValue
                    )
                    removePendingVote(for: merchantHash)
                    await refreshConsensus(for: merchantHash)
                } catch let ckError as CKError where !isTransientCloudKitError(ckError) {
                    // Permanent error: discard vote to prevent endless loops
                    removePendingVote(for: merchantHash)
                } catch {
                    MoneyCityLog.error("[CommunityMerchantService] Failed draining pending vote for \(merchantHash): \(error)")
                }
            }
        } catch {
            MoneyCityLog.error("[CommunityMerchantService] Drain outbox failed checking account: \(error)")
        }
    }

    public func queuePendingVote(voterId: String, merchantHash: String, categoryRawValue: String) {
        lock.lock()
        pendingOutbox[merchantHash] = PendingCommunityVote(
            voterId: voterId,
            merchantHash: merchantHash,
            categoryRawValue: categoryRawValue
        )
        lock.unlock()
        saveOutbox()
    }

    public func pendingVote(for merchantHash: String) -> PendingCommunityVote? {
        lock.lock()
        defer { lock.unlock() }
        return pendingOutbox[merchantHash]
    }

    public func pendingOutboxCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingOutbox.count
    }

    public func removePendingVote(for merchantHash: String) {
        lock.lock()
        pendingOutbox.removeValue(forKey: merchantHash)
        lock.unlock()
        saveOutbox()
    }

    private func isTransientCloudKitError(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return true
        default:
            return false
        }
    }

    // MARK: - Consensus Refresh

    /// Fetches votes and updates the local cache for a single merchant hash.
    public func refreshConsensus(for merchantHash: String) async {
        guard !merchantHash.isEmpty else { return }
        do {
            let votes = try await client.fetchVotes(merchantHash: merchantHash)
            let result = CommunityConsensusEngine.computeConsensus(merchantHash: merchantHash, votes: votes)
            let entry = CommunityCacheEntry(consensus: result)
            cache.setEntry(entry)
            recordRefreshTimestamp(for: merchantHash)
        } catch {
            MoneyCityLog.error("[CommunityMerchantService] Refresh consensus failed for \(merchantHash): \(error)")
        }
    }

    /// Refreshes community consensus for eligible recent candidates during History appearance or maintenance.
    public func refreshCandidateMerchants(merchantHashes: [String], force: Bool = false) async {
        guard remoteConfig.isFeatureEnabled("communityMerchantLearning", default: false) else { return }
        guard !merchantHashes.isEmpty else { return }

        let now = Date()
        let candidates = merchantHashes.filter { hash in
            guard !hash.isEmpty else { return false }
            if force { return true }
            if let last = lastRefreshTimestamp(for: hash), now.timeIntervalSince(last) < Self.cacheTTL {
                return false
            }
            if let cached = cache.entry(for: hash), now.timeIntervalSince(cached.fetchedAt) < Self.cacheTTL {
                return false
            }
            return true
        }

        let capped = Array(candidates.prefix(Self.maxCandidateRefreshBatch))
        for hash in capped {
            await refreshConsensus(for: hash)
        }
    }

    /// Maintenance task triggered on app foreground.
    public func performMaintenanceRefresh() async {
        await drainOutbox()
    }

    // MARK: - Internal Outbox Persistence

    private func saveOutbox() {
        guard let url = outboxURL else { return }
        lock.lock()
        let snapshot = pendingOutbox
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            MoneyCityLog.error("[CommunityMerchantService] Failed to save outbox: \(error)")
        }
    }

    private func loadOutbox() {
        guard let url = outboxURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            if let decoded = try? JSONDecoder().decode([String: PendingCommunityVote].self, from: data) {
                lock.lock()
                self.pendingOutbox = decoded
                lock.unlock()
            } else if let legacy = try? JSONDecoder().decode([String: String].self, from: data) {
                lock.lock()
                self.pendingOutbox = legacy.mapValues {
                    PendingCommunityVote(voterId: "legacy", merchantHash: $0, categoryRawValue: $0)
                }
                lock.unlock()
            }
        } catch {
            MoneyCityLog.error("[CommunityMerchantService] Failed to load outbox, resetting: \(error)")
            try? FileManager.default.removeItem(at: url)
            lock.lock()
            self.pendingOutbox.removeAll()
            lock.unlock()
        }
    }

    private func recordRefreshTimestamp(for merchantHash: String) {
        lock.lock()
        lastRefreshedTimestamps[merchantHash] = Date()
        lock.unlock()
    }

    private func lastRefreshTimestamp(for merchantHash: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return lastRefreshedTimestamps[merchantHash]
    }

    private static func defaultOutboxURL() -> URL? {
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.moneycity.app") {
            return appGroupURL.appendingPathComponent("pending_community_votes.json")
        }
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            return appSupport.appendingPathComponent("pending_community_votes.json")
        }
        return nil
    }
}
