import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Weekly spending reminder and transactional notifications for Apple Pay ingests.
public enum NotificationService {

    public static let weeklyIdentifier = "moneycity.weekly.summary"
    public static let monthlyRecapIdentifier = "moneycity.monthly.recap"
    public static let categoryMissingAmount = "moneycity.missing_amount"
    public static let actionEnterAmount = "ACTION_ENTER_AMOUNT"

    public static var isEnabled: Bool {
        let defaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard
        return defaults.object(forKey: "notifications_enabled") as? Bool ?? true
    }

    public static var isCaptureNotificationEnabled: Bool {
        let defaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard
        return defaults.object(forKey: "expense_capture_notifications_enabled") as? Bool ?? true
    }

    /// Call on launch and whenever the user flips the toggle.
    public static func sync(enabled: Bool, isHebrew: Bool) {
        let defaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard
        defaults.set(enabled, forKey: "notifications_enabled")
        #if canImport(UserNotifications)
        registerNotificationCategories()
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [weeklyIdentifier, monthlyRecapIdentifier])
            return
        }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async {
                    defaults.set(false, forKey: "notifications_enabled")
                }
                return
            }
            scheduleWeeklyNotification(isHebrew: isHebrew)
            scheduleMonthlyRecapNotification(isHebrew: isHebrew)
            Task { @MainActor in
                CityNarrativeEngine.shared.onAppForeground()
            }
        }
        #endif
    }

    #if canImport(UserNotifications)
    private static let delegate = NotificationDelegate()

    public static func setupDelegate() {
        UNUserNotificationCenter.current().delegate = delegate
        registerNotificationCategories()
    }

    private static func registerNotificationCategories() {
        let enterAmountAction = UNTextInputNotificationAction(
            identifier: actionEnterAmount,
            title: AppLanguage.localized("הזן סכום", "Enter amount"),
            options: [],
            textInputButtonTitle: AppLanguage.localized("שמור", "Save"),
            textInputPlaceholder: AppLanguage.localized("למשל: 48.50", "For example: 48.50")
        )

        let missingAmountCategory = UNNotificationCategory(
            identifier: categoryMissingAmount,
            actions: [enterAmountAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([missingAmountCategory])
    }

    public static func scheduleWeeklyNotification(isHebrew: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyIdentifier])

        let content = UNMutableNotificationContent()
        content.title = isHebrew ? "העיר שלך מחכה לך 🏙️" : "Your City Awaits 🏙️"
        content.body = isHebrew
            ? "עבר עוד שבוע — פתח את SPENT כדי לראות איך ההוצאות שלך עיצבו את קו הרקיע."
            : "Another week has passed — open SPENT to see how your spending shaped the skyline."
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1
        components.hour = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyIdentifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// Schedules a monthly notification for the 1st of every month at 11:00 AM.
    public static func scheduleMonthlyRecapNotification(isHebrew: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [monthlyRecapIdentifier])

        let content = UNMutableNotificationContent()
        content.title = isHebrew ? "הסיכום החודשי של העיר שלך מוכן! 🏙️🎉" : "Your Monthly City Recap is Ready! 🏙️🎉"
        content.body = isHebrew
            ? "חודש חדש נפתח! היכנס לגלות איזה רובע הוביל, מה היה יום השיא ואיך נראה קו הרקיע שלך."
            : "A new month has begun! Tap to discover your top district, peak day, and city story."
        content.sound = .default
        content.userInfo = ["type": "monthly_recap"]

        // Fires on the 1st of every month at 11:00 AM
        var components = DateComponents()
        components.day = 1
        components.hour = 11
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: monthlyRecapIdentifier, content: content, trigger: trigger)
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
        guard isEnabled && isCaptureNotificationEnabled else { return }
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
            content.title = AppLanguage.localized("זוהה זיכוי ע״ס \(formattedAmount) 💰", "Refund of \(formattedAmount) detected 💰")
            content.body = AppLanguage.localized("\(merchant) • ממתין לבדיקתך ב-SPENT", "\(merchant) • Ready for review in SPENT")
        } else {
            content.title = AppLanguage.localized("\(formattedAmount) · \(merchant) נוספו לעיר ✓", "\(formattedAmount) · \(merchant) added to your city ✓")
            content.body = AppLanguage.localized("\(categoryName) התעדכן בתקציב", "\(categoryName) updated in your budget")
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "moneycity.expense.\(UUID().uuidString)",
            content: content,
            trigger: nil // Delivers immediately
        )
        content.userInfo = [
            "type": "expense_logged",
            "amount": amount,
            "currency": currency,
            "merchant": merchant,
            "categoryName": categoryName,
            "isRefund": isRefund
        ]
        center.add(request, withCompletionHandler: nil)
    }

    /// Dispatches an interactive notification asking the user to enter the transaction amount.
    public static func sendMissingAmountNotification(pending: PendingWalletIngest) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        dispatchMissingAmountNotification(pending: pending)
                    }
                }
            } else if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                dispatchMissingAmountNotification(pending: pending)
            }
        }
    }

    private static func dispatchMissingAmountNotification(pending: PendingWalletIngest) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()

        content.title = AppLanguage.localized("💳 זוהה תשלום ב-Apple Pay", "💳 Apple Pay payment detected")
        content.body = AppLanguage.localized("ב-\(pending.merchant). הקש להזנת סכום", "At \(pending.merchant). Tap to enter the amount")
        content.categoryIdentifier = categoryMissingAmount
        content.sound = .default

        // Single source of truth: only store identifier & schema version in userInfo
        content.userInfo = [
            "pendingId": pending.id,
            "schemaVersion": 1
        ]

        let request = UNNotificationRequest(
            identifier: "moneycity.missing_amount.\(pending.id)",
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }

    #endif
}

