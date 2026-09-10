import Foundation
import SQLite3

/// Keeps a few recent copies of the SwiftData store file, so a launch that cannot open it
/// has somewhere to go back to.
///
/// The store is one file. Every time a model gains a property, the next launch asks iOS to
/// reshape that file in place — and the moment it starts, the old shape is gone. So a copy
/// is only worth anything if it is taken *before the container opens*, which is why all of
/// this runs at the very top of `DatabaseService.init` rather than anywhere more natural.
///
/// This is not the same thing as the JSON export. The export is the user's data in a form
/// they can read, keep and move elsewhere. A snapshot is the app's own file, kept so the app
/// can put itself back together without anyone opening a Mac.
public enum StoreSnapshotService {

    /// How many snapshots to keep. Three covers "the build before last still worked" without
    /// quietly turning into a second copy of the database for every version ever installed.
    public static let keepCount = 3

    private static let lastBuildKey = "snapshot_last_build"
    private static let pendingRestoreKey = "snapshot_pending_restore"
    private static let knownCountKey = "snapshot_known_transaction_count"

    // MARK: - Locations

    /// The files SwiftData actually writes. The journal and shared-memory files are part of
    /// the database: copying `default.store` alone can capture a torn state.
    public static let storeFileNames = ["default.store", "default.store-wal", "default.store-shm"]

    public static func applicationSupportDirectory() -> URL? {
        DatabaseService.authoritativeStoreDirectoryURL()
    }

    public static func snapshotsDirectory() -> URL? {
        applicationSupportDirectory()?.appendingPathComponent("Snapshots", isDirectory: true)
    }

    // MARK: - Describing a snapshot

    public struct Snapshot: Identifiable, Equatable {
        public let id: String          // the folder name, which is also its sort key
        public let url: URL
        public let takenAt: Date
        public let build: String
        public let version: String
        public let transactionCount: Int?
        public let byteSize: Int64

        public var displayDate: String {
            let f = DateFormatter()
            f.dateFormat = "dd/MM/yyyy HH:mm"
            return f.string(from: takenAt)
        }
    }

    private struct Metadata: Codable {
        let takenAt: Date
        let build: String
        let version: String
        let transactionCount: Int?
    }

    // MARK: - Naming

    /// Folder names sort chronologically as text, so "newest first" never needs to parse a
    /// date back out of a filename.
    public static func folderName(for date: Date, build: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        let safeBuild = build.isEmpty ? "0" : build.replacingOccurrences(of: "/", with: "-")
        return f.string(from: date) + "-build" + safeBuild
    }

    /// Which snapshots to delete, given every folder name present, newest last.
    ///
    /// Pure so the retention rule can be tested without touching a disk: sort by name, keep
    /// the newest `keepCount`, drop the rest.
    public static func foldersToPrune(_ names: [String], keep: Int = keepCount, excluding: String? = nil) -> [String] {
        let eligible = names.filter { $0 != excluding }
        guard eligible.count > keep else { return [] }
        return Array(eligible.sorted(by: >).dropFirst(keep))
    }

    // MARK: - Taking one

    /// Copies the store aside when the build has changed since the last time this ran.
    ///
    /// Only on a build change: opening the app cannot alter the file's shape, so a snapshot
    /// per launch would be pure noise. A new build is exactly the moment a migration can run.
    @discardableResult
    public static func snapshotIfBuildChanged(
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> URL? {
        let build = currentBuild()
        let previous = defaults.string(forKey: lastBuildKey)
        guard previous != build else { return nil }

        let url = takeSnapshot(build: build, defaults: defaults, now: now)
        let storeExists = applicationSupportDirectory().map {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("default.store").path)
        } ?? false
        // Retry a failed backup on the next launch; first install has nothing to preserve.
        if url != nil || !storeExists { defaults.set(build, forKey: lastBuildKey) }
        return url
    }

