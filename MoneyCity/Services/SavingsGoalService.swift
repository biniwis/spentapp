import Foundation

/// Pure goal maths — progress, pace, and whether the user is on track.
public enum SavingsGoalService {

    /// 0…1. A goal with no target has no meaningful progress rather than infinite progress.
    public static func fraction(saved: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(1.0, max(0, saved / target))
    }

    public static func remaining(saved: Double, target: Double) -> Double {
        max(0, target - saved)
    }

    /// Whole months from `now` until the target date, counting the current month as one.
    /// Returns nil when there is no deadline, and 1 once the deadline is here or past —
    /// "you need the rest this month" is more useful than a division by zero.
    public static func monthsRemaining(
        until targetDate: Date?,
        from now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let targetDate else { return nil }
        let start = calendar.dateComponents([.year, .month], from: now)
        let end = calendar.dateComponents([.year, .month], from: targetDate)
        guard let sy = start.year, let sm = start.month, let ey = end.year, let em = end.month else { return nil }
        let months = (ey * 12 + em) - (sy * 12 + sm)
        return max(1, months + 1)
    }

    /// What the user has to put aside each month to land on time.
    public static func monthlyContributionNeeded(
        saved: Double,
        target: Double,
        targetDate: Date?,
        from now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double? {
        let left = remaining(saved: saved, target: target)
        guard left > 0, let months = monthsRemaining(until: targetDate, from: now, calendar: calendar) else { return nil }
        return left / Double(months)
    }

    /// A deposit toward a goal is also a real savings transfer, so it is recorded as one —
    /// carrying the goal's id, so the two records can never disagree about what happened.
    public static func makeDepositTransaction(
        goalId: UUID,
        goalName: String,
        amount: Double,
        currency: String,
        date: Date = Date()
    ) -> Transaction {
        Transaction(
            amount: amount,
            currency: currency,
            merchant: goalName,
            category: .savings,
            timestamp: date,
            confidenceScore: 1.0,
            isManual: true,
            isConfirmed: true,
            note: "הפקדה ליעד חיסכון",
            buildingId: "savings_sanctuary",
            savingsGoalId: goalId
        )
    }

    // MARK: - Reconciliation

    /// What a goal should hold, given the deposits that still exist.
    ///
    /// Pure so the rule can be tested without a store: the banked baseline plus every
    /// surviving linked transfer. Deleting a deposit from history therefore lowers the
    /// goal by exactly that deposit, and editing one moves it by exactly the difference.
    public static func reconciledAmount(baseline: Double, linkedDeposits: [Double]) -> Double {
        max(0, baseline) + linkedDeposits.reduce(0, +)
    }

    /// Recomputes each goal from the deposits that still exist, and reports whether
    /// anything moved.
    ///
    /// The goal's total used to be a second, independent copy of the money: a deposit
    /// incremented `savedAmount` and separately inserted a transaction, with nothing tying
    /// them together. Deleting the transfer from history shrank the city's savings park and
    /// left the goal bar untouched — and a goal could stay "complete", holding a permanent
    /// landmark, on deposits the user had since removed.
    ///
    /// A goal that predates the link has deposits that cannot be identified any more, so
    /// the first pass banks its current total as a baseline instead of wiping it.
    @discardableResult
    public static func reconcile(goals: [SavingsGoal], transactions: [Transaction]) -> Bool {
        guard !goals.isEmpty else { return false }

        var depositsByGoal: [UUID: [Double]] = [:]
        for tx in transactions {
            guard let goalId = tx.savingsGoalId else { continue }
            depositsByGoal[goalId, default: []].append(tx.amount)
        }

        var changed = false
        for goal in goals {
            if !goal.baselineCaptured {
                // Everything it holds today came from deposits that were never linked.
                goal.unlinkedBaseline = max(0, goal.savedAmount - (depositsByGoal[goal.id]?.reduce(0, +) ?? 0))
                goal.baselineCaptured = true
                changed = true
            }
            let expected = reconciledAmount(
                baseline: goal.unlinkedBaseline,
                linkedDeposits: depositsByGoal[goal.id] ?? []
            )
            if abs(goal.savedAmount - expected) > 0.005 {
                goal.savedAmount = expected
                changed = true
            }
            // `completedAt` is deliberately left alone. Clearing it would let the goal be
            // "completed" a second time and insert the same landmark twice; the progress
            // the user sees comes from `savedAmount`, which is now correct either way.
        }
        return changed
    }

    /// The landmark a finished goal earns in the city, reusing the enrichment machinery
    /// the weekly-progress feature already feeds into the diorama.
    public static func makeCompletionEnrichment(for goal: SavingsGoal) -> CityEnrichment {
        CityEnrichment(
            itemId: "goal_\(goal.id.uuidString.prefix(8))",
            name: goal.name,
            subtitle: "יעד חיסכון שהושלם",
            icon: goal.icon,
            type: .landmark,
            tier: "large",
            savedAmount: goal.targetAmount,
            districtId: "savings"
        )
    }
}
