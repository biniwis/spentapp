import XCTest
@testable import MoneyCity

/// "How much did I actually spend" is only worth showing if every unit of it is provably
/// the user's own money. These tests pin the refusals as hard as the sums, because the
/// dangerous failure is not a wrong number — it is a number that looks right.
final class MyTotalSpendTests: XCTestCase {

    private let now = Date()

    private func makeSpace(id: UUID = UUID(), currency: String = "ILS") -> SharedSpace {
        SharedSpace(id: id, name: "s\(currency)", currencyCode: currency, timeZoneID: "UTC",
                    mapStyle: "urban", createdAt: now, monthlyBudgetMinor: nil)
    }

    private func makeMember(_ id: String, _ spaceID: UUID, active: Bool = true) -> SharedMember {
        SharedMember(id: id, spaceID: spaceID, name: id, colorHex: "#7C5CFF", isActive: active)
    }

    /// Resolved unless told otherwise: a rate the app already holds, so the record has an
    /// honest amount in the space's currency.
    private func makeExpense(spaceID: UUID, minor: Int64, paidBy: String, currency: String = "ILS",
                             unresolved: Bool = false, date: Date? = nil) -> SharedExpense {
        SharedExpense(id: UUID(), spaceID: spaceID, amountMinor: minor, currencyCode: currency,
                      merchant: "T", category: .food, buildingID: "food_bistro",
                      date: date ?? now, note: "", paidBy: paidBy, createdBy: paidBy, updatedBy: paidBy,
                      originalAmount: unresolved ? "10.00" : nil,
                      originalCurrency: unresolved ? "EUR" : nil,
                      exchangeRate: unresolved ? nil : nil, exchangeRateDate: nil)
    }

    /// A fixed table, so a test can name the rate it is about without touching the device.
    private func stubbed(_ rates: [String: Double]) -> (Double, String, String) -> Double? {
        { amount, from, to in
            guard let rate = rates[from.uppercased()] else { return nil }
            guard rate > 0 else { return nil }
            return amount * rate / (rates[to.uppercased()] ?? 1)
        }
    }

