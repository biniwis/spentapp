import XCTest
import SwiftData
@testable import MoneyCity

/// The ingest log holds raw merchant names and amounts, so how long it keeps them is a
/// privacy rule, not a housekeeping detail. These cases pin both ends of it: too aggressive
/// and the evidence is gone before the user can show it to anyone, too lax and the log
/// quietly becomes a second, unbounded copy of their spending history.
final class IngestLogRetentionTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_770_000_000)

    private func age(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 24 * 60 * 60)
    }

    func testNewestEntryIsKept() {
        XCTAssertFalse(
            DatabaseService.shouldDropIngestEntry(index: 0, receivedAt: now, now: now)
        )
    }

    func testEntryJustInsideTheCountCapIsKept() {
        XCTAssertFalse(
            DatabaseService.shouldDropIngestEntry(
                index: IngestLogRetention.maxEntries - 1, receivedAt: age(1), now: now
            )
        )
    }

    func testEntryAtTheCountCapIsDropped() {
        XCTAssertTrue(
            DatabaseService.shouldDropIngestEntry(
                index: IngestLogRetention.maxEntries, receivedAt: age(1), now: now
            )
        )
    }

    func testRecentEntryPastTheAgeLimitIsDroppedEvenAtIndexZero() {
        // The count cap alone would keep this forever for a light user.
        XCTAssertTrue(
            DatabaseService.shouldDropIngestEntry(index: 0, receivedAt: age(15), now: now)
        )
    }

    func testEntryExactlyAtTheAgeLimitIsKept() {
        XCTAssertFalse(
            DatabaseService.shouldDropIngestEntry(index: 0, receivedAt: age(14), now: now)
        )
    }

    func testEntryOneSecondPastTheAgeLimitIsDropped() {
        let stale = now.addingTimeInterval(-(IngestLogRetention.maxAge + 1))
        XCTAssertTrue(
            DatabaseService.shouldDropIngestEntry(index: 0, receivedAt: stale, now: now)
        )
    }

    func testFutureDatedEntryIsNotDropped() {
        // A device whose clock jumped forward and back must not erase its own evidence.
        XCTAssertFalse(
            DatabaseService.shouldDropIngestEntry(
                index: 0, receivedAt: now.addingTimeInterval(3600), now: now
            )
        )
    }

    func testRetentionWindowIsTwoWeeks() {
        XCTAssertEqual(IngestLogRetention.maxAge, 14 * 24 * 60 * 60)
    }
}

/// The versioned schema is the thing that lets the next model change be a migration instead
/// of a failed launch. If a model is ever added to the container without being added here,
/// the version stops describing the store and the plan is silently useless — so the list is
/// asserted directly.
final class MoneyCitySchemaTests: XCTestCase {

    func testSchemaIsAtVersionOne() {
        XCTAssertEqual(MoneyCitySchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
    }

    func testSchemaV2IsTheLatestAndAddsRecapSnapshot() {
        XCTAssertEqual(MoneyCitySchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        let v1Names = MoneyCitySchemaV1.models.map { String(describing: $0) }
        let v2Names = MoneyCitySchemaV2.models.map { String(describing: $0) }
        XCTAssertEqual(Set(v1Names).subtracting(Set(v2Names)), [])
        XCTAssertEqual(Set(v2Names).subtracting(Set(v1Names)), ["RecapSnapshot"])
    }

    func testMigrationPlanListsEveryVersionInOrder() {
        // Compared by name rather than by metatype: existential metatype equality is
        // fragile across toolchains, and the name is what actually has to stay stable.
        XCTAssertEqual(
            MoneyCityMigrationPlan.schemas.map { String(describing: $0) },
            ["MoneyCitySchemaV1", "MoneyCitySchemaV2"]
        )
        XCTAssertEqual(MoneyCityMigrationPlan.stages.count, 1)
    }

    func testEveryPersistedModelIsListedExactlyOnce() {
        let names = MoneyCitySchemaV1.models.map { String(describing: $0) }
        XCTAssertEqual(names.count, Set(names).count, "a model is listed twice in the schema")

        let expected: Set<String> = [
            "Transaction",
            "CityEnrichment",
            "RecurringExpense",
            "IncomeSource",
            "CategoryBudget",
            "MerchantRule",
            "InstallmentPlan",
            "SavingsGoal",
            "IngestLogEntry"
        ]
        XCTAssertEqual(
            Set(names), expected,
            "a model was added or removed without updating the versioned schema"
        )
    }
}

@MainActor
final class StoreTransferRegressionTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func directory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeLegacyStore(in folder: URL) throws -> UUID {
        // An unversioned container represents the store opened by the old implementation.
        let schema = Schema(MoneyCitySchemaV1.models)
        let config = ModelConfiguration(schema: schema, url: folder.appendingPathComponent("default.store"))
        let container = try ModelContainer(for: schema, configurations: [config])
        let tx = Transaction(amount: 42.75, merchant: "Upgrade fixture", category: .food)
        container.mainContext.insert(tx)
        try container.mainContext.save()
        return tx.id
    }

    private func openVersioned(_ folder: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MoneyCitySchemaV1.self)
        let config = ModelConfiguration(schema: schema, url: folder.appendingPathComponent("default.store"))
        return try ModelContainer(for: schema, migrationPlan: MoneyCityMigrationPlan.self, configurations: [config])
    }

