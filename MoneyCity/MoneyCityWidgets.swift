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
        isHebrew: Bool,
        currencySymbol: String = "₪"
    ) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            #if DEBUG
            print("[MoneyCityWidgets] Error: App Group container '\(appGroupIdentifier)' is not accessible. Check entitlements and provisioning.")
            #endif
            return
        }

        let language = isHebrew ? "he" : "en"
        // A parent view can appear again without any visible widget data changing.
        // Avoid waking WidgetKit and rewriting the same App Group snapshot in that case.
        if defaults.object(forKey: "widget_monthly_spent") != nil,
           defaults.double(forKey: "widget_monthly_spent") == spent,
           defaults.double(forKey: "widget_monthly_budget") == budget,
           defaults.double(forKey: "widget_monthly_savings") == savings,
           defaults.string(forKey: "widget_recent_merchant") == recentMerchant,
           defaults.string(forKey: "app_language_pref") == language,
           defaults.string(forKey: "app_language") == language,
           defaults.string(forKey: "widget_currency_symbol") == currencySymbol { return }

        defaults.set(spent, forKey: "widget_monthly_spent")
        defaults.set(budget, forKey: "widget_monthly_budget")
        defaults.set(savings, forKey: "widget_monthly_savings")
        defaults.set(recentMerchant, forKey: "widget_recent_merchant")
        defaults.set(isHebrew ? "he" : "en", forKey: "app_language_pref")
        defaults.set(isHebrew ? "he" : "en", forKey: "app_language")
        defaults.set(currencySymbol, forKey: "widget_currency_symbol")

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