    private func compute(personalMinor: Int64 = 0,
                         spaces: [SharedSpace],
                         expenses: [SharedExpense],
                         members: [SharedMember],
                         base: String = "ILS",
                         convert: ((Double, String, String) -> Double?)? = nil,
                         me: ((UUID) -> String?)? = nil) -> MyTotalSpend {
        MyTotalSpendCalculator.compute(
            baseCurrencyCode: base, personalMinor: personalMinor, spaces: spaces,
            expenses: expenses, members: members,
            convert: convert ?? FXService.convert(amount:from:to:),
            myMemberID: me ?? { _ in "me" }, now: now)
    }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(3.65, forKey: "fx_rate_usd_ils")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "fx_rate_usd_ils")
        super.tearDown()
    }

    // MARK: - Personal only

    func testPersonalOnlyTotalsAreExactlyThePersonalAmount() {
        let result = compute(personalMinor: 50_000, spaces: [], expenses: [], members: [])

        XCTAssertEqual(result.totalMinor, 50_000, "No shared spaces, nothing added, nothing lost")
        XCTAssertEqual(result.sharedMinor, 0)
        XCTAssertFalse(result.isMemberOfAnySpace,
                       "So the tile is never offered a breakdown that would have one line")
        XCTAssertTrue(result.includedExpenses.isEmpty)
    }

    func testAMemberWhoSpentNothingThisMonthStillGetsTheReading() {
        let space = makeSpace()
        let result = compute(personalMinor: 50_000, spaces: [space], expenses: [],
                             members: [makeMember("me", space.id)])

        XCTAssertEqual(result.totalMinor, 50_000)
        XCTAssertEqual(result.sharedMinor, 0, "Zero shared is a true zero, not a hidden one")
        XCTAssertTrue(result.isMemberOfAnySpace, "Belonging is what earns the reading, not spending")
    }

    // MARK: - Only what the user paid

    func testWhatTheUserPaidInASharedSpaceIsIncluded() {
        let space = makeSpace()
        let result = compute(personalMinor: 10_000, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 40_000, paidBy: "me")],
                             members: [makeMember("me", space.id), makeMember("partner", space.id)])

        XCTAssertEqual(result.sharedMinor, 40_000)
        XCTAssertEqual(result.totalMinor, 50_000)
        XCTAssertEqual(result.includedExpenses.count, 1)
    }

    func testWhatThePartnerPaidIsNeverTheUsersMoney() {
        let space = makeSpace()
        let result = compute(personalMinor: 10_000, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 90_000, paidBy: "partner")],
                             members: [makeMember("me", space.id), makeMember("partner", space.id)])

        XCTAssertEqual(result.sharedMinor, 0, "A partner's groceries are a partner's money")
        XCTAssertEqual(result.totalMinor, 10_000)
        XCTAssertTrue(result.includedExpenses.isEmpty)
        XCTAssertTrue(result.isMemberOfAnySpace,
                      "Still a member, so the profile tile can offer the reading")
    }

    func testARefundTheUserGotReducesTheirTotal() {
        let space = makeSpace()
        let result = compute(personalMinor: 0, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 100_000, paidBy: "me"),
                                        makeExpense(spaceID: space.id, minor: -30_000, paidBy: "me")],
                             members: [makeMember("me", space.id)])

        XCTAssertEqual(result.sharedMinor, 70_000, "Signed, like everywhere else money is counted")
        XCTAssertEqual(result.totalMinor, 70_000)
    }

    func testUnresolvedForeignIsLeftOutRatherThanGuessedAt() {
        let space = makeSpace(currency: "USD")
        let result = compute(personalMinor: 0, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 5_000, paidBy: "me",
                                                    currency: "USD", unresolved: true)],
                             members: [makeMember("me", space.id)])

        XCTAssertEqual(result.sharedMinor, 0)
        XCTAssertTrue(result.includedExpenses.isEmpty)
    }


    func testEverySpaceTheUserPaidInIsCounted() {
        let home = makeSpace()
        let abroad = makeSpace()
        let result = compute(personalMinor: 0, spaces: [home, abroad],
                             expenses: [makeExpense(spaceID: home.id, minor: 10_000, paidBy: "me"),
                                        makeExpense(spaceID: abroad.id, minor: 25_000, paidBy: "me"),
                                        makeExpense(spaceID: abroad.id, minor: 99_000, paidBy: "someone-else")],
                             members: [makeMember("me", home.id), makeMember("me", abroad.id)])

        XCTAssertEqual(result.sharedMinor, 35_000)
        XCTAssertEqual(result.spaces.count, 2)
    }

    // MARK: - History

    func testMoneyIAlreadyPaidThisMonthIsMineEvenIfILeftTheSpaceAfterwards() {
        let space = makeSpace()
        let result = compute(personalMinor: 0, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 6_000, paidBy: "me")],
                             members: [makeMember("me", space.id, active: false)])

        XCTAssertEqual(result.sharedMinor, 6_000,
                       "It left my account before I left the space")
        XCTAssertEqual(result.totalMinor, 6_000)
        XCTAssertEqual(result.includedExpenses.count, 1)
    }

    func testAMonthTheUserPaidInIsCountedEvenIfTheyHaveSinceLeft() {
        let space = makeSpace()
        let lastMonth = Self.month(-1)
        let result = compute(personalMinor: 0, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 12_000, paidBy: "me",
                                                    date: lastMonth)],
                             members: [makeMember("me", space.id, active: false)])

        XCTAssertEqual(result.sharedMinor, 0, "Not this month, so not this month's total")
        let historical = MyTotalSpendCalculator.compute(
            baseCurrencyCode: "ILS", personalMinor: 0, spaces: [space],
            expenses: [makeExpense(spaceID: space.id, minor: 12_000, paidBy: "me", date: lastMonth)],
            members: [makeMember("me", space.id, active: false)],
            convert: FXService.convert(amount:from:to:), myMemberID: { _ in "me" }, now: lastMonth)
        XCTAssertEqual(historical.sharedMinor, 12_000,
                       "In the month it happened, their own money is still their own")
    }

    // MARK: - Identity

    func testASpaceWithNoTrustworthyIdentityIsLeftOutRatherThanGuessed() {
        let space = makeSpace()
        let result = compute(personalMinor: 10_000, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 40_000, paidBy: "me")],
                             members: [makeMember("me", space.id)], me: { _ in nil })

        XCTAssertTrue(result.spaces.isEmpty, "Not knowing who I am means not claiming the money")
        XCTAssertEqual(result.totalMinor, 10_000)
    }

    func testTheFirstMemberIsNotAssumedToBeTheUser() {
        let space = makeSpace()
        let result = compute(personalMinor: 0, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 40_000, paidBy: "first-listed")],
                             members: [makeMember("first-listed", space.id),
                                       makeMember("actually-me", space.id)], me: { _ in "actually-me" })

        XCTAssertEqual(result.sharedMinor, 0, "Order in a list is not an identity")
    }

    func testAnIdentityThatMatchesNoMemberRecordInThatSpaceIsRefused() {
        let space = makeSpace()
        let result = compute(personalMinor: 0, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 40_000, paidBy: "me")],
                             members: [makeMember("me", makeSpace().id)], me: { _ in "me" })

        XCTAssertTrue(result.spaces.isEmpty)
    }

    func testAnotherSpacesMembersDoNotLeakIn() {
        let mine = makeSpace()
        let theirs = makeSpace()
        let result = compute(personalMinor: 0, spaces: [mine, theirs],
                             expenses: [makeExpense(spaceID: theirs.id, minor: 40_000, paidBy: "me")],
                             members: [makeMember("me", mine.id), makeMember("me", theirs.id)],
                             me: { _ in "me" })

        XCTAssertEqual(result.spaces.count, 2)
        XCTAssertEqual(result.spaces.first { $0.spaceID == mine.id }?.minorInSpaceCurrency, 0)
        XCTAssertEqual(result.spaces.first { $0.spaceID == theirs.id }?.minorInSpaceCurrency, 40_000)
    }

    // MARK: - Currency

    func testAPersonalAndASharedSpaceInTheSameCurrencyAddUpDirectly() {
        let space = makeSpace(currency: "ILS")
        let result = compute(personalMinor: 10_000, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 8_000, paidBy: "me")],
                             members: [makeMember("me", space.id)])

        XCTAssertEqual(result.sharedMinor, 8_000, "No rate, no conversion, no rounding in the way")
        XCTAssertEqual(result.totalMinor, 18_000)
        XCTAssertTrue(result.omittedCurrencies.isEmpty)
    }

    func testAForeignSpaceIsConvertedAtTheAppsOwnRate() {
        let space = makeSpace(currency: "USD")
        let result = compute(personalMinor: 0, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 2_000, paidBy: "me",
                                                    currency: "USD")],
                             members: [makeMember("me", space.id)])

        // $20 at the app's own USD→ILS rate. The number comes from FXService, not from
        // some other transaction's rate and not from a 1:1 guess.
        let expected = Int64(((FXService.convert(amount: 20, from: "USD", to: "ILS") ?? 0) * 100).rounded())
        XCTAssertEqual(result.sharedMinor, expected)
        XCTAssertEqual(expected, 7_300, "20 × 3.65")
        XCTAssertEqual(result.includedExpenses.first?.snapshot.currency, "ILS",
                       "Stated in the currency the personal analytics is denominated in")
    }

    func testAZeroDecimalCurrencyIsNotReadAsAHundredTimesTooMuch() {
        let space = makeSpace(currency: "JPY")
        // ¥500 is 500 minor units, because the yen has no minor unit at all.
        let result = compute(personalMinor: 0, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 500, paidBy: "me",
                                                    currency: "JPY")],
                             members: [makeMember("me", space.id)],
                             convert: stubbed(["JPY": 0.025, "ILS": 1]))

        XCTAssertEqual(result.sharedMinor, 1_250, "500 yen is 12.5 shekels, not 1,250 of them")
    }

    func testACurrencyWithNoRateIsLeftOutRatherThanAssumedToBeOneToOne() {
        let space = makeSpace(currency: "XTS")
        let result = compute(personalMinor: 10_000, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 5_000, paidBy: "me",
                                                    currency: "XTS")],
                             members: [makeMember("me", space.id)])

        XCTAssertNil(FXService.convert(amount: 1, from: "XTS", to: "ILS"),
                     "The premise of this test: there is no honest rate to be had for this one")
        XCTAssertEqual(result.sharedMinor, 0, "No rate is never a 1:1")
        XCTAssertEqual(result.totalMinor, 10_000)
        XCTAssertEqual(result.spaces.first?.minorInSpaceCurrency, 5_000, "The money is still reported")
        XCTAssertEqual(result.omittedCurrencies, ["XTS"], "And said to be missing from the total")
        XCTAssertTrue(result.includedExpenses.isEmpty)
    }

    func testARefundInAForeignCurrencyKeepsItsSignThroughTheConversion() {
        let space = makeSpace(currency: "USD")
        let result = compute(personalMinor: 0, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 5_000, paidBy: "me",
                                                    currency: "USD"),
                                        makeExpense(spaceID: space.id, minor: -2_000, paidBy: "me",
                                                    currency: "USD")],
                             members: [makeMember("me", space.id)])

        XCTAssertEqual(result.sharedMinor, 10_950, "$30 at 3.65 — a refund takes money off, not adds it")
        XCTAssertEqual(result.includedExpenses.last?.minorInPersonalCurrency, -7_300,
                       "The refund is still a refund after being converted")
        XCTAssertEqual(result.includedExpenses.last?.snapshot.amount ?? 0, -73, accuracy: 0.001)
    }

    func testTwoSpacesInTwoCurrenciesBothCount() {
        let dollars = makeSpace(currency: "USD")
        let euros = makeSpace(currency: "EUR")
        let result = compute(personalMinor: 0, spaces: [dollars, euros],
                             expenses: [makeExpense(spaceID: dollars.id, minor: 1_000, paidBy: "me",
                                                    currency: "USD"),
                                        makeExpense(spaceID: euros.id, minor: 1_000, paidBy: "me",
                                                    currency: "EUR")],
                             members: [makeMember("me", dollars.id), makeMember("me", euros.id)])

        let dollarsILS = Int64(((FXService.convert(amount: 10, from: "USD", to: "ILS") ?? 0) * 100).rounded())
        let eurosILS = Int64(((FXService.convert(amount: 10, from: "EUR", to: "ILS") ?? 0) * 100).rounded())
        XCTAssertEqual(result.sharedMinor, dollarsILS + eurosILS, "Each space converted on its own terms")
        XCTAssertEqual(result.spaces.count, 2)
    }

    func testOneUnconvertibleSpaceDoesNotStopAnotherFromCounting() {
        let dollars = makeSpace(currency: "USD")
        let unknown = makeSpace(currency: "XTS")
        let result = compute(personalMinor: 0, spaces: [dollars, unknown],
                             expenses: [makeExpense(spaceID: dollars.id, minor: 1_000, paidBy: "me",
                                                    currency: "USD"),
                                        makeExpense(spaceID: unknown.id, minor: 5_000, paidBy: "me",
                                                    currency: "XTS")],
                             members: [makeMember("me", dollars.id), makeMember("me", unknown.id)])

        XCTAssertEqual(result.sharedMinor, 3_650, "$10 at 3.65 — the dollars still count")
        XCTAssertEqual(result.omittedCurrencies, ["XTS"])
        XCTAssertEqual(result.spaces.count, 2, "And the unconvertible one is still reported")
    }

    // MARK: - Nothing else moves

    func testComputingThisTouchesNoLedgerAndNoScope() {
        let space = makeSpace()
        let expenses = [makeExpense(spaceID: space.id, minor: 40_000, paidBy: "me")]
        let members = [makeMember("me", space.id)]
        let before = (spaces: [space], expenses: expenses, members: members)

        _ = compute(personalMinor: 10_000, spaces: spaces(before), expenses: expenses,
                    members: members)

        XCTAssertEqual(spaces(before).map(\.id), [space.id])
        XCTAssertEqual(before.expenses, expenses)
        XCTAssertEqual(before.members, members)
    }

    private func spaces(_ value: (spaces: [SharedSpace], expenses: [SharedExpense],
                                  members: [SharedMember])) -> [SharedSpace] { value.spaces }

    private static func month(_ offset: Int) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .month, value: offset, to: Date())!
    }
}

