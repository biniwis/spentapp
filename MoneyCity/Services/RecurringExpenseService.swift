import Foundation
import SwiftData

/// Turns fixed-expense templates into real transactions.
///
/// The scheduling half is deliberately pure and calendar-driven so it can be tested
/// without a database — getting "the 31st in February" or "the app wasn't opened for
/// three months" wrong would put invented or missing money in the user's city.
public enum RecurringExpenseService {

    /// Never back-fill more than a year, even if a template has been dormant far longer.
    public static let maxCatchUpMonths = 12

    // MARK: - Period helpers

    /// "yyyy-MM" — stable, sortable, and locale-independent.
    public static func periodKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    public static func components(ofPeriod period: String) -> (year: Int, month: Int)? {
        let parts = period.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              (1...12).contains(m) else { return nil }
        return (y, m)
    }

    /// The actual date a template fires in a given month, clamping a day that the
    /// month does not have — day 31 in February becomes the 28th (or 29th).
    public static func occurrenceDate(
        period: String,
        dayOfMonth: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard let (year, month) = components(ofPeriod: period) else { return nil }
        var monthStart = DateComponents()
        monthStart.year = year
        monthStart.month = month
        monthStart.day = 1
        guard let firstOfMonth = calendar.date(from: monthStart),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = min(max(1, dayOfMonth), range.count)
        comps.hour = 9
        return calendar.date(from: comps)
    }

    private static func nextPeriod(after period: String) -> String? {
        guard let (year, month) = components(ofPeriod: period) else { return nil }
        return month == 12
            ? String(format: "%04d-01", year + 1)
            : String(format: "%04d-%02d", year, month + 1)
    }

    private static func period(_ period: String, offsetByMonths delta: Int) -> String? {
        guard let (year, month) = components(ofPeriod: period) else { return nil }
        let zeroBased = year * 12 + (month - 1) + delta
        guard zeroBased >= 0 else { return nil }
        return String(format: "%04d-%02d", zeroBased / 12, zeroBased % 12 + 1)
    }

    // MARK: - Scheduling

    /// Every month this template still owes, oldest first.
    ///
    /// A month is owed once its occurrence date has passed. The template's own creation
    /// month is included even if the day already went by, because that charge did happen —
    /// duplicate protection at insert time is what stops it colliding with a manual entry.
    public static func duePeriods(
        lastGeneratedPeriod: String?,
        createdAt: Date,
        dayOfMonth: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        let currentPeriod = periodKey(for: now, calendar: calendar)

        // A marker ahead of today means the device clock was set forward once. Treat it
        // as last month so the template resumes now, instead of staying silent until that
        // month actually arrives. ("yyyy-MM" is fixed width, so string order is date order.)
        var effectiveLast = lastGeneratedPeriod
        if let last = effectiveLast, last > currentPeriod {
            effectiveLast = period(currentPeriod, offsetByMonths: -1)
        }

        var cursor: String
        if let last = effectiveLast, let next = nextPeriod(after: last) {
            cursor = next
        } else {
            cursor = periodKey(for: createdAt, calendar: calendar)
        }

        // A template dormant for years must resume near the present, not replay its history.
        // "yyyy-MM" sorts lexicographically, so a string compare is the month compare.
        if let earliest = period(currentPeriod, offsetByMonths: -(maxCatchUpMonths - 1)),
           cursor < earliest {
            cursor = earliest
        }

        var result: [String] = []
        var guardCount = 0

        while guardCount < maxCatchUpMonths * 2 {
            guardCount += 1
            guard let (cy, cm) = components(ofPeriod: cursor),
                  let (ny, nm) = components(ofPeriod: currentPeriod) else { break }
            // Stop once the cursor moves past the current month.
            if (cy, cm) > (ny, nm) { break }

            if let occurrence = occurrenceDate(period: cursor, dayOfMonth: dayOfMonth, calendar: calendar),
               occurrence <= now {
                result.append(cursor)
            }

            guard let next = nextPeriod(after: cursor) else { break }
            cursor = next
        }

        return Array(result.suffix(maxCatchUpMonths))
    }

