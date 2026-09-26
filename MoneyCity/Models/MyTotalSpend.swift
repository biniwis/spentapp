import Foundation

/// What actually left the user's pocket this month: their own personal spending, plus what
/// they personally paid for in the shared spaces they belong to.
///
/// Money somebody else spent in a shared space is not this user's money and never appears
/// here. A space counts only once the app can prove which member the signed-in user is in
/// it — where that identity cannot be established the space is left out rather than guessed
/// at, because guessing would turn somebody else's spending into the user's total.
public struct MyTotalSpend {

    public struct SpaceAmount: Equatable, Identifiable, Sendable {
        public let spaceID: UUID
        public let name: String
        public let currencyCode: String
        /// What the user paid in this space, in the space's own currency.
        public let minorInSpaceCurrency: Int64
        /// The same money in the personal base currency, or `nil` when the space runs on
        /// another currency and no trustworthy rate exists. A `nil` here means the money
        /// is real but the total must not pretend to know what it is worth.
        public let minorInPersonalCurrency: Int64?
        public var id: UUID { spaceID }
    }

    /// A shared expense that is genuinely the user's, already expressed in the personal
    /// base currency, so it can join an Analytics view that is denominated in it.
    public struct IncludedExpense: Identifiable, Sendable {
        public let id: UUID
        public let spaceID: UUID
        public let spaceName: String
        public let snapshot: ExpenseSnapshot
        public let minorInPersonalCurrency: Int64
    }

    public let personalMinor: Int64
    public let baseCurrencyCode: String
    public let spaces: [SpaceAmount]
    public let includedExpenses: [IncludedExpense]

    public static func == (lhs: MyTotalSpend, rhs: MyTotalSpend) -> Bool {
        lhs.personalMinor == rhs.personalMinor && lhs.baseCurrencyCode == rhs.baseCurrencyCode
            && lhs.spaces == rhs.spaces && lhs.includedExpenses.map(\.id) == rhs.includedExpenses.map(\.id)
            && lhs.includedExpenses.map(\.minorInPersonalCurrency) == rhs.includedExpenses.map(\.minorInPersonalCurrency)
    }

    /// The user belongs to at least one shared space. This is what makes the second state
    /// of the profile tile worth offering, and it is true even when the user spent nothing.
    public var isMemberOfAnySpace: Bool { !spaces.isEmpty }

    /// Only the spaces whose money can be stated in the personal currency are added up.
    public var sharedMinor: Int64 { spaces.compactMap(\.minorInPersonalCurrency).reduce(0, +) }

    public var totalMinor: Int64 { personalMinor + sharedMinor }

    /// Spaces left out of the total because their money is in a currency we cannot honestly
    /// convert. A quiet note, not an error: nothing is broken, there is simply no rate.
    public var omittedCurrencies: [String] {
        var seen = Set<String>()
        return spaces.compactMap { space in
            guard space.minorInPersonalCurrency == nil, space.minorInSpaceCurrency != 0 else { return nil }
            return seen.insert(space.currencyCode).inserted ? space.currencyCode : nil
        }
    }
}

/// Turns a month of ledgers into `MyTotalSpend`.
///
/// Every decision is made from data that is handed in, so the rule "only money I can prove
/// is mine, in a currency I can honestly state" is checkable without a CloudKit account, a
/// simulator or a running app.
enum MyTotalSpendCalculator {

    /// - Parameters:
    ///   - personalMinor: the user's own spending for the month, already net of savings by
    ///     whatever rule the surface asking for it uses, so the two states of a card can
    ///     never disagree about the personal part.
    ///   - myMemberID: the app's per-space member identity, or `nil` where the signed-in
    ///     account cannot be resolved. A space is skipped unless this returns an ID that
    ///     matches a real member record in that space.
    ///   - convert: the app's one conversion source. Supplied rather than reached for, so
    ///     this function never fetches anything and the rule stays checkable.
    static func compute(baseCurrencyCode: String,
                        personalMinor: Int64,
                        spaces: [SharedSpace],
                        expenses: [SharedExpense],
                        members: [SharedMember],
                        convert: (Double, String, String) -> Double?,
                        myMemberID: (UUID) -> String?,
                        now: Date) -> MyTotalSpend {

        let base = baseCurrencyCode.uppercased()
        var amounts: [MyTotalSpend.SpaceAmount] = []
        var included: [MyTotalSpend.IncludedExpense] = []

        for space in spaces {
            // No trustworthy identity means no space. Not a guess, not the first member,
            // not "probably me".
            guard let memberID = myMemberID(space.id),
                  members.contains(where: { $0.id == memberID && $0.spaceID == space.id }) else { continue }

            let interval = space.calendar.dateInterval(of: .month, for: now)
            let mine = expenses.filter {
                $0.spaceID == space.id
                    && $0.paidBy == memberID
                    && !$0.isUnresolvedForeign
                    && interval?.contains($0.date) == true
            }
            let minor = mine.reduce(Int64(0)) { $0 + $1.amountMinor }

            // Same currency is the same money. A different currency is only ever counted
            // at a rate the app's own conversion source can state, and there is no 1:1
            // stand-in for a missing one: without a rate the money stays out of the total
            // and the space says so quietly.
            let spaceCode = space.currencyCode.uppercased()
            let converted: Double? = spaceCode == base
                ? SharedMoney.major(minor, currency: space.currencyCode)
                : convert(SharedMoney.major(minor, currency: space.currencyCode), spaceCode, base)
                    .flatMap { $0.isFinite ? $0 : nil }

            var convertedMinor: Int64?
            var spaceIncluded: [MyTotalSpend.IncludedExpense] = []
            if let converted {
                let digits = Double(SharedMoney.digits(base))
                convertedMinor = Int64((converted * pow(10, digits)).rounded())
                for expense in mine {
                    // Converted at the major level, because a minor unit in one currency is
                    // not a minor unit in another: ¥100 is a whole unit and ₪100 is not.
                    let major = convert(SharedMoney.major(expense.amountMinor, currency: space.currencyCode),
                                        spaceCode, base) ?? 0
                    let personal = Int64((major * pow(10, digits)).rounded())
                    var snapshot = ExpenseSnapshot(expense)
                    snapshot.timeZoneID = space.timeZoneID
                    if spaceCode != base { snapshot = snapshot.converted(to: base, amount: major) }
                    spaceIncluded.append(MyTotalSpend.IncludedExpense(
                        id: expense.id, spaceID: space.id, spaceName: space.name,
                        snapshot: snapshot, minorInPersonalCurrency: personal))
                }
            }

            amounts.append(MyTotalSpend.SpaceAmount(spaceID: space.id, name: space.name,
                                                    currencyCode: space.currencyCode,
                                                    minorInSpaceCurrency: minor,
                                                    minorInPersonalCurrency: convertedMinor))
            included.append(contentsOf: spaceIncluded)
        }

        return MyTotalSpend(personalMinor: personalMinor, baseCurrencyCode: base,
                            spaces: amounts, includedExpenses: included)
    }
}
