import XCTest
import CloudKit
@testable import MoneyCity

final class MockCommunityCloudDatabase: CommunityCloudDatabaseProtocol, @unchecked Sendable {
    var status: CKAccountStatus = .available
    var userID: String = "test-user-record-id-123"
    var shouldFailSave: Bool = false
    var savedRecords: [String: (merchantHash: String, category: String)] = [:]
    var mockVotes: [String: [CommunityVote]] = [:]

    func accountStatus() async throws -> CKAccountStatus {
        return status
    }

    func currentUserID() async throws -> String {
        return userID
    }

    func saveVoteRecord(recordName: String, merchantHash: String, categoryRawValue: String) async throws {
        if shouldFailSave {
            throw NSError(domain: CKErrorDomain, code: CKError.networkUnavailable.rawValue, userInfo: nil)
        }
        savedRecords[recordName] = (merchantHash, categoryRawValue)
    }

    func fetchVotes(merchantHash: String) async throws -> [CommunityVote] {
        return mockVotes[merchantHash] ?? []
    }
}

final class CommunityMerchantServiceTests: XCTestCase {

    var mockClient: MockCommunityCloudDatabase!
    var cache: CommunityMerchantCache!
    var remoteConfig: RemoteConfigService!
    var service: CommunityMerchantService!
    var defaults: UserDefaults!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test_service_\(UUID().uuidString)")!
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let cacheURL = tempDir.appendingPathComponent("test_cache.json")
        let outboxURL = tempDir.appendingPathComponent("test_outbox.json")
        cache = CommunityMerchantCache(storageURL: cacheURL)

        var root = RemoteConfigRoot.bundledDefault
        root.features["communityMerchantLearning"] = true
        remoteConfig = RemoteConfigService(defaults: defaults)
        remoteConfig.updateConfig(root)