    @discardableResult
    public static func takeSnapshot(
        build: String = currentBuild(),
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        excludingFromPrune: String? = nil
    ) -> URL? {
        let fm = FileManager.default
        guard let support = applicationSupportDirectory(),
              let snapshots = snapshotsDirectory() else { return nil }

        let present = storeFileNames.filter {
            fm.fileExists(atPath: support.appendingPathComponent($0).path)
        }
        guard !present.isEmpty else { return nil }   // nothing to copy yet

        let folder = snapshots.appendingPathComponent(
            folderName(for: now, build: build), isDirectory: true
        )
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent("default.store")
            guard !fm.fileExists(atPath: destination.path) else { return nil }
            try StoreFileTransfer.validatedSnapshot(
                from: support.appendingPathComponent("default.store"), to: destination)
            let meta = Metadata(
                takenAt: now,
                build: build,
                version: currentVersion(),
                transactionCount: defaults.object(forKey: knownCountKey) as? Int
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(meta).write(to: folder.appendingPathComponent("meta.json"))
        } catch {
            try? fm.removeItem(at: folder)
            MoneyCityLog.error("snapshot failed: \(error)")
            return nil
        }

        prune(excluding: excludingFromPrune)
        return folder
    }

    /// Recorded after a successful open so the *next* snapshot can say how much it holds.
    /// A snapshot cannot count its own rows without opening it, and opening it would migrate
    /// the very file it is meant to preserve.
    public static func recordTransactionCount(_ count: Int, defaults: UserDefaults = .standard) {
        defaults.set(count, forKey: knownCountKey)
    }

    public static func prune(excluding: String? = nil) {
        let fm = FileManager.default
        guard let snapshots = snapshotsDirectory(),
              let names = try? fm.contentsOfDirectory(atPath: snapshots.path) else { return }
        let folders = names.filter { !$0.hasPrefix(".") }
        for name in foldersToPrune(folders, excluding: excluding) {
            try? fm.removeItem(at: snapshots.appendingPathComponent(name))
        }
    }

    // MARK: - Reading them back

    public static func available() -> [Snapshot] {
        let fm = FileManager.default
        var searchDirs: [URL] = []
        if let dir = snapshotsDirectory() {
            searchDirs.append(dir)
        }
        if let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            searchDirs.append(appSupport.appendingPathComponent("Snapshots", isDirectory: true))
            searchDirs.append(appSupport.appendingPathComponent("StoreSnapshots", isDirectory: true))
        }
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.moneycity.app") {
            let groupAppSupport = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
            searchDirs.append(groupAppSupport.appendingPathComponent("Snapshots", isDirectory: true))
            searchDirs.append(groupAppSupport.appendingPathComponent("StoreSnapshots", isDirectory: true))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var seenIds = Set<String>()
        var results: [Snapshot] = []