/// The same rule read through the real store and through the real Analytics pipeline,
/// because the pure calculator can be right while a caller still wires it wrongly.
@MainActor
final class MyTotalSpendScopeTests: XCTestCase {

    func testTheDemoSpaceContributesOnlyWhatTheSignedInUserPaidFor() async throws {
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        let spaceID = try XCTUnwrap(store.activeSpaceID)
        let scope = AppScopeContext(store: store)

        let spend = scope.myTotalSpend(for: Date(), baseCurrencyCode: "ILS", personalTransactions: [])

        let myID = try XCTUnwrap(store.currentMemberID(in: spaceID))
        let mine = store.expenses.filter { $0.spaceID == spaceID && $0.paidBy == myID && !$0.isUnresolvedForeign }
        let theirs = store.expenses.filter { $0.spaceID == spaceID && $0.paidBy != myID }

        XCTAssertFalse(mine.isEmpty, "The demo has the user paying for things")
        XCTAssertFalse(theirs.isEmpty, "And the partner paying for others")
        XCTAssertEqual(spend.sharedMinor, mine.reduce(Int64(0)) { $0 + $1.amountMinor })
        XCTAssertTrue(spend.includedExpenses.allSatisfy { $0.snapshot.paidBy == myID })
    }

    func testAnUnresolvedStoreReportsNoIdentityAndSoNoSharedMoney() async throws {
        let store = SharedWorkspaceStore()
        let scope = AppScopeContext(store: store)

        // Never connected: the account name is unknown, so the derived member id matches
        // nobody. The total must fall back to personal rather than claim a stranger's money.
        let spend = scope.myTotalSpend(for: Date(), baseCurrencyCode: "ILS", personalTransactions: [])

        XCTAssertTrue(spend.spaces.isEmpty)
        XCTAssertEqual(spend.totalMinor, spend.personalMinor)
    }


