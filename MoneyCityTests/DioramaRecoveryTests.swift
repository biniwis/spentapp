import XCTest
@testable import MoneyCity

/// Decision matrix for the diorama renderer self-healing state machine.
///
/// `ThreeDioramaView.Coordinator.shouldRecover` is pure and covers the guards that decide
/// whether a recovery reload may start right now. It is intentionally tested without a real
/// WKWebView — the "web view available" and "no infinite loop" guarantees fall out of the
/// `isRecoveringRenderer` / `isDisposed` flags, which `recoverRendererIfNeeded` reads first.
final class DioramaRecoveryDecisionTests: XCTestCase {

    private typealias Decision = ThreeDioramaView.Coordinator

    // MARK: - Recovery allowed

    func testTerminatedWhileActiveAndVisibleAllowsRecovery() {
        XCTAssertTrue(Decision.shouldRecover(
            isDisposed: false,
            needsRendererRecovery: true,
            isRecoveringRenderer: false,
            appIsActive: true,
            isPaused: false
        ))
    }

    // MARK: - Recovery deferred

    func testTerminatedWhileAppIsInBackgroundDefersRecovery() {
        XCTAssertFalse(Decision.shouldRecover(
            isDisposed: false,
            needsRendererRecovery: true,
            isRecoveringRenderer: false,
            appIsActive: false,
            isPaused: false
        ), "A backgrounded app must not spin up WebGL for recovery.")
    }

    func testTerminatedWhileOnAnotherTabDefersRecovery() {
        XCTAssertFalse(Decision.shouldRecover(
            isDisposed: false,
            needsRendererRecovery: true,
            isRecoveringRenderer: false,
            appIsActive: true,
            isPaused: true
        ), "Recovery must wait for the user to return to the city.")
    }

    func testReturningToCityAfterDeferredRecoveryAllowsIt() {
        XCTAssertTrue(Decision.shouldRecover(
            isDisposed: false,
            needsRendererRecovery: true,
            isRecoveringRenderer: false,
            appIsActive: true,
            isPaused: false
        ), "The pending flag clears the moment the city is visible again.")
    }

    // MARK: - No reload loops / no redundant reloads

    func testNormalForegroundWithoutTerminationNeverReloads() {
        XCTAssertFalse(Decision.shouldRecover(
            isDisposed: false,
            needsRendererRecovery: false,
            isRecoveringRenderer: false,
            appIsActive: true,
            isPaused: false
        ), "Every regular foreground must not produce a reload.")
    }

    func testAlreadyRecoveringBlocksSecondReload() {
        XCTAssertFalse(Decision.shouldRecover(
            isDisposed: false,
            needsRendererRecovery: true,
            isRecoveringRenderer: true,
            appIsActive: true,
            isPaused: false
        ), "Duplicate terminations must never stack reloads.")
    }

    func testDisposedBlocksRecovery() {
        XCTAssertFalse(Decision.shouldRecover(
            isDisposed: true,
            needsRendererRecovery: true,
            isRecoveringRenderer: false,
            appIsActive: true,
            isPaused: false
        ), "Torn-down coordinators must never reload.")
    }

    func testPausedAndRecoveringTogetherStillBlock() {
        XCTAssertFalse(Decision.shouldRecover(
            isDisposed: false,
            needsRendererRecovery: true,
            isRecoveringRenderer: true,
            appIsActive: true,
            isPaused: true
        ))
    }
}