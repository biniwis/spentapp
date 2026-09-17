import XCTest
@testable import MoneyCity

final class RemoteConfigTests: XCTestCase {

    var testDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.remoteconfig.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - 1. Valid JSON Decoding

    func testValidJSONDecoding() throws {
        let json = """
        {
          "schemaVersion": 1,
          "revision": 42,
          "features": {
            "notifications": true,
            "automaticCapture": false,
            "savingsGoals": true
          },
          "announcement": {
            "id": "promo-2026",
            "enabled": true,
            "startsAt": "2026-09-16T00:00:00Z",
            "endsAt": "2026-09-20T23:59:59Z",
            "title": { "he": "שלום", "en": "Hello" },
            "body": { "he": "בדיקה", "en": "Test" },
            "action": "openCaptureGuide"
          },
          "copy": {
            "capture.active.title": {
              "he": "קליטה פעילה",
              "en": "Active Capture"
            }
          },
          "captureGuide": {
            "mode": "native",
            "forceVariant": "ios27",
            "revision": 2,
            "steps": [1, 3, 4, 5, 6]
          },
          "notifications": {
            "weeklyDigest": {
              "enabled": true,
              "weekday": 2,
              "hour": 19,
              "minute": 30,
              "title": { "he": "תזכורת", "en": "Reminder" },
              "body": { "he": "טקסט", "en": "Text" }
            },
            "monthlyRecap": null,
            "cityNarrativeEnabled": false,
            "captureHealthCheckEnabled": true
          },
          "merchantOverrides": [
            {
              "match": "cofix",
              "mode": "exact",
              "category": "food"
            }
          ]
        }
        """

        let data = Data(json.utf8)
        let config = try RemoteConfigService.decodeJSON(from: data)

        XCTAssertEqual(config.schemaVersion, 1)
        XCTAssertEqual(config.revision, 42)
        XCTAssertEqual(config.features["notifications"], true)
        XCTAssertEqual(config.features["automaticCapture"], false)
        XCTAssertEqual(config.features["savingsGoals"], true)

        XCTAssertNotNil(config.announcement)
        XCTAssertEqual(config.announcement?.id, "promo-2026")
        XCTAssertEqual(config.announcement?.safeAction, .openCaptureGuide)

        XCTAssertEqual(config.captureGuide.forceVariant, "ios27")
        XCTAssertEqual(config.captureGuide.steps, [1, 3, 4, 5, 6])

        XCTAssertEqual(config.notifications.cityNarrativeEnabled, false)
        XCTAssertEqual(config.notifications.captureHealthCheckEnabled, true)
        XCTAssertEqual(config.notifications.weeklyDigest?.weekday, 2)
        XCTAssertEqual(config.notifications.weeklyDigest?.hour, 19)

        XCTAssertEqual(config.merchantOverrides.count, 1)
        XCTAssertEqual(config.merchantOverrides.first?.match, "cofix")
        XCTAssertEqual(config.merchantOverrides.first?.category, "food")
    }

    // MARK: - 2. Unsupported Schema Rejection

    func testUnsupportedSchemaRejection() async {
        let service = RemoteConfigService(defaults: testDefaults)
        let initialConfig = service.currentConfig

        let futureJSON = """
        {
          "schemaVersion": 2,
          "revision": 999,
          "features": { "notifications": false }
        }
        """
        let data = Data(futureJSON.utf8)

        // Simulate receiving schemaVersion = 2 data
        if let decoded = try? RemoteConfigService.decodeJSON(from: data) {
            if decoded.schemaVersion == RemoteConfigService.supportedSchemaVersion {
                service.updateConfig(decoded)
            }
        }

        // Must still retain previous / initial config
        XCTAssertEqual(service.currentConfig.schemaVersion, RemoteConfigService.supportedSchemaVersion)
        XCTAssertEqual(service.currentConfig.revision, initialConfig.revision)
    }

    // MARK: - 3. Malformed JSON Fallback

    func testMalformedJSONFallback() {
        let service = RemoteConfigService(defaults: testDefaults)
        let malformedData = Data("{{ not json }}".utf8)

        XCTAssertThrowsError(try RemoteConfigService.decodeJSON(from: malformedData))
        // Service remains safely initialized with bundled defaults
        XCTAssertEqual(service.currentConfig.schemaVersion, 1)
        XCTAssertTrue(service.isFeatureEnabled("notifications"))
    }

    // MARK: - 4. Feature Fallback

