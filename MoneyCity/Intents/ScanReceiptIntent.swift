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

            for candidate in scanResult.candidates {
                let transaction = Transaction(
                    amount: candidate.amount,
                    merchant: candidate.merchant,
                    category: candidate.category,
                    timestamp: candidate.date ?? Date(),
                    confidenceScore: candidate.confidence,
                    isConfirmed: candidate.confidence >= 0.85,
                    buildingId: candidate.buildingId
                )
                try await DatabaseService.shared.save(transaction: transaction)
            }

            if scanResult.candidates.count == 1, let primary = scanResult.primary {
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
                let count = scanResult.candidates.count
                let totalSum = scanResult.candidates.reduce(0.0) { $0 + $1.amount }
                let formattedTotal = "₪" + (totalSum.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", totalSum) : String(format: "%.2f", totalSum))
                let storesSummary = scanResult.candidates.map { "\($0.merchant) (₪\($0.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", $0.amount) : String(format: "%.2f", $0.amount)))" }.joined(separator: ", ")
                let successMessage = "נוספו \(count) עסקאות מתוך צילום המסך (סך הכל \(formattedTotal)): \(storesSummary)"

                #if canImport(UserNotifications)
                NotificationService.sendExpenseLoggedNotification(
                    amount: totalSum,
                    categoryName: scanResult.candidates.first?.category.displayName ?? "קניות",
                    merchant: "\(count) חנויות: \(scanResult.candidates.map(\.merchant).joined(separator: ", "))"
                )
                #endif

                return .result(
                    value: successMessage,
                    dialog: "\(successMessage)"
                )
            }
        } catch {
            return .result(
                value: "שגיאה בפענוח צילום המסך",
                dialog: "לא הצלחנו לפענח את הסכום או בית העסק מתוך התמונה."
            )
        }
    }
}
