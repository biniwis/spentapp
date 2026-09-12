import XCTest
import SwiftData
@testable import MoneyCity

/// Phase 9 gate: closed months freeze their selected Hero / Noticed / MicroFact content and
/// never re-curate on reopen, while the open current month keeps regenerating normally.
///
/// These tests exercise `DatabaseService.shared.context` — the production container — because
/// custom in-memory containers built inside the unit-test host are unreliable for the
/// newly-added `RecapSnapshot` model in this toolchain. Far-future month keys (2098) keep the
/// tests isolated from any real user data, and `tearDown` removes the rows each test creates.
@MainActor
final class RecapSnapshotTests: XCTestCase {

    // MARK: - Helpers

    private var context: ModelContext { DatabaseService.shared.context }
    private var touchedMonthIds: Set<String> = []

    override func tearDown() {
        for monthId in touchedMonthIds {
            let rows = (try? context.fetch(FetchDescriptor<RecapSnapshot>(
                predicate: #Predicate { $0.monthId == monthId }))) ?? []
            for row in rows { context.delete(row) }
            _ = DatabaseService.safeSave(context, caller: "RecapSnapshotTests.tearDown")
        }
        touchedMonthIds.removeAll()
    }

    private func countSnapshots(_ monthId: String) throws -> Int {
        try context.fetchCount(FetchDescriptor<RecapSnapshot>(
            predicate: #Predicate { $0.monthId == monthId }))
    }

    private func gregorian() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Jerusalem") ?? cal.timeZone
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        gregorian().date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func tx(
        _ amount: Double, _ merchant: String, _ category: SpendingCategory,
        _ year: Int, _ month: Int, _ day: Int
    ) -> Transaction {
        Transaction(amount: amount, merchant: merchant, category: category, timestamp: date(year, month, day))
    }

    private func curatedInsight(
        family: String? = "outlier",
        category: SpendingCategory? = .shopping,
        merchant: String? = "Zara",
        score: Double = 0.66,
        headlineHe: String? = "רכישה אחת שברה את התבנית",
        headlineEn: String? = "One purchase broke the pattern",
        valueHe: String? = "₪450",
        valueEn: String? = "₪450",
        supportHe: String? = "לעומת 32 ₪ ברכישה ממוצעת",
        supportEn: String? = "vs ₪32 on an average purchase"
    ) -> MonthlyRecapDynamicInsight {
        MonthlyRecapDynamicInsight(
            type: .curated,
            primaryValue: 450,
            secondaryValue: 3.1,
            count: 1,
            category: category,
            merchant: merchant,
            date: date(2026, 8, 14),
            score: score,
            copyVariant: "curated",
            family: family,
            headlineHe: headlineHe,
            headlineEn: headlineEn,
            valueHe: valueHe,
            valueEn: valueEn,
            supportHe: supportHe,
            supportEn: supportEn
        )
    }

    // MARK: - Codable story round trip

    func testStoryRoundTripsOneToOne() throws {
        let story = RecapStorySnapshot(
            dynamicInsights: [curatedInsight(), curatedInsight(family: "accumulation", score: 0.9)],
            noticedInsights: [curatedInsight(family: "concentration", score: 0.6)],
            microFactInsight: curatedInsight(family: "merchant", score: 0.32)
        )
        let data = try XCTUnwrap(try? RecapSnapshotService.makeEncoder().encode(story))
        let decoded = try XCTUnwrap(try RecapSnapshotService.makeDecoder().decode(RecapStorySnapshot.self, from: data))
        XCTAssertEqual(decoded, story)
        XCTAssertEqual(decoded.dynamicInsights.count, 2)
        XCTAssertEqual(decoded.noticedInsights.count, 1)
        XCTAssertEqual(decoded.microFactInsight, story.microFactInsight)
    }

    // MARK: - Closed month freeze + no re-curation

    func testClosedMonthFreezesOnceAndIsNeverRecurated() throws {
        let now = date(2098, 9, 5) // August 2098 is entirely in the past → closed
        touchedMonthIds.insert("2098-08")

        var all = [
            tx(3200, "שכירות", .housing, 2098, 8, 1),
            tx(450, "Zara", .shopping, 2098, 8, 14),
            tx(150, "Shufersal", .food, 2098, 8, 3),
            tx(90, "Shufersal", .food, 2098, 8, 10)
        ]

        let first = MonthlyRecapService.timelineRecap(
            for: date(2098, 8, 1), allTransactions: all, context: context, now: now
        )
        XCTAssertEqual(first.monthId, "2098-08")
        XCTAssertFalse(first.dynamicInsights.isEmpty, "a two-story month must not be empty")
        XCTAssertEqual(try countSnapshots("2098-08"), 1)

        // A dataset the current engine would curate differently must not touch the archive:
        // the stored story is the one that renders.
        all.append(tx(700, "Salomon", .shopping, 2098, 8, 20))
        all.append(tx(300, "Castro", .shopping, 2098, 8, 22))

        let reopened = MonthlyRecapService.timelineRecap(
            for: date(2098, 8, 1), allTransactions: all, context: context, now: now
        )
        XCTAssertEqual(reopened.dynamicInsights, first.dynamicInsights)
        XCTAssertEqual(reopened.noticedInsights, first.noticedInsights)
        XCTAssertEqual(reopened.microFactInsight, first.microFactInsight)
        XCTAssertEqual(try countSnapshots("2098-08"), 1, "later openings must never overwrite")
    }

    func testFrozenStorySurvivesWhenEngineWouldPickNothingNew() throws {
        let now = date(2098, 9, 5)
        touchedMonthIds.insert("2098-08")

        let all = [
            tx(3200, "שכירות", .housing, 2098, 8, 1),
            tx(450, "Zara", .shopping, 2098, 8, 14),
            tx(150, "Shufersal", .food, 2098, 8, 3)
        ]
        let first = MonthlyRecapService.timelineRecap(
            for: date(2098, 8, 1), allTransactions: all, context: context, now: now
        )
        let frozen = RecapSnapshotService.storedStory(for: "2098-08", context: context)
        XCTAssertNotNil(frozen)

        // Reopen after the transactions are gone entirely: anchors keep their frozen story.
        let reopened = MonthlyRecapService.timelineRecap(
            for: date(2098, 8, 1), allTransactions: [], context: context, now: now
        )
        XCTAssertEqual(reopened.dynamicInsights, first.dynamicInsights)
        XCTAssertEqual(reopened.noticedInsights, first.noticedInsights)
    }

    // MARK: - Open month keeps regenerating

    func testOpenCurrentMonthRegeneratesWithoutAnyFreeze() throws {
        let now = date(2098, 9, 10) // mid September → open

        var all = [
            tx(50, "Aroma", .food, 2098, 9, 5),
            tx(120, "Super", .food, 2098, 9, 8)
        ]
        let first = MonthlyRecapService.timelineRecap(
            for: date(2098, 9, 1), allTransactions: all, context: context, now: now
        )
        XCTAssertEqual(first.monthId, "2098-09")
        XCTAssertEqual(try countSnapshots("2098-09"), 0)

        // Growing the open month changes the live recap — no snapshot, no freeze.
        all.append(tx(45, "Aroma", .food, 2098, 9, 12))
        let second = MonthlyRecapService.timelineRecap(
            for: date(2098, 9, 1), allTransactions: all, context: context, now: now
        )
        XCTAssertEqual(second.transactionCount, 3)
        XCTAssertEqual(try countSnapshots("2098-09"), 0)
    }

    func testFinalDayOfCurrentMonthIsClosedAndFrozen() throws {
        let lastDay = date(2098, 9, 30, hour: 23)
        touchedMonthIds.insert("2098-09")
        let all = [
            tx(3200, "שכירות", .housing, 2098, 9, 1),
            tx(150, "Shufersal", .food, 2098, 9, 20)
        ]
        let recap = MonthlyRecapService.timelineRecap(
            for: date(2098, 9, 1), allTransactions: all, context: context, now: lastDay
        )
        XCTAssertEqual(recap.monthId, "2098-09")
        XCTAssertEqual(try countSnapshots("2098-09"), 1)
    }

    // MARK: - Applying a frozen story

    func testAppliedStoryReplacesOnlyTheStorySlots() throws {
        let recap = MonthlyRecapService.generateRecap(
            for: date(2098, 8, 1), allTransactions: [], monthlyBudget: 8000
        )
        XCTAssertTrue(recap.dynamicInsights.isEmpty)

        let story = RecapStorySnapshot(
            dynamicInsights: [curatedInsight()],
            noticedInsights: [curatedInsight(family: "concentration")],
            microFactInsight: curatedInsight(family: "merchant", score: 0.32)
        )
        let applied = RecapSnapshotService.applied(to: recap, story: story)
        XCTAssertEqual(applied.dynamicInsights, story.dynamicInsights)
        XCTAssertEqual(applied.noticedInsights, story.noticedInsights)
        XCTAssertEqual(applied.microFactInsight, story.microFactInsight)
        // Accounting anchors are untouched by the story swap.
        XCTAssertEqual(applied.transactionCount, 0)
        XCTAssertEqual(applied.monthId, recap.monthId)
        XCTAssertEqual(applied.cityVibe, recap.cityVibe)
    }
}