import Foundation

/// One shared space's month, told as a page of the personal recap.
///
/// Transient on purpose. It is built from the shared ledger the user can read right now and
/// thrown away when the recap closes. Nothing here is written into the personal recap
/// snapshot, the personal store or a backup, so a past month keeps reporting the spaces that
/// are still visible to the user and keeps nothing private about the ones that are not.
///
/// Every figure that describes money, members or the target is read from
/// `SharedMonthlySummary.month(of:expenses:members:now:)` rather than counted again here, so
/// a shared page cannot tell a different story from the space's own month: who paid,
/// whether somebody who has since left still belongs to the month, what a refund did, and
/// what is still waiting for a rate are all already decided there.
///
/// Never merged with the personal half. A section is in the space's own currency, and two
/// spaces in two currencies are two sections that never meet.
struct SharedRecapSection: Identifiable, Equatable {
    let spaceID: UUID
    let spaceName: String
    let currencyCode: String
    /// Any date inside the month being summarised. The space's own calendar decides which
    /// month a record belongs to, never the reader's.
    let month: Date

    let spentMinor: Int64
    /// Includes records still waiting for a rate, as the space's own month counts them.
    let transactionCount: Int
    let unresolvedCount: Int

    /// The space's own monthly target, or nil when it has none. Nil means "no target" and is
    /// never reported as a target of zero.
    let targetMinor: Int64?
    let memberTotals: [SharedMemberTotal]
    /// Money whose payer is not anybody who was ever in this space.
    let unattributedMinor: Int64
    let biggestCategory: SharedRecapCategory?

    var id: String { spaceID.uuidString }

    init(summary: SharedMonthlySummary,
         spaceName: String,
         currencyCode: String,
         month: Date,
         biggestCategory: SharedRecapCategory?) {
        self.spaceID = summary.spaceID
        self.spaceName = spaceName
        self.currencyCode = currencyCode
        self.month = month
        self.spentMinor = summary.spentMinor
        self.transactionCount = summary.transactionCount
        self.unresolvedCount = summary.unresolvedCount
        self.targetMinor = summary.progress.targetMinor
        self.memberTotals = summary.memberTotals
        self.unattributedMinor = summary.unattributedMinor
        self.biggestCategory = biggestCategory
    }

    // MARK: - The target, in its three honest states

    private var hasTarget: Bool { (targetMinor ?? 0) > 0 }
    var remainingMinor: Int64? {
        guard let targetMinor, hasTarget else { return nil }
        return targetMinor - spentMinor
    }
    /// How far past the target the month went, when it did. Positive.
    var overTargetMinor: Int64? {
        guard let remaining = remainingMinor, remaining < 0 else { return nil }
        return -remaining
    }
    /// The target as a figure. Only read on a path that has already established there is a
    /// target, so a space without one is never described as having a target of zero.
    var targetMoney: String { money(targetMinor ?? 0) }

    // MARK: - What is worth a page

    /// Whether there is anybody to name. Zero is a real answer — somebody was in the space
    /// all month and paid nothing — and a historical member who paid in this month is
    /// included whether or not they are still active.
    var hasMemberRow: Bool { !memberTotals.isEmpty }
    var hasUnresolved: Bool { unresolvedCount > 0 }
    var hasUnattributed: Bool { unattributedMinor != 0 }

    // MARK: - Money, always in this space's own currency

    var currencySymbol: String { SharedMoney.symbol(currencyCode) }

    func money(_ minor: Int64) -> String {
        let sign = minor < 0 ? "\u{2212}" : ""
        return sign + currencySymbol + SharedMoney.formattedMajor(Swift.abs(minor), currency: currencyCode)
    }

    // MARK: - Building

    /// One section per space that did anything in the month, in the order the spaces were
    /// given. Spaces are never merged: two spaces in two currencies are two months of
    /// somebody's life, not one number.
    static func sections(for month: Date,
                         spaces: [SharedSpace],
                         expenses: [SharedExpense],
                         members: [SharedMember]) -> [SharedRecapSection] {
        spaces.compactMap { space in
            let summary = SharedMonthlySummary.month(of: space, expenses: expenses,
                                                     members: members, now: month)
            // A month with nothing in it is not a page. Unresolved records still count as
            // activity, the same way the space's own month counts them.
            guard summary.transactionCount > 0 else { return nil }
            return SharedRecapSection(summary: summary, spaceName: space.name,
                                      currencyCode: space.currencyCode, month: month,
                                      biggestCategory: biggestCategory(in: space, expenses: expenses, month: month))
        }
    }

    /// The month starts a recap could be opened for, because a space the user can see had
    /// something in it. Put on one calendar so a shared month and a personal month are the
    /// same bucket and cannot both appear for what is one month.
    static func monthsWithActivity(spaces: [SharedSpace],
                                   expenses: [SharedExpense],
                                   on calendar: Calendar) -> [Date] {
        var starts = Set<Date>()
        for space in spaces {
            for expense in expenses where expense.spaceID == space.id {
                guard let start = space.calendar.dateInterval(of: .month, for: expense.date)?.start,
                      let bucket = calendar.dateInterval(of: .month, for: start)?.start else { continue }
                starts.insert(bucket)
            }
        }
        return Array(starts).sorted()
    }

    /// Which category took the most of the month. Counted from the same records the summary
    /// counts, so it cannot name a category the month does not include. Ties break on the
    /// category's own name, because a recap that reshuffles itself between openings is not
    /// a description of anything.
    private static func biggestCategory(in space: SharedSpace,
                                        expenses: [SharedExpense],
                                        month: Date) -> SharedRecapCategory? {
        var totals: [SpendingCategory: Int64] = [:]
        for expense in expenses
        where expense.spaceID == space.id && !expense.isUnresolvedForeign
            && expense.amountMinor > 0
            && expense.category.canonical != .savings
            && space.calendar.isDate(expense.date, equalTo: month, toGranularity: .month) {
            totals[expense.category, default: 0] += expense.amountMinor
        }
        guard let winner = totals.sorted(by: { first, second in
            first.value == second.value ? first.key.rawValue < second.key.rawValue : first.value > second.value
        }).first else { return nil }
        return SharedRecapCategory(category: winner.key, amountMinor: winner.value)
    }
}

/// The category that took the most of a shared month, and how much of it.
struct SharedRecapCategory: Equatable {
    let category: SpendingCategory
    let amountMinor: Int64
}
