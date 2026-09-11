import Foundation

/// The spending pace states of the Nature Reserve (שמורת הטבע).
public enum ReservePaceState: String, Sendable, CaseIterable {
    case noBudget
    case calm
    case balanced
    case active
    case busy

    public func localizedTitle(isHebrew: Bool) -> String {
        switch self {
        case .noBudget:
            return isHebrew ? "טרם הוגדר תקציב" : "No budget set"
        case .calm:
            return isHebrew ? "קצב רגוע" : "Calm pace"
        case .balanced:
            return isHebrew ? "קצב מאוזן" : "Balanced pace"
        case .active:
            return isHebrew ? "קצב מעט גבוה" : "Slightly ahead"
        case .busy:
            return isHebrew ? "קצב מהיר" : "Fast pace"
        }
    }

    public func localizedDescription(isHebrew: Bool) -> String {
        switch self {
        case .noBudget:
            return isHebrew
                ? "כדי שהשמורה תשקף את קצב החודש, אפשר להגדיר כמה בערך תרצה להוציא בכל חודש."
                : "To have the sanctuary reflect your monthly pace, set a monthly spending target."
        case .calm:
            return isHebrew
                ? "קצב ההוצאות נמוך מהתכנון ביחס לימים שחלפו בחודש."
                : "Spending is running lower than planned for this point in the month."
        case .balanced:
            return isHebrew
                ? "קצב ההוצאות תואם בדיוק את ימי החודש שחלפו."
                : "Spending is tracking closely with the days elapsed this month."
        case .active:
            return isHebrew
                ? "קצב ההוצאות מעט מקדים את התכנון החודשי."
                : "Spending is running slightly ahead of your planned monthly pace."
        case .busy:
            return isHebrew
                ? "קצב ההוצאות מהיר מהתכנון ביחס לזמן שנותר בחודש."
                : "Spending is moving faster than planned for the remaining days."
        }
    }

    /// Normalized visual health index sent to the 3D Diorama (0.0 ... 1.0).
    /// 1.0 = Calm (lush, deep forest/sage green)
    /// 0.78 = Balanced (fresh natural meadow green with wildflowers)
    /// 0.50 = Active (warm summer yellow-green, vibrant energy)
    /// 0.22 = Busy (warm golden-ochre autumn tone, elegant)
    /// 0.70 = No budget (neutral pleasant park)
    public var visualHealthLevel: Double {
        switch self {
        case .noBudget:  return 0.70
        case .calm:      return 1.00
        case .balanced:  return 0.78
        case .active:    return 0.50
        case .busy:      return 0.22
        }
    }
}

/// A clean, decoupled snapshot representing the state of the Nature Reserve.
public struct ReserveSnapshot: Sendable, Equatable {
    public let monthlyBudget: Double
    public let monthlySpent: Double
    public let monthProgressRatio: Double  // 0.0 ... 1.0
    public let budgetUsageRatio: Double    // spent / budget (or 0 if no budget)
    public let state: ReservePaceState
    public let remainingBudget: Double     // max(0, budget - spent)

    public var hasBudget: Bool {
        monthlyBudget > 0
    }

    public init(
        monthlyBudget: Double,
        monthlySpent: Double,
        monthProgressRatio: Double,
        budgetUsageRatio: Double,
        state: ReservePaceState,
        remainingBudget: Double
    ) {
        self.monthlyBudget = monthlyBudget
        self.monthlySpent = monthlySpent
        self.monthProgressRatio = monthProgressRatio
        self.budgetUsageRatio = budgetUsageRatio
        self.state = state
        self.remainingBudget = remainingBudget
    }
}

public enum ReserveStateService {
    /// Pure computation of the Nature Reserve snapshot from authoritative budget and spending inputs.
    public static func computeSnapshot(
        monthlyBudget: Double,
        monthlySpent: Double,
        monthProgressRatio: Double
    ) -> ReserveSnapshot {
        let budget = max(0.0, monthlyBudget)
        let spent = max(0.0, monthlySpent)
        let progress = min(1.0, max(0.0, monthProgressRatio))

        guard budget > 0 else {
            return ReserveSnapshot(
                monthlyBudget: 0,
                monthlySpent: spent,
                monthProgressRatio: progress,
                budgetUsageRatio: 0,
                state: .noBudget,
                remainingBudget: 0
            )
        }

        let usage = spent / budget
        let remaining = max(0.0, budget - spent)

        let state: ReservePaceState
        // Compare budget usage against time progress with an early-month buffer
        if progress <= 0.05 {
            // First 1-2 days of month: normal single transactions shouldn't shock the reserve
            state = usage > 0.15 ? .active : .balanced
        } else {
            let ratio = usage / max(0.05, progress)
            if ratio <= 0.85 {
                state = .calm
            } else if ratio <= 1.15 {
                state = .balanced
            } else if ratio <= 1.45 {
                state = .active
            } else {
                state = .busy
            }
        }

        return ReserveSnapshot(
            monthlyBudget: budget,
            monthlySpent: spent,
            monthProgressRatio: progress,
            budgetUsageRatio: usage,
            state: state,
            remainingBudget: remaining
        )
    }
}
