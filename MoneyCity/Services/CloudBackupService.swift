import Foundation
import SwiftData
import Combine

/// Describes a discovered iCloud backup generation.
public struct CloudBackupDescriptor: Identifiable, Equatable, Sendable {
    public let id: String              // file name
    public let url: URL
    public let exportedAt: Date
    public let appVersion: String
    public let appBuild: String
    public let recordCount: Int
    public let byteSize: Int64

    public var displayDate: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: exportedAt)
    }

    public init(
        id: String,
        url: URL,
        exportedAt: Date,
        appVersion: String,
        appBuild: String,
        recordCount: Int,
        byteSize: Int64
    ) {
        self.id = id
        self.url = url
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.recordCount = recordCount
        self.byteSize = byteSize
    }
}

/// Actor managing low-level iCloud Documents / ubiquity container operations.
///
/// Keeps all filesystem and ubiquitous coordination off the main thread.
public actor CloudBackupStorageWorker {
    public static let containerIdentifier = "iCloud.com.moneycity.app"
    public static let keepGenerationsCount = 3

    private let fileManager = FileManager()
    private var customContainerURL: URL? = nil

    public init(customContainerURL: URL? = nil) {
        self.customContainerURL = customContainerURL
    }

    /// Resolves the ubiquity container directory for SPENT backups.
    public func resolveBackupDirectory() throws -> URL {
        let baseDir: URL
        if let custom = customContainerURL {
            baseDir = custom
        } else {
            guard let container = fileManager.url(forUbiquityContainerIdentifier: Self.containerIdentifier) ??
                    fileManager.url(forUbiquityContainerIdentifier: nil) else {
                throw CloudBackupError.iCloudContainerUnavailable
            }
            baseDir = container
        }

        let backupsDir = baseDir.appendingPathComponent("Documents/Backups", isDirectory: true)
        if !fileManager.fileExists(atPath: backupsDir.path) {
            try fileManager.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        }
        return backupsDir
    }

    /// Checks if iCloud Documents storage is available on this device.
    public func isUbiquityAvailable() -> Bool {
        if customContainerURL != nil { return true }
        guard fileManager.ubiquityIdentityToken != nil else { return false }
        return (fileManager.url(forUbiquityContainerIdentifier: Self.containerIdentifier) ??
                fileManager.url(forUbiquityContainerIdentifier: nil)) != nil
    }

    /// Generates a chronologically sortable backup file name.
    public static func backupFileName(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return "SPENT-backup-\(f.string(from: date)).json"
    }

    /// Writes a backup payload atomically to the cloud container and prunes older generations,
    /// using NSFileCoordinator to coordinate safely with ubiquitous storage daemons.
    public func writeBackupData(_ data: Data, exportedAt: Date = Date()) throws -> CloudBackupDescriptor {
        let backupsDir = try resolveBackupDirectory()
        let fileName = Self.backupFileName(for: exportedAt)
        let destinationURL = backupsDir.appendingPathComponent(fileName)
        let tempURL = backupsDir.appendingPathComponent(".\(fileName).tmp")

        // 1. Validate envelope integrity before writing to cloud storage
        let envelope = try DataPortabilityService.validateBackupData(data)

        // 2. Atomic coordinated write via temporary file inside the container
        if fileManager.fileExists(atPath: tempURL.path) {
            try? fileManager.removeItem(at: tempURL)
        }
        try data.write(to: tempURL, options: [.atomic, .completeFileProtection])

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var actionError: Error?

        coordinator.coordinate(writingItemAt: destinationURL, options: [.forReplacing], error: &coordinationError) { targetURL in
            do {
                if fileManager.fileExists(atPath: targetURL.path) {
                    _ = try fileManager.replaceItemAt(targetURL, withItemAt: tempURL)
                } else {
                    try fileManager.moveItem(at: tempURL, to: targetURL)
                }
            } catch {
                actionError = error
            }
        }

        if let coordinationError = coordinationError {
            try? fileManager.removeItem(at: tempURL)
            throw coordinationError
        }
        if let actionError = actionError {
            try? fileManager.removeItem(at: tempURL)
            throw actionError
        }

        // 3. Prune older generations beyond keepGenerationsCount
        pruneGenerations(in: backupsDir, keeping: Self.keepGenerationsCount)

        let attributes = (try? fileManager.attributesOfItem(atPath: destinationURL.path)) ?? [:]
        let size = (attributes[.size] as? Int64) ?? Int64(data.count)

        return CloudBackupDescriptor(
            id: fileName,
            url: destinationURL,
            exportedAt: envelope.exportedAt,
            appVersion: envelope.appVersion,
            appBuild: envelope.appBuild,
            recordCount: envelope.totalRecords,
            byteSize: size
        )
    }

    /// Reads data from a backup URL, triggering ubiquitous download if not local, coordinated via NSFileCoordinator.
    public func readBackupData(from url: URL, timeout: TimeInterval = 10.0) async throws -> Data {
        let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        if values?.isUbiquitousItem == true {
            if values?.ubiquitousItemDownloadingStatus != .current {
                try fileManager.startDownloadingUbiquitousItem(at: url)
                let start = Date()
                while Date().timeIntervalSince(start) < timeout {
                    let updated = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    if updated?.ubiquitousItemDownloadingStatus == .current {
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                }
            }
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var readData: Data?

        coordinator.coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordinationError) { coordinatedURL in
            readData = try? Data(contentsOf: coordinatedURL)
        }

        if let coordinationError = coordinationError {
            throw coordinationError
        }
        guard let data = readData ?? (try? Data(contentsOf: url)) else {
            throw CloudBackupError.corruptedBackup("Unable to read backup file")
        }
        return data
    }

    /// Lists all valid backups currently available in the cloud directory, newest first.
    public func availableBackups() throws -> [CloudBackupDescriptor] {
        let backupsDir = try resolveBackupDirectory()
        let items = (try? fileManager.contentsOfDirectory(atPath: backupsDir.path)) ?? []
        let backupFiles = items.filter { $0.hasPrefix("SPENT-backup-") && $0.hasSuffix(".json") }.sorted(by: >)

        var descriptors: [CloudBackupDescriptor] = []
        for file in backupFiles {
            let url = backupsDir.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: url),
                  let envelope = try? DataPortabilityService.validateBackupData(data) else {
                continue
            }
            let attrs = (try? fileManager.attributesOfItem(atPath: url.path)) ?? [:]
            let size = (attrs[.size] as? Int64) ?? Int64(data.count)

            descriptors.append(CloudBackupDescriptor(
                id: file,
                url: url,
                exportedAt: envelope.exportedAt,
                appVersion: envelope.appVersion,
                appBuild: envelope.appBuild,
                recordCount: envelope.totalRecords,
                byteSize: size
            ))
        }

        return descriptors
    }

    /// Prunes older backup files in the given directory, keeping the newest `keep` count.
    public func pruneGenerations(in dir: URL, keeping keep: Int) {
        let items = (try? fileManager.contentsOfDirectory(atPath: dir.path)) ?? []
        let backupFiles = items.filter { $0.hasPrefix("SPENT-backup-") && $0.hasSuffix(".json") }.sorted(by: >)
        guard backupFiles.count > keep else { return }

        let filesToRemove = backupFiles.dropFirst(keep)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        for file in filesToRemove {
            let fileURL = dir.appendingPathComponent(file)
            var coordError: NSError?
            coordinator.coordinate(writingItemAt: fileURL, options: [.forDeleting], error: &coordError) { targetURL in
                try? fileManager.removeItem(at: targetURL)
            }
        }
    }
}

