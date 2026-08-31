import AppIntents
import Foundation
import SwiftData

/// App Intent for scanning payment confirmation screenshots and receipts via Apple Shortcuts or iOS Share Sheet.
public struct ScanReceiptIntent: AppIntent {

    public static var title: LocalizedStringResource = "סרוק צילום מסך / קבלה ל-Money City"
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

            // Persist the transaction into SwiftData
            let transaction = Transaction(
                amount: scanResult.amount,
                merchant: scanResult.merchant,
                category: scanResult.category,
                timestamp: scanResult.date ?? Date(),
                confidenceScore: scanResult.confidence,
                isConfirmed: scanResult.confidence >= 0.85,
                buildingId: scanResult.buildingId
            )

            try await DatabaseService.shared.save(transaction: transaction)

            // Dispatch immediate local notification
            #if canImport(UserNotifications)
            NotificationService.sendExpenseLoggedNotification(
                amount: scanResult.amount,
                categoryName: scanResult.category.displayName,
                merchant: scanResult.merchant
            )
            #endif

            let formattedAmount = "₪" + (scanResult.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", scanResult.amount) : String(format: "%.2f", scanResult.amount))
            let successMessage = "✓ נוספו \(formattedAmount) ל\(scanResult.category.displayName) — \(scanResult.merchant)"

            return .result(
                value: successMessage,
                dialog: "\(successMessage)"
            )
        } catch {
            return .result(
                value: "שגיאה בפענוח צילום המסך",
                dialog: "לא הצלחנו לפענח את הסכום או בית העסק מתוך התמונה."
            )
        }
    }
}
