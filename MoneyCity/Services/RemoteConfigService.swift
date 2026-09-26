import Foundation
import SwiftUI
import Combine

// MARK: - Remote Config Models (Schema Version 1)

public struct RemoteConfigRoot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var revision: Int
    public var features: [String: Bool]
    public var announcement: RemoteAnnouncement?
    public var copy: [String: [String: String]]
    public var captureGuide: RemoteCaptureGuideConfig
    public var notifications: RemoteNotificationConfig
    public var merchantOverrides: [RemoteMerchantOverride]

    public init(
        schemaVersion: Int = 1,
        revision: Int = 1,
        features: [String: Bool] = [:],
        announcement: RemoteAnnouncement? = nil,
        copy: [String: [String: String]] = [:],
        captureGuide: RemoteCaptureGuideConfig = RemoteCaptureGuideConfig(),
        notifications: RemoteNotificationConfig = RemoteNotificationConfig(),
        merchantOverrides: [RemoteMerchantOverride] = []
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.features = features
        self.announcement = announcement
        self.copy = copy
        self.captureGuide = captureGuide
        self.notifications = notifications
        self.merchantOverrides = merchantOverrides
    }

    public static var bundledDefault: RemoteConfigRoot {
        RemoteConfigRoot(
            schemaVersion: 1,
            revision: 1,
            features: [
                "notifications": true,
                "automaticCapture": true,
                "receiptScanner": false,
                "weeklyAdditions": true,
                "savingsGoals": true,
                "communityMerchantLearning": false
            ],
            announcement: nil,
            copy: [:],
            captureGuide: RemoteCaptureGuideConfig(mode: "native", forceVariant: nil, revision: 1, steps: nil),
            notifications: RemoteNotificationConfig(
                weeklyDigest: nil,
                monthlyRecap: nil,
                cityNarrativeEnabled: true,
                captureHealthCheckEnabled: true
            ),
            merchantOverrides: baselineCuratedMerchantOverrides
        )
    }

    public static let baselineCuratedMerchantOverrides: [RemoteMerchantOverride] = [
        // Food / Delivery
        RemoteMerchantOverride(match: "wolt", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "וולט", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "10bis", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "תן ביס", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "tabit", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "טאביט", mode: "exact", category: "food"),

        // Supermarkets & Groceries
        RemoteMerchantOverride(match: "shufersal", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "שופרסל", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "שופרסל דיל", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "שופרסל שלי", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "שופרסל אקספרס", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "יש חסד", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "יש בשכונה", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "rami levy", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "רמי לוי", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "am:pm", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "victory", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "ויקטורי", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "carrefour", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "קרפור", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "יוחננוף", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "yohanof", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "yohananof", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "טיב טעם", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "tiv taam", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "אושר עד", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "osher ad", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "חצי חינם", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "hazi hinam", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "מגה בעיר", mode: "exact", category: "food"),

        // Major Coffee & Bakeries
        RemoteMerchantOverride(match: "aroma", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "ארומה", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "arcaffe", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "ארקפה", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "landwer", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "לנדוור", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "קפה גרג", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "רולדין", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "roladin", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "גולדה", mode: "exact", category: "food"),
        RemoteMerchantOverride(match: "golda", mode: "exact", category: "food"),

        // Transit & Parking
        RemoteMerchantOverride(match: "gett", mode: "exact", category: "transport"),
        RemoteMerchantOverride(match: "גט", mode: "exact", category: "transport"),
        RemoteMerchantOverride(match: "uber", mode: "exact", category: "transport"),
        RemoteMerchantOverride(match: "אובר", mode: "exact", category: "transport"),
        RemoteMerchantOverride(match: "pango", mode: "exact", category: "transport"),
        RemoteMerchantOverride(match: "פנגו", mode: "exact", category: "transport"),
        RemoteMerchantOverride(match: "cellopark", mode: "exact", category: "transport"),
        RemoteMerchantOverride(match: "סלופארק", mode: "exact", category: "transport"),
        RemoteMerchantOverride(match: "rav kav", mode: "exact", category: "transport"),
        RemoteMerchantOverride(match: "רב קו", mode: "exact", category: "transport"),

        // Pharmacies
        RemoteMerchantOverride(match: "super-pharm", mode: "exact", category: "health"),
        RemoteMerchantOverride(match: "super pharm", mode: "exact", category: "health"),
        RemoteMerchantOverride(match: "סופר-פארם", mode: "exact", category: "health"),
        RemoteMerchantOverride(match: "סופר פארם", mode: "exact", category: "health"),
        RemoteMerchantOverride(match: "be פארם", mode: "exact", category: "health"),

        // Major Retailers
        RemoteMerchantOverride(match: "zara", mode: "exact", category: "shopping"),
        RemoteMerchantOverride(match: "זארה", mode: "exact", category: "shopping")
    ]
}

