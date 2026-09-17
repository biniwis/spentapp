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

    // Test 10: Fast Setup started -> .setupInProgress
    func test10_fastSetupStarted_returnsSetupInProgress() {
        let now = Date()
        store.markFastSetupStarted(at: now)

        XCTAssertTrue(store.hasFreshFastSetupProgress(now: now))
        XCTAssertEqual(store.state(now: now), .setupInProgress)
    }

    // Test 11: Stale Fast Setup progress (> 24 hours) expires and returns .notConfigured
    func test11_staleFastSetupProgress_expiresAndReturnsNotConfigured() {
        let now = Date()
        let twentyFiveHoursAgo = now.addingTimeInterval(-25 * 60 * 60)

        store.markFastSetupStarted(at: twentyFiveHoursAgo)
        XCTAssertFalse(store.hasFreshFastSetupProgress(now: now))
        XCTAssertEqual(store.state(now: now), .notConfigured)
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupStartedAt))
    }

    // Test 12: markSetupCompleted clears Fast Setup progress
    func test12_markSetupCompleted_clearsFastSetupProgress() {
        let now = Date()
        store.markFastSetupStarted(at: now)

        store.markSetupCompleted(at: now)

        XCTAssertFalse(store.hasFreshFastSetupProgress(now: now))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupStartedAt))
        XCTAssertEqual(store.state(now: now), .configuredAwaitingFirstCapture)
    }

    // Test 13: markAutomaticCaptureDetected clears Fast Setup progress
    func test13_markAutomaticCaptureDetected_clearsFastSetupProgress() {
        let now = Date()
        store.markFastSetupStarted(at: now)

        let detected = now.addingTimeInterval(10)
        store.markAutomaticCaptureDetected(at: detected)

        XCTAssertFalse(store.hasFreshFastSetupProgress(now: now))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupStartedAt))
        XCTAssertEqual(store.state(now: detected), .captureDetected(detected))
    }

    // Test 14: clearFastSetupProgress cleans fastSetupStartedAt (e.g. when user chooses manual setup)
    func test14_clearFastSetupProgress_resetsFastSetup() {
        let now = Date()
        store.markFastSetupStarted(at: now)
        XCTAssertTrue(store.hasFreshFastSetupProgress(now: now))

        store.clearFastSetupProgress()
        XCTAssertFalse(store.hasFreshFastSetupProgress(now: now))
        XCTAssertEqual(store.state(now: now), .notConfigured)
    }

    // Test 15: captureDetected precedence beats Fast Setup in progress
    func test15_captureDetectedPrecedence_beatsFastSetup() {
        let now = Date()
        let detected = now.addingTimeInterval(-60)
        testDefaults.set(detected.timeIntervalSince1970, forKey: AutomaticCaptureStateStore.Key.lastDetectedAt)

        store.markFastSetupStarted(at: now)

        // Capture detected ALWAYS beats in-progress setup
        XCTAssertEqual(store.state(now: now), .captureDetected(detected))
    }

    // Test 16: markFastSetupOpenedAutomations sets fresh automations and .setupInProgress
    func test16_fastSetupOpenedAutomations_returnsSetupInProgress() {
        let now = Date()
        store.markFastSetupOpenedAutomations(at: now)

        XCTAssertTrue(store.hasFreshFastSetupOpenedAutomations(now: now))
        XCTAssertTrue(store.hasFreshFastSetupProgress(now: now))
        XCTAssertEqual(store.state(now: now), .setupInProgress)
    }

    // Test 17: Stale fastSetupOpenedAutomations (> 24 hours) expires and returns .notConfigured
    func test17_staleFastSetupOpenedAutomations_expiresAndReturnsNotConfigured() {
        let now = Date()
        let twentyFiveHoursAgo = now.addingTimeInterval(-25 * 60 * 60)

        store.markFastSetupOpenedAutomations(at: twentyFiveHoursAgo)
        XCTAssertFalse(store.hasFreshFastSetupOpenedAutomations(now: now))
        XCTAssertFalse(store.hasFreshFastSetupProgress(now: now))
        XCTAssertEqual(store.state(now: now), .notConfigured)
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupOpenedAutomationsAt))
    }

    // Test 18: clearFastSetupProgress clears both startedAt and openedAutomationsAt
    func test18_clearFastSetupProgress_clearsBothTimestamps() {
        let now = Date()
        store.markFastSetupStarted(at: now)
        store.markFastSetupOpenedAutomations(at: now)

        XCTAssertTrue(store.hasFreshFastSetupStarted(now: now))
        XCTAssertTrue(store.hasFreshFastSetupOpenedAutomations(now: now))

        store.clearFastSetupProgress()

        XCTAssertFalse(store.hasFreshFastSetupStarted(now: now))
        XCTAssertFalse(store.hasFreshFastSetupOpenedAutomations(now: now))
        XCTAssertFalse(store.hasFreshFastSetupProgress(now: now))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupStartedAt))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupOpenedAutomationsAt))
    }

    // Test 19: markSetupCompleted clears openedAutomationsAt and transitions to .configuredAwaitingFirstCapture
    func test19_markSetupCompleted_clearsOpenedAutomations() {
        let now = Date()
        store.markFastSetupOpenedAutomations(at: now)

        store.markSetupCompleted(at: now)

        XCTAssertFalse(store.hasFreshFastSetupOpenedAutomations(now: now))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupOpenedAutomationsAt))
        XCTAssertEqual(store.state(now: now), .configuredAwaitingFirstCapture)
    }

    // Test 20: markAutomaticCaptureDetected clears openedAutomationsAt and transitions to .captureDetected
    func test20_markAutomaticCaptureDetected_clearsOpenedAutomations() {
        let now = Date()
        store.markFastSetupOpenedAutomations(at: now)

        let detected = now.addingTimeInterval(5)
        store.markAutomaticCaptureDetected(at: detected)

        XCTAssertFalse(store.hasFreshFastSetupOpenedAutomations(now: now))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupOpenedAutomationsAt))
        XCTAssertEqual(store.state(now: detected), .captureDetected(detected))
    }

    // Test 21: Existing completed or active users are not broken
    func test21_existingUsers_remainStable() {
        let pastDate = Date(timeIntervalSince1970: 1700000000)

        // Case A: User completed setup before, waiting for first capture
        testDefaults.set(pastDate.timeIntervalSince1970, forKey: AutomaticCaptureStateStore.Key.setupCompletedAt)
        XCTAssertEqual(store.state(), .configuredAwaitingFirstCapture)

        // Case B: User with active capture detected
        let captureDate = Date(timeIntervalSince1970: 1710000000)
        testDefaults.set(captureDate.timeIntervalSince1970, forKey: AutomaticCaptureStateStore.Key.lastDetectedAt)
        XCTAssertEqual(store.state(), .captureDetected(captureDate))
    }

    // Test 22: Shortcuts URL constants validation
    func test22_shortcutsURLConstants() {
        XCTAssertEqual(IOS27FastCaptureSetupView.automationsURL.absoluteString, "shortcuts://automations")
        XCTAssertEqual(IOS27FastCaptureSetupView.fallbackShortcutsURL.absoluteString, "shortcuts://")
    }

    // Test 23: lastDetectedDate property returns Date when set, nil when unset
    func test23_lastDetectedDate_behavior() {
        XCTAssertNil(store.lastDetectedDate)
        XCTAssertFalse(store.hasLastDetectedCapture)

        let testDate = Date(timeIntervalSince1970: 1720001234)
        store.markAutomaticCaptureDetected(at: testDate)

        XCTAssertNotNil(store.lastDetectedDate)
        XCTAssertTrue(store.hasLastDetectedCapture)
        XCTAssertEqual(store.lastDetectedDate?.timeIntervalSince1970, testDate.timeIntervalSince1970)
    }

    // Test 24: FastSetupEntryMode equality and cases
    func test24_fastSetupEntryMode() {
        let restartMode: FastSetupEntryMode = .restart
        let resumeMode: FastSetupEntryMode = .resume

        XCTAssertEqual(restartMode, .restart)
        XCTAssertEqual(resumeMode, .resume)
        XCTAssertNotEqual(restartMode, resumeMode)
    }

    // Test 25: Date formatting contains no em-dash or en-dash
    func test25_dateFormatting_noDashes() {
        let testDate = Date()

        let formattedHebrew = AutomaticCaptureStateStore.formatLastDetected(date: testDate, isHebrew: true)
        XCTAssertFalse(formattedHebrew.contains("—"), "Must not contain em-dash")
        XCTAssertFalse(formattedHebrew.contains("–"), "Must not contain en-dash")

        let formattedEnglish = AutomaticCaptureStateStore.formatLastDetected(date: testDate, isHebrew: false)
        XCTAssertFalse(formattedEnglish.contains("—"), "Must not contain em-dash")
        XCTAssertFalse(formattedEnglish.contains("–"), "Must not contain en-dash")

        // Older date
        let olderDate = Calendar.current.date(byAdding: .day, value: -10, to: testDate)!
        let formattedOldHe = AutomaticCaptureStateStore.formatLastDetected(date: olderDate, isHebrew: true)
        XCTAssertFalse(formattedOldHe.contains("—"))
        XCTAssertFalse(formattedOldHe.contains("–"))

        let formattedOldEn = AutomaticCaptureStateStore.formatLastDetected(date: olderDate, isHebrew: false)
        XCTAssertFalse(formattedOldEn.contains("—"))
        XCTAssertFalse(formattedOldEn.contains("–"))
    }

    // Test 26: Reconfigure (restart) clears fast setup progress but keeps historical capture and setupCompleted
    func test26_restartKeepsHistory() {
        let pastDate = Date(timeIntervalSince1970: 1700000000)
        store.markAutomaticCaptureDetected(at: pastDate)
        XCTAssertEqual(store.state(), .captureDetected(pastDate))

        // Start fast setup progress
        let newProgressDate = Date()
        store.markFastSetupStarted(at: newProgressDate)
        store.markFastSetupOpenedAutomations(at: newProgressDate)

        // Clear fast setup progress (like restart mode does)
        store.clearFastSetupProgress()

        // Fast setup progress is wiped
        XCTAssertFalse(store.hasFreshFastSetupStarted(now: newProgressDate))
        XCTAssertFalse(store.hasFreshFastSetupOpenedAutomations(now: newProgressDate))
        XCTAssertFalse(store.hasFreshFastSetupProgress(now: newProgressDate))

        // Historical capture is completely preserved
        XCTAssertEqual(store.lastDetectedDate?.timeIntervalSince1970, pastDate.timeIntervalSince1970)
        XCTAssertTrue(store.hasLastDetectedCapture)
        XCTAssertEqual(store.state(), .captureDetected(pastDate))
    }

    // Test 27: FastSetupStep enum equality and states
    func test27_fastSetupStepEnum() {
        XCTAssertEqual(IOS27FastCaptureSetupView.FastSetupStep.initial, .initial)
        XCTAssertEqual(IOS27FastCaptureSetupView.FastSetupStep.shortcutAddedCheckpoint, .shortcutAddedCheckpoint)
        XCTAssertEqual(IOS27FastCaptureSetupView.FastSetupStep.openAutomationsPrompt, .openAutomationsPrompt)
        XCTAssertEqual(IOS27FastCaptureSetupView.FastSetupStep.automationsEnabledCheckpoint, .automationsEnabledCheckpoint)
        XCTAssertEqual(IOS27FastCaptureSetupView.FastSetupStep.captureDetectedSuccess, .captureDetectedSuccess)
        XCTAssertNotEqual(IOS27FastCaptureSetupView.FastSetupStep.initial, .shortcutAddedCheckpoint)
        XCTAssertNotEqual(IOS27FastCaptureSetupView.FastSetupStep.openAutomationsPrompt, .automationsEnabledCheckpoint)
        XCTAssertNotEqual(IOS27FastCaptureSetupView.FastSetupStep.automationsEnabledCheckpoint, .captureDetectedSuccess)
    }

    // Test 28: Detection comparison in session
    func test28_sessionDetectionLogic() {
        let historicalCapture = Date(timeIntervalSince1970: 1700000000)
        let sessionStartedAt = Date(timeIntervalSince1970: 1720000000)
        let newInSessionCapture = Date(timeIntervalSince1970: 1720000010)

        // Historical capture does not exceed sessionStartedAt
        XCTAssertFalse(historicalCapture > sessionStartedAt)

        // Capture detected during session DOES exceed sessionStartedAt
        XCTAssertTrue(newInSessionCapture > sessionStartedAt)
    }

    // Test 29: clearFastSetupOpenedAutomations clears automations timestamp but preserves startedAt
    func test29_clearFastSetupOpenedAutomations_preservesStartedAt() {
        let now = Date()
        store.markFastSetupStarted(at: now)
        store.markFastSetupOpenedAutomations(at: now)

        XCTAssertTrue(store.hasFreshFastSetupStarted(now: now))
        XCTAssertTrue(store.hasFreshFastSetupOpenedAutomations(now: now))

        store.clearFastSetupOpenedAutomations()

        // openedAutomations is cleared
        XCTAssertFalse(store.hasFreshFastSetupOpenedAutomations(now: now))
        XCTAssertNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupOpenedAutomationsAt))

        // startedAt is still intact
        XCTAssertTrue(store.hasFreshFastSetupStarted(now: now))
        XCTAssertNotNil(testDefaults.object(forKey: AutomaticCaptureStateStore.Key.fastSetupStartedAt))
        XCTAssertTrue(store.hasFreshFastSetupProgress(now: now))
    }
}
