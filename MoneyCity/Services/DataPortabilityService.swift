import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Reads and writes the whole database as one JSON file.
///
/// Until this existed there was no way to get anything out of the app. If the store ever
/// became unreadable, what survived was a SQLite blob that needed a Mac and the right tools
/// to open — which is not the same as having your data. A plain, readable file the user can
/// keep in Files or iCloud Drive is the difference between "the app broke" and "I lost a
/// year of spending".
///
/// Deliberately a file and not a service: the app asks for no bank credentials and talks to
/// nothing, and a backup that required an account would give that up for convenience.
public enum DataPortabilityService {

    /// Bumped only when the shape changes in a way an older reader could not handle. The
    /// reader checks it so a future file fails loudly here rather than importing half of
    /// itself and leaving the user to discover which half.
    public static let formatVersion = 3
    public static let formatIdentifier = "moneycity.backup"

    // MARK: - The file

    public struct RecapSnapshotDTO: Codable, Equatable {
        public var monthId: String
        public var payloadJSON: String
        public var frozenAt: Date

        public init(monthId: String, payloadJSON: String, frozenAt: Date) {
            self.monthId = monthId
            self.payloadJSON = payloadJSON
            self.frozenAt = frozenAt
        }
    }

    public struct AppPreferencesDTO: Codable, Equatable {
        public var userName: String?
        public var monthlyBudget: Double?
        public var hasCompletedOnboarding: Bool?
        public var hasStartedOnboardingV2: Bool?
        public var trackingActiveDays: [String]?
        public var mapStyle: String?
        public var monthlyMapSelections: [String: CityMapSelection.MonthEntry]?
        public var cityRewardStateData: Data?
        public var cityCompanionsStartedAt: Double?
        public var firstAppLaunchDate: Date?
        public var lastAcknowledgedMonth: String?
        public var onboardingMapStyle: String?
        public var appLanguage: String?
        public var appCurrency: String?
        public var autoConvertFX: Bool?
        public var hapticsEnabled: Bool?
        public var statsExcludeHousing: Bool?
        public var notificationsEnabled: Bool?
        public var captureNotificationsEnabled: Bool?
        public var autoCaptureSetupCompletedAt: Double?
        public var autoCaptureLastDetectedAt: Double?
        public var didMigrateLegacyMonthlyTargetIncome: Bool?

        public init(
            userName: String? = nil,
            monthlyBudget: Double? = nil,
            hasCompletedOnboarding: Bool? = nil,
            hasStartedOnboardingV2: Bool? = nil,
            trackingActiveDays: [String]? = nil,
            mapStyle: String? = nil,
            monthlyMapSelections: [String: CityMapSelection.MonthEntry]? = nil,
            cityRewardStateData: Data? = nil,
            cityCompanionsStartedAt: Double? = nil,
            firstAppLaunchDate: Date? = nil,
            lastAcknowledgedMonth: String? = nil,
            onboardingMapStyle: String? = nil,
            appLanguage: String? = nil,
            appCurrency: String? = nil,
            autoConvertFX: Bool? = nil,
            hapticsEnabled: Bool? = nil,
            statsExcludeHousing: Bool? = nil,
            notificationsEnabled: Bool? = nil,
            captureNotificationsEnabled: Bool? = nil,
            autoCaptureSetupCompletedAt: Double? = nil,
            autoCaptureLastDetectedAt: Double? = nil,
            didMigrateLegacyMonthlyTargetIncome: Bool? = nil
        ) {
            self.userName = userName
            self.monthlyBudget = monthlyBudget
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.hasStartedOnboardingV2 = hasStartedOnboardingV2
            self.trackingActiveDays = trackingActiveDays
            self.mapStyle = mapStyle
            self.monthlyMapSelections = monthlyMapSelections
            self.cityRewardStateData = cityRewardStateData
            self.cityCompanionsStartedAt = cityCompanionsStartedAt
            self.firstAppLaunchDate = firstAppLaunchDate
            self.lastAcknowledgedMonth = lastAcknowledgedMonth
            self.onboardingMapStyle = onboardingMapStyle
            self.appLanguage = appLanguage
            self.appCurrency = appCurrency
            self.autoConvertFX = autoConvertFX
            self.hapticsEnabled = hapticsEnabled
            self.statsExcludeHousing = statsExcludeHousing
            self.notificationsEnabled = notificationsEnabled
            self.captureNotificationsEnabled = captureNotificationsEnabled
            self.autoCaptureSetupCompletedAt = autoCaptureSetupCompletedAt
            self.autoCaptureLastDetectedAt = autoCaptureLastDetectedAt
            self.didMigrateLegacyMonthlyTargetIncome = didMigrateLegacyMonthlyTargetIncome
        }
    }

    // MARK: - Versioned Backup Schemas

    public struct BackupHeader: Decodable {
        public let format: String
        public let formatVersion: Int
        public let appVersion: String?
        public let appBuild: String?
        public let exportedAt: Date?
    }

    /// Historical V1 Backup Envelope (pre-cloud version in the wild).
    public struct EnvelopeV1: Decodable {
        public var format: String
        public var formatVersion: Int
        public var appVersion: String
        public var appBuild: String
        public var exportedAt: Date

        public var transactions: [TransactionDTO]
        public var recurring: [RecurringDTO]
        public var income: [IncomeDTO]
        public var budgets: [BudgetDTO]
        public var merchantRules: [MerchantRuleDTO]
        public var installments: [InstallmentDTO]
        public var savingsGoals: [SavingsGoalDTO]
        public var enrichments: [EnrichmentDTO]

        /// Deterministic migration from V1 to V2:
        /// Missing collections (recaps, preferences) default safely without fabricating non-existent history.
        public func migrateToV2() -> EnvelopeV2 {
            EnvelopeV2(
                format: format,
                formatVersion: 2,
                appVersion: appVersion,
                appBuild: appBuild,
                exportedAt: exportedAt,
                transactions: transactions,
                recurring: recurring,
                income: income,
                budgets: budgets,
                merchantRules: merchantRules,
                installments: installments,
                savingsGoals: savingsGoals,
                enrichments: enrichments,
                recaps: [],
                preferences: nil
            )
        }
    }

    /// Canonical V2 Backup Envelope (current format with recaps and durable preferences).
    public struct EnvelopeV2: Codable {
        public var format: String
        public var formatVersion: Int
        public var appVersion: String
        public var appBuild: String
        public var exportedAt: Date