        mockClient = MockCommunityCloudDatabase()
        service = CommunityMerchantService(
            client: mockClient,
            cache: cache,
            remoteConfig: remoteConfig,
            outboxURL: outboxURL
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: defaults.description)
        super.tearDown()
    }

    func testSuccessfulVoteUpload() async {
        let merchant = "מכולת דוד"
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)

        await service.submitOrQueueVote(merchantHash: hash, category: .food)

        let expectedRecordName = CommunityMerchantIdentity.voteRecordName(
            userRecordName: mockClient.userID,
            merchantHash: hash
        )
        XCTAssertNotNil(mockClient.savedRecords[expectedRecordName])
        XCTAssertEqual(mockClient.savedRecords[expectedRecordName]?.category, SpendingCategory.food.rawValue)
        XCTAssertEqual(mockClient.savedRecords[expectedRecordName]?.merchantHash, hash)
    }

    func testOfflineQueuesToOutboxAndDrainsOnReconnect() async {
        let merchant = "מכולת דוד"
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)

        // Simulate network failure
        mockClient.shouldFailSave = true
        await service.submitOrQueueVote(merchantHash: hash, category: .food)

        // Nothing saved in CloudKit yet
        XCTAssertTrue(mockClient.savedRecords.isEmpty)

        // Network recovers
        mockClient.shouldFailSave = false
        await service.drainOutbox()

        let expectedRecordName = CommunityMerchantIdentity.voteRecordName(
            userRecordName: mockClient.userID,
            merchantHash: hash
        )
        XCTAssertNotNil(mockClient.savedRecords[expectedRecordName])
        XCTAssertEqual(mockClient.savedRecords[expectedRecordName]?.category, SpendingCategory.food.rawValue)
    }

    func testOutboxDeduplicatesMultipleVotesForSameMerchant() async {
        let hash = CommunityMerchantIdentity.merchantHash(for: "עסק בדיקה")

        // First offline vote
        mockClient.shouldFailSave = true
        await service.submitOrQueueVote(merchantHash: hash, category: .food)

        // User changes mind while still offline
        await service.submitOrQueueVote(merchantHash: hash, category: .shopping)

        // Drain on reconnect
        mockClient.shouldFailSave = false
        await service.drainOutbox()

        let expectedRecordName = CommunityMerchantIdentity.voteRecordName(
            userRecordName: mockClient.userID,
            merchantHash: hash
        )
        // Only one record saved, with the newest choice (shopping)
        XCTAssertEqual(mockClient.savedRecords.count, 1)
        XCTAssertEqual(mockClient.savedRecords[expectedRecordName]?.category, SpendingCategory.shopping.rawValue)
    }

    func testNoAccountDoesNotQueueOrThrow() async {
        mockClient.status = .noAccount

        let hash = CommunityMerchantIdentity.merchantHash(for: "עסק בדיקה")
        await service.submitOrQueueVote(merchantHash: hash, category: .food)

        XCTAssertTrue(mockClient.savedRecords.isEmpty)

        // Even after a drain, nothing is pending
        mockClient.status = .available
        await service.drainOutbox()
        XCTAssertTrue(mockClient.savedRecords.isEmpty)
    }

    func testCacheCorruptionRecoversSafely() {
        let cacheFile = tempDir.appendingPathComponent("corrupted_cache.json")
        try? "not a valid json".data(using: .utf8)?.write(to: cacheFile)

        let corruptCache = CommunityMerchantCache(storageURL: cacheFile)
        XCTAssertTrue(corruptCache.allEntries().isEmpty)

        // Saving works after corruption recovery
        corruptCache.setEntry(
            CommunityCacheEntry(
                merchantHash: "hash123",
                winnerCategoryRawValue: SpendingCategory.food.rawValue,
                status: .confirmed,
                winningVotes: 3,
                totalVotes: 3,
                agreementRatio: 1.0
            )
        )
        XCTAssertEqual(corruptCache.entry(for: "hash123")?.winnerCategory, .food)
    }

    func testDeterministicVoteRecordIDReplacesPreviousChoice() {
        let user = "user-abc"
        let hash = CommunityMerchantIdentity.merchantHash(for: "AM:PM")

        let recordName1 = CommunityMerchantIdentity.voteRecordName(userRecordName: user, merchantHash: hash)
        let recordName2 = CommunityMerchantIdentity.voteRecordName(userRecordName: user, merchantHash: hash)

        // Must be stable and identical
        XCTAssertEqual(recordName1, recordName2)
        XCTAssertFalse(recordName1.isEmpty)
    }

    func testMerchantHashIsDeterministicAndDoesNotContainMerchantString() {
        let hash1 = CommunityMerchantIdentity.merchantHash(for: "  WOLT  ")
        let hash2 = CommunityMerchantIdentity.merchantHash(for: "wolt")

        XCTAssertEqual(hash1, hash2)
        XCTAssertFalse(hash1.lowercased().contains("wolt"), "Hash must be pseudonymous digest, not raw name")
        XCTAssertEqual(hash1.count, 64, "SHA-256 hex string should be 64 characters")
    }

    func testAccountIdentityMismatchDoesNotSubmitStaleVote() async {
        let hash = CommunityMerchantIdentity.merchantHash(for: "עסק בדיקה")

        // User 1 queues a vote while offline
        let user1 = "user-account-1"
        let voter1 = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: user1)
        service.queuePendingVote(voterId: voter1, merchantHash: hash, categoryRawValue: SpendingCategory.food.rawValue)

        XCTAssertEqual(service.pendingOutboxCount(), 1)

        // Device switches to User 2 before outbox drains
        mockClient.userID = "user-account-2"
        mockClient.status = .available
        mockClient.shouldFailSave = false

        await service.drainOutbox()

        // Vote must NOT be submitted under User 2's account, and should be discarded
        XCTAssertTrue(mockClient.savedRecords.isEmpty, "Pending vote from another account must not be saved")
        XCTAssertEqual(service.pendingOutboxCount(), 0, "Stale mismatched vote must be purged from outbox")
    }

    @MainActor
    func testSwipeActionRowTapSuppressorSuppressesTapTemporarily() {
        SwipeActionRowTapSuppressor.resetForTesting()
        XCTAssertFalse(SwipeActionRowTapSuppressor.shouldSuppress())

        SwipeActionRowTapSuppressor.suppressNext()
        XCTAssertTrue(SwipeActionRowTapSuppressor.shouldSuppress())

        SwipeActionRowTapSuppressor.resetForTesting()
        XCTAssertFalse(SwipeActionRowTapSuppressor.shouldSuppress())
    }
}
