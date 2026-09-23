#if DEBUG && !SWIFT_PACKAGE
import CloudKit
import CryptoKit
import SwiftUI

/// Phase 1 only. Dedicated test zones and cache; never reads or writes the personal ledger.
/// Manual sync makes offline/relaunch behavior observable without background timing assumptions.
@MainActor
final class SharedCloudLab: ObservableObject, CKSyncEngineDelegate {
    static let shared = SharedCloudLab()
    static let zonePrefix = "SPENT.SharedLab."
    let container = CKContainer(identifier: "iCloud.com.moneycity.app")

    struct Space: Identifiable {
        let zone: CKRecordZone
        let scope: CKDatabase.Scope
        var id: String { "\(scope.rawValue):\(zone.zoneID.ownerName):\(zone.zoneID.zoneName)" }
    }

    private struct DiskState: Codable {
        var records: [String: Data] = [:]
        var dirty: [String: String] = [:]
        var scopes: [String: Int] = [:]
        var engines: [String: CKSyncEngine.State.Serialization] = [:]
    }

    @Published var presentRequested = false
    @Published var spaces: [Space] = []
    @Published var selectedID: String?
    @Published var rows: [CKRecord] = []
    @Published var status = "Connect to iCloud to begin. Test data only."
    @Published var busy = false
    @Published var pendingCount = 0
    @Published var invitation: CKShare.Metadata?
    private var disk = DiskState()
    private var diskURL: URL?
    private var engines: [Int: CKSyncEngine] = [:]
    private var accountID: CKRecord.ID?
    private var halted = false

