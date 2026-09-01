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
        try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
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
    public static func foldersToPrune(_ names: [String], keep: Int = keepCount) -> [String] {
        guard names.count > keep else { return [] }
        return Array(names.sorted(by: >).dropFirst(keep))
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
        now: Date = Date()
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

        prune()
        return folder
    }

    /// Recorded after a successful open so the *next* snapshot can say how much it holds.
    /// A snapshot cannot count its own rows without opening it, and opening it would migrate
    /// the very file it is meant to preserve.
    public static func recordTransactionCount(_ count: Int, defaults: UserDefaults = .standard) {
        defaults.set(count, forKey: knownCountKey)
    }

    public static func prune() {
        let fm = FileManager.default
        guard let snapshots = snapshotsDirectory(),
              let names = try? fm.contentsOfDirectory(atPath: snapshots.path) else { return }
        let folders = names.filter { !$0.hasPrefix(".") }
        for name in foldersToPrune(folders) {
            try? fm.removeItem(at: snapshots.appendingPathComponent(name))
        }
    }

    // MARK: - Reading them back

    public static func available() -> [Snapshot] {
        let fm = FileManager.default
        guard let dir = snapshotsDirectory(),
              let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return names.filter { !$0.hasPrefix(".") }.sorted(by: >).compactMap { name in
            let folder = dir.appendingPathComponent(name, isDirectory: true)
            guard fm.fileExists(atPath: folder.appendingPathComponent("default.store").path) else { return nil }

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

            return Snapshot(
                id: name, url: folder, takenAt: takenAt,
                build: build, version: version,
                transactionCount: count, byteSize: bytes
            )
        }
    }

    // MARK: - Restoring

    /// Restoring is deliberately a two-step: the choice is recorded now, the files are
    /// swapped at the top of the next launch.
    ///
    /// SwiftData holds the store open for the life of the process. Overwriting the file
    /// underneath a live container is how a merely-empty database becomes a corrupt one, so
    /// the swap happens at the only moment nothing has it open.
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
        guard let support = applicationSupportDirectory(),
              let dir = snapshotsDirectory() else { return false }
        let folder = dir.appendingPathComponent(id, isDirectory: true)
        guard fm.fileExists(atPath: folder.appendingPathComponent("default.store").path) else {
            MoneyCityLog.error("pending restore \(id) is missing")
            return false
        }

        // The file being replaced is itself snapshotted first. A restore is a decision made
        // in a hurry, and the state being discarded may be the only copy of today's work.
        takeSnapshot(build: currentBuild() + "-prerestore", defaults: defaults)

        do {
            for name in storeFileNames {
                let live = support.appendingPathComponent(name)
                if fm.fileExists(atPath: live.path) { try fm.removeItem(at: live) }
                let source = folder.appendingPathComponent(name)
                if fm.fileExists(atPath: source.path) {
                    try fm.copyItem(at: source, to: live)
                }
            }
            MoneyCityLog.debug("restored store from snapshot \(id)")
            return true
        } catch {
            MoneyCityLog.error("restore failed: \(error)")
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
