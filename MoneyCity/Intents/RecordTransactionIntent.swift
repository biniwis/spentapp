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
        description: "סכום העסקה שהועבר מ-Wallet"
    )
    public var amount: Double?

    /// Fallback for the known Shortcuts defect where the numeric amount arrives as 0.0
    /// while the text representation of the same transaction is intact.
    @Parameter(title: "סכום כטקסט", description: "אופציונלי. גיבוי אם הסכום המספרי מגיע ריק")
    public var amountText: String?

    @Parameter(
        title: "שם בית העסק",
        description: "שם העסק (Merchant) שהתקבל ב-Apple Pay"
    )
    public var merchant: String?

    @Parameter(title: "מטבע", description: "ברירת המחדל היא המטבע הראשי שהוגדר באפליקציה")
    public var currency: String?

    @Parameter(title: "תאריך ושעה", description: "זמן ביצוע העסקה")
    public var transactionDate: Date?

    public static var parameterSummary: some ParameterSummary {
        Summary("קלוט עסקה של \(\.$amount) ב-\(\.$merchant)") {
            \.$currency
            \.$transactionDate
            \.$amountText
        }
    }

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
        var effectiveAmount = amount
        var effectiveMerchant = merchant

        let hasAmount = (effectiveAmount != nil && effectiveAmount! > 0)
            || TransactionIngest.amountLikeValue(in: amountText) != nil
            || TransactionIngest.normalizedAmount(nil, amountText) != nil
            || TransactionIngest.amountLikeValue(in: merchant) != nil

        if !hasAmount {
            do {
                let promptDialog = IntentDialog("💳 זוהה תשלום ב-Apple Pay. מה הסכום ששילמת?")
                let requested = try await $amount.requestValue(promptDialog)
                if requested > 0 {
                    effectiveAmount = requested
                }
            } catch {
                // If user dismissed or cancelled, proceed to log failure gracefully
            }
        }

        if (effectiveMerchant == nil || effectiveMerchant?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) && (effectiveAmount != nil && effectiveAmount! > 0) {
            effectiveMerchant = "תשלום Apple Pay"
        }

        let debugRaw = """
        [SPENT Ingest Debug]
        • amount received: \(effectiveAmount != nil ? "\(effectiveAmount!)" : "nil")
        • merchant received: \(effectiveMerchant != nil ? "\"\(effectiveMerchant!)\"" : "nil")
        • currency received: \(currency != nil ? "\"\(currency!)\"" : "nil")
        • transactionDate received: \(transactionDate != nil ? "\(transactionDate!)" : "nil")
        • amountText received: \(amountText != nil ? "\"\(amountText!)\"" : "nil")
        """
        MoneyCityLog.sensitive(debugRaw)

        let result = await WalletIngestCoordinator.run(
            amount: effectiveAmount,
            amountText: amountText,
            merchant: effectiveMerchant,
            currency: currency,
            transactionDate: transactionDate,
            intentName: "RecordTransactionIntent"
        )

        let dialogMessage = MoneyCityLog.isDebugBuild
            ? "\(debugRaw)\n\n\(result.message)"
            : result.message
        return .result(dialog: IntentDialog(stringLiteral: dialogMessage))
    }
}
