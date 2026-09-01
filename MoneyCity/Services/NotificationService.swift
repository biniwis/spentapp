import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Weekly spending reminder. The "notifications_enabled" preference used to be stored
/// and never acted on; this service is what actually schedules and cancels it.
public enum NotificationService {

    public static let weeklyIdentifier = "moneycity.weekly.summary"

    public static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "notifications_enabled") as? Bool ?? true
    }

    /// Call on launch and whenever the user flips the toggle.
    public static func sync(enabled: Bool, isHebrew: Bool) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [weeklyIdentifier])
            return
        }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async {
                    UserDefaults.standard.set(false, forKey: "notifications_enabled")
                }
                return
            }
            scheduleWeekly(isHebrew: isHebrew)
        }
        #endif
    }

    #if canImport(UserNotifications)
    private static let delegate = NotificationDelegate()

    public static func setupDelegate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
    }

    private static func scheduleWeekly(isHebrew: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyIdentifier])

        let content = UNMutableNotificationContent()
        content.title = isHebrew ? "סיכום שבועי בעיר" : "Weekly City Summary"
        content.body = isHebrew
            ? "בוא לראות איך העיר שלך השתנתה השבוע."
            : "See how your city changed this week."
        content.sound = .default

        // Sunday 20:00 local time — start of the Israeli work week.
        var components = DateComponents()
        components.weekday = 1
        components.hour = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyIdentifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// Dispatches an immediate confirmation notification when an Apple Pay expense is logged.
    public static func sendExpenseLoggedNotification(
        amount: Double,
        currency: String = "₪",
        categoryName: String,
        merchant: String,
        isRefund: Bool = false
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        dispatchNotification(amount: amount, currency: currency, categoryName: categoryName, merchant: merchant, isRefund: isRefund)
                    }
                }
            } else if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                dispatchNotification(amount: amount, currency: currency, categoryName: categoryName, merchant: merchant, isRefund: isRefund)
            }
        }
    }

    private static func dispatchNotification(
        amount: Double,
        currency: String,
        categoryName: String,
        merchant: String,
        isRefund: Bool
    ) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        
        let amountFormatted = (amount.truncatingRemainder(dividingBy: 1) == 0)
            ? String(format: "%.0f", amount)
            : String(format: "%.2f", amount)
        let formattedAmount = "\(currency)\(amountFormatted)"
        
        if isRefund {
            content.title = "זוהה זיכוי ע״ס \(formattedAmount) 💰"
            content.body = "\(merchant) • ממתין לבדיקתך ב-SPENT"
        } else {
            content.title = "נוספו \(formattedAmount) ל\(categoryName) לתקציב 🏙️"
            content.body = "עסקה ב-\(merchant) נקלטה בהצלחה"
        }
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "moneycity.expense.\(UUID().uuidString)",
            content: content,
            trigger: nil // Delivers immediately
        )
        center.add(request, withCompletionHandler: nil)
    }

    /// Schedules a realistic simulated Apple Pay transaction notification to fire on the lock screen after a delay.
    public static func scheduleLockScreenFakePurchase(
        amount: Double = 142.50,
        merchant: String = "שופרסל דיל",
        categoryName: String = "קניות וסופרמרקט",
        delaySeconds: TimeInterval = 4.0,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                completion?(false)
                return
            }
            
            let content = UNMutableNotificationContent()
            let formattedAmount = "₪" + (amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", amount) : String(format: "%.2f", amount))
            content.title = "Apple Pay • \(merchant)"
            content.subtitle = "עסקה ע״ס \(formattedAmount) אושרה בהצלחה"
            content.body = "נקלט ונצבר ב-SPENT • \(categoryName)"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1.0, delaySeconds), repeats: false)
            let request = UNNotificationRequest(
                identifier: "moneycity.fake.purchase.\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                completion?(error == nil)
            }
        }
    }
    #endif
}

#if canImport(UserNotifications)
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even if app is in the foreground
        completionHandler([.banner, .sound, .badge, .list])
    }
}
#endif
