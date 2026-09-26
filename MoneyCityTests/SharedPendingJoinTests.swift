import XCTest
import SwiftData
@testable import MoneyCity

/// A join that starts and does not finish is worse than a join that never started.
///
/// Accepting a share spends a one-time invitation on CloudKit's side, while the member that
/// makes the user real — name, colour, payable — is written locally afterwards. The two can
/// be split by a crash, a background kill, or a dead network, and nothing in the old flow
/// could tell the difference: the link had already stopped working, so the user was left
/// inside a space where nobody could assign spending to them and there was no way back in.
///
/// The CloudKit round trip itself stays integration level. What is pinned down here is
/// everything around it: that the intent survives being written to disk, that the
/// irreversible step happens in the right order, and that finishing twice changes nothing.
@MainActor
final class SharedPendingJoinTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("shared-join-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
        try super.tearDownWithError()
    }

    /// Reopening a store over the same directory is the shape of a relaunch: new process,
    /// same Shared store. If the intent were only in memory it would be gone, and the
    /// invitation with it.
    private func reopen() throws -> SharedDatabaseService {
        try SharedDatabaseService(directory: directory)
    }

    private func joins(_ database: SharedDatabaseService) throws -> [SharedPendingJoin] {
        try database.context.fetch(FetchDescriptor<SharedPendingJoin>())
    }

    // MARK: - The recorded intent survives

    func testPendingJoinSurvivesReopeningTheStore() throws {
        let space = UUID()
        let database = try reopen()
        database.context.insert(SharedPendingJoin(spaceID: space.uuidString, memberName: "Maya"))
        try database.save()

        let saved = try XCTUnwrap(try reopen().firstPendingJoin())
        XCTAssertEqual(saved.spaceID, space.uuidString)
        XCTAssertEqual(saved.memberName, "Maya")
        XCTAssertNil(saved.acceptedAt, "a fresh intent has not been accepted yet")
    }

    func testAcceptedStateIsRecordedSeparatelyFromTheIntent() throws {
        // Resume has to know whether CloudKit already accepted, otherwise a relaunch either
        // replays a share it already holds or gives up on one it already spent.
        let database = try reopen()
        let row = SharedPendingJoin(spaceID: UUID().uuidString, memberName: "Noa")
        database.context.insert(row)
        try database.save()
        XCTAssertNil(row.acceptedAt)

        row.acceptedAt = Date()
        try database.save()

        let saved = try XCTUnwrap(try reopen().firstPendingJoin())
        XCTAssertNotNil(saved.acceptedAt)
        XCTAssertEqual(saved.memberName, "Noa")
    }

    /// The record exists to repair an interrupted join, so it must not be able to stand in
    /// for the invitation itself. A copy of a share URL or token sitting in the app's
    /// container would be a reusable invitation in a place it was never meant to live.
    func testPendingJoinStoresNoInvitationMaterial() {
        // A @Model's own properties are underscore-prefixed and SwiftData adds its own
        // `$`-prefixed bookkeeping, so the field names are read off the instance and
        // compared rather than matched against an exhaustive set.
        let fields = Set(Mirror(reflecting: SharedPendingJoin(spaceID: UUID().uuidString, memberName: "Maya"))
            .children.compactMap(\.label)
            .map { String($0.drop(while: { $0 == "_" })) })
        for expected in ["spaceID", "memberName", "acceptedAt"] {
            XCTAssertTrue(fields.contains(expected), "the pending join should record \(expected)")
        }
        for forbidden in ["url", "token", "metadata", "shareURL"] {
            XCTAssertFalse(fields.contains(forbidden), "the pending join must not store \(forbidden)")
        }
    }

    /// One intent per space, enforced by the storage layer: a second tap cannot leave two
    /// records for the resume pass to reconcile, so it cannot rename or duplicate a join
    /// that is already under way.
    func testTheSameSpaceCannotAccumulateTwoIntents() throws {
        let space = UUID().uuidString
        let database = try reopen()
        database.context.insert(SharedPendingJoin(spaceID: space, memberName: "Maya"))
        try database.save()

        database.context.insert(SharedPendingJoin(spaceID: space, memberName: "Maya"))
        try? database.save()

        let rows = try joins(try reopen())
        XCTAssertEqual(rows.count, 1, "a space must not accumulate pending joins")
    }

    func testDeletingTheIntentLeavesNothingToResume() throws {
        // Cleared only after the member is real, so this is the state a completed join is
        // allowed to reach: a resumed pass finds nothing and does no work.
        let database = try reopen()
        let row = SharedPendingJoin(spaceID: UUID().uuidString, memberName: "Maya", acceptedAt: Date())
        database.context.insert(row)
        try database.save()

        database.context.delete(row)
        try database.save()

        XCTAssertTrue(try joins(try reopen()).isEmpty)
    }

    // MARK: - The order of a join

    func testIntentIsWrittenBeforeAnythingIrreversibleHappens() {
        // The one thing that cannot be undone must never be the first thing that happens.
        XCTAssertEqual(SharedJoin.next(hasIntent: false, cloudAccepted: false), .beginIntent)
    }

    func testAnIntentThatCloudKitHasNotAcceptedGoesToAccept() {
        XCTAssertEqual(SharedJoin.next(hasIntent: true, cloudAccepted: false), .accept)
    }

    /// A resumed join must not try to accept a share it already holds. Doing so is the
    /// failure this whole mechanism exists to prevent.
    func testAnAcceptedJoinResumesAtTheLocalHalfRatherThanAcceptingAgain() {
        XCTAssertEqual(SharedJoin.next(hasIntent: true, cloudAccepted: true), .finish)
    }

    func testAcceptedStateWithoutAnIntentDoesNotSkipTheRecord() {
        // Defensive: accepted without a recorded intent means the record was lost, and the
        // safe response is to rebuild it rather than assume the join is finished.
        XCTAssertEqual(SharedJoin.next(hasIntent: false, cloudAccepted: true), .beginIntent)
    }

    // MARK: - Entering a space

    func testAJoinThatIsNotMaterializedYetMustNotOpenTheSpace() {
        // CloudKit can accept a share before the zone shows up in this account's listing.
        XCTAssertFalse(SharedJoin.canActivate(materialized: false, canWrite: true, memberWritten: true))
    }

    func testAJoinWithoutAMemberMustNotOpenTheSpace() {
        // The member is the point of joining: no member row means no name, no colour and
        // nobody to assign spending to, which is exactly the state being prevented.
        XCTAssertFalse(SharedJoin.canActivate(materialized: true, canWrite: true, memberWritten: false))
    }

    func testAReadOnlyJoinMustNotOpenTheSpaceForWriting() {
        XCTAssertFalse(SharedJoin.canActivate(materialized: true, canWrite: false, memberWritten: true))
    }

    func testACompleteJoinOpensTheSpace() {
        XCTAssertTrue(SharedJoin.canActivate(materialized: true, canWrite: true, memberWritten: true))
    }

    // MARK: - Finishing twice is harmless

    func testRegisteringTheSameMemberTwiceWritesOneRow() async throws {
        // Resume may run after a finish that already succeeded, so the second run has to be
        // a no-op rather than a second member — or a second colour, which would make the
        // user's spending change colour in everybody else's recap.
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        let space = try XCTUnwrap(store.activeSpaceID)
        // A name the demo fixture does not already use, so this counts only what these two
        // calls produce.
        let name = "Tamar"

        try store.registerMember(in: space, name: name)
        let first = try XCTUnwrap(store.members.first { $0.spaceID == space && $0.name == name })

        try store.registerMember(in: space, name: name)
        let second = try XCTUnwrap(store.members.first { $0.spaceID == space && $0.name == name })

        XCTAssertEqual(store.members.filter { $0.spaceID == space && $0.name == name }.count, 1)
        XCTAssertEqual(first.id, second.id, "the same account must keep the same member identity")
        XCTAssertEqual(first.colorHex, second.colorHex, "a repeat must not change the member's colour")
    }
}

private extension SharedDatabaseService {
    func firstPendingJoin() throws -> SharedPendingJoin? {
        try context.fetch(FetchDescriptor<SharedPendingJoin>()).first
    }
}
