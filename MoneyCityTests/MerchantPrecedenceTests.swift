import XCTest
@testable import MoneyCity

final class MerchantPrecedenceTests: XCTestCase {

    var remoteConfig: RemoteConfigService!
    var communityCache: CommunityMerchantCache!
    var defaults: UserDefaults!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test_precedence_\(UUID().uuidString)")!
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        communityCache = CommunityMerchantCache(storageURL: tempDir.appendingPathComponent("test_cache.json"))

        // Create remote config with communityMerchantLearning = true
        var root = RemoteConfigRoot.bundledDefault
        root.features["communityMerchantLearning"] = true
        remoteConfig = RemoteConfigService(defaults: defaults)
        remoteConfig.updateConfig(root)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: defaults.description)
        super.tearDown()
    }

    func testUserRuleBeatsRemoteOverride() {
        let merchant = "Wolt"
        // Remote override exists for Wolt -> food
        XCTAssertEqual(remoteConfig.merchantOverride(for: merchant), .food)

        // User personal rule set to entertainment
        let userRule = MerchantRule(
            merchantKey: MerchantRuleService.normalizedKey(merchant),
            displayName: merchant,
            category: .entertainment
        )

        let result = MerchantRuleService.classify(
            merchant: merchant,
            amount: 50.0,
            rules: [userRule],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        XCTAssertEqual(result.category, .entertainment)
        XCTAssertEqual(result.source, .userRule)
        XCTAssertEqual(result.confidence, 1.0)
    }

    func testUserRuleBeatsCommunityConfirmed() {
        let merchant = "מכולת השכונה"
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)
        communityCache.setEntry(
            CommunityCacheEntry(
                merchantHash: hash,
                winnerCategoryRawValue: SpendingCategory.food.rawValue,
                status: .confirmed,
                winningVotes: 10,
                totalVotes: 10,
                agreementRatio: 1.0
            )
        )

        // User personal rule set to shopping
        let userRule = MerchantRule(
            merchantKey: MerchantRuleService.normalizedKey(merchant),
            displayName: merchant,
            category: .shopping
        )

        let result = MerchantRuleService.classify(
            merchant: merchant,
            amount: 50.0,
            rules: [userRule],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        XCTAssertEqual(result.category, .shopping)
        XCTAssertEqual(result.source, .userRule)
    }

    func testUserRuleBeatsCommunitySuggestion() {
        let merchant = "חנות פינתית"
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)
        communityCache.setEntry(
            CommunityCacheEntry(
                merchantHash: hash,
                winnerCategoryRawValue: SpendingCategory.shopping.rawValue,
                status: .suggestion,
                winningVotes: 2,
                totalVotes: 2,
                agreementRatio: 1.0
            )
        )

        let userRule = MerchantRule(
            merchantKey: MerchantRuleService.normalizedKey(merchant),
            displayName: merchant,
            category: .entertainment
        )

        let result = MerchantRuleService.classify(
            merchant: merchant,
            amount: 50.0,
            rules: [userRule],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        XCTAssertEqual(result.category, .entertainment)
        XCTAssertEqual(result.source, .userRule)
    }

    func testRemoteOverrideBeatsCommunityConfirmed() {
        let merchant = "Wolt"
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)
        // Community mistakenly cached Wolt as shopping
        communityCache.setEntry(
            CommunityCacheEntry(
                merchantHash: hash,
                winnerCategoryRawValue: SpendingCategory.shopping.rawValue,
                status: .confirmed,
                winningVotes: 10,
                totalVotes: 10,
                agreementRatio: 1.0
            )
        )

        let result = MerchantRuleService.classify(
            merchant: merchant,
            amount: 50.0,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        // Remote override wins
        XCTAssertEqual(result.category, .food)
        XCTAssertEqual(result.source, .remoteOverride)
        XCTAssertEqual(result.confidence, 0.98)
    }

    func testCommunityConfirmedBeatsHeuristic() {
        let merchant = "עסק חדש לגמרי ללא מילות מפתח"
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)
        communityCache.setEntry(
            CommunityCacheEntry(
                merchantHash: hash,
                winnerCategoryRawValue: SpendingCategory.health.rawValue,
                status: .confirmed,
                winningVotes: 4,
                totalVotes: 4,
                agreementRatio: 1.0
            )
        )

        let result = MerchantRuleService.classify(
            merchant: merchant,
            amount: 50.0,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        XCTAssertEqual(result.category, .health)
        XCTAssertEqual(result.source, .communityConfirmed)
        XCTAssertEqual(result.confidence, 0.95)
    }

    func testCommunitySuggestionProvidesSuggestion() {
        let merchant = "עסק לא מוכר"
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)
        communityCache.setEntry(
            CommunityCacheEntry(
                merchantHash: hash,
                winnerCategoryRawValue: SpendingCategory.transport.rawValue,
                status: .suggestion,
                winningVotes: 2,
                totalVotes: 2,
                agreementRatio: 1.0
            )
        )

        let result = MerchantRuleService.classify(
            merchant: merchant,
            amount: 50.0,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        XCTAssertEqual(result.category, .transport)
        XCTAssertEqual(result.source, .communitySuggestion)
        XCTAssertEqual(result.confidence, 0.85)
    }

    func testHeuristicStillWorksWhenCacheIsEmpty() {
        // "פז" is a known gas heuristic keyword in the built-in dictionary
        let result = MerchantRuleService.classify(
            merchant: "תחנת דלק פז",
            amount: 200.0,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        XCTAssertEqual(result.category, .transport)
        XCTAssertEqual(result.source, .heuristic)
    }

    func testUnknownFallsBackToOther() {
        let result = MerchantRuleService.classify(
            merchant: "xyzqrs998877",
            amount: 100.0,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        XCTAssertEqual(result.category, .other)
        XCTAssertEqual(result.source, .unknown)
    }

    func testKnownMajorMerchantsAreCuratedAndTrusted() {
        let majorMerchants = [
            ("Wolt", SpendingCategory.food),
            ("shufersal", SpendingCategory.food),
            ("רמי לוי", SpendingCategory.food),
            ("AM:PM", SpendingCategory.food),
            ("Gett", SpendingCategory.transport),
            ("Super-Pharm", SpendingCategory.health),
            ("Zara", SpendingCategory.shopping)
        ]

        for (merchant, expectedCat) in majorMerchants {
            let result = MerchantRuleService.classify(
                merchant: merchant,
                amount: 40.0,
                rules: [],
                remoteConfig: remoteConfig,
                communityCache: communityCache
            )
            XCTAssertEqual(result.category, expectedCat, "Failed for \(merchant)")
            XCTAssertEqual(result.source, .remoteOverride, "\(merchant) must be curated remote override")
        }
    }

    func testCommunityConfirmedDoesNotPersistPersonalMerchantRule() {
        let merchant = "עסק חדש בקהילה"
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)
        communityCache.setEntry(
            CommunityCacheEntry(
                merchantHash: hash,
                winnerCategoryRawValue: SpendingCategory.food.rawValue,
                status: .confirmed,
                winningVotes: 5,
                totalVotes: 5,
                agreementRatio: 1.0
            )
        )

        var rules: [MerchantRule] = []

        let result = MerchantRuleService.classify(
            merchant: merchant,
            amount: 50.0,
            rules: rules,
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        XCTAssertEqual(result.source, .communityConfirmed)
        XCTAssertEqual(result.category, .food)
        // Personal rules must remain empty; community learning never auto-creates user rules
        XCTAssertTrue(rules.isEmpty)
        XCTAssertNil(MerchantRuleService.rule(for: merchant, in: rules))
    }
}