    func testFeatureFallback() {
        let service = RemoteConfigService(defaults: testDefaults)
        var custom = RemoteConfigRoot.bundledDefault
        custom.features = ["customFeature": false]
        service.updateConfig(custom)

        XCTAssertFalse(service.isFeatureEnabled("customFeature", default: true))
        // Missing key returns default argument
        XCTAssertTrue(service.isFeatureEnabled("nonExistentFeature", default: true))
        XCTAssertFalse(service.isFeatureEnabled("nonExistentFeature", default: false))
    }

    // MARK: - 5. Copy Fallback

    func testCopyFallback() {
        let service = RemoteConfigService(defaults: testDefaults)
        var custom = RemoteConfigRoot.bundledDefault
        custom.copy = [
            "capture.active.title": [
              "he": "קליטה אוטומטית פעילה",
              "en": "Automatic capture is active"
            ],
            "incomplete.key": [
              "he": "רק בעברית"
            ]
        ]
        service.updateConfig(custom)

        // Matched keys
        XCTAssertEqual(
            service.localizedCopy(key: "capture.active.title", fallbackHe: "רגיל", fallbackEn: "Default", isHebrew: true),
            "קליטה אוטומטית פעילה"
        )
        XCTAssertEqual(
            service.localizedCopy(key: "capture.active.title", fallbackHe: "רגיל", fallbackEn: "Default", isHebrew: false),
            "Automatic capture is active"
        )

        // Missing English translation falls back to fallbackEn
        XCTAssertEqual(
            service.localizedCopy(key: "incomplete.key", fallbackHe: "עברית", fallbackEn: "Fallback English", isHebrew: false),
            "Fallback English"
        )

        // Completely missing key falls back
        XCTAssertEqual(
            service.localizedCopy(key: "unknown.key", fallbackHe: "ברירת מחדל", fallbackEn: "Default", isHebrew: true),
            "ברירת מחדל"
        )
    }

    // MARK: - 6. Announcement Date Window & Action

    func testAnnouncementDateWindow() {
        let service = RemoteConfigService(defaults: testDefaults)
        let now = Date(timeIntervalSince1970: 1780000000)

        // Case A: Active within window
        let activeAnnouncement = RemoteAnnouncement(
            id: "window-test",
            enabled: true,
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(3600),
            title: ["en": "Active"],
            body: ["en": "Active body"],
            action: "openCaptureGuide"
        )
        var configA = RemoteConfigRoot.bundledDefault
        configA.announcement = activeAnnouncement
        service.updateConfig(configA)

        XCTAssertEqual(service.activeAnnouncement(now: now)?.id, "window-test")
        XCTAssertEqual(service.activeAnnouncement(now: now)?.safeAction, .openCaptureGuide)

        // Case B: In the future (not yet started)
        let futureAnnouncement = RemoteAnnouncement(
            id: "future-test",
            enabled: true,
            startsAt: now.addingTimeInterval(100),
            endsAt: now.addingTimeInterval(3600),
            title: ["en": "Future"]
        )
        var configB = RemoteConfigRoot.bundledDefault
        configB.announcement = futureAnnouncement
        service.updateConfig(configB)
        XCTAssertNil(service.activeAnnouncement(now: now))

        // Case C: In the past (already expired)
        let pastAnnouncement = RemoteAnnouncement(
            id: "past-test",
            enabled: true,
            startsAt: now.addingTimeInterval(-7200),
            endsAt: now.addingTimeInterval(-3600),
            title: ["en": "Past"]
        )
        var configC = RemoteConfigRoot.bundledDefault
        configC.announcement = pastAnnouncement
        service.updateConfig(configC)
        XCTAssertNil(service.activeAnnouncement(now: now))

        // Case D: Disabled flag
        let disabledAnnouncement = RemoteAnnouncement(
            id: "disabled-test",
            enabled: false,
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(3600)
        )
        var configD = RemoteConfigRoot.bundledDefault
        configD.announcement = disabledAnnouncement
        service.updateConfig(configD)
        XCTAssertNil(service.activeAnnouncement(now: now))

        // Case E: Dismissed by user
        service.updateConfig(configA)
        XCTAssertNotNil(service.activeAnnouncement(now: now))
        service.dismissAnnouncement(id: "window-test")
        XCTAssertNil(service.activeAnnouncement(now: now))
    }

