import AppIntents
import Foundation
import SwiftData

/// On-screen prompt App Intent that allows entering an expense directly
/// from a Home Screen shortcut / Siri / Action Button without opening the app.
public struct QuickExpensePromptIntent: AppIntent {
    public static var title: LocalizedStringResource = "Quick Expense"
    public static var description = IntentDescription("Enter an expense in an on-screen prompt without opening the app.")

    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true

    @Parameter(
        title: "Amount",
        description: "The amount you paid",
        requestValueDialog: IntentDialog("How much did you pay?")
    )
    public var amount: Double

    @Parameter(
        title: "Merchant",
        description: "Where you paid (for example: groceries, coffee, gas)",
        requestValueDialog: IntentDialog("Where did you pay?")
    )
    public var merchant: String?

    public static var parameterSummary: some ParameterSummary {
        Summary("Add expense of \(\.$amount) at \(\.$merchant)")
    }

    public init() {}

    public init(amount: Double, merchant: String? = nil) {
        self.amount = amount
        self.merchant = merchant
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let cleanMerchant = (merchant?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? merchant!.trimmingCharacters(in: .whitespacesAndNewlines)
            : AppLanguage.localized("הוצאה כללית", "General expense")

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
