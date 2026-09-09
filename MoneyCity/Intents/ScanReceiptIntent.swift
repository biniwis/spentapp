import AppIntents
import Foundation
import SwiftData

/// App Intent for scanning payment confirmation screenshots and receipts via Apple Shortcuts or iOS Share Sheet.
public struct ScanReceiptIntent: AppIntent {

    public static var title: LocalizedStringResource = "סרוק צילום מסך / קבלה ל-SPENT"
    public static var description = IntentDescription(
        "מזהה אוטומטית סכום, בית עסק, תאריך וקטגוריה מתוך צילום מסך או קבלה ושומר את ההוצאה בעיר."
    )

    public static var openAppWhenRun: Bool = false

    @Parameter(
        title: "צילום מסך או תמונת קבלה",
        description: "קובץ התמונה לסריקה",
        supportedTypeIdentifiers: ["public.image", "public.png", "public.jpeg", "public.heic"]
    )
    public var imageFile: IntentFile?

    public init() {}

    public init(imageFile: IntentFile?) {
        self.imageFile = imageFile
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let imageFile = imageFile else {
            return .result(
                value: "לא התקבלה תמונה לסריקה",
                dialog: "לא התקבלה תמונה לסריקה. אנא בחר צילום מסך של אישור תשלום."
            )
        }

        let imageData = imageFile.data
        let rules = DatabaseService.shared.fetchMerchantRules()

        do {
            let scanResult = try await ReceiptOCRService.scanImage(data: imageData, rules: rules)
            guard !scanResult.candidates.isEmpty else {
                throw ReceiptOCRService.OCRError.parsingFailed
            }

            let recentTxs = DatabaseService.shared.fetchRecentTransactions(within: 7 * 24 * 3600)
            var newTransactions: [Transaction] = []

            for candidate in scanResult.candidates {
                let candDate = candidate.date ?? Date()

                // Deduplicate against existing ledger and against other candidates in the same image
                if TransactionIngest.isDuplicate(
                    merchant: candidate.merchant,
                    amount: candidate.amount,
                    currency: candidate.currency,
                    date: candDate,
                    in: recentTxs + newTransactions
                ) {
                    continue
                }

                var finalAmount = candidate.amount
                var finalCurrency = "₪"
                var origAmount: Double? = nil
                var origCurrency: String? = nil
                var exRate: Double? = nil

                if let currType = CurrencyType(symbolOrCode: candidate.currency), currType != .ils {
                    let converted = FXService.convert(amount: candidate.amount, from: currType, to: .ils)
                    finalAmount = converted
                    finalCurrency = CurrencyType.ils.symbol
                    origAmount = candidate.amount
                    origCurrency = currType.symbol
                    exRate = candidate.amount > 0 ? converted / candidate.amount : nil
                } else {
                    finalCurrency = CurrencyType(symbolOrCode: candidate.currency)?.symbol ?? "₪"
                }

                let transaction = Transaction(
                    amount: finalAmount,
                    currency: finalCurrency,
                    merchant: candidate.merchant,
                    category: candidate.category,
                    timestamp: candDate,
                    confidenceScore: candidate.confidence,
                    isConfirmed: candidate.confidence >= 0.85,
                    buildingId: candidate.buildingId,
                    originalAmount: origAmount,
                    originalCurrency: origCurrency,
                    exchangeRate: exRate
                )
                newTransactions.append(transaction)
            }

            guard !newTransactions.isEmpty else {
                let msg = "כל העסקאות בצילום המסך כבר קיימות באפליקציה (זוהו ככפולות)"
                return .result(value: msg, dialog: "\(msg)")
            }

            // Atomic batch save
            try await DatabaseService.shared.save(transactions: newTransactions)

            if newTransactions.count == 1, let primary = newTransactions.first {
                #if canImport(UserNotifications)
                NotificationService.sendExpenseLoggedNotification(
                    amount: primary.amount,
                    categoryName: primary.category.displayName,
                    merchant: primary.merchant
                )
                #endif

                let formattedAmount = "₪" + (primary.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", primary.amount) : String(format: "%.2f", primary.amount))
                let successMessage = "נוספו \(formattedAmount) ל\(primary.category.displayName) — \(primary.merchant)"

                return .result(
                    value: successMessage,
                    dialog: "\(successMessage)"
                )
            } else {
                let count = newTransactions.count
                let totalSum = newTransactions.reduce(0.0) { $0 + $1.amount }
                let formattedTotal = "₪" + (totalSum.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", totalSum) : String(format: "%.2f", totalSum))
                let storesSummary = newTransactions.map { "\($0.merchant) (₪\($0.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", $0.amount) : String(format: "%.2f", $0.amount)))" }.joined(separator: ", ")
                let successMessage = "נוספו \(count) עסקאות מתוך צילום המסך (סך הכל \(formattedTotal)): \(storesSummary)"

                #if canImport(UserNotifications)
                NotificationService.sendExpenseLoggedNotification(
                    amount: totalSum,
                    categoryName: newTransactions.first?.category.displayName ?? "קניות",
                    merchant: "\(count) חנויות: \(newTransactions.map(\.merchant).joined(separator: ", "))"
                )
                #endif

                return .result(
                    value: successMessage,
                    dialog: "\(successMessage)"
                )
            }
        } catch {
            // The error was discarded here without a log, a trace or even a name — a scan
            // started from Shortcuts failed and left nothing at all behind.
            let failure = error as? ReceiptOCRService.OCRFailure
            ReceiptOCRService.recordScanAttempt(
                outcome: failure.map { "failed_\($0.reason)" } ?? "failed",
                failureReason: error.localizedDescription,
                trace: failure?.trace
            )
            return .result(
                value: "שגיאה בפענוח צילום המסך",
                dialog: "לא הצלחנו לפענח את הסכום או בית העסק מתוך התמונה."
            )
        }
    }
}
