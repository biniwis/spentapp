import Foundation

/// How a category is doing against its ceiling.
public enum BudgetStatus: String, Sendable {
    case noBudget      // the user has not set a limit for this category
    case under
    case approaching   // at or past the warning threshold, still inside the limit
    case over
}

/// One category's month so far, measured against its ceiling.
public struct BudgetUsage: Identifiable, Sendable {
    public let category: SpendingCategory
    public let limit: Double
    public let spent: Double

    public var id: String { category.rawValue }

    /// Never negative — "you are ₪120 over" is carried by `overspend`, not by a negative remainder.
    public var remaining: Double { max(0, limit - spent) }
    public var overspend: Double { max(0, spent - limit) }

    /// 0…1 for display. A category with no ceiling has no meaningful fraction.
    public var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, spent / limit)
    }

    public var status: BudgetStatus {
        guard limit > 0 else { return .noBudget }
        if spent > limit { return .over }
        if spent >= limit * BudgetService.warningThreshold { return .approaching }
        return .under
    }

    public init(category: SpendingCategory, limit: Double, spent: Double) {
        self.category = category
        self.limit = limit
        self.spent = spent
    }
}

/// The month's shape: what came in, what went out, what is left.
public struct CashFlow: Sendable {
    public let income: Double
    public let spent: Double
    public let savedToSavings: Double

    /// What is genuinely unspent — income minus everything that left, transfers included.
    public var leftover: Double { max(0, income - spent - savedToSavings) }

    public init(income: Double, spent: Double, savedToSavings: Double) {
        self.income = income
        self.spent = spent
        self.savedToSavings = savedToSavings
    }
}

/// Pure budget maths. Kept free of SwiftData so every rule here is testable.
public enum BudgetService {

    /// Warn once a category passes this share of its ceiling.
    public static let warningThreshold: Double = 0.8

    // MARK: - Spending

    /// Spend per category for a set of transactions, with legacy aliases collapsed and
    /// savings transfers excluded — they are not spending.
    public static func spentByCategory(_ transactions: [Transaction]) -> [SpendingCategory: Double] {
        var totals: [SpendingCategory: Double] = [:]
        for tx in transactions where tx.category.canonical != .savings {
            totals[tx.category.canonical, default: 0] += tx.amount
        }
        return totals
    }

    public static func totalSpent(_ transactions: [Transaction]) -> Double {
        transactions.filter { $0.category.canonical != .savings }.reduce(0) { $0 + $1.amount }
    }

    public static func totalSavedToSavings(_ transactions: [Transaction]) -> Double {
        transactions.filter { $0.category.canonical == .savings }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Income

    /// Expected income for a month from the user's active sources.
    public static func expectedMonthlyIncome(_ sources: [IncomeSource]) -> Double {
        sources.filter(\.isActive).reduce(0) { $0 + $1.amount }
    }

    // MARK: - The monthly spending plan

    /// The one definition of "what I plan to spend this month".
    ///
    /// Three screens used to answer this question three different ways: the city took the
    /// user's income, the profile ring took the sum of the category ceilings, and a field
    /// buried in Settings held a third number almost nothing read. That is why the budget
    /// screen felt broken — editing it moved none of the things it appeared to control.
    ///
    /// Income is deliberately not part of the answer. Using income as a spending budget
    /// means spending every shekel you earn reads as perfectly on pace, which is the
    /// opposite of what this app is for. Income stays what it is: the ceiling the plan
    /// should fit inside.
    ///
    /// Priority: the ceilings the user set per category, because that is the most
    /// deliberate statement of intent; then the single overall figure; then nothing, and
    /// callers fall back to what the user's past months actually cost.
    public static func monthlySpendingBudget(
        categoryBudgets: [CategoryBudget],
        overallBudget: Double
    ) -> Double {
        var ceilings: [SpendingCategory: Double] = [:]
        for budget in categoryBudgets where budget.monthlyLimit > 0 {
            let key = budget.category.canonical
            guard key != .savings else { continue }
            ceilings[key] = max(ceilings[key] ?? 0, budget.monthlyLimit)
        }
        let total = ceilings.values.reduce(0, +)
        if total > 0 { return total }
        return max(0, overallBudget)
    }

    // MARK: - Usage

    /// One row per category the user has actually budgeted, ordered by urgency:
    /// overspent first, then closest to the limit.
    public static func usages(
        budgets: [CategoryBudget],
        transactions: [Transaction]
    ) -> [BudgetUsage] {
        let spend = spentByCategory(transactions)

        // Guard against two rows for the same canonical category (legacy data, or a race
        // that created a duplicate) by keeping the larger ceiling rather than showing both.
        var limits: [SpendingCategory: Double] = [:]
        for budget in budgets where budget.monthlyLimit > 0 {
            let key = budget.category.canonical
            limits[key] = max(limits[key] ?? 0, budget.monthlyLimit)
        }

        return limits
            .map { BudgetUsage(category: $0.key, limit: $0.value, spent: spend[$0.key] ?? 0) }
            .sorted { lhs, rhs in
                if (lhs.status == .over) != (rhs.status == .over) { return lhs.status == .over }
                if lhs.fraction != rhs.fraction { return lhs.fraction > rhs.fraction }
                return lhs.category.rawValue < rhs.category.rawValue
            }
    }

    /// Categories that just crossed the warning line or the limit — what a notification says.
    public static func needingAttention(_ usages: [BudgetUsage]) -> [BudgetUsage] {
        usages.filter { $0.status == .over || $0.status == .approaching }
    }

    // MARK: - Cash flow

    public static func cashFlow(income: Double, transactions: [Transaction]) -> CashFlow {
        CashFlow(
            income: income,
            spent: totalSpent(transactions),
            savedToSavings: totalSavedToSavings(transactions)
        )
    }

    // MARK: - Forecast

    /// Projects the month's end from the pace so far.
    ///
    /// Returns nil before there is enough of a month to extrapolate from — a single day's
    /// spending multiplied by thirty is a number that would only mislead.
    public static func projectedMonthEnd(
        spentSoFar: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double? {
        guard spentSoFar > 0 else { return nil }
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return nil }
        let dayOfMonth = calendar.component(.day, from: now)
        guard dayOfMonth >= 5 else { return nil }
        let daysInMonth = Double(range.count)
        return spentSoFar / Double(dayOfMonth) * daysInMonth
    }
}
