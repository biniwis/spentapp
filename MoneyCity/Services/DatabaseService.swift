import Foundation
import SwiftData

/// How much of the raw-payload diagnostic trail is kept, and for how long.
///
/// The count cap alone is not enough: a user whose automation works writes a handful of
/// entries a week, so 100 entries can mean a year of merchant names and amounts sitting on
/// disk to explain a problem that was fixed in March. The age cap is the one that actually
/// bounds the exposure. Kept outside `DatabaseService` so the pure retention rule is
/// reachable without touching the main actor.
public enum IngestLogRetention {
    public static let maxEntries = 100
    public static let maxAge: TimeInterval = 14 * 24 * 60 * 60
}

/// Centralized, production-grade database coordinator for SwiftData & SQLite storage.
@MainActor
public final class DatabaseService {
    public static let shared = DatabaseService()
    
    public let container: ModelContainer
    public var context: ModelContext {
        container.mainContext
    }
    
    /// How the store actually opened. Anything other than `.persistent` means the app is
    /// running degraded and the user has to be told, because both other modes look
    /// identical to "all my data disappeared" from the outside.
    public enum StorageMode: Equatable {
        /// Normal operation: the existing on-disk store opened.
        case persistent
        /// The old store could not be opened, so it was moved aside and a new one started.
        /// Nothing was deleted — `backupPath` is where the old files are.
        case recoveredFreshStore(backupPath: String?)
        /// Nothing could be opened on disk. The app runs, but nothing survives relaunch.
        case memoryOnly
    }

    /// The mode the container opened in.
    public let storageMode: StorageMode

    /// The underlying error, when the first attempt failed. Diagnostics only.
    public let storageFailure: String?

    /// True when writes will not survive the app being closed.
    public var isEphemeral: Bool { storageMode == .memoryOnly }

    private init() {
        // Both of these have to happen before the container exists, and in this order.
        //
        // A restore swaps the store file, which is only safe while nothing has it open — and
        // a snapshot is worthless if it is taken after a migration has already reshaped the
        // file it was meant to preserve. This is the one moment in the app's life when
        // neither is true yet.
        StoreSnapshotService.applyPendingRestoreIfNeeded()
        StoreSnapshotService.snapshotIfBuildChanged()

        // Built from the versioned schema, not a bare model list, so the store carries the
        // version identifier the migration plan matches against. V1 is 1.0.0, which is also
        // what an unversioned schema defaulted to — so an existing store opens unchanged.
        let schema = Schema(versionedSchema: MoneyCitySchemaV1.self)
        let outcome = DatabaseService.openContainer(schema: schema)
        self.container = outcome.container
        self.storageMode = outcome.mode
        self.storageFailure = outcome.failure

        // A snapshot cannot count its own rows — opening it to look would migrate the very
        // file it exists to preserve — so the count is banked here, from the store that just
        // opened, and the next snapshot carries it as its label.
        if outcome.mode == .persistent {
            let count = (try? container.mainContext.fetchCount(FetchDescriptor<Transaction>())) ?? 0
            StoreSnapshotService.recordTransactionCount(count)
        }
    }

    // MARK: - Container recovery

