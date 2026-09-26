import XCTest
@testable import MoneyCity

/// What makes shared data converge on a device, and what must never be paid for it.
///
/// CloudKit push is the fast path and this suite deliberately does not pretend to test it.
/// APNs delivery and CKSyncEngine's remote fetch are real-device behaviour: there is no
/// way to make a server push arrive from inside a unit test, and a test that pretended to
/// would be worse than no test, because it would look like coverage. What *can* be pinned
/// down deterministically is everything this app is responsible for around that push —
/// the registration path not asking the user for anything, the foreground net that catches
/// whatever push missed, and the concurrency that used to turn an ordinary overlap into a
/// "your shared data is unavailable" alert.
@MainActor
final class SharedLiveSyncTests: XCTestCase {

    // MARK: - Registration must not ask the user for anything

    /// CloudKit's silent push is infrastructure. Asking for notification permission would
    /// put a system prompt in front of a user who never asked to hear from us, and refusing
    /// it would cost nothing that the foreground net does not already cover.
    func testTheRegistrationPathRequestsNoUserNotificationAuthorization() throws {
        let source = try Self.source(of: "MoneyCityApp.swift")
        // The one call that can raise a permission prompt, and it must not appear on the
        // launch or registration path.
        for forbidden in ["requestAuthorization", "UNAuthorizationOptions"] {
            XCTAssertFalse(source.contains(forbidden),
                           "launch path must not use \(forbidden): a CloudKit push must not prompt the user")
        }
    }

    func testRemoteNotificationRegistrationHappensOnLaunch() throws {
        let source = try Self.source(of: "MoneyCityApp.swift")
        XCTAssertTrue(source.contains("registerForRemoteNotifications()"),
                      "the app must register for remote notifications on launch")
        // Inside the launch handler rather than buried in shared-mode code, so it happens
        // for every user regardless of whether they ever open a shared space.
        let launch = try XCTUnwrap(source.range(of: "didFinishLaunchingWithOptions"))
        let registration = try XCTUnwrap(source.range(of: "registerForRemoteNotifications()"))
        XCTAssertTrue(registration.lowerBound > launch.lowerBound)
    }

    func testRegistrationFailureIsLoggedAndNotFatal() throws {
        let source = try Self.source(of: "MoneyCityApp.swift")
        XCTAssertTrue(source.contains("didFailToRegisterForRemoteNotificationsWithError"),
                      "a registration failure needs a diagnostic path")
        // Personal money is local, and the foreground net still converges shared state, so
        // there is nothing to tell the user and nothing broken on their device.
        let handler = try XCTUnwrap(source.range(of: "didFailToRegisterForRemoteNotificationsWithError"))
        let tail = String(source[handler.lowerBound...])
        XCTAssertFalse(tail.contains("fatalError"))
        XCTAssertFalse(tail.contains("preconditionFailure"))
    }

    /// The capability has to be declared or registration silently does nothing.
    func testTheAppDeclaresThePushCapabilityAndBackgroundDelivery() throws {
        let entitlements = try Self.text(at: Self.projectRoot().appendingPathComponent("MoneyCity/MoneyCity.entitlements"))
        XCTAssertTrue(entitlements.contains("aps-environment"),
                      "without aps-environment the device never receives CloudKit pushes")

        let infoPlist = try Self.text(at: Self.projectRoot().appendingPathComponent("MoneyCity/Info.plist"))
        XCTAssertTrue(infoPlist.contains("remote-notification"),
                      "without the remote-notification background mode iOS will not wake the app for a push")

        let debugEntitlements = try Self.text(at: Self.projectRoot().appendingPathComponent("MoneyCity/SharedLab.entitlements"))
        XCTAssertTrue(debugEntitlements.contains("aps-environment"),
                      "Debug entitlements must also declare aps-environment for physical test devices")

        let debugInfoPlist = try Self.text(at: Self.projectRoot().appendingPathComponent("MoneyCity/SharedLab-Info.plist"))
        XCTAssertTrue(debugInfoPlist.contains("remote-notification"),
                      "Debug Info.plist must also declare remote-notification for physical test devices")
    }

