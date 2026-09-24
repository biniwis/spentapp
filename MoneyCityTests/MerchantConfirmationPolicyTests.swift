import XCTest
@testable import MoneyCity

final class MerchantConfirmationPolicyTests: XCTestCase {

    var remoteConfig: RemoteConfigService!
    var communityCache: CommunityMerchantCache!
    var defaults: UserDefaults!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test_policy_\(UUID().uuidString)")!
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        communityCache = CommunityMerchantCache(storageURL: tempDir.appendingPathComponent("test_cache.json"))

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

    private func makeTx(
        merchant: String,
        amount: Double = 50.0,
        category: SpendingCategory = .food,
        isManual: Bool = false,
        note: String? = nil,
        isConfirmed: Bool = true,
        date: Date = Date(),
        currency: String = "₪"
    ) -> Transaction {
        Transaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            category: category,
            timestamp: date,
            confidenceScore: 0.95,
            isManual: isManual,
            isConfirmed: isConfirmed,
            note: note,
            buildingId: "food_bistro"
        )
    }

    func testEligibleTransactionShowsConfirmation() {
        let tx = makeTx(merchant: "מכולת דוד")
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertTrue(eligible)
    }

    func testManualTransactionDoesNotShowConfirmation() {
        let tx = makeTx(merchant: "מכולת דוד", isManual: true)
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertFalse(eligible)
    }

    func testRefundTransactionDoesNotShowConfirmation() {
        let tx = makeTx(merchant: "מכולת דוד", amount: -50.0, note: "זיכוי")
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertFalse(eligible)
    }

    func testUnresolvedFXDoesNotShowConfirmation() {
        // EUR charge with nil exchangeRate in ILS base currency is unresolved foreign
        let tx = Transaction(
            amount: 50.0,
            currency: "€",
            merchant: "Cafe Paris",
            category: .food,
            timestamp: Date(),
            confidenceScore: 0.9,
            isManual: false,
            isConfirmed: false,
            note: "Foreign currency",
            buildingId: "food_bistro",
            originalAmount: 50.0,
            originalCurrency: "EUR",
            exchangeRate: nil
        )
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertFalse(eligible)
    }

    func testOtherCategoryDoesNotShowConfirmation() {
        let tx = makeTx(merchant: "עסק מוזר", category: .other)
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertFalse(eligible)
    }

    func testExistingPersonalRuleSuppressesConfirmation() {
        let merchant = "מכולת דוד"
        let tx = makeTx(merchant: merchant)
        let rule = MerchantRule(
            merchantKey: MerchantRuleService.normalizedKey(merchant),
            displayName: merchant,
            category: .food
        )
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [rule],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertFalse(eligible)
    }

    func testCuratedRemoteOverrideSuppressesConfirmation() {
        // Wolt is in curated remote overrides
        let tx = makeTx(merchant: "Wolt")
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertFalse(eligible)
    }

    func testCommunityConfirmedSuppressesConfirmation() {
        let merchant = "עסק שכבר אושר בקהילה"
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

        let tx = makeTx(merchant: merchant)
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertFalse(eligible)
    }

    func testEmptyOrGenericUnknownMerchantSuppressesConfirmation() {
        let blankTx = makeTx(merchant: "   ")
        XCTAssertFalse(MerchantConfirmationPolicy.isEligible(transaction: blankTx, rules: [], remoteConfig: remoteConfig, communityCache: communityCache))

        let unknownTx = makeTx(merchant: "לא זוהה")
        XCTAssertFalse(MerchantConfirmationPolicy.isEligible(transaction: unknownTx, rules: [], remoteConfig: remoteConfig, communityCache: communityCache))
    }

    func testFeatureFlagDisabledSuppressesConfirmation() {
        var disabledRoot = RemoteConfigRoot.bundledDefault
        disabledRoot.features["communityMerchantLearning"] = false
        remoteConfig.updateConfig(disabledRoot)

        let tx = makeTx(merchant: "מכולת דוד")
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertFalse(eligible)
    }

    func testMultipleTransactionsForSameMerchantExposesOnlyOneConfirmationOnNewest() {
        let now = Date()
        let txOldest = makeTx(merchant: "  מכולת דוד  ", date: now.addingTimeInterval(-3600))
        let txMiddle = makeTx(merchant: "מכולת דוד", date: now.addingTimeInterval(-1800))
        let txNewest = makeTx(merchant: "מכולת דוד", date: now)

        let eligibleIDs = MerchantConfirmationPolicy.eligibleTransactionIDs(
            in: [txOldest, txMiddle, txNewest],
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        XCTAssertEqual(eligibleIDs.count, 1)
        XCTAssertTrue(eligibleIDs.contains(txNewest.id), "Only the newest transaction must be eligible")
        XCTAssertFalse(eligibleIDs.contains(txMiddle.id))
        XCTAssertFalse(eligibleIDs.contains(txOldest.id))
    }

    func testFormattingVariantsMappingToSameCanonicalMerchantShowOnlyOneAffordance() {
        let now = Date()
        // Three formatting variants that all canonicalize to "קפה שכונתי"
        let tx1 = makeTx(merchant: "PAY* קפה שכונתי", date: now.addingTimeInterval(-3600))
        let tx2 = makeTx(merchant: "קפה שכונתי*IL", date: now.addingTimeInterval(-1800))
        let tx3 = makeTx(merchant: "  קפה שכונתי  ", date: now)

        let eligibleIDs = MerchantConfirmationPolicy.eligibleTransactionIDs(
            in: [tx1, tx2, tx3],
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )

        // All three map to canonical "קפה שכונתי"
        XCTAssertEqual(eligibleIDs.count, 1)
        XCTAssertTrue(eligibleIDs.contains(tx3.id), "Affordance should appear strictly on the newest canonical match")
    }

    func testEligibilityIsDecoupledFromTransactionIsConfirmed() {
        // Old ingest or user confirmation might have set tx.isConfirmed = true,
        // but if merchant is heuristic, merchant-level trust still offers confirmation check.
        let tx = makeTx(merchant: "חנות חדשה", isConfirmed: true)
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertTrue(eligible, "Merchant confirmation must be based on merchant trust, not tx.isConfirmed review state")
    }

    func testCommunitySuggestionStillShowsConfirmationAffordance() {
        let merchant = "חנות בהצבעה"
        let hash = CommunityMerchantIdentity.merchantHash(for: merchant)
        // Cache has a suggestion (2 votes, not confirmed)
        communityCache.setEntry(
            CommunityCacheEntry(
                merchantHash: hash,
                winnerCategoryRawValue: SpendingCategory.food.rawValue,
                status: .suggestion,
                winningVotes: 2,
                totalVotes: 2,
                agreementRatio: 1.0
            )
        )

        let tx = makeTx(merchant: merchant)
        let eligible = MerchantConfirmationPolicy.isEligible(
            transaction: tx,
            rules: [],
            remoteConfig: remoteConfig,
            communityCache: communityCache
        )
        XCTAssertTrue(eligible, "Community suggestion should still offer confirmation affordance (not false certainty)")
    }
}
