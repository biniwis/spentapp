import XCTest
@testable import MoneyCity

final class AutomaticCaptureStateStoreTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var store: AutomaticCaptureStateStore!
    private let suiteName = "AutomaticCaptureStateStoreTests"

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removePersistentDomain(forName: suiteName)
        store = AutomaticCaptureStateStore(userDefaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        store = nil
        super.tearDown()
    }

    // Test 1: No completion, No detection, No fresh progress -> .notConfigured
    func test1_noCompletionNoDetectionNoProgress_returnsNotConfigured() {
        let state = store.state()
        XCTAssertEqual(state, .notConfigured)
    }

    // Test 2: Guide progress updated 10 minutes ago -> .setupInProgress
    func test2_freshProgress10MinutesAgo_returnsSetupInProgress() {
        let now = Date()
        let tenMinutesAgo = now.addingTimeInterval(-10 * 60)

        store.saveIOS27Progress(screen: 2, at: tenMinutesAgo)
        XCTAssertTrue(store.hasFreshIOS27Progress(now: now))
        XCTAssertEqual(store.state(now: now), .setupInProgress)

        // Also verify for legacy
        testDefaults.removePersistentDomain(forName: suiteName)
        store.saveLegacyProgress(step: 3, at: tenMinutesAgo)
        XCTAssertTrue(store.hasFreshLegacyProgress(now: now))
        XCTAssertEqual(store.state(now: now), .setupInProgress)
    }

    // Test 3: Guide progress updated 25 hours ago -> .notConfigured and stale progress cleared
    func test3_staleProgress25HoursAgo_returnsNotConfiguredAndClears() {
        let now = Date()
        let twentyFiveHoursAgo = now.addingTimeInterval(-25 * 60 * 60)

        store.saveIOS27Progress(screen: 3, at: twentyFiveHoursAgo)
        XCTAssertFalse(store.hasFreshIOS27Progress(now: now))
        XCTAssertEqual(store.state(now: now), .notConfigured)
        XCTAssertNil(store.getFreshIOS27Progress(now: now))

        // Same for legacy
        store.saveLegacyProgress(step: 4, at: twentyFiveHoursAgo)
        XCTAssertFalse(store.hasFreshLegacyProgress(now: now))
        XCTAssertEqual(store.state(now: now), .notConfigured)
        XCTAssertNil(store.getFreshLegacyProgress(now: now))
    }

    // Test 4: Setup completed, No detection -> .configuredAwaitingFirstCapture
    func test4_setupCompletedNoDetection_returnsConfiguredAwaitingFirstCapture() {
        let completedDate = Date()
        store.markSetupCompleted(at: completedDate)
        XCTAssertEqual(store.state(), .configuredAwaitingFirstCapture)
    }

    // Test 5: lastDetectedAt exists -> .captureDetected(date)
    func test5_lastDetectedAtExists_returnsCaptureDetected() {
        let detectedDate = Date(timeIntervalSince1970: 1720000000)
        store.markAutomaticCaptureDetected(at: detectedDate)
        XCTAssertEqual(store.state(), .captureDetected(detectedDate))
    }

    // Test 6: markAutomaticCaptureDetected must also make setup considered completed and clear guide progress
    func test6_markAutomaticCaptureDetected_completesSetupAndClearsGuideProgress() {
        let now = Date()
        store.saveIOS27Progress(screen: 2, at: now)
        store.saveLegacyProgress(step: 3, at: now)

        let detectedDate = now.addingTimeInterval(5)
        store.markAutomaticCaptureDetected(at: detectedDate)

        // Detection exists
        XCTAssertEqual(store.state(), .captureDetected(detectedDate))

        // SetupCompletedAt is also set
        let completed = testDefaults.object(forKey: AutomaticCaptureStateStore.Key.setupCompletedAt) as? Double
        XCTAssertNotNil(completed)

        // Guide progress is cleared
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideScreen))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideLegacyStep))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideUpdatedAt))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideLegacyUpdatedAt))
    }

    // Test 7: isAutomaticCaptureIntent validation
    func test7_isAutomaticCaptureIntent() {
        XCTAssertTrue(AutomaticCaptureStateStore.isAutomaticCaptureIntent("RecordTransactionIntent"))
        XCTAssertTrue(AutomaticCaptureStateStore.isAutomaticCaptureIntent("LogWalletPaymentIntent"))

        XCTAssertFalse(AutomaticCaptureStateStore.isAutomaticCaptureIntent("NotificationAmountCompletion"))
        XCTAssertFalse(AutomaticCaptureStateStore.isAutomaticCaptureIntent("QuickExpensePromptIntent"))
        XCTAssertFalse(AutomaticCaptureStateStore.isAutomaticCaptureIntent("ScanReceiptIntent"))
        XCTAssertFalse(AutomaticCaptureStateStore.isAutomaticCaptureIntent(""))
    }

    // Test 8: resetGuideProgress() clears guide screen/step/timestamps but preserves setupCompletedAt and lastDetectedAt
    func test8_resetGuideProgress_clearsGuideOnly() {
        let now = Date()
        let detectedDate = now.addingTimeInterval(-100)
        let completedDate = now.addingTimeInterval(-200)

        store.markSetupCompleted(at: completedDate)
        testDefaults.set(detectedDate.timeIntervalSince1970, forKey: AutomaticCaptureStateStore.Key.lastDetectedAt)
        store.saveIOS27Progress(screen: 4, at: now)
        store.saveLegacyProgress(step: 5, at: now)

        store.resetGuideProgress()

        // Guide progress gone
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideScreen))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideLegacyStep))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideUpdatedAt))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideLegacyUpdatedAt))

        // History preserved
        XCTAssertEqual(testDefaults.double(forKey: AutomaticCaptureStateStore.Key.setupCompletedAt), completedDate.timeIntervalSince1970)
        XCTAssertEqual(testDefaults.double(forKey: AutomaticCaptureStateStore.Key.lastDetectedAt), detectedDate.timeIntervalSince1970)
        XCTAssertEqual(store.state(), .captureDetected(detectedDate))
    }

    // Test 9: markSetupCompleted() clears both Legacy and iOS 27 progress
    func test9_markSetupCompleted_clearsBothGuides() {
        let now = Date()
        store.saveIOS27Progress(screen: 3, at: now)
        store.saveLegacyProgress(step: 7, at: now)

        store.markSetupCompleted(at: now)

        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideScreen))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideLegacyStep))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideUpdatedAt))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.guideLegacyUpdatedAt))
        XCTAssertEqual(store.state(), .configuredAwaitingFirstCapture)
    }
}
