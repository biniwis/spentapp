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

    // MARK: - Currency scale

    private func personal(_ amount: Double, base: String, at date: Date? = nil,
                          category: SpendingCategory = .food) -> Transaction {
        Transaction(amount: amount, currency: base, merchant: "M", category: category,
                    timestamp: date ?? now, buildingId: "food_bistro")
    }

    /// The same pair of numbers in three currencies that disagree about what a minor unit
    /// is. A shekel has two decimal places, a yen has none, a dinar has three — so "1,000"
    /// is not the same number of minor units in any two of them, and a total that assumed
    /// two places would be a hundred times out in the yen.
    private func assertScaleIsHonoured(base: String, digits: Int) {
        let space = makeSpace(currency: base)
        let personalMinor = MyTotalSpendCalculator.personalMinor(
            in: [personal(1_000, base: base)], month: now, baseCurrencyCode: base)
        let result = compute(personalMinor: personalMinor, spaces: [space],
                             expenses: [makeExpense(spaceID: space.id, minor: 1_234, paidBy: "me",
                                                    currency: base)],
                             members: [makeMember("me", space.id)], base: base)

        XCTAssertEqual(SharedMoney.digits(base), digits, "\(base) is a \(digits)-digit currency")
        XCTAssertEqual(personalMinor, Int64(1_000 * pow(10, Double(digits))),
                       "1,000 \(base) is not the same number of minor units as 1,000 of anything else")
        XCTAssertEqual(result.sharedMinor, 1_234, "Same currency, so the shared money is simply counted")
        XCTAssertEqual(result.totalMinor, personalMinor + 1_234,
                       "personal + shared = total, in this currency too")
    }

    func testPersonalAndSharedAddUpInShekels() {
        assertScaleIsHonoured(base: "ILS", digits: 2)
    }

    func testPersonalAndSharedAddUpInYenWhichHasNoMinorUnit() {
        assertScaleIsHonoured(base: "JPY", digits: 0)
    }

    func testPersonalAndSharedAddUpInDinarWhichHasThreeDecimalPlaces() {
        assertScaleIsHonoured(base: "KWD", digits: 3)
    }

    func testAPersonalRefundStillSubtractsWhateverTheCurrencyScaleIs() {
        for base in ["ILS", "JPY", "KWD"] {
            let minor = MyTotalSpendCalculator.personalMinor(
                in: [personal(500, base: base), personal(-200, base: base)],
                month: now, baseCurrencyCode: base)
            XCTAssertEqual(minor, Int64(300 * pow(10, Double(SharedMoney.digits(base)))),
                           "A refund takes money off in \(base) as well")
        }
    }

    func testSavingsAreStillNotSpendingInAnyCurrency() {
        for base in ["ILS", "JPY", "KWD"] {
            let saving = personal(1_000, base: base, category: .savings)
            let minor = MyTotalSpendCalculator.personalMinor(in: [saving], month: now, baseCurrencyCode: base)
            XCTAssertEqual(minor, 0, "\(base): money set aside is not money spent")
        }
    }

    func testPersonalMoneyFromAnotherMonthIsNotThisMonthsMoney() {
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        let minor = MyTotalSpendCalculator.personalMinor(
            in: [personal(1_000, base: "ILS", at: lastMonth), personal(250, base: "ILS")],
            month: now, baseCurrencyCode: "ILS")
        XCTAssertEqual(minor, 25_000)
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

    // MARK: - Every month the screen shows

    /// The window a screen looks at: the chart months, plus the month the total on screen
    /// is compared against. Index 0 is the anchor month, 1 the month before, and so on.
    /// The last element is that comparison month again, which is usually already inside
    /// the window — and asking about it twice must not be asking about it twice.
    private func monthsAScreenAsksAbout(anchor: Date, selectedBar: Int? = nil,
                                        count: Int = 6) -> [Date] {
        let cal = scopeCalendarForTests
        let window = (0..<count).map { cal.date(byAdding: .month, value: -$0, to: anchor) ?? anchor }
        let offset = selectedBar ?? 0
        return window + [cal.date(byAdding: .month, value: offset - 1, to: anchor) ?? anchor]
    }

    private var scopeCalendarForTests: Calendar { .current }

    /// Per-month shared totals, read the way the view reads them when the tag is on.
    private func sharedTotals(_ scope: AppScopeContext, over asked: [Date],
                              base: String = "ILS") -> [Double] {
        let cal = scope.calendar
        let listed = scope.mySharedExpenses(for: asked, baseCurrencyCode: base)
        return asked.map { date in
            listed.filter { cal.isDate($0.timestamp, equalTo: date, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }
        }
    }

    /// Starts the demo space, notes what the user had already paid in each of those months,
    /// and hands the test a way to add more. Measured before and after on the same store,
    /// so the demo's own spending is never mistaken for the money under test.
    private func measuringMyMonths(selectedBar: Int? = nil,
                                   _ test: (_ scope: AppScopeContext,
                                            _ add: ([Int]) async throws -> Void,
                                            _ baseline: [Double],
                                            _ asked: [Date]) async throws -> Void) async throws {
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        // Asked of the store before the scope moves to personal, which is what clearing
        // the active space means.
        let spaceID = try XCTUnwrap(store.activeSpaceID)
        let me = try XCTUnwrap(store.currentMemberID(in: spaceID))
        let scope = AppScopeContext(store: store)
        scope.selectPersonal()
        let asked = monthsAScreenAsksAbout(anchor: Date(), selectedBar: selectedBar)
        let baseline = sharedTotals(scope, over: asked)

        let add: ([Int]) async throws -> Void = { offsets in
            for offset in offsets {
                let date = Calendar.current.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
                try store.saveExpense(SharedExpense(
                    id: UUID(), spaceID: spaceID, amountMinor: 5_000, currencyCode: "ILS",
                    merchant: "S", category: .food, buildingID: "food_bistro", date: date,
                    note: "", paidBy: me, createdBy: me, updatedBy: me))
            }
        }

        try await test(scope, add, baseline, asked)
    }

    private func growth(_ baseline: [Double], after: [Double]) -> [Double] {
        zip(after, baseline).map { $0 - $1 }
    }

    func testBothMonthsOfTheComparisonGetTheSharedMoneyTheyActuallySpent() async throws {
        try await measuringMyMonths { scope, add, baseline, asked in
            try await add([0, 1])

            let added = growth(baseline, after: sharedTotals(scope, over: asked))

            XCTAssertEqual(added[0], 50, "This month's shared money is in this month's total")
            XCTAssertEqual(added[asked.count - 1], 50,
                           "And the month before carries its own, which is the month being compared")
        }
    }

    func testEveryMonthOfTheChartGetsItsOwnSharedMoneyRatherThanTheSelectedMonths() async throws {
        try await measuringMyMonths { scope, add, baseline, asked in
            try await add([2, 4])

            let added = growth(baseline, after: sharedTotals(scope, over: asked))

            XCTAssertEqual(Array(added.prefix(6)), [0, 0, 50, 0, 50, 0],
                           "Two and four months back each carry their own money, and no other bar does")
            XCTAssertEqual(added[6], 0, "The month before the window had none of its own to add")
        }
    }

    func testGoingBackToAnEarlierMonthShowsThatMonthsSharedMoney() async throws {
        try await measuringMyMonths(selectedBar: 3) { scope, add, baseline, asked in
            try await add([3])

            let added = growth(baseline, after: sharedTotals(scope, over: asked))

            XCTAssertEqual(added[3], 50, "The month the user navigated to carries its own shared money")
            XCTAssertEqual(added[2], 0, "And the month before it carries its own, which is nothing")
            XCTAssertEqual(added[0], 0, "The month they walked away from is not added to this one")
        }
    }

    func testAMonthAskedAboutTwiceIsCountedOnceInEachTotalAndOnceAcrossThem() async throws {
        try await measuringMyMonths { scope, add, baseline, asked in
            try await add([0, 1, 2])

            let listed = scope.mySharedExpenses(for: asked, baseCurrencyCode: "ILS")
            let ids = listed.map(\.id)
            let added = growth(baseline, after: sharedTotals(scope, over: asked))

            XCTAssertEqual(Set(ids).count, ids.count, "Overlapping months must not double a row")
            XCTAssertEqual(asked[6], asked[1], "This screen really does ask about one month twice")
            XCTAssertEqual(added[6], added[1], "And gets the same answer, not two of them")
            XCTAssertEqual(Array(added.prefix(6)).reduce(0, +), 150,
                           "Three months of shared money across the window, each counted once")
        }
    }

    func testWithTheTagOffTheScreenIsPersonalOnlyIncludingThePastMonths() async throws {
        try await measuringMyMonths { scope, add, baseline, asked in
            try await add([0, 1, 2])
            let now = Date()
            let personal = [ExpenseSnapshot(id: UUID(), amount: 30, merchant: "P", category: .food,
                                            timestamp: now, buildingId: "food_bistro")]
            let cal = scope.calendar
            let off = asked.map { date in
                personal.filter { cal.isDate($0.timestamp, equalTo: date, toGranularity: .month) }
                    .reduce(0) { $0 + $1.amount }
            }

            XCTAssertEqual(off, [30, 0, 0, 0, 0, 0, 0],
                           "With the tag off every past month is empty, exactly as it always was")
            XCTAssertEqual(Array(growth(baseline, after: sharedTotals(scope, over: asked)).prefix(6))
                            .reduce(0, +), 150, "With it on, the same three months appear")
        }
    }

    func testReadingTheOtherMonthsWritesNothingAndGrantsNothing() async throws {
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        let scope = AppScopeContext(store: store)
        scope.selectPersonal()
        let expensesBefore = store.expenses
        let membersBefore = store.members
        let capabilitiesBefore = scope.capabilities

        _ = scope.mySharedExpenses(for: monthsAScreenAsksAbout(anchor: Date()),
                                   baseCurrencyCode: "ILS")

        XCTAssertEqual(store.expenses, expensesBefore, "A wider question copies nothing into anywhere")
        XCTAssertEqual(store.members, membersBefore)
        XCTAssertEqual(scope.capabilities, capabilitiesBefore)
    }

    func testAHistoryOfSharedMoneyDoesNotChangeWhatASharedSpaceReports() async throws {
        let store = SharedWorkspaceStore()
        try await store.startDemo()
        let spaceID = try XCTUnwrap(store.activeSpaceID)
        let scope = AppScopeContext(store: store)
        scope.selectShared(spaceID: spaceID)
        let before = try XCTUnwrap(scope.sharedMonthSummary(for: Date()))
        scope.selectPersonal()

        _ = scope.mySharedExpenses(for: monthsAScreenAsksAbout(anchor: Date()),
                                   baseCurrencyCode: "ILS")
        scope.selectShared(spaceID: spaceID)
        let after = try XCTUnwrap(scope.sharedMonthSummary(for: Date()))

        XCTAssertEqual(before.spentMinor, after.spentMinor, "The space's own month is its own business")
        XCTAssertEqual(before.memberTotals.map(\.amountMinor), after.memberTotals.map(\.amountMinor))
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
