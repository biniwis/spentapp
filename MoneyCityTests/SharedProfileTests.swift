import XCTest
import SwiftData
@testable import MoneyCity

/// Covers the shared money arithmetic behind the shared Profile: which target belongs to
/// which space, what counts as this month's spend, and what each member is owed on the
/// ledger. All of it is pure, so none of it needs CloudKit or a signed-in account.
final class SharedProfileTests: XCTestCase {

    // MARK: - Builders

    private func makeSpace(id: UUID = UUID(),
                           currency: String = "ILS",
                           timeZone: String = "Asia/Jerusalem",
                           targetMinor: Int64? = 800_000) -> SharedSpace {
        SharedSpace(id: id,
                    name: "הבית שלנו",
                    currencyCode: currency,
                    timeZoneID: timeZone,
                    mapStyle: "classic",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    monthlyBudgetMinor: targetMinor)
    }

    private func makeMember(id: String, spaceID: UUID, name: String = "member", color: String = "#7C5CFF", active: Bool = true) -> SharedMember {
        SharedMember(id: id, spaceID: spaceID, name: name, colorHex: color, isActive: active)
    }

    /// Signed on purpose: a refund is a negative `amountMinor`, as in the personal ledger.
    private func makeExpense(spaceID: UUID,
                             minor: Int64,
                             paidBy: String,
                             at date: Date,
                             currency: String = "ILS",
                             originalCurrency: String? = nil,
                             exchangeRate: String? = nil,
                             merchant: String = "Test") -> SharedExpense {
        SharedExpense(id: UUID(),
                      spaceID: spaceID,
                      amountMinor: minor,
                      currencyCode: currency,
                      merchant: merchant,
                      category: .other,
                      buildingID: "b1",
                      date: date,
                      note: "",
                      paidBy: paidBy,
                      createdBy: paidBy,
                      updatedBy: paidBy,
                      originalAmount: originalCurrency == nil ? nil : "10.00",
                      originalCurrency: originalCurrency,
                      exchangeRate: exchangeRate,
                      exchangeRateDate: nil)
    }

