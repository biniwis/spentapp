import AppIntents
import Foundation

/// The one-field version of the Wallet ingest action.
///
/// The detailed action has a parameter per value, and every one of them is a chance to
/// leave a field empty or map it to the wrong thing — which is exactly how a correctly
/// built automation ended up delivering five empty fields. This action asks for one thing:
/// the transaction. Everything else is worked out in the app, where it can be tested.
public struct LogWalletPaymentIntent: AppIntent {
    public static var title: LocalizedStringResource = "Capture Apple Pay Payment (Simple)"
    public static var description = IntentDescription(
        "Drag the shortcut input into this single field. The app extracts the amount and merchant automatically."
    )

    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = false

    /// A single parameter, so Shortcuts has one obvious thing to connect the automation's
    /// input to instead of five it can silently leave blank.
    @Parameter(
        title: "Transaction Details",
        description: "Transaction input received from Wallet",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    public var payload: String?

    public static var parameterSummary: some ParameterSummary {
        Summary("Capture payment from \(\.$payload)")
    }

    public init() {}

    public init(payload: String?) {
        self.payload = payload
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let effectivePayload = payload

        let debugRaw = """
        [SPENT Simple Ingest Debug]
        • payload received: \(effectivePayload != nil ? "\"\(effectivePayload!)\"" : "nil")
        """
        MoneyCityLog.sensitive(debugRaw)

        let result = await WalletIngestCoordinator.run(
            amount: nil,
            amountText: nil,
            merchant: effectivePayload,
            currency: nil,
            transactionDate: nil,
            intentName: "LogWalletPaymentIntent"
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