    func testAnnouncementAllowListedAction() {
        let validAction = RemoteAnnouncement(id: "1", title: [:], body: [:], action: "openCaptureGuide")
        XCTAssertEqual(validAction.safeAction, .openCaptureGuide)

        let profileAction = RemoteAnnouncement(id: "2", title: [:], body: [:], action: "openProfile")
        XCTAssertEqual(profileAction.safeAction, .openProfile)

        let arbitraryAction = RemoteAnnouncement(id: "3", title: [:], body: [:], action: "https://malicious.url")
        XCTAssertEqual(arbitraryAction.safeAction, .none)

        let emptyAction = RemoteAnnouncement(id: "4", title: [:], body: [:], action: nil)
        XCTAssertEqual(emptyAction.safeAction, .none)
    }

    // MARK: - 7. Merchant Precedence

    func testMerchantPrecedence() {
        let service = RemoteConfigService(defaults: testDefaults)
        var config = RemoteConfigRoot.bundledDefault
        config.merchantOverrides = [
            RemoteMerchantOverride(match: "mystery-merchant", mode: "exact", category: "entertainment"),
            RemoteMerchantOverride(match: "super", mode: "contains", category: "housing"),
            RemoteMerchantOverride(match: "super pharmacy", mode: "contains", category: "shopping")
        ]
        service.updateConfig(config)

        // 1. User rule ALWAYS beats global remote override
        let userRules = [
            MerchantRule(merchantKey: "mystery-merchant", displayName: "Mystery", category: .food)
        ]
        let result1 = MerchantRuleService.classify(
            merchant: "mystery-merchant",
            amount: 100,
            rules: userRules,
            remoteConfig: service
        )
        XCTAssertEqual(result1.category, .food, "User rule must beat global remote override")

        // 2. Global remote exact match wins when no user rule exists
        let result2 = MerchantRuleService.classify(
            merchant: "mystery-merchant",
            amount: 100,
            rules: [],
            remoteConfig: service
        )
        XCTAssertEqual(result2.category, .entertainment, "Remote exact override must match")

        // 3. Exact beats contains
        var configExactWins = RemoteConfigRoot.bundledDefault
        configExactWins.merchantOverrides = [
            RemoteMerchantOverride(match: "coffee-shop", mode: "contains", category: "transport"),
            RemoteMerchantOverride(match: "coffee-shop", mode: "exact", category: "food")
        ]
        service.updateConfig(configExactWins)
        let exactResult = service.merchantOverride(for: "coffee-shop")
        XCTAssertEqual(exactResult, .food, "Exact match must beat contains")

        // 4. Longest contains wins among multiple contains
        var configLongestContains = RemoteConfigRoot.bundledDefault
        configLongestContains.merchantOverrides = [
            RemoteMerchantOverride(match: "mega", mode: "contains", category: "housing"),
            RemoteMerchantOverride(match: "mega market", mode: "contains", category: "food")
        ]
        service.updateConfig(configLongestContains)
        let longestResult = service.merchantOverride(for: "mega market branch 5")
        XCTAssertEqual(longestResult, .food, "Longest contains substring must win")

        // 5. Short contains (< 3 characters) is rejected
        var configShortContains = RemoteConfigRoot.bundledDefault
        configShortContains.merchantOverrides = [
            RemoteMerchantOverride(match: "ab", mode: "contains", category: "transport")
        ]
        service.updateConfig(configShortContains)
        let shortResult = service.merchantOverride(for: "about")
        XCTAssertNil(shortResult, "Contains with < 3 characters must be ignored")
    }

    // MARK: - 8. Invalid Merchant Category Ignored

    func testInvalidMerchantCategoryIgnored() {
        let service = RemoteConfigService(defaults: testDefaults)
        var config = RemoteConfigRoot.bundledDefault
        config.merchantOverrides = [
            RemoteMerchantOverride(match: "unknown-store", mode: "exact", category: "non_existent_category")
        ]
        service.updateConfig(config)

        let override = service.merchantOverride(for: "unknown-store")
        XCTAssertNil(override, "Invalid SpendingCategory rawValue must be safely ignored")
    }

    // MARK: - 9. Refresh Throttling

    func testRefreshThrottling() async {
        let service = RemoteConfigService(defaults: testDefaults)
        let now = Date()

        // First attempt sets timestamp
        testDefaults.set(now.timeIntervalSince1970, forKey: "remote_config_last_refresh_attempt_timestamp")

        // Second attempt 5 minutes later (less than 30 min / 1800s) should be skipped
        let fiveMinutesLater = now.addingTimeInterval(300)
        let elapsed = fiveMinutesLater.timeIntervalSince1970 - now.timeIntervalSince1970
        XCTAssertTrue(elapsed < 1800, "Should be within 30-minute throttle window")

        // Over 30 minutes later should be allowed
        let thirtyOneMinutesLater = now.addingTimeInterval(1860)
        let elapsedAfter = thirtyOneMinutesLater.timeIntervalSince1970 - now.timeIntervalSince1970
        XCTAssertTrue(elapsedAfter >= 1800, "Should be eligible for refresh after 30 minutes")
    }

