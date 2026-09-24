import AppIntents
import SwiftData
import Foundation

extension TransactionIngestError: CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .missingMerchant:
            return LocalizedStringResource(stringLiteral: AppLanguage.localized("לא התקבל שם בית עסק מ-Wallet, לכן העסקה לא נרשמה.", "Wallet did not provide a merchant name, so the transaction was not recorded."))
        case .missingAmount:
            return LocalizedStringResource(stringLiteral: AppLanguage.localized("לא התקבל סכום תקין מ-Wallet, לכן העסקה לא נרשמה.", "Wallet did not provide a valid amount, so the transaction was not recorded."))
        case .duplicate:
            return LocalizedStringResource(stringLiteral: AppLanguage.localized("העסקה הזו כבר נרשמה.", "This transaction has already been recorded."))
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
    public static var title: LocalizedStringResource = "Record Apple Pay Transaction"
    public static var description = IntentDescription("Record a payment and automatically categorize it in your city.")

    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true

    @Parameter(
        title: "Transaction Amount",
        description: "Transaction amount received from Wallet"
    )
    public var amount: Double?

    /// Fallback for the known Shortcuts defect where the numeric amount arrives as 0.0
    /// while the text representation of the same transaction is intact.
    @Parameter(title: "Amount as Text", description: "Optional fallback if the numeric amount is empty")
    public var amountText: String?

    @Parameter(
        title: "Merchant",
        description: "Merchant name received from Apple Pay"
    )
    public var merchant: String?

    @Parameter(title: "Currency", description: "Defaults to the base currency selected in the app")
    public var currency: String?

    /// Structured currency amount supplied by Apple Pay / Shortcuts (when available on iOS)
    @Parameter(title: "Currency Amount", description: "Optional structured monetary amount with ISO currency code")
    public var currencyAmount: IntentCurrencyAmount?

    @Parameter(title: "Date and Time", description: "When the transaction took place")
    public var transactionDate: Date?

    public static var parameterSummary: some ParameterSummary {
        Summary("Record payment of \(\.$amount) at \(\.$merchant)") {
            \.$currency
            \.$currencyAmount
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
        date: Date? = nil,
        currencyAmount: IntentCurrencyAmount? = nil
    ) {
        self.amount = amount
        self.amountText = amountText
        self.merchant = merchant
        self.currency = currency
        self.transactionDate = date
        self.currencyAmount = currencyAmount
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        var effectiveAmount = amount

        // If amount was empty, check if currencyAmount provided a positive amount value
        if let ca = currencyAmount, (effectiveAmount == nil || effectiveAmount == 0) {
            let decimalVal = NSDecimalNumber(decimal: ca.amount).doubleValue
            if decimalVal > 0 {
                effectiveAmount = decimalVal
            }
        }

        var effectiveMerchant = merchant

        if (effectiveMerchant == nil || effectiveMerchant?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) && (effectiveAmount != nil && effectiveAmount! > 0) {
            effectiveMerchant = AppLanguage.localized("תשלום Apple Pay", "Apple Pay payment")
        }

        let debugRaw = """
        [SPENT Ingest Debug]
        • amount received: \(effectiveAmount != nil ? "\(effectiveAmount!)" : "nil")
        • merchant received: \(effectiveMerchant != nil ? "\"\(effectiveMerchant!)\"" : "nil")
        • currency parameter: \(currency != nil ? "\"\(currency!)\"" : "nil")
        • transactionDate received: \(transactionDate != nil ? "\(transactionDate!)" : "nil")
        • amountText received: \(amountText != nil ? "\"\(amountText!)\"" : "nil")
        """
        MoneyCityLog.sensitive(debugRaw)

        // PRODUCT SAFETY DECISION:
        // Shortcuts / iOS often synthesizes unreliable default currency metadata (e.g. synthetic USD
        // on devices or unconfigured shortcut parameters), which previously caused domestic Shekel (₪)
        // transactions in Israel to be misclassified and converted as USD (e.g. ₪34.50 becoming $34.50 -> ₪104).
        // To strictly protect domestic capture, automatic Wallet capture intentionally ignores any
        // shortcut-supplied currency or structured currency metadata and relies exclusively on the user's
        // configured base currency in SPENT (passing currency: nil and structuredCurrency: nil).
        let result = await WalletIngestCoordinator.run(
            amount: effectiveAmount,
            amountText: amountText,
            merchant: effectiveMerchant,
            currency: nil,
            transactionDate: transactionDate,
            intentName: "RecordTransactionIntent",
            structuredCurrency: nil
        )

        guard result.succeeded else {
            throw IngestIntentError.executionFailed(result.message)
        }

        let dialogMessage = MoneyCityLog.isDebugBuild
            ? "\(debugRaw)\n\n\(result.message)"
            : result.message
        return .result(dialog: IntentDialog(stringLiteral: dialogMessage))
    }
}

public enum IngestIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case executionFailed(String)

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .executionFailed(let msg):
            return LocalizedStringResource(stringLiteral: msg)
        }
    }
}
