import Foundation

/// A single cached snapshot entry for community merchant knowledge.
public struct CommunityCacheEntry: Codable, Sendable, Equatable {
    public let merchantHash: String
    public let winnerCategoryRawValue: String?
    public let status: CommunityConsensusStatus
    public let winningVotes: Int
    public let totalVotes: Int
    public let agreementRatio: Double
    public let fetchedAt: Date
    public let identityVersion: Int64
    public let schemaVersion: Int64

    public init(
        merchantHash: String,
        winnerCategoryRawValue: String?,
        status: CommunityConsensusStatus,
        winningVotes: Int,
        totalVotes: Int,
        agreementRatio: Double,
        fetchedAt: Date = Date(),
        identityVersion: Int64 = 1,
        schemaVersion: Int64 = 1
    ) {
        self.merchantHash = merchantHash
        self.winnerCategoryRawValue = winnerCategoryRawValue
        self.status = status
        self.winningVotes = winningVotes
        self.totalVotes = totalVotes
        self.agreementRatio = agreementRatio
        self.fetchedAt = fetchedAt
        self.identityVersion = identityVersion
        self.schemaVersion = schemaVersion
    }

    public init(consensus: CommunityConsensusResult, fetchedAt: Date = Date()) {
        self.merchantHash = consensus.merchantHash
        self.winnerCategoryRawValue = consensus.winnerCategory?.rawValue
        self.status = consensus.status
        self.winningVotes = consensus.winningVotes
        self.totalVotes = consensus.totalVotes
        self.agreementRatio = consensus.agreementRatio
        self.fetchedAt = fetchedAt
        self.identityVersion = 1
        self.schemaVersion = CommunityConsensusEngine.supportedSchemaVersion
    }

    public var winnerCategory: SpendingCategory? {
        guard let raw = winnerCategoryRawValue else { return nil }
        return SpendingCategory(rawValue: raw)
    }

    public var recognitionState: MerchantRecognitionState {
        switch status {
        case .confirmed:
            return .trusted
        case .suggestion:
            return .suggested
        case .none, .disputed:
            return .unknown
        }
    }
}

/// Fast, thread-safe, synchronous local cache for community merchant consensus.
///
/// Principles:
/// - Fast synchronous lookups during transaction classification (no await, no network).
/// - Completely decoupled from SwiftData to avoid database migrations.
/// - Persisted as an atomic Codable store in the shared App Group / Application Support.
/// - Graceful corruption fallback: corrupted cache file is discarded without crashing.
public final class CommunityMerchantCache: @unchecked Sendable {
    public static let shared = CommunityMerchantCache()

    private let lock = NSLock()
    private var entries: [String: CommunityCacheEntry] = [:]
    private let storageURL: URL?

    public convenience init() {
        self.init(storageURL: Self.defaultStorageURL())
    }

    public init(storageURL: URL?) {
        self.storageURL = storageURL
        loadFromDisk()
    }

    // MARK: - Synchronous Lookup

    /// Returns the cached consensus entry for a merchant hash, if present.
    public func entry(for merchantHash: String) -> CommunityCacheEntry? {
        guard !merchantHash.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return entries[merchantHash]
    }

    /// Returns the cached consensus entry for a merchant name string.
    public func entry(forMerchant merchant: String) -> CommunityCacheEntry? {
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)
        return entry(for: hash)
    }

    // MARK: - Updates & Mutation

    /// Stores or updates a single cache entry in memory and flushes to disk.
    public func setEntry(_ entry: CommunityCacheEntry) {
        lock.lock()
        entries[entry.merchantHash] = entry
        lock.unlock()
        saveToDisk()
    }

    /// Stores or updates multiple cache entries and flushes to disk.
    public func update(entries newEntries: [CommunityCacheEntry]) {
        guard !newEntries.isEmpty else { return }
        lock.lock()
        for e in newEntries {
            entries[e.merchantHash] = e
        }
        lock.unlock()
        saveToDisk()
    }

    /// Removes an entry from the cache.
    public func removeEntry(for merchantHash: String) {
        lock.lock()
        entries.removeValue(forKey: merchantHash)
        lock.unlock()
        saveToDisk()
    }

    /// Resets all cached entries in memory and removes disk file.
    public func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
        saveToDisk()
    }

    /// Returns all currently cached entries.
    public func allEntries() -> [CommunityCacheEntry] {
        lock.lock()
        defer { lock.unlock() }
        return Array(entries.values)
    }

    // MARK: - Persistence & Corruption Fallback

    private func saveToDisk() {
        guard let url = storageURL else { return }
        lock.lock()
        let snapshot = entries
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            MoneyCityLog.error("[CommunityMerchantCache] Failed to save cache: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let url = storageURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: CommunityCacheEntry].self, from: data)
            lock.lock()
            self.entries = decoded
            lock.unlock()
        } catch {
            // Corruption fallback: discard corrupted cache safely
            MoneyCityLog.error("[CommunityMerchantCache] Corrupted cache detected. Resetting: \(error)")
            try? FileManager.default.removeItem(at: url)
            lock.lock()
            self.entries.removeAll()
            lock.unlock()
        }
    }

    private static func defaultStorageURL() -> URL? {
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.moneycity.app") {
            return appGroupURL.appendingPathComponent("community_merchant_cache.json")
        }
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            return appSupport.appendingPathComponent("community_merchant_cache.json")
        }
        return nil
    }
}