    func testCleanInstallAndLegacyUpgradePreserveData() throws {
        let fresh = try directory("fresh")
        let clean = try openVersioned(fresh)
        XCTAssertEqual(try clean.mainContext.fetchCount(FetchDescriptor<Transaction>()), 0)
        let legacy = try directory("legacy")
        let id = try writeLegacyStore(in: legacy)
        let upgraded = try openVersioned(legacy)
        let rows = try upgraded.mainContext.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(rows.map(\.id), [id])
        XCTAssertEqual(rows.first?.amount, 42.75)
        XCTAssertEqual(rows.first?.merchant, "Upgrade fixture")
    }

    func testMigrationIncludesCommittedWALAndPreservesSource() throws {
        let source = try directory("source")
        let destination = try directory("destination")
        let container = try openVersioned(source)
        let tx = Transaction(amount: 17.50, merchant: "WAL purchase", category: .coffee)
        container.mainContext.insert(tx)
        try container.mainContext.save()
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appendingPathComponent("default.store-wal").path))
        try StoreFileTransfer.migrateIfNeeded(to: destination, candidates: [source])
        let migrated = try openVersioned(destination)
        XCTAssertEqual(try migrated.mainContext.fetch(FetchDescriptor<Transaction>()).map(\.id), [tx.id])
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Transaction>()), 1)
    }

    func testExistingSmallStoreIsNeverReplaced() throws {
        let source = try directory("source")
        let destination = try directory("destination")
        _ = try writeLegacyStore(in: source)
        let original = Data("existing data".utf8)
        let target = destination.appendingPathComponent("default.store")
        try original.write(to: target)
        try StoreFileTransfer.migrateIfNeeded(to: destination, candidates: [source])
        XCTAssertEqual(try Data(contentsOf: target), original)
    }

    func testAmbiguousAndCorruptSourcesDoNotPublishAStore() throws {
        let a = try directory("a"), b = try directory("b"), destination = try directory("destination")
        for dir in [a, b] { try Data("corrupt".utf8).write(to: dir.appendingPathComponent("default.store")) }
        XCTAssertThrowsError(try StoreFileTransfer.migrateIfNeeded(to: destination, candidates: [a, b]))
        XCTAssertThrowsError(try StoreFileTransfer.migrateIfNeeded(to: destination, candidates: [a]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("default.store").path))
        XCTAssertEqual(try Data(contentsOf: a.appendingPathComponent("default.store")), Data("corrupt".utf8))
    }

    func testFailedRestoreReturnsEveryOriginalFile() throws {
        let destination = try directory("destination")
        for name in StoreFileTransfer.names {
            try Data(name.utf8).write(to: destination.appendingPathComponent(name))
        }
        let stage = root.appendingPathComponent("stage")
        try Data("replacement".utf8).write(to: stage)
        struct InjectedFailure: Error {}
        XCTAssertThrowsError(try StoreFileTransfer.replaceStore(in: destination, with: stage, beforeInstall: {
            // Simulate a partial installation before an I/O failure.
            try Data("partial".utf8).write(to: destination.appendingPathComponent("default.store"))
            throw InjectedFailure()
        }))
        for name in StoreFileTransfer.names {
            XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent(name)), Data(name.utf8))
        }
    }

    func testInterruptedRollbackCanBeRepeatedWithoutLosingOriginals() throws {
        let destination = try directory("destination")
        let rollback = destination.appendingPathComponent(StoreFileTransfer.rollbackName)
        try FileManager.default.createDirectory(at: rollback, withIntermediateDirectories: true)
        let original = Data("original".utf8)
        try original.write(to: rollback.appendingPathComponent("default.store"))
        try JSONEncoder().encode(["default.store"]).write(to: rollback.appendingPathComponent("manifest.json"))
        try Data("mixed".utf8).write(to: destination.appendingPathComponent("default.store"))
        try Data("stale journal".utf8).write(to: destination.appendingPathComponent("default.store-wal"))
        try StoreFileTransfer.recoverInterruptedRestore(in: destination)
        try StoreFileTransfer.recoverInterruptedRestore(in: destination)
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("default.store")), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("default.store-wal").path))
    }

    func testIncompleteRollbackKeepsManifestAndOriginalsForRetry() throws {
        let destination = try directory("destination")
        let rollback = destination.appendingPathComponent(StoreFileTransfer.rollbackName)
        try FileManager.default.createDirectory(at: rollback, withIntermediateDirectories: true)
        let original = Data("original".utf8)
        try original.write(to: rollback.appendingPathComponent("default.store"))
        let manifest = rollback.appendingPathComponent("manifest.json")
        try JSONEncoder().encode(["default.store", "default.store-wal"]).write(to: manifest)
        let live = destination.appendingPathComponent("default.store")
        try Data("current".utf8).write(to: live)
        XCTAssertThrowsError(try StoreFileTransfer.recoverInterruptedRestore(in: destination))
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.path))
        XCTAssertEqual(try Data(contentsOf: rollback.appendingPathComponent("default.store")), original)
        XCTAssertEqual(try Data(contentsOf: live), Data("current".utf8))
    }

    func testOrphanedJournalBlocksMigrationWithoutDeletingAnything() throws {
        let destination = try directory("destination"), source = try directory("source")
        _ = try writeLegacyStore(in: source)
        let wal = destination.appendingPathComponent("default.store-wal")
        try Data("retained journal".utf8).write(to: wal)
        XCTAssertThrowsError(try StoreFileTransfer.migrateIfNeeded(to: destination, candidates: [source]))
        XCTAssertEqual(try Data(contentsOf: wal), Data("retained journal".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("default.store").path))
    }

    func testMigrationIsIdempotentAndDeduplicatesSourcePaths() throws {
        let destination = try directory("destination"), source = try directory("source")
        let id = try writeLegacyStore(in: source)
        try StoreFileTransfer.migrateIfNeeded(to: destination, candidates: [source, source, destination])
        try StoreFileTransfer.migrateIfNeeded(to: destination, candidates: [source])
        let migrated = try openVersioned(destination)
        XCTAssertEqual(try migrated.mainContext.fetch(FetchDescriptor<Transaction>()).map(\.id), [id])
    }

    func testSnapshotRestoreReopensWithOriginalTransactions() throws {
        let source = try directory("source"), destination = try directory("destination")
        let id = try writeLegacyStore(in: source)
        _ = try writeLegacyStore(in: destination)
        let stage = root.appendingPathComponent("snapshot.store")
        try StoreFileTransfer.validatedSnapshot(from: source.appendingPathComponent("default.store"), to: stage)
        try StoreFileTransfer.replaceStore(in: destination, with: stage)
        let restored = try openVersioned(destination)
        XCTAssertEqual(try restored.mainContext.fetch(FetchDescriptor<Transaction>()).map(\.id), [id])
    }

    func testMerchantAndBuildingEditsRebuildCachedCityRows() {
        let tx = Transaction(amount: 20, merchant: "Original", category: .food)
        let cache = CityDerivedCache()
        var builds = 0
        func read() {
            _ = cache.monthTransactions(key: CityTransactionDigest.make([tx])) {
                builds += 1
                return [tx]
            }
        }
        read(); read()
        XCTAssertEqual(builds, 1)
        tx.merchant = "New merchant"
        read()
        XCTAssertEqual(builds, 2)
        tx.buildingIdRaw = "food_bistro"
        read()
        XCTAssertEqual(builds, 3)
        tx.note = "new classification hint"
        read()
        XCTAssertEqual(builds, 4)
    }
}
