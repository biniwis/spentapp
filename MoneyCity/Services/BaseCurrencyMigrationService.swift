import Foundation
import SwiftData

/// Safe migration service when user changes base currency.
///
/// Prevents historical ledger numbers from being silently relabeled (e.g. 10,000 ILS -> €10,000).
/// If financial data exists, converts all monetary amounts using verified FX rates.
/// If no data exists, allows immediate change.
///
/// ATOMICITY INVARIANT: if any read, conversion, validation, or save fails, the entire
/// financial database and the base-currency preference stay unchanged. The preference is
/// only written AFTER every model has been migrated and persisted successfully.
public enum BaseCurrencyMigrationService {

    public enum MigrationError: Error, LocalizedError {
        /// No verified rate exists between the two currencies. Nothing was changed.
        case rateUnavailable(from: String, to: String)
        /// A database read / fetch while migrating failed. Nothing was changed.
        case dataMigrationFailed
        /// Persisting the migrated data failed. Everything was rolled back.
        case saveFailed

        public var errorDescription: String? {
            switch self {
            case .rateUnavailable:
                return AppLanguage.localized(
                    "לא ניתן לשנות מטבע כרגע כי שער ההמרה אינו זמין. הנתונים שלך לא שונו.",
                    "The base currency couldn't be changed because an exchange rate is unavailable. Your data was not changed."
                )
            case .dataMigrationFailed, .saveFailed:
                return AppLanguage.localized(
                    "שינוי המטבע לא הושלם. הנתונים שלך נשארו ללא שינוי.",
                    "The currency change couldn't be completed. Your data was left unchanged."
                )
            }
        }
    }

    /// Checks whether any user financial data currently exists in the store.
    ///
    /// A database read error must NOT be interpreted as "the user has no financial data":
    /// fetches are real `try` and the error is propagated so the migration aborts.
    @MainActor
    public static func hasFinancialData(context: ModelContext) throws -> Bool {
        if try context.fetchCount(FetchDescriptor<Transaction>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<CategoryBudget>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<IncomeSource>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<RecurringExpense>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<InstallmentPlan>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<SavingsGoal>()) > 0 { return true }
        if try context.fetchCount(FetchDescriptor<ScheduledExpense>()) > 0 { return true }
        return false
    }

