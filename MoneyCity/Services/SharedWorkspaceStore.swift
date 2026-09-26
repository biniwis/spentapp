#if !SWIFT_PACKAGE
import CloudKit
import CryptoKit
import SwiftUI
import SwiftData

@MainActor
final class SharedWorkspaceStore: ObservableObject, CKSyncEngineDelegate {
    static let shared = SharedWorkspaceStore()
    static let zonePrefix = "SPENT.Shared."
    /// A zone CloudKit has just saved can answer `zoneNotFound` until its own listing
    /// catches up. One blip must not cost the user a space, so a revoke has to repeat
    /// itself before we believe it.
    static let revocationThreshold = 3
    let cloud: CKContainer
    private let accountProvider: SharedCloudAccountProvider
    private let customRootDirectory: URL?

    init(
        cloud: CKContainer = CKContainer(identifier: "iCloud.com.moneycity.app"),
        rootDirectory: URL? = nil,
        accountProvider: SharedCloudAccountProvider? = nil
    ) {
        self.cloud = cloud
        self.customRootDirectory = rootDirectory
        self.accountProvider = accountProvider ?? cloud
    }

    @Published private(set) var spaces: [SharedSpace] = []
    @Published private(set) var members: [SharedMember] = []
    @Published private(set) var expenses: [SharedExpense] = []
    @Published private(set) var pendingCount = 0
    @Published private(set) var conflictCount = 0
    @Published private(set) var conflicts: [SharedExpenseConflict] = []
    @Published private(set) var demo = false
    @Published private(set) var activeSpaceID: UUID?
    @Published var showSetup = false
    @Published var showAccountSwitcher = false
    @Published var busy = false
    /// Background/transport failures. Presented as a global alert.
    @Published var errorMessage: String?
    /// Failures caused by what the user just typed. The setup screen owns these and
    /// renders them inline, so a bad link never escalates to an app-wide alert.
    @Published private(set) var setupError: String?
    @Published var invitation: CKShare.Metadata?
    private(set) var database: SharedDatabaseService?
    private var engines: [Int: CKSyncEngine] = [:]
    private var engineGenerations: [ObjectIdentifier: UInt64] = [:]
    private var accountName: String?
    private var writableSpaces = Set<UUID>()
    private var revokedSpaces = Set<UUID>()
    private var unsupportedSpaces = Set<UUID>()
    private var ownedSpaces = Set<UUID>()
    private var revocationStrikes: [UUID: Int] = [:]
    private var accountObserver: NSObjectProtocol?
    private var connecting = false
    private var stopped = false
    private var accountGeneration: UInt64 = 0

    func isSpaceRevoked(_ id: UUID) -> Bool { revokedSpaces.contains(id) }
    func isSpaceUnsupported(_ id: UUID) -> Bool { unsupportedSpaces.contains(id) }
    var connectedAccount: String? { accountName }
    var activeRevokedSpaces: Set<UUID> { revokedSpaces }
    var activeUnsupportedSpaces: Set<UUID> { unsupportedSpaces }
    #if DEBUG
    var currentAccountGeneration: UInt64 { accountGeneration }
    func engineForTesting(scope: CKDatabase.Scope) -> CKSyncEngine? { engines[scope.rawValue] }
    func isEngineActiveForTesting(_ syncEngine: CKSyncEngine) -> Bool {
        let scope = syncEngine.database.databaseScope.rawValue
        return !stopped &&
            engineGenerations[ObjectIdentifier(syncEngine)] == accountGeneration &&
            engines[scope] === syncEngine
    }
    var onRefreshSuspensionHook: (() async -> Void)?
    #endif

    var activeSpace: SharedSpace? { spaces.first { $0.id == activeSpaceID } }
    func text(_ he: String, _ en: String) -> String { AppLanguage.current == .hebrew ? he : en }
    private func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func myMemberID(in space: UUID) -> String { hash(space.uuidString + (accountName ?? "")) }

    private func saveAccountMetadata() {
        guard let directory = database?.directory else { return }
        let metadata = SharedAccountMetadata(
            revokedSpaceIDs: revokedSpaces,
            unsupportedSpaceIDs: unsupportedSpaces,
            revocationStrikes: revocationStrikes,
            activeSpaceID: activeSpaceID
        )
        metadata.save(to: directory)
    }

    private func loadAccountMetadata() {
        guard let directory = database?.directory else { return }
        let metadata = SharedAccountMetadata.load(from: directory)
        revokedSpaces = metadata.revokedSpaceIDs
        unsupportedSpaces = metadata.unsupportedSpaceIDs
        revocationStrikes = metadata.revocationStrikes
        if let savedActive = metadata.activeSpaceID, !revokedSpaces.contains(savedActive), !unsupportedSpaces.contains(savedActive) {
            activeSpaceID = savedActive
        }
    }

