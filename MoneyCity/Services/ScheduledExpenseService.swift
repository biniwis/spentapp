import Foundation
import SwiftData

/// Materializes one-time scheduled expenses into real Transactions when their due date arrives.
public enum ScheduledExpenseService {

    /// Materializes all due scheduled expenses whose scheduled date has arrived and that haven't been materialized yet.
    /// Safe to call on every launch and app-active transition (idempotent).
    @MainActor
    @discardableResult
    public static func materializeDue(
        now: Date = Date(),
        context: ModelContext,
        calendar: Calendar = .current
    ) -> Int {
        let descriptor = FetchDescriptor<ScheduledExpense>()
        guard let scheduled = try? context.fetch(descriptor), !scheduled.isEmpty else {
            return 0
        }

        let todayStart = calendar.startOfDay(for: now)
        let unmaterialized = scheduled.filter { expense in
            guard expense.materializedAt == nil else { return false }
            let expenseDayStart = calendar.startOfDay(for: expense.scheduledFor)
            return expenseDayStart <= todayStart
        }

        guard !unmaterialized.isEmpty else { return 0 }

        // Fetch existing transactions in the relevant date window to guarantee idempotency
        let minDate = unmaterialized.map(\.scheduledFor).min() ?? now
        let horizon = calendar.startOfDay(for: minDate)
        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= horizon }
        )
        let existingTxs = (try? context.fetch(txDescriptor)) ?? []

        var created = 0

        for expense in unmaterialized {
            // If already associated with an existing transaction, mark as materialized and skip duplicate creation
            if let matId = expense.materializedTransactionId,
               existingTxs.contains(where: { $0.id == matId }) {
                if expense.materializedAt == nil {
                    expense.materializedAt = now
                }
                continue
            }

            let finalBuildingId = expense.buildingIdRaw ?? CategorizationEngine.shared.mapToBuildingId(
                category: expense.category,
                merchant: expense.merchant
            )

            let tx = Transaction(
                amount: expense.amount,
                currency: expense.currency,
                merchant: expense.merchant,
                category: expense.category,
                timestamp: expense.scheduledFor,
                confidenceScore: 1.0,
                isManual: true,
                isConfirmed: true,
                note: nil,
                buildingId: finalBuildingId,
                originalAmount: expense.originalAmount,
                originalCurrency: expense.originalCurrency,
                exchangeRate: expense.exchangeRate
            )

            context.insert(tx)
            expense.materializedAt = now
            expense.materializedTransactionId = tx.id
            created += 1
        }

        do {
            try context.save()
            return created
        } catch {
            MoneyCityLog.error("ScheduledExpenseService: save failed: \(error)")
            context.rollback()
            return 0
        }
    }
}