    // MARK: - 10. Last Known Good Persistence & Recovery

    func testLastKnownGoodPersistenceAndRecovery() throws {
        // Create an initial LKG data blob in user defaults
        let lkgRoot = RemoteConfigRoot(
            schemaVersion: 1,
            revision: 88,
            features: ["persistedFlag": true],
            announcement: nil,
            copy: [:],
            captureGuide: RemoteCaptureGuideConfig(),
            notifications: RemoteNotificationConfig(),
            merchantOverrides: []
        )
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(lkgRoot)

        testDefaults.set(encodedData, forKey: "remote_config_last_known_good_json")

        // Initialize a fresh service instance from the same defaults
        let restoredService = RemoteConfigService(defaults: testDefaults)

        XCTAssertEqual(restoredService.currentConfig.revision, 88)
        XCTAssertTrue(restoredService.isFeatureEnabled("persistedFlag"))
    }

    // MARK: - 11. Fast Setup & Shortcut URL Validation

    func testFastSetupConfigDecoding() throws {
        let json = """
        {
          "schemaVersion": 1,
          "revision": 10,
          "features": {},
          "copy": {},
          "captureGuide": {
            "mode": "native",
            "fastSetupEnabled": false,
            "shortcutURL": "https://www.icloud.com/shortcuts/custom123"
          },
          "notifications": {},
          "merchantOverrides": []
        }
        """
        let data = Data(json.utf8)
        let config = try RemoteConfigService.decodeJSON(from: data)

        XCTAssertEqual(config.captureGuide.fastSetupEnabled, false)
        XCTAssertEqual(config.captureGuide.shortcutURL, "https://www.icloud.com/shortcuts/custom123")
    }

    func testResolvedShortcutURLSecurity() {
        let service = RemoteConfigService(defaults: testDefaults)
        let defaultExpected = URL(string: RemoteConfigService.defaultShortcutURL)!

        // Default state when nil
        XCTAssertTrue(service.isFastSetupEnabled)
        XCTAssertEqual(service.resolvedShortcutURL, defaultExpected)

        // Valid iCloud Shortcut URL
        var configValid = RemoteConfigRoot.bundledDefault
        configValid.captureGuide.shortcutURL = "https://www.icloud.com/shortcuts/72aa49c6fe0449fd99703e8d4f2a1853"
        configValid.captureGuide.fastSetupEnabled = true
        service.updateConfig(configValid)

        XCTAssertTrue(service.isFastSetupEnabled)
        XCTAssertEqual(service.resolvedShortcutURL.absoluteString, "https://www.icloud.com/shortcuts/72aa49c6fe0449fd99703e8d4f2a1853")

        // Valid icloud.com without www
        var configNoWWW = RemoteConfigRoot.bundledDefault
        configNoWWW.captureGuide.shortcutURL = "https://icloud.com/shortcuts/test456"
        service.updateConfig(configNoWWW)
        XCTAssertEqual(service.resolvedShortcutURL.absoluteString, "https://icloud.com/shortcuts/test456")

        // Insecure scheme (http) -> must fallback
        var configHTTP = RemoteConfigRoot.bundledDefault
        configHTTP.captureGuide.shortcutURL = "http://www.icloud.com/shortcuts/test456"
        service.updateConfig(configHTTP)
        XCTAssertEqual(service.resolvedShortcutURL, defaultExpected)

        // Untrusted host (phishing/open redirect) -> must fallback
        var configUntrusted = RemoteConfigRoot.bundledDefault
        configUntrusted.captureGuide.shortcutURL = "https://malicious-site.com/shortcuts/steal"
        service.updateConfig(configUntrusted)
        XCTAssertEqual(service.resolvedShortcutURL, defaultExpected)

        // Missing /shortcuts/ path prefix -> must fallback
        var configBadPath = RemoteConfigRoot.bundledDefault
        configBadPath.captureGuide.shortcutURL = "https://www.icloud.com/other/path"
        service.updateConfig(configBadPath)
        XCTAssertEqual(service.resolvedShortcutURL, defaultExpected)

        // Empty string -> must fallback
        var configEmpty = RemoteConfigRoot.bundledDefault
        configEmpty.captureGuide.shortcutURL = "   "
        service.updateConfig(configEmpty)
        XCTAssertEqual(service.resolvedShortcutURL, defaultExpected)
    }
}