        public var transactions: [TransactionDTO]
        public var recurring: [RecurringDTO]
        public var income: [IncomeDTO]
        public var budgets: [BudgetDTO]
        public var merchantRules: [MerchantRuleDTO]
        public var installments: [InstallmentDTO]
        public var savingsGoals: [SavingsGoalDTO]
        public var enrichments: [EnrichmentDTO]
        public var recaps: [RecapSnapshotDTO]
        public var preferences: AppPreferencesDTO?

        public var totalRecords: Int {
            transactions.count + recurring.count + income.count + budgets.count
                + merchantRules.count + installments.count + savingsGoals.count + enrichments.count
                + recaps.count
        }

        public init(
            format: String = DataPortabilityService.formatIdentifier,
            formatVersion: Int = DataPortabilityService.formatVersion,
            appVersion: String,
            appBuild: String,
            exportedAt: Date,
            transactions: [TransactionDTO],
            recurring: [RecurringDTO],
            income: [IncomeDTO],
            budgets: [BudgetDTO],
            merchantRules: [MerchantRuleDTO],
            installments: [InstallmentDTO],
            savingsGoals: [SavingsGoalDTO],
            enrichments: [EnrichmentDTO],
            recaps: [RecapSnapshotDTO] = [],
            preferences: AppPreferencesDTO? = nil
        ) {
            self.format = format
            self.formatVersion = formatVersion
            self.appVersion = appVersion
            self.appBuild = appBuild
            self.exportedAt = exportedAt
            self.transactions = transactions
            self.recurring = recurring
            self.income = income
            self.budgets = budgets
            self.merchantRules = merchantRules
            self.installments = installments
            self.savingsGoals = savingsGoals
            self.enrichments = enrichments
            self.recaps = recaps
            self.preferences = preferences
        }

        /// Deterministic migration from V2 to V3:
        /// Missing scheduled collection defaults to empty.
        public func migrateToV3() -> EnvelopeV3 {
            EnvelopeV3(
                format: format,
                formatVersion: 3,
                appVersion: appVersion,
                appBuild: appBuild,
                exportedAt: exportedAt,
                transactions: transactions,
                recurring: recurring,
                income: income,
                budgets: budgets,
                merchantRules: merchantRules,
                installments: installments,
                savingsGoals: savingsGoals,
                enrichments: enrichments,
                recaps: recaps,
                scheduled: [],
                preferences: preferences
            )
        }
    }

    /// Canonical V3 Backup Envelope (current format with scheduled expenses).
    public struct EnvelopeV3: Codable {
        public var format: String
        public var formatVersion: Int
        public var appVersion: String
        public var appBuild: String
        public var exportedAt: Date

        public var transactions: [TransactionDTO]
        public var recurring: [RecurringDTO]
        public var income: [IncomeDTO]
        public var budgets: [BudgetDTO]
        public var merchantRules: [MerchantRuleDTO]
        public var installments: [InstallmentDTO]
        public var savingsGoals: [SavingsGoalDTO]
        public var enrichments: [EnrichmentDTO]
        public var recaps: [RecapSnapshotDTO]
        public var scheduled: [ScheduledDTO]
        public var preferences: AppPreferencesDTO?

        public var totalRecords: Int {
            transactions.count + recurring.count + income.count + budgets.count
                + merchantRules.count + installments.count + savingsGoals.count + enrichments.count
                + recaps.count + scheduled.count
        }

        public init(
            format: String = DataPortabilityService.formatIdentifier,
            formatVersion: Int = DataPortabilityService.formatVersion,
            appVersion: String,
            appBuild: String,
            exportedAt: Date,
            transactions: [TransactionDTO],
            recurring: [RecurringDTO],
            income: [IncomeDTO],
            budgets: [BudgetDTO],
            merchantRules: [MerchantRuleDTO],
            installments: [InstallmentDTO],
            savingsGoals: [SavingsGoalDTO],
            enrichments: [EnrichmentDTO],
            recaps: [RecapSnapshotDTO] = [],
            scheduled: [ScheduledDTO] = [],
            preferences: AppPreferencesDTO? = nil
        ) {
            self.format = format
            self.formatVersion = formatVersion
            self.appVersion = appVersion
            self.appBuild = appBuild
            self.exportedAt = exportedAt
            self.transactions = transactions
            self.recurring = recurring
            self.income = income
            self.budgets = budgets
            self.merchantRules = merchantRules
            self.installments = installments
            self.savingsGoals = savingsGoals
            self.enrichments = enrichments
            self.recaps = recaps
            self.scheduled = scheduled
            self.preferences = preferences
        }

        private enum CodingKeys: String, CodingKey {
            case format, formatVersion, appVersion, appBuild, exportedAt
            case transactions, recurring, income, budgets, merchantRules
            case installments, savingsGoals, enrichments, recaps, scheduled, preferences
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            format = try container.decode(String.self, forKey: .format)
            formatVersion = try container.decode(Int.self, forKey: .formatVersion)
            appVersion = try container.decode(String.self, forKey: .appVersion)
            appBuild = try container.decode(String.self, forKey: .appBuild)
            exportedAt = try container.decode(Date.self, forKey: .exportedAt)
            transactions = try container.decode([TransactionDTO].self, forKey: .transactions)
            recurring = try container.decode([RecurringDTO].self, forKey: .recurring)
            income = try container.decode([IncomeDTO].self, forKey: .income)
            budgets = try container.decode([BudgetDTO].self, forKey: .budgets)
            merchantRules = try container.decode([MerchantRuleDTO].self, forKey: .merchantRules)
            installments = try container.decode([InstallmentDTO].self, forKey: .installments)
            savingsGoals = try container.decode([SavingsGoalDTO].self, forKey: .savingsGoals)
            enrichments = try container.decode([EnrichmentDTO].self, forKey: .enrichments)
            recaps = try container.decodeIfPresent([RecapSnapshotDTO].self, forKey: .recaps) ?? []
            scheduled = try container.decodeIfPresent([ScheduledDTO].self, forKey: .scheduled) ?? []
            preferences = try container.decodeIfPresent(AppPreferencesDTO.self, forKey: .preferences)
        }
    }

    public typealias Envelope = EnvelopeV3

