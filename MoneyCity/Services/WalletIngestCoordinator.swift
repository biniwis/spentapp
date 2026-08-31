import Foundation
import SwiftData

/// The outcome of one ingest attempt, in the words shown back to the user.
public struct WalletIngestResult: Sendable {
    public let message: String
    public let succeeded: Bool
}

/// The shared body of every Wallet ingest path.
///
/// Two App Intents feed this: the detailed one with a field per value, and the single-field
/// one that takes the whole transaction. Keeping the logic here means the simple action is
/// not a second, weaker implementation of the same thing.
public enum WalletIngestCoordinator {

    @MainActor
    public static func run(
        amount: Double?,
        amountText: String?,
        merchant: String?,
        currency: String?,
        transactionDate: Date?
    ) async -> WalletIngestResult {

        let date = TransactionIngest.sanitizedDate(transactionDate) ?? Date()

        // Record the payload before anything can reinterpret it — when the automation
        // misbehaves this log is the only evidence of what it actually sent.
        let log = IngestLogEntry(
            receivedAt: Date(),
            rawAmount: IngestLogEntry.describe(amount),
            rawAmountText: IngestLogEntry.describe(amountText),
            rawMerchant: IngestLogEntry.describe(merchant),
            rawCurrency: IngestLogEntry.describe(currency),
            rawDate: IngestLogEntry.describe(transactionDate)
        )
        DatabaseService.shared.record(log)

        let finalCurrency = TransactionIngest.sanitizedCurrency(currency)
            ?? LocalizationManager.shared.baseCurrency.symbol

        // Never trust which field a value arrived in — Shortcuts fills whichever one it
        // was pointed at, often with the whole transaction description.
        let salvaged = TransactionIngest.salvage(
            amount: amount,
            amountText: amountText,
            merchant: merchant
        )

        let recent = DatabaseService.shared.fetchRecentTransactions(
            within: TransactionIngest.duplicateWindow * 2,
            of: date
        )
        let rules = DatabaseService.shared.fetchMerchantRules()

        do {
            let newTransaction = try TransactionIngest.makeTransaction(
                amount: salvaged.amount,
                amountText: nil,
                merchant: salvaged.merchant,
                currency: finalCurrency,
                date: date,
                existing: recent,
                rules: rules
            )

            if let fired = MerchantRuleService.rule(for: newTransaction.merchant, in: rules) {
                fired.hitCount += 1
            }

            try await DatabaseService.shared.save(transaction: newTransaction)

            log.outcome = newTransaction.isConfirmed ? "נשמר" : "נשמר — ממתין לאישור"
            log.resolvedAmount = newTransaction.amount
            log.resolvedMerchant = newTransaction.merchant
            DatabaseService.shared.persist()

            let amountString = String(format: "%.2f", newTransaction.amount)
            let message = newTransaction.isConfirmed
                ? "נרשמה עסקה ע״ס \(finalCurrency)\(amountString) ב-\(newTransaction.merchant) (\(newTransaction.category.shortName))"
                : "נרשמה עסקה ע״ס \(finalCurrency)\(amountString) ב-\(newTransaction.merchant). הסיווג לא ודאי — ממתין לאישור."

            return WalletIngestResult(message: message, succeeded: true)

        } catch TransactionIngestError.duplicate {
            log.outcome = "כפילות — לא נשמר שוב"
            DatabaseService.shared.persist()
            return WalletIngestResult(message: "העסקה הזו כבר נרשמה בעיר.", succeeded: true)

        } catch {
            // The payment happened even if the payload was unusable, so it is parked as an
            // unconfirmed row carrying the raw values — never dropped, never presented as a
            // real ₪0 purchase.
            let placeholderMerchant = salvaged.merchant ?? "Apple Pay — פרטים חסרים"
            let payloadNote = "מטען גולמי: amount=\(log.rawAmount) · amountText=\(log.rawAmountText) · merchant=\(log.rawMerchant)"

            let fallback = Transaction(
                amount: salvaged.amount ?? 0.0,
                currency: finalCurrency,
                merchant: placeholderMerchant,
                category: .other,
                timestamp: date,
                confidenceScore: 0.0,
                isManual: false,
                isConfirmed: false,
                note: payloadNote,
                buildingId: "shop_boutique"
            )
            try? await DatabaseService.shared.save(transaction: fallback)

            log.outcome = "לא זוהה — נשמר לאישור"
            log.resolvedAmount = salvaged.amount
            log.resolvedMerchant = salvaged.merchant
            DatabaseService.shared.persist()

            return WalletIngestResult(
                message: "Wallet לא העביר פרטים מלאים. נשמרה שורה לאישור — פתח את האפליקציה כדי להשלים אותה.",
                succeeded: false
            )
        }
    }
}
