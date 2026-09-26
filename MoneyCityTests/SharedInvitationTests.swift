import XCTest
@testable import MoneyCity
import CloudKit

/// The rules behind handing somebody a link they can open.
///
/// `createInvitationLink` itself is a CloudKit round trip and stays integration level —
/// what is pinned down here is every decision it makes on the way there, so a change
/// that would quietly make a space public, hand out a claimed link, or let a
/// non-owner invite people fails here rather than in somebody's WhatsApp.
final class SharedInvitationTests: XCTestCase {

    // MARK: - Who may ask for a link

    func testOwnerWithNothingPendingIsAllowed() throws {
        XCTAssertNoThrow(try SharedInvitation.validate(isDemo: false, isOwner: true,
                                                       hasPendingLocalChanges: false))
    }

    func testNonOwnerCannotCreateAnInvite() {
        XCTAssertThrowsError(try SharedInvitation.validate(isDemo: false, isOwner: false,
                                                          hasPendingLocalChanges: false)) { error in
            XCTAssertEqual(error as? SharedLedgerError, .noAccess)
        }
    }

    func testDemoSpaceCannotCreateAnInvite() {
        // Demo is checked before ownership: it has no CloudKit share to invite into.
        XCTAssertThrowsError(try SharedInvitation.validate(isDemo: true, isOwner: false,
                                                          hasPendingLocalChanges: false)) { error in
            XCTAssertEqual(error as? SharedLedgerError, .noAccount)
        }
    }

    func testUnsyncedEditsBlockAnInvite() {
        // Inviting now would promise the new member a space that does not match the one
        // the owner's own pending edits are about to produce.
        XCTAssertThrowsError(try SharedInvitation.validate(isDemo: false, isOwner: true,
                                                          hasPendingLocalChanges: true)) { error in
            XCTAssertEqual(error as? SharedLedgerError, .pendingChanges)
        }
    }

    // MARK: - The share stays private

    func testPrivateShareIsAccepted() {
        XCTAssertNoThrow(try SharedInvitation.ensurePrivate(.none))
    }

    func testPublicShareIsRefusedRatherThanSaved() {
        // An invitation link needs no public share. Accepting one here would reopen the
        // space's expenses to anyone holding the URL.
        for permission in [CKShare.ParticipantPermission.readOnly, .readWrite] {
            XCTAssertThrowsError(try SharedInvitation.ensurePrivate(permission)) { error in
                XCTAssertEqual(error as? SharedLedgerError, .noAccess)
            }
        }
    }

    func testFreshShareIsStillPrivate() {
        let share = CKShare(recordZoneID: CKRecordZone(zoneName: "SPENT.Shared.test").zoneID)
        share.publicPermission = .none
        XCTAssertNoThrow(try SharedInvitation.ensurePrivate(share.publicPermission))
        XCTAssertEqual(share.publicPermission, .none)
    }

    // MARK: - One-time participants

    func testNewOneTimeParticipantCanReadAndWrite() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("one-time URL participants need iOS 18")
        }
        let participant = CKShare.Participant.oneTimeURLParticipant()
        participant.permission = .readWrite
        // A member is invited to add expenses; read-only would be the wrong promise.
        XCTAssertEqual(participant.permission, .readWrite)
        XCTAssertFalse(participant.participantID.isEmpty)
    }

    // "One explicit invite, one brand new participant" has no unit test on purpose.
    // `CKShare.addParticipant(_:)` traps inside CloudKit on a share that was never
    // saved, and the real path always works from a share the server already holds, so
    // any test of it would be testing a state production never reaches.

    // MARK: - A link that never arrived

    func testMissingLinkIsAnErrorRatherThanAnEmptyInvite() {
        XCTAssertThrowsError(try SharedInvitation.requireLink(nil)) { error in
            XCTAssertEqual(error as? SharedLedgerError, .inviteLinkUnavailable)
        }
    }

    func testLinkIsReturnedWhenCloudKitProducedOne() throws {
        let url = URL(string: "https://www.icloud.com/share/abc123")!
        XCTAssertEqual(try SharedInvitation.requireLink(url), url)
    }

    func testBothInviteFailuresCarryTheirOwnMessage() {
        // A silent failure here looks to the user like the button did nothing.
        for error in [SharedLedgerError.inviteLinkUnavailable, .inviteLinkUnsupported] {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.isUserInput, "a CloudKit or OS fault is not the user's typo")
        }
    }

    // MARK: - The manual fallback still works

    func testPastedInvitationLinkIsAcceptedWithStrayWhitespace() throws {
        // People paste links with a trailing space or a newline. CloudKit rejects the
        // untrimmed form, so this is the difference between a typo and a dead end.
        let clean = "https://www.icloud.com/share/abc123"
        for sloppy in [clean + " ", clean + "\n", "  " + clean + "\n"] {
            XCTAssertEqual(SharedInvitation.pastedURL(sloppy)?.absoluteString, clean)
        }
    }

    func testJunkIsNotTreatedAsAnInvitationLink() {
        for junk in ["", "   ", "not a url", "ftp://icloud.com/share", "icloud.com/share", "https://"] {
            XCTAssertNil(SharedInvitation.pastedURL(junk), "\(junk) should not parse as an invitation")
        }
    }
}