    /// Version-aware decoder that dispatches to historical schema models and migrates forward deterministically.
    public enum BackupMigrator {
        public static func decodeAndMigrate(_ data: Data) throws -> Envelope {
            guard data.count <= DataPortabilityService.maxBackupFileSize else {
                throw DataPortabilityService.ImportError.fileTooLarge
            }

            let header: BackupHeader
            do {
                header = try DataPortabilityService.makeDecoder().decode(BackupHeader.self, from: data)
            } catch {
                throw DataPortabilityService.ImportError.notABackup
            }

            guard header.format == DataPortabilityService.formatIdentifier else {
                throw DataPortabilityService.ImportError.notABackup
            }

            guard header.formatVersion <= DataPortabilityService.formatVersion else {
                throw DataPortabilityService.ImportError.futureFormat(header.formatVersion)
            }

            guard header.formatVersion >= 1 else {
                throw DataPortabilityService.ImportError.notABackup
            }

            let envelope: Envelope
            switch header.formatVersion {
            case 1:
                let v1 = try DataPortabilityService.makeDecoder().decode(EnvelopeV1.self, from: data)
                envelope = v1.migrateToV2().migrateToV3()
            case 2:
                let v2 = try DataPortabilityService.makeDecoder().decode(EnvelopeV2.self, from: data)
                envelope = v2.migrateToV3()
            case 3:
                envelope = try DataPortabilityService.makeDecoder().decode(EnvelopeV3.self, from: data)
            default:
                throw DataPortabilityService.ImportError.futureFormat(header.formatVersion)
            }

            guard envelope.totalRecords <= DataPortabilityService.maxRecordCount else {
                throw DataPortabilityService.ImportError.tooManyRecords
            }

            return envelope
        }
    }

    public struct TransactionDTO: Codable {
        public var id: UUID
        public var amount: Double
        public var currency: String
        public var merchant: String
        public var category: String
        public var timestamp: Date
        public var confidenceScore: Double
        public var isManual: Bool
        public var isConfirmed: Bool
        public var note: String?
        public var buildingId: String?
        public var originalAmount: Double?
        public var originalCurrency: String?
        public var exchangeRate: Double?
        public var savingsGoalId: UUID?
        public var installmentPlanId: UUID?
        public var installmentIndex: Int?

        public init(
            id: UUID,
            amount: Double,
            currency: String,
            merchant: String,
            category: String,
            timestamp: Date,
            confidenceScore: Double,
            isManual: Bool,
            isConfirmed: Bool,
            note: String? = nil,
            buildingId: String? = nil,
            originalAmount: Double? = nil,
            originalCurrency: String? = nil,
            exchangeRate: Double? = nil,
            savingsGoalId: UUID? = nil,
            installmentPlanId: UUID? = nil,
            installmentIndex: Int? = nil
        ) {
            self.id = id
            self.amount = amount
            self.currency = currency
            self.merchant = merchant
            self.category = category
            self.timestamp = timestamp
            self.confidenceScore = confidenceScore
            self.isManual = isManual
            self.isConfirmed = isConfirmed
            self.note = note
            self.buildingId = buildingId
            self.originalAmount = originalAmount
            self.originalCurrency = originalCurrency
            self.exchangeRate = exchangeRate
            self.savingsGoalId = savingsGoalId
            self.installmentPlanId = installmentPlanId
            self.installmentIndex = installmentIndex
        }
    }

    public struct RecurringDTO: Codable {
        public var id: UUID
        public var merchant: String
        public var amount: Double
        public var currency: String
        public var category: String
        public var dayOfMonth: Int
        public var isActive: Bool
        public var lastGeneratedPeriod: String?
        public var createdAt: Date
    }

    public struct IncomeDTO: Codable {
        public var id: UUID
        public var name: String
        public var amount: Double
        public var currency: String
        public var dayOfMonth: Int
        public var isActive: Bool
        public var createdAt: Date
    }

    public struct BudgetDTO: Codable {
        public var id: UUID
        public var category: String
        public var monthlyLimit: Double
        public var createdAt: Date
    }

    public struct MerchantRuleDTO: Codable {
        public var id: UUID
        public var merchantKey: String
        public var displayName: String
        public var category: String
        public var buildingId: String?
        public var hitCount: Int
        public var createdAt: Date
    }

    public struct InstallmentDTO: Codable {
        public var id: UUID
        public var merchant: String
        public var totalAmount: Double
        public var currency: String
        public var numberOfPayments: Int
        public var firstChargeDate: Date
        public var category: String
        public var createdAt: Date
        public var lastMaterializedIndex: Int?
        public var buildingId: String?

        public init(
            id: UUID,
            merchant: String,
            totalAmount: Double,
            currency: String,
            numberOfPayments: Int,
            firstChargeDate: Date,
            category: String,
            createdAt: Date,
            lastMaterializedIndex: Int? = nil,
            buildingId: String? = nil
        ) {
            self.id = id
            self.merchant = merchant
            self.totalAmount = totalAmount
            self.currency = currency
            self.numberOfPayments = numberOfPayments
            self.firstChargeDate = firstChargeDate
            self.category = category
            self.createdAt = createdAt
            self.lastMaterializedIndex = lastMaterializedIndex
            self.buildingId = buildingId
        }
    }

    public struct SavingsGoalDTO: Codable {
        public var id: UUID
        public var name: String
        public var icon: String
        public var targetAmount: Double
        public var savedAmount: Double
        public var currency: String
        public var targetDate: Date?
        public var createdAt: Date
        public var completedAt: Date?
        public var unlinkedBaseline: Double
        public var baselineCaptured: Bool
    }

    public struct EnrichmentDTO: Codable {
        public var id: UUID
        public var itemId: String
        public var name: String
        public var subtitle: String
        public var icon: String
        public var type: String
        public var tier: String
        public var unlockedDate: Date
        public var savedAmount: Double
        public var districtId: String
        public var isApplied: Bool
        public var placedSlotId: String?
    }

    public struct ScheduledDTO: Codable, Equatable {
        public var id: UUID
        public var merchant: String
        public var amount: Double
        public var currency: String
        public var category: String
        public var scheduledFor: Date
        public var createdAt: Date
        public var buildingId: String?
        public var originalAmount: Double?
        public var originalCurrency: String?
        public var exchangeRate: Double?
        public var materializedAt: Date?
        public var materializedTransactionId: UUID?

        public init(
            id: UUID,
            merchant: String,
            amount: Double,
            currency: String,
            category: String,
            scheduledFor: Date,
            createdAt: Date,
            buildingId: String?,
            originalAmount: Double?,
            originalCurrency: String?,
            exchangeRate: Double?,
            materializedAt: Date?,
            materializedTransactionId: UUID?
        ) {
            self.id = id
            self.merchant = merchant
            self.amount = amount
            self.currency = currency
            self.category = category
            self.scheduledFor = scheduledFor
            self.createdAt = createdAt
            self.buildingId = buildingId
            self.originalAmount = originalAmount
            self.originalCurrency = originalCurrency
            self.exchangeRate = exchangeRate
            self.materializedAt = materializedAt
            self.materializedTransactionId = materializedTransactionId
        }
    }