    /// Shared sync belongs to the app. The widget renders a read-only snapshot and has no
    /// CloudKit container of its own, so it must not be given push or iCloud entitlements.
    func testTheWidgetIsNotGivenCloudKitOrPushEntitlements() throws {
        let widget = try Self.text(at: Self.projectRoot().appendingPathComponent("spent fast/spent fastExtension.entitlements"))
        XCTAssertFalse(widget.contains("aps-environment"))
        XCTAssertFalse(widget.contains("icloud-services"))
    }

    // MARK: - The foreground net

    func testAPersonalOnlyUserNeverTriggersASharedSync() {
        // No shared account means no round trip, no wait and no alert. This is the single
        // most important property here: a user who has never shared anything must not be
        // made to pay for CloudKit on every return to the app.
        XCTAssertFalse(SharedForegroundSync.shouldRefresh(hasSharedState: false, lastRefresh: nil, now: Date()))
    }

    func testASharedUserIsRefreshedWhenReturningToTheApp() {
        // The whole point: a push that was delayed, coalesced or never delivered still
        // converges the moment the app is opened.
        XCTAssertTrue(SharedForegroundSync.shouldRefresh(hasSharedState: true, lastRefresh: nil, now: Date()))
    }

    func testRepeatedActivationsDoNotBecomeASyncStorm() {
        // Flicking between apps must not re-fetch each time. This is the failure mode that
        // does not show up in a test but shows up as a battery complaint.
        let start = Date()
        XCTAssertTrue(SharedForegroundSync.shouldRefresh(hasSharedState: true, lastRefresh: nil, now: start))
        XCTAssertFalse(SharedForegroundSync.shouldRefresh(hasSharedState: true, lastRefresh: start,
                                                          now: start.addingTimeInterval(1)))
        XCTAssertFalse(SharedForegroundSync.shouldRefresh(hasSharedState: true, lastRefresh: start,
                                                          now: start.addingTimeInterval(19)))
    }

    func testAFreshReturnAfterARealPauseIsAllowedThrough() {
        // Debouncing must not become "never refresh again" — coming back later has to work.
        let start = Date()
        XCTAssertTrue(SharedForegroundSync.shouldRefresh(hasSharedState: true, lastRefresh: start,
                                                         now: start.addingTimeInterval(SharedForegroundSync.minimumInterval)))
        XCTAssertTrue(SharedForegroundSync.shouldRefresh(hasSharedState: true, lastRefresh: start,
                                                         now: start.addingTimeInterval(3_600)))
    }

    func testTheDebounceIsIndependentOfWhetherThereIsSharedState() {
        // A personal-only user stays unrefreshed however often they switch apps, including
        // long after a hypothetical first attempt.
        let start = Date()
        for offset in [0.0, 1, 60, 86_400] {
            XCTAssertFalse(SharedForegroundSync.shouldRefresh(hasSharedState: false, lastRefresh: start,
                                                              now: start.addingTimeInterval(offset)))
        }
    }

    // MARK: - Overlapping discovery

