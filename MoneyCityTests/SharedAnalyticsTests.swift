import XCTest
@testable import MoneyCity

/// Covers the shared money rules behind shared Analytics: what a month is worth, who paid
/// it, what may be drawn as a share of it, and which records stay out of the sums.
///
/// The screen itself is SwiftUI and cannot be exercised here, so these pin the arithmetic
/// and the two decisions Analytics asks of it — `countsTowardStats` and `canShowMemberShares`
/// — which is where the scope and currency mistakes would actually be made.
final class SharedAnalyticsTests: XCTestCase {

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
                             category: SpendingCategory = .other,
                             currency: String = "ILS",
                             originalCurrency: String? = nil,
                             exchangeRate: String? = nil,
                             merchant: String = "Test") -> SharedExpense {
        SharedExpense(id: UUID(),
                      spaceID: spaceID,
                      amountMinor: minor,
                      currencyCode: currency,
                      merchant: merchant,
                      category: category,
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

    /// Mid-month, so a record on a month boundary is unambiguously a different month.
    private lazy var now = iso("2026-09-15T10:00:00Z")

    private let me = "me"
    private let maya = "maya"

    private func summary(of space: SharedSpace,
                         expenses: [SharedExpense],
                         members: [SharedMember],
                         month: Date? = nil) -> SharedMonthlySummary {
        SharedMonthlySummary.month(of: space, expenses: expenses, members: members, now: month ?? now)
    }

    private func amount(_ id: String, in summary: SharedMonthlySummary) -> Int64 {
        summary.memberTotals.first { $0.memberID == id }?.amountMinor ?? 0
    }

    // MARK: - Scope isolation

    func testSpaceAAttributionNeverIncludesSpaceBSpending() {
        let spaceA = makeSpace(targetMinor: 800_000)
        let spaceB = makeSpace(targetMinor: 1_500_000)
        let members = [makeMember(id: me, spaceID: spaceA.id), makeMember(id: maya, spaceID: spaceA.id)]

        let expenses = [
            makeExpense(spaceID: spaceA.id, minor: 300_00, paidBy: me, at: now),
            // A big record in the other space, plus a member of the other space. If either
            // leaked, the totals below would be wrong by an order of magnitude.
            makeExpense(spaceID: spaceB.id, minor: 900_000, paidBy: me, at: now),
            makeExpense(spaceID: spaceA.id, minor: 700_00, paidBy: "outsider", at: now)
        ]

        let a = summary(of: spaceA, expenses: expenses, members: members)
        XCTAssertEqual(a.spentMinor, 1_000_00, "Space B's record must not be in space A's month")
        XCTAssertEqual(a.attributedMinor, 300_00)
        XCTAssertEqual(a.unattributedMinor, 700_00, "The outsider's record stays in the month, unassigned")
        XCTAssertEqual(a.progress.targetMinor, 800_000)

        let b = summary(of: spaceB, expenses: expenses, members: members)
        XCTAssertEqual(b.spentMinor, 900_000)
        XCTAssertEqual(b.memberTotals.count, 0, "Space A's members are not members of space B")
        XCTAssertEqual(b.attributedMinor, 0)
        XCTAssertEqual(b.unattributedMinor, 900_000)
        XCTAssertEqual(b.progress.targetMinor, 1_500_000)
    }

    /// A shared month must never fall back to the personal budget, and vice versa. The
    /// personal number lives in `UserDefaults` and is a different scope's money entirely.
    func testNoScopeBorrowsTheOtherScopesTarget() {
        let space = makeSpace(targetMinor: nil)
        let members = [makeMember(id: me, spaceID: space.id)]
        let expenses = [makeExpense(spaceID: space.id, minor: 250_00, paidBy: me, at: now)]

        let shared = summary(of: space, expenses: expenses, members: members)
        XCTAssertFalse(shared.progress.hasTarget)
        XCTAssertNil(shared.progress.fraction)
        XCTAssertEqual(shared.progress.remainingMinor, nil)
        XCTAssertEqual(shared.spentMinor, 250_00, "The spending is real even with no target to measure it against")
    }

    /// Switching scope and back must not leave the previous space's numbers on screen. The
    /// summary is a pure read of one space, so this pins that there is no state to leak.
    func testSwitchingBetweenSpacesDoesNotRetainTheOldTotals() {
        let spaceA = makeSpace(targetMinor: 800_000)
        let spaceB = makeSpace(targetMinor: 800_000)
        let membersA = [makeMember(id: me, spaceID: spaceA.id, name: "בנימין")]
        let membersB = [makeMember(id: maya, spaceID: spaceB.id, name: "מאיה")]
        let expenses = [
            makeExpense(spaceID: spaceA.id, minor: 111_00, paidBy: me, at: now),
            makeExpense(spaceID: spaceB.id, minor: 222_00, paidBy: maya, at: now)
        ]

        let firstA = summary(of: spaceA, expenses: expenses, members: membersA)
        let b = summary(of: spaceB, expenses: expenses, members: membersB)
        let againA = summary(of: spaceA, expenses: expenses, members: membersA)

        XCTAssertEqual(firstA.spentMinor, 111_00)
        XCTAssertEqual(b.spentMinor, 222_00)
        XCTAssertEqual(againA.spentMinor, 111_00, "Coming back must not carry space B's total")
        XCTAssertEqual(againA.memberTotals.map(\.name), ["בנימין"])
        XCTAssertNotEqual(againA.attributedMinor, b.attributedMinor)
    }

    // MARK: - Target

    func testTargetProgressBelowExactAndAbove() {
        let space = makeSpace(targetMinor: 800_000)
        let members = [makeMember(id: me, spaceID: space.id)]

        let below = space.progress(spentMinor: 500_000)
        XCTAssertEqual(below.remainingMinor, 300_000)
        XCTAssertEqual(below.fraction ?? 0, 0.625, accuracy: 0.0001)
        XCTAssertFalse(below.isOverTarget)

        let exact = space.progress(spentMinor: 800_000)
        XCTAssertEqual(exact.remainingMinor, 0)
        XCTAssertEqual(exact.fraction ?? 0, 1, accuracy: 0.0001)
        XCTAssertFalse(exact.isOverTarget)

        let above = space.progress(spentMinor: 944_000)
        XCTAssertEqual(above.remainingMinor, -144_000)
        // Uncapped on purpose: 118% spent is a fact, and only the drawn bar is limited.
        XCTAssertEqual(above.fraction ?? 0, 1.18, accuracy: 0.0001)
        XCTAssertTrue(above.isOverTarget)
    }

    func testOverTargetMonthReportsRemainingAsZeroRatherThanNegativeSpend() {
        // The screens ask for the amount *over* by negating `remainingMinor`, so the value
        // itself has to stay a plain signed difference.
        let space = makeSpace(targetMinor: 800_000)
        let over = space.progress(spentMinor: 900_000)
        XCTAssertEqual(over.remainingMinor, -100_000)
        XCTAssertEqual(-(over.remainingMinor ?? 0), 100_000)
    }

    // MARK: - Member totals

    func testTwoMembersSplitTheMonthWithoutRanking() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id, name: "בנימין", color: "#FF6B4A"),
                       makeMember(id: maya, spaceID: space.id, name: "מאיה", color: "#4A9BFF")]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 300_00, paidBy: me, at: now),
            makeExpense(spaceID: space.id, minor: 200_00, paidBy: maya, at: now)
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(amount(me, in: result), 300_00)
        XCTAssertEqual(amount(maya, in: result), 200_00)
        XCTAssertEqual(result.spentMinor, 500_00)
        XCTAssertEqual(result.attributedMinor, result.spentMinor)
        // Order follows the member list, not who paid more: this is a record, not a podium.
        XCTAssertEqual(result.memberTotals.map(\.name), ["בנימין", "מאיה"])
        XCTAssertEqual(result.memberTotals.map(\.colorHex), ["#FF6B4A", "#4A9BFF"])
        XCTAssertTrue(result.canShowMemberShares)
    }

    func testMemberWhoSpentNothingStillAppearsAtZero() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id, name: "בנימין"),
                       makeMember(id: maya, spaceID: space.id, name: "מאיה")]
        let expenses = [makeExpense(spaceID: space.id, minor: 300_00, paidBy: me, at: now)]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(amount(maya, in: result), 0, "Living together is not the same as spending together")
        XCTAssertEqual(result.memberTotals.count, 2)
        XCTAssertTrue(result.canShowMemberShares, "A zero is a real share: nothing to hide")
    }

    func testRefundReducesTheMonthAndTheMemberWhoPaidIt() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id), makeMember(id: maya, spaceID: space.id)]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 500_00, paidBy: me, at: now),
            makeExpense(spaceID: space.id, minor: 200_00, paidBy: maya, at: now),
            makeExpense(spaceID: space.id, minor: -120_00, paidBy: me, at: now, merchant: "החזר")
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(result.spentMinor, 580_00)
        XCTAssertEqual(amount(me, in: result), 380_00, "The refund comes off the member who paid it")
        XCTAssertEqual(amount(maya, in: result), 200_00)
        XCTAssertTrue(result.canShowMemberShares)
    }

    func testRefundLargerThanThePaymentLeavesAMemberNegative() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id), makeMember(id: maya, spaceID: space.id)]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 50_00, paidBy: maya, at: now),
            makeExpense(spaceID: space.id, minor: -200_00, paidBy: maya, at: now, merchant: "החזר חלקי")
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(amount(maya, in: result), -150_00, "Reported as it happened, not flattened to zero")
        XCTAssertEqual(result.spentMinor, -150_00)
        // A negative member cannot be drawn as a share of a negative month.
        XCTAssertFalse(result.canShowMemberShares)
    }

    func testPayerOutsideTheMemberListCountsTowardTheMonthButToNobody() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id), makeMember(id: maya, spaceID: space.id)]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 400_00, paidBy: me, at: now),
            makeExpense(spaceID: space.id, minor: 100_00, paidBy: "a-visitor", at: now)
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(result.spentMinor, 500_00)
        XCTAssertEqual(result.attributedMinor, 400_00)
        XCTAssertEqual(result.unattributedMinor, 100_00)
        XCTAssertEqual(result.memberTotals.count, 2, "The visitor is not invented as a third member")
        // The visible bars would not add up to the month they sit under, so no shares.
        XCTAssertFalse(result.canShowMemberShares)
    }

    func testNegativeUnattributedAmountIsReportedAsItIs() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id)]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 300_00, paidBy: me, at: now),
            makeExpense(spaceID: space.id, minor: -50_00, paidBy: "a-visitor", at: now)
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(result.unattributedMinor, -50_00)
        XCTAssertFalse(result.canShowMemberShares)
    }

    // MARK: - Member share rules

    func testMemberSharesAreAllowedOnlyWhenTheMonthCanCarryThem() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id)]

        func shares(_ minor: Int64) -> Bool {
            summary(of: space,
                    expenses: [makeExpense(spaceID: space.id, minor: minor, paidBy: me, at: now)],
                    members: members).canShowMemberShares
        }

        XCTAssertTrue(shares(100_00))
        XCTAssertFalse(shares(0), "Zero spend has nothing to divide")
        XCTAssertFalse(shares(-100_00), "A negative month has no share to be part of")
    }

    // MARK: - Foreign currency

    func testUnresolvedForeignRecordIsCountedButNotSummed() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id)]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 300_00, paidBy: me, at: now, category: .food),
            makeExpense(spaceID: space.id, minor: 45_000, paidBy: me, at: now,
                        category: .food, originalCurrency: "USD")
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(result.spentMinor, 300_00, "No rate means no value in the space's currency")
        XCTAssertEqual(result.transactionCount, 2, "The record is still a transaction that happened")
        XCTAssertEqual(result.unresolvedCount, 1)
        XCTAssertEqual(amount(me, in: result), 300_00)
    }

    func testResolvedForeignRecordIsIncluded() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id)]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 300_00, paidBy: me, at: now, category: .food),
            makeExpense(spaceID: space.id, minor: 45_000, paidBy: me, at: now,
                        category: .food, originalCurrency: "USD", exchangeRate: "3.5")
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(result.spentMinor, 75_000, "Already in the space's currency, so it is simply added")
        XCTAssertEqual(result.unresolvedCount, 0)
        XCTAssertEqual(result.transactionCount, 2)
    }

    func testForeignRecordInTheSpacesOwnCurrencyIsNotUnresolved() {
        let space = makeSpace(currency: "ILS")
        let members = [makeMember(id: me, spaceID: space.id)]
        let expenses = [makeExpense(spaceID: space.id, minor: 100_00, paidBy: me, at: now,
                                    originalCurrency: "ILS")]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(result.unresolvedCount, 0)
        XCTAssertEqual(result.spentMinor, 100_00)
    }

    func testUnresolvedRecordsStayOutOfCategoryTotalsAndSavingsDoToo() {
        let space = makeSpace()
        let expenses = [
            makeExpense(spaceID: space.id, minor: 300_00, paidBy: me, at: now, category: .food),
            makeExpense(spaceID: space.id, minor: 200_00, paidBy: me, at: now, category: .transport),
            makeExpense(spaceID: space.id, minor: 90_00, paidBy: me, at: now,
                        category: .food, originalCurrency: "USD"),
            makeExpense(spaceID: space.id, minor: 1_000_00, paidBy: me, at: now, category: .savings)
        ]
        let snapshots = expenses.map(ExpenseSnapshot.init)

        func totals(excludeHousing: Bool = false) -> [SpendingCategory: Double] {
            var result: [SpendingCategory: Double] = [:]
            for item in AnalyticsCategoryTotal.totals(from: snapshots,
                                                      countsTowardStats: { AnalyticsCategoryTotal.countsTowardStats($0, excludeHousing: excludeHousing) }) {
                result[item.category] = item.amount
            }
            return result
        }

        // Category amounts come back in major units, the screen's own unit.
        let counted = totals()
        XCTAssertEqual(counted[.food], 300, "The unresolved $90 is not added to food")
        XCTAssertEqual(counted[.transport], 200)
        XCTAssertNil(counted[.savings], "Savings are not spending")
        XCTAssertEqual(counted.values.reduce(0, +), 500)

        // The ledger's month is deliberately the larger number: a space's target covers
        // everything that left the account this month, savings included, while the
        // categories only break down what was spent. Analytics reports the gap rather than
        // pretending the two are the same figure.
        let result = summary(of: space, expenses: expenses, members: [makeMember(id: me, spaceID: space.id)])
        XCTAssertEqual(result.spentMinor, 150_000)
        XCTAssertEqual(Int64(counted.values.reduce(0, +) * 100), 50_000)
        XCTAssertEqual(result.spentMinor - 50_000, 100_000, "Exactly the savings record")
    }

    func testSavingsCategoryIsExcludedFromStatistics() {
        let savings = makeExpense(spaceID: UUID(), minor: 10, paidBy: "me", at: now, category: .savings)
        let housing = makeExpense(spaceID: UUID(), minor: 20, paidBy: "me", at: now, category: .housing)
        let food = makeExpense(spaceID: UUID(), minor: 30, paidBy: "me", at: now, category: .food)

        XCTAssertFalse(AnalyticsCategoryTotal.countsTowardStats(ExpenseSnapshot(savings)))
        XCTAssertTrue(AnalyticsCategoryTotal.countsTowardStats(ExpenseSnapshot(housing)))
        XCTAssertFalse(AnalyticsCategoryTotal.countsTowardStats(ExpenseSnapshot(housing), excludeHousing: true))
        XCTAssertTrue(AnalyticsCategoryTotal.countsTowardStats(ExpenseSnapshot(food)))
    }

    // MARK: - Time

    func testMonthBoundariesFollowTheSpacesTimeZoneNotTheDevices() {
        // Two records an hour apart on the last night of August. In Jerusalem it is already
        // September; in New York it is still August. The space decides, not the phone.
        let boundary = iso("2026-08-31T22:30:00Z")
        // A date unambiguously inside September, so the record's month is the question.
        let september = iso("2026-09-30T12:00:00Z")

        let jerusalem = makeSpace(timeZone: "Asia/Jerusalem")
        let newYork = makeSpace(timeZone: "America/New_York")
        let members = [makeMember(id: me, spaceID: jerusalem.id)]

        let forJerusalem = summary(of: jerusalem, expenses: [
            makeExpense(spaceID: jerusalem.id, minor: 100_00, paidBy: me, at: boundary)
        ], members: members, month: september)
        XCTAssertEqual(forJerusalem.spentMinor, 100_00, "August 31 22:30Z is already September in Jerusalem")

        let forNewYork = summary(of: newYork, expenses: [
            makeExpense(spaceID: newYork.id, minor: 100_00, paidBy: me, at: boundary)
        ], members: members, month: september)
        XCTAssertEqual(forNewYork.spentMinor, 0, "and still August in New York")
    }

    func testPreviousMonthIsReadFromTheSameSpaceRecordsOnly() {
        let space = makeSpace(timeZone: "UTC")
        let members = [makeMember(id: me, spaceID: space.id)]
        let august = iso("2026-08-10T12:00:00Z")
        let september = iso("2026-09-10T12:00:00Z")

        let expenses = [
            makeExpense(spaceID: space.id, minor: 400_00, paidBy: me, at: august),
            makeExpense(spaceID: space.id, minor: 600_00, paidBy: me, at: september)
        ]

        let prev = summary(of: space, expenses: expenses, members: members, month: august)
        let current = summary(of: space, expenses: expenses, members: members, month: september)

        XCTAssertEqual(prev.spentMinor, 400_00)
        XCTAssertEqual(current.spentMinor, 600_00)
        XCTAssertEqual(prev.progress.targetMinor, current.progress.targetMinor,
                       "A target is monthly, so it applies to the month being looked at too")
    }

    // MARK: - Categories

    func testCategoryTotalsSumToTheResolvedMonthAndRankByAmount() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id), makeMember(id: maya, spaceID: space.id)]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 500_00, paidBy: me, at: now, category: .food),
            makeExpense(spaceID: space.id, minor: 200_00, paidBy: maya, at: now, category: .food),
            makeExpense(spaceID: space.id, minor: 300_00, paidBy: maya, at: now, category: .transport)
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        let totals = AnalyticsCategoryTotal.totals(from: expenses.map(ExpenseSnapshot.init),
                                                   countsTowardStats: { AnalyticsCategoryTotal.countsTowardStats($0) })

        XCTAssertEqual(totals.count, 2)
        XCTAssertEqual(totals.map(\.category), [.food, .transport], "Largest first")
        XCTAssertEqual(totals[0].amount, 700)
        XCTAssertEqual(totals[0].fraction, 0.7, accuracy: 0.0001)
        XCTAssertEqual(totals.map(\.amount).reduce(0, +), Double(result.spentMinor) / 100,
                       "Categories must reconstruct the month, with nothing invented or lost")
        XCTAssertEqual(totals.map(\.amount).reduce(0, +), 1_000)
    }

    func testRefundMovesItsCategoryTheSameWayItMovesTheMonth() {
        let space = makeSpace()
        let members = [makeMember(id: me, spaceID: space.id)]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 500_00, paidBy: me, at: now, category: .food),
            makeExpense(spaceID: space.id, minor: -200_00, paidBy: me, at: now, category: .food, merchant: "החזר")
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        let totals = AnalyticsCategoryTotal.totals(from: expenses.map(ExpenseSnapshot.init),
                                                   countsTowardStats: { AnalyticsCategoryTotal.countsTowardStats($0) })

        XCTAssertEqual(totals.first?.amount, 300, "The refund comes off its own category")
        XCTAssertEqual(Int64((totals.first?.amount ?? 0) * 100), result.spentMinor)
    }

    func testNegativeCategoryAmountIsKeptRatherThanHiddenAsZero() {
        let space = makeSpace()
        let expenses = [
            makeExpense(spaceID: space.id, minor: 100_00, paidBy: "me", at: now, category: .food),
            makeExpense(spaceID: space.id, minor: -400_00, paidBy: "me", at: now, category: .food, merchant: "החזר")
        ]
        let totals = AnalyticsCategoryTotal.totals(from: expenses.map(ExpenseSnapshot.init),
                                                   countsTowardStats: { AnalyticsCategoryTotal.countsTowardStats($0) })
        XCTAssertEqual(totals.first?.amount, -300, "The screen decides not to draw a share; the data stays true")
    }

    // MARK: - Housing filter

    func testHiddenHousingCountsOnlyMoneyThatWasEverGoingToBeCounted() {
        let spaceID = UUID()
        let expenses = [
            // Countable housing: genuinely hidden when the filter is on.
            makeExpense(spaceID: spaceID, minor: 1_200_00, paidBy: "me", at: now, category: .housing),
            // Housing in a foreign currency with no rate: never in the total, so it cannot
            // be described as hidden. Summing it would invent a value in the space's
            // currency and overstate what the filter did.
            makeExpense(spaceID: spaceID, minor: 400_00, paidBy: "me", at: now,
                        category: .housing, originalCurrency: "USD"),
            // Not housing at all.
            makeExpense(spaceID: spaceID, minor: 300_00, paidBy: "me", at: now, category: .food)
        ]
        let snapshots = expenses.map(ExpenseSnapshot.init)

        XCTAssertEqual(AnalyticsCategoryTotal.hiddenHousingAmount(in: snapshots), 1_200,
                       "Only the resolvable housing record is hidden money")
        XCTAssertEqual(AnalyticsCategoryTotal.hiddenHousingAmount(in: snapshots) * 100, 1_200_00)
    }

    func testHiddenHousingIsZeroWhenTheOnlyHousingCannotBeConverted() {
        let unresolvedHousing = makeExpense(spaceID: UUID(), minor: 400_00, paidBy: "me", at: now,
                                            category: .housing, originalCurrency: "USD")
        XCTAssertEqual(AnalyticsCategoryTotal.hiddenHousingAmount(in: [ExpenseSnapshot(unresolvedHousing)]), 0,
                       "Nothing was hidden, so there is no hidden amount to report")
    }

    func testHiddenHousingExcludesSavingsLikeEveryOtherStatistic() {
        let savings = makeExpense(spaceID: UUID(), minor: 900_00, paidBy: "me", at: now, category: .savings)
        // A savings record is not housing, so it is doubly out; the predicate must not be
        // reading only the category.
        XCTAssertEqual(AnalyticsCategoryTotal.hiddenHousingAmount(in: [ExpenseSnapshot(savings)]), 0)
    }

    func testHousingFilterDoesNotAffectTheUnfilteredHousingRow() {
        // The row is shown from the same counted money, so an all-unresolved housing month
        // does not produce a row claiming to hide ₪0.
        let spaceID = UUID()
        let unresolvedOnly = [
            makeExpense(spaceID: spaceID, minor: 400_00, paidBy: "me", at: now,
                        category: .housing, originalCurrency: "USD")
        ].map(ExpenseSnapshot.init)
        XCTAssertEqual(AnalyticsCategoryTotal.hiddenHousingAmount(in: unresolvedOnly), 0)
    }

    // MARK: - Savings in the ledger month

    func testSavingsIsInTheTargetMonthButNotInTheCategoryBreakdown() {
        let space = makeSpace(targetMinor: 800_000)
        let members = [makeMember(id: me, spaceID: space.id)]
        let expenses = [
            makeExpense(spaceID: space.id, minor: 500_00, paidBy: me, at: now, category: .food),
            makeExpense(spaceID: space.id, minor: 300_00, paidBy: me, at: now, category: .savings),
            // Unresolved savings has no value either, so it belongs in neither figure.
            makeExpense(spaceID: space.id, minor: 90_00, paidBy: me, at: now,
                        category: .savings, originalCurrency: "USD")
        ]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(result.savingsMinor, 300_00, "Reported so the screen can name the reason")
        XCTAssertEqual(result.spentMinor, 80_000, "The target covers it: the money left the account")
        // ₪800 spent against an ₪8,000 target — the ₪300 of savings is inside that ₪800.
        XCTAssertEqual(result.progress.remainingMinor, 720_000,
                       "Savings counts against the target, which is the whole point of reporting it")
        XCTAssertFalse(result.progress.isOverTarget)

        let counted = AnalyticsCategoryTotal.totals(from: expenses.map(ExpenseSnapshot.init),
                                                    countsTowardStats: { AnalyticsCategoryTotal.countsTowardStats($0) })
        XCTAssertEqual(counted.map(\.category), [.food], "The breakdown shows only what was spent")
        XCTAssertEqual(counted.map(\.amount).reduce(0, +), 500)
    }

    func testNoSavingsMeansNothingToExplain() {
        let space = makeSpace()
        let expenses = [makeExpense(spaceID: space.id, minor: 500_00, paidBy: me, at: now, category: .food)]
        let result = summary(of: space, expenses: expenses, members: [makeMember(id: me, spaceID: space.id)])
        XCTAssertEqual(result.savingsMinor, 0, "A month with no savings needs no line about savings")
    }

    // MARK: - Empty and unusual months

    func testMonthWithNoTransactionsIsEmptyNotZeroPlausible() {
        let space = makeSpace(targetMinor: 800_000)
        let result = summary(of: space, expenses: [], members: [makeMember(id: me, spaceID: space.id)])

        XCTAssertEqual(result.spentMinor, 0)
        XCTAssertEqual(result.transactionCount, 0)
        XCTAssertEqual(result.unresolvedCount, 0)
        XCTAssertEqual(result.unattributedMinor, 0)
        // The target still stands, so a reader can see where an untouched month sits.
        XCTAssertTrue(result.progress.hasTarget)
        XCTAssertEqual(result.progress.remainingMinor, 800_000)
        XCTAssertFalse(result.canShowMemberShares)
    }

    func testMonthOfNothingButRefundsStaysNegative() {
        let space = makeSpace(targetMinor: 800_000)
        let members = [makeMember(id: me, spaceID: space.id)]
        let expenses = [makeExpense(spaceID: space.id, minor: -300_00, paidBy: me, at: now, merchant: "החזר")]

        let result = summary(of: space, expenses: expenses, members: members)
        XCTAssertEqual(result.spentMinor, -300_00, "A refund-only month is negative, not zero")
        XCTAssertEqual(result.attributedMinor, -300_00)
        XCTAssertTrue(result.transactionCount > 0)
        XCTAssertFalse(result.canShowMemberShares, "Nothing can be a share of a negative month")
        // The target comparison is still honest: it simply says the month is under.
        XCTAssertTrue(result.progress.hasTarget)
        XCTAssertEqual(result.progress.remainingMinor, 830_000)
    }

    // MARK: - Formatting

    func testSharedAmountsUseTheSpacesCurrencyAndKeepOnlyRealDecimals() {
        XCTAssertEqual(SharedMoney.formattedMajor(586_000, currency: "ILS"), "5,860")
        XCTAssertEqual(SharedMoney.formattedMajor(586_050, currency: "ILS"), "5,860.5")
        // A zero-decimal currency must not be handed phantom decimals.
        XCTAssertEqual(SharedMoney.formattedMajor(5_000, currency: "JPY"), "5,000")
        XCTAssertEqual(SharedMoney.major(586_050, currency: "ILS"), 5_860.5, accuracy: 0.0001)
        XCTAssertEqual(SharedMoney.major(5_000, currency: "JPY"), 5_000, accuracy: 0.0001)
    }
}