    // MARK: - Coders

    /// ISO-8601 throughout: a backup is meant to still be readable in five years, by a
    /// reader that is not this build, and possibly by a person.
    public static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    public static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Preferences Mapping

    public static func buildPreferencesDTO(
        defaults: UserDefaults = .standard,
        groupDefaults: UserDefaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard
    ) -> AppPreferencesDTO {
        let activeDays = TrackingActivityService(defaults: defaults).activeDays()
        let customMapStyle = CityMapSelection.hasCustomStyle(defaults: defaults) ? CityMapSelection.currentStyle(defaults: defaults).rawValue : nil
        let rewardData = defaults.data(forKey: CityRewardEngine.storageKey)
        let companionsStarted = defaults.object(forKey: "cityCompanionsStartedAt") as? Double
        let firstLaunch = defaults.object(forKey: "firstAppLaunchDate") as? Date
        let lastAckMonth = defaults.string(forKey: "last_acknowledged_month")
        let userName = defaults.string(forKey: "userName") ?? defaults.string(forKey: "user_name")
        let monthlyBudget = defaults.object(forKey: "monthly_budget") as? Double
        let hasCompletedOnboarding = defaults.object(forKey: "hasCompletedOnboarding") as? Bool
        let hasStartedOnboardingV2 = defaults.object(forKey: "hasStartedOnboardingV2") as? Bool
        let appLang = defaults.string(forKey: "app_language_pref")
        let appCur = defaults.string(forKey: "app_currency_pref")
        let autoFX = defaults.object(forKey: "auto_convert_fx") as? Bool
        let haptics = defaults.object(forKey: "haptics_enabled") as? Bool
        let statsHousing = defaults.object(forKey: "stats_exclude_housing") as? Bool
        let notifs = groupDefaults.object(forKey: "notifications_enabled") as? Bool
        let captureNotifs = groupDefaults.object(forKey: "expense_capture_notifications_enabled") as? Bool
        let captureSetupAt = defaults.object(forKey: AutomaticCaptureStateStore.Key.setupCompletedAt) as? Double
        let captureLastDetectedAt = defaults.object(forKey: AutomaticCaptureStateStore.Key.lastDetectedAt) as? Double
        let migratedLegacyIncome = defaults.object(forKey: "didMigrateLegacyMonthlyTargetIncome") as? Bool

        return AppPreferencesDTO(
            userName: userName,
            monthlyBudget: monthlyBudget,
            hasCompletedOnboarding: hasCompletedOnboarding,
            hasStartedOnboardingV2: hasStartedOnboardingV2,
            trackingActiveDays: activeDays.isEmpty ? nil : activeDays,
            mapStyle: customMapStyle,
            monthlyMapSelections: nil,
            cityRewardStateData: rewardData,
            cityCompanionsStartedAt: companionsStarted,
            firstAppLaunchDate: firstLaunch,
            lastAcknowledgedMonth: lastAckMonth,
            onboardingMapStyle: nil,
            appLanguage: appLang,
            appCurrency: appCur,
            autoConvertFX: autoFX,
            hapticsEnabled: haptics,
            statsExcludeHousing: statsHousing,
            notificationsEnabled: notifs,
            captureNotificationsEnabled: captureNotifs,
            autoCaptureSetupCompletedAt: captureSetupAt,
            autoCaptureLastDetectedAt: captureLastDetectedAt,
            didMigrateLegacyMonthlyTargetIncome: migratedLegacyIncome
        )
    }

    public static func restorePreferences(
        _ prefs: AppPreferencesDTO,
        defaults: UserDefaults = .standard,
        groupDefaults: UserDefaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard
    ) {
        if let name = prefs.userName {
            let clean = InputSanitizer.sanitizeSingleLine(name, maxLength: InputSanitizer.maxMerchantLength)
            defaults.set(clean, forKey: "userName")
            defaults.set(clean, forKey: "user_name")
        }
        if let budget = prefs.monthlyBudget, budget.isFinite, budget >= 0 {
            defaults.set(budget, forKey: "monthly_budget")
        }
        if let completed = prefs.hasCompletedOnboarding {
            defaults.set(completed, forKey: "hasCompletedOnboarding")
        }
        if let startedV2 = prefs.hasStartedOnboardingV2 {
            defaults.set(startedV2, forKey: "hasStartedOnboardingV2")
        }
        if let days = prefs.trackingActiveDays {
            TrackingActivityService(defaults: defaults).setActiveDays(days)
        }
        if let styleStr = prefs.mapStyle, let style = CityMapStyle(rawValue: styleStr) {
            CityMapSelection.save(style, defaults: defaults)
        } else if let maps = prefs.monthlyMapSelections, !maps.isEmpty {
            let sortedKeys = maps.keys.sorted(by: >)
            for key in sortedKeys {
                if let entry = maps[key], let style = CityMapStyle(rawValue: entry.style) {
                    CityMapSelection.save(style, defaults: defaults)
                    break
                }
            }
        } else if let mapStyle = prefs.onboardingMapStyle, let style = CityMapStyle(rawValue: mapStyle) {
            CityMapSelection.save(style, defaults: defaults)
        }
        if let rewardData = prefs.cityRewardStateData {
            defaults.set(rewardData, forKey: CityRewardEngine.storageKey)
        }
        if let comp = prefs.cityCompanionsStartedAt, comp > 0 {
            defaults.set(comp, forKey: "cityCompanionsStartedAt")
        }
        if let first = prefs.firstAppLaunchDate {
            defaults.set(first, forKey: "firstAppLaunchDate")
        }
        if let ack = prefs.lastAcknowledgedMonth {
            defaults.set(ack, forKey: "last_acknowledged_month")
        }
        if let lang = prefs.appLanguage {
            defaults.set(lang, forKey: "app_language_pref")
        }
        if let cur = prefs.appCurrency {
            defaults.set(cur, forKey: "app_currency_pref")
        }
        if let fx = prefs.autoConvertFX {
            defaults.set(fx, forKey: "auto_convert_fx")
        }
        if let haptics = prefs.hapticsEnabled {
            defaults.set(haptics, forKey: "haptics_enabled")
        }
        if let housing = prefs.statsExcludeHousing {
            defaults.set(housing, forKey: "stats_exclude_housing")
        }
        if let notifs = prefs.notificationsEnabled {
            groupDefaults.set(notifs, forKey: "notifications_enabled")
        }
        if let capNotifs = prefs.captureNotificationsEnabled {
            groupDefaults.set(capNotifs, forKey: "expense_capture_notifications_enabled")
        }
        if let setupAt = prefs.autoCaptureSetupCompletedAt, setupAt > 0 {
            defaults.set(setupAt, forKey: AutomaticCaptureStateStore.Key.setupCompletedAt)
        }
        if let detectedAt = prefs.autoCaptureLastDetectedAt, detectedAt > 0 {
            defaults.set(detectedAt, forKey: AutomaticCaptureStateStore.Key.lastDetectedAt)
        }
        if let migrated = prefs.didMigrateLegacyMonthlyTargetIncome {
            defaults.set(migrated, forKey: "didMigrateLegacyMonthlyTargetIncome")
        }
    }