public struct RemoteAnnouncement: Codable, Equatable, Sendable {
    public var id: String
    public var enabled: Bool
    public var startsAt: Date?
    public var endsAt: Date?
    public var title: [String: String]
    public var body: [String: String]
    public var action: String?

    public init(
        id: String,
        enabled: Bool = true,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        title: [String: String] = [:],
        body: [String: String] = [:],
        action: String? = nil
    ) {
        self.id = id
        self.enabled = enabled
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.title = title
        self.body = body
        self.action = action
    }

    public var safeAction: RemoteAnnouncementAction {
        guard let action = action?.trimmingCharacters(in: .whitespacesAndNewlines),
              let safe = RemoteAnnouncementAction(rawValue: action) else {
            return .none
        }
        return safe
    }
}

public enum RemoteAnnouncementAction: String, Codable, Sendable {
    case none
    case openCaptureGuide
    case openProfile
}

public struct RemoteCaptureGuideConfig: Codable, Equatable, Sendable {
    public var mode: String?
    public var forceVariant: String?
    public var revision: Int?
    public var steps: [Int]?
    public var fastSetupEnabled: Bool?
    public var shortcutURL: String?

    public init(
        mode: String? = "native",
        forceVariant: String? = nil,
        revision: Int? = 1,
        steps: [Int]? = nil,
        fastSetupEnabled: Bool? = nil,
        shortcutURL: String? = nil
    ) {
        self.mode = mode
        self.forceVariant = forceVariant
        self.revision = revision
        self.steps = steps
        self.fastSetupEnabled = fastSetupEnabled
        self.shortcutURL = shortcutURL
    }
}

public struct RemoteNotificationConfig: Codable, Equatable, Sendable {
    public var weeklyDigest: RemoteNotificationScheduleConfig?
    public var monthlyRecap: RemoteNotificationScheduleConfig?
    public var cityNarrativeEnabled: Bool?
    public var captureHealthCheckEnabled: Bool?

    public init(
        weeklyDigest: RemoteNotificationScheduleConfig? = nil,
        monthlyRecap: RemoteNotificationScheduleConfig? = nil,
        cityNarrativeEnabled: Bool? = true,
        captureHealthCheckEnabled: Bool? = true
    ) {
        self.weeklyDigest = weeklyDigest
        self.monthlyRecap = monthlyRecap
        self.cityNarrativeEnabled = cityNarrativeEnabled
        self.captureHealthCheckEnabled = captureHealthCheckEnabled
    }
}

public struct RemoteNotificationScheduleConfig: Codable, Equatable, Sendable {
    public var enabled: Bool?
    public var weekday: Int?
    public var day: Int?
    public var hour: Int?
    public var minute: Int?
    public var title: [String: String]?
    public var body: [String: String]?

    public init(
        enabled: Bool? = true,
        weekday: Int? = nil,
        day: Int? = nil,
        hour: Int? = nil,
        minute: Int? = nil,
        title: [String: String]? = nil,
        body: [String: String]? = nil
    ) {
        self.enabled = enabled
        self.weekday = weekday
        self.day = day
        self.hour = hour
        self.minute = minute
        self.title = title
        self.body = body
    }
}

