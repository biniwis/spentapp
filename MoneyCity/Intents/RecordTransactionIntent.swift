import AppIntents
import SwiftData
import Foundation

extension TransactionIngestError: CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .missingMerchant:
            return "לא התקבל שם בית עסק מ-Wallet, לכן העסקה לא נרשמה."
        case .missingAmount:
            return "לא התקבל סכום תקין מ-Wallet, לכן העסקה לא נרשמה."
        case .duplicate:
            return "העסקה הזו כבר נרשמה."
        }
    }
}

/// App Intent triggered in the background by the Shortcuts "Wallet"/"Transaction" automation
/// after an Apple Pay payment completes.
///
/// Every parameter is optional on purpose. The automation trigger is documented to sometimes
/// hand a custom intent an empty merchant and a 0.0 amount; non-optional parameters would make
/// Shortcuts stop and *ask* for a value, which in a background automation just fails silently.
/// Optional parameters let this intent receive the bad payload, refuse it, and say why.
public struct RecordTransactionIntent: AppIntent {
    public static var title: LocalizedStringResource = "הקלטת עסקת Apple Pay"
    public static var description = IntentDescription("קולט עסקת תשלום ומסווג אותה אוטומטית לעיר.")

    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true

    @Parameter(
        title: "סכום העסקה",
        description: "סכום העסקה שהועבר מ-Wallet",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    public var amount: Double?

    /// Fallback for the known Shortcuts defect where the numeric amount arrives as 0.0
    /// while the text representation of the same transaction is intact.
    @Parameter(title: "סכום כטקסט", description: "אופציונלי. גיבוי אם הסכום המספרי מגיע ריק")
    public var amountText: String?

    @Parameter(
        title: "שם בית העסק",
        description: "שם העסק (Merchant) שהתקבל ב-Apple Pay",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    public var merchant: String?

    @Parameter(title: "מטבע", description: "ברירת המחדל היא המטבע הראשי שהוגדר באפליקציה")
    public var currency: String?

    @Parameter(title: "תאריך ושעה", description: "זמן ביצוע העסקה")
    public var transactionDate: Date?

    public init() {}

    public init(
        amount: Double?,
        merchant: String?,
        amountText: String? = nil,
        currency: String? = nil,
        date: Date? = nil
    ) {
        self.amount = amount
        self.amountText = amountText
        self.merchant = merchant
        self.currency = currency
        self.transactionDate = date
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // All the work lives in the coordinator so this action and the single-field one
        // cannot drift into two different behaviours.
        let result = await WalletIngestCoordinator.run(
            amount: amount,
            amountText: amountText,
            merchant: merchant,
            currency: currency,
            transactionDate: transactionDate
        )
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}
