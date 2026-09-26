import XCTest
import SwiftData
@testable import MoneyCity

/// A shared month is allowed into the personal recap, so these tests are mostly about what it
/// is *not* allowed to do: merge with the personal half, invent a number the space's own
/// month does not have, print one currency on another space's money, or leave anything behind
/// in the personal store.
@MainActor
final class SharedRecapSectionTests: XCTestCase {

    private let month = SharedRecapSectionTests.date(year: 2026, month: 8, day: 20)

    // MARK: - Fixtures

    private static func utcInstant(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func makeSpace(id: UUID = UUID(), name: String = "בית", currency: String = "ILS",
                           timeZone: String = "UTC", budgetMinor: Int64? = nil) -> SharedSpace {
        SharedSpace(id: id, name: name, currencyCode: currency, timeZoneID: timeZone,
                    mapStyle: "urban", createdAt: month, monthlyBudgetMinor: budgetMinor)
    }

    private func makeMember(_ id: String, _ spaceID: UUID, name: String? = nil,
                            color: String = "#7C5CFF", active: Bool = true) -> SharedMember {
        SharedMember(id: id, spaceID: spaceID, name: name ?? id, colorHex: color, isActive: active)
    }

    private func makeExpense(spaceID: UUID, minor: Int64, paidBy: String,
                             category: SpendingCategory = .food, currency: String = "ILS",
                             unresolved: Bool = false, instant: Date? = nil,
                             inMonth: Int = 8) -> SharedExpense {
        SharedExpense(id: UUID(), spaceID: spaceID, amountMinor: minor, currencyCode: currency,
                      merchant: "M", category: category, buildingID: "food_bistro",
                      date: instant ?? Self.date(year: 2026, month: inMonth, day: 3),
                      note: "", paidBy: paidBy, createdBy: paidBy, updatedBy: paidBy,
                      originalAmount: unresolved ? "10.00" : nil,
                      originalCurrency: unresolved ? "EUR" : nil,
                      exchangeRate: nil, exchangeRateDate: nil)
    }

    private func sections(for month: Date, spaces: [SharedSpace], expenses: [SharedExpense],
                          members: [SharedMember]) -> [SharedRecapSection] {
        SharedRecapSection.sections(for: month, spaces: spaces, expenses: expenses, members: members)
    }

    private func personalRecap(_ amounts: [(Double, Int, SpendingCategory)] = [(90, 2, .food)],
                               budget: Double = 8000) -> MonthlyRecap {
        MonthlyRecapService.generateRecap(
            for: month,
            allTransactions: amounts.map {
                MoneyCity.Transaction(amount: $0.0, merchant: "P", category: $0.2,
                                      timestamp: Self.date(year: 2026, month: 8, day: $0.1))
            },
            monthlyBudget: budget)
    }

    private func noticedInsight() -> MonthlyRecapDynamicInsight {
        MonthlyRecapDynamicInsight(type: .curated, primaryValue: 0, secondaryValue: 0, count: 0,
                                   category: nil, merchant: "P", date: nil, score: 0.5,
                                   copyVariant: "curated", family: "merchant",
                                   headlineHe: "מסעדה אחת", headlineEn: "One restaurant")
    }

    // MARK: - Personal only is untouched

    func testAPersonalOnlyMonthIsTheSequenceItHasAlwaysBeen() {
        let recap = personalRecap()

        XCTAssertEqual(
            RecapEditorialShot.sequence(for: recap, sharedSections: []),
            RecapEditorialShot.sequence(for: recap),
            "No shared sections must be indistinguishable from the call this screen always made"
        )
        for shot in RecapEditorialShot.sequence(for: recap) {
            switch shot {
            case .sharedOverview, .sharedMembers:
                XCTFail("A personal recap has no shared pages in it at all")
            default:
                break
            }
        }
    }

    // MARK: - Both halves, in order, never merged

    func testTheStoryRunsPersonalThenSharedThenClose() {
        let space = makeSpace()
        let shared = sections(for: month, spaces: [space],
                              expenses: [makeExpense(spaceID: space.id, minor: 2_000, paidBy: "a"),
                                        makeExpense(spaceID: space.id, minor: 1_000, paidBy: "b",
                                                    inMonth: 8)],
                              members: [makeMember("a", space.id), makeMember("b", space.id)])
        var recap = personalRecap()
        recap.noticedInsights = [noticedInsight()]

        let shots = RecapEditorialShot.sequence(for: recap, sharedSections: shared)

        XCTAssertEqual(shots, [
            .opening, .total, .activity, .district,
            .sharedOverview(shared[0]), .sharedMembers(shared[0]),
            .noticed(recap.noticedInsights),
            .portrait,
        ])

        XCTAssertEqual(shared[0].spentMinor, 3_000, "The space's own month")
        XCTAssertNotEqual(shared[0].spentMinor, 3_000 + Int64(recap.totalSpent),
                          "The two halves are never added into one figure")
    }

    func testAPersonalMonthWithNothingToSayGetsNoPersonalPages() {
        let space = makeSpace()
        let shared = sections(for: month, spaces: [space],
                              expenses: [makeExpense(spaceID: space.id, minor: 4_200, paidBy: "a")],
                              members: [makeMember("a", space.id)])
        let recap = MonthlyRecapService.generateRecap(for: month, allTransactions: [])
        XCTAssertEqual(recap.transactionCount, 0)

        let shots = RecapEditorialShot.sequence(for: recap, sharedSections: shared)

        XCTAssertEqual(shots, [.opening, .sharedOverview(shared[0]), .sharedMembers(shared[0]), .portrait],
                       "No total, no activity, no district — a zero would be an invention")
    }

    // MARK: - Who paid

    func testMemberAmountsColoursAndOrderComeFromTheSpaceUnchanged() {
        let space = makeSpace()
        let members = [
            makeMember("a", space.id, name: "נועה", color: "#FF7A5C"),
            makeMember("b", space.id, name: "דן", color: "#2D9CDB"),
            makeMember("c", space.id, name: "רונית", color: "#27AE60"),
        ]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 3_000, paidBy: "a"),
            makeExpense(spaceID: space.id, minor: 1_500, paidBy: "b"),
        ]
        let section = sections(for: month, spaces: [space], expenses: expenses, members: members)[0]

