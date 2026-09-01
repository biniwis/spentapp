import AppIntents
import Foundation
import SwiftData

/// On-screen prompt App Intent that allows entering an expense directly
/// from a Home Screen shortcut / Siri / Action Button without opening the app.
public struct QuickExpensePromptIntent: AppIntent {
    public static var title: LocalizedStringResource = "הוספת הוצאה מהירה"
    public static var description = IntentDescription("הזנת הוצאה ישירות מחלונית צפה על המסך ללא פתיחת האפליקציה.")

    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true

    @Parameter(
        title: "סכום",
        description: "הסכום ששילמת",
        requestValueDialog: IntentDialog("כמה שילמת?")
    )
    public var amount: Double

    @Parameter(
        title: "שם בית העסק",
        description: "איפה שילמת (למשל: סופר, קפה, דלק)",
        default: "הוצאה כללית",
        requestValueDialog: IntentDialog("איפה שילמת?")
    )
    public var merchant: String?

    public static var parameterSummary: some ParameterSummary {
        Summary("הוסף הוצאה של \(\.$amount) ב-\(\.$merchant)")
    }

    public init() {}

    public init(amount: Double, merchant: String? = "הוצאה כללית") {
        self.amount = amount
        self.merchant = merchant
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let cleanMerchant = (merchant?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? merchant!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "הוצאה כללית"

        let result = await WalletIngestCoordinator.run(
            amount: amount,
            amountText: nil,
            merchant: cleanMerchant,
            currency: nil,
            transactionDate: Date(),
            intentName: "QuickExpensePromptIntent"
        )

        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}
