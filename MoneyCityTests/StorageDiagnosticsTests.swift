import XCTest
import SwiftData
@testable import MoneyCity

/// The ingest log holds raw merchant names and amounts, so how long it keeps them is a
/// privacy rule, not a housekeeping detail. These cases pin both ends of it: too aggressive
/// and the evidence is gone before the user can show it to anyone, too lax and the log
/// quietly becomes a second, unbounded copy of their spending history.
final class IngestLogRetentionTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_770_000_000)

    private func age(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 24 * 60 * 60)
    }

    func testNewestEntryIsKept() {
        XCTAssertFalse(
            DatabaseService.shouldDropIngestEntry(index: 0, receivedAt: now, now: now)
        )
    }

    func testEntryJustInsideTheCountCapIsKept() {
        XCTAssertFalse(
            DatabaseService.shouldDropIngestEntry(
                index: IngestLogRetention.maxEntries - 1, receivedAt: age(1), now: now
            )
        )
    }

    func testEntryAtTheCountCapIsDropped() {
        XCTAssertTrue(
            DatabaseService.shouldDropIngestEntry(
                index: IngestLogRetention.maxEntries, receivedAt: age(1), now: now
            )
        )
    }

    func testRecentEntryPastTheAgeLimitIsDroppedEvenAtIndexZero() {
        // The count cap alone would keep this forever for a light user.
        XCTAssertTrue(
            DatabaseService.shouldDropIngestEntry(index: 0, receivedAt: age(15), now: now)
        )
    }

    func testEntryExactlyAtTheAgeLimitIsKept() {
        XCTAssertFalse(
            DatabaseService.shouldDropIngestEntry(index: 0, receivedAt: age(14), now: now)
        )
    }

    func testEntryOneSecondPastTheAgeLimitIsDropped() {
        let stale = now.addingTimeInterval(-(IngestLogRetention.maxAge + 1))
        XCTAssertTrue(
            DatabaseService.shouldDropIngestEntry(index: 0, receivedAt: stale, now: now)
        )
    }

    func testFutureDatedEntryIsNotDropped() {
        // A device whose clock jumped forward and back must not erase its own evidence.
        XCTAssertFalse(
            DatabaseService.shouldDropIngestEntry(
                index: 0, receivedAt: now.addingTimeInterval(3600), now: now
            )
        )
    }

    func testRetentionWindowIsTwoWeeks() {
        XCTAssertEqual(IngestLogRetention.maxAge, 14 * 24 * 60 * 60)
    }
}

/// The versioned schema is the thing that lets the next model change be a migration instead
/// of a failed launch. If a model is ever added to the container without being added here,
/// the version stops describing the store and the plan is silently useless — so the list is
/// asserted directly.
final class MoneyCitySchemaTests: XCTestCase {

    func testSchemaIsAtVersionOne() {
        XCTAssertEqual(MoneyCitySchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
    }

    func testMigrationPlanStartsFromV1() {
        // Compared by name rather than by metatype: existential metatype equality is
        // fragile across toolchains, and the name is what actually has to stay stable.
        XCTAssertEqual(
            MoneyCityMigrationPlan.schemas.map { String(describing: $0) },
            ["MoneyCitySchemaV1"]
        )
    }

    func testEveryPersistedModelIsListedExactlyOnce() {
        let names = MoneyCitySchemaV1.models.map { String(describing: $0) }
        XCTAssertEqual(names.count, Set(names).count, "a model is listed twice in the schema")

        let expected: Set<String> = [
            "Transaction",
            "CityEnrichment",
            "RecurringExpense",
            "IncomeSource",
            "CategoryBudget",
            "MerchantRule",
            "InstallmentPlan",
            "SavingsGoal",
            "IngestLogEntry"
        ]
        XCTAssertEqual(
            Set(names), expected,
            "a model was added or removed without updating the versioned schema"
        )
    }
}
