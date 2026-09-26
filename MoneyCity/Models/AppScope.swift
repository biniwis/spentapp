import Foundation
import SwiftUI
import Combine

/// Represents the active data scope/workspace of the application.
public enum AppScope: Equatable, Hashable {
    case personal
    case shared(spaceID: UUID)

    public var isShared: Bool {
        if case .shared = self { return true }
        return false
    }

    public var spaceID: UUID? {
        if case let .shared(id) = self { return id }
        return nil
    }
}

/// Declares feature availability based on the active scope.
public struct ScopeCapabilities: Equatable {
    public let hasBudget: Bool
    public let hasSavings: Bool
    public let hasRecurring: Bool
    public let hasPayerSelection: Bool
    public let hasMemberManagement: Bool
    public let canWrite: Bool
    public let isShared: Bool

    public static let personal = ScopeCapabilities(
        hasBudget: true,
        hasSavings: true,
        hasRecurring: true,
        hasPayerSelection: false,
        hasMemberManagement: false,
        canWrite: true,
        isShared: false
    )

    public static func shared(canWrite: Bool) -> ScopeCapabilities {
        ScopeCapabilities(
            hasBudget: false,
            hasSavings: false,
            hasRecurring: false,
            hasPayerSelection: true,
            hasMemberManagement: true,
            canWrite: canWrite,
            isShared: true
        )
    }
}

#if !SWIFT_PACKAGE
@MainActor
public final class AppScopeContext: ObservableObject {
    public static let shared = AppScopeContext(store: .shared)

    /// The active scope. Defaults strictly to .personal on cold launch.
    @Published public private(set) var activeScope: AppScope = .personal

    private let store: SharedWorkspaceStore
    private var subscriptions = Set<AnyCancellable>()
    init(store: SharedWorkspaceStore) {
        self.store = store
        store.$activeSpaceID.removeDuplicates().sink { [weak self] id in
            self?.activeScope = id.map { .shared(spaceID: $0) } ?? .personal
        }.store(in: &subscriptions)
        store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &subscriptions)
    }

    public var capabilities: ScopeCapabilities {
        switch activeScope {
        case .personal:
            return .personal
        case let .shared(spaceID):
            let canWrite = store.canWrite(spaceID)
            return .shared(canWrite: canWrite)
        }
    }

    var currentSpace: SharedSpace? {
        guard case let .shared(id) = activeScope else { return nil }
        return store.spaces.first { $0.id == id }
    }

    public var displayName: String {
        switch activeScope {
        case .personal:
            return LocalizationManager.shared.isHebrew ? "העיר שלי" : "My City"
        case .shared:
            return currentSpace?.name ?? (LocalizationManager.shared.isHebrew ? "מרחב משותף" : "Shared Space")
        }
    }

    public var calendar: Calendar {
        currentSpace?.calendar ?? Calendar.current
    }

    public var currencyCode: String {
        currentSpace?.currencyCode ?? (UserDefaults.standard.string(forKey: "app_currency_pref") ?? "ILS")
    }

    /// The active scope's monthly spending target, in minor units of that scope's currency.
    ///
    /// Shared reads only `SharedSpace.monthlyBudgetMinor`, in the space's own currency.
    /// There is deliberately no fallback in either direction: a space with no target
    /// reports none instead of borrowing the personal `monthly_budget`, and the personal
    /// budget keeps living in its existing `BudgetService` path untouched. Personal
    /// returns `nil` here on purpose — callers that want the personal number must ask for
    /// it, so the two can never be confused for each other.
    var sharedMonthlyTargetMinor: Int64? {
        currentSpace?.monthlyTarget
    }

    /// The active scope's shared currency. `nil` in personal, where amounts are not in a
    /// space's currency and must not be formatted as if they were.
    var sharedCurrencyCode: String? {
        currentSpace?.currencyCode
    }

    /// The active space's month, or `nil` in personal scope.
    ///
    /// Built from the local store, never from the network: a target saved offline has to
    /// show up immediately, so the profile never waits on a sync round trip.
    var sharedMonthSummary: SharedMonthlySummary? {
        sharedMonthSummary(for: Date())
    }

    /// The active space's month containing `date`, or `nil` in personal scope.
    ///
    /// Analytics browses months, so it cannot use the current month alone: a target read
    /// for today would sit above last month's spending. The date decides the month in the
    /// space's own calendar, and the arithmetic is the same single engine the profile uses.
    func sharedMonthSummary(for date: Date) -> SharedMonthlySummary? {
        guard let space = currentSpace else { return nil }
        return SharedMonthlySummary.month(of: space, expenses: store.expenses, members: store.members, now: date)
    }

    public func selectPersonal() {
        store.select(nil)
    }

    public func selectShared(spaceID: UUID) {
        store.select(spaceID)
    }

    public func allExpenses(personalTransactions: [Transaction]) -> [ExpenseSnapshot] {
        guard case let .shared(id) = activeScope else { return personalTransactions.map(ExpenseSnapshot.init) }
        guard let space = currentSpace else { return [] }
        return store.expenses
            .filter { $0.spaceID == id && $0.currencyCode == space.currencyCode }
            .map {
                var snapshot = ExpenseSnapshot($0)
                snapshot.timeZoneID = space.timeZoneID
                return snapshot
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Provides normalized ExpenseSnapshots for the active scope and specified month.
    public func expenses(for month: Date, personalTransactions: [Transaction]) -> [ExpenseSnapshot] {
        switch activeScope {
        case .personal:
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: month)
            return personalTransactions.compactMap { tx in
                let txComps = cal.dateComponents([.year, .month], from: tx.timestamp)
                guard txComps.year == comps.year && txComps.month == comps.month else { return nil }
                return ExpenseSnapshot(tx)
            }

        case let .shared(spaceID):
            guard let space = currentSpace,
                  let interval = space.calendar.dateInterval(of: .month, for: month) else { return [] }
            return store.expenses
                .filter { $0.spaceID == spaceID && $0.currencyCode == space.currencyCode && interval.contains($0.date) }
                .map {
                var snapshot = ExpenseSnapshot($0)
                snapshot.timeZoneID = space.timeZoneID
                return snapshot
            }
        }
    }

    /// Everything the city needs to describe a shared month, read once from that space's
    /// own ledger.
    ///
    /// The city used to be handed a constant budget and a constant park, so a shared space
    /// had a garden that never moved and a plan nothing could be measured against. Reading
    /// the month once — the same reading the profile and analytics get — means the city,
    /// the numbers beside it and the ledger cannot disagree, and a target that was never
    /// set stays absent instead of turning into a real-looking zero.
    ///
    /// `nil` in personal scope, where the personal city has its own budget history and must
    /// never borrow a space's numbers.
    func sharedCityContext(for date: Date) -> SharedCityContext? {
        guard let space = currentSpace, let summary = sharedMonthSummary(for: date) else { return nil }
        return SharedCityContext(space: space, summary: summary)
    }

    /// Participants for the currently active space (empty for personal).
    var participants: [SharedMember] {
        guard case let .shared(spaceID) = activeScope else { return [] }
        return store.members.filter { $0.spaceID == spaceID }
    }
}