public enum CloudBackupError: LocalizedError {
    case iCloudContainerUnavailable
    case backupDisabled
    case noBackupFound
    case corruptedBackup(String)

    public var errorDescription: String? {
        switch self {
        case .iCloudContainerUnavailable:
            return AppLanguage.localized(
                "שירות iCloud אינו זמין כעת במכשיר זה.",
                "iCloud storage is currently unavailable on this device."
            )
        case .backupDisabled:
            return AppLanguage.localized(
                "גיבוי iCloud מושבת בהגדרות.",
                "iCloud Backup is disabled in settings."
            )
        case .noBackupFound:
            return AppLanguage.localized(
                "לא נמצא גיבוי ב־iCloud.",
                "No backup found in iCloud."
            )
        case .corruptedBackup(let msg):
            return AppLanguage.localized(
                "קובץ הגיבוי פגום: \(msg)",
                "Backup file is corrupted: \(msg)"
            )
        }
    }
}

/// Centralized coordinator for private iCloud backup and recovery.
///
/// Designed with strict resource discipline:
/// - Coalesced dirty-tracking (never backs up on every keystroke or transaction write)
/// - Backs up when app transitions to background or on explicit request
/// - Does not replace local-first data; serves strictly as an off-device recovery destination
@MainActor
public final class CloudBackupService: ObservableObject {
    public static let shared = CloudBackupService()

    public enum Status: Equatable {
        case checking
        case available(lastBackup: Date?, descriptor: CloudBackupDescriptor?)
        case backingUp
        case restoring
        case unavailable(reason: String)
    }

    @Published public private(set) var status: Status = .checking
    @Published public private(set) var lastBackupDate: Date? = nil
    @Published public private(set) var isBackingUp: Bool = false
    @Published public private(set) var isRestoring: Bool = false