    /// Opens the store, preferring to keep the user's data over keeping the app quiet.
    ///
    /// The previous version fell straight to an in-memory store on any failure and only
    /// printed about it. That is the worst possible outcome for a ledger: the app opens,
    /// looks empty, accepts new expenses all day, and loses them at relaunch — while the
    /// real store is still sitting on disk, unopened and now competing with a month of
    /// re-entered data. So the failure path here moves the unreadable store somewhere safe
    /// first, and only gives up on disk entirely if that doesn't help.
    private static func openContainer(
        schema: Schema
    ) -> (container: ModelContainer, mode: StorageMode, failure: String?) {

        // 1. The ordinary path.
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: MoneyCityMigrationPlan.self,
                configurations: [config]
            )
            return (container, .persistent, nil)
        } catch {
            let firstFailure = String(describing: error)
            MoneyCityLog.error("on-disk container failed to open: \(firstFailure)")

            // 2. Quarantine whatever is there and try again on disk. If the store files
            //    aren't where we expect, `quarantine` returns nil and retrying would just
            //    fail the same way, so we skip straight to memory.
            if let backup = quarantineExistingStore() {
                MoneyCityLog.error("previous store moved to \(backup); retrying on disk")
                do {
                    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                    let container = try ModelContainer(
                        for: schema,
                        migrationPlan: MoneyCityMigrationPlan.self,
                        configurations: [config]
                    )
                    return (container, .recoveredFreshStore(backupPath: backup), firstFailure)
                } catch {
                    MoneyCityLog.error("fresh on-disk container also failed: \(error)")
                }
            }

            // 3. Last resort. The app opens; the banner tells the user not to trust it.
            do {
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [memoryConfig])
                return (container, .memoryOnly, firstFailure)
            } catch {
                fatalError("Critical: no SwiftData container could be created: \(error)")
            }
        }
    }

    /// Moves the existing store aside rather than deleting it, and reports where it went.
    ///
    /// Returns nil when there was nothing to move, which is also the signal that a retry
    /// on disk is pointless.
    private static func quarantineExistingStore() -> String? {
        let fm = FileManager.default
        guard let support = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }

        let names = ["default.store", "default.store-wal", "default.store-shm"]
        let present = names.filter { fm.fileExists(atPath: support.appendingPathComponent($0).path) }
        guard !present.isEmpty else { return nil }

        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd-HHmmss"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        let folder = support
            .appendingPathComponent("RecoveredStores", isDirectory: true)
            .appendingPathComponent(stamp.string(from: Date()), isDirectory: true)

        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for name in present {
                try fm.moveItem(
                    at: support.appendingPathComponent(name),
                    to: folder.appendingPathComponent(name)
                )
            }
            return folder.path
        } catch {
            MoneyCityLog.error("could not quarantine store: \(error)")
            return nil
        }
    }
    
    // MARK: - Transaction CRUD
    
    public func save(transaction: Transaction) async throws {
        context.insert(transaction)
        try context.save()
    }
    
    public func save(transactions: [Transaction]) async throws {
        for t in transactions {
            context.insert(t)
        }
        try context.save()
    }
    
    public func delete(transaction: Transaction) async throws {
        context.delete(transaction)
        try context.save()
    }
    
    public func delete(transactions: [Transaction]) async throws {
        for t in transactions {
            context.delete(t)
        }
        try context.save()
    }
    
    public func deleteAllTransactions() async throws {
        let all = fetchAllTransactions()
        try await delete(transactions: all)
    }
    
    // MARK: - Queries
    
    public func fetchAllTransactions() -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            MoneyCityLog.error("Error fetching all transactions: \(error)")
            return []
        }
    }
    
    public func fetchTransactions(for month: Date = Date()) -> [Transaction] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= startOfMonth && $0.timestamp < nextMonth },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            MoneyCityLog.error("Error fetching month transactions: \(error)")
            return []
        }
    }
    
    public func fetchTransactions(for category: SpendingCategory, in month: Date = Date()) -> [Transaction] {
        let raw = category.rawValue
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= startOfMonth && $0.timestamp < nextMonth && $0.categoryRawValue == raw },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            MoneyCityLog.error("Error fetching category transactions: \(error)")
            return []
        }
    }
    
    public func fetchYearlyTransactions(for year: Int = Calendar.current.component(.year, from: Date())) -> [Transaction] {
        let calendar = Calendar.current
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let nextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return []
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= startOfYear && $0.timestamp < nextYear },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            MoneyCityLog.error("Error fetching yearly transactions: \(error)")
            return []
        }
    }
    
    /// Recent rows only — used by the Wallet ingest path to detect a retried payment
    /// without loading the entire history.
    public func fetchRecentTransactions(within seconds: TimeInterval, of date: Date = Date()) -> [Transaction] {
        let lowerBound = date.addingTimeInterval(-seconds)
        let upperBound = date.addingTimeInterval(seconds)
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= lowerBound && $0.timestamp <= upperBound },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            MoneyCityLog.error("Error fetching recent transactions: \(error)")
            return []
        }
    }

    // MARK: - Ingest diagnostics

    /// Stores a raw-payload record immediately, so evidence survives even if the rest of
    /// the intent throws.
    public func record(_ entry: IngestLogEntry) {
        context.insert(entry)
        try? context.save()
        pruneIngestLog()
    }

    /// Saves changes made to an already-inserted object.
    public func persist() {
        try? context.save()
    }

    public func fetchIngestLog(limit: Int = 50) -> [IngestLogEntry] {
        var descriptor = FetchDescriptor<IngestLogEntry>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    public func clearIngestLog() {
        let all = (try? context.fetch(FetchDescriptor<IngestLogEntry>())) ?? []
        for entry in all { context.delete(entry) }
        try? context.save()
    }

    /// This is a diagnostic trail, not history — keep it small and short-lived.
    /// Also called at launch: pruning only on write means a user who stops using the
    /// automation keeps their last payloads on disk indefinitely, which is exactly the
    /// case the age limit exists for.
    public func pruneIngestLog() {
        let descriptor = FetchDescriptor<IngestLogEntry>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor) else { return }

        let now = Date()
        var removed = false

        for (index, entry) in all.enumerated()
        where DatabaseService.shouldDropIngestEntry(index: index, receivedAt: entry.receivedAt, now: now) {
            context.delete(entry)
            removed = true
        }

        if removed { try? context.save() }
    }

    /// Whether one entry in the newest-first list has aged out. Pure, so it can be tested
    /// without a store: the retention rule is the part that has to stay correct, and a
    /// mistake here means either an unbounded payload archive or a log that erases the
    /// evidence before the user can show it to anyone.
    ///
    /// - Parameter index: position in a list sorted newest first.
    nonisolated public static func shouldDropIngestEntry(
        index: Int,
        receivedAt: Date,
        now: Date
    ) -> Bool {
        if index >= IngestLogRetention.maxEntries { return true }
        return now.timeIntervalSince(receivedAt) > IngestLogRetention.maxAge
    }

    // MARK: - Aggregations
    
    public func fetchCategoryTotals(for month: Date = Date()) -> [SpendingCategory: Double] {
        let txs = fetchTransactions(for: month)
        var totals: [SpendingCategory: Double] = [:]
        for cat in SpendingCategory.allCases {
            totals[cat] = 0.0
        }
        for t in txs {
            totals[t.category, default: 0.0] += t.amount
        }
        return totals
    }
    
    public func fetchBuildingTotals(for month: Date = Date()) -> [String: Double] {
        let txs = fetchTransactions(for: month)
        var totals: [String: Double] = [
            "food_bistro": 0.0,
            "food_super": 0.0,
            "food_coffee": 0.0,
            "food_wolt": 0.0,
            "shop_boutique": 0.0,
            "shop_tech": 0.0,
            "shop_travel": 0.0,
            "shop_arcade": 0.0,
            "trans_station": 0.0,
            "house_tower": 0.0,
            "house_util": 0.0,
            "house_subs": 0.0,
            "savings_sanctuary": 0.0
        ]
        
        for t in txs {
            let bId = t.buildingId
            totals[bId, default: 0.0] += t.amount
        }
        return totals
    }
    
    // MARK: - Reset

    public func resetAllData() async throws {
        try await deleteAllTransactions()

        // Fixed-expense templates are configuration, not data, so they survive a reset —
        // but their bookkeeping is rewound so a reset does not back-fill a year of rent.
        let recurringDescriptor = FetchDescriptor<RecurringExpense>()
        if let templates = try? context.fetch(recurringDescriptor) {
            for t in templates {
                t.lastGeneratedPeriod = nil
                t.createdAt = Date()
            }
        }
        
        let enrichDescriptor = FetchDescriptor<CityEnrichment>()
        if let enrichments = try? context.fetch(enrichDescriptor) {
            for e in enrichments {
                context.delete(e)
            }
            try context.save()
        }
    }

    // MARK: - Learned Merchant Rules
    
    public func rememberCorrection(merchant: String, category: SpendingCategory, buildingId: String? = nil) {
        let existing = fetchMerchantRules()
        if let rule = MerchantRuleService.ruleAfterCorrection(merchant: merchant, category: category, buildingId: buildingId, existing: existing) {
            context.insert(rule)
        }
        try? context.save()
    }
    
    public func fetchMerchantRules() -> [MerchantRule] {
        let descriptor = FetchDescriptor<MerchantRule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            MoneyCityLog.error("Error fetching merchant rules: \(error)")
            return []
        }
    }
}