public struct RemoteMerchantOverride: Codable, Equatable, Sendable {
    public var match: String
    public var mode: String
    public var category: String

    public init(match: String, mode: String = "exact", category: String) {
        self.match = match
        self.mode = mode
        self.category = category
    }
}

// MARK: - Notification Extension

public extension Notification.Name {
    static let remoteConfigDidUpdate = Notification.Name("moneycity.remoteConfigDidUpdate")
}

// MARK: - Central Service

/// Central service for fetching, validating, caching, and serving SPENT Remote Content (V1).
///
/// Principles:
/// - Refreshed strictly on foreground transition with a ~30-minute throttle.
/// - Never polls in background, uses no background timers or battery-draining fetch.
/// - Safe 3-tier fallback: Network -> Last Known Good (LKG) -> Bundled Defaults.
/// - Remote Config is strictly read-only data and never modifies financial integrity.
public final class RemoteConfigService: ObservableObject, @unchecked Sendable {
    public static let shared = RemoteConfigService()

    public static let supportedSchemaVersion = 1
    public static let maxPayloadBytes = 512 * 1024 // 512 KB
    public static let requestTimeoutSeconds: TimeInterval = 5.0
    public static let defaultThrottleSeconds: TimeInterval = 30 * 60 // 30 minutes

    // Production and Staging raw endpoints on the main branch
    public static let defaultProductionURL = URL(string: "https://raw.githubusercontent.com/biniwis/spentapp/main/remote-config/production.json")!
    public static let defaultStagingURL = URL(string: "https://raw.githubusercontent.com/biniwis/spentapp/main/remote-config/staging.json")!
    #if DEBUG
    /// Endpoint pointing directly to the feature/city-v2 branch staging configuration for pre-merge testing.
    public static let branchStagingURL = URL(string: "https://raw.githubusercontent.com/biniwis/spentapp/feature/city-v2/remote-config/staging.json")!
    #endif
    public static let defaultShortcutURL = "https://www.icloud.com/shortcuts/72aa49c6fe0449fd99703e8d4f2a1853"

    // Keys
    private let keyLastRefreshAttempt = "remote_config_last_refresh_attempt_timestamp"
    private let keyLastKnownGood = "remote_config_last_known_good_json"
    private let keyDismissedAnnouncements = "remote_config_dismissed_announcements"
    #if DEBUG
    private let keyEndpointOverride = "remote_config_endpoint_url"
    #endif

    private let lock = NSLock()
    private var cachedConfig: RemoteConfigRoot
    private let defaults: UserDefaults

    @Published public private(set) var config: RemoteConfigRoot

    public init(defaults: UserDefaults = (UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard)) {
        self.defaults = defaults

        // 1. Initialize from Last Known Good if available, otherwise bundled default
        let initialConfig: RemoteConfigRoot
        if let lkgData = defaults.data(forKey: "remote_config_last_known_good_json"),
           let decoded = try? Self.decodeJSON(from: lkgData),
           decoded.schemaVersion == Self.supportedSchemaVersion {
            initialConfig = decoded
        } else if let bundled = Self.loadBundledConfig() {
            initialConfig = bundled
        } else {
            initialConfig = .bundledDefault
        }

        self.cachedConfig = initialConfig
        self.config = initialConfig
    }

    // MARK: - Thread-safe Access

    public var currentConfig: RemoteConfigRoot {
        lock.lock()
        defer { lock.unlock() }
        return cachedConfig
    }

    // MARK: - Active Endpoint

    public var endpointURL: URL {
        #if DEBUG
        if let overrideString = defaults.string(forKey: keyEndpointOverride),
           let url = URL(string: overrideString), !overrideString.isEmpty {
            return url
        }
        return Self.defaultStagingURL
        #else
        return Self.defaultProductionURL
        #endif
    }

