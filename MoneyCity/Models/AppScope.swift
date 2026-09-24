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

@MainActor
public final class AppScopeContext: ObservableObject {
    public static let shared = AppScopeContext()

    /// The active scope. Defaults strictly to .personal on cold launch.
    @Published public private(set) var activeScope: AppScope = .personal

    private init() {
        // Enforce constraint 6: Fresh/cold launch must always enter Personal.
        self.activeScope = .personal
    }

    public var capabilities: ScopeCapabilities {
        switch activeScope {
        case .personal:
            return .personal
        case let .shared(spaceID):
            let canWrite = SharedWorkspaceStore.shared.canWrite(spaceID)
            return .shared(canWrite: canWrite)
        }
    }

    var currentSpace: SharedSpace? {
        guard case let .shared(id) = activeScope else { return nil }
        return SharedWorkspaceStore.shared.spaces.first { $0.id == id }
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

    public func selectPersonal() {
        activeScope = .personal
        SharedWorkspaceStore.shared.select(nil)
    }

    public func selectShared(spaceID: UUID) {
        activeScope = .shared(spaceID: spaceID)
        SharedWorkspaceStore.shared.select(spaceID)
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
            return SharedWorkspaceStore.shared.expenses
                .filter { $0.spaceID == spaceID && $0.currencyCode == space.currencyCode && interval.contains($0.date) }
                .map(ExpenseSnapshot.init)
        }
    }

    /// Participants for the currently active space (empty for personal).
    var participants: [SharedMember] {
        guard case let .shared(spaceID) = activeScope else { return [] }
        return SharedWorkspaceStore.shared.members.filter { $0.spaceID == spaceID }
    }
}