        for dir in searchDirs {
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for name in names.filter({ !$0.hasPrefix(".") }) {
                guard !seenIds.contains(name) else { continue }
                let folder = dir.appendingPathComponent(name, isDirectory: true)
                guard fm.fileExists(atPath: folder.appendingPathComponent("default.store").path) else { continue }

                seenIds.insert(name)
                var takenAt = Date.distantPast
                var build = "?"
                var version = "?"
                var count: Int? = nil
                if let data = try? Data(contentsOf: folder.appendingPathComponent("meta.json")),
                   let meta = try? decoder.decode(Metadata.self, from: data) {
                    takenAt = meta.takenAt
                    build = meta.build
                    version = meta.version
                    count = meta.transactionCount
                }

                var bytes: Int64 = 0
                for file in storeFileNames {
                    let attrs = try? fm.attributesOfItem(atPath: folder.appendingPathComponent(file).path)
                    bytes += (attrs?[.size] as? Int64) ?? 0
                }

                results.append(Snapshot(
                    id: name, url: folder, takenAt: takenAt,
                    build: build, version: version,
                    transactionCount: count, byteSize: bytes
                ))
            }
        }
        return results.sorted(by: { $0.id > $1.id })
    }

    // MARK: - Restoring

    /// Restoring is deliberately a two-step: the choice is recorded now, the files are
    /// swapped at the top of the next launch.
    public static func requestRestore(_ snapshot: Snapshot, defaults: UserDefaults = .standard) {
        defaults.set(snapshot.id, forKey: pendingRestoreKey)
    }

    public static func pendingRestoreId(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: pendingRestoreKey)
    }

    public static func cancelPendingRestore(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingRestoreKey)
    }

    /// Applies a requested restore. Call before the container is created; does nothing if
    /// none was requested.
    @discardableResult
    public static func applyPendingRestoreIfNeeded(defaults: UserDefaults = .standard) -> Bool {
        guard let id = pendingRestoreId(defaults: defaults) else { return false }
        let fm = FileManager.default
        guard let support = applicationSupportDirectory() else { return false }

        var snapshotFolder: URL? = nil
        var searchDirs: [URL] = []
        if let dir = snapshotsDirectory() { searchDirs.append(dir) }
        if let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            searchDirs.append(appSupport.appendingPathComponent("Snapshots", isDirectory: true))
            searchDirs.append(appSupport.appendingPathComponent("StoreSnapshots", isDirectory: true))
        }
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.moneycity.app") {
            let groupAppSupport = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
            searchDirs.append(groupAppSupport.appendingPathComponent("Snapshots", isDirectory: true))
            searchDirs.append(groupAppSupport.appendingPathComponent("StoreSnapshots", isDirectory: true))
        }
        for dir in searchDirs {
            let candidate = dir.appendingPathComponent(id, isDirectory: true)
            if fm.fileExists(atPath: candidate.appendingPathComponent("default.store").path) {
                snapshotFolder = candidate
                break
            }
        }
        guard let folder = snapshotFolder else {
            MoneyCityLog.error("pending restore \(id) is missing")
            return false
        }

        let stagingFolder = support.appendingPathComponent("RestoreStaging-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: stagingFolder) }
        do {
            try fm.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
            let stagedStore = stagingFolder.appendingPathComponent("default.store")
            try StoreFileTransfer.validatedSnapshot(
                from: folder.appendingPathComponent("default.store"), to: stagedStore)
            takeSnapshot(build: currentBuild() + "-prerestore", defaults: defaults, excludingFromPrune: id)
            try StoreFileTransfer.replaceStore(in: support, with: stagedStore)
            defaults.removeObject(forKey: pendingRestoreKey)
            MoneyCityLog.debug("restored store from snapshot \(id)")
            return true
        } catch {
            MoneyCityLog.error("restore failed; source and rollback data retained: \(error)")
            return false
        }
    }

    // MARK: - Build identity

    public static func currentBuild() -> String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
    }

    public static func currentVersion() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }
}

/// File operations run before SwiftData opens the destination. SQLite's backup API
/// includes committed WAL contents; a byte copy of the main file alone does not.
enum StoreFileTransfer {
    enum Failure: Error {
        case ambiguousSources, orphanedSidecars, invalidStore, sqlite(Int32), incompleteRollback
    }

    static let names = ["default.store", "default.store-wal", "default.store-shm"]
    static let rollbackName = "PendingStoreRollback"