    #if DEBUG
    /// Sets or clears a custom endpoint URL override (strictly DEBUG-only; inactive in Release).
    public func setEndpointOverride(_ urlString: String?) {
        if let str = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
            defaults.set(str, forKey: keyEndpointOverride)
        } else {
            defaults.removeObject(forKey: keyEndpointOverride)
        }
    }

    /// The current custom endpoint override, if configured (strictly DEBUG-only).
    public var endpointOverride: String? {
        defaults.string(forKey: keyEndpointOverride)
    }
    #endif

    // MARK: - Lifecycle Refresh

    /// Called during app foreground maintenance.
    /// Checks the 30-minute throttle before firing a network request.
    public func refreshIfNeeded(
        now: Date = Date(),
        throttleInterval: TimeInterval = defaultThrottleSeconds,
        session: URLSession = .shared
    ) async {
        let lastAttempt = defaults.double(forKey: keyLastRefreshAttempt)
        if lastAttempt > 0 {
            let elapsed = now.timeIntervalSince1970 - lastAttempt
            if elapsed >= 0 && elapsed < throttleInterval {
                // Throttled; skip network request
                return
            }
        }

        // Record attempt timestamp immediately to throttle subsequent rapid foregrounds
        defaults.set(now.timeIntervalSince1970, forKey: keyLastRefreshAttempt)

        do {
            var request = URLRequest(url: endpointURL)
            request.timeoutInterval = Self.requestTimeoutSeconds
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }

            guard data.count <= Self.maxPayloadBytes else {
                print("[RemoteConfig] Payload exceeds 512 KB limit (\(data.count) bytes). Rejected.")
                return
            }

            let parsed = try Self.decodeJSON(from: data)
            guard parsed.schemaVersion == Self.supportedSchemaVersion else {
                print("[RemoteConfig] Unsupported schemaVersion \(parsed.schemaVersion). Expected \(Self.supportedSchemaVersion).")
                return
            }

            // Successfully validated; persist to Last Known Good
            saveLastKnownGood(data: data)
            updateConfig(parsed)
        } catch {
            print("[RemoteConfig] Refresh failed or offline: \(error.localizedDescription). Using Last Known Good / Bundled.")
        }
    }

    // MARK: - Update & Persistence

    public func updateConfig(_ newConfig: RemoteConfigRoot) {
        lock.lock()
        cachedConfig = newConfig
        lock.unlock()

        DispatchQueue.main.async {
            self.config = newConfig
            NotificationCenter.default.post(name: .remoteConfigDidUpdate, object: newConfig)
        }
    }

    private func saveLastKnownGood(data: Data) {
        defaults.set(data, forKey: keyLastKnownGood)
    }

    // MARK: - Feature Flags

    public func isFeatureEnabled(_ key: String, default defaultValue: Bool = true) -> Bool {
        let cfg = currentConfig
        return cfg.features[key] ?? defaultValue
    }

    // MARK: - Copy Overrides

    public func localizedCopy(
        key: String,
        fallbackHe: String,
        fallbackEn: String,
        isHebrew: Bool
    ) -> String {
        let cfg = currentConfig
        if let entry = cfg.copy[key] {
            let langKey = isHebrew ? "he" : "en"
            if let val = entry[langKey]?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
                return val
            }
        }
        return isHebrew ? fallbackHe : fallbackEn
    }

    public func localizedCopy(
        key: String,
        fallbackHe: String,
        fallbackEn: String
    ) -> String {
        let isHe = AppLanguage.current == .hebrew
        return localizedCopy(key: key, fallbackHe: fallbackHe, fallbackEn: fallbackEn, isHebrew: isHe)
    }

    // MARK: - Announcements

    public func activeAnnouncement(now: Date = Date()) -> RemoteAnnouncement? {
        let cfg = currentConfig
        guard let a = cfg.announcement, a.enabled else { return nil }
        if let start = a.startsAt, now < start { return nil }
        if let end = a.endsAt, now > end { return nil }
        if isAnnouncementDismissed(id: a.id) { return nil }
        return a
    }

    public func isAnnouncementDismissed(id: String) -> Bool {
        let dismissed = defaults.stringArray(forKey: keyDismissedAnnouncements) ?? []
        return dismissed.contains(id)
    }

    public func dismissAnnouncement(id: String) {
        var dismissed = defaults.stringArray(forKey: keyDismissedAnnouncements) ?? []
        if !dismissed.contains(id) {
            dismissed.append(id)
            defaults.set(dismissed, forKey: keyDismissedAnnouncements)
        }
    }

    // MARK: - Merchant Overrides

    /// Evaluates remote merchant overrides for a given merchant string:
    /// - 1. Exact match beats contains.
    /// - 2. Contains requires match.count >= 3; longest contains match wins.
    /// - 3. Category must exist in SpendingCategory.rawValue (invalid rawValue is ignored).
    public func merchantOverride(for merchant: String) -> SpendingCategory? {
        let rawKey = MerchantRuleService.normalizedKey(merchant)
        guard !rawKey.isEmpty else { return nil }

        let overrides = currentConfig.merchantOverrides
        guard !overrides.isEmpty else { return nil }

        // Filter to only overrides with valid SpendingCategory
        let validOverrides: [(rule: RemoteMerchantOverride, category: SpendingCategory)] = overrides.compactMap { rule in
            guard let cat = SpendingCategory(rawValue: rule.category) else { return nil }
            return (rule, cat)
        }

        // 1. Exact match
        for item in validOverrides where item.rule.mode.lowercased() == "exact" {
            let matchKey = MerchantRuleService.normalizedKey(item.rule.match)
            if matchKey == rawKey {
                return item.category
            }
        }

        // 2. Contains match (minimum 3 characters, longest match wins)
        let matchingContains = validOverrides.filter { item in
            guard item.rule.mode.lowercased() == "contains" else { return false }
            let matchKey = MerchantRuleService.normalizedKey(item.rule.match)
            guard matchKey.count >= 3 else { return false }
            return rawKey.contains(matchKey)
        }

        if let best = matchingContains.max(by: {
            MerchantRuleService.normalizedKey($0.rule.match).count < MerchantRuleService.normalizedKey($1.rule.match).count
        }) {
            return best.category
        }

        return nil
    }

    // MARK: - Notification Controls

    public var isCityNarrativeEnabled: Bool {
        currentConfig.notifications.cityNarrativeEnabled ?? true
    }

    public var isCaptureHealthCheckEnabled: Bool {
        currentConfig.notifications.captureHealthCheckEnabled ?? true
    }

    public var weeklyDigestConfig: RemoteNotificationScheduleConfig? {
        currentConfig.notifications.weeklyDigest
    }

    public var monthlyRecapConfig: RemoteNotificationScheduleConfig? {
        currentConfig.notifications.monthlyRecap
    }

    // MARK: - Capture Guide Controls

    public var captureGuideForceVariant: String? {
        currentConfig.captureGuide.forceVariant
    }

    public var captureGuideSteps: [Int]? {
        currentConfig.captureGuide.steps
    }

    public var isFastSetupEnabled: Bool {
        currentConfig.captureGuide.fastSetupEnabled ?? true
    }

    public var resolvedShortcutURL: URL {
        let fallback = URL(string: Self.defaultShortcutURL)!
        guard let urlString = currentConfig.captureGuide.shortcutURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            return fallback
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            return fallback
        }
        guard let host = url.host?.lowercased(),
              host == "icloud.com" || host == "www.icloud.com" else {
            return fallback
        }
        guard url.path.hasPrefix("/shortcuts/") else {
            return fallback
        }
        return url
    }

    // MARK: - Static Decoding & Bundled Fallback

    public static func decodeJSON(from data: Data) throws -> RemoteConfigRoot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateStr) {
                return date
            }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateStr) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date string: \(dateStr)")
        }
        return try decoder.decode(RemoteConfigRoot.self, from: data)
    }

    public static func loadBundledConfig() -> RemoteConfigRoot? {
        // Try to load from bundle if present
        if let url = Bundle.main.url(forResource: "remote_config_default", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? decodeJSON(from: data) {
            return decoded
        }
        return nil
    }
}