    /// Performs the safe currency migration across all monetary models.
    ///
    /// `rateProvider` is injectable for tests: it returns how many units of `to` one unit
    /// of `from` is worth. Defaults to the canonical `FXService.convert` path (rate 1 for 1).
    @MainActor
    public static func migrateBaseCurrency(
        from oldBase: CurrencyType,
        to newBase: CurrencyType,
        context: ModelContext,
        rateProvider: (String, String) -> Double? = { from, to in
            FXService.convert(amount: 1.0, from: from, to: to)
        }
    ) throws {
        guard oldBase != newBase else { return }

        let hasData: Bool
        do {
            hasData = try hasFinancialData(context: context)
        } catch {
            throw MigrationError.dataMigrationFailed
        }

        // No financial data: update the setting directly; there is nothing to migrate.
        guard hasData else {
            LocalizationManager.shared.baseCurrency = newBase
            return
        }

        // Verify a conversion rate exists BEFORE touching any model.
        guard let rate = rateProvider(oldBase.rawValue, newBase.rawValue),
              rate > 0, rate.isFinite else {
            throw MigrationError.rateUnavailable(from: oldBase.rawValue, to: newBase.rawValue)
        }

        // Read + mutate phase. Any fetch failure aborts the whole migration.
        do {
            // 1. Transactions
            let transactions = try context.fetch(FetchDescriptor<Transaction>())
            for tx in transactions {
                migrateTransaction(tx, rate: rate, newBase: newBase)
            }

            // 2. CategoryBudgets
            let budgets = try context.fetch(FetchDescriptor<CategoryBudget>())
            for b in budgets {
                b.monthlyLimit = rounded(b.monthlyLimit * rate)
            }

            // 3. IncomeSources
            let incomes = try context.fetch(FetchDescriptor<IncomeSource>())
            for inc in incomes {
                inc.amount = rounded(inc.amount * rate)
                inc.currency = newBase.symbol
            }

            // 4. RecurringExpenses
            let recurring = try context.fetch(FetchDescriptor<RecurringExpense>())
            for r in recurring {
                r.amount = rounded(r.amount * rate)
                r.currency = newBase.symbol
            }

            // 5. InstallmentPlans
            let plans = try context.fetch(FetchDescriptor<InstallmentPlan>())
            for p in plans {
                p.totalAmount = rounded(p.totalAmount * rate)
                p.currency = newBase.symbol
            }

            // 6. SavingsGoals
            let goals = try context.fetch(FetchDescriptor<SavingsGoal>())
            for g in goals {
                g.targetAmount = rounded(g.targetAmount * rate)
                g.savedAmount = rounded(g.savedAmount * rate)
                g.currency = newBase.symbol
            }

            // 7. ScheduledExpenses
            let scheduled = try context.fetch(FetchDescriptor<ScheduledExpense>())
            for s in scheduled {
                // Materialized records are historical linkage metadata: the linked
                // Transaction is the authoritative financial record and gets migrated
                // above. Only unmaterialized scheduled expenses are future ledger data.
                guard !s.isMaterialized else { continue }
                migrateScheduledExpense(s, rate: rate, newBase: newBase)
            }
        } catch {
            context.rollback()
            throw MigrationError.dataMigrationFailed
        }

        // Persist phase. A save failure rolls back every mutation made above.
        do {
            try context.save()
        } catch {
            context.rollback()
            throw MigrationError.saveFailed
        }

        // ONLY AFTER successful persistence: update the active base currency.
        LocalizationManager.shared.baseCurrency = newBase
    }

    /// Converts a single Transaction into the new base currency.
    /// If it was originally entered in the destination currency, its exact original value
    /// is restored rather than doing an unnecessary round-trip conversion.
    private static func migrateTransaction(_ tx: Transaction, rate: Double, newBase: CurrencyType) {
        if let origAmt = tx.originalAmount,
           let origCurr = tx.originalCurrency,
           CurrencyResolutionService.normalizeToISOCode(origCurr) == newBase.rawValue {
            tx.amount = tx.amount < 0 ? -abs(origAmt) : abs(origAmt)
            tx.currency = newBase.symbol
            tx.originalAmount = nil
            tx.originalCurrency = nil
            tx.exchangeRate = nil
        } else {
            tx.amount = rounded(tx.amount * rate)
            tx.currency = newBase.symbol
            if let origAmt = tx.originalAmount, origAmt > 0 {
                tx.exchangeRate = abs(tx.amount) / origAmt
            }
        }
    }

    /// Converts an unmaterialized ScheduledExpense into the new base currency, keeping the
    /// same semantics as Transaction: sign preserved, foreign metadata restored or rebuilt.
    private static func migrateScheduledExpense(_ s: ScheduledExpense, rate: Double, newBase: CurrencyType) {
        if let origAmt = s.originalAmount,
           let origCurr = s.originalCurrency,
           CurrencyResolutionService.normalizeToISOCode(origCurr) == newBase.rawValue {
            s.amount = s.amount < 0 ? -abs(origAmt) : abs(origAmt)
            s.currency = newBase.symbol
            s.originalAmount = nil
            s.originalCurrency = nil
            s.exchangeRate = nil
        } else {
            s.amount = rounded(s.amount * rate)
            s.currency = newBase.symbol
            if let origAmt = s.originalAmount, origAmt > 0 {
                s.exchangeRate = abs(s.amount) / origAmt
            }
        }
    }

    private static func rounded(_ v: Double) -> Double {
        (v * 100).rounded() / 100
    }
}