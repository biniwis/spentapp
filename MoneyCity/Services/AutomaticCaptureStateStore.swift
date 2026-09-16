import Foundation

/// Lifecycle state for Automatic Capture.
public enum AutomaticCaptureState: Equatable, Sendable {
    case notConfigured
    case setupInProgress
    case configuredAwaitingFirstCapture
    case captureDetected(Date)

    public static func == (lhs: AutomaticCaptureState, rhs: AutomaticCaptureState) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured):
            return true
        case (.setupInProgress, .setupInProgress):
            return true
        case (.configuredAwaitingFirstCapture, .configuredAwaitingFirstCapture):
            return true
        case let (.captureDetected(d1), .captureDetected(d2)):
            return abs(d1.timeIntervalSince1970 - d2.timeIntervalSince1970) < 0.001
        default:
            return false
        }
    }
}

/// Single source of truth for Automatic Capture lifecycle state, TTL, and persistence.
public final class AutomaticCaptureStateStore: @unchecked Sendable {
    public static let shared = AutomaticCaptureStateStore()

    // MARK: - Centralized Keys
    public enum Key {
        public static let setupCompletedAt = "spent.capture.setup.completedAt"
        public static let lastDetectedAt = "spent.capture.lastDetectedAt"

        public static let guideScreen = "spent.capture.guide.screen"
        public static let guideUpdatedAt = "spent.capture.guide.updatedAt"

        public static let guideLegacyStep = "spent.capture.guide.legacy.step"
        public static let guideLegacyUpdatedAt = "spent.capture.guide.legacy.updatedAt"

        public static let bootstrapV1 = "spent.capture.bootstrap.v1"
    }

    /// 24-hour TTL for in-progress setup guide.
    public static let setupProgressTTL: TimeInterval = 24 * 60 * 60

    public let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - State Precedence
    //
    // A. Last automatic capture exists: spent.capture.lastDetectedAt -> .captureDetected(date)
    // B. Setup was completed: spent.capture.setup.completedAt -> .configuredAwaitingFirstCapture
    // C. Fresh guide progress exists (< 24h) -> .setupInProgress
    // D. Otherwise -> .notConfigured
    public func state(now: Date = Date()) -> AutomaticCaptureState {
        // A. Last automatic capture exists
        if let detectedTimestamp = userDefaults.object(forKey: Key.lastDetectedAt) as? Double, detectedTimestamp > 0 {
            return .captureDetected(Date(timeIntervalSince1970: detectedTimestamp))
        }

        // B. Setup completed
        if let completedTimestamp = userDefaults.object(forKey: Key.setupCompletedAt) as? Double, completedTimestamp > 0 {
            return .configuredAwaitingFirstCapture
        }

        // C. Fresh guide progress
        let freshIOS27 = hasFreshIOS27Progress(now: now)
        let freshLegacy = hasFreshLegacyProgress(now: now)
        if freshIOS27 || freshLegacy {
            return .setupInProgress
        }

        // D. Otherwise
        return .notConfigured
    }

    // MARK: - iOS 27 Guide Progress
    public func saveIOS27Progress(screen: Int, at date: Date = Date()) {
        userDefaults.set(screen, forKey: Key.guideScreen)
        userDefaults.set(date.timeIntervalSince1970, forKey: Key.guideUpdatedAt)
    }

    public func hasFreshIOS27Progress(now: Date = Date()) -> Bool {
        guard let updatedTimestamp = userDefaults.object(forKey: Key.guideUpdatedAt) as? Double, updatedTimestamp > 0 else {
            return false
        }
        let updatedDate = Date(timeIntervalSince1970: updatedTimestamp)
        let elapsed = now.timeIntervalSince(updatedDate)
        if elapsed >= 0 && elapsed < Self.setupProgressTTL {
            return userDefaults.object(forKey: Key.guideScreen) != nil
        } else {
            // Expired (> 24 hours): reset and treat as nonexistent
            clearIOS27Progress()
            return false
        }
    }

    public func getFreshIOS27Progress(now: Date = Date()) -> Int? {
        if hasFreshIOS27Progress(now: now) {
            return userDefaults.integer(forKey: Key.guideScreen)
        }
        return nil
    }

    private func clearIOS27Progress() {
        userDefaults.removeObject(forKey: Key.guideScreen)
        userDefaults.removeObject(forKey: Key.guideUpdatedAt)
    }

    // MARK: - Legacy Guide Progress
    public func saveLegacyProgress(step: Int, at date: Date = Date()) {
        userDefaults.set(step, forKey: Key.guideLegacyStep)
        userDefaults.set(date.timeIntervalSince1970, forKey: Key.guideLegacyUpdatedAt)
    }

    public func hasFreshLegacyProgress(now: Date = Date()) -> Bool {
        guard let updatedTimestamp = userDefaults.object(forKey: Key.guideLegacyUpdatedAt) as? Double, updatedTimestamp > 0 else {
            return false
        }
        let updatedDate = Date(timeIntervalSince1970: updatedTimestamp)
        let elapsed = now.timeIntervalSince(updatedDate)
        if elapsed >= 0 && elapsed < Self.setupProgressTTL {
            return userDefaults.object(forKey: Key.guideLegacyStep) != nil
        } else {
            // Expired (> 24 hours): reset and treat as nonexistent
            clearLegacyProgress()
            return false
        }
    }

