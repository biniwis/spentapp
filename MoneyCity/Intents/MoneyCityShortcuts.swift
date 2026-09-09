import AppIntents

/// Exposes the App Shortcut to the iOS Shortcuts App and Siri.
public struct MoneyCityShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickExpensePromptIntent(),
            phrases: [
                "הוסף הוצאה ב-\(.applicationName)",
                "רשום הוצאה ב-\(.applicationName)",
                "Add expense in \(.applicationName)",
                "Quick expense in \(.applicationName)"
            ],
            shortTitle: "הוספת הוצאה",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: RecordTransactionIntent(),
            phrases: [
                "הקלט עסקה ב-\(.applicationName)",
                "רשום תשלום ב-\(.applicationName)",
                "Log payment in \(.applicationName)"
            ],
            shortTitle: "הקלטת עסקה",
            systemImageName: "creditcard.and.123"
        )
    }
}