    /// True when this month already holds the same charge — same merchant AND same amount.
    ///
    /// Merchant alone is not enough: a ₪75 Netflix gift card bought with Apple Pay would
    /// otherwise cancel that month's ₪54.90 subscription charge, and because the marker
    /// advances it would never be reconsidered.
    public static func alreadyRecorded(
        merchant: String,
        amount: Double,
        period: String,
        in transactions: [Transaction],
        calendar: Calendar = .current
    ) -> Bool {
        let key = merchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return transactions.contains { tx in
            tx.merchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == key
                && abs(tx.amount - amount) < 0.01
                && periodKey(for: tx.timestamp, calendar: calendar) == period
        }
    }

    /// Builds the transaction for one due month, or nil if that month is already covered.
    public static func makeTransaction(
        for template: RecurringExpense,
        period: String,
        existing: [Transaction],
        calendar: Calendar = .current
    ) -> Transaction? {
        guard !alreadyRecorded(merchant: template.merchant, amount: template.amount, period: period, in: existing, calendar: calendar),
              let date = occurrenceDate(period: period, dayOfMonth: template.dayOfMonth, calendar: calendar)
        else { return nil }

        return Transaction(
            amount: template.amount,
            currency: template.currency,
            merchant: template.merchant,
            category: template.category,
            timestamp: date,
            confidenceScore: 1.0,
            isManual: true,
            isConfirmed: true,
            note: "הוצאה קבועה",
            buildingId: CategorizationEngine.shared.mapToBuildingId(
                category: template.category,
                merchant: template.merchant
            )
        )
    }

    // MARK: - Database side

    /// Materialises everything owed. Safe to call on every launch.
    @MainActor
    @discardableResult
    public static func materializeDue(
        now: Date = Date(),
        context: ModelContext,
        calendar: Calendar = .current
    ) -> Int {
        let templateDescriptor = FetchDescriptor<RecurringExpense>()
        guard let templates = try? context.fetch(templateDescriptor), !templates.isEmpty else {
            return 0
        }

        // Only the catch-up window can matter, so do not drag the whole history onto
        // the main thread at launch.
        let horizon = calendar.date(byAdding: .month, value: -(maxCatchUpMonths + 1), to: now) ?? now
        let existingDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= horizon }
        )
        var existing = (try? context.fetch(existingDescriptor)) ?? []

        // A pause means "skip these months", not "owe them later". Without this, resuming
        // a template paused for the summer posts every paused month at once.
        for template in templates where !template.isActive {
            template.lastGeneratedPeriod = periodKey(for: now, calendar: calendar)
        }

        var created = 0
        for template in templates where template.isActive {
            let periods = duePeriods(
                lastGeneratedPeriod: template.lastGeneratedPeriod,
                createdAt: template.createdAt,
                dayOfMonth: template.dayOfMonth,
                now: now,
                calendar: calendar
            )

            for period in periods {
                if let tx = makeTransaction(
                    for: template,
                    period: period,
                    existing: existing,
                    calendar: calendar
                ) {
                    context.insert(tx)
                    existing.append(tx)
                    created += 1
                    template.lastGeneratedPeriod = period
                } else if alreadyRecorded(
                    merchant: template.merchant,
                    amount: template.amount,
                    period: period,
                    in: existing,
                    calendar: calendar
                ) {
                    // Genuinely already covered, so this month is settled.
                    template.lastGeneratedPeriod = period
                }
                // Any other failure leaves the marker alone so the month is retried.
            }
        }

        do {
            try context.save()
        } catch {
            // Never report a phantom success — the caller shows the user a confirmation.
            MoneyCityLog.error("RecurringExpenseService: save failed: \(error)")
            return 0
        }
        return created
    }
}
