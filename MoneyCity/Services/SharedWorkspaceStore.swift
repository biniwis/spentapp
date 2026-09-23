#if !SWIFT_PACKAGE
import CloudKit
import CryptoKit
import SwiftUI
import SwiftData

@MainActor
final class SharedWorkspaceStore: ObservableObject, CKSyncEngineDelegate {
    static let shared = SharedWorkspaceStore()
    static let zonePrefix = "SPENT.Shared."
    let cloud = CKContainer(identifier: "iCloud.com.moneycity.app")
    @Published private(set) var spaces: [SharedSpace] = []
    @Published private(set) var members: [SharedMember] = []
    @Published private(set) var expenses: [SharedExpense] = []
    @Published private(set) var pendingCount = 0
    @Published private(set) var conflictCount = 0
    @Published private(set) var demo = false
    @Published var activeSpaceID: UUID?
    @Published var showSetup = false
    @Published var busy = false
    @Published var errorMessage: String?
    @Published var invitation: CKShare.Metadata?
    private(set) var database: SharedDatabaseService?
    private var engines: [Int: CKSyncEngine] = [:]
    private var accountName: String?
    private var writableSpaces = Set<UUID>()
    private var revokedSpaces = Set<UUID>()
    private var unsupportedSpaces = Set<UUID>()
    private var accountObserver: NSObjectProtocol?
    private var connecting = false
    private var stopped = false

