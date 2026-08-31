import AppIntents

/// Exposes the App Shortcut to the iOS Shortcuts App and Siri.
public struct MoneyCityShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWalletPaymentIntent(),
            phrases: [
                "קלוט תשלום ב-\(.applicationName)",
                "Capture payment in \(.applicationName)"
            ],
            shortTitle: "קליטת תשלום",
            systemImageName: "wallet.pass.fill"
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

        AppShortcut(
            intent: ScanReceiptIntent(),
            phrases: [
                "סרוק צילום מסך ב-\(.applicationName)",
                "סרוק קבלה ב-\(.applicationName)",
                "Scan receipt in \(.applicationName)"
            ],
            shortTitle: "סריקת צילום מסך",
            systemImageName: "camera.viewfinder"
        )
    }
}