    // MARK: - Export

    @MainActor
    public static func buildEnvelope(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        groupDefaults: UserDefaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard,
        includePreferences: Bool = true,
        now: Date = Date()
    ) throws -> Envelope {
        func all<T: PersistentModel>(_ type: T.Type) throws -> [T] {
            try context.fetch(FetchDescriptor<T>())
        }

        return Envelope(
            format: formatIdentifier,
            formatVersion: formatVersion,
            appVersion: StoreSnapshotService.currentVersion(),
            appBuild: StoreSnapshotService.currentBuild(),
            exportedAt: now,
            transactions: try all(Transaction.self).map {
                TransactionDTO(
                    id: $0.id, amount: $0.amount, currency: $0.currency, merchant: $0.merchant,
                    category: $0.categoryRawValue, timestamp: $0.timestamp,
                    confidenceScore: $0.confidenceScore, isManual: $0.isManual,
                    isConfirmed: $0.isConfirmed, note: $0.note, buildingId: $0.buildingIdRaw,
                    originalAmount: $0.originalAmount, originalCurrency: $0.originalCurrency,
                    exchangeRate: $0.exchangeRate, savingsGoalId: $0.savingsGoalId,
                    installmentPlanId: $0.installmentPlanId,
                    installmentIndex: $0.installmentIndex
                )
            },
            recurring: try all(RecurringExpense.self).map {
                RecurringDTO(
                    id: $0.id, merchant: $0.merchant, amount: $0.amount, currency: $0.currency,
                    category: $0.categoryRawValue, dayOfMonth: $0.dayOfMonth,
                    isActive: $0.isActive, lastGeneratedPeriod: $0.lastGeneratedPeriod,
                    createdAt: $0.createdAt
                )
            },
            income: try all(IncomeSource.self).map {
                IncomeDTO(
                    id: $0.id, name: $0.name, amount: $0.amount, currency: $0.currency,
                    dayOfMonth: $0.dayOfMonth, isActive: $0.isActive, createdAt: $0.createdAt
                )
            },
            budgets: try all(CategoryBudget.self).map {
                BudgetDTO(
                    id: $0.id, category: $0.categoryRawValue,
                    monthlyLimit: $0.monthlyLimit, createdAt: $0.createdAt
                )
            },
            merchantRules: try all(MerchantRule.self).map {
                MerchantRuleDTO(
                    id: $0.id, merchantKey: $0.merchantKey, displayName: $0.displayName,
                    category: $0.categoryRawValue, buildingId: $0.buildingIdRaw,
                    hitCount: $0.hitCount, createdAt: $0.createdAt
                )
            },
            installments: try all(InstallmentPlan.self).map {
                InstallmentDTO(
                    id: $0.id, merchant: $0.merchant, totalAmount: $0.totalAmount,
                    currency: $0.currency, numberOfPayments: $0.numberOfPayments,
                    firstChargeDate: $0.firstChargeDate, category: $0.categoryRawValue,
                    createdAt: $0.createdAt,
                    lastMaterializedIndex: $0.lastMaterializedIndex,
                    buildingId: $0.buildingIdRaw
                )
            },
            savingsGoals: try all(SavingsGoal.self).map {
                SavingsGoalDTO(
                    id: $0.id, name: $0.name, icon: $0.icon, targetAmount: $0.targetAmount,
                    savedAmount: $0.savedAmount, currency: $0.currency, targetDate: $0.targetDate,
                    createdAt: $0.createdAt, completedAt: $0.completedAt,
                    unlinkedBaseline: $0.unlinkedBaseline, baselineCaptured: $0.baselineCaptured
                )
            },
            enrichments: try all(CityEnrichment.self).map {
                EnrichmentDTO(
                    id: $0.id, itemId: $0.itemId, name: $0.name, subtitle: $0.subtitle,
                    icon: $0.icon, type: $0.typeRawValue, tier: $0.tierRawValue,
                    unlockedDate: $0.unlockedDate, savedAmount: $0.savedAmount,
                    districtId: $0.districtId, isApplied: $0.isApplied,
                    placedSlotId: $0.placedSlotId
                )
            },
            recaps: try all(RecapSnapshot.self).map {
                RecapSnapshotDTO(
                    monthId: $0.monthId,
                    payloadJSON: $0.payloadJSON,
                    frozenAt: $0.frozenAt
                )
            },
            scheduled: try all(ScheduledExpense.self).map {
                ScheduledDTO(
                    id: $0.id,
                    merchant: $0.merchant,
                    amount: $0.amount,
                    currency: $0.currency,
                    category: $0.categoryRawValue,
                    scheduledFor: $0.scheduledFor,
                    createdAt: $0.createdAt,
                    buildingId: $0.buildingIdRaw,
                    originalAmount: $0.originalAmount,
                    originalCurrency: $0.originalCurrency,
                    exchangeRate: $0.exchangeRate,
                    materializedAt: $0.materializedAt,
                    materializedTransactionId: $0.materializedTransactionId
                )
            },
            preferences: includePreferences ? buildPreferencesDTO(defaults: defaults, groupDefaults: groupDefaults) : nil
        )
    }

    @MainActor
    public static func exportData(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        groupDefaults: UserDefaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard,
        includePreferences: Bool = true,
        now: Date = Date()
    ) throws -> Data {
        try makeEncoder().encode(try buildEnvelope(
            context: context,
            defaults: defaults,
            groupDefaults: groupDefaults,
            includePreferences: includePreferences,
            now: now
        ))
    }

    /// `MoneyCity-2026-09-01-1432.json` — sorts chronologically in Files, and says what it is
    /// without being opened.
    public static func suggestedFileName(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return "MoneyCity-\(f.string(from: now)).json"
    }