// MARK: - Expense Confirmation Coordinator

public struct PendingExpenseConfirmation: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let amount: Double
    public let merchant: String
    public let timestamp: Date
    public let isRefund: Bool

    public init(
        id: String = UUID().uuidString,
        amount: Double,
        merchant: String,
        timestamp: Date = Date(),
        isRefund: Bool = false
    ) {
        self.id = id
        self.amount = amount
        self.merchant = merchant
        self.timestamp = timestamp
        self.isRefund = isRefund
    }
}

@MainActor
public final class ExpenseConfirmationCoordinator: ObservableObject {
    public static let shared = ExpenseConfirmationCoordinator()

    private let queueKey = "moneycity_pending_confirmations_queue"
    private let defaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard

    @Published public var activeConfirmation: PendingExpenseConfirmation? = nil

    private var lastConfirmedSignature: String? = nil

    private init() {
        let queue = loadQueueInternal()
        if let first = queue.first {
            self.activeConfirmation = first
        }
    }

    public func triggerConfirmation(amount: Double, merchant: String, isRefund: Bool = false) {
        queuePendingConfirmation(amount: amount, merchant: merchant, isRefund: isRefund)
    }

    public func queuePendingConfirmation(amount: Double, merchant: String, isRefund: Bool = false) {
        guard amount > 0 else { return }
        let signature = "\(amount)_\(merchant)_\(Int(Date().timeIntervalSince1970 / 8))"
        guard signature != lastConfirmedSignature else { return }
        lastConfirmedSignature = signature

        let item = PendingExpenseConfirmation(
            amount: amount,
            merchant: merchant,
            timestamp: Date(),
            isRefund: isRefund
        )

        var queue = loadQueueInternal()
        queue.append(item)
        saveQueueInternal(queue)

        self.activeConfirmation = item
    }

    /// Consumes and clears all queued confirmations.
    public func consumeAllPendingConfirmations() -> [PendingExpenseConfirmation] {
        var queue = loadQueueInternal()
        if queue.isEmpty, let active = activeConfirmation {
            queue.append(active)
        }
        defaults.removeObject(forKey: queueKey)
        self.activeConfirmation = nil
        return queue
    }

    public func clearActiveConfirmation() {
        self.activeConfirmation = nil
        defaults.removeObject(forKey: queueKey)
    }

    private func loadQueueInternal() -> [PendingExpenseConfirmation] {
        guard let data = defaults.data(forKey: queueKey),
              let list = try? JSONDecoder().decode([PendingExpenseConfirmation].self, from: data) else {
            return []
        }
        return list
    }

    private func saveQueueInternal(_ queue: [PendingExpenseConfirmation]) {
        if let encoded = try? JSONEncoder().encode(queue) {
            defaults.set(encoded, forKey: queueKey)
        }
    }
}

#if canImport(UserNotifications)
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even if app is in foreground
        completionHandler([.banner, .sound, .badge, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle inline text input from notification action
        if let textResponse = response as? UNTextInputNotificationResponse,
           textResponse.actionIdentifier == NotificationService.actionEnterAmount {
            let userText = textResponse.userText
            guard let parsedDecimal = AmountParser.parse(userText),
                  let pendingId = userInfo["pendingId"] as? String,
                  let pending = PendingWalletStore.shared.get(id: pendingId) else {
                // Invalid input (empty, 0, abc, negative) or missing pending record.
                // Do NOT delete pending record so the user can re-enter. Complete cleanly.
                completionHandler()
                return
            }

            let amount = NSDecimalNumber(decimal: parsedDecimal).doubleValue

            // Save to durable queue in App Group container (safe even when device is locked)
            // Note (F02): The pending record is preserved until WalletIngestCoordinator commits.
            WalletIngestCoordinator.enqueueBackgroundCompletion(
                amount: amount,
                merchant: pending.merchant,
                currency: pending.currency,
                transactionDate: pending.timestamp,
                pendingID: pending.id
            )

            // If device is unlocked and protected data is ready, drain to SwiftData immediately
            #if canImport(UIKit)
            if UIApplication.shared.isProtectedDataAvailable {
                Task { @MainActor in
                    defer { completionHandler() }
                    await WalletIngestCoordinator.drainPendingBackgroundCompletions()
                }
                return
            }
            #endif

            completionHandler()
            return
        }

        // Handle default notification tap
        if let amount = userInfo["amount"] as? Double {
            let merchant = userInfo["merchant"] as? String ?? ""
            let isRefund = userInfo["isRefund"] as? Bool ?? false
            Task { @MainActor in
                ExpenseConfirmationCoordinator.shared.queuePendingConfirmation(
                    amount: amount,
                    merchant: merchant,
                    isRefund: isRefund
                )
            }
        }

        completionHandler()
    }
}
#endif