    /// A second discovery while one is already running used to throw
    /// `storageUnavailable` — "the shared data is unavailable" — shown to a user at the
    /// exact moment their data was being loaded. It has to coalesce onto the attempt in
    /// flight instead.
    func testOverlappingDiscoveryNeverReportsStorageUnavailable() async throws {
        let store = SharedWorkspaceStore()

        // Ten callers at once, the way a launch, an opened shared screen and a foreground
        // transition can all land together. Every one of them must get a real answer about
        // iCloud, and none may be handed "the shared data is unavailable" merely because
        // another caller was already in flight.
        let outcomes = await withTaskGroup(of: SharedLedgerError?.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    do {
                        try await store.connect()
                        return nil            // connected
                    } catch let error as SharedLedgerError {
                        return error
                    } catch {
                        return .storageUnavailable
                    }
                }
            }
            var collected: [SharedLedgerError?] = []
            for await value in group { collected.append(value) }
            return collected
        }

        XCTAssertEqual(outcomes.count, 10)
        for outcome in outcomes {
            XCTAssertNotEqual(outcome, .storageUnavailable,
                              "a concurrent caller was told the shared data is unavailable instead of waiting")
        }
        // Every caller must also reach the same conclusion rather than a mix of answers,
        // which is what coalescing actually means.
        let distinct = Set(outcomes.compactMap { $0 })
        XCTAssertLessThanOrEqual(distinct.count, 1, "concurrent callers disagreed: \(outcomes)")
    }

    func testDiscoveryAfterADisconnectFailureStillLeavesPersonalAlone() async throws {
        // No iCloud account, no prior state: discovery must complete quietly and change
        // nothing, because a personal user has no shared data to be missing.
        let store = SharedWorkspaceStore()
        let before = store.errorMessage
        await store.discover()
        // Silent on an ordinary state: no alert raised over a personal user's money.
        XCTAssertEqual(store.errorMessage, before)
        XCTAssertTrue(store.spaces.isEmpty)
    }

    func testTheForegroundNetIsInertUntilSharedStateExists() async {
        let store = SharedWorkspaceStore()
        try? await store.startDemo()
        // A demo store is a local stand-in with no CloudKit behind it, so the foreground
        // path must decline to do anything with it rather than reach for the network.
        await store.refreshOnForeground()
        XCTAssertTrue(store.errorMessage == nil)
    }

    func testConcurrentDiscoverCallsCoalesceSafelyWithoutError() async {
        let store = SharedWorkspaceStore()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    await store.discover()
                }
            }
        }
        XCTAssertNil(store.errorMessage, "concurrent discover calls must not surface errors")
    }

    func testConcurrentRefreshCallsCoalesceSafely() async throws {
        let store = SharedWorkspaceStore()
        let outcomes = await withTaskGroup(of: SharedLedgerError?.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    do {
                        try await store.refresh()
                        return nil
                    } catch let error as SharedLedgerError {
                        return error
                    } catch {
                        return .storageUnavailable
                    }
                }
            }
            var collected: [SharedLedgerError?] = []
            for await value in group { collected.append(value) }
            return collected
        }
        for outcome in outcomes {
            XCTAssertNotEqual(outcome, .storageUnavailable, "coalesced refresh must not return storageUnavailable")
        }
        let distinct = Set(outcomes.compactMap { $0 })
        XCTAssertLessThanOrEqual(distinct.count, 1, "concurrent refreshes reached differing results: \(outcomes)")
    }

    func testPersonalOnlyLifecycleIsIndependentOfCloudKit() async {
        let store = SharedWorkspaceStore()
        XCTAssertFalse(store.hasSharedState, "fresh store with no account or spaces has no shared state")
        // Calling foreground refresh on personal user must not touch network or change error state
        await store.refreshOnForeground()
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.spaces.isEmpty)
    }

    // MARK: - Helpers

    private static func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)            // …/MoneyCityTests/SharedLiveSyncTests.swift
            .deletingLastPathComponent()           // …/MoneyCityTests
            .deletingLastPathComponent()           // repo root
    }

    private static func text(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private static func source(of file: String) throws -> String {
        try strippingComments(text(at: projectRoot().appendingPathComponent("MoneyCity/\(file)")))
    }

    /// Comments are removed before scanning, so that a comment *explaining* that the app
    /// never asks for notification permission cannot be mistaken for it doing so.
    private static func strippingComments(_ source: String) -> String {
        var out = ""
        var inBlockComment = false
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            var text = String(line)
            if inBlockComment {
                if let end = text.range(of: "*/") {
                    text = String(text[end.upperBound...])
                    inBlockComment = false
                } else {
                    continue
                }
            }
            while let start = text.range(of: "/*") {
                guard let end = text.range(of: "*/", range: start.upperBound..<text.endIndex) else {
                    text = String(text[..<start.lowerBound])
                    inBlockComment = true
                    break
                }
                text = String(text[..<start.lowerBound]) + " " + String(text[end.upperBound...])
            }
            // `//` that is not part of `://`, so a URL in code is not mistaken for a comment.
            var scan = text.startIndex
            while let found = text.range(of: "//", range: scan..<text.endIndex) {
                if found.lowerBound > text.startIndex {
                    let previous = text[text.index(before: found.lowerBound)]
                    if previous == ":" { scan = found.upperBound; continue }
                }
                text = String(text[..<found.lowerBound])
                break
            }
            out += text + "\n"
        }
        return out
    }
}