    // MARK: - Import

    public enum ImportMode: String, Hashable, CaseIterable {
        /// Anything already present stays; only records the store has never seen are added.
        case merge
        /// Everything the file covers is cleared first. The file becomes the truth.
        case replace
    }

    public static let maxBackupFileSize = 15 * 1024 * 1024 // 15 MB
    public static let maxRecordCount = 50_000

    public enum ImportError: LocalizedError {
        case notABackup
        case futureFormat(Int)
        case fileTooLarge
        case tooManyRecords

        public var errorDescription: String? {
            switch self {
            case .notABackup:
                return AppLanguage.localized("הקובץ הזה אינו גיבוי של MoneyCity.", "This file is not a MoneyCity backup.")
            case .futureFormat(let v):
                return AppLanguage.localized("הגיבוי נוצר בגרסה חדשה יותר של האפליקציה (פורמט \(v)).", "This backup was created by a newer version of the app (format \(v)).")
            case .fileTooLarge:
                return AppLanguage.localized("קובץ הגיבוי גדול מדי (מקסימום 15MB).", "Backup file exceeds maximum allowed size (15MB).")
            case .tooManyRecords:
                return AppLanguage.localized("קובץ הגיבוי מכיל יותר מדי רשומות.", "Backup file contains too many records.")
            }
        }
    }

    public struct ImportSummary: Equatable {
        public var added = 0
        public var skipped = 0
        public var exportedAt: Date? = nil
    }

    public static func isPlausibleDate(_ date: Date, reference: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let refYear = calendar.component(.year, from: reference)
        return year >= 2000 && year <= refYear + 10
    }

    public static func validateBackupData(_ data: Data) throws -> Envelope {
        try BackupMigrator.decodeAndMigrate(data)
    }