    private func iso(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string) ?? Date(timeIntervalSince1970: 0)
    }

    /// Mid-month, so a record on a month boundary is unambiguously the wrong month.
    private lazy var now = iso("2026-09-15T10:00:00Z")

    // MARK: - Target isolation

    func testTargetBelongsToItsOwnSpaceOnly() {
        let spaceA = makeSpace(targetMinor: 800_000)
        let spaceB = makeSpace(targetMinor: nil)

        XCTAssertEqual(spaceA.monthlyTarget, 800_000)
        // The central trap: a space with no target must report none. It must never fall
        // back to a personal budget, because that number belongs to a different scope and
        // a different currency.
        XCTAssertNil(spaceB.monthlyTarget)

        let spent: Int64 = 100_00
        XCTAssertTrue(spaceA.progress(spentMinor: spent).hasTarget)
        XCTAssertFalse(spaceB.progress(spentMinor: spent).hasTarget)
        XCTAssertNil(spaceB.progress(spentMinor: spent).fraction)
    }

    func testStoredZeroOrNegativeTargetReadsAsNoTarget() {
        XCTAssertNil(makeSpace(targetMinor: 0).monthlyTarget)
        XCTAssertNil(makeSpace(targetMinor: -5_000).monthlyTarget)
    }

    func testSpaceAProgressIsUnaffectedBySpaceBTarget() {
        let spaceA = makeSpace(targetMinor: 800_000)
        let spaceB = makeSpace(targetMinor: 100_000)
        let progress = spaceA.progress(spentMinor: 200_000)

        XCTAssertEqual(progress.remainingMinor, 600_000)
        XCTAssertEqual(progress.fraction ?? 0, 0.25, accuracy: 0.0001)
        // A different space's target must not leak into this one.
        XCTAssertNotEqual(progress.targetMinor, spaceB.monthlyBudgetMinor)
    }

    // MARK: - Which expenses count

    func testSpentCountsOnlyTheActiveSpace() {
        let spaceA = makeSpace()
        let spaceB = makeSpace()
        let binjamin = makeMember(id: "m1", spaceID: spaceA.id)
        let maya = makeMember(id: "m2", spaceID: spaceB.id)

        let expenses = [
            makeExpense(spaceID: spaceA.id, minor: 300_00, paidBy: "m1", at: now),
            makeExpense(spaceID: spaceB.id, minor: 900_00, paidBy: "m2", at: now)
        ]

        let summary = SharedMonthlySummary.month(of: spaceA, expenses: expenses, members: [binjamin, maya], now: now)

        XCTAssertEqual(summary.spentMinor, 300_00)
        XCTAssertEqual(summary.transactionCount, 1, "Another space's record is not this space's month")
    }

    func testSpentUsesTheSpacesOwnCalendarAndTimeZone() {
        // UTC+14: local month boundaries sit a day away from UTC's, so a host that used
        // Calendar.current would put this record in the wrong month.
        let space = makeSpace(timeZone: "Pacific/Kiritimati")
        let member = makeMember(id: "m1", spaceID: space.id)

        // 2026-09-30T10:30Z is 2026-10-01 00:30 in Kiritimati: October there, September in UTC.
        let belongsToNextMonth = makeExpense(spaceID: space.id, minor: 500_00, paidBy: "m1", at: iso("2026-09-30T10:30:00Z"))
        let belongsToThisMonth = makeExpense(spaceID: space.id, minor: 100_00, paidBy: "m1", at: iso("2026-09-14T10:00:00Z"))

        let summary = SharedMonthlySummary.month(of: space,
                                                expenses: [belongsToNextMonth, belongsToThisMonth],
                                                members: [member],
                                                now: now)

        XCTAssertEqual(summary.spentMinor, 100_00)
        XCTAssertEqual(summary.transactionCount, 1)
    }

    func testUnresolvedForeignIsCountedButNotSummed() {
        let space = makeSpace()
        let member = makeMember(id: "m1", spaceID: space.id)
        let expenses = [
            makeExpense(spaceID: space.id, minor: 100_00, paidBy: "m1", at: now),
            // Foreign original, no rate applied: no honest value in the space's currency.
            makeExpense(spaceID: space.id, minor: 90_00, paidBy: "m1", at: now, originalCurrency: "USD"),
            // Same foreign original, but a rate was applied, so it is real spend.
            makeExpense(spaceID: space.id, minor: 70_00, paidBy: "m1", at: now, originalCurrency: "USD", exchangeRate: "3.5")
        ]

        let summary = SharedMonthlySummary.month(of: space, expenses: expenses, members: [member], now: now)

        XCTAssertEqual(summary.spentMinor, 170_00, "Only money with a known value counts")
        XCTAssertEqual(summary.transactionCount, 3, "The record still exists, so the count reflects it")
        XCTAssertEqual(summary.unresolvedCount, 1)
        XCTAssertEqual(summary.memberTotals.first?.amountMinor, 170_00)
    }

    func testSameCurrencyWithNoRateIsNotUnresolved() {
        let space = makeSpace()
        let member = makeMember(id: "m1", spaceID: space.id)
        let expense = makeExpense(spaceID: space.id, minor: 100_00, paidBy: "m1", at: now, originalCurrency: "ILS")

        let summary = SharedMonthlySummary.month(of: space, expenses: [expense], members: [member], now: now)

        XCTAssertEqual(summary.unresolvedCount, 0)
        XCTAssertEqual(summary.spentMinor, 100_00)
    }

    // MARK: - Refunds

    func testRefundReducesMonthAndTheMemberWhoPaidIt() {
        let space = makeSpace()
        let binjamin = makeMember(id: "m1", spaceID: space.id)
        let maya = makeMember(id: "m2", spaceID: space.id)
        let expenses = [
            makeExpense(spaceID: space.id, minor: 500_00, paidBy: "m1", at: now),
            makeExpense(spaceID: space.id, minor: 200_00, paidBy: "m2", at: now),
            // Maya got ₪80 back, so her net is what she actually put in.
            makeExpense(spaceID: space.id, minor: -80_00, paidBy: "m2", at: now)
        ]

        let summary = SharedMonthlySummary.month(of: space, expenses: expenses, members: [binjamin, maya], now: now)

        XCTAssertEqual(summary.spentMinor, 620_00)
        let totals = Dictionary(uniqueKeysWithValues: summary.memberTotals.map { ($0.memberID, $0.amountMinor) })
        XCTAssertEqual(totals["m1"], 500_00)
        XCTAssertEqual(totals["m2"], 120_00)
    }

    func testRefundLargerThanPaymentKeepsTheRealNegativeNet() {
        let space = makeSpace()
        let maya = makeMember(id: "m2", spaceID: space.id)
        let expenses = [
            makeExpense(spaceID: space.id, minor: 100_00, paidBy: "m2", at: now),
            makeExpense(spaceID: space.id, minor: -150_00, paidBy: "m2", at: now)
        ]

        let summary = SharedMonthlySummary.month(of: space, expenses: expenses, members: [maya], now: now)

        // The ledger says she is net ₪50 down. Clamping at zero would invent a spend that
        // did not happen and would also make remaining target wrong.
        XCTAssertEqual(summary.memberTotals.first?.amountMinor, -50_00)
        XCTAssertEqual(summary.spentMinor, -50_00)
        // A negative month means more of the target is still available, not less.
        XCTAssertEqual(summary.progress.remainingMinor, 805_000)
    }

    // MARK: - Members

    func testMemberWithNoSpendingStillAppearsAtZero() {
        let space = makeSpace()
        let binjamin = makeMember(id: "m1", spaceID: space.id)
        let maya = makeMember(id: "m2", spaceID: space.id)
        let expenses = [makeExpense(spaceID: space.id, minor: 300_00, paidBy: "m1", at: now)]

        let summary = SharedMonthlySummary.month(of: space, expenses: expenses, members: [binjamin, maya], now: now)

        XCTAssertEqual(summary.memberTotals.count, 2, "A member is not hidden for having spent nothing")
        XCTAssertEqual(summary.memberTotals.first { $0.memberID == "m2" }?.amountMinor, 0)
    }

    func testUnknownPayerCountsTowardTheMonthButIsAttributedToNobody() {
        let space = makeSpace()
        let binjamin = makeMember(id: "m1", spaceID: space.id)
        let expenses = [
            makeExpense(spaceID: space.id, minor: 300_00, paidBy: "m1", at: now),
            makeExpense(spaceID: space.id, minor: 120_00, paidBy: "someone-else", at: now)
        ]

        let summary = SharedMonthlySummary.month(of: space, expenses: expenses, members: [binjamin], now: now)

        XCTAssertEqual(summary.spentMinor, 420_00, "The month does not shrink because the payer is unknown")
        XCTAssertEqual(summary.unattributedMinor, 120_00)
        XCTAssertEqual(summary.attributedMinor, 300_00)
        XCTAssertEqual(summary.memberTotals.count, 1)
    }

    /// The demo seed, rebuilt here, so its shape can be asserted rather than eyeballed.
    func testDemoSeedKeepsTheTwoRulesThatAreEasyToBreak() {
        let space = makeSpace(targetMinor: 800_000)
        let me = makeMember(id: "me", spaceID: space.id, name: "אני")
        let maya = makeMember(id: "demo-partner", spaceID: space.id, name: "מאיה", color: "#FF6446")
        var expenses: [SharedExpense] = []
        for index in 0..<18 {
            let payer = index % 3 == 0 ? maya.id : me.id
            expenses.append(makeExpense(spaceID: space.id, minor: Int64(1800 + index * 370), paidBy: payer, at: now))
        }
        expenses.append(makeExpense(spaceID: space.id, minor: -1_200, paidBy: me.id, at: now))
        expenses.append(makeExpense(spaceID: space.id, minor: 4_500, paidBy: maya.id, at: now,
                                    originalCurrency: "USD"))

        let summary = SharedMonthlySummary.month(of: space, expenses: expenses, members: [me, maya], now: now)

        XCTAssertEqual(summary.transactionCount, 20)
        XCTAssertEqual(summary.unresolvedCount, 1)
        let resolvable = expenses.filter { !$0.isUnresolvedForeign }
        let resolvableTotal = resolvable.reduce(Int64(0)) { $0 + $1.amountMinor }
        XCTAssertEqual(summary.spentMinor, resolvableTotal)
        // The unresolved record contributes no money even though it is counted above.
        // Stated as a difference rather than a hardcoded figure so the check keeps working
        // if the seed amounts change.
        let unresolvedSum = expenses.filter(\.isUnresolvedForeign).reduce(Int64(0)) { $0 + $1.amountMinor }
        XCTAssertGreaterThan(unresolvedSum, 0, "The seed must keep a record that proves the rule")
        XCTAssertEqual(summary.spentMinor + unresolvedSum, expenses.reduce(Int64(0)) { $0 + $1.amountMinor })

        // Each member's net must equal their own resolvable records, sign included.
        for member in [me, maya] {
            let expected = resolvable.filter { $0.paidBy == member.id }.reduce(Int64(0)) { $0 + $1.amountMinor }
            XCTAssertEqual(summary.memberTotals.first { $0.memberID == member.id }?.amountMinor, expected)
        }
        // And the two together must reconstruct the month, with nothing lost or invented.
        XCTAssertEqual(summary.attributedMinor, summary.spentMinor)
        XCTAssertEqual(summary.unattributedMinor, 0)
    }

    // MARK: - Snapshot bridging

    /// `ExpenseSnapshot` is what analytics, recap and the city read. It used to hardcode
    /// `isUnresolvedForeign = false` for shared records, so every one of those screens
    /// counted an unconvertible expense as real spend. These pin the bridge to the
    /// record's own answer rather than to a second, drifting copy of the rule.
    func testSnapshotReportsAPlainSharedExpenseAsLocal() {
        let space = makeSpace()
        let snapshot = ExpenseSnapshot(makeExpense(spaceID: space.id, minor: 100_00, paidBy: "m1", at: now))
        XCTAssertFalse(snapshot.isUnresolvedForeign)
    }

    func testSnapshotReportsAForeignSharedExpenseWithNoRateAsUnresolved() {
        let space = makeSpace()
        let expense = makeExpense(spaceID: space.id, minor: 90_00, paidBy: "m1", at: now, originalCurrency: "USD")
        XCTAssertTrue(expense.isUnresolvedForeign, "The record should know it is unconvertible")
        XCTAssertTrue(ExpenseSnapshot(expense).isUnresolvedForeign, "And the snapshot must not lose that")
    }

    func testSnapshotReportsAForeignSharedExpenseWithARateAsResolved() {
        let space = makeSpace()
        let expense = makeExpense(spaceID: space.id, minor: 70_00, paidBy: "m1", at: now,
                                  originalCurrency: "USD", exchangeRate: "3.5")
        XCTAssertFalse(expense.isUnresolvedForeign)
        XCTAssertFalse(ExpenseSnapshot(expense).isUnresolvedForeign)
    }

    /// The bridge must not touch the personal path, which reads `Transaction` and keeps
    /// its own rule. Only the money is compared here, to prove nothing shifted.
    func testPersonalSnapshotIsUnaffectedByTheSharedBridge() {
        let inMemory = try! makePersonalContainer()
        let context = ModelContext(inMemory)
        let local = Transaction(amount: 100, currency: "₪", merchant: "קפה", category: .food,
                                timestamp: now, buildingId: "food_coffee")
        let foreignUnresolved = Transaction(amount: 90, currency: "₪", merchant: "טיסה", category: .food,
                                           timestamp: now, buildingId: "transport_air",
                                           originalAmount: 120, originalCurrency: "USD", exchangeRate: nil)
        let foreignResolved = Transaction(amount: 70, currency: "₪", merchant: "טיסה", category: .food,
                                          timestamp: now, buildingId: "transport_air",
                                          originalAmount: 120, originalCurrency: "USD", exchangeRate: 3.5)
        context.insert(local); context.insert(foreignUnresolved); context.insert(foreignResolved)
        try! context.save()

        XCTAssertFalse(ExpenseSnapshot(local).isUnresolvedForeign)
        XCTAssertFalse(ExpenseSnapshot(foreignResolved).isUnresolvedForeign)
        // A personal foreign expense still keeps its original amount visible, so the
        // bridging change did not cost the "revert foreign" affordance.
        XCTAssertTrue(ExpenseSnapshot(foreignUnresolved).canRevertForeign)

        // The personal rule measures against the *personal base currency*, read from
        // defaults, and a foreign record only counts as unresolved when its own
        // `currency` is not that base. A record already filed under the base currency with
        // a foreign original is therefore not "unresolved" by definition — it is a
        // converted figure waiting for its rate. Stating it explicitly: this asserts the
        // personal path is untouched, not that the personal rule matches the shared one.
        let baseCode = UserDefaults.standard.string(forKey: "app_currency_pref") ?? "ILS"
        let baseSymbol = CurrencyType(rawValue: baseCode).symbol
        let personalUnresolved = Transaction(amount: 90, currency: "$", merchant: "טיסה", category: .food,
                                             timestamp: now, buildingId: "transport_air",
                                             originalAmount: 90, originalCurrency: "USD", exchangeRate: nil)
        let expected = baseSymbol != "$" && baseCode != "USD"
        XCTAssertEqual(ExpenseSnapshot(personalUnresolved).isUnresolvedForeign, expected)
    }

    private func makePersonalContainer() throws -> ModelContainer {
        let schema = Schema([Transaction.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testLeftMemberIsStillAMemberOfTheMonthTheyPaidIn() {
        let space = makeSpace()
        let binjamin = makeMember(id: "m1", spaceID: space.id, name: "בנימין")
        let gone = makeMember(id: "m2", spaceID: space.id, name: "עזב", active: false)
        let expenses = [makeExpense(spaceID: space.id, minor: 300_00, paidBy: "m2", at: now)]

        let summary = SharedMonthlySummary.month(of: space, expenses: expenses, members: [binjamin, gone], now: now)

        XCTAssertEqual(summary.memberTotals.map(\.memberID), ["m1", "m2"])
        XCTAssertEqual(summary.memberTotals.first { $0.memberID == "m2" }?.amountMinor, 300_00)
        XCTAssertEqual(summary.spentMinor, 300_00)
        XCTAssertEqual(summary.unattributedMinor, 0,
                       "A former member's spend is never given to someone else, and never given to nobody")
    }

    func testMemberColorsAndNamesComeFromTheSpaceNotTheView() {
        let space = makeSpace()
        let binjamin = makeMember(id: "m1", spaceID: space.id, name: "בנימין", color: "#7C5CFF")
        let maya = makeMember(id: "m2", spaceID: space.id, name: "מאיה", color: "#FF8A3D")
        let expenses = [
            makeExpense(spaceID: space.id, minor: 300_00, paidBy: "m1", at: now),
            makeExpense(spaceID: space.id, minor: 200_00, paidBy: "m2", at: now)
        ]

        let summary = SharedMonthlySummary.month(of: space, expenses: expenses, members: [binjamin, maya], now: now)

        XCTAssertEqual(summary.memberTotals.first { $0.memberID == "m1" }?.colorHex, "#7C5CFF")
        XCTAssertEqual(summary.memberTotals.first { $0.memberID == "m2" }?.name, "מאיה")
    }

    // MARK: - Progress

    func testProgressBelowExactAndAboveTarget() {
        let target: Int64 = 800_000

        let below = makeSpace(targetMinor: target).progress(spentMinor: 400_000)
        XCTAssertEqual(below.fraction ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(below.remainingMinor, 400_000)
        XCTAssertFalse(below.isOverTarget)

        let exact = makeSpace(targetMinor: target).progress(spentMinor: target)
        XCTAssertEqual(exact.fraction ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(exact.remainingMinor, 0)
        XCTAssertFalse(exact.isOverTarget)

        let above = makeSpace(targetMinor: target).progress(spentMinor: 944_000)
        // Uncapped on purpose: the business value is 1.18 and the bar clamps, not this.
        XCTAssertEqual(above.fraction ?? 0, 1.18, accuracy: 0.0001)
        XCTAssertEqual(above.remainingMinor, -144_000)
        XCTAssertTrue(above.isOverTarget)
    }

    func testEmptyMonthWithATarget() {
        let space = makeSpace(targetMinor: 800_000)
        let member = makeMember(id: "m1", spaceID: space.id)

        let summary = SharedMonthlySummary.month(of: space, expenses: [], members: [member], now: now)

        XCTAssertEqual(summary.spentMinor, 0)
        XCTAssertEqual(summary.transactionCount, 0)
        XCTAssertEqual(summary.progress.remainingMinor, 800_000)
        XCTAssertEqual(summary.memberTotals.first?.amountMinor, 0)
    }

    func testEmptyMonthWithoutATargetReportsNoNumbers() {
        let space = makeSpace(targetMinor: nil)
        let member = makeMember(id: "m1", spaceID: space.id)

        let summary = SharedMonthlySummary.month(of: space, expenses: [], members: [member], now: now)

        XCTAssertFalse(summary.progress.hasTarget)
        XCTAssertNil(summary.progress.remainingMinor)
        XCTAssertNil(summary.progress.fraction, "No target means no 0% bar pretending to be progress")
    }
}

// MARK: - Who a month happened to

/// A month is made of the people who took part in it, which is not the same list as the
/// people in the space today. Somebody who paid and then left still happened to that month:
/// their spending, their name and their colour are history, and history is not membership.
@MainActor
final class SharedMemberHistoryTests: XCTestCase {

    private func makeSpace(id: UUID = UUID(), targetMinor: Int64? = 1_000_00) -> SharedSpace {
        SharedSpace(id: id, name: "s", currencyCode: "ILS", timeZoneID: "UTC",
                    mapStyle: "urban", createdAt: Date(), monthlyBudgetMinor: targetMinor)
    }

    private func makeMember(id: String, spaceID: UUID, name: String = "m",
                            color: String = "#7C5CFF", active: Bool = true) -> SharedMember {
        SharedMember(id: id, spaceID: spaceID, name: name, colorHex: color, isActive: active)
    }

    private func makeExpense(spaceID: UUID, minor: Int64, paidBy: String, at date: Date) -> SharedExpense {
        SharedExpense(id: UUID(), spaceID: spaceID, amountMinor: minor, currencyCode: "ILS",
                      merchant: "T", category: .food, buildingID: "food_bistro", date: date, note: "",
                      paidBy: paidBy, createdBy: paidBy, updatedBy: paidBy)
    }

    private static func month(_ iso: String) -> Date {
        var comps = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month], from: ISO8601DateFormatter().date(from: iso) ?? Date())
        comps.day = 15
        comps.hour = 10
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private let september = SharedMemberHistoryTests.month("2026-09-15T10:00:00Z")
    private let august = SharedMemberHistoryTests.month("2026-08-15T10:00:00Z")

    // MARK: The rule

    func testActiveMemberWithSpendIsAttributed() {
        let space = makeSpace()
        let me = makeMember(id: "a", spaceID: space.id, name: "אני")
        let summary = SharedMonthlySummary.month(of: space,
            expenses: [makeExpense(spaceID: space.id, minor: 400_00, paidBy: "a", at: september)],
            members: [me], now: september)
        XCTAssertEqual(summary.memberTotals.map(\.memberID), ["a"])
        XCTAssertEqual(summary.memberTotals.first?.amountMinor, 400_00)
        XCTAssertEqual(summary.unattributedMinor, 0)
    }

    func testActiveMemberWithNothingStillAppearsWithZero() {
        let space = makeSpace()
        let me = makeMember(id: "a", spaceID: space.id)
        let idle = makeMember(id: "b", spaceID: space.id)
        let summary = SharedMonthlySummary.month(of: space,
            expenses: [makeExpense(spaceID: space.id, minor: 400_00, paidBy: "a", at: september)],
            members: [me, idle], now: september)
        XCTAssertEqual(summary.memberTotals.first { $0.memberID == "b" }?.amountMinor, 0,
                       "Being in the space is being in the month")
    }

    func testInactiveMemberWithSpendKeepsTheirNameColourAndAmount() {
        let space = makeSpace()
        let here = makeMember(id: "a", spaceID: space.id)
        let leaver = makeMember(id: "b", spaceID: space.id, name: "מאיה", color: "#FF6446", active: false)
        let summary = SharedMonthlySummary.month(of: space,
            expenses: [makeExpense(spaceID: space.id, minor: 900_00, paidBy: "b", at: september)],
            members: [here, leaver], now: september)
        let kept = summary.memberTotals.first { $0.memberID == "b" }
        XCTAssertEqual(kept?.name, "מאיה", "The month remembers who they were")
        XCTAssertEqual(kept?.colorHex, "#FF6446", "And in which colour")
        XCTAssertEqual(kept?.amountMinor, 900_00)
        XCTAssertEqual(summary.unattributedMinor, 0, "Leaving is not a reason for their money to belong to nobody")
        XCTAssertTrue(summary.canShowMemberShares,
                      "One person leaving must not switch off the breakdown for everybody else")
    }

    func testInactiveMemberRefundStaysAttributedToThemAndReducesTheirNet() {
        let space = makeSpace()
        let leaver = makeMember(id: "b", spaceID: space.id, active: false)
        let summary = SharedMonthlySummary.month(of: space,
            expenses: [makeExpense(spaceID: space.id, minor: 1_000_00, paidBy: "b", at: september),
                       makeExpense(spaceID: space.id, minor: -300_00, paidBy: "b", at: september)],
            members: [leaver], now: september)
        XCTAssertEqual(summary.memberTotals.first?.amountMinor, 700_00)
        XCTAssertEqual(summary.unattributedMinor, 0)
        XCTAssertEqual(summary.spentMinor, 700_00)
    }

    func testInactiveMemberWithNothingInTheMonthIsLeftOutOfIt() {
        let space = makeSpace()
        let me = makeMember(id: "a", spaceID: space.id)
        let leaver = makeMember(id: "b", spaceID: space.id, active: false)
        let summary = SharedMonthlySummary.month(of: space,
            expenses: [makeExpense(spaceID: space.id, minor: 100_00, paidBy: "a", at: september)],
            members: [me, leaver], now: september)
        XCTAssertEqual(summary.memberTotals.map(\.memberID), ["a"],
                       "A month they had no part in is not a month they appear in")
    }

    func testAMemberInactiveTodayStillAppearsInTheMonthTheyActuallyPaidIn() {
        let space = makeSpace()
        let leaver = makeMember(id: "b", spaceID: space.id, name: "מאיה", active: false)
        let expenses = [makeExpense(spaceID: space.id, minor: 500_00, paidBy: "b", at: august),
                        makeExpense(spaceID: space.id, minor: 700_00, paidBy: "ghost", at: september)]

        let lastMonth = SharedMonthlySummary.month(of: space, expenses: expenses, members: [leaver], now: august)
        XCTAssertEqual(lastMonth.memberTotals.map(\.memberID), ["b"],
                       "Analytics browsing August must still see who paid for it")
        XCTAssertEqual(lastMonth.memberTotals.first?.amountMinor, 500_00)

        let thisMonth = SharedMonthlySummary.month(of: space, expenses: expenses, members: [leaver], now: september)
        XCTAssertTrue(thisMonth.memberTotals.isEmpty, "September is not theirs either, they paid nothing in it")
        XCTAssertEqual(thisMonth.spentMinor, 700_00, "The record is still counted, whoever paid it")
        XCTAssertEqual(thisMonth.unattributedMinor, 700_00,
                       "A payer with no member record at all is honestly unattributed rather than invented")
    }

    func testTrulyUnknownPayerIsStillUnattributed() {
        let space = makeSpace()
        let me = makeMember(id: "a", spaceID: space.id)
        let summary = SharedMonthlySummary.month(of: space,
            expenses: [makeExpense(spaceID: space.id, minor: 100_00, paidBy: "a", at: september),
                       makeExpense(spaceID: space.id, minor: 250_00, paidBy: "ghost", at: september)],
            members: [me], now: september)
        XCTAssertEqual(summary.unattributedMinor, 250_00,
                       "A payer with no member record at all has no name and no colour to be given")
        XCTAssertEqual(summary.memberTotals.map(\.memberID), ["a"])
        XCTAssertFalse(summary.canShowMemberShares)
    }

    func testOneRecordForOnePersonIsOneRow() {
        let space = makeSpace()
        let doubled = [makeMember(id: "a", spaceID: space.id), makeMember(id: "a", spaceID: space.id)]
        let summary = SharedMonthlySummary.month(of: space,
            expenses: [makeExpense(spaceID: space.id, minor: 100_00, paidBy: "a", at: september)],
            members: doubled, now: september)
        XCTAssertEqual(summary.memberTotals.count, 1, "Two records for one person must not double their spending")
        XCTAssertEqual(summary.memberTotals.first?.amountMinor, 100_00)
    }

    func testAnotherSpacesMembersAreNeverParticipants() {
        let mine = makeSpace()
        let theirs = makeSpace()
        let stranger = makeMember(id: "x", spaceID: theirs.id)
        let summary = SharedMonthlySummary.month(of: mine,
            expenses: [makeExpense(spaceID: mine.id, minor: 100_00, paidBy: "x", at: september)],
            members: [stranger], now: september)
        XCTAssertTrue(summary.memberTotals.isEmpty)
        XCTAssertEqual(summary.unattributedMinor, 100_00)
    }

    // MARK: History is not membership

    func testALeaverKeepsNoPermissionsAndNoPlaceInThePayerList() async throws {
        let space = makeSpace()
        let me = makeMember(id: "a", spaceID: space.id, name: "אני")
        let leaver = makeMember(id: "b", spaceID: space.id, name: "מאיה", color: "#FF6446", active: false)
        let members = [me, leaver]
        let expenses = [makeExpense(spaceID: space.id, minor: 900_00, paidBy: "b", at: august)]

        // History is reported...
        let summary = SharedMonthlySummary.month(of: space, expenses: expenses, members: members, now: august)
        XCTAssertEqual(summary.memberTotals.map(\.memberID), ["a", "b"])
        let theirRow = summary.memberTotals.first { $0.memberID == "b" }
        XCTAssertEqual(theirRow?.name, "מאיה")
        XCTAssertEqual(theirRow?.colorHex, "#FF6446")
        XCTAssertEqual(theirRow?.amountMinor, 900_00)

        // ...and the payer list is built from membership, which never moved. This is the
        // same filter the quick add sheet applies when it offers payers.
        let payers = members.filter { $0.spaceID == space.id && $0.isActive }
        XCTAssertEqual(payers.map(\.id), ["a"], "A leaver is not somebody you can pay as")
        XCTAssertFalse(leaver.isActive, "And reporting their month does not reactivate them")

        // Nor does it change what the scope is allowed to do. Capabilities are the app's
        // own answer to may this scope write, pick payers, manage members, and a month
        // being summarised must not move a single one of them.
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        let scope = AppScopeContext(store: store)
        let before = scope.capabilities
        _ = scope.sharedMonthSummary(for: Date())
        _ = SharedMonthlySummary.month(of: space, expenses: expenses, members: members, now: september)
        XCTAssertEqual(scope.capabilities, before, "Reading history grants nothing")
    }
}
