import XCTest
import CloudKit
import SwiftData
@testable import MoneyCity

final class MockSharedCloudAccountProvider: SharedCloudAccountProvider, @unchecked Sendable {
    var status: CKAccountStatus
    var recordID: CKRecord.ID
    var statusError: Error?

    var onAccountStatusCalled: (() -> Void)?
    var statusContinuation: CheckedContinuation<CKAccountStatus, Error>?

    init(
        status: CKAccountStatus = .available,
        recordID: CKRecord.ID = CKRecord.ID(recordName: "user-A")
    ) {
        self.status = status
        self.recordID = recordID
    }

    func accountStatus() async throws -> CKAccountStatus {
        if let statusError { throw statusError }
        if let onAccountStatusCalled {
            onAccountStatusCalled()
            return try await withCheckedThrowingContinuation { continuation in
                self.statusContinuation = continuation
            }
        }
        return status
    }

    func userRecordID() async throws -> CKRecord.ID {
        return recordID
    }
}

@MainActor
final class SharedAccountIsolationTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: "shared_spaces_enabled")
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SharedIsolationTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "shared_spaces_enabled")
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try await super.tearDown()
    }

    @discardableResult
    private func insertMockSpace(
        to store: SharedWorkspaceStore,
        id: UUID = UUID(),
        name: String = "Test Space",
        schemaVersion: Int = 1
    ) throws -> UUID {
        guard let database = store.database else {
            throw SharedLedgerError.storageUnavailable
        }
        let space = SharedSpace(
            id: id,
            name: name,
            currencyCode: "ILS",
            timeZoneID: TimeZone.current.identifier,
            mapStyle: "urban",
            createdAt: Date()
        )
        let payload = try JSONEncoder().encode(space)
        let zoneName = "space-" + id.uuidString
        let zoneOwner = "_mock_owner_"
        let key = "\(zoneOwner)|\(zoneName)|space"
        let record = SharedStoredRecord(
            key: key,
            spaceID: id.uuidString,
            kind: "space",
            payload: payload,
            zoneName: zoneName,
            zoneOwner: zoneOwner,
            databaseScope: CKDatabase.Scope.private.rawValue
        )
        record.schemaVersion = schemaVersion
        database.context.insert(record)
        try database.save()
        try store.reload()
        return id
    }

    // MARK: - Scenario 1: Revoked space stays hidden after store recreation
    func testRevokedSpaceStaysHiddenAfterStoreRecreation() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store1 = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await store1.connect()

        let spaceID = try insertMockSpace(to: store1, name: "Revoked Family")
        XCTAssertEqual(store1.spaces.count, 1)

        store1.markSpaceRevokedForTesting(spaceID)
        XCTAssertTrue(store1.isSpaceRevoked(spaceID))
        XCTAssertTrue(store1.spaces.isEmpty, "Revoked space must immediately be filtered out of spaces")

        // Recreate the store from the same rootDirectory (simulating app restart)
        let store2 = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await store2.connect()

        XCTAssertTrue(store2.isSpaceRevoked(spaceID), "Revocation must persist across store recreation")
        XCTAssertTrue(store2.spaces.isEmpty, "Revoked space must remain hidden after recreation")
        store2.select(spaceID)
        XCTAssertNil(store2.activeSpaceID, "Cannot select a revoked space")
    }

    // MARK: - Scenario 2: Unsupported space stays blocked after restart
    func testUnsupportedSpaceStaysBlockedAfterRestart() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store1 = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await store1.connect()

        let spaceID = try insertMockSpace(to: store1, name: "Future Space", schemaVersion: 2)
        store1.markSpaceUnsupportedForTesting(spaceID)

        XCTAssertTrue(store1.isSpaceUnsupported(spaceID))
        XCTAssertFalse(store1.canWrite(spaceID))
        XCTAssertTrue(store1.spaces.isEmpty)

        // Recreate the store
        let store2 = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await store2.connect()

        XCTAssertTrue(store2.isSpaceUnsupported(spaceID), "Unsupported schema status must persist across restarts")
        XCTAssertFalse(store2.canWrite(spaceID))
        XCTAssertTrue(store2.spaces.isEmpty)
        store2.select(spaceID)
        XCTAssertNil(store2.activeSpaceID)
    }

    // MARK: - Scenario 3: Retryable CloudKit error does not persist revocation
    func testRetryableCloudKitErrorDoesNotPersistRevocation() async throws {
        let retryableCodes: [CKError.Code] = [
            .networkUnavailable,
            .networkFailure,
            .serviceUnavailable,
            .requestRateLimited,
            .zoneBusy,
            .internalError,
            .operationCancelled
        ]

        for code in retryableCodes {
            let failure = SharedSyncClassifier.classify(code)
            XCTAssertFalse(failure.mayRevokeSpace, "Code \(code) must not revoke space")
            XCTAssertTrue(failure.keepsPendingChange, "Code \(code) must keep pending changes queued")
        }

        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await store.connect()

        let spaceID = try insertMockSpace(to: store, name: "Active Space")
        XCTAssertEqual(store.spaces.count, 1)

        XCTAssertFalse(store.isSpaceRevoked(spaceID))
        XCTAssertTrue(store.activeRevokedSpaces.isEmpty)
    }

    // MARK: - Scenario 4: Account A to No Account hides A's spaces
    func testAccountAToNoAccountHidesASpaces() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        let scope = AppScopeContext(store: store)
        try await store.connect()

        let spaceID = try insertMockSpace(to: store, name: "Account A Space")
        store.select(spaceID)
        XCTAssertEqual(store.activeSpaceID, spaceID)
        XCTAssertEqual(scope.activeScope, .shared(spaceID: spaceID))

        // Transition to no account
        provider.status = .noAccount
        do {
            try await store.connect()
            XCTFail("Connecting with no account should throw .noAccount")
        } catch let err as SharedLedgerError {
            XCTAssertEqual(err, .noAccount)
        }

        XCTAssertTrue(store.spaces.isEmpty, "No account must hide all shared spaces")
        XCTAssertNil(store.activeSpaceID, "Active space must reset to nil")
        XCTAssertEqual(scope.activeScope, .personal, "AppScopeContext must revert to personal mode")
    }

    // MARK: - Scenario 5: Account A to Account B never shows A's spaces
    func testAccountAToAccountBNeverShowsASpaces() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let storeA = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await storeA.connect()

        let spaceA = try insertMockSpace(to: storeA, name: "User A Space")
        XCTAssertEqual(storeA.spaces.count, 1)
        XCTAssertEqual(storeA.spaces.first?.id, spaceA)

        // Switch to Account B
        provider.recordID = CKRecord.ID(recordName: "user-B")
        let storeB = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await storeB.connect()

        XCTAssertTrue(storeB.spaces.isEmpty, "Account B must not see any of Account A's spaces")
        XCTAssertFalse(storeB.spaces.contains(where: { $0.id == spaceA }))
    }

    // MARK: - Scenario 6: Account B cannot read A's active space ID
    func testAccountBCannotReadAActiveSpaceID() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let storeA = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await storeA.connect()

        let spaceA = try insertMockSpace(to: storeA, name: "Secret Space A")
        storeA.select(spaceA)
        XCTAssertEqual(storeA.activeSpaceID, spaceA)

        // Switch to Account B
        provider.recordID = CKRecord.ID(recordName: "user-B")
        let storeB = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await storeB.connect()

        XCTAssertNil(storeB.activeSpaceID, "Account B must start with nil activeSpaceID, not Account A's")
        XCTAssertNotEqual(storeB.activeSpaceID, spaceA)
    }

    // MARK: - Scenario 7: Account A returning reloads only A's scoped state
    func testAccountAReturningReloadsOnlyAScopedState() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let storeA1 = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await storeA1.connect()

        let spaceA = try insertMockSpace(to: storeA1, name: "Persisted Space A")
        storeA1.select(spaceA)
        XCTAssertEqual(storeA1.activeSpaceID, spaceA)

        // Transition to Account B
        provider.recordID = CKRecord.ID(recordName: "user-B")
        let storeB = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await storeB.connect()
        let spaceB = try insertMockSpace(to: storeB, name: "Persisted Space B")
        storeB.select(spaceB)
        XCTAssertEqual(storeB.activeSpaceID, spaceB)

        // Return to Account A
        provider.recordID = CKRecord.ID(recordName: "user-A")
        let storeA2 = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await storeA2.connect()

        XCTAssertEqual(storeA2.spaces.count, 1)
        XCTAssertEqual(storeA2.spaces.first?.id, spaceA)
        XCTAssertFalse(storeA2.spaces.contains(where: { $0.id == spaceB }), "Account A must not see Account B's spaces")
        XCTAssertEqual(storeA2.activeSpaceID, spaceA, "Account A's active space must be restored cleanly")
    }

    // MARK: - Scenario 8: Personal store survives all account transitions unchanged
    func testPersonalStoreSurvivesAllAccountTransitionsUnchanged() async throws {
        let initialCurrency = UserDefaults.standard.string(forKey: "app_currency_pref")
        let initialLang = UserDefaults.standard.string(forKey: "app_lang_pref")

        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        let scope = AppScopeContext(store: store)

        // Initial Personal State
        XCTAssertEqual(scope.activeScope, .personal)

        // Account A connect & select
        try await store.connect()
        let spaceA = try insertMockSpace(to: store, name: "A Space")
        store.select(spaceA)
        XCTAssertEqual(scope.activeScope, .shared(spaceID: spaceA))

        // Account Change to No Account
        provider.status = .noAccount
        store.handleAccountChange()
        XCTAssertEqual(scope.activeScope, .personal)

        // Account B connect
        provider.status = .available
        provider.recordID = CKRecord.ID(recordName: "user-B")
        try await store.connect()
        XCTAssertEqual(scope.activeScope, .personal)

        // Return to Account A
        provider.recordID = CKRecord.ID(recordName: "user-A")
        try await store.connect()
        store.select(spaceA)
        XCTAssertEqual(scope.activeScope, .shared(spaceID: spaceA))

        // Revert to Personal
        scope.selectPersonal()
        XCTAssertEqual(scope.activeScope, .personal)

        // Verify Personal prefs were never disturbed
        XCTAssertEqual(UserDefaults.standard.string(forKey: "app_currency_pref"), initialCurrency)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "app_lang_pref"), initialLang)
    }

    // MARK: - Scenario 9: Foreground refresh cannot resurrect revoked space
    func testForegroundRefreshCannotResurrectRevokedSpace() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await store.connect()

        let spaceID = try insertMockSpace(to: store, name: "Terminal Revoked Space")
        store.markSpaceRevokedForTesting(spaceID)
        XCTAssertTrue(store.isSpaceRevoked(spaceID))
        XCTAssertTrue(store.spaces.isEmpty)

        // Foreground refresh occurs (no CloudKit zone reappeared)
        await store.refreshOnForeground(now: Date())

        XCTAssertTrue(store.isSpaceRevoked(spaceID), "Foreground refresh must not un-revoke a revoked space")
        XCTAssertTrue(store.spaces.isEmpty, "Space must remain hidden")
        XCTAssertNil(store.activeSpaceID)
    }

    // MARK: - Scenario 10: Concurrent account change and refresh remains safe
    func testConcurrentAccountChangeAndRefreshRemainsSafe() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)
        try await store.connect()

        let _ = try insertMockSpace(to: store, name: "Concurrent Test Space")
        XCTAssertEqual(store.spaces.count, 1)

        // Concurrently trigger account change (sign out) and discover/refresh
        provider.status = .noAccount
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                store.handleAccountChange()
            }
            group.addTask { @MainActor in
                await store.discover()
            }
            group.addTask { @MainActor in
                await store.refreshOnForeground(now: Date().addingTimeInterval(100))
            }
        }

        // Must settle safely without crashing or leaking state
        XCTAssertTrue(store.spaces.isEmpty, "After account change, in-memory spaces must be cleared")
        XCTAssertNil(store.activeSpaceID)
    }

    // MARK: - Scenario 11: Stale Account A async connect cannot repopulate after sign out
    func testStaleAccountAAsyncConnectCannotRepopulateAfterSignOut() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)

        // 1. First populate Account A with data on disk so if it did re-connect, spaces would exist
        try await store.connect()
        let _ = try insertMockSpace(to: store, name: "Secret Space A")
        XCTAssertEqual(store.spaces.count, 1)

        // Reset store state simulating fresh launch or sign-out
        store.handleAccountChange()
        XCTAssertTrue(store.spaces.isEmpty)
        XCTAssertNil(store.connectedAccount)
        XCTAssertNil(store.database)

        // 2. Set up controllable suspension in CloudKit accountStatus()
        let statusSuspended = expectation(description: "Account status call suspended")
        provider.onAccountStatusCalled = {
            statusSuspended.fulfill()
        }

        // 3. Launch Account A connect
        let staleConnectTask = Task { @MainActor in
            try await store.connect()
        }

        // 4. Wait until Account A is confirmed suspended at the CloudKit boundary
        await fulfillment(of: [statusSuspended], timeout: 2.0)

        // 5. User signs out before CloudKit responds
        provider.onAccountStatusCalled = nil
        provider.status = .noAccount
        store.handleAccountChange()

        // 6. Account A's suspended CloudKit await returns with a successful result
        provider.statusContinuation?.resume(returning: .available)

        // 7. Stale task must fail with CancellationError and MUST NOT apply state
        do {
            try await staleConnectTask.value
            XCTFail("Stale Account A connect must throw CancellationError when resumed after handleAccountChange")
        } catch is CancellationError {
            // Expected: epoch mismatch throws CancellationError
        } catch {
            XCTFail("Expected CancellationError but got \(error)")
        }

        // 8. Assert ZERO Account A state repopulated
        XCTAssertNil(store.connectedAccount, "Stale task must not set connectedAccount")
        XCTAssertNil(store.database, "Stale task must not recreate database")
        XCTAssertTrue(store.spaces.isEmpty, "Stale task must not load spaces from disk")
        XCTAssertNil(store.activeSpaceID, "Stale task must not set activeSpaceID")
    }

    // MARK: - Scenario 12: Stale Account A async connect cannot overwrite Account B state
    func testStaleAccountAAsyncConnectCannotOverwriteAccountBState() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)

        // 1. Populate Account A with data
        try await store.connect()
        let _ = try insertMockSpace(to: store, name: "Account A Space")
        store.handleAccountChange()

        // 2. Account A begins connecting and suspends in CloudKit
        let statusSuspended = expectation(description: "Account status call suspended for A")
        provider.onAccountStatusCalled = {
            statusSuspended.fulfill()
        }

        let staleConnectTaskA = Task { @MainActor in
            try await store.connect()
        }

        await fulfillment(of: [statusSuspended], timeout: 2.0)

        // 3. User switches to Account B while Account A is suspended
        provider.onAccountStatusCalled = nil
        provider.recordID = CKRecord.ID(recordName: "user-B")
        provider.status = .available
        store.handleAccountChange()

        // 4. Account B connects and establishes its own workspace
        try await store.connect()
        let spaceB = try insertMockSpace(to: store, name: "Account B Space")
        store.select(spaceB)

        XCTAssertEqual(store.connectedAccount, "user-B")
        XCTAssertEqual(store.spaces.count, 1)
        XCTAssertEqual(store.spaces.first?.id, spaceB)
        XCTAssertEqual(store.activeSpaceID, spaceB)

        // 5. Account A resumes with a stale successful result
        provider.statusContinuation?.resume(returning: .available)

        _ = try? await staleConnectTaskA.value

        // 6. Assert Account B's state remains 100% pure and untouched
        XCTAssertEqual(store.connectedAccount, "user-B", "Account B must remain the connected account")
        XCTAssertEqual(store.spaces.count, 1, "Only Account B spaces may exist")
        XCTAssertEqual(store.spaces.first?.id, spaceB, "Space B must remain intact")
        XCTAssertEqual(store.activeSpaceID, spaceB, "Space B must remain active")
    }

    // MARK: - Scenario 13: Stale Account A refresh or engine event cannot mutate Account B after switch
    func testStaleAccountARefreshOrEngineEventCannotMutateAccountBAfterSwitch() async throws {
        let provider = MockSharedCloudAccountProvider(status: .available, recordID: CKRecord.ID(recordName: "user-A"))
        let store = SharedWorkspaceStore(rootDirectory: tempDir, accountProvider: provider)

        // 1. Account A connects and establishes its sync engine
        try await store.connect()
        let engineA = store.engineForTesting(scope: .private)
        XCTAssertNotNil(engineA, "Account A should have an initialized sync engine")
        XCTAssertTrue(store.isEngineActiveForTesting(engineA!), "Engine A must be active while on Account A")

        // 2. Account A initiates refresh and suspends at CloudKit await boundary
        let refreshSuspended = expectation(description: "Account A refresh suspended")
        var resumeRefreshContinuation: CheckedContinuation<Void, Never>?
        store.onRefreshSuspensionHook = {
            refreshSuspended.fulfill()
            await withCheckedContinuation { continuation in
                resumeRefreshContinuation = continuation
            }
        }

        let staleRefreshTaskA = Task { @MainActor in
            try await store.refresh()
        }

        await fulfillment(of: [refreshSuspended], timeout: 2.0)

        // 3. User switches to Account B while Account A's refresh is suspended
        store.onRefreshSuspensionHook = nil
        provider.recordID = CKRecord.ID(recordName: "user-B")
        store.handleAccountChange()

        // Account B connects and establishes its workspace
        try await store.connect()
        let engineB = store.engineForTesting(scope: .private)
        XCTAssertNotNil(engineB, "Account B should have an initialized sync engine")
        let spaceB = try insertMockSpace(to: store, name: "Account B Pure Space")
        store.select(spaceB)

        // 4. Verify Account A's old engine is structurally invalidated and rejected
        XCTAssertFalse(store.isEngineActiveForTesting(engineA!), "Account A engine must be rejected by active store guards")
        XCTAssertTrue(store.isEngineActiveForTesting(engineB!), "Only Account B engine may be accepted")

        // 5. Resume Account A's stale refresh with successful return
        resumeRefreshContinuation?.resume()

        do {
            try await staleRefreshTaskA.value
            XCTFail("Stale Account A refresh must throw CancellationError upon resuming after account switch")
        } catch is CancellationError {
            // Expected: epoch token mismatch triggers immediate CancellationError
        } catch {
            XCTFail("Expected CancellationError but got \(error)")
        }

        // 6. Assert Account B's state remains completely untainted
        XCTAssertEqual(store.connectedAccount, "user-B", "Account B must remain active")
        XCTAssertEqual(store.spaces.count, 1, "Only Account B space may exist")
        XCTAssertEqual(store.spaces.first?.id, spaceB, "Space B must remain intact")
        XCTAssertEqual(store.activeSpaceID, spaceB, "Space B must remain active")
        XCTAssertTrue(store.activeRevokedSpaces.isEmpty, "No revoked spaces from Account A may leak")
        XCTAssertTrue(store.activeUnsupportedSpaces.isEmpty, "No unsupported spaces from Account A may leak")
    }
}