    var selected: Space? { spaces.first { $0.id == selectedID } }
    private func key(_ id: CKRecord.ID) -> String {
        "\(id.zoneID.ownerName)|\(id.zoneID.zoneName)|\(id.recordName)"
    }
    private func archive(_ record: CKRecord) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: record, requiringSecureCoding: true)
    }
    private func record(_ data: Data) throws -> CKRecord {
        guard let record = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.self, from: data) else {
            throw LabError.invalidCache
        }
        return record
    }
    private func persist() throws {
        guard let diskURL else { throw LabError.notConnected }
        try JSONEncoder().encode(disk).write(to: diskURL, options: .atomic)
        pendingCount = disk.dirty.count
    }
    private func publishRows() throws {
        guard let selected else { rows = []; return }
        rows = try disk.records.values.map(record).filter {
            $0.recordID.zoneID == selected.zone.zoneID && ($0["isDeleted"] as? Int64 ?? 0) == 0
        }.sorted { $0.recordID.recordName < $1.recordID.recordName }
    }
    func select(_ id: String?) {
        selectedID = id
        do { try publishRows() } catch { fail(error) }
    }
    func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        status = "Working…"
        Task {
            defer { busy = false }
            do {
                try await action()
                if !halted && status == "Working…" { status = "Ready · \(disk.dirty.count) pending changes" }
            } catch { status = error.localizedDescription }
        }
    }
    private func fail(_ error: Error) {
        halted = true
        status = "Stopped to preserve local data: \(error.localizedDescription). Reopen the app."
        engines.removeAll()
    }

    func connect() async throws {
        guard !halted else { throw LabError.reopenRequired }
        guard try await container.accountStatus() == .available else { throw LabError.noAccount }
        let current = try await container.userRecordID()
        if let accountID, accountID != current {
            rows = []; spaces = []; selectedID = nil
            fail(LabError.accountChanged)
            throw LabError.accountChanged
        }
        guard accountID == nil else { return }
        // The lab is Debug / Development only. Account caches never share engine tokens.
        let hash = SHA256.hash(data: Data(current.recordName.utf8)).map { String(format: "%02x", $0) }.joined()
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
            .appendingPathComponent("SharedCloudLab/Development/\(hash)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("state.json")
        let restored = FileManager.default.fileExists(atPath: url.path)
            ? try JSONDecoder().decode(DiskState.self, from: Data(contentsOf: url)) : DiskState()
        // Validate the cache before allowing writes. Never silently reset unreadable state.
        for data in restored.records.values { _ = try record(data) }
        disk = restored; diskURL = url; accountID = current
        for scope: CKDatabase.Scope in [.private, .shared] {
            var configuration = CKSyncEngine.Configuration(database: container.database(with: scope),
                stateSerialization: disk.engines[String(scope.rawValue)], delegate: self)
            configuration.automaticallySync = false
            let engine = CKSyncEngine(configuration)
            engines[scope.rawValue] = engine
            // Local revisions recover a save interrupted before engine state serialization.
            for id in disk.dirty.keys where disk.scopes[id] == scope.rawValue {
                if let data = disk.records[id] {
                    engine.state.add(pendingRecordZoneChanges: [.saveRecord(try record(data).recordID)])
                }
            }
        }
        pendingCount = disk.dirty.count
    }

    func refresh() async throws {
        try await connect()
        var found: [Space] = []
        for scope: CKDatabase.Scope in [.private, .shared] {
            let zones = try await container.database(with: scope).allRecordZones()
            found += zones.filter { $0.zoneID.zoneName.hasPrefix(Self.zonePrefix) }.map { Space(zone: $0, scope: scope) }
            try await engines[scope.rawValue]?.fetchChanges()
        }
        guard !halted else { throw LabError.reopenRequired }
        spaces = found.sorted { $0.id < $1.id }
        if !spaces.contains(where: { $0.id == selectedID }) { selectedID = spaces.first?.id }
        try publishRows()
    }

    func createSpace() async throws {
        try await connect()
        let zone = CKRecordZone(zoneName: Self.zonePrefix + UUID().uuidString)
        _ = try await container.privateCloudDatabase.save(zone)
        let share = CKShare(recordZoneID: zone.zoneID)
        share[CKShare.SystemFieldKey.title] = "SPENT Shared Lab" as CKRecordValue
        share.publicPermission = .none
        _ = try await container.privateCloudDatabase.save(share)
        try await refresh()
        select(spaces.first { $0.zone.zoneID == zone.zoneID }?.id)
    }

    func sharingRecord() async throws -> CKShare {
        try await connect()
        guard let selected, let shareID = selected.zone.share?.recordID else { throw LabError.noSpace }
        guard let share = try await container.database(with: selected.scope).record(for: shareID) as? CKShare else {
            throw LabError.noSpace
        }
        return share
    }

    func acceptInvitation(url: String) async throws {
        try await connect()
        let metadata: CKShare.Metadata
        if let invitation {
            metadata = invitation
        } else {
            guard let link = URL(string: url), link.scheme == "https" else { throw LabError.invalidInvitation }
            guard let result = try await container.shareMetadatas(for: [link])[link] else { throw LabError.invalidInvitation }
            metadata = try result.get()
        }
        guard metadata.containerIdentifier == container.containerIdentifier,
              metadata.share.recordID.zoneID.zoneName.hasPrefix(Self.zonePrefix) else { throw LabError.invalidInvitation }
        guard let result = try await container.accept([metadata])[metadata] else { throw LabError.invalidInvitation }
        _ = try result.get()
        invitation = nil
        try await refresh()
        select(spaces.first { $0.zone.zoneID == metadata.share.recordID.zoneID }?.id)
    }

    /// One fixed sample amount avoids accidentally turning the spike into a production ledger.
    func saveSample(existing: CKRecord? = nil, deleted: Bool = false) throws {
        guard !halted, let selected, let engine = engines[selected.scope.rawValue] else { throw LabError.notConnected }
        let item = try existing.map { try record(archive($0)) }
            ?? CKRecord(recordType: "SharedLabExpense", recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: selected.zone.zoneID))
        guard item.recordID.zoneID == selected.zone.zoneID else { throw LabError.noSpace }
        let revision = UUID().uuidString
        item["localRevision"] = revision as CKRecordValue
        item["amountMinor"] = ((item["amountMinor"] as? Int64 ?? 0) + (deleted ? 0 : 100)) as CKRecordValue
        item["currency"] = "ILS" as CKRecordValue
        item["isDeleted"] = (deleted ? Int64(1) : Int64(0)) as CKRecordValue
        let id = key(item.recordID)
        let previous = disk
        disk.records[id] = try archive(item)
        disk.dirty[id] = revision
        disk.scopes[id] = selected.scope.rawValue
        do { try persist() } catch { disk = previous; throw error }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(item.recordID)])
        try publishRows()
    }

    func sync() async throws {
        try await connect()
        for scope: CKDatabase.Scope in [.private, .shared] {
            try await engines[scope.rawValue]?.sendChanges()
        }
        try await refresh()
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard !halted else { return }
        do {
            switch event {
            case .stateUpdate(let update):
                disk.engines[String(syncEngine.database.databaseScope.rawValue)] = update.stateSerialization
            case .accountChange(let change):
                if case .signIn = change.changeType { return }
                rows = []; spaces = []; selectedID = nil
                fail(LabError.accountChanged)
                return
            case .fetchedRecordZoneChanges(let changes):
                for modification in changes.modifications {
                    let item = modification.record
                    guard item.recordType == "SharedLabExpense", item.recordID.zoneID.zoneName.hasPrefix(Self.zonePrefix) else { continue }
                    let id = key(item.recordID)
                    // Preserve unsent edits until conditional upload resolves the conflict.
                    if disk.dirty[id] == nil || (item["isDeleted"] as? Int64) == 1 {
                        disk.records[id] = try archive(item)
                        disk.scopes[id] = syncEngine.database.databaseScope.rawValue
                        if (item["isDeleted"] as? Int64) == 1 {
                            disk.dirty[id] = nil
                            syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(item.recordID)])
                        }
                    }
                }
                for deletion in changes.deletions { remove(deletion.recordID, engine: syncEngine) }
            case .fetchedDatabaseChanges(let changes):
                for deletion in changes.deletions {
                    for data in Array(disk.records.values) {
                        let item = try record(data)
                        if item.recordID.zoneID == deletion.zoneID { remove(item.recordID, engine: syncEngine) }
                    }
                }
            case .sentRecordZoneChanges(let changes):
                for item in changes.savedRecords {
                    let id = key(item.recordID)
                    if disk.dirty[id] == item["localRevision"] as? String {
                        disk.records[id] = try archive(item); disk.dirty[id] = nil
                    } else if let data = disk.records[id], disk.dirty[id] != nil {
                        // Keep newer local fields, but advance their server change tag.
                        let local = try record(data)
                        for field in local.allKeys() { item[field] = local[field] }
                        disk.records[id] = try archive(item)
                        syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(item.recordID)])
                    }
                }
                for failure in changes.failedRecordSaves {
                    let id = key(failure.record.recordID)
                    if failure.error.code == .serverRecordChanged, let server = failure.error.serverRecord {
                        let local = try disk.records[id].map(record)
                        if (local?["isDeleted"] as? Int64) == 1, (server["isDeleted"] as? Int64) != 1 {
                            server["isDeleted"] = Int64(1) as CKRecordValue
                            server["localRevision"] = disk.dirty[id] as CKRecordValue?
                            disk.records[id] = try archive(server)
                            syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(server.recordID)])
                        } else {
                            disk.records[id] = try archive(server); disk.dirty[id] = nil
                            syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(server.recordID)])
                            status = "Concurrent edit: server version kept (lab policy)."
                        }
                    } else {
                        // No automatic recreation of a missing zone or revoked record.
                        status = failure.error.localizedDescription
                    }
                }
            default: return
            }
            try persist()
            try publishRows()
        } catch { fail(error) }
    }

    private func remove(_ id: CKRecord.ID, engine: CKSyncEngine) {
        disk.records[key(id)] = nil; disk.dirty[key(id)] = nil; disk.scopes[key(id)] = nil
        engine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                  syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard !halted else { return nil }
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        var records: [CKRecord.ID: CKRecord] = [:]
        do {
            for id in disk.dirty.keys where disk.scopes[id] == syncEngine.database.databaseScope.rawValue {
                if let data = disk.records[id] { let item = try record(data); records[item.recordID] = item }
            }
        } catch { fail(error); return nil }
        let snapshot = records
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { snapshot[$0] }
    }

    enum LabError: LocalizedError {
        case noAccount, notConnected, noSpace, invalidCache, invalidInvitation, accountChanged, reopenRequired
        var errorDescription: String? {
            switch self {
            case .noAccount: return "Sign in to iCloud on this device first."
            case .notConnected: return "Connect to the lab before editing."
            case .noSpace: return "Select a shared test space with an active share."
            case .invalidCache: return "The lab cache could not be read; it has not been overwritten."
            case .invalidInvitation: return "Use an invitation to a SPENT Shared Lab test space."
            case .accountChanged: return "iCloud account changed. Reopen the app; previous pending data is preserved separately."
            case .reopenRequired: return "The lab is stopped. Reopen the app before continuing."
            }
        }
    }
}
#endif