/// A shared month, prepared for the city in one reading.
///
/// The conversion between the ledger's minor units and the renderer's whole currency units
/// happens here, once, so no view has to remember which of the two it is holding — the
/// mistake the old hardcoded budget was hiding behind.
struct SharedCityContext: Equatable {
    let spaceID: UUID
    let currencyCode: String
    /// The world this space lives in, carried from the space itself.
    let mapStyle: String
    /// The space's monthly target in minor units, or nil when it has not set one.
    let monthlyTargetMinor: Int64?
    /// Resolved spending this month, signed, in minor units.
    let monthlySpentMinor: Int64
    /// What the month has done to that target, including the case where there is no target.
    let park: SharedParkState
    /// Active members with the colors the city should use for them. Read from the summary
    /// rather than the member list so somebody who has left the space stops colouring it.
    let members: [SharedMemberTotal]

    /// The target in whole currency units, or nil when the space has not set one.
    var monthlyTargetMajor: Double? {
        guard let monthlyTargetMinor, monthlyTargetMinor > 0 else { return nil }
        return SharedMoney.major(monthlyTargetMinor, currency: currencyCode)
    }

    /// The only way to build one from live data: a space and a reading of that same space's
    /// month.
    ///
    /// Taking both together is the point. A context assembled from two different sources
    /// could describe a target from one space and a park from another, and nothing in the
    /// city would notice.
    init(space: SharedSpace, summary: SharedMonthlySummary) {
        self.init(spaceID: space.id,
                  currencyCode: space.currencyCode,
                  mapStyle: space.mapStyle,
                  monthlyTargetMinor: summary.progress.targetMinor,
                  monthlySpentMinor: summary.progress.spentMinor,
                  park: SharedParkState(fraction: summary.progress.fraction),
                  members: summary.memberTotals)
    }

    init(spaceID: UUID, currencyCode: String, mapStyle: String, monthlyTargetMinor: Int64?,
         monthlySpentMinor: Int64, park: SharedParkState, members: [SharedMemberTotal]) {
        self.spaceID = spaceID
        self.currencyCode = currencyCode
        self.mapStyle = mapStyle
        self.monthlyTargetMinor = monthlyTargetMinor
        self.monthlySpentMinor = monthlySpentMinor
        self.park = park
        self.members = members
    }
}

#endif

extension LocalizationManager {
    /// Shared amounts already use the ledger currency. Never convert them to the personal currency.
    public func formatScoped(amount: Double, showDecimals: Bool = false) -> String {
        #if !SWIFT_PACKAGE
        if let space = AppScopeContext.shared.currentSpace {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = space.currencyCode
            formatter.locale = Locale(identifier: isHebrew ? "he_IL" : "en_US")
            formatter.minimumFractionDigits = showDecimals ? SharedMoney.digits(space.currencyCode) : 0
            formatter.maximumFractionDigits = formatter.minimumFractionDigits
            return "\u{2068}" + (formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(space.currencyCode)") + "\u{2069}"
        }
        #endif
        return format(amount: amount, showDecimals: showDecimals)
    }

    /// A shared amount from minor units, in the space's own currency.
    ///
    /// Decimals appear only when the currency has them *and* the value carries a fraction,
    /// so ₪5,860 stays ₪5,860, ₪5,860.50 keeps its cents, and ¥5,000 is not handed
    /// phantom decimals. One definition, used by every surface that reports shared money.
    func formatScopedMinor(_ minor: Int64, currency: String) -> String {
        let major = SharedMoney.major(minor, currency: currency)
        let hasFraction = SharedMoney.digits(currency) > 0 && major != major.rounded()
        return formatScoped(amount: major, showDecimals: hasFraction)
    }
}