        XCTAssertEqual(section.memberTotals.map(\.memberID), members.map(\.id),
                       "The order the space reports is the order the page uses — this is not a ranking")
        XCTAssertEqual(section.memberTotals.map(\.amountMinor), [3_000, 1_500, 0],
                       "Somebody who was there and paid nothing is still a real zero")
        XCTAssertEqual(section.memberTotals.map(\.colorHex), ["#FF7A5C", "#2D9CDB", "#27AE60"])
        XCTAssertTrue(section.hasMemberRow)
    }

    func testSomebodyWhoPaidAndThenLeftIsStillPartOfThatMonth() {
        let space = makeSpace()
        let members = [makeMember("stays", space.id, name: "נועה"),
                       makeMember("left", space.id, name: "אורי", active: false)]
        let expenses = [makeExpense(spaceID: space.id, minor: 2_500, paidBy: "left")]
        let section = sections(for: month, spaces: [space], expenses: expenses, members: members)[0]

        XCTAssertEqual(section.memberTotals.map(\.memberID), ["stays", "left"])
        XCTAssertEqual(section.memberTotals.last?.amountMinor, 2_500,
                       "August happened to them, so August still reports their spending")
        XCTAssertEqual(section.unattributedMinor, 0,
                       "Being inactive is not a reason to turn a payer into nobody")
    }

    func testMoneyPaidBySomebodyOutsideTheSpaceIsNamedRatherThanSpreadAround() {
        let space = makeSpace()
        let expenses = [
            makeExpense(spaceID: space.id, minor: 1_000, paidBy: "a"),
            makeExpense(spaceID: space.id, minor: 400, paidBy: "guest"),
        ]
        let section = sections(for: month, spaces: [space], expenses: expenses,
                              members: [makeMember("a", space.id)])[0]

        XCTAssertEqual(section.unattributedMinor, 400)
        XCTAssertTrue(section.hasUnattributed)
        XCTAssertEqual(section.memberTotals.map(\.amountMinor), [1_000],
                       "The rows are the members' own money; the gap is reported, not redistributed")
    }

    // MARK: - The spaces on screen

    func testASpaceWithNothingInTheMonthIsNotAPage() {
        let quiet = makeSpace(name: "שקט")
        let busy = makeSpace(name: "רועש")
        let expenses = [makeExpense(spaceID: busy.id, minor: 900, paidBy: "a")]
        let members = [makeMember("a", busy.id)]

        XCTAssertEqual(sections(for: month, spaces: [quiet, busy], expenses: expenses,
                                members: members).map(\.spaceName), ["רועש"])
    }

    func testASpaceTheReaderCannotSeeAnyMoreContributesNothing() {
        // Visibility is the store's rule, not the recap's: a space that is not handed over
        // cannot become a page, so nothing about a space the user left is retained here.
        let old = makeSpace(name: "ישן")
        let expenses = [makeExpense(spaceID: old.id, minor: 5_000, paidBy: "a")]

        XCTAssertTrue(sections(for: month, spaces: [], expenses: expenses,
                               members: [makeMember("a", old.id, active: false)]).isEmpty)
    }

    func testTwoSpacesInTwoCurrenciesAreTwoSectionsThatNeverMeet() {
        let shekels = makeSpace(name: "בית", currency: "ILS", budgetMinor: 800_000)
        let euros = makeSpace(name: "חופשה", currency: "EUR", budgetMinor: 400_000)
        let members = [makeMember("a", shekels.id), makeMember("b", euros.id)]
        let expenses = [
            makeExpense(spaceID: shekels.id, minor: 62_400, paidBy: "a"),
            makeExpense(spaceID: euros.id, minor: 12_000, paidBy: "b", currency: "EUR"),
        ]
        let shared = sections(for: month, spaces: [shekels, euros], expenses: expenses, members: members)

        XCTAssertEqual(shared.count, 2)
        XCTAssertEqual(shared.map(\.currencyCode), ["ILS", "EUR"])
        XCTAssertEqual(shared.map(\.currencySymbol), [SharedMoney.symbol("ILS"), SharedMoney.symbol("EUR")])
        XCTAssertNotEqual(shared[0].currencySymbol, shared[1].currencySymbol,
                          "One symbol for two currencies would be a claim about one pot of money")
        XCTAssertEqual(Set(shared.map(\.id)).count, 2, "Two spaces are two pages")

        let shots = RecapEditorialShot.sequence(for: personalRecap(), sharedSections: shared)
        let ids = shots.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Every page needs its own identity to animate")
        XCTAssertTrue(ids.contains("shared-overview-\(shekels.id.uuidString)"))
        XCTAssertTrue(ids.contains("shared-members-\(euros.id.uuidString)"))
    }

    // MARK: - The target, in its three honest states

    func testTheTargetIsReportedAsRemainingOverOrAbsent() {
        let under = makeSpace(name: "מתחת", budgetMinor: 800_000)
        let over = makeSpace(name: "מעל", budgetMinor: 100_000)
        let none = makeSpace(name: "בלי", budgetMinor: nil)
        let members = [makeMember("a", under.id), makeMember("b", over.id), makeMember("c", none.id)]
        let expenses = [
            makeExpense(spaceID: under.id, minor: 62_400, paidBy: "a"),
            makeExpense(spaceID: over.id, minor: 125_000, paidBy: "b"),
            makeExpense(spaceID: none.id, minor: 3_000, paidBy: "c"),
        ]
        let shared = sections(for: month, spaces: [under, over, none], expenses: expenses, members: members)

        XCTAssertEqual(shared[0].remainingMinor, 737_600)
        XCTAssertNil(shared[0].overTargetMinor, "Still inside the target")
        XCTAssertEqual(shared[1].overTargetMinor, 25_000, "A distance over the target")
        XCTAssertEqual(shared[1].remainingMinor, -25_000,
                       "The signed remainder is still real data, and it is what makes the two agree")
        XCTAssertNil(shared[2].targetMinor, "No target is not a target of zero")
        XCTAssertNil(shared[2].remainingMinor)
        XCTAssertNil(shared[2].overTargetMinor)
    }

    // MARK: - Refunds, unresolved money, and whose month it is

    func testARefundIsSignedAndCannotBecomeTheBiggestCategory() {
        let space = makeSpace()
        let expenses = [
            makeExpense(spaceID: space.id, minor: 1_000, paidBy: "a"),
            makeExpense(spaceID: space.id, minor: 3_000, paidBy: "a", category: .transport),
            // A big charge that came back: the money left the account and returned.
            makeExpense(spaceID: space.id, minor: -9_000, paidBy: "b", category: .shopping),
        ]
        let section = sections(for: month, spaces: [space], expenses: expenses,
                              members: [makeMember("a", space.id), makeMember("b", space.id)])[0]

        XCTAssertEqual(section.spentMinor, -5_000, "Signed, so a refund can lower a month")
        XCTAssertEqual(section.memberTotals.first { $0.memberID == "b" }?.amountMinor, -9_000,
                       "Shown as money coming back, not as a smaller contribution")
        XCTAssertEqual(section.biggestCategory?.category, .transport,
                       "Money set aside or returned is not spending and cannot win a category")
        XCTAssertTrue(section.money(-9_000).hasPrefix("\u{2212}"), "The sign survives into the figure")
    }

    func testUnresolvedMoneyIsCountedButNeverSummedOrHidden() {
        let space = makeSpace(budgetMinor: 800_000)
        let expenses = [
            makeExpense(spaceID: space.id, minor: 10_000, paidBy: "a"),
            makeExpense(spaceID: space.id, minor: 5_000, paidBy: "a", unresolved: true),
        ]
        let section = sections(for: month, spaces: [space], expenses: expenses,
                              members: [makeMember("a", space.id)])[0]

        XCTAssertEqual(section.transactionCount, 2, "It happened, so the month happened")
        XCTAssertEqual(section.spentMinor, 10_000, "Money with no rate is never guessed at")
        XCTAssertEqual(section.unresolvedCount, 1)
        XCTAssertTrue(section.hasUnresolved)
    }

    func testTheSpaceCalendarDecidesWhichMonthARecordBelongsTo() {
        // Noon UTC on the last day of August is already September east of the date line and
        // still August west of it. The space's own calendar is what decides, not the reader's.
        let instant = SharedRecapSectionTests.utcInstant(year: 2026, month: 8, day: 31, hour: 12)
        let east = makeSpace(name: "מזרח", timeZone: "Pacific/Kiritimati")
        let west = makeSpace(name: "מערב", timeZone: "Pacific/Midway")
        let members = [makeMember("a", east.id), makeMember("a", west.id)]
        let expenses = [
            makeExpense(spaceID: east.id, minor: 1_000, paidBy: "a", instant: instant),
            makeExpense(spaceID: west.id, minor: 2_000, paidBy: "a", instant: instant),
        ]
        let august = Self.date(year: 2026, month: 8, day: 20)
        let september = Self.date(year: 2026, month: 9, day: 20)

        XCTAssertEqual(sections(for: august, spaces: [east], expenses: expenses, members: members).count, 0,
                       "For the space east of the date line this record is September's")
        XCTAssertEqual(sections(for: august, spaces: [west], expenses: expenses, members: members)
                        .map(\.spentMinor), [2_000])
        XCTAssertEqual(sections(for: september, spaces: [east], expenses: expenses, members: members)
                        .map(\.spentMinor), [1_000])
    }

    // MARK: - The archive is one list of months

    func testTheArchiveListsASharedOnlyMonthExactlyOnce() {
        let space = makeSpace()
        let july = Self.date(year: 2026, month: 7, day: 10)
        let personal = [MoneyCity.Transaction(amount: 50, merchant: "P", category: .food, timestamp: july)]
        let sharedExpenses = [
            makeExpense(spaceID: space.id, minor: 1_000, paidBy: "a", inMonth: 7),
            makeExpense(spaceID: space.id, minor: 2_000, paidBy: "a", inMonth: 8),
        ]
        let cal = Calendar(identifier: .gregorian)
        let sharedMonths = SharedRecapSection.monthsWithActivity(spaces: [space], expenses: sharedExpenses,
                                                                  on: cal)

        let months = MonthlyRecapService.availableRecapMonths(from: personal, sharedMonths: sharedMonths)

        XCTAssertEqual(months.filter { $0 == cal.dateInterval(of: .month, for: july)!.start }.count, 1,
                       "Personal and shared in one month is one month, not two rows")
        XCTAssertEqual(months.filter { $0 == cal.dateInterval(of: .month, for: month)!.start }.count, 1)
        XCTAssertTrue(months.contains(cal.dateInterval(of: .month, for: month)!.start),
                      "A month only a space lived in is still openable")

        XCTAssertEqual(MonthlyRecapService.availableRecapMonths(from: personal),
                       MonthlyRecapService.availableRecapMonths(from: personal, sharedMonths: []),
                       "A personal-only list is exactly what it was before shared months existed")
    }

    // MARK: - Nothing is left behind

    func testASharedStoryNeverReachesThePersonalSnapshot() throws {
        // The production container, as `RecapSnapshotTests` does it: a custom in-memory
        // container is unreliable for this model in this toolchain. A far-future month keeps
        // the row away from any real data, and tearDown removes it.
        let monthId = "2098-08"
        let context = DatabaseService.shared.context
        defer {
            let rows = (try? context.fetch(FetchDescriptor<RecapSnapshot>(
                predicate: #Predicate { $0.monthId == monthId }))) ?? []
            for row in rows { context.delete(row) }
            _ = DatabaseService.safeSave(context, caller: "SharedRecapSectionTests")
        }

        let space = makeSpace(name: "מרחב סודי")
        let members = [makeMember("a", space.id, name: "נועה")]
        let expenses = [makeExpense(spaceID: space.id, minor: 9_999, paidBy: "a")]
        let shared = sections(for: month, spaces: [space], expenses: expenses, members: members)
        let recap = personalRecap()

        XCTAssertTrue(RecapSnapshotService.freeze(RecapSnapshotService.story(from: recap),
                                                  for: monthId, context: context))
        let row = try XCTUnwrap(try context.fetch(FetchDescriptor<RecapSnapshot>(
            predicate: #Predicate { $0.monthId == monthId })).first)

        XCTAssertFalse(row.payloadJSON.contains(space.name), "No space name in the personal store")
        XCTAssertFalse(row.payloadJSON.contains("נועה"), "No member name in the personal store")
        XCTAssertFalse(row.payloadJSON.contains("9,999"), "No shared amount in the personal store")
        XCTAssertFalse(row.payloadJSON.contains("shared-overview"))

        // The shared half is rebuilt on demand rather than read back out of storage.
        XCTAssertEqual(sections(for: month, spaces: [space], expenses: expenses, members: members),
                       shared, "Same ledger in, same page out — nothing was frozen")
    }
}
