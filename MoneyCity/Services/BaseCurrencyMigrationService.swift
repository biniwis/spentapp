import Foundation
import SwiftData

/// Safe migration service when user changes base currency.
///
/// Prevents historical ledger numbers from being silently relabeled (e.g. 10,000 ILS -> €10,000).
/// If financial data exists, converts all monetary amounts using verified FX rates.
/// If no data exists, allows immediate change.
public enum BaseCurrencyMigrationService {

    public enum MigrationError: Error, LocalizedError {
        case rateUnavailable(from: String, to: String)
        case saveFailed

        public var errorDescription: String? {
            switch self {
            case .rateUnavailable(let from, let to):
                return "Exchange rate between \(from) and \(to) is currently unavailable."
            case .saveFailed:
                return "Failed to save migrated financial data."
            }
        }
    }

    /// Checks whether any user financial data currently exists in the store.
    @MainActor
    public static func hasFinancialData(context: ModelContext) -> Bool {
        do {
            let txCount = try context.fetchCount(FetchDescriptor<Transaction>())
            if txCount > 0 { return true }
            let budgetCount = try context.fetchCount(FetchDescriptor<CategoryBudget>())
            if budgetCount > 0 { return true }
            let incomeCount = try context.fetchCount(FetchDescriptor<IncomeSource>())
            if incomeCount > 0 { return true }
            let recurCount = try context.fetchCount(FetchDescriptor<RecurringExpense>())
            if recurCount > 0 { return true }
            let instCount = try context.fetchCount(FetchDescriptor<InstallmentPlan>())
            if instCount > 0 { return true }
            let savingsCount = try context.fetchCount(FetchDescriptor<SavingsGoal>())
            if savingsCount > 0 { return true }
            return false
        } catch {
            return false
        }
    }

    /// Performs the safe currency migration across all monetary models.
    @MainActor
    public static func migrateBaseCurrency(
        from oldBase: CurrencyType,
        to newBase: CurrencyType,
        context: ModelContext
    ) throws {
        guard oldBase != newBase else { return }

        // If no financial data exists, update setting directly without recalculation
        guard hasFinancialData(context: context) else {
            LocalizationManager.shared.baseCurrency = newBase
            return
        }

        // Verify conversion rate exists
        let rate = CurrencyType.convert(amount: 1.0, from: oldBase, to: newBase)
        guard rate > 0, rate.isFinite else {
            throw MigrationError.rateUnavailable(from: oldBase.rawValue, to: newBase.rawValue)
        }

        // 1. Migrate Transactions
        if let transactions = try? context.fetch(FetchDescriptor<Transaction>()) {
            for tx in transactions {
                // If this transaction was originally in the new base currency, restore its exact original value
                if let origAmt = tx.originalAmount,
                   let origCurr = tx.originalCurrency,
                   CurrencyResolutionService.normalizeToISOCode(origCurr) == newBase.rawValue {
                    tx.amount = tx.amount < 0 ? -abs(origAmt) : abs(origAmt)
                    tx.currency = newBase.symbol
                    tx.originalAmount = nil
                    tx.originalCurrency = nil
                    tx.exchangeRate = nil
                } else {
                    let converted = (tx.amount * rate * 100).rounded() / 100
                    tx.amount = converted
                    tx.currency = newBase.symbol
                    if let origAmt = tx.originalAmount, origAmt > 0 {
                        tx.exchangeRate = abs(tx.amount) / origAmt
                    }
                }
            }
        }

        // 2. Migrate CategoryBudgets
        if let budgets = try? context.fetch(FetchDescriptor<CategoryBudget>()) {
            for b in budgets {
                b.monthlyLimit = (b.monthlyLimit * rate * 100).rounded() / 100
            }
        }

        // 3. Migrate IncomeSources
        if let incomes = try? context.fetch(FetchDescriptor<IncomeSource>()) {
            for inc in incomes {
                inc.amount = (inc.amount * rate * 100).rounded() / 100
                inc.currency = newBase.symbol
            }
        }

        // 4. Migrate RecurringExpenses
        if let recurring = try? context.fetch(FetchDescriptor<RecurringExpense>()) {
            for r in recurring {
                r.amount = (r.amount * rate * 100).rounded() / 100
                r.currency = newBase.symbol
            }
        }

        // 5. Migrate InstallmentPlans
        if let plans = try? context.fetch(FetchDescriptor<InstallmentPlan>()) {
            for p in plans {
                p.totalAmount = (p.totalAmount * rate * 100).rounded() / 100
                p.currency = newBase.symbol
            }
        }

        // 6. Migrate SavingsGoals
        if let goals = try? context.fetch(FetchDescriptor<SavingsGoal>()) {
            for g in goals {
                g.targetAmount = (g.targetAmount * rate * 100).rounded() / 100
                g.savedAmount = (g.savedAmount * rate * 100).rounded() / 100
                g.currency = newBase.symbol
            }
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw MigrationError.saveFailed
        }

        // Update active base currency
        LocalizationManager.shared.baseCurrency = newBase
    }
}