    private let defaults: UserDefaults
    private let groupDefaults: UserDefaults
    private let worker: CloudBackupStorageWorker

    private var isDirty: Bool = false
    private var lastBackupAttempt: Date = .distantPast
    /// Rate limit for opportunistic backup checks while app is active.
    /// Primary automatic backups occur when the app transitions to background (scenePhase == .background).
    private let minOpportunisticBackupInterval: TimeInterval = 60 * 60 // 1 hour

    public static let backupEnabledKey = "spent.icloud_backup_enabled"
    public static let lastBackupDateKey = "spent.icloud_last_backup_date"

    public var isBackupEnabled: Bool {
        get { defaults.object(forKey: Self.backupEnabledKey) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Self.backupEnabledKey)
            objectWillChange.send()
        }
    }

    public init(
        defaults: UserDefaults = .standard,
        groupDefaults: UserDefaults = (UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard),
        worker: CloudBackupStorageWorker = CloudBackupStorageWorker()
    ) {
        self.defaults = defaults
        self.groupDefaults = groupDefaults
        self.worker = worker
        self.lastBackupDate = defaults.object(forKey: Self.lastBackupDateKey) as? Date
    }

    /// Marks that durable application state has changed and needs off-device backup.
    public func markDirty() {
        isDirty = true
    }

    /// Refreshes current iCloud backup status and lists the latest backup metadata.
    public func refreshStatus() async {
        let isAvailable = await worker.isUbiquityAvailable()
        guard isAvailable else {
            status = .unavailable(reason: AppLanguage.localized("iCloud אינו זמין", "iCloud unavailable"))
            return
        }

        do {
            let backups = try await worker.availableBackups()
            let latest = backups.first
            let latestDate = latest?.exportedAt ?? defaults.object(forKey: Self.lastBackupDateKey) as? Date
            self.lastBackupDate = latestDate
            status = .available(lastBackup: latestDate, descriptor: latest)
        } catch {
            status = .unavailable(reason: error.localizedDescription)
        }
    }

    /// Performs an off-device backup to the user's private iCloud container if enabled and dirty.
    @discardableResult
    public func performBackupIfNeeded(context: ModelContext, force: Bool = false) async throws -> CloudBackupDescriptor? {
        guard isBackupEnabled else { return nil }
        guard force || isDirty else { return nil }

        let now = Date()
        if !force && now.timeIntervalSince(lastBackupAttempt) < minOpportunisticBackupInterval {
            return nil
        }

        isBackingUp = true
        status = .backingUp
        defer { isBackingUp = false }

        do {
            let data = try DataPortabilityService.exportData(
                context: context,
                defaults: defaults,
                groupDefaults: groupDefaults,
                includePreferences: true,
                now: now
            )

            let descriptor = try await worker.writeBackupData(data, exportedAt: now)
            self.lastBackupDate = descriptor.exportedAt
            self.lastBackupAttempt = now
            self.isDirty = false
            defaults.set(descriptor.exportedAt, forKey: Self.lastBackupDateKey)
            status = .available(lastBackup: descriptor.exportedAt, descriptor: descriptor)
            return descriptor
        } catch {
            status = .unavailable(reason: error.localizedDescription)
            MoneyCityLog.error("CloudBackupService failed to write backup: \(error)")
            throw error
        }
    }

    /// For users upgrading from an older SPENT version that lacked Cloud Backup:
    /// Automatically creates their first iCloud backup in the background if they have existing local state
    /// and have never had an iCloud backup recorded.
    public func bootstrapFirstBackupIfNeeded(context: ModelContext) async {
        guard isBackupEnabled else { return }

        // If a backup date is already recorded, this installation has already completed its first backup.
        if lastBackupDate != nil { return }

        // CRITICAL GUARD: Only run bootstrap if SwiftData store opened successfully in persistent mode.
        // If a migration failed and created a recoveredFreshStore or memoryOnly store, NEVER backup an empty store!
        guard DatabaseService.shared.storageMode == .persistent else {
            MoneyCityLog.debug("Database is in degraded/recovery mode (\(DatabaseService.shared.storageMode)); skipping bootstrap backup to avoid saving an empty store.")
            return
        }

        // Only bootstrap if the user actually has meaningful existing local state (evaluated with OR logic)
        guard Self.hasMeaningfulLocalState(context: context, defaults: defaults, groupDefaults: groupDefaults) else {
            MoneyCityLog.debug("No meaningful local state yet; bootstrap backup will run after user setup.")
            return
        }

        // Verify iCloud storage is available on this device
        guard await worker.isUbiquityAvailable() else {
            MoneyCityLog.debug("Cloud storage unavailable for initial bootstrap; will retry later.")
            return
        }

        // Check if an existing cloud backup is already present in the user's iCloud container
        if let existing = try? await worker.availableBackups(), let latest = existing.first {
            // Already backed up from another device or prior session: record metadata without overwriting
            self.lastBackupDate = latest.exportedAt
            defaults.set(latest.exportedAt, forKey: Self.lastBackupDateKey)
            status = .available(lastBackup: latest.exportedAt, descriptor: latest)
            MoneyCityLog.debug("Found pre-existing iCloud backup (\(latest.id)), bootstrap not needed.")
            return
        }

        // No iCloud backup exists yet: create the very first backup from existing local state!
        MoneyCityLog.debug("Bootstrapping first iCloud backup from existing local user data...")
        do {
            _ = try await performBackupIfNeeded(context: context, force: true)
            MoneyCityLog.debug("Successfully created the first iCloud backup for returning user.")
        } catch {
            MoneyCityLog.error("Initial cloud backup creation failed; will retry automatically: \(error)")
        }
    }

    /// Checks if a valid cloud backup exists to offer on a clean installation.
    public func discoverCleanInstallBackup() async -> CloudBackupDescriptor? {
        let isAvailable = await worker.isUbiquityAvailable()
        guard isAvailable else { return nil }
        guard let backups = try? await worker.availableBackups(), let latest = backups.first else {
            return nil
        }
        return latest
    }

    /// Restores the complete application state from the latest available iCloud backup.
    @discardableResult
    public func restoreLatestBackup(context: ModelContext) async throws -> DataPortabilityService.ImportSummary {
        let isAvailable = await worker.isUbiquityAvailable()
        guard isAvailable else { throw CloudBackupError.iCloudContainerUnavailable }

        isRestoring = true
        status = .restoring
        defer { isRestoring = false }

        let backups = try await worker.availableBackups()
        guard let latest = backups.first else {
            throw CloudBackupError.noBackupFound
        }

        let data = try await worker.readBackupData(from: latest.url)
        let summary = try DataPortabilityService.importData(
            data,
            into: context,
            defaults: defaults,
            groupDefaults: groupDefaults,
            mode: .replace,
            restorePreferences: true
        )

        self.lastBackupDate = latest.exportedAt
        defaults.set(latest.exportedAt, forKey: Self.lastBackupDateKey)
        status = .available(lastBackup: latest.exportedAt, descriptor: latest)
        return summary
    }

    /// Disables dirty flag after explicit restore.
    public func clearDirty() {
        isDirty = false
    }

    /// Determines whether the local device contains any meaningful user data (evaluated strictly with OR logic).
    /// If ANY single user signal is present, returns true.
    public static func hasMeaningfulLocalState(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        groupDefaults: UserDefaults = (UserDefaults(suiteName: "group.com.moneycity.app") ?? .standard)
    ) -> Bool {
        // 1. Onboarding markers
        if defaults.bool(forKey: "hasCompletedOnboarding") || defaults.bool(forKey: "hasStartedOnboardingV2") {
            return true
        }

        // 2. User profile name
        let userName = (defaults.string(forKey: "userName") ?? defaults.string(forKey: "user_name") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !userName.isEmpty { return true }

        // 3. Monthly budget
        if defaults.double(forKey: "monthly_budget") > 0 || groupDefaults.double(forKey: "monthly_budget") > 0 {
            return true
        }

        // 4. Streak / awareness active days
        let activeDays = defaults.stringArray(forKey: "spent_tracking_active_days") ?? []
        if !activeDays.isEmpty { return true }

        // 5. City map style preference
        if CityMapSelection.hasCustomStyle(defaults: defaults) { return true }

        // 6. Core SwiftData models (ANY row count > 0 is meaningful state)
        if (try? context.fetchCount(FetchDescriptor<Transaction>())) ?? 0 > 0 { return true }
        if (try? context.fetchCount(FetchDescriptor<SavingsGoal>())) ?? 0 > 0 { return true }
        if (try? context.fetchCount(FetchDescriptor<RecapSnapshot>())) ?? 0 > 0 { return true }
        if (try? context.fetchCount(FetchDescriptor<CityEnrichment>())) ?? 0 > 0 { return true }
        if (try? context.fetchCount(FetchDescriptor<CategoryBudget>())) ?? 0 > 0 { return true }
        if (try? context.fetchCount(FetchDescriptor<RecurringExpense>())) ?? 0 > 0 { return true }
        if (try? context.fetchCount(FetchDescriptor<IncomeSource>())) ?? 0 > 0 { return true }
        if (try? context.fetchCount(FetchDescriptor<InstallmentPlan>())) ?? 0 > 0 { return true }
        if (try? context.fetchCount(FetchDescriptor<MerchantRule>())) ?? 0 > 0 { return true }

        return false
    }
}
