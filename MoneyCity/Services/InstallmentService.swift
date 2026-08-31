import Foundation

/// What is still owed on a plan.
public struct InstallmentProgress: Sendable {
    public let paid: Int
    public let total: Int
    public let paidAmount: Double
    public let remainingAmount: Double

    public var isComplete: Bool { paid >= total }
    public var remainingPayments: Int { max(0, total - paid) }

    public init(paid: Int, total: Int, paidAmount: Double, remainingAmount: Double) {
        self.paid = paid
        self.total = total
        self.paidAmount = paidAmount
        self.remainingAmount = remainingAmount
    }
}

/// Splitting a purchase into monthly charges.
///
/// Pure and unit-tested, because the two things that go wrong here are silent: the parts
/// not adding back up to the total, and a charge landing in the wrong month.
public enum InstallmentService {

    public static let maxPayments = 36

    /// Splits a total into `count` charges that sum back to it exactly.
    ///
    /// Works in agorot to avoid floating-point drift, and puts the rounding remainder in
    /// the first payment — the same convention Israeli card issuers use.
    public static func paymentAmounts(total: Double, count: Int) -> [Double] {
        guard count > 0, total > 0 else { return [] }
        let units = Int((total * 100).rounded())
        guard units > 0 else { return [] }

        let base = units / count
        let remainder = units % count

        return (0..<count).map { index in
            Double(base + (index == 0 ? remainder : 0)) / 100.0
        }
    }

    /// One charge date per payment, a month apart, with the day clamped into short months.
    public static func chargeDates(
        firstCharge: Date,
        count: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0 else { return [] }
        let day = calendar.component(.day, from: firstCharge)

        return (0..<count).compactMap { offset in
            guard let monthAnchor = calendar.date(byAdding: .month, value: offset, to: firstCharge),
                  let range = calendar.range(of: .day, in: .month, for: monthAnchor)
            else { return nil }

            var comps = calendar.dateComponents([.year, .month], from: monthAnchor)
            comps.day = min(day, range.count)
            comps.hour = 9
            return calendar.date(from: comps)
        }
    }

    /// The transactions a plan produces — one per payment, dated when it will be charged.
    public static func makeTransactions(
        for plan: InstallmentPlan,
        calendar: Calendar = .current
    ) -> [Transaction] {
        let amounts = paymentAmounts(total: plan.totalAmount, count: plan.numberOfPayments)
        let dates = chargeDates(firstCharge: plan.firstChargeDate, count: plan.numberOfPayments, calendar: calendar)
        guard amounts.count == dates.count else { return [] }

        let building = CategorizationEngine.shared.mapToBuildingId(
            category: plan.category,
            merchant: plan.merchant
        )

        return zip(amounts.indices, zip(amounts, dates)).map { index, pair in
            let (amount, date) = pair
            return Transaction(
                amount: amount,
                currency: plan.currency,
                merchant: plan.merchant,
                category: plan.category,
                timestamp: date,
                confidenceScore: 1.0,
                isManual: true,
                isConfirmed: true,
                note: "תשלום \(index + 1) מתוך \(plan.numberOfPayments)",
                buildingId: building
            )
        }
    }

    /// How far along a plan is, as of a given date.
    public static func progress(
        for plan: InstallmentPlan,
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> InstallmentProgress {
        let amounts = paymentAmounts(total: plan.totalAmount, count: plan.numberOfPayments)
        let dates = chargeDates(firstCharge: plan.firstChargeDate, count: plan.numberOfPayments, calendar: calendar)

        var paid = 0
        var paidAmount = 0.0
        for (index, date) in dates.enumerated() where date <= now {
            paid += 1
            if index < amounts.count { paidAmount += amounts[index] }
        }

        return InstallmentProgress(
            paid: paid,
            total: plan.numberOfPayments,
            paidAmount: paidAmount,
            remainingAmount: max(0, plan.totalAmount - paidAmount)
        )
    }

    /// Total still owed across every open plan — the commitment a monthly budget hides.
    public static func totalOutstanding(
        plans: [InstallmentPlan],
        asOf now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        plans.reduce(0) { $0 + progress(for: $1, asOf: now, calendar: calendar).remainingAmount }
    }
}