    func testPersonalBudgetCityAndParkAreUntouchedByThisReading() async throws {
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        let scope = AppScopeContext(store: store)
        let spaceID = try XCTUnwrap(store.activeSpaceID)

        let expensesBefore = store.expenses
        let membersBefore = store.members

        // Personal scope, reading a shared space's money.
        scope.selectPersonal()
        let capabilitiesBefore = scope.capabilities
        _ = scope.myTotalSpend(for: Date(), baseCurrencyCode: "ILS", personalTransactions: [])

        XCTAssertEqual(scope.capabilities, capabilitiesBefore, "A reading grants and revokes nothing")
        XCTAssertTrue(scope.capabilities.hasBudget, "The personal budget is still the personal one")
        XCTAssertEqual(store.expenses, expensesBefore, "No expense is copied into the personal ledger")
        XCTAssertEqual(store.members, membersBefore)
        XCTAssertNil(scope.sharedCityContext(for: Date()),
                     "The personal city keeps its own world and never borrows a space's numbers")

        // And the shared city's own park is unchanged by anything personal.
        scope.selectShared(spaceID: spaceID)
        let context = try XCTUnwrap(scope.sharedCityContext(for: Date()))
        XCTAssertEqual(context.spaceID, spaceID)
    }

    // MARK: - The Analytics tag