    static func migrateIfNeeded(to destination: URL, candidates: [URL]) throws {
        let fm = FileManager.default
        let target = destination.appendingPathComponent(names[0])
        // Size cannot tell us whether a store contains valuable user data.
        guard !fm.fileExists(atPath: target.path) else { return }
        guard !names.dropFirst().contains(where: {
            fm.fileExists(atPath: destination.appendingPathComponent($0).path)
        }) else { throw Failure.orphanedSidecars }
        let canonical = destination.resolvingSymlinksInPath().standardizedFileURL
        let sources = Set(candidates.map { $0.resolvingSymlinksInPath().standardizedFileURL })
            .filter { $0 != canonical && fm.fileExists(atPath: $0.appendingPathComponent(names[0]).path) }
        guard sources.count <= 1 else { throw Failure.ambiguousSources }
        guard let source = sources.first else { return }
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let stage = destination.appendingPathComponent(".StoreMigration-\(UUID().uuidString)")
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }
        let stagedStore = stage.appendingPathComponent(names[0])
        try validatedSnapshot(from: source.appendingPathComponent(names[0]), to: stagedStore)
        // One complete, closed SQLite file is published on the same filesystem.
        // No existing destination or source file is removed.
        try fm.moveItem(at: stagedStore, to: target)
    }

    static func validatedSnapshot(from source: URL, to destination: URL) throws {
        var input: OpaquePointer?
        var output: OpaquePointer?
        defer {
            if let input { sqlite3_close(input) }
            if let output { sqlite3_close(output) }
        }
        let opened = sqlite3_open_v2(source.path, &input, SQLITE_OPEN_READONLY, nil)
        guard opened == SQLITE_OK else { throw Failure.sqlite(opened) }
        let created = sqlite3_open_v2(destination.path, &output, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard created == SQLITE_OK else { throw Failure.sqlite(created) }
        sqlite3_busy_timeout(input, 1000)
        guard let backup = sqlite3_backup_init(output, "main", input, "main") else {
            throw Failure.sqlite(sqlite3_errcode(output))
        }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE, finish == SQLITE_OK else {
            throw Failure.sqlite(step == SQLITE_DONE ? finish : step)
        }
        // A self-contained result has no WAL dependency when it is renamed.
        guard sqlite3_exec(output, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else {
            throw Failure.sqlite(sqlite3_errcode(output))
        }
        guard try scalar(output, "PRAGMA quick_check") == "ok",
              try scalar(output, "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='Z_METADATA'") == "1" else {
            throw Failure.invalidStore
        }
    }

    private static func scalar(_ db: OpaquePointer?, _ sql: String) throws -> String {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0) else {
            throw Failure.sqlite(sqlite3_errcode(db))
        }
        return String(cString: value)
    }

    /// Copies the old set before writing a durable rollback manifest. An interrupted
    /// replacement is rolled back on next launch, before any container can open it.
    static func replaceStore(in support: URL, with stagedStore: URL,
                             beforeInstall: () throws -> Void = {}) throws {
        let fm = FileManager.default
        try recoverInterruptedRestore(in: support)
        let rollback = support.appendingPathComponent(rollbackName, isDirectory: true)
        try fm.createDirectory(at: rollback, withIntermediateDirectories: true)
        let originals = names.filter { fm.fileExists(atPath: support.appendingPathComponent($0).path) }
        for name in originals {
            try fm.copyItem(at: support.appendingPathComponent(name), to: rollback.appendingPathComponent(name))
        }
        // No destination mutation is permitted before this atomic marker exists.
        try JSONEncoder().encode(originals).write(to: rollback.appendingPathComponent("manifest.json"), options: .atomic)
        do {
            for name in names {
                let url = support.appendingPathComponent(name)
                if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
            }
            try beforeInstall()
            try fm.moveItem(at: stagedStore, to: support.appendingPathComponent(names[0]))
            // Removing the marker commits; a crash before this point restores the old set.
            try fm.removeItem(at: rollback.appendingPathComponent("manifest.json"))
        } catch {
            try recoverInterruptedRestore(in: support)
            throw error
        }
        try? fm.removeItem(at: rollback)
    }

    static func recoverInterruptedRestore(in support: URL) throws {
        let fm = FileManager.default
        let rollback = support.appendingPathComponent(rollbackName, isDirectory: true)
        guard fm.fileExists(atPath: rollback.path) else { return }
        let manifest = rollback.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifest.path) else {
            // Either preparation never touched the live set, or replacement committed.
            try fm.removeItem(at: rollback)
            return
        }
        let originals = try JSONDecoder().decode([String].self, from: Data(contentsOf: manifest))
        guard Set(originals).isSubset(of: Set(names)), originals.allSatisfy({
            fm.fileExists(atPath: rollback.appendingPathComponent($0).path)
        }) else { throw Failure.incompleteRollback }
        for name in names {
            let live = support.appendingPathComponent(name)
            if fm.fileExists(atPath: live.path) { try fm.removeItem(at: live) }
            if originals.contains(name) {
                // Copy, never move: every original survives another interrupted rollback.
                try fm.copyItem(at: rollback.appendingPathComponent(name), to: live)
            }
        }
        try fm.removeItem(at: manifest)
        try? fm.removeItem(at: rollback)
    }
}