    @MainActor
    public static func importData(
        _ data: Data,
        into context: ModelContext,
        defaults: UserDefaults = .standard,
        groupDefaults: UserDefaults = UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard,
        mode: ImportMode = .merge,
        restorePreferences: Bool = true
    ) throws -> ImportSummary {
        let envelope = try validateBackupData(data)

        var summary = ImportSummary()
        summary.exportedAt = envelope.exportedAt

        func existingIds<T: PersistentModel>(_ type: T.Type, _ id: (T) -> UUID) throws -> Set<UUID> {
            Set((try context.fetch(FetchDescriptor<T>())).map(id))
        }
        func wipe<T: PersistentModel>(_ type: T.Type) throws {
            for object in try context.fetch(FetchDescriptor<T>()) {
                context.delete(object)
            }
        }

        if mode == .replace {
            try wipe(Transaction.self); try wipe(RecurringExpense.self); try wipe(IncomeSource.self)
            try wipe(CategoryBudget.self); try wipe(MerchantRule.self); try wipe(InstallmentPlan.self)
            try wipe(SavingsGoal.self); try wipe(CityEnrichment.self); try wipe(RecapSnapshot.self)
            try wipe(ScheduledExpense.self)
        }

        var txIds = mode == .replace ? Set<UUID>() : (try existingIds(Transaction.self) { $0.id })
        for dto in envelope.transactions {
            guard !txIds.contains(dto.id) else { summary.skipped += 1; continue }
            guard dto.amount.isFinite, let sanitizedAmount = MoneyAmount.sanitizedSigned(dto.amount) else {
                continue
            }
            let category = SpendingCategory(rawValue: dto.category)?.canonical ?? .other
            let cleanMerchant = InputSanitizer.sanitizeSingleLine(dto.merchant, maxLength: InputSanitizer.maxMerchantLength)
            let cleanCurrency = InputSanitizer.sanitizeSingleLine(dto.currency, maxLength: InputSanitizer.maxCurrencyLength)
            let date = isPlausibleDate(dto.timestamp) ? dto.timestamp : Date()
            let cleanNote = dto.note.map { InputSanitizer.sanitizeMultiline($0, maxLength: InputSanitizer.maxNoteLength) }
            let validBuildingId = dto.buildingId.flatMap { raw -> String? in
                let cleaned = InputSanitizer.sanitizeIdentifier(raw)
                return CityBuilding.allKnownBuildingIds.contains(cleaned) ? cleaned : nil
            }
            let safeConfidence = dto.confidenceScore.isFinite ? min(1.0, max(0.0, dto.confidenceScore)) : 1.0

            let t = Transaction(
                id: dto.id,
                amount: sanitizedAmount,
                currency: cleanCurrency.isEmpty ? "₪" : cleanCurrency,
                merchant: cleanMerchant,
                category: category,
                timestamp: date,
                confidenceScore: safeConfidence,
                isManual: dto.isManual,
                isConfirmed: dto.isConfirmed,
                note: cleanNote,
                buildingId: validBuildingId,
                originalAmount: dto.originalAmount.flatMap { $0.isFinite ? $0 : nil },
                originalCurrency: dto.originalCurrency.map { InputSanitizer.sanitizeSingleLine($0, maxLength: InputSanitizer.maxCurrencyLength) },
                exchangeRate: dto.exchangeRate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
                savingsGoalId: dto.savingsGoalId,
                installmentPlanId: dto.installmentPlanId,
                installmentIndex: dto.installmentIndex.flatMap { (1...120).contains($0) ? $0 : nil }
            )
            context.insert(t)
            txIds.insert(dto.id)
            summary.added += 1
        }

        var recIds = mode == .replace ? Set<UUID>() : (try existingIds(RecurringExpense.self) { $0.id })
        for dto in envelope.recurring {
            guard !recIds.contains(dto.id) else { summary.skipped += 1; continue }
            guard dto.amount.isFinite, let sanitizedAmount = MoneyAmount.sanitized(dto.amount) else {
                continue
            }
            let category = SpendingCategory(rawValue: dto.category)?.canonical ?? .other
            let cleanMerchant = InputSanitizer.sanitizeSingleLine(dto.merchant, maxLength: InputSanitizer.maxMerchantLength)
            let cleanCurrency = InputSanitizer.sanitizeSingleLine(dto.currency, maxLength: InputSanitizer.maxCurrencyLength)
            let day = max(1, min(31, dto.dayOfMonth))

            let r = RecurringExpense(
                merchant: cleanMerchant,
                amount: sanitizedAmount,
                category: category,
                dayOfMonth: day
            )
            r.id = dto.id
            r.currency = cleanCurrency.isEmpty ? "₪" : cleanCurrency
            r.categoryRawValue = category.rawValue
            r.isActive = dto.isActive
            r.lastGeneratedPeriod = dto.lastGeneratedPeriod.map { InputSanitizer.sanitizeIdentifier($0, maxLength: 32) }
            r.createdAt = isPlausibleDate(dto.createdAt) ? dto.createdAt : Date()
            context.insert(r)
            recIds.insert(dto.id)
            summary.added += 1
        }

        var incIds = mode == .replace ? Set<UUID>() : (try existingIds(IncomeSource.self) { $0.id })
        for dto in envelope.income {
            guard !incIds.contains(dto.id) else { summary.skipped += 1; continue }
            guard dto.amount.isFinite, let sanitizedAmount = MoneyAmount.sanitized(dto.amount) else {
                continue
            }
            let cleanName = InputSanitizer.sanitizeSingleLine(dto.name, maxLength: InputSanitizer.maxMerchantLength)
            let cleanCurrency = InputSanitizer.sanitizeSingleLine(dto.currency, maxLength: InputSanitizer.maxCurrencyLength)
            let day = max(1, min(31, dto.dayOfMonth))

            let i = IncomeSource(name: cleanName, amount: sanitizedAmount, dayOfMonth: day)
            i.id = dto.id
            i.currency = cleanCurrency.isEmpty ? "₪" : cleanCurrency
            i.isActive = dto.isActive
            i.createdAt = isPlausibleDate(dto.createdAt) ? dto.createdAt : Date()
            context.insert(i)
            incIds.insert(dto.id)
            summary.added += 1
        }

        var budIds = mode == .replace ? Set<UUID>() : (try existingIds(CategoryBudget.self) { $0.id })
        for dto in envelope.budgets {
            guard !budIds.contains(dto.id) else { summary.skipped += 1; continue }
            guard dto.monthlyLimit.isFinite && dto.monthlyLimit >= 0 else { continue }
            let category = SpendingCategory(rawValue: dto.category)?.canonical ?? .other

            let b = CategoryBudget(
                category: category,
                monthlyLimit: dto.monthlyLimit
            )
            b.id = dto.id
            b.categoryRawValue = category.rawValue
            b.createdAt = isPlausibleDate(dto.createdAt) ? dto.createdAt : Date()
            context.insert(b)
            budIds.insert(dto.id)
            summary.added += 1
        }

        var ruleIds = mode == .replace ? Set<UUID>() : (try existingIds(MerchantRule.self) { $0.id })
        for dto in envelope.merchantRules {
            guard !ruleIds.contains(dto.id) else { summary.skipped += 1; continue }
            let category = SpendingCategory(rawValue: dto.category)?.canonical ?? .other
            let cleanKey = InputSanitizer.sanitizeSingleLine(dto.merchantKey, maxLength: InputSanitizer.maxMerchantLength)
            let cleanDisplay = InputSanitizer.sanitizeSingleLine(dto.displayName, maxLength: InputSanitizer.maxMerchantLength)
            let validBuildingId = dto.buildingId.flatMap { raw -> String? in
                let cleaned = InputSanitizer.sanitizeIdentifier(raw)
                return CityBuilding.allKnownBuildingIds.contains(cleaned) ? cleaned : nil
            }

            let r = MerchantRule(
                id: dto.id,
                merchantKey: cleanKey,
                displayName: cleanDisplay,
                category: category,
                buildingId: validBuildingId,
                hitCount: max(0, dto.hitCount),
                createdAt: isPlausibleDate(dto.createdAt) ? dto.createdAt : Date()
            )
            context.insert(r)
            ruleIds.insert(dto.id)
            summary.added += 1
        }

        var planIds = mode == .replace ? Set<UUID>() : (try existingIds(InstallmentPlan.self) { $0.id })
        for dto in envelope.installments {
            guard !planIds.contains(dto.id) else { summary.skipped += 1; continue }
            guard dto.totalAmount.isFinite, let sanitizedTotal = MoneyAmount.sanitized(dto.totalAmount) else {
                continue
            }
            let payments = min(120, max(1, dto.numberOfPayments))
            let category = SpendingCategory(rawValue: dto.category)?.canonical ?? .other
            let cleanMerchant = InputSanitizer.sanitizeSingleLine(dto.merchant, maxLength: InputSanitizer.maxMerchantLength)
            let cleanCurrency = InputSanitizer.sanitizeSingleLine(dto.currency, maxLength: InputSanitizer.maxCurrencyLength)
            let validBuildingId = dto.buildingId.flatMap { raw -> String? in
                let cleaned = InputSanitizer.sanitizeIdentifier(raw)
                return CityBuilding.allKnownBuildingIds.contains(cleaned) ? cleaned : nil
            }
            let firstDate = isPlausibleDate(dto.firstChargeDate) ? dto.firstChargeDate : Date()
            let createdDate = isPlausibleDate(dto.createdAt) ? dto.createdAt : Date()
            let lastMat = max(0, min(payments, dto.lastMaterializedIndex ?? 0))

            let p = InstallmentPlan(
                id: dto.id,
                merchant: cleanMerchant,
                totalAmount: sanitizedTotal,
                currency: cleanCurrency.isEmpty ? "₪" : cleanCurrency,
                numberOfPayments: payments,
                firstChargeDate: firstDate,
                category: category,
                createdAt: createdDate,
                lastMaterializedIndex: lastMat,
                buildingIdRaw: validBuildingId
            )
            context.insert(p)
            planIds.insert(dto.id)
            summary.added += 1
        }

        var goalIds = mode == .replace ? Set<UUID>() : (try existingIds(SavingsGoal.self) { $0.id })
        for dto in envelope.savingsGoals {
            guard !goalIds.contains(dto.id) else { summary.skipped += 1; continue }
            let cleanName = InputSanitizer.sanitizeSingleLine(dto.name, maxLength: InputSanitizer.maxMerchantLength)
            let cleanIcon = InputSanitizer.sanitizeSingleLine(dto.icon, maxLength: 64)
            let cleanCurrency = InputSanitizer.sanitizeSingleLine(dto.currency, maxLength: InputSanitizer.maxCurrencyLength)
            let targetAmt = dto.targetAmount.isFinite ? max(0.0, dto.targetAmount) : 0.0
            let savedAmt = dto.savedAmount.isFinite ? max(0.0, dto.savedAmount) : 0.0
            let targetDate = dto.targetDate.flatMap { isPlausibleDate($0) ? $0 : nil }
            let createdDate = isPlausibleDate(dto.createdAt) ? dto.createdAt : Date()
            let completedDate = dto.completedAt.flatMap { isPlausibleDate($0) ? $0 : nil }
            let unlinked = dto.unlinkedBaseline.isFinite ? max(0.0, dto.unlinkedBaseline) : 0.0

            let g = SavingsGoal(
                id: dto.id,
                name: cleanName,
                icon: cleanIcon,
                targetAmount: targetAmt,
                savedAmount: savedAmt,
                currency: cleanCurrency.isEmpty ? "₪" : cleanCurrency,
                targetDate: targetDate,
                createdAt: createdDate,
                completedAt: completedDate,
                unlinkedBaseline: unlinked,
                baselineCaptured: dto.baselineCaptured
            )
            context.insert(g)
            goalIds.insert(dto.id)
            summary.added += 1
        }

        var enrIds = mode == .replace ? Set<UUID>() : (try existingIds(CityEnrichment.self) { $0.id })
        for dto in envelope.enrichments {
            guard !enrIds.contains(dto.id) else { summary.skipped += 1; continue }
            let cleanItemId = InputSanitizer.sanitizeIdentifier(dto.itemId)
            let cleanName = InputSanitizer.sanitizeSingleLine(dto.name, maxLength: InputSanitizer.maxMerchantLength)
            let cleanSubtitle = InputSanitizer.sanitizeSingleLine(dto.subtitle, maxLength: InputSanitizer.maxMerchantLength)
            let cleanIcon = InputSanitizer.sanitizeSingleLine(dto.icon, maxLength: 64)
            let type = EnrichmentType(rawValue: dto.type) ?? .decoration
            let cleanTier = InputSanitizer.sanitizeSingleLine(dto.tier, maxLength: 32)
            let unlockedDate = isPlausibleDate(dto.unlockedDate) ? dto.unlockedDate : Date()
            let savedAmt = dto.savedAmount.isFinite ? max(0.0, dto.savedAmount) : 0.0
            let cleanDistrictId = InputSanitizer.sanitizeIdentifier(dto.districtId)
            let cleanSlotId = dto.placedSlotId.map { InputSanitizer.sanitizeIdentifier($0) }

            let e = CityEnrichment(
                id: dto.id,
                itemId: cleanItemId,
                name: cleanName,
                subtitle: cleanSubtitle,
                icon: cleanIcon,
                type: type,
                tier: cleanTier,
                unlockedDate: unlockedDate,
                savedAmount: savedAmt,
                districtId: cleanDistrictId,
                isApplied: dto.isApplied,
                placedSlotId: cleanSlotId
            )
            context.insert(e)
            enrIds.insert(dto.id)
            summary.added += 1
        }

        var recapIds = mode == .replace ? Set<String>() : Set((try context.fetch(FetchDescriptor<RecapSnapshot>())).map { $0.monthId })
        for dto in envelope.recaps {
            guard !recapIds.contains(dto.monthId) else { summary.skipped += 1; continue }
            let cleanMonthId = InputSanitizer.sanitizeIdentifier(dto.monthId, maxLength: 32)
            guard !cleanMonthId.isEmpty else { continue }
            let date = isPlausibleDate(dto.frozenAt) ? dto.frozenAt : Date()

            let s = RecapSnapshot(
                monthId: cleanMonthId,
                payloadJSON: dto.payloadJSON,
                frozenAt: date
            )
            context.insert(s)
            recapIds.insert(cleanMonthId)
            summary.added += 1
        }

        var schedIds = mode == .replace ? Set<UUID>() : (try existingIds(ScheduledExpense.self) { $0.id })
        for dto in envelope.scheduled {
            guard !schedIds.contains(dto.id) else { summary.skipped += 1; continue }
            guard dto.amount.isFinite, let sanitizedAmount = MoneyAmount.sanitized(dto.amount) else { continue }
            let category = SpendingCategory(rawValue: dto.category)?.canonical ?? .other
            let cleanMerchant = InputSanitizer.sanitizeSingleLine(dto.merchant, maxLength: InputSanitizer.maxMerchantLength)
            let cleanCurrency = InputSanitizer.sanitizeSingleLine(dto.currency, maxLength: InputSanitizer.maxCurrencyLength)
            let schedDate = isPlausibleDate(dto.scheduledFor) ? dto.scheduledFor : Date()
            let validBuildingId = dto.buildingId.flatMap { raw -> String? in
                let cleaned = InputSanitizer.sanitizeIdentifier(raw)
                return CityBuilding.allKnownBuildingIds.contains(cleaned) ? cleaned : nil
            }
            let s = ScheduledExpense(
                id: dto.id,
                merchant: cleanMerchant,
                amount: sanitizedAmount,
                currency: cleanCurrency.isEmpty ? "₪" : cleanCurrency,
                category: category,
                scheduledFor: schedDate,
                createdAt: isPlausibleDate(dto.createdAt) ? dto.createdAt : Date(),
                buildingIdRaw: validBuildingId,
                originalAmount: dto.originalAmount.flatMap { MoneyAmount.sanitized($0) },
                originalCurrency: dto.originalCurrency.map { InputSanitizer.sanitizeSingleLine($0, maxLength: InputSanitizer.maxCurrencyLength) },
                exchangeRate: dto.exchangeRate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
                materializedAt: dto.materializedAt.flatMap { isPlausibleDate($0) ? $0 : nil },
                materializedTransactionId: dto.materializedTransactionId
            )
            context.insert(s)
            schedIds.insert(dto.id)
            summary.added += 1
        }

        // Reconcile goal math with restored transactions
        SavingsGoalService.reconcileAll(context: context)

        do {
            try context.save()
        } catch {
            // In .replace mode every existing row has already been deleted on this context. Leaving
            // that staged means the next unrelated save in the app silently commits the wipe.
            context.rollback()
            throw error
        }

        if restorePreferences, let prefs = envelope.preferences {
            Self.restorePreferences(prefs, defaults: defaults, groupDefaults: groupDefaults)
            Self.postRestoreRefresh()
        }

        return summary
    }

    /// Refreshes runtime singletons and external system services after restoring user preferences.
    @MainActor
    public static func postRestoreRefresh() {
        // 1. Refresh Localization & Currency
        LocalizationManager.shared.refresh()

        // 2. Resynchronize scheduled notifications with restored preferences & language
        NotificationService.sync(
            enabled: NotificationService.isEnabled,
            isHebrew: LocalizationManager.shared.isHebrew
        )

        // 3. Reload Widget timelines to reflect restored balances and settings
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
