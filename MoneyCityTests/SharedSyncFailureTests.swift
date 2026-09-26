import XCTest
@testable import MoneyCity
import CloudKit

/// What a failed CloudKit save is allowed to do to a space and to the queued change.
///
/// This is the regression test for a bug that cost users their work: every error other
/// than `zoneNotFound` used to be treated as a revocation, so one dropped connection
/// removed the pending expense from the queue and hid the space — including the owner's
/// own — as if it had been deleted. A transport problem and a deleted zone look identical
/// if you only ask "did the save fail?", and the fix is to stop asking that.
final class SharedSyncFailureTests: XCTestCase {

    // MARK: - The classification itself

    func testTransportAndServerFailuresAreRetryable() {
        let retryable: [CKError.Code] = [.networkUnavailable, .networkFailure, .serviceUnavailable,
                                         .requestRateLimited, .zoneBusy, .internalError,
                                         .partialFailure, .operationCancelled,
                                         .badContainer, .badDatabase, .serverRejectedRequest]
        for code in retryable {
            XCTAssertEqual(SharedSyncClassifier.classify(code), .retryable, "\(code) should be retryable")
        }
    }

    func testAccountFailureIsNotARevocation() {
        // Signing out must never cost the user the space or the write: signing back in has
        // to be enough to carry on, without a new invitation.
        XCTAssertEqual(SharedSyncClassifier.classify(.notAuthenticated), .accountRequired)
    }

    func testQuotaAndLimitAreReportedButKeepTheWrite() {
        // The entry is still correct and still worth uploading once space is freed, so the
        // change stays queued.
        XCTAssertEqual(SharedSyncClassifier.classify(.quotaExceeded), .quotaExceeded)
        XCTAssertEqual(SharedSyncClassifier.classify(.limitExceeded), .quotaExceeded)
    }

    func testConflictIsItsOwnOutcome() {
        XCTAssertEqual(SharedSyncClassifier.classify(.serverRecordChanged), .conflict)
    }

    func testOnlyPositiveEvidenceRevokes() {
        // A deleted share, a deleted zone, a removed participant and a refused permission
        // are the four that actually mean "you cannot reach this any more".
        let revoking: [CKError.Code] = [.unknownItem, .userDeletedZone, .permissionFailure]
        for code in revoking {
            XCTAssertEqual(SharedSyncClassifier.classify(code), .accessRevoked, "\(code) should revoke")
        }
    }

    func testMissingZoneIsCountedRatherThanBelieved() {
        // CloudKit's listing can lag a zone it has just written.
        XCTAssertEqual(SharedSyncClassifier.classify(.zoneNotFound), .zoneMissing)
    }

    func testUnrecognisedCodeIsTreatedAsRetryable() {
        // Being wrong in this direction costs a retry. Being wrong in the other direction
        // costs somebody's expense, so an unknown fault must never destroy queued work.
        XCTAssertEqual(SharedSyncClassifier.classify(.changeTokenExpired), .unknown)
    }

    // MARK: - What each outcome is allowed to do

    func testOnlyRevocationMayTakeTheWriteOutOfTheQueue() {
        XCTAssertTrue(SharedSyncFailure.retryable.keepsPendingChange)
        XCTAssertTrue(SharedSyncFailure.accountRequired.keepsPendingChange)
        XCTAssertTrue(SharedSyncFailure.quotaExceeded.keepsPendingChange)
        XCTAssertTrue(SharedSyncFailure.conflict.keepsPendingChange)
        XCTAssertTrue(SharedSyncFailure.zoneMissing.keepsPendingChange)
        XCTAssertTrue(SharedSyncFailure.unknown.keepsPendingChange)
        XCTAssertFalse(SharedSyncFailure.accessRevoked.keepsPendingChange)
    }

    func testOnlyRevocationMayHideTheSpace() {
        XCTAssertTrue(SharedSyncFailure.accessRevoked.mayRevokeSpace)
        for kind in [SharedSyncFailure.retryable, .accountRequired, .quotaExceeded,
                     .conflict, .zoneMissing, .unknown] {
            XCTAssertFalse(kind.mayRevokeSpace, "\(kind) must not hide a space")
        }
    }

    /// The behaviour that actually matters, stated as one property: for every outcome
    /// except a real revocation, a failed save leaves the user's queued work alone.
    func testNoTemporaryFailureEverDestroysPendingWork() {
        let temporary: [SharedSyncFailure] = [.retryable, .accountRequired, .quotaExceeded,
                                              .conflict, .zoneMissing, .unknown]
        for kind in temporary {
            XCTAssertTrue(kind.keepsPendingChange, "\(kind) dropped a pending change")
            XCTAssertFalse(kind.mayRevokeSpace, "\(kind) revoked a space")
        }
    }

    // MARK: - What the user is told

    func testSilentOutcomesDoNotInterrupt() {
        // A conflict has its own screen and a lagging zone listing is expected, so neither
        // should raise an alert over the top of the user's work.
        XCTAssertNil(SharedSyncFailure.retryable.reportText)
        XCTAssertNil(SharedSyncFailure.zoneMissing.reportText)
        XCTAssertNil(SharedSyncFailure.conflict.reportText)
    }

    func testOutcomesThatNeedAttentionSaySo() {
        XCTAssertNotNil(SharedSyncFailure.accountRequired.reportText)
        XCTAssertNotNil(SharedSyncFailure.quotaExceeded.reportText)
        XCTAssertNotNil(SharedSyncFailure.accessRevoked.reportText)
        XCTAssertNotNil(SharedSyncFailure.unknown.reportText)
    }

    /// Deliberately does not pin the language. The wording is checked structurally rather
    /// than against one language, because `AppLanguage.current` is process-wide: a test
    /// that writes the preference changes what every other test in the run sees, which is
    /// how a merchant test that hardcodes Hebrew output started failing here.
    func testOutcomesThatNeedAttentionAllSaySomething() throws {
        for kind in [SharedSyncFailure.accountRequired, .quotaExceeded,
                     .accessRevoked, .unknown] {
            let text = try XCTUnwrap(kind.reportText, "\(kind) had no message")
            XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