    public func getFreshLegacyProgress(now: Date = Date()) -> Int? {
        if hasFreshLegacyProgress(now: now) {
            return userDefaults.integer(forKey: Key.guideLegacyStep)
        }
        return nil
    }

    private func clearLegacyProgress() {
        userDefaults.removeObject(forKey: Key.guideLegacyStep)
        userDefaults.removeObject(forKey: Key.guideLegacyUpdatedAt)
    }

    // MARK: - Completion & Detection
    /// Mark setup as completed.
    /// Stores setup.completedAt, clears both guide progress tracks, but preserves lastDetectedAt.
    public func markSetupCompleted(at date: Date = Date()) {
        userDefaults.set(date.timeIntervalSince1970, forKey: Key.setupCompletedAt)
        resetGuideProgress()
    }

    /// Mark automatic capture detected from Shortcuts invocation.
    /// 1. Set lastDetectedAt
    /// 2. Ensure setup is considered completed
    /// 3. Clear guide progress
    public func markAutomaticCaptureDetected(at date: Date) {
        userDefaults.set(date.timeIntervalSince1970, forKey: Key.lastDetectedAt)
        if userDefaults.object(forKey: Key.setupCompletedAt) == nil {
            userDefaults.set(date.timeIntervalSince1970, forKey: Key.setupCompletedAt)
        }
        resetGuideProgress()
    }

    /// Clears guide screen/step/timestamps without deleting setupCompletedAt or lastDetectedAt.
    public func resetGuideProgress() {
        clearIOS27Progress()
        clearLegacyProgress()
    }

    // MARK: - Bootstrap Flag
    public var isBootstrapped: Bool {
        userDefaults.bool(forKey: Key.bootstrapV1)
    }

    public var hasLastDetectedCapture: Bool {
        if let timestamp = userDefaults.object(forKey: Key.lastDetectedAt) as? Double, timestamp > 0 {
            return true
        }
        return false
    }

    public func markBootstrapped() {
        userDefaults.set(true, forKey: Key.bootstrapV1)
    }

    // MARK: - Intent Validation
    public static func isAutomaticCaptureIntent(_ intentName: String) -> Bool {
        intentName == "RecordTransactionIntent" || intentName == "LogWalletPaymentIntent"
    }

    // MARK: - Static Convenience Forwarders
    public static func state(now: Date = Date()) -> AutomaticCaptureState {
        shared.state(now: now)
    }

    public static func saveIOS27Progress(screen: Int, at date: Date = Date()) {
        shared.saveIOS27Progress(screen: screen, at: date)
    }

    public static func getFreshIOS27Progress(now: Date = Date()) -> Int? {
        shared.getFreshIOS27Progress(now: now)
    }

    public static func saveLegacyProgress(step: Int, at date: Date = Date()) {
        shared.saveLegacyProgress(step: step, at: date)
    }

    public static func getFreshLegacyProgress(now: Date = Date()) -> Int? {
        shared.getFreshLegacyProgress(now: now)
    }

    public static func markSetupCompleted(at date: Date = Date()) {
        shared.markSetupCompleted(at: date)
    }

    public static func markAutomaticCaptureDetected(at date: Date) {
        shared.markAutomaticCaptureDetected(at: date)
    }

    public static func resetGuideProgress() {
        shared.resetGuideProgress()
    }

    public static var isBootstrapped: Bool {
        shared.isBootstrapped
    }

    public static var hasLastDetectedCapture: Bool {
        shared.hasLastDetectedCapture
    }

    public static func markBootstrapped() {
        shared.markBootstrapped()
    }

    // MARK: - Date Formatting (No em-dash / en-dash, clean and localized)
    public static func formatLastDetected(date: Date, isHebrew: Bool, calendar: Calendar = .current) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar

        if calendar.isDateInToday(date) {
            if isHebrew {
                timeFormatter.locale = Locale(identifier: "he_IL")
                timeFormatter.dateFormat = "HH:mm"
                return "קליטה אחרונה היום, \(timeFormatter.string(from: date))"
            } else {
                timeFormatter.locale = Locale(identifier: "en_US")
                timeFormatter.dateFormat = "h:mm a"
                return "Last capture today, \(timeFormatter.string(from: date))"
            }
        } else if calendar.isDateInYesterday(date) {
            if isHebrew {
                timeFormatter.locale = Locale(identifier: "he_IL")
                timeFormatter.dateFormat = "HH:mm"
                return "קליטה אחרונה אתמול, \(timeFormatter.string(from: date))"
            } else {
                timeFormatter.locale = Locale(identifier: "en_US")
                timeFormatter.dateFormat = "h:mm a"
                return "Last capture yesterday, \(timeFormatter.string(from: date))"
            }
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = calendar
            if isHebrew {
                dateFormatter.locale = Locale(identifier: "he_IL")
                dateFormatter.dateFormat = "d בMMMM, HH:mm"
                return "קליטה אחרונה: \(dateFormatter.string(from: date))"
            } else {
                dateFormatter.locale = Locale(identifier: "en_US")
                dateFormatter.dateFormat = "MMM d, h:mm a"
                return "Last capture: \(dateFormatter.string(from: date))"
            }
        }
    }
}
