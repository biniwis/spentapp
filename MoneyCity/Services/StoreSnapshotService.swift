import Foundation

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
        // Recorded even when nothing was copied — a first install has no store to snapshot,
        // and retrying that on every launch would achieve nothing.
        defaults.set(build, forKey: lastBuildKey)
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
            for name in present {
                let dest = folder.appendingPathComponent(name)
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: support.appendingPathComponent(name), to: dest)
            }
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
        defaults.removeObject(forKey: pendingRestoreKey)

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

        // 1. Stage the snapshot files first to verify integrity
        let stagingFolder = support.appendingPathComponent("RestoreStaging-\(UUID().uuidString)", isDirectory: true)
        do {
            try fm.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
            for name in storeFileNames {
                let src = folder.appendingPathComponent(name)
                if fm.fileExists(atPath: src.path) {
                    try fm.copyItem(at: src, to: stagingFolder.appendingPathComponent(name))
                }
            }
            let stagedStore = stagingFolder.appendingPathComponent("default.store")
            let attrs = try fm.attributesOfItem(atPath: stagedStore.path)
            let size = (attrs[.size] as? Int64) ?? 0
            guard size > 0 else {
                MoneyCityLog.error("restore staged default.store is 0 bytes; aborting")
                try? fm.removeItem(at: stagingFolder)
                return false
            }
        } catch {
            MoneyCityLog.error("failed staging restore source files: \(error)")
            try? fm.removeItem(at: stagingFolder)
            return false
        }

        // 2. The file being replaced is itself snapshotted first, protecting `id` from being pruned!
        takeSnapshot(build: currentBuild() + "-prerestore", defaults: defaults, excludingFromPrune: id)

        // 3. Rollback safety: move live files to a rollback folder before replacing
        let rollbackFolder = support.appendingPathComponent("RestoreRollback-\(UUID().uuidString)", isDirectory: true)
        var movedLiveFiles: [String] = []
        do {
            try fm.createDirectory(at: rollbackFolder, withIntermediateDirectories: true)
            for name in storeFileNames {
                let live = support.appendingPathComponent(name)
                if fm.fileExists(atPath: live.path) {
                    let dest = rollbackFolder.appendingPathComponent(name)
                    try fm.moveItem(at: live, to: dest)
                    movedLiveFiles.append(name)
                }
            }

            // 4. Move staged files into live position
            for name in storeFileNames {
                let staged = stagingFolder.appendingPathComponent(name)
                if fm.fileExists(atPath: staged.path) {
                    let live = support.appendingPathComponent(name)
                    try fm.moveItem(at: staged, to: live)
                }
            }

            // Verify live store exists and is non-empty
            let liveStore = support.appendingPathComponent("default.store")
            guard fm.fileExists(atPath: liveStore.path) else {
                throw NSError(domain: "StoreSnapshotService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Live store missing after swap"])
            }

            // Cleanup staging & rollback on success
            try? fm.removeItem(at: stagingFolder)
            try? fm.removeItem(at: rollbackFolder)
            MoneyCityLog.debug("restored store from snapshot \(id)")
            return true
        } catch {
            MoneyCityLog.error("restore failed: \(error). Rolling back.")
            // Rollback
            for name in movedLiveFiles {
                let dest = support.appendingPathComponent(name)
                let src = rollbackFolder.appendingPathComponent(name)
                if !fm.fileExists(atPath: dest.path) && fm.fileExists(atPath: src.path) {
                    try? fm.moveItem(at: src, to: dest)
                }
            }
            try? fm.removeItem(at: stagingFolder)
            try? fm.removeItem(at: rollbackFolder)
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
