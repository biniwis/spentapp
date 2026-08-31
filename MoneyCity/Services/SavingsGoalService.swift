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

    /// A deposit toward a goal is also a real savings transfer, so it is recorded as one.
    public static func makeDepositTransaction(
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
            buildingId: "savings_sanctuary"
        )
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
