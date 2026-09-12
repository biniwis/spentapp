import Foundation

/// Lightweight service tracking user engagement and awareness days.
///
/// Anchored to the core philosophy of SPENT:
/// Awareness, review, and checking the city is what gets rewarded with a streak —
/// not spending money.
public final class TrackingActivityService: @unchecked Sendable {
    public static let shared = TrackingActivityService()

    private let lock = NSLock()
    private let defaults: UserDefaults
    private let storageKey = "spent_tracking_active_days"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func dayKey(for date: Date) -> String {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Records that the user actively opened and checked SPENT today.
    public func recordActiveToday() {
        lock.lock()
        defer { lock.unlock() }

        let todayKey = dayKey(for: Date())
        var days = defaults.stringArray(forKey: storageKey) ?? []
        if !days.contains(todayKey) {
            days.append(todayKey)
            defaults.set(days, forKey: storageKey)
        }
    }

    /// Checks if the user was already active today.
    public func isActiveToday() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let todayKey = dayKey(for: Date())
        let days = defaults.stringArray(forKey: storageKey) ?? []
        return days.contains(todayKey)
    }

    /// Calculates the current consecutive tracking streak in days.
    public func currentStreakDays() -> Int {
        lock.lock()
        defer { lock.unlock() }

        let daysArray = defaults.stringArray(forKey: storageKey) ?? []
        guard !daysArray.isEmpty else { return 0 }
        let daysSet = Set(daysArray)

        let cal = Calendar.current
        let today = Date()
        let todayKey = dayKey(for: today)

        var streak = 0
        var checkDate: Date

        if daysSet.contains(todayKey) {
            checkDate = today
        } else if let yesterday = cal.date(byAdding: .day, value: -1, to: today),
                  daysSet.contains(dayKey(for: yesterday)) {
            checkDate = yesterday
        } else {
            return 0
        }

        while daysSet.contains(dayKey(for: checkDate)) {
            streak += 1
            guard let prevDay = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }

        return streak
    }
}
