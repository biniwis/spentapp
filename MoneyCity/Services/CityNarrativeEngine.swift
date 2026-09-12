import Foundation
import SwiftData
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Intelligent, throttled city narrative engine for SPENT.
///
/// Built on a strict policy of restraint: the city stays silent 98% of the time,
/// speaking only when there is a meaningful behavioral surge or an ingest health anomaly.
public final class CityNarrativeEngine: @unchecked Sendable {
    public static let shared = CityNarrativeEngine()

    public static let idWatchdog = "moneycity.health.ingestWatchdog"
    public static let idWeeklyNarrative = "moneycity.narrative.weekly"

    private let lock = NSLock()
    private let defaults = UserDefaults.standard

    private let keyLastProactiveAttemptDate = "moneycity_last_proactive_attempt_date"
    private let keyScheduledDigestDate = "moneycity_scheduled_digest_delivery_date"
    private let keyLastApplePayDate = "moneycity_last_apple_pay_ingest_date"
    private let keyWatchdogArmedUntil = "moneycity_watchdog_armed_until_date"

    private init() {}

    // MARK: - Persisted State

    /// Tracks the last proactive notification attempt (category surge or scheduled digest).
    /// Because Apple local notification delivery is best-effort, this timestamp represents an attempted
    /// outreach to strictly enforce the 7-day quiet period without spamming the user.
    public var lastProactiveAttemptDate: Date? {
        get { defaults.object(forKey: keyLastProactiveAttemptDate) as? Date }
        set { defaults.set(newValue, forKey: keyLastProactiveAttemptDate) }
    }

    public var scheduledDigestDate: Date? {
        get { defaults.object(forKey: keyScheduledDigestDate) as? Date }
        set { defaults.set(newValue, forKey: keyScheduledDigestDate) }
    }

    public var lastApplePayDate: Date? {
        get { defaults.object(forKey: keyLastApplePayDate) as? Date }
        set { defaults.set(newValue, forKey: keyLastApplePayDate) }
    }

    public var watchdogArmedUntil: Date? {
        get { defaults.object(forKey: keyWatchdogArmedUntil) as? Date }
        set { defaults.set(newValue, forKey: keyWatchdogArmedUntil) }
    }

    // MARK: - State Reconciliation

    /// Reconciles delivered pre-scheduled digests before any new evaluation.
    /// If scheduledDigestDate has passed, iOS attempted delivery while the app was suspended.
    public func reconcileState(now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }

        // If the pre-scheduled digest delivery time has passed, treat it as a completed attempt
        if let scheduled = scheduledDigestDate, scheduled <= now {
            lastProactiveAttemptDate = scheduled
            scheduledDigestDate = nil
        }
    }

    // MARK: - Rate Limiting (Rolling 7 Days)

    /// Checks if a proactive narrative push can be sent now.
    public func isEligibleForProactivePush(now: Date = Date()) -> Bool {
        reconcileState(now: now)
        guard let last = lastProactiveAttemptDate else { return true }
        return now.timeIntervalSince(last) >= 7 * 86400
    }

    // MARK: - Event Hooks

    /// Invoked immediately after an Apple Pay transaction is saved.
    /// Resets and re-arms the Watchdog anchored STRICTLY to this transaction date.
    @MainActor
    public func onApplePayTransactionIngested(
        transactionDate: Date,
        category: SpendingCategory,
        amount: Double,
        currency: String
    ) {
        reconcileState(now: Date())

        lock.lock()
        self.lastApplePayDate = transactionDate
        lock.unlock()

        #if canImport(UserNotifications)
        guard NotificationService.isEnabled else { return }

        // 1. Arm Watchdog based ONLY on the actual transaction date
        armWatchdog(anchorDate: transactionDate)

        // 2. Evaluate Category Surge (INTERESTING)
        evaluateCategorySurge(triggeredCategory: category, currency: currency)

        // 3. Refresh pre-scheduled Weekly Digest for upcoming Sunday
        refreshWeeklyDigestSchedule()
        #endif
    }

    /// Invoked when SPENT enters the foreground or launches.
    /// NEVER advances the watchdog trigger time; only reconciles existing state.
    @MainActor
    public func onAppForeground() {
        reconcileState(now: Date())

        #if canImport(UserNotifications)
        guard NotificationService.isEnabled else { return }

        // Verify watchdog: if missing but eligible and not expired, restore anchored to lastApplePayDate
        if let lastDate = lastApplePayDate {
            let now = Date()
            if let armed = watchdogArmedUntil, armed > now {
                // Watchdog is active and waiting in the future
            } else if watchdogArmedUntil == nil {
                armWatchdog(anchorDate: lastDate)
            }
        }

        // Refresh pre-scheduled Weekly Digest
        refreshWeeklyDigestSchedule()
        #endif
    }

    // MARK: - Watchdog Anomaly Detector

    /// Computes the personalized watchdog delay based on user transaction frequency.
    /// Returns nil if the user does not have an established habit (minimum 4 transactions in 14 days).
    public static func computePersonalizedWatchdogDelay(recentDates: [Date]) -> TimeInterval? {
        guard recentDates.count >= 4 else { return nil }
        let sorted = recentDates.sorted()
        var gaps: [TimeInterval] = []
        for i in 1..<sorted.count {
            let gap = sorted[i].timeIntervalSince(sorted[i - 1])
            if gap > 60 { // Ignore near-simultaneous triggers
                gaps.append(gap)
            }
        }
        guard !gaps.isEmpty else { return 72 * 3600 }
        let medianGap = gaps.sorted()[gaps.count / 2]
        // Anomaly threshold: at least 72 hours, or 3 times the median gap
        return max(72 * 3600, medianGap * 3)
    }

    /// Adjusts an alert delivery date to respectful daytime hours (10:00 - 20:30).
    public static func adjustToSafeDaytime(date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour >= 21 {
            // Push to next morning 10:00
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: date) {
                return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nextDay) ?? date
            }
        } else if hour < 10 {
            // Push to same day 10:00
            return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date) ?? date
        }
        return date
    }

    #if canImport(UserNotifications)
    @MainActor
    private func armWatchdog(anchorDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.idWatchdog])

        let context = DatabaseService.shared.context
        let cutoff = Date().addingTimeInterval(-14 * 86400)
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= cutoff }
        )
        let recent = (try? context.fetch(descriptor)) ?? []
        let recentDates = recent.map { $0.timestamp }

        guard let delay = Self.computePersonalizedWatchdogDelay(recentDates: recentDates) else {
            lock.lock()
            self.watchdogArmedUntil = nil
            lock.unlock()
            return
        }

        let rawTargetDate = anchorDate.addingTimeInterval(delay)
        let safeTargetDate = Self.adjustToSafeDaytime(date: rawTargetDate)
        let timeInterval = safeTargetDate.timeIntervalSince(Date())

        guard timeInterval > 0 else {
            lock.lock()
            self.watchdogArmedUntil = nil
            lock.unlock()
            return
        }

        let content = UNMutableNotificationContent()
        let isHebrew = LocalizationManager.shared.language == .hebrew
        content.title = isHebrew
            ? "לא ראיתי עסקאות Apple Pay כבר זמן מה"
            : "No Apple Pay transactions detected in a while"
        content.body = isHebrew
            ? "אם כן קנית לאחרונה, אולי כדאי לבדוק שהאוטומציה עדיין פעילה."
            : "If you made recent purchases, check that your Shortcut automation is still active."
        content.sound = .default
        content.userInfo = ["type": "health_watchdog"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.idWatchdog, content: content, trigger: trigger)

        center.add(request) { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.watchdogArmedUntil = safeTargetDate
            self.lock.unlock()
        }
    }
    #endif

    // MARK: - Category Surge (INTERESTING)

    #if canImport(UserNotifications)
    @MainActor
    private func evaluateCategorySurge(
        triggeredCategory: SpendingCategory,
        currency: String
    ) {
        guard isEligibleForProactivePush() else { return }

        // Check if current hour is suitable for notification (10:00 - 20:30)
        let currentHour = Calendar.current.component(.hour, from: Date())
        guard currentHour >= 10 && currentHour < 21 else { return }

        let context = DatabaseService.shared.context
        let past7DaysCutoff = Date().addingTimeInterval(-7 * 86400)
        let past35DaysCutoff = Date().addingTimeInterval(-35 * 86400)

        let allRecentDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= past35DaysCutoff }
        )
        let allTransactions = (try? context.fetch(allRecentDescriptor)) ?? []

        let categoryRaw = triggeredCategory.rawValue
        let matching = allTransactions.filter { $0.categoryRawValue == categoryRaw && $0.amount > 0 }

        let last7DaysSpent = matching
            .filter { $0.timestamp >= past7DaysCutoff }
            .reduce(0.0) { $0 + $1.amount }

        let prior28DaysSpent = matching
            .filter { $0.timestamp < past7DaysCutoff }
            .reduce(0.0) { $0 + $1.amount }

        let priorWeeklyAverage = prior28DaysSpent / 4.0

        // Surge Condition: spent >= 1.8x historical weekly average AND absolute spend >= 120
        guard priorWeeklyAverage >= 40.0,
              last7DaysSpent >= priorWeeklyAverage * 1.8,
              last7DaysSpent >= 120.0 else {
            return
        }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        let lang = LocalizationManager.shared.language
        let isHebrew = lang == .hebrew
        let categoryName = triggeredCategory.displayName(for: lang)

        content.title = isHebrew
            ? "האזור של \(categoryName) נהיה די צפוף השבוע 🏙️"
            : "\(categoryName) had a busy week in your city 🏙️"
        content.body = isHebrew
            ? "הוצאת שם בערך פי 2 מהרגיל (\(currency)\(Int(last7DaysSpent)) השבוע)."
            : "Spending here was about 2x your usual pace (\(currency)\(Int(last7DaysSpent)) this week)."
        content.sound = .default
        content.userInfo = ["type": "category_surge"]

        let request = UNNotificationRequest(
            identifier: "moneycity.narrative.surge.\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )
        center.add(request, withCompletionHandler: nil)

        // Update rate limiting
        self.lastProactiveAttemptDate = Date()

        // Cancel the scheduled Sunday Weekly Digest (the single proactive slot was consumed!)
        center.removePendingNotificationRequests(withIdentifiers: [Self.idWeeklyNarrative])
        self.scheduledDigestDate = nil
    }
    #endif

    // MARK: - Pre-scheduled Weekly Digest

    #if canImport(UserNotifications)
    @MainActor
    private func refreshWeeklyDigestSchedule() {
        let center = UNUserNotificationCenter.current()

        // If a proactive notification was already sent in the last 7 days, don't schedule a digest
        guard isEligibleForProactivePush() else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.idWeeklyNarrative])
            self.scheduledDigestDate = nil
            return
        }

        let calendar = Calendar.current
        var comp = DateComponents()
        comp.weekday = 1 // Sunday
        comp.hour = 20
        comp.minute = 0

        guard let nextSunday = calendar.nextDate(after: Date(), matching: comp, matchingPolicy: .nextTime) else {
            return
        }

        let context = DatabaseService.shared.context
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: nextSunday) ?? Date()
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= startOfWeek && $0.amount > 0 }
        )
        let weekTransactions = (try? context.fetch(descriptor)) ?? []

        guard !weekTransactions.isEmpty else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.idWeeklyNarrative])
            self.scheduledDigestDate = nil
            return
        }

        let totalSpent = weekTransactions.reduce(0.0) { $0 + $1.amount }
        let currency = weekTransactions.first?.currency ?? "₪"
        let count = weekTransactions.count

        // Find top category
        var categoryTotals: [String: Double] = [:]
        for tx in weekTransactions {
            categoryTotals[tx.categoryRawValue, default: 0] += tx.amount
        }
        let topCategoryRaw = categoryTotals.max(by: { $0.value < $1.value })?.key ?? "shopping"
        let topCategory = SpendingCategory(rawValue: topCategoryRaw) ?? .shopping
        let lang = LocalizationManager.shared.language
        let isHebrew = lang == .hebrew

        let content = UNMutableNotificationContent()
        content.title = isHebrew
            ? "השבוע בעיר: \(currency)\(Int(totalSpent)) · \(count) רכישות"
            : "This week in your city: \(currency)\(Int(totalSpent)) · \(count) purchases"
        content.body = isHebrew
            ? "הכי הרבה כסף עבר בקטגוריית \(topCategory.displayName(for: lang)) השבוע."
            : "Most spending this week was in \(topCategory.displayName(for: lang))."
        content.sound = .default
        content.userInfo = ["type": "weekly_digest"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.weekday, .hour, .minute], from: nextSunday), repeats: false)
        let request = UNNotificationRequest(identifier: Self.idWeeklyNarrative, content: content, trigger: trigger)

        center.add(request) { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.scheduledDigestDate = nextSunday
            self.lock.unlock()
        }
    }
    #endif
}