    var activeSpace: SharedSpace? { spaces.first { $0.id == activeSpaceID } }
    func text(_ he: String, _ en: String) -> String { AppLanguage.current == .hebrew ? he : en }
    private func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func myMemberID(in space: UUID) -> String { hash(space.uuidString + (accountName ?? "")) }
    func canWrite(_ id: UUID) -> Bool {
        !stopped && !unsupportedSpaces.contains(id) && !revokedSpaces.contains(id) && writableSpaces.contains(id)
    }
    func select(_ id: UUID?) {
        guard id == nil || spaces.contains(where: { $0.id == id }) else { return }
        activeSpaceID = id
    }
    func perform(_ work: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { try await work() } catch { errorMessage = error.localizedDescription }
        }
    }

    func connect() async throws {
        guard !connecting else { throw SharedLedgerError.storageUnavailable }
        if demo { return }
        guard !stopped else { throw SharedLedgerError.storageUnavailable }
        connecting = true
        defer { connecting = false }
        guard try await cloud.accountStatus() == .available else { throw SharedLedgerError.noAccount }
        let account = try await cloud.userRecordID().recordName
        if let previous = accountName, previous != account {
            stopForAccountChange()
            throw SharedLedgerError.noAccount
        }
        guard database == nil else { return }
        #if DEBUG
        let environment = "Development"
        #else
        let environment = "Production"
        #endif
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
        database = try SharedDatabaseService(directory: root.appendingPathComponent("Shared/\(environment)/\(hash(account))"))
        accountName = account
        UserDefaults.standard.set(true, forKey: "shared_spaces_enabled")
        try reload()
        guard let database else { throw SharedLedgerError.storageUnavailable }
        let states = try database.context.fetch(FetchDescriptor<SharedEngineState>())
        for scope: CKDatabase.Scope in [.private, .shared] {
            let state = try states.first { $0.scope == scope.rawValue }.map {
                try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0.serialization)
            }
            let config = CKSyncEngine.Configuration(database: cloud.database(with: scope), stateSerialization: state, delegate: self)
            let engine = CKSyncEngine(config)
            engines[scope.rawValue] = engine
            for row in try database.records() where row.databaseScope == scope.rawValue && row.localRevision != nil {
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID(row))])
            }
        }
        accountObserver = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopForAccountChange() }
        }
    }

    private func stopForAccountChange() {
        stopped = true; engines.removeAll(); writableSpaces.removeAll()
        spaces = []; members = []; expenses = []; activeSpaceID = nil
        database = nil
        errorMessage = text("חשבון iCloud השתנה. יש לפתוח מחדש את האפליקציה. שינויים ממתינים נשמרו בחשבון המקורי.",
                            "iCloud account changed. Reopen the app. Pending changes remain in the original account.")
    }

    private func recordID(_ row: SharedStoredRecord) -> CKRecord.ID {
        CKRecord.ID(recordName: row.key.components(separatedBy: "|").last ?? row.key,
                    zoneID: .init(zoneName: row.zoneName, ownerName: row.zoneOwner))
    }
    private func key(_ id: CKRecord.ID) -> String { "\(id.zoneID.ownerName)|\(id.zoneID.zoneName)|\(id.recordName)" }
    private func spaceID(_ zone: CKRecordZone.ID) -> UUID? {
        guard zone.zoneName.hasPrefix(Self.zonePrefix) else { return nil }
        return UUID(uuidString: String(zone.zoneName.dropFirst(Self.zonePrefix.count)))
    }
    private func spaceRow(_ id: UUID) throws -> SharedStoredRecord {
        guard let row = try database?.records().first(where: { $0.spaceID == id.uuidString && $0.kind == "space" && !$0.isDeleted }) else {
            throw SharedLedgerError.noAccess
        }
        return row
    }

    func reload() throws {
        guard let database else { return }
        let records = try database.records()
        var nextSpaces: [SharedSpace] = [], nextMembers: [SharedMember] = [], nextExpenses: [SharedExpense] = []
        for row in records where !row.isDeleted && row.schemaVersion == 1 {
            guard let id = UUID(uuidString: row.spaceID), !revokedSpaces.contains(id) else { continue }
            switch row.kind {
            case "space": nextSpaces.append(try JSONDecoder().decode(SharedSpace.self, from: row.payload))
            case "member": nextMembers.append(try JSONDecoder().decode(SharedMember.self, from: row.payload))
            case "expense": nextExpenses.append(try JSONDecoder().decode(SharedExpense.self, from: row.payload))
            default: break
            }
        }
        spaces = nextSpaces.sorted { $0.createdAt < $1.createdAt }
        members = nextMembers.sorted { $0.id < $1.id }
        expenses = nextExpenses.sorted { $0.date > $1.date }
        pendingCount = records.filter { $0.localRevision != nil }.count
        conflictCount = records.filter { $0.recoveryPayload != nil }.count
        if let activeSpaceID, !spaces.contains(where: { $0.id == activeSpaceID }) { self.activeSpaceID = nil }
    }

    private func put<T: Encodable>(_ value: T, kind: String, name: String, space: UUID,
                                    zone: CKRecordZone.ID, scope: Int) throws {
        guard let database else { throw SharedLedgerError.storageUnavailable }
        let id = CKRecord.ID(recordName: name, zoneID: zone)
        let row: SharedStoredRecord
        if let existing = try database.record(key(id)) { row = existing }
        else {
            row = SharedStoredRecord(key: key(id), spaceID: space.uuidString, kind: kind, payload: Data(),
                                     zoneName: zone.zoneName, zoneOwner: zone.ownerName, databaseScope: scope)
            database.context.insert(row)
        }
        guard !row.isDeleted else { throw SharedLedgerError.noAccess }
        row.payload = try JSONEncoder().encode(value)
        row.localRevision = demo ? nil : UUID().uuidString
        try database.save()
        if !demo { engines[scope]?.state.add(pendingRecordZoneChanges: [.saveRecord(id)]) }
        try reload()
    }

    func create(name: String, memberName: String, currency: String, mapStyle: String) async throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !memberName.isEmpty,
              Locale.commonISOCurrencyCodes.contains(currency) else { throw SharedLedgerError.invalidInput }
        try await connect()
        let id = UUID()
        let space = SharedSpace(id: id, name: String(name.prefix(60)), currencyCode: currency,
                                timeZoneID: TimeZone.current.identifier, mapStyle: mapStyle, createdAt: Date())
        let zone = CKRecordZone(zoneName: Self.zonePrefix + id.uuidString)
        if !demo {
            _ = try await cloud.privateCloudDatabase.save(zone)
            let share = CKShare(recordZoneID: zone.zoneID)
            share[CKShare.SystemFieldKey.title] = space.name as CKRecordValue
            share.publicPermission = .none
            _ = try await cloud.privateCloudDatabase.save(share)
        }
        writableSpaces.insert(id)
        try put(space, kind: "space", name: "space", space: id, zone: zone.zoneID, scope: CKDatabase.Scope.private.rawValue)
        try registerMember(in: id, name: memberName)
        activeSpaceID = id
        if !demo { try await sync() }
    }

    func registerMember(in id: UUID, name: String) throws {
        guard canWrite(id), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SharedLedgerError.noAccess }
        let row = try spaceRow(id)
        let memberID = myMemberID(in: id)
        let existing = members.first { $0.id == memberID && $0.spaceID == id }
        let palette = ["#5653E8", "#FF6446", "#2D9E65", "#3F86C7", "#C9913F", "#D85F73"]
        let index = members.filter { $0.spaceID == id }.count % palette.count
        let member = SharedMember(id: memberID, spaceID: id, name: String(name.prefix(40)),
                                  colorHex: existing?.colorHex ?? palette[index], isActive: true)
        try put(member, kind: "member", name: "member-" + memberID, space: id,
                zone: recordID(row).zoneID, scope: row.databaseScope)
    }

    func saveExpense(_ expense: SharedExpense) throws {
        guard canWrite(expense.spaceID), let space = spaces.first(where: { $0.id == expense.spaceID }) else { throw SharedLedgerError.noAccess }
        guard expense.currencyCode == space.currencyCode, expense.amount.isFinite, expense.amount != 0,
              abs(expense.amount) <= MoneyAmount.maximum, expense.date <= Date(),
              expense.category.canonical != .savings, !expense.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              expense.merchant.count <= 120, expense.note.count <= 1000,
              members.contains(where: { $0.id == expense.paidBy && $0.spaceID == expense.spaceID }) else { throw SharedLedgerError.invalidInput }
        let row = try spaceRow(expense.spaceID)
        var value = expense
        value.updatedBy = myMemberID(in: space.id)
        if let previous = expenses.first(where: { $0.id == expense.id && $0.spaceID == expense.spaceID }) {
            value.createdBy = previous.createdBy
        } else { value.createdBy = value.updatedBy }
        try put(value, kind: "expense", name: expense.id.uuidString, space: expense.spaceID,
                zone: recordID(row).zoneID, scope: row.databaseScope)
    }

    func deleteExpense(_ expense: SharedExpense) throws {
        guard canWrite(expense.spaceID), let database else { throw SharedLedgerError.noAccess }
        let space = try spaceRow(expense.spaceID)
        let id = CKRecord.ID(recordName: expense.id.uuidString, zoneID: recordID(space).zoneID)
        guard let row = try database.record(key(id)) else { return }
        row.isDeleted = true
        row.localRevision = demo ? nil : UUID().uuidString
        try database.save()
        engines[row.databaseScope]?.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
        try reload()
    }

    func refresh() async throws {
        if demo { return }
        try await connect()
        var accessible = Set<UUID>(), writable = Set<UUID>()
        for scope: CKDatabase.Scope in [.private, .shared] {
            let zones = try await cloud.database(with: scope).allRecordZones()
            for zone in zones {
                guard let id = spaceID(zone.zoneID) else { continue }
                accessible.insert(id)
                if scope == .private { writable.insert(id) }
                else if let shareID = zone.share?.recordID,
                        let share = try await cloud.sharedCloudDatabase.record(for: shareID) as? CKShare,
                        share.currentUserParticipant?.permission == .readWrite { writable.insert(id) }
            }
            try await engines[scope.rawValue]?.fetchChanges()
        }
        // Only a complete successful listing proves absence; network errors never revoke data.
        revokedSpaces.formUnion(Set(spaces.map(\.id)).subtracting(accessible))
        writableSpaces = writable
        try reload()
    }

    func sync() async throws {
        if demo { return }
        try await connect()
        for engine in engines.values { try await engine.sendChanges() }
        try await refresh()
    }

    func sharingRecord(in space: UUID) async throws -> CKShare {
        guard !demo else { throw SharedLedgerError.noAccount }
        let row = try spaceRow(space)
        let db = cloud.database(with: CKDatabase.Scope(rawValue: row.databaseScope) ?? .shared)
        let zone = try await db.recordZone(for: recordID(row).zoneID)
        guard let id = zone.share?.recordID, let share = try await db.record(for: id) as? CKShare else { throw SharedLedgerError.noAccess }
        return share
    }

    func accept(_ metadata: CKShare.Metadata, memberName: String) async throws {
        guard !demo, metadata.containerIdentifier == cloud.containerIdentifier,
              let id = spaceID(metadata.share.recordID.zoneID) else { throw SharedLedgerError.wrongInvitation }
        try await connect()
        guard let result = try await cloud.accept([metadata])[metadata] else { throw SharedLedgerError.wrongInvitation }
        _ = try result.get()
        try await refresh()
        if canWrite(id) { try registerMember(in: id, name: memberName) }
        invitation = nil; activeSpaceID = id
    }

    func metadata(for url: String) async throws -> CKShare.Metadata {
        guard let url = URL(string: url), url.scheme == "https",
              let result = try await cloud.shareMetadatas(for: [url])[url] else { throw SharedLedgerError.wrongInvitation }
        return try result.get()
    }

    /// Access-management UI must not allow leaving while there are unsent local edits.
    func ensureNoPendingChanges(in id: UUID) throws {
        guard !(try database?.records().contains { $0.spaceID == id.uuidString && $0.localRevision != nil } ?? false) else {
            throw SharedLedgerError.pendingChanges
        }
    }

    private func cloudRecord(_ row: SharedStoredRecord) throws -> CKRecord {
        let record: CKRecord
        if let fields = row.systemFields {
            let decoder = try NSKeyedUnarchiver(forReadingFrom: fields)
            decoder.requiresSecureCoding = true
            guard let restored = CKRecord(coder: decoder) else { throw SharedLedgerError.storageUnavailable }
            decoder.finishDecoding(); record = restored
        } else { record = CKRecord(recordType: "SPENTSharedRecord", recordID: recordID(row)) }
        record["payload"] = row.payload as CKRecordValue
        record["kind"] = row.kind as CKRecordValue
        record["revision"] = row.localRevision as CKRecordValue?
        record["deleted"] = (row.isDeleted ? Int64(1) : Int64(0)) as CKRecordValue
        record["schemaVersion"] = Int64(1) as CKRecordValue
        return record
    }
    private func systemFields(_ record: CKRecord) -> Data {
        let encoder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: encoder); encoder.finishEncoding()
        return encoder.encodedData
    }
    private func merge(_ record: CKRecord, scope: Int, acknowledge: Bool = false, conflict: Bool = false) throws {
        guard record.recordType == "SPENTSharedRecord", let id = spaceID(record.recordID.zoneID), let database,
              let kind = record["kind"] as? String, let payload = record["payload"] as? Data,
              payload.count < 100_000 else { return }
        guard record["schemaVersion"] as? Int64 == 1 else { unsupportedSpaces.insert(id); return }
        // Validate foreign records before allowing them into financial calculations.
        switch kind {
        case "space":
            let value = try JSONDecoder().decode(SharedSpace.self, from: payload)
            guard value.id == id, value.name.count <= 60, Locale.commonISOCurrencyCodes.contains(value.currencyCode),
                  TimeZone(identifier: value.timeZoneID) != nil else { throw SharedLedgerError.invalidInput }
        case "member":
            let value = try JSONDecoder().decode(SharedMember.self, from: payload)
            guard value.spaceID == id, value.name.count <= 40 else { throw SharedLedgerError.invalidInput }
        case "expense":
            let value = try JSONDecoder().decode(SharedExpense.self, from: payload)
            guard value.spaceID == id, Locale.commonISOCurrencyCodes.contains(value.currencyCode),
                  value.amount.isFinite, abs(value.amount) <= MoneyAmount.maximum, value.amount != 0,
                  value.merchant.count <= 120, value.note.count <= 1000,
                  value.category.canonical != .savings else { throw SharedLedgerError.invalidInput }
        default: unsupportedSpaces.insert(id); return
        }
        let row: SharedStoredRecord
        if let existing = try database.record(key(record.recordID)) { row = existing }
        else {
            row = SharedStoredRecord(key: key(record.recordID), spaceID: id.uuidString, kind: kind, payload: payload,
                                     zoneName: record.recordID.zoneID.zoneName, zoneOwner: record.recordID.zoneID.ownerName, databaseScope: scope)
            database.context.insert(row)
        }
        let deleted = (record["deleted"] as? Int64) == 1
        if row.isDeleted && !deleted {
            row.systemFields = systemFields(record)
            row.localRevision = row.localRevision ?? UUID().uuidString
            engines[scope]?.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
            return
        }
        if let local = row.localRevision, !deleted {
            if acknowledge && local != record["revision"] as? String {
                row.systemFields = systemFields(record)
                engines[scope]?.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
                return
            }
            if !acknowledge && !conflict { return }
            if conflict { row.recoveryPayload = row.payload }
        }
        row.payload = payload; row.isDeleted = deleted
        row.systemFields = systemFields(record); row.localRevision = nil
        engines[scope]?.state.remove(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        let scope = syncEngine.database.databaseScope.rawValue
        guard !stopped, engines[scope] === syncEngine, let database else { return }
        do {
            switch event {
            case .stateUpdate(let value):
                let data = try JSONEncoder().encode(value.stateSerialization)
                if let row = try database.context.fetch(FetchDescriptor<SharedEngineState>()).first(where: { $0.scope == scope }) { row.serialization = data }
                else { database.context.insert(SharedEngineState(scope: scope, serialization: data)) }
            case .accountChange(let change):
                if case .signIn = change.changeType { return }
                stopForAccountChange(); return
            case .fetchedRecordZoneChanges(let changes):
                for modification in changes.modifications { try merge(modification.record, scope: scope) }
                for deletion in changes.deletions {
                    if let row = try database.record(key(deletion.recordID)) {
                        row.isDeleted = true; row.localRevision = nil
                        syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(deletion.recordID)])
                    }
                }
            case .fetchedDatabaseChanges(let changes):
                for deletion in changes.deletions {
                    if let id = spaceID(deletion.zoneID) { revokedSpaces.insert(id); writableSpaces.remove(id) }
                }
            case .sentRecordZoneChanges(let changes):
                for record in changes.savedRecords { try merge(record, scope: scope, acknowledge: true) }
                for failure in changes.failedRecordSaves {
                    if failure.error.code == .serverRecordChanged, let server = failure.error.serverRecord {
                        try merge(server, scope: scope, conflict: true)
                    } else {
                        if [.permissionFailure, .zoneNotFound, .userDeletedZone].contains(failure.error.code), let id = spaceID(failure.record.recordID.zoneID) {
                            revokedSpaces.insert(id); writableSpaces.remove(id)
                            syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(failure.record.recordID)])
                        }
                        errorMessage = failure.error.localizedDescription
                    }
                }
            default: return
            }
            try database.save()
            try reload()
        } catch {
            database.context.rollback()
            stopped = true; engines.removeAll(); writableSpaces.removeAll()
            errorMessage = error.localizedDescription
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard !stopped, let database else { return nil }
        do {
            var records: [CKRecord.ID: CKRecord] = [:]
            for row in try database.records() where row.localRevision != nil && row.databaseScope == syncEngine.database.databaseScope.rawValue {
                guard let id = UUID(uuidString: row.spaceID), !revokedSpaces.contains(id), !unsupportedSpaces.contains(id) else { continue }
                records[recordID(row)] = try cloudRecord(row)
            }
            let snapshot = records
            let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
            return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { snapshot[$0] }
        } catch { errorMessage = error.localizedDescription; return nil }
    }

    #if DEBUG
    func startDemo() async throws {
        guard database == nil else { throw SharedLedgerError.invalidInput }
        demo = true; accountName = "demo-user"
        database = try SharedDatabaseService(directory: nil, inMemory: true)
        try await create(name: text("הבית שלנו · הדגמה", "Our home · Demo"), memberName: text("אני", "Me"), currency: "ILS", mapStyle: "urban")
        guard let id = activeSpaceID else { return }
        let row = try spaceRow(id)
        let partner = SharedMember(id: "demo-partner", spaceID: id, name: text("מאיה", "Maya"), colorHex: "#FF6446", isActive: true)
        try put(partner, kind: "member", name: "member-demo-partner", space: id, zone: recordID(row).zoneID, scope: row.databaseScope)
        for index in 0..<18 {
            let payer = index % 3 == 0 ? partner.id : myMemberID(in: id)
            try saveExpense(SharedExpense(id: UUID(), spaceID: id, amountMinor: Int64(1800 + index * 370), currencyCode: "ILS",
                merchant: index % 2 == 0 ? text("בית קפה", "Coffee shop") : text("סופר", "Groceries"), category: .food,
                buildingID: index % 2 == 0 ? "food_coffee" : "food_super", date: Date().addingTimeInterval(-Double(index) * 3600 * 8),
                note: "", paidBy: payer, createdBy: payer, updatedBy: payer))
        }
    }
    #endif
}
#endif