    private func pipeline(_ transactions: [ExpenseSnapshot]) -> (total: Double, categories: [AnalyticsCategoryTotal]) {
        let counted = transactions.filter { AnalyticsCategoryTotal.countsTowardStats($0, excludeHousing: false) }
        return (counted.reduce(0) { $0 + $1.amount },
                AnalyticsCategoryTotal.totals(from: transactions, countsTowardStats: {
                    AnalyticsCategoryTotal.countsTowardStats($0, excludeHousing: false)
                }))
    }

    func testWithTheTagOffThePersonalListIsUntouchedByTheSharedReading() async throws {
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        let scope = AppScopeContext(store: store)
        scope.selectPersonal()

        // What the screen reads when the tag is off: the personal list, and nothing else.
        let personal = scope.allExpenses(personalTransactions: [])
        let before = pipeline(personal)

        let spend = scope.myTotalSpend(for: Date(), baseCurrencyCode: "ILS", personalTransactions: [])
        XCTAssertFalse(spend.includedExpenses.isEmpty, "There is shared money waiting to be included")
        XCTAssertEqual(scope.allExpenses(personalTransactions: []).map(\.id), personal.map(\.id),
                       "Reading it changes nothing about what the personal screen shows")
        XCTAssertEqual(scope.allExpenses(personalTransactions: []).map(\.amount), personal.map(\.amount))

        let after = pipeline(personal)
        XCTAssertEqual(before.total, after.total)
        XCTAssertEqual(before.categories.map(\.amount), after.categories.map(\.amount))
    }

    func testWithTheTagOnTheSameNumbersGrowByExactlyWhatTheUserPaid() async throws {
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        let spaceID = try XCTUnwrap(store.activeSpaceID)
        let scope = AppScopeContext(store: store)
        scope.selectPersonal()

        let personal = store.expenses
            .filter { $0.spaceID == spaceID && $0.paidBy == "not-me" }
            .map(ExpenseSnapshot.init)
        let spend = scope.myTotalSpend(for: Date(), baseCurrencyCode: "ILS", personalTransactions: [])
        let shared = spend.includedExpenses.map(\.snapshot)

        let before = pipeline(personal)
        let after = pipeline(personal + shared)

        XCTAssertGreaterThan(after.total, before.total)
        XCTAssertEqual(after.total - before.total, Double(spend.sharedMinor) / 100, accuracy: 0.001,
                       "The same sum the profile card shows, arriving in the analytics total")
        XCTAssertEqual(after.categories.reduce(0) { $0 + $1.amount }, after.total,
                       "Categories add up to the total, so the breakdown did not drift from it")
    }

    func testTheTagNeverOffersTheUsersMoneyFromASpaceTheyCannotBeIdentifiedIn() async throws {
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        let scope = AppScopeContext(store: store)
        scope.selectPersonal()

        XCTAssertTrue(scope.myTotalSpend(for: Date(), baseCurrencyCode: "ILS",
                                         personalTransactions: []).isMemberOfAnySpace)
    }
}
