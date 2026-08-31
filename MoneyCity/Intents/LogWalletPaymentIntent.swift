import AppIntents
import Foundation

/// The one-field version of the Wallet ingest action.
///
/// The detailed action has a parameter per value, and every one of them is a chance to
/// leave a field empty or map it to the wrong thing — which is exactly how a correctly
/// built automation ended up delivering five empty fields. This action asks for one thing:
/// the transaction. Everything else is worked out in the app, where it can be tested.
public struct LogWalletPaymentIntent: AppIntent {
    public static var title: LocalizedStringResource = "קליטת תשלום Apple Pay (פשוט)"
    public static var description = IntentDescription(
        "שדה אחד בלבד — גרור לתוכו את קלט הקיצור. האפליקציה מחלצת ממנו את הסכום ואת שם בית העסק בעצמה."
    )

    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true

    /// A single parameter, so Shortcuts has one obvious thing to connect the automation's
    /// input to instead of five it can silently leave blank.
    @Parameter(
        title: "פרטי העסקה",
        description: "קלט העסקה שהועבר מ-Wallet",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    public var payload: String?

    public static var parameterSummary: some ParameterSummary {
        Summary("קלוט תשלום מתוך \(\.$payload)")
    }

    public init() {}

    public init(payload: String?) {
        self.payload = payload
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let debugRaw = """
        [SPENT Simple Ingest Debug]
        • payload received: \(payload != nil ? "\"\(payload!)\"" : "nil")
        """
        print(debugRaw)

        let result = await WalletIngestCoordinator.run(
            amount: nil,
            amountText: nil,
            merchant: payload,
            currency: nil,
            transactionDate: nil
        )
        let dialogMessage = "\(debugRaw)\n\n\(result.message)"
        return .result(dialog: IntentDialog(stringLiteral: dialogMessage))
    }
}
