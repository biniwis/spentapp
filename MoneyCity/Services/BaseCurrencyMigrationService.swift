import Foundation
import SwiftData

/// Safe migration service when user changes base currency.
///
/// Prevents historical ledger numbers from being silently relabeled (e.g. 10,000 ILS -> €10,000).
/// If financial data exists, converts all monetary amounts using verified FX rates.
/// If no data exists, allows immediate change.
///
/// ATOMICITY INVARIANT: if any read, conversion, validation, or save fails, the entire
/// financial database, the base-currency preference, AND the monthly budget stay unchanged.
/// The preference and the converted budget are only written AFTER every model has been
/// migrated and persisted successfully.
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

    /// The monthly budget lives in the standard UserDefaults, backed by @AppStorage.
    /// It is financial data the user will notice losing, so the migration treats it the same
    /// way it treats a CategoryBudget row: convert it, or abort without touching it.
    private static let monthlyBudgetKey = "monthly_budget"

    nonisolated private static func readMonthlyBudget(defaults: UserDefaults) -> Double {
        let v = defaults.double(forKey: monthlyBudgetKey)
        return v.isFinite && v > 0 ? v : 0
    }

    nonisolated private static func writeMonthlyBudget(_ value: Double, defaults: UserDefaults) {
        let v = value.isFinite && value > 0 ? (value * 100).rounded() / 100 : 0
        defaults.set(v, forKey: monthlyBudgetKey)
    }

    private static func restoreMonthlyBudget(_ oldValue: Double, defaults: UserDefaults) {
        if oldValue > 0 {
            defaults.set(oldValue, forKey: monthlyBudgetKey)
        } else {
            defaults.removeObject(forKey: monthlyBudgetKey)
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
        // A stored monthly budget is financial data even when the store itself is empty.
        if readMonthlyBudget(defaults: .standard) > 0 { return true }
        return false
    }

    /// Performs the safe currency migration across all monetary models.
    ///
    /// `rateProvider` is injectable for tests: it returns how many units of `to` one unit
    /// of `from` is worth. Defaults to the canonical `FXService.convert` path.
    ///
    /// `markBackupDirty` is called ONLY after everything else has been persisted, so the
    /// next iCloud backup reflects the freshly migrated ledger rather than a half-written one.
    @MainActor
    public static func migrateBaseCurrency(
        from oldBase: CurrencyType,
        to newBase: CurrencyType,
        context: ModelContext,
        rateProvider: (String, String) -> Double? = { from, to in
            FXService.convert(amount: 1.0, from: from, to: to)
        },
        markBackupDirty: (() -> Void)? = nil
    ) throws {
        guard oldBase != newBase else { return }

        let oldMonthlyBudget = readMonthlyBudget(defaults: .standard)

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
                try migrateTransaction(tx, rate: rate, newBase: newBase, rateProvider: rateProvider)
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
                try migrateInstallmentPlan(p, rate: rate, newBase: newBase, rateProvider: rateProvider)
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
                try migrateScheduledExpense(s, rate: rate, newBase: newBase, rateProvider: rateProvider)
            }
        } catch let error as MigrationError {
            // A real MigrationError (e.g. a missing direct rate for a foreign row) must be
            // rethrown as-is so the caller knows exactly why the migration aborted.
            context.rollback()
            restoreMonthlyBudget(oldMonthlyBudget, defaults: .standard)
            throw error
        } catch {
            context.rollback()
            restoreMonthlyBudget(oldMonthlyBudget, defaults: .standard)
            throw MigrationError.dataMigrationFailed
        }

        // Persist phase. A save failure rolls back every mutation made above.
        do {
            try context.save()
        } catch {
            context.rollback()
            restoreMonthlyBudget(oldMonthlyBudget, defaults: .standard)
            throw MigrationError.saveFailed
        }

        // ONLY AFTER successful persistence: convert the stored monthly budget, then update
        // the active base currency. The budget is written before the preference so a system
        // snapshot immediately after either write is still internally consistent.
        if oldMonthlyBudget > 0 {
            writeMonthlyBudget(rounded(oldMonthlyBudget * rate), defaults: .standard)
        }
        LocalizationManager.shared.baseCurrency = newBase
        markBackupDirty?()
    }

    /// Converts a single Transaction into the new base currency.
    /// If it was originally entered in the destination currency, its exact original value
    /// is restored rather than doing an unnecessary round-trip conversion.
    private static func migrateTransaction(
        _ tx: Transaction,
        rate: Double,
        newBase: CurrencyType,
        rateProvider: (String, String) -> Double?
    ) throws {
        // An unresolved foreign transaction is still sitting in its own currency with no
        // rate. The only honest conversion is its original currency -> new base directly.
        // A stand-in old-base -> new-base rate would fabricate a value that never existed.
        if tx.isUnresolvedForeign {
            let resolved = try resolveUnresolvedForeign(
                amount: tx.amount,
                currency: tx.currency,
                originalAmount: tx.originalAmount,
                originalCurrency: tx.originalCurrency,
                newBase: newBase,
                rateProvider: rateProvider
            )
            tx.amount = resolved.amount
            tx.currency = newBase.symbol
            tx.exchangeRate = resolved.exchangeRate
            tx.originalAmount = resolved.originalAmount
            tx.originalCurrency = resolved.originalCurrency
            return
        }

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
    private static func migrateScheduledExpense(
        _ s: ScheduledExpense,
        rate: Double,
        newBase: CurrencyType,
        rateProvider: (String, String) -> Double?
    ) throws {
        // Same unresolved-foreign rule as Transactions: never a stand-in rate.
        if s.isUnresolvedForeign {
            let resolved = try resolveUnresolvedForeign(
                amount: s.amount,
                currency: s.currency,
                originalAmount: s.originalAmount,
                originalCurrency: s.originalCurrency,
                newBase: newBase,
                rateProvider: rateProvider
            )
            s.amount = resolved.amount
            s.currency = newBase.symbol
            s.exchangeRate = resolved.exchangeRate
            s.originalAmount = resolved.originalAmount
            s.originalCurrency = resolved.originalCurrency
            return
        }

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

    /// Converts an InstallmentPlan into the new base currency.
    ///
    /// A plan with foreign metadata holds a fixed original total in its own currency: that
    /// total is converted directly so the parts keep adding up to the purchase in the
    /// currency it was made in. A plan entered in the destination currency restores its
    /// exact original total. A domestic plan is multiplied by the old-base -> new-base rate.
    private static func migrateInstallmentPlan(
        _ p: InstallmentPlan,
        rate: Double,
        newBase: CurrencyType,
        rateProvider: (String, String) -> Double?
    ) throws {
        if let origTotal = p.originalTotalAmount, origTotal > 0,
           let origCurr = p.originalCurrency,
           CurrencyResolutionService.normalizeToISOCode(origCurr) == newBase.rawValue {
            p.totalAmount = rounded(origTotal)
            p.currency = newBase.symbol
            p.originalTotalAmount = nil
            p.originalCurrency = nil
            p.exchangeRate = nil
            return
        }

        if let origTotal = p.originalTotalAmount, origTotal > 0,
           let origCurr = p.originalCurrency {
            let origISO = CurrencyResolutionService.normalizeToISOCode(origCurr) ?? origCurr.uppercased()
            guard let directRate = rateProvider(origISO, newBase.rawValue),
                  directRate > 0, directRate.isFinite else {
                throw MigrationError.rateUnavailable(from: origISO, to: newBase.rawValue)
            }
            let newTotal = rounded(origTotal * directRate)
            p.totalAmount = newTotal
            p.currency = newBase.symbol
            p.exchangeRate = newTotal / origTotal
            return
        }

        p.totalAmount = rounded(p.totalAmount * rate)
        p.currency = newBase.symbol
        if let origTotal = p.originalTotalAmount, origTotal > 0 {
            p.exchangeRate = abs(p.totalAmount) / origTotal
        }
    }

    private struct ResolvedForeignAmount {
        let amount: Double
        let exchangeRate: Double?
        let originalAmount: Double?
        let originalCurrency: String?
    }

    /// Converts an unresolved foreign amount directly from its own currency to the new base.
    ///
    /// Never multiplies by the old-base -> new-base rate, never invents a 1:1 rate, and
    /// never persists unless a real direct rate exists. Throws so the whole migration aborts
    /// and every previous mutation is rolled back.
    private static func resolveUnresolvedForeign(
        amount: Double,
        currency: String,
        originalAmount: Double?,
        originalCurrency: String?,
        newBase: CurrencyType,
        rateProvider: (String, String) -> Double?
    ) throws -> ResolvedForeignAmount {
        let sign = amount < 0 ? -1.0 : 1.0
        let magnitude = abs(originalAmount ?? amount)
        let foreignISO = CurrencyResolutionService.normalizeToISOCode(originalCurrency)
            ?? CurrencyResolutionService.normalizeToISOCode(currency)
            ?? currency.uppercased()

        // The "foreign" currency turns out to be the new base: restore the exact value the
        // move to this currency would have produced anyway.
        guard foreignISO != newBase.rawValue else {
            let restored = rounded(magnitude)
            return ResolvedForeignAmount(
                amount: restored * sign,
                exchangeRate: nil,
                originalAmount: nil,
                originalCurrency: nil
            )
        }

        guard let directRate = rateProvider(foreignISO, newBase.rawValue),
              directRate > 0, directRate.isFinite else {
            throw MigrationError.rateUnavailable(from: foreignISO, to: newBase.rawValue)
        }
        let converted = rounded(magnitude * directRate)
        let exRate = magnitude > 0 ? converted / magnitude : nil
        return ResolvedForeignAmount(
            amount: converted * sign,
            exchangeRate: exRate,
            originalAmount: magnitude,
            originalCurrency: foreignISO
        )
    }

    private static func rounded(_ v: Double) -> Double {
        (v * 100).rounded() / 100
    }
}