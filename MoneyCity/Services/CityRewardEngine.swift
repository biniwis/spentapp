import Foundation

public enum CityRewardTrigger: String, Codable, Sendable {
    case weeklyPresence, quietPeriod
}

public struct CityRewardContext: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public let trigger: CityRewardTrigger
    public let unlockedAt: Date
    public var headline: String { "משהו חדש בעיר" }
    public var reasonText: String {
        trigger == .weeklyPresence ? "עוד שבוע עבר בעיר." : "העיר הייתה שקטה מהרגיל בשלושת הימים האחרונים."
    }
}

public struct CityRewardProgress: Sendable {
    public let daysRemaining: Int
    public let daysElapsed: Int
    public let totalCycleDays: Int
    public let activeDaysCount: Int
    public let requiredActiveDays: Int
    public let isReady: Bool
    public let progressFraction: Double

    public init(
        daysRemaining: Int,
        daysElapsed: Int,
        totalCycleDays: Int = 7,
        activeDaysCount: Int,
        requiredActiveDays: Int = 3,
        isReady: Bool,
        progressFraction: Double
    ) {
        self.daysRemaining = daysRemaining
        self.daysElapsed = daysElapsed
        self.totalCycleDays = totalCycleDays
        self.activeDaysCount = activeDaysCount
        self.requiredActiveDays = requiredActiveDays
        self.isReady = isReady
        self.progressFraction = progressFraction
    }
}

/// Persisted separately from inventory: no SwiftData schema or existing records change.
public struct CityRewardState: Codable {
    public var lastWeeklyRewardDate: Date?
    public var lastSurpriseRewardDate: Date?
    public var lastAnyRewardDate: Date?
    public var reconciledInventoryDate: Date?
    public var pending: CityRewardContext?
    public var promptedID: UUID?
    public var lastPresentationDate: Date?
    public var activeDays: [Date] = []
    public var counters: [String: Int] = [:]
    public init() {}
}

public struct CityRewardEngine {
    public static let storageKey = "cityRewardState.v1"
    public var state: CityRewardState
    public var calendar: Calendar = .current

