import AppIntents

/// Exposes the App Shortcut to the iOS Shortcuts App and Siri.
public struct MoneyCityShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickExpensePromptIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Quick expense in \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: RecordTransactionIntent(),
            phrases: [
                "Log payment in \(.applicationName)",
                "Record transaction in \(.applicationName)"
            ],
            shortTitle: "Record Transaction",
            systemImageName: "creditcard.and.123"
        )
    }
}