    /// The same identity, but only when it can actually be trusted.
    ///
    /// `myMemberID` hashes in an empty account name before the store has connected, and
    /// that hash matches no member at all. Reporting it as an identity would be a guess
    /// that silently reads as certainty, so anything asking "am I a member of this space,
    /// and did I pay for it?" must ask this instead and take a `nil` seriously.
    func currentMemberID(in space: UUID) -> String? {
        guard let accountName, !accountName.isEmpty else { return nil }
        return myMemberID(in: space)
    }
    func canWrite(_ id: UUID) -> Bool {
        guard !stopped, !unsupportedSpaces.contains(id), !revokedSpaces.contains(id) else { return false }
        // Denial needs positive evidence. Anything else risks locking the owner out of
        // their own space over a listing that had not caught up yet.
        return writableSpaces.contains(id) || ownedSpaces.contains(id)
    }
    func select(_ id: UUID?) {
        guard id == nil || (spaces.contains(where: { $0.id == id }) && !revokedSpaces.contains(id!) && !unsupportedSpaces.contains(id!)) else { return }
        activeSpaceID = id
        saveAccountMetadata()
    }
    func perform(_ work: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { try await work() }
            catch is CancellationError {
                return
            }
            catch {
                // The user's own input belongs on the screen they are looking at.
                // Escalating it to a global alert is what made a bad invite link look
                // like the whole app had broken.
                if let ledger = error as? SharedLedgerError, ledger.isUserInput {
                    setupError = ledger.errorDescription
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clearSetupError() { setupError = nil }

    /// The connect attempt currently in flight, if any.
    ///
    /// Discovery is triggered from several independent places — launch, opening the shared
    /// screen, and returning to the foreground — and those can easily overlap. Treating an
    /// overlap as a failure was wrong twice over: it told a user their shared data was
    /// unavailable at the exact moment it was being loaded, and it made an ordinary
    /// foreground transition look like a fault. Concurrent callers now wait for the attempt
    /// already running and share its result, so a second request is free rather than an
    /// error, and a burst of them cannot fan out into a burst of CloudKit calls.
    private var connectAttempt: Task<Void, Error>?

    func connect() async throws {
        if demo { return }
        if let attempt = connectAttempt {
            try await attempt.value
            return
        }
        let attempt = Task { try await performConnect() }
        connectAttempt = attempt
        defer { connectAttempt = nil }
        try await attempt.value
    }

    private func performConnect() async throws {
        guard !stopped else { throw SharedLedgerError.storageUnavailable }
        var generation = accountGeneration
        connecting = true
        defer { connecting = false }
        let status = try await accountProvider.accountStatus()
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        guard status == .available else {
            handleAccountChange()
            throw SharedLedgerError.noAccount
        }
        let account = try await accountProvider.userRecordID().recordName
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        if let previous = accountName, previous != account {
            handleAccountChange()
            generation = accountGeneration
        }
        guard database == nil else { return }
        #if DEBUG
        let environment = "Development"
        #else
        let environment = "Production"
        #endif
        let root: URL
        if let custom = customRootDirectory {
            root = custom
        } else {
            root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
        }
        let accountFolder = root.appendingPathComponent("Shared/\(environment)/\(hash(account))")
        database = try SharedDatabaseService(directory: accountFolder)
        accountName = account
        loadAccountMetadata()
        UserDefaults.standard.set(true, forKey: "shared_spaces_enabled")
        UserDefaults.standard.set(true, forKey: "shared_spaces_enabled_\(hash(account))")
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
            engineGenerations[ObjectIdentifier(engine)] = generation
            for row in try database.records() where row.databaseScope == scope.rawValue && row.localRevision != nil {
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID(row))])
            }
        }
        if accountObserver == nil {
            accountObserver = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleAccountChange() }
            }
        }
    }

    func handleAccountChange() {
        accountGeneration &+= 1
        connectAttempt?.cancel()
        connectAttempt = nil
        refreshAttempt?.cancel()
        refreshAttempt = nil
        engineGenerations.removeAll()
        engines.removeAll()
        writableSpaces.removeAll()
        ownedSpaces.removeAll()
        revokedSpaces.removeAll()
        unsupportedSpaces.removeAll()
        revocationStrikes.removeAll()
        spaces = []
        members = []
        expenses = []
        conflicts = []
        conflictCount = 0
        activeSpaceID = nil
        accountName = nil
        database = nil
        stopped = false
    }

    private func stopForAccountChange() {
        handleAccountChange()
        stopped = true
        errorMessage = text("חשבון iCloud השתנה. יש לפתוח מחדש את האפליקציה. שינויים ממתינים נשמרו בחשבון המקורי.",
                            "iCloud account changed. Reopen the app. Pending changes remain in the original account.")
    }

    deinit {
        if let accountObserver {
            NotificationCenter.default.removeObserver(accountObserver)
        }
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
        // A zone that lives in our own private database is ours to write to, whether or
        // not CloudKit has answered us lately. Tracked here so `canWrite` stays a cheap
        // lookup instead of a scan, and so a failed refresh cannot cost us our own spaces.
        ownedSpaces = Set(records.filter { $0.kind == "space" && !$0.isDeleted &&
                                            $0.databaseScope == CKDatabase.Scope.private.rawValue }
                                .compactMap { UUID(uuidString: $0.spaceID) }
                                .filter { !revokedSpaces.contains($0) && !unsupportedSpaces.contains($0) })
        var nextSpaces: [SharedSpace] = [], nextMembers: [SharedMember] = [], nextExpenses: [SharedExpense] = []
        for row in records where !row.isDeleted && row.schemaVersion == 1 {
            guard let id = UUID(uuidString: row.spaceID),
                  !revokedSpaces.contains(id),
                  !unsupportedSpaces.contains(id) else { continue }
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
        var nextConflicts: [SharedExpenseConflict] = []
        for row in records where !row.isDeleted && row.kind == "expense" {
            guard let recPayload = row.recoveryPayload,
                  let spaceID = UUID(uuidString: row.spaceID),
                  !revokedSpaces.contains(spaceID),
                  !unsupportedSpaces.contains(spaceID) else { continue }
            if let serverExp = try? JSONDecoder().decode(SharedExpense.self, from: row.payload),
               let localExp = try? JSONDecoder().decode(SharedExpense.self, from: recPayload) {
                nextConflicts.append(SharedExpenseConflict(
                    recordKey: row.key,
                    spaceID: spaceID,
                    serverExpense: serverExp,
                    localExpense: localExp
                ))
            }
        }
        conflicts = nextConflicts
        conflictCount = nextConflicts.count
        if let active = activeSpaceID, (!spaces.contains(where: { $0.id == active }) || revokedSpaces.contains(active) || unsupportedSpaces.contains(active)) {
            self.activeSpaceID = nil
            saveAccountMetadata()
        }
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

    private enum Revocation {
        /// The owner removed the share or the zone. The space is gone.
        case terminal
        /// CloudKit's listing has not caught up yet. Believed only if it repeats.
        case transient
    }

    /// Returns true when the space is actually revoked, so callers know whether to
    /// discard the queued change and report, or to keep waiting quietly.
    @discardableResult
    private func revoke(_ id: UUID, because reason: Revocation) -> Bool {
        switch reason {
        case .terminal:
            revokedSpaces.insert(id)
            writableSpaces.remove(id)
            revocationStrikes[id] = nil
            saveAccountMetadata()
            return true
        case .transient:
            let strikes = (revocationStrikes[id] ?? 0) + 1
            revocationStrikes[id] = strikes
            guard strikes >= Self.revocationThreshold else {
                saveAccountMetadata()
                return false
            }
            revokedSpaces.insert(id)
            writableSpaces.remove(id)
            saveAccountMetadata()
            return true
        }
    }

    func create(name: String, memberName: String, currency: String, mapStyle: String,
                monthlyBudgetMinor: Int64? = nil) async throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMember = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanMember.isEmpty,
              Locale.commonISOCurrencyCodes.contains(currency) else { throw SharedLedgerError.invalidInput }
        // A target is optional, but a target of zero or less is a mistake, not a choice.
        // Rejected before anything is created, so a bad number costs nothing.
        if let monthlyBudgetMinor, monthlyBudgetMinor <= 0 { throw SharedLedgerError.invalidAmount }
        let generation = accountGeneration
        try await connect()
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        let id = UUID()
        let space = SharedSpace(id: id, name: String(cleanName.prefix(60)), currencyCode: currency,
                                timeZoneID: TimeZone.current.identifier, mapStyle: mapStyle, createdAt: Date(),
                                monthlyBudgetMinor: monthlyBudgetMinor)
        let zone = CKRecordZone(zoneName: Self.zonePrefix + id.uuidString)
        do {
            if !demo {
                _ = try await cloud.privateCloudDatabase.save(zone)
                guard generation == accountGeneration, !Task.isCancelled else {
                    rollbackSpace(id, zone: zone)
                    throw CancellationError()
                }
                let share = CKShare(recordZoneID: zone.zoneID)
                share[CKShare.SystemFieldKey.title] = space.name as CKRecordValue
                share.publicPermission = .none
                _ = try await cloud.privateCloudDatabase.save(share)
                guard generation == accountGeneration, !Task.isCancelled else {
                    rollbackSpace(id, zone: zone)
                    throw CancellationError()
                }
            }
            writableSpaces.insert(id)
            try put(space, kind: "space", name: "space", space: id, zone: zone.zoneID, scope: CKDatabase.Scope.private.rawValue)
            try registerMember(in: id, name: cleanMember)
            if !demo {
                try await sync()
                guard generation == accountGeneration, !Task.isCancelled else {
                    rollbackSpace(id, zone: zone)
                    throw CancellationError()
                }
            }
        } catch {
            // Half a space is worse than no space: undo every step this call made.
            rollbackSpace(id, zone: zone)
            throw error
        }
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        // The app only leaves the previous scope once the new space and its first
        // sync are both real, so a failed create cannot strand the user in a broken scope.
        activeSpaceID = id
        saveAccountMetadata()
    }

    /// Undoes a partially created space: local rows, write access, the engine queue,
    /// and the remote zone. CloudKit cleanup is best effort — the local state is what
    /// the user actually sees, so that part is not allowed to fail.
    private func rollbackSpace(_ id: UUID, zone: CKRecordZone) {
        writableSpaces.remove(id)
        revocationStrikes[id] = nil
        saveAccountMetadata()
        if let database {
            for record in ((try? database.records()) ?? []) where record.spaceID == id.uuidString {
                database.context.delete(record)
            }
            try? database.save()
        }
        let queued: [CKSyncEngine.PendingRecordZoneChange] = [
            .saveRecord(CKRecord.ID(recordName: "space", zoneID: zone.zoneID)),
            .saveRecord(CKRecord.ID(recordName: "member-" + myMemberID(in: id), zoneID: zone.zoneID))
        ]
        for engine in engines.values { engine.state.remove(pendingRecordZoneChanges: queued) }
        if !demo {
            let container = cloud
            Task.detached(priority: .utility) {
                try? await container.privateCloudDatabase.deleteRecordZone(withID: zone.zoneID)
            }
        }
        try? reload()
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

    /// Sets or clears the space's own monthly target. Never touches a personal budget:
    /// the value lives in the space record, so every member reads the same one.
    func setMonthlyBudget(_ minor: Int64?, for id: UUID) throws {
        guard canWrite(id) else { throw SharedLedgerError.noAccess }
        if let minor, minor <= 0 { throw SharedLedgerError.invalidAmount }
        guard var space = spaces.first(where: { $0.id == id }) else { throw SharedLedgerError.noAccess }
        let row = try spaceRow(id)
        space.monthlyBudgetMinor = minor
        try put(space, kind: "space", name: "space", space: id,
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

    /// Finds the spaces this account can see in CloudKit, whether or not anything local
    /// remembers them.
    ///
    /// Discovery deliberately does not consult `shared_spaces_enabled`. That flag used to
    /// gate the only call to `refresh()`, while `connect()` was the only writer of the
    /// flag, so a fresh install or a new device could never set it and therefore could
    /// never look: the gate could not be opened from inside. CloudKit is the record of
    /// what this account owns and belongs to, so opening the shared UI has to be enough
    /// to go and read it.
    ///
    /// Having no iCloud account is an ordinary state, not a failure to report: a personal
    /// user who never shared anything should not meet an alert for it. Everything else is
    /// surfaced, because a discovery that silently did not happen is how a user concludes
    /// their spaces are gone.
    func discover() async {
        if demo { return }
        do {
            try await refresh()
            guard !Task.isCancelled else { return }
        } catch is CancellationError {
            return
        } catch let error as SharedLedgerError where error == .noAccount {
            return
        } catch let ckError as CKError where SharedSyncClassifier.classify(ckError.code) == .retryable || SharedSyncClassifier.classify(ckError.code) == .accountRequired {
            return
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            return
        }
        guard !Task.isCancelled else { return }
        // Discovery is also the moment a join left half-finished by a previous launch can
        // be completed, so recovery does not depend on the user still holding the link.
        await resumePendingJoinIfAny()
    }

    /// The refresh attempt currently in flight, if any.
    ///
    /// Startup, opening the shared screen, returning to the foreground, or resuming
    /// pending joins can all call refresh at once. Sharing the attempt already in flight
    /// prevents redundant CloudKit fetches and avoids hammering CKSyncEngine with
    /// concurrent fetchChanges calls.
    private var refreshAttempt: Task<Void, Error>?

    func refresh() async throws {
        if demo { return }
        if let attempt = refreshAttempt {
            try await attempt.value
            return
        }
        let attempt = Task { try await performRefresh() }
        refreshAttempt = attempt
        defer { refreshAttempt = nil }
        try await attempt.value
    }

    private func performRefresh() async throws {
        let generation = accountGeneration
        try await connect()
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        #if DEBUG
        if let onRefreshSuspensionHook {
            await onRefreshSuspensionHook()
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        }
        #endif
        var accessible = Set<UUID>(), writable = Set<UUID>()
        for scope: CKDatabase.Scope in [.private, .shared] {
            let zones = try await cloud.database(with: scope).allRecordZones()
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
            for zone in zones {
                guard let id = spaceID(zone.zoneID) else { continue }
                accessible.insert(id)
                if scope == .private { writable.insert(id) }
                else if let shareID = zone.share?.recordID {
                    let record = try await cloud.sharedCloudDatabase.record(for: shareID)
                    guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
                    if let share = record as? CKShare,
                       share.currentUserParticipant?.permission == .readWrite {
                        writable.insert(id)
                    }
                }
            }
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
            try await engines[scope.rawValue]?.fetchChanges()
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        }
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        // A space we can see again is not revoked, and its access comes back with it.
        revokedSpaces.subtract(accessible)
        // Only a space that actually reappeared clears its record. Wiping every strike
        // for any space missing from this listing would reset the count to zero on each
        // pass, and the threshold could never be reached by a zone that is really gone.
        for id in accessible { revocationStrikes[id] = nil }
        // Absence from one listing is not proof: a zone CloudKit accepted moments ago
        // can take a while to show up in its own list. It gets the same strike budget as
        // a transient zoneNotFound instead of a silent, permanent revoke.
        for missing in Set(spaces.map(\.id)).subtracting(accessible) { revoke(missing, because: .transient) }
        // Write access is withdrawn only on positive evidence — the space is listed, but
        // its share says read-only. A zone we merely failed to see never costs access.
        writableSpaces.formUnion(writable)
        writableSpaces.subtract(accessible.subtracting(writable))
        saveAccountMetadata()
        try reload()
    }

    /// Undoes a revocation and re-sends whatever the space never managed to upload.
    /// Safe to call on a space that is not revoked: refresh decides the truth.
    func recoverSpace(_ id: UUID) async throws {
        let generation = accountGeneration
        revokedSpaces.remove(id)
        revocationStrikes[id] = nil
        saveAccountMetadata()
        // reload() reads revokedSpaces, so the row has to surface here before anything
        // downstream can look the space up by id.
        try reload()
        // Rows still carrying a local revision are unsent work. If their place in the
        // engine queue was lost, re-arm them here: recovery has to restore the data, not
        // just hand the permission back.
        if let database {
            for row in try database.records() where row.spaceID == id.uuidString &&
                                                   row.localRevision != nil && !row.isDeleted {
                engines[row.databaseScope]?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID(row))])
            }
        }
        try await refresh()
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        guard canWrite(id) else { return }
        try await sync()
    }

    func sync() async throws {
        if demo { return }
        let generation = accountGeneration
        try await connect()
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        for engine in engines.values {
            try await engine.sendChanges()
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        }
        try await refresh()
    }

    func sharingRecord(in space: UUID) async throws -> CKShare {
        guard !demo else { throw SharedLedgerError.noAccount }
        let generation = accountGeneration
        let row = try spaceRow(space)
        let db = cloud.database(with: CKDatabase.Scope(rawValue: row.databaseScope) ?? .shared)
        let zone = try await db.recordZone(for: recordID(row).zoneID)
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        if let id = zone.share?.recordID, let share = try? await db.record(for: id) as? CKShare {
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
            return share
        }
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        if row.databaseScope == CKDatabase.Scope.private.rawValue {
            let spaceObj = spaces.first(where: { $0.id == space }) ?? SharedSpace(id: space, name: "SPENT", currencyCode: "ILS", timeZoneID: TimeZone.current.identifier, mapStyle: "urban", createdAt: Date(), monthlyBudgetMinor: nil)
            let share = CKShare(recordZoneID: zone.zoneID)
            share[CKShare.SystemFieldKey.title] = spaceObj.name as CKRecordValue
            share.publicPermission = .none
            let saved = try await cloud.privateCloudDatabase.save(share)
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
            return (saved as? CKShare) ?? share
        }
        throw SharedLedgerError.noAccess
    }

    /// A link one specific person can claim once.
    ///
    /// `CKShare.url` is deliberately not used here. On a private share that URL only
    /// resolves for accounts CloudKit can already identify, so pasting it into WhatsApp
    /// does not invite an arbitrary recipient — and opening the share to the public to
    /// make the link work would expose the space's expenses to anyone holding it. A
    /// one-time URL participant is the documented way to hand somebody a link without
    /// knowing who they are first, and it keeps `publicPermission` at `.none`.
    func createInvitationLink(in spaceID: UUID) async throws -> URL {
        // A one-time URL participant can be added from iOS 18, but `oneTimeURL(for:)` —
        // the only Swift-visible way to read the link back — is iOS 26 and newer. Refused
        // below that rather than reaching for `CKShare.url`, which on a private share
        // would not open for a recipient CloudKit cannot already identify.
        guard #available(iOS 26.0, *) else { throw SharedLedgerError.inviteLinkUnsupported }
        // Refused before the share is even fetched, and before a participant is added.
        try SharedInvitation.validate(isDemo: demo, isOwner: isOwner(spaceID),
                                      hasPendingLocalChanges: hasPendingLocalChanges(in: spaceID))

        let share = try await sharingRecord(in: spaceID)
        try SharedInvitation.ensurePrivate(share.publicPermission)
        // Reasserted on the object that is about to be saved. This method never widens a
        // share, whatever the fetched copy claimed.
        share.publicPermission = .none

        // A brand new participant every time, never an earlier pending one. A pending
        // participant with no name and no lookup info does not prove SPENT created it —
        // and handing the same one-time URL to two people would turn one invitation into
        // a single-use link that only one of them can claim. One explicit invite action,
        // one link, one person.
        let participant = addOneTimeParticipant(to: share)

        // The owner holds the share in their own private database, so that is where the
        // updated share and its new participant have to be written.
        let saved = try await cloud.privateCloudDatabase.save(share)
        guard let savedShare = saved as? CKShare else { throw SharedLedgerError.inviteLinkUnavailable }
        return try SharedInvitation.requireLink(savedShare.oneTimeURL(for: participant.participantID))
    }

    /// A participant with readWrite, because a member of a shared space is expected to
    /// add expenses to it — that is the whole point of inviting them.
    @available(iOS 26.0, *)
    private func addOneTimeParticipant(to share: CKShare) -> CKShare.Participant {
        let participant = CKShare.Participant.oneTimeURLParticipant()
        participant.permission = .readWrite
        share.addParticipant(participant)
        return participant
    }

    func accept(_ metadata: CKShare.Metadata, memberName: String) async throws {
        guard !demo, metadata.containerIdentifier == cloud.containerIdentifier,
              let id = spaceID(metadata.share.recordID.zoneID) else { throw SharedLedgerError.wrongInvitation }
        let cleanName = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw SharedLedgerError.invalidInput }
        let generation = accountGeneration
        try await connect()
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        // Written before the irreversible call, so a death on the far side of it still
        // leaves enough on disk to finish the job. Without this the invitation is spent
        // and the user is left inside a space with no member row and no second link.
        switch SharedJoin.next(hasIntent: pendingJoin(id) != nil,
                                cloudAccepted: pendingJoin(id)?.acceptedAt != nil) {
        case .beginIntent:
            try beginPendingJoin(spaceID: id, memberName: cleanName)
        case .accept:
            // Accepting a share cannot be undone and cannot be replayed, so it happens at
            // most once per recorded intent.
            guard let result = try await cloud.accept([metadata])[metadata] else { throw SharedLedgerError.wrongInvitation }
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
            _ = try result.get()
            try markPendingJoinAccepted(id)
        case .finish, .done:
            break
        }
        try await finishPendingJoin(id)
    }

    // MARK: - Durable join

    /// Whether this device has anything shared to keep in step: a local shared store, spaces
    /// already known, or the flag saying this account has used sharing before.
    var hasSharedState: Bool {
        database != nil || !spaces.isEmpty || UserDefaults.standard.bool(forKey: "shared_spaces_enabled")
    }

    private var lastForegroundRefresh: Date?

    /// The safety net under push, run when the app comes back to the foreground.
    ///
    /// Best effort by design. A personal-only user never reaches CloudKit at all, a missing
    /// iCloud account is treated as an ordinary state rather than a failure to report, and
    /// the whole thing is asynchronous so it cannot hold up the personal UI. A network that
    /// is merely absent leaves spaces and write access exactly as they were — nothing here
    /// can hide a space or revoke anything.
    func refreshOnForeground(now: Date = Date()) async {
        guard !demo else { return }
        guard SharedForegroundSync.shouldRefresh(hasSharedState: hasSharedState,
                                                 lastRefresh: lastForegroundRefresh, now: now) else { return }
        lastForegroundRefresh = now
        await discover()
    }

    private func pendingJoins() throws -> [SharedPendingJoin] {
        guard let database else { return [] }
        return try database.context.fetch(FetchDescriptor<SharedPendingJoin>())
    }

    private func pendingJoin(_ id: UUID) -> SharedPendingJoin? {
        guard let database else { return nil }
        return try? database.context.fetch(FetchDescriptor<SharedPendingJoin>())
            .first { $0.spaceID == id.uuidString }
    }

    private func beginPendingJoin(spaceID id: UUID, memberName: String) throws {
        guard let database else { throw SharedLedgerError.storageUnavailable }
        if pendingJoin(id) == nil {
            database.context.insert(SharedPendingJoin(spaceID: id.uuidString, memberName: memberName))
        } else {
            pendingJoin(id)?.memberName = memberName
        }
        try database.save()
    }

    private func markPendingJoinAccepted(_ id: UUID) throws {
        guard let database else { throw SharedLedgerError.storageUnavailable }
        pendingJoin(id)?.acceptedAt = Date()
        try database.save()
    }

    private func clearPendingJoin(_ id: UUID) throws {
        guard let database, let row = pendingJoin(id) else { return }
        database.context.delete(row)
        try database.save()
    }

    /// Finishes a recorded join. Safe to run more than once: the member's record name is
    /// derived from the account and the space, so a second run rewrites the same row
    /// instead of adding another member.
    private func finishPendingJoin(_ id: UUID) async throws {
        guard let pending = pendingJoin(id) else { throw SharedLedgerError.wrongInvitation }
        let generation = accountGeneration
        try await refresh()
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        // The space has to exist here before it can be entered. CloudKit can accept a share
        // before the zone appears in this account's own listing, and activating a space
        // that is not there would leave the app pointed at nothing.
        let materialized = spaces.contains(where: { $0.id == id })
        let writable = canWrite(id)
        guard SharedJoin.canActivate(materialized: materialized, canWrite: writable, memberWritten: false) else {
            // Still on disk, so the next attempt resumes rather than restarting.
            throw materialized || !writable
                ? SharedLedgerError.noAccess
                : SharedLedgerError.storageUnavailable
        }
        // Safe to run more than once: the member's record name is derived from the account
        // and the space, so a second run rewrites the same row instead of adding another
        // member or handing out a second colour.
        try registerMember(in: id, name: pending.memberName)
        // Cleared only once the member row is real, so an interrupted finish resumes
        // instead of stranding a user CloudKit already let in.
        try clearPendingJoin(id)
        invitation = nil
        activeSpaceID = id
        saveAccountMetadata()
    }

    /// Picks up a join that CloudKit accepted but the app never finished. Runs on the
    /// paths that already talk to CloudKit, so a relaunch repairs the join on its own
    /// without the user having to remember the link they were given.
    func resumePendingJoinIfAny() async {
        guard !demo, let pending = try? pendingJoins().first,
              let id = UUID(uuidString: pending.spaceID), pending.acceptedAt != nil else { return }
        do {
            try await finishPendingJoin(id)
        } catch {
            // Left on disk on purpose: the next attempt tries again rather than stranding
            // a user CloudKit already let in.
            errorMessage = error.localizedDescription
        }
    }

    func metadata(for url: String) async throws -> CKShare.Metadata {
        // A link pasted with a trailing space or a stray newline is a typo, not a broken
        // invitation, and CloudKit would reject the untrimmed form.
        guard let link = SharedInvitation.pastedURL(url),
              let result = try await cloud.shareMetadatas(for: [link])[link] else {
            throw SharedLedgerError.wrongInvitation
        }
        do { return try result.get() }
        catch { throw SharedLedgerError.wrongInvitation }
    }

    /// Access-management UI must not allow leaving while there are unsent local edits.
    func ensureNoPendingChanges(in id: UUID) throws {
        guard !hasPendingLocalChanges(in: id) else { throw SharedLedgerError.pendingChanges }
    }

    private func hasPendingLocalChanges(in id: UUID) -> Bool {
        (try? database?.records().contains { $0.spaceID == id.uuidString && $0.localRevision != nil }) ?? false
    }

    func isOwner(_ spaceID: UUID) -> Bool {
        guard let row = try? spaceRow(spaceID) else { return false }
        return row.databaseScope == CKDatabase.Scope.private.rawValue
    }

    func deleteSpace(_ id: UUID) async throws {
        try ensureNoPendingChanges(in: id)
        guard isOwner(id) else { throw SharedLedgerError.noAccess }
        guard let database else { throw SharedLedgerError.storageUnavailable }
        let generation = accountGeneration
        let row = try spaceRow(id)
        if !demo && row.databaseScope == CKDatabase.Scope.private.rawValue {
            let zoneID = recordID(row).zoneID
            _ = try await cloud.privateCloudDatabase.deleteRecordZone(withID: zoneID)
            guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        }
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
        let records = try database.records()
        for r in records where r.spaceID == id.uuidString {
            database.context.delete(r)
        }
        try database.save()
        revokedSpaces.insert(id)
        writableSpaces.remove(id)
        if activeSpaceID == id {
            activeSpaceID = nil
        }
        saveAccountMetadata()
        try reload()
    }

    /// Owner stops sharing: participants lose access, but owner retains the space, city, and expenses.
    func stopSharing(in id: UUID) async throws {
        try ensureNoPendingChanges(in: id)
        guard isOwner(id) else { throw SharedLedgerError.noAccess }
        guard let database else { throw SharedLedgerError.storageUnavailable }
        let generation = accountGeneration

        if !demo {
            do {
                let share = try await sharingRecord(in: id)
                guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
                _ = try await cloud.privateCloudDatabase.deleteRecord(withID: share.recordID)
                guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
            } catch is CancellationError {
                throw CancellationError()
            } catch let ckError as CKError where ckError.code == .unknownItem {
                // Already removed from server
            }
        }
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }

        // Keep space and expenses for the owner; remove other members from local store
        let myID = myMemberID(in: id)
        let records = try database.records()
        for r in records where r.spaceID == id.uuidString && r.kind == "member" && !r.key.contains("member-\(myID)") {
            database.context.delete(r)
        }
        try database.save()
        try reload()
    }

    /// Participant leaves the shared space: removes participation on CloudKit shared database,
    /// and only after cloud confirmation cleans up local records.
    func leaveSpace(_ id: UUID) async throws {
        try ensureNoPendingChanges(in: id)
        guard !isOwner(id) else { throw SharedLedgerError.noAccess }
        guard let database else { throw SharedLedgerError.storageUnavailable }
        let generation = accountGeneration

        if !demo {
            let row = try spaceRow(id)
            let zoneID = recordID(row).zoneID
            do {
                let share = try await sharingRecord(in: id)
                guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
                _ = try await cloud.sharedCloudDatabase.deleteRecord(withID: share.recordID)
                guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
            } catch is CancellationError {
                throw CancellationError()
            } catch let ckError as CKError where ckError.code == .unknownItem {
                // Already removed on server
            } catch {
                do {
                    _ = try await cloud.sharedCloudDatabase.deleteRecordZone(withID: zoneID)
                    guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }
                } catch is CancellationError {
                    throw CancellationError()
                } catch let ckError as CKError where ckError.code == .unknownItem {
                    // Already removed
                }
            }
        }
        guard generation == accountGeneration, !Task.isCancelled else { throw CancellationError() }

        // Only executed if cloud removal succeeded
        let records = try database.records()
        for r in records where r.spaceID == id.uuidString {
            database.context.delete(r)
        }
        try database.save()
        revokedSpaces.insert(id)
        writableSpaces.remove(id)
        if activeSpaceID == id {
            activeSpaceID = nil
        }
        saveAccountMetadata()
        try reload()
    }

    /// Resolves an edit conflict by accepting the server version and discarding the local backup.
    func keepServerVersion(conflict: SharedExpenseConflict) throws {
        guard let database else { throw SharedLedgerError.storageUnavailable }
        if let row = try database.record(conflict.recordKey) {
            row.recoveryPayload = nil
            try database.save()
        }
        try reload()
    }

    /// Resolves an edit conflict by applying the user's local edits over the server version.
    func restoreLocalVersion(conflict: SharedExpenseConflict) throws {
        guard let database else { throw SharedLedgerError.storageUnavailable }
        try saveExpense(conflict.localExpense)
        if let row = try database.record(conflict.recordKey) {
            row.recoveryPayload = nil
            try database.save()
        }
        try reload()
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
        guard record["schemaVersion"] as? Int64 == 1 else {
            unsupportedSpaces.insert(id)
            saveAccountMetadata()
            return
        }
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
        default:
            unsupportedSpaces.insert(id)
            saveAccountMetadata()
            return
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
        guard !stopped,
              engineGenerations[ObjectIdentifier(syncEngine)] == accountGeneration,
              engines[scope] === syncEngine,
              let database else { return }
        do {
            switch event {
            case .stateUpdate(let value):
                let data = try JSONEncoder().encode(value.stateSerialization)
                if let row = try database.context.fetch(FetchDescriptor<SharedEngineState>()).first(where: { $0.scope == scope }) { row.serialization = data }
                else { database.context.insert(SharedEngineState(scope: scope, serialization: data)) }
            case .accountChange(let change):
                if case .signIn = change.changeType { return }
                handleAccountChange()
                return
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
                    if let id = spaceID(deletion.zoneID) { revoke(id, because: .terminal) }
                }
            case .sentRecordZoneChanges(let changes):
                for record in changes.savedRecords {
                    try merge(record, scope: scope, acknowledge: true)
                    if let id = spaceID(record.recordID.zoneID) {
                        revocationStrikes[id] = nil
                        saveAccountMetadata()
                    }
                }
                for failure in changes.failedRecordSaves {
                    // Classified, not guessed. A conflict keeps both versions and asks the
                    // user; a transport, server, rate or account fault keeps the change
                    // queued for CloudKit to retry. Only evidence that this account can no
                    // longer reach the zone is allowed to take a space away, and even
                    // then the queued write stays where it is until the revocation is
                    // actually believed, so a zone that reappears still has its work.
                    let kind = SharedSyncClassifier.classify(failure.error.code)
                    if kind == .conflict, let server = failure.error.serverRecord {
                        try merge(server, scope: scope, conflict: true)
                        continue
                    }
                    guard let id = spaceID(failure.record.recordID.zoneID) else { continue }
                    if kind == .zoneMissing {
                        // CloudKit's listing can lag a zone it has just written, so this
                        // is counted and only believed once it repeats.
                        if !revoke(id, because: .transient) { continue }
                    } else if kind.mayRevokeSpace {
                        revoke(id, because: .terminal)
                    }
                    // Retryable, quota, account and unknown failures fall through here on
                    // purpose: the change keeps its place in the queue, the space keeps its
                    // write access, and the row keeps its local revision. Only a believed
                    // revocation drops the queued change.
                    if !kind.keepsPendingChange {
                        syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(failure.record.recordID)])
                    }
                    // CloudKit's own retry timing wins. When it supplies a retry-after, the
                    // engine already knows; nothing here schedules a second attempt.
                    if let text = kind.reportText { errorMessage = text }
                }
            default: return
            }
            try database.save()
            try reload()
        } catch {
            // One malformed record is a bad record, not a dead engine. Tearing the whole
            // store down here used to leave the app in a shared scope with no write
            // access, no explanation, and no way back — permanently.
            database.context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = syncEngine.database.databaseScope.rawValue
        guard !stopped,
              engineGenerations[ObjectIdentifier(syncEngine)] == accountGeneration,
              engines[scope] === syncEngine,
              let database else { return nil }
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
        try await create(name: text("הבית שלנו · הדגמה", "Our home · Demo"), memberName: text("אני", "Me"),
                         currency: "ILS", mapStyle: "urban",
                         monthlyBudgetMinor: try SharedMoney.minor("8000", currency: "ILS"))
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
        // A refund, so the demo can actually show a member's net dropping below what they
        // paid rather than only ever growing. Stored negative, like the personal ledger.
        let meID = myMemberID(in: id)
        try saveExpense(SharedExpense(id: UUID(), spaceID: id, amountMinor: -1_200, currencyCode: "ILS",
            merchant: text("החזר מספקה", "Supermarket refund"), category: .food, buildingID: "food_super",
            date: Date().addingTimeInterval(-3_600 * 5), note: "", paidBy: meID, createdBy: meID, updatedBy: meID))
        // A foreign-currency record with no rate applied. It must show up in the record
        // count and stay out of the money, which is only visible if one exists.
        try saveExpense(SharedExpense(id: UUID(), spaceID: id, amountMinor: 4_500, currencyCode: "ILS",
            merchant: text("טיסה", "Flight"), category: .transport, buildingID: "transport_air",
            date: Date().addingTimeInterval(-3_600 * 30), note: "", paidBy: partner.id, createdBy: partner.id,
            updatedBy: partner.id, originalAmount: "120.00", originalCurrency: "USD",
            exchangeRate: nil, exchangeRateDate: nil))
    }

    func markSpaceRevokedForTesting(_ id: UUID) {
        revokedSpaces.insert(id)
        writableSpaces.remove(id)
        saveAccountMetadata()
        try? reload()
    }

    func markSpaceUnsupportedForTesting(_ id: UUID) {
        unsupportedSpaces.insert(id)
        writableSpaces.remove(id)
        saveAccountMetadata()
        try? reload()
    }
    #endif
}
#endif