    public init(defaults: UserDefaults = .standard) {
        state = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(CityRewardState.self, from: $0) } ?? CityRewardState()
    }
    public func save(defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.storageKey) }
    }
    private func day(_ date: Date) -> Date { calendar.startOfDay(for: date) }
    private func adding(_ days: Int, to date: Date) -> Date { calendar.date(byAdding: .day, value: days, to: date)! }
    public mutating func recordVisit(at now: Date) {
        state.activeDays = Array(Set(state.activeDays.filter { $0 >= adding(-35, to: day(now)) } + [day(now)]))
    }
    public mutating func evaluate(expenses: [CityCompanions.Expense], firstUse: Date, latestClaim: Date?, now: Date) {
        // Reconcile old inventory and a save interrupted between inventory and reward-state writes.
        if let latestClaim, latestClaim > max(state.lastAnyRewardDate ?? .distantPast, state.reconciledInventoryDate ?? .distantPast) {
            state.reconciledInventoryDate = latestClaim
            state.lastAnyRewardDate = latestClaim
            state.lastWeeklyRewardDate = latestClaim
            state.pending = nil
        }
        guard state.pending == nil,
              state.lastAnyRewardDate.map({ now >= adding(4, to: $0) }) ?? true else { return }
        let valid = expenses.filter { $0.date <= now && $0.amount.isFinite && $0.amount > 0 }
        let cycleStart = max(firstUse, state.lastWeeklyRewardDate ?? firstUse)
        let activeStart = max(day(cycleStart), adding(-6, to: day(now)))
        let active = Set((state.activeDays + valid.map(\.date)).filter { $0 >= activeStart && $0 <= now }.map(day))
        if now >= adding(7, to: cycleStart), active.count >= 3 {
            unlock(.weeklyPresence, now: now)
            return
        }
        guard state.lastSurpriseRewardDate.map({ $0 < cycleStart && now >= adding(4, to: $0) }) ?? true else { return }
        // Three completed days, compared with the preceding 21 days. Never overlap the baseline.
        let end = day(now), recentStart = adding(-3, to: end), baselineStart = adding(-24, to: end)
        let excluded: Set<String> = ["housing", "subscriptions", "health", "finance", "savings", "other"]
        let everyday = valid.filter { !excluded.contains($0.category) }
        let recent = everyday.filter { $0.date >= recentStart && $0.date < end }
        let baseline = everyday.filter { $0.date >= baselineStart && $0.date < recentStart }
        guard let oldest = baseline.map(\.date).min(), oldest <= adding(-14, to: recentStart),
              Set(baseline.map { day($0.date) }).count >= 7,
              Set(recent.map { day($0.date) }).count >= 2 else { return }
        let baselineAverage = baseline.reduce(0) { $0 + $1.amount } / 21
        let recentAverage = recent.reduce(0) { $0 + $1.amount } / 3
        if baselineAverage > 0, recentAverage < baselineAverage * 0.7 { unlock(.quietPeriod, now: now) }
    }
    private mutating func unlock(_ trigger: CityRewardTrigger, now: Date) {
        state.pending = CityRewardContext(trigger: trigger, unlockedAt: now)
        state.counters[trigger == .weeklyPresence ? "reward_trigger_weekly_count" : "reward_trigger_surprise_count", default: 0] += 1
    }
    public func canPresent(at now: Date) -> Bool {
        guard let pending = state.pending, state.promptedID != pending.id else { return false }
        return state.lastPresentationDate.map { day($0) < day(now) } ?? true
    }
    public mutating func markPresented(at now: Date) {
        state.promptedID = state.pending?.id
        state.lastPresentationDate = now
    }
    public func canClaim(at now: Date) -> Bool {
        state.pending != nil && (state.lastAnyRewardDate.map { day($0) < day(now) } ?? true)
    }
    public mutating func claim(at now: Date) {
        guard canClaim(at: now), let pending = state.pending else { return }
        if pending.trigger == .weeklyPresence { state.lastWeeklyRewardDate = now }
        else { state.lastSurpriseRewardDate = now }
        state.lastAnyRewardDate = now
        state.pending = nil
        state.counters["reward_claimed_count", default: 0] += 1
    }
    public mutating func dismiss() {
        if state.pending != nil { state.counters["reward_dismissed_count", default: 0] += 1 }
    }

    public func progress(firstUse: Date = Date(), now: Date = Date()) -> CityRewardProgress {
        if state.pending != nil {
            return CityRewardProgress(
                daysRemaining: 0,
                daysElapsed: 7,
                totalCycleDays: 7,
                activeDaysCount: 3,
                requiredActiveDays: 3,
                isReady: true,
                progressFraction: 1.0
            )
        }
        let cycleStart = max(firstUse, state.lastWeeklyRewardDate ?? firstUse)
        let startOfCycle = calendar.startOfDay(for: cycleStart)
        let startOfNow = calendar.startOfDay(for: now)
        let calendarDaysDiff = max(0, calendar.dateComponents([.day], from: startOfCycle, to: startOfNow).day ?? 0)
        let daysElapsed = min(7, calendarDaysDiff)
        let daysRemaining = max(0, 7 - daysElapsed)

        let activeStart = max(startOfCycle, calendar.date(byAdding: .day, value: -6, to: startOfNow) ?? startOfNow)
        let active = Set(state.activeDays.filter { $0 >= activeStart && $0 <= now }.map { calendar.startOfDay(for: $0) })
        let activeCount = active.count

        let fraction = min(1.0, max(0.08, Double(daysElapsed) / 7.0))
        let isReady = daysRemaining == 0 && activeCount >= 3

        return CityRewardProgress(
            daysRemaining: daysRemaining,
            daysElapsed: daysElapsed,
            totalCycleDays: 7,
            activeDaysCount: activeCount,
            requiredActiveDays: 3,
            isReady: isReady,
            progressFraction: fraction
        )
    }
    #if DEBUG
    public mutating func debugTrigger(_ trigger: CityRewardTrigger) { unlock(trigger, now: Date()) }
    public mutating func debugResetCooldowns() {
        state.reconciledInventoryDate = state.lastAnyRewardDate ?? state.reconciledInventoryDate
        state.lastWeeklyRewardDate = nil
        state.lastSurpriseRewardDate = nil
        state.lastAnyRewardDate = nil
        state.lastPresentationDate = nil
        state.promptedID = nil
    }
    #endif
}
