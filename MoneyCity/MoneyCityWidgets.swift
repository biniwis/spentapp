import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Dedicated publisher for widget data.
///
/// Keeps the main app decoupled from Widget UI/Providers, publishing real ledger metrics
/// strictly into the shared App Group container.
public enum MoneyCityWidgets {
    public static let appGroupIdentifier = "group.com.moneycity.app"

    /// Publishes the latest real ledger totals to the App Group container and triggers WidgetKit reload.
    public static func publishData(
        spent: Double,
        budget: Double,
        savings: Double,
        recentMerchant: String,
        isHebrew: Bool
    ) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            #if DEBUG
            print("[MoneyCityWidgets] Error: App Group container '\(appGroupIdentifier)' is not accessible. Check entitlements and provisioning.")
            #endif
            return
        }

        defaults.set(spent, forKey: "widget_monthly_spent")
        defaults.set(budget, forKey: "widget_monthly_budget")
        defaults.set(savings, forKey: "widget_monthly_savings")
        defaults.set(recentMerchant, forKey: "widget_recent_merchant")
        defaults.set(isHebrew ? "he" : "en", forKey: "app_language_pref")
        defaults.set(isHebrew ? "he" : "en", forKey: "app_language")

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
