import XCTest
import SwiftData
@testable import MoneyCity

/// Snapshots are the app's rollback for the one failure that actually happens — a new build
/// whose migration does not go through. The naming and retention rules are what make the
/// folder a usable history instead of an unbounded second copy of the database.
final class StoreSnapshotNamingTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0, _ sec: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi, second: sec))!
    }

    func testFolderNamesSortChronologicallyAsText() {
        // The listing sorts by name; if that ever stopped matching time order, "restore the
        // newest" would quietly restore something else.
        let older = StoreSnapshotService.folderName(for: date(2026, 9, 1, 9), build: "40")
        let newer = StoreSnapshotService.folderName(for: date(2026, 9, 1, 17), build: "41")
        let nextYear = StoreSnapshotService.folderName(for: date(2027, 1, 3, 8), build: "42")
        XCTAssertLessThan(older, newer)
        XCTAssertLessThan(newer, nextYear)
    }

    func testFolderNameCarriesTheBuild() {
        XCTAssertTrue(StoreSnapshotService.folderName(for: date(2026, 9, 1), build: "47").hasSuffix("-build47"))
    }

    func testFolderNameSurvivesAnEmptyBuildNumber() {
        XCTAssertTrue(StoreSnapshotService.folderName(for: date(2026, 9, 1), build: "").hasSuffix("-build0"))
    }

    func testNothingIsPrunedWhileUnderTheLimit() {
        let names = ["2026-09-01-100000-build1", "2026-09-02-100000-build2"]
        XCTAssertTrue(StoreSnapshotService.foldersToPrune(names, keep: 3).isEmpty)
    }

    func testTheOldestAreDroppedFirst() {
        let names = [
            "2026-09-01-100000-build1",
            "2026-09-02-100000-build2",
            "2026-09-03-100000-build3",
            "2026-09-04-100000-build4",
            "2026-09-05-100000-build5"
        ]
        XCTAssertEqual(
            StoreSnapshotService.foldersToPrune(names, keep: 3).sorted(),
            ["2026-09-01-100000-build1", "2026-09-02-100000-build2"]
        )
    }

    func testPruningIsIndependentOfListingOrder() {
        let shuffled = ["2026-09-03-100000-build3", "2026-09-01-100000-build1", "2026-09-02-100000-build2"]
        XCTAssertEqual(StoreSnapshotService.foldersToPrune(shuffled, keep: 2), ["2026-09-01-100000-build1"])
    }

    func testKeepingNoneDropsEverything() {
        let names = ["2026-09-01-100000-build1", "2026-09-02-100000-build2"]
        XCTAssertEqual(StoreSnapshotService.foldersToPrune(names, keep: 0).count, 2)
    }

    func testTheStoreJournalFilesAreIncluded() {
        // Copying default.store on its own can capture a torn write; the -wal file is part
        // of the database, not a temporary.
        XCTAssertTrue(StoreSnapshotService.storeFileNames.contains("default.store"))
        XCTAssertTrue(StoreSnapshotService.storeFileNames.contains("default.store-wal"))
        XCTAssertTrue(StoreSnapshotService.storeFileNames.contains("default.store-shm"))
    }
}

/// The export file is the only copy of the user's data that is readable without this app, so
/// its shape has to survive a round trip exactly, and a file that is not ours has to be
/// refused rather than half-imported.
final class BackupEnvelopeTests: XCTestCase {

    private func envelope(transactions: [DataPortabilityService.TransactionDTO] = []) -> DataPortabilityService.Envelope {
        DataPortabilityService.Envelope(
            format: DataPortabilityService.formatIdentifier,
            formatVersion: DataPortabilityService.formatVersion,
            appVersion: "1.0", appBuild: "47",
            exportedAt: Date(timeIntervalSince1970: 1_788_000_000),
            transactions: transactions, recurring: [], income: [], budgets: [],
            merchantRules: [], installments: [], savingsGoals: [], enrichments: []
        )
    }

    private func sampleTransaction() -> DataPortabilityService.TransactionDTO {
        DataPortabilityService.TransactionDTO(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            amount: 1450.50, currency: "₪", merchant: "סופר-פארם",
            category: "groceries", timestamp: Date(timeIntervalSince1970: 1_787_900_000),
            confidenceScore: 0.94, isManual: false, isConfirmed: true,
            note: "הערה", buildingId: "food_super",
            originalAmount: 380.0, originalCurrency: "$", exchangeRate: 3.81,
            savingsGoalId: nil
        )
    }

    func testATransactionSurvivesTheRoundTripExactly() throws {
        let original = envelope(transactions: [sampleTransaction()])
        let data = try DataPortabilityService.makeEncoder().encode(original)
        let back = try DataPortabilityService.makeDecoder()
            .decode(DataPortabilityService.Envelope.self, from: data)

        XCTAssertEqual(back.transactions.count, 1)
        let t = back.transactions[0]
        XCTAssertEqual(t.id, original.transactions[0].id)
        XCTAssertEqual(t.amount, 1450.50, accuracy: 0.0001)
        XCTAssertEqual(t.merchant, "סופר-פארם")
        XCTAssertEqual(t.currency, "₪")
        XCTAssertEqual(t.category, "groceries")
        XCTAssertEqual(t.note, "הערה")
        XCTAssertEqual(t.originalCurrency, "$")
        XCTAssertEqual(t.exchangeRate, 3.81)
        XCTAssertEqual(t.timestamp.timeIntervalSince1970,
                       original.transactions[0].timestamp.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    func testDatesAreWrittenAsReadableISO8601() throws {
        // A backup should still make sense to a person, and to a reader that is not this
        // build, years from now — not as a floating-point offset from 2001.
        let data = try DataPortabilityService.makeEncoder().encode(envelope())
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("2026-"), "expected an ISO-8601 date, got: \(text.prefix(300))")
    }

    func testTheEnvelopeIdentifiesItself() throws {
        let data = try DataPortabilityService.makeEncoder().encode(envelope())
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("moneycity.backup"))
    }

    func testAFileThatIsNotABackupIsRejected() throws {
        let foreign = #"{"format":"something.else","formatVersion":1}"#.data(using: .utf8)!
        XCTAssertThrowsError(
            try DataPortabilityService.makeDecoder()
                .decode(DataPortabilityService.Envelope.self, from: foreign)
        )
    }

    func testTotalRecordsCountsEveryKind() {
        var e = envelope(transactions: [sampleTransaction(), sampleTransaction()])
        e.savingsGoals = [
            DataPortabilityService.SavingsGoalDTO(
                id: UUID(), name: "טיול", icon: "✈️", targetAmount: 4000, savedAmount: 500,
                currency: "₪", targetDate: nil, createdAt: Date(), completedAt: nil,
                unlinkedBaseline: 0, baselineCaptured: true
            )
        ]
        XCTAssertEqual(e.totalRecords, 3)
    }

    func testSuggestedFileNameSortsAndSaysWhatItIs() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        let d = c.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 14, minute: 32))!
        let name = DataPortabilityService.suggestedFileName(now: d)
        XCTAssertTrue(name.hasPrefix("MoneyCity-2026-09-01-"))
        XCTAssertTrue(name.hasSuffix(".json"))
    }

    func testPruningExcludesSnapshotBeingRestored() {
        let names = [
            "2026-09-01-100000-build1",
            "2026-09-02-100000-build2",
            "2026-09-03-100000-build3",
            "2026-09-04-100000-build4",
            "2026-09-05-100000-build5"
        ]
        // build1 is oldest, but if it is being restored, it must never be pruned!
        let pruned = StoreSnapshotService.foldersToPrune(names, keep: 3, excluding: "2026-09-01-100000-build1")
        XCTAssertFalse(pruned.contains("2026-09-01-100000-build1"))
        XCTAssertEqual(pruned.sorted(), ["2026-09-02-100000-build2"])
    }

    func testInstallmentPlanDTOAndTransactionLinkRoundTrip() throws {
        let planId = UUID()
        let tx = DataPortabilityService.TransactionDTO(
            id: UUID(),
            amount: 250.0,
            currency: "₪",
            merchant: "KSP",
            category: "electronics",
            timestamp: Date(timeIntervalSince1970: 1_788_000_000),
            confidenceScore: 1.0,
            isManual: true,
            isConfirmed: true,
            buildingId: "shop_tech",
            installmentPlanId: planId,
            installmentIndex: 1
        )
        let plan = DataPortabilityService.InstallmentDTO(
            id: planId,
            merchant: "KSP",
            totalAmount: 3000.0,
            currency: "₪",
            numberOfPayments: 12,
            firstChargeDate: Date(timeIntervalSince1970: 1_788_000_000),
            category: "electronics",
            createdAt: Date(timeIntervalSince1970: 1_788_000_000),
            lastMaterializedIndex: 1,
            buildingId: "shop_tech"
        )

        var e = envelope(transactions: [tx])
        e.installments = [plan]

        let data = try DataPortabilityService.makeEncoder().encode(e)
        let decoded = try DataPortabilityService.makeDecoder().decode(DataPortabilityService.Envelope.self, from: data)

        XCTAssertEqual(decoded.transactions[0].installmentPlanId, planId)
        XCTAssertEqual(decoded.transactions[0].installmentIndex, 1)
        XCTAssertEqual(decoded.installments[0].lastMaterializedIndex, 1)
        XCTAssertEqual(decoded.installments[0].buildingId, "shop_tech")
    }
}

// MARK: - Persistence & Cloud Backup V2 Tests

@MainActor
final class PersistenceAndCloudBackupTests: XCTestCase {

    private func makeInMemoryContext() -> ModelContext {
        let schema = Schema(MoneyCitySchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testV2BackupRoundTripWithPreferencesAndRecaps() throws {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let recap = DataPortabilityService.RecapSnapshotDTO(
            monthId: "2026-08",
            payloadJSON: "{\"totalSpent\": 2450.0}",
            frozenAt: now
        )
        let prefs = DataPortabilityService.AppPreferencesDTO(
            userName: "Bini",
            monthlyBudget: 5000.0,
            hasCompletedOnboarding: true,
            hasStartedOnboardingV2: true,
            trackingActiveDays: ["2026-09-18", "2026-09-19", "2026-09-20"],
            monthlyMapSelections: ["2026-09": CityMapSelection.MonthEntry(style: "urban", confirmed: true)],
            appLanguage: "he",
            appCurrency: "ILS",
            autoConvertFX: true,
            hapticsEnabled: true,
            notificationsEnabled: true
        )
        let goal = DataPortabilityService.SavingsGoalDTO(
            id: UUID(),
            name: "Emergency Fund",
            icon: "🛡️",
            targetAmount: 10000.0,
            savedAmount: 2500.0,
            currency: "ILS",
            targetDate: nil,
            createdAt: now,
            completedAt: nil,
            unlinkedBaseline: 2500.0,
            baselineCaptured: true
        )

        let envelope = DataPortabilityService.Envelope(
            format: DataPortabilityService.formatIdentifier,
            formatVersion: 2,
            appVersion: "1.0",
            appBuild: "47",
            exportedAt: now,
            transactions: [],
            recurring: [],
            income: [],
            budgets: [],
            merchantRules: [],
            installments: [],
            savingsGoals: [goal],
            enrichments: [],
            recaps: [recap],
            preferences: prefs
        )

        let encoded = try DataPortabilityService.makeEncoder().encode(envelope)
        let decoded = try DataPortabilityService.validateBackupData(encoded)

        XCTAssertEqual(decoded.formatVersion, 2)
        XCTAssertEqual(decoded.recaps.count, 1)
        XCTAssertEqual(decoded.recaps[0].monthId, "2026-08")
        XCTAssertEqual(decoded.recaps[0].payloadJSON, "{\"totalSpent\": 2450.0}")
        XCTAssertEqual(decoded.preferences?.userName, "Bini")
        XCTAssertEqual(decoded.preferences?.monthlyBudget, 5000.0)
        XCTAssertEqual(decoded.preferences?.trackingActiveDays, ["2026-09-18", "2026-09-19", "2026-09-20"])
        XCTAssertEqual(decoded.preferences?.monthlyMapSelections?["2026-09"]?.style, "urban")
        XCTAssertEqual(decoded.preferences?.monthlyMapSelections?["2026-09"]?.confirmed, true)
        XCTAssertEqual(decoded.preferences?.appCurrency, "ILS")
        XCTAssertEqual(decoded.preferences?.hasCompletedOnboarding, true)
        XCTAssertEqual(decoded.savingsGoals[0].unlinkedBaseline, 2500.0)
        XCTAssertEqual(decoded.savingsGoals[0].baselineCaptured, true)
        XCTAssertEqual(decoded.totalRecords, 2) // 1 goal + 1 recap
    }

    func testV1BackupBackwardCompatibility() throws {
        // A real V1 JSON fixture without recaps or preferences
        let v1JSON = """
        {
          "format": "moneycity.backup",
          "formatVersion": 1,
          "appVersion": "1.0",
          "appBuild": "42",
          "exportedAt": "2026-09-01T10:00:00Z",
          "transactions": [],
          "recurring": [],
          "income": [],
          "budgets": [],
          "merchantRules": [],
          "installments": [],
          "savingsGoals": [],
          "enrichments": []
        }
        """
        let data = v1JSON.data(using: .utf8)!
        let envelope = try DataPortabilityService.validateBackupData(data)

        XCTAssertEqual(envelope.format, "moneycity.backup")
        XCTAssertEqual(envelope.formatVersion, 2) // Migrated to current portable envelope format
        XCTAssertTrue(envelope.recaps.isEmpty)
        XCTAssertNil(envelope.preferences)
    }

    func testDataLossAndCorruptionSafety() throws {
        // Truncated data
        let truncated = "{\"format\":\"moneycity.backup\",\"formatVersion\":2".data(using: .utf8)!
        XCTAssertThrowsError(try DataPortabilityService.validateBackupData(truncated))

        // Invalid format identifier
        let wrongFormat = "{\"format\":\"invalid.backup\",\"formatVersion\":2}".data(using: .utf8)!
        XCTAssertThrowsError(try DataPortabilityService.validateBackupData(wrongFormat))

        // Unsupported future format version
        let futureVersion = "{\"format\":\"moneycity.backup\",\"formatVersion\":999,\"appVersion\":\"1.0\",\"appBuild\":\"1\",\"exportedAt\":\"2026-09-01T10:00:00Z\",\"transactions\":[],\"recurring\":[],\"income\":[],\"budgets\":[],\"merchantRules\":[],\"installments\":[],\"savingsGoals\":[],\"enrichments\":[]}".data(using: .utf8)!
        XCTAssertThrowsError(try DataPortabilityService.validateBackupData(futureVersion))
    }

    func testStreakTrackingDaysSurvivesRoundTrip() throws {
        let testDefaults = UserDefaults(suiteName: "test_streak_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        let trackingService = TrackingActivityService(defaults: testDefaults)
        let cal = Calendar.current
        let today = Date()
        let d0 = trackingService.dayKey(for: today)
        let d1 = trackingService.dayKey(for: cal.date(byAdding: .day, value: -1, to: today)!)
        let d2 = trackingService.dayKey(for: cal.date(byAdding: .day, value: -2, to: today)!)
        let originalDays = [d2, d1, d0]
        trackingService.setActiveDays(originalDays)
        XCTAssertEqual(trackingService.activeDays(), originalDays)

        let context = makeInMemoryContext()
        let data = try DataPortabilityService.exportData(
            context: context,
            defaults: testDefaults,
            groupDefaults: testDefaults,
            includePreferences: true
        )

        // Clear tracking days
        trackingService.setActiveDays([])
        XCTAssertTrue(trackingService.activeDays().isEmpty)

        // Restore
        _ = try DataPortabilityService.importData(
            data,
            into: context,
            defaults: testDefaults,
            groupDefaults: testDefaults,
            mode: .replace,
            restorePreferences: true
        )

        XCTAssertEqual(trackingService.activeDays(), originalDays)
        XCTAssertEqual(trackingService.currentStreakDays(), 3)
    }

    func testMapStyleSurvivesRoundTrip() throws {
        let testDefaults = UserDefaults(suiteName: "test_maps_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        CityMapSelection.save(.medieval, defaults: testDefaults)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .medieval)

        let context = makeInMemoryContext()
        let data = try DataPortabilityService.exportData(
            context: context,
            defaults: testDefaults,
            groupDefaults: testDefaults,
            includePreferences: true
        )

        // Clear entry
        testDefaults.removeObject(forKey: CityMapSelection.preferenceKey)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .urban)

        // Restore
        _ = try DataPortabilityService.importData(
            data,
            into: context,
            defaults: testDefaults,
            groupDefaults: testDefaults,
            mode: .replace,
            restorePreferences: true
        )

        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .medieval)
    }

    func testLegacyMonthlyMapSelectionsRestoresAsGlobalMapStyle() throws {
        let testDefaults = UserDefaults(suiteName: "test_legacy_maps_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        let context = makeInMemoryContext()
        let prefs = DataPortabilityService.AppPreferencesDTO(
            monthlyMapSelections: [
                "2026-07": CityMapSelection.MonthEntry(style: "medieval", confirmed: true),
                "2026-08": CityMapSelection.MonthEntry(style: "arctic", confirmed: true)
            ]
        )
        let envelope = DataPortabilityService.Envelope(
            format: DataPortabilityService.formatIdentifier,
            formatVersion: 2,
            appVersion: "1.0",
            appBuild: "47",
            exportedAt: Date(),
            transactions: [],
            recurring: [],
            income: [],
            budgets: [],
            merchantRules: [],
            installments: [],
            savingsGoals: [],
            enrichments: [],
            recaps: [],
            preferences: prefs
        )
        let data = try DataPortabilityService.makeEncoder().encode(envelope)

        _ = try DataPortabilityService.importData(
            data,
            into: context,
            defaults: testDefaults,
            groupDefaults: testDefaults,
            mode: .replace,
            restorePreferences: true
        )

        // Latest entry from legacy backup is arctic
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .arctic)
    }

    func testSavingsGoalsReconciliationNoDoubleCounting() throws {
        let context = makeInMemoryContext()

        let goalId = UUID()
        let goal = SavingsGoal(
            name: "Vacation",
            icon: "✈️",
            targetAmount: 5000.0,
            savedAmount: 1000.0,
            currency: "ILS",
            unlinkedBaseline: 1000.0,
            baselineCaptured: true
        )
        goal.id = goalId
        context.insert(goal)

        let tx = Transaction(
            amount: 500.0,
            merchant: "Flight Deposit",
            category: .savings,
            savingsGoalId: goalId
        )
        context.insert(tx)
        try context.save()

        // First reconciliation: 1000 baseline + 500 transaction = 1500
        SavingsGoalService.reconcileAll(context: context)
        XCTAssertEqual(goal.savedAmount, 1500.0)

        // Second reconciliation: should remain 1500.0, NEVER double count baseline or transaction
        SavingsGoalService.reconcileAll(context: context)
        XCTAssertEqual(goal.savedAmount, 1500.0)
    }

    func testCloudBackupStorageWorkerGenerationsAndPruning() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let worker = CloudBackupStorageWorker(customContainerURL: tempDir)

        let context = makeInMemoryContext()

        // Write 5 backups sequentially with distinct timestamps
        let baseTime = Date(timeIntervalSince1970: 1_788_000_000)
        for i in 1...5 {
            let writeTime = baseTime.addingTimeInterval(Double(i * 60))
            let data = try DataPortabilityService.exportData(context: context, now: writeTime)
            _ = try await worker.writeBackupData(data, exportedAt: writeTime)
        }

        // Must keep exactly the newest 3 generations
        let backups = try await worker.availableBackups()
        XCTAssertEqual(backups.count, 3)

        // The newest must be the 5th write
        XCTAssertEqual(backups.first?.exportedAt.timeIntervalSince1970, baseTime.addingTimeInterval(300).timeIntervalSince1970)
        // The oldest of the 3 must be the 3rd write
        XCTAssertEqual(backups.last?.exportedAt.timeIntervalSince1970, baseTime.addingTimeInterval(180).timeIntervalSince1970)
    }

    func testCleanInstallDiscoveryWithEmptyOrCorruptedContainer() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanInstallTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let worker = CloudBackupStorageWorker(customContainerURL: tempDir)

        // 1. Empty container -> no backups
        let emptyBackups = try await worker.availableBackups()
        XCTAssertTrue(emptyBackups.isEmpty)

        // 2. Corrupted file in container -> safely ignored
        let backupsDir = try await worker.resolveBackupDirectory()
        let corruptURL = backupsDir.appendingPathComponent("SPENT-backup-2026-09-20-120000.json")
        try "CORRUPTED_JSON_DATA".data(using: .utf8)!.write(to: corruptURL)

        let backupsAfterCorrupt = try await worker.availableBackups()
        XCTAssertTrue(backupsAfterCorrupt.isEmpty)

        // 3. Add valid backup -> safely discovered
        let context = makeInMemoryContext()
        let data = try DataPortabilityService.exportData(context: context)
        let validDesc = try await worker.writeBackupData(data, exportedAt: Date())

        let discovered = try await worker.availableBackups()
        XCTAssertEqual(discovered.count, 1)
        XCTAssertEqual(discovered.first?.id, validDesc.id)
    }

    func testVersionedBackupMigrationFromV1ToCurrent() throws {
        // Real V1 format in the wild
        let v1JSON = """
        {
          "format": "moneycity.backup",
          "formatVersion": 1,
          "appVersion": "1.0",
          "appBuild": "42",
          "exportedAt": "2026-08-15T12:00:00Z",
          "transactions": [
            {
              "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
              "amount": 89.90,
              "currency": "₪",
              "merchant": "Aroma",
              "category": "food",
              "timestamp": "2026-08-15T11:30:00Z",
              "confidenceScore": 1.0,
              "isManual": true,
              "isConfirmed": true
            }
          ],
          "recurring": [],
          "income": [],
          "budgets": [],
          "merchantRules": [],
          "installments": [],
          "savingsGoals": [],
          "enrichments": []
        }
        """
        let data = v1JSON.data(using: .utf8)!
        let migrated = try DataPortabilityService.validateBackupData(data)

        XCTAssertEqual(migrated.format, "moneycity.backup")
        XCTAssertEqual(migrated.formatVersion, 2)
        XCTAssertEqual(migrated.transactions.count, 1)
        XCTAssertEqual(migrated.transactions[0].merchant, "Aroma")
        XCTAssertEqual(migrated.transactions[0].amount, 89.90)
        // Must NOT invent fabricated preferences or recaps
        XCTAssertTrue(migrated.recaps.isEmpty)
        XCTAssertNil(migrated.preferences)
    }

    func testFutureBackupFormatRejectedSafely() throws {
        let futureJSON = """
        {
          "format": "moneycity.backup",
          "formatVersion": 3,
          "appVersion": "2.0",
          "appBuild": "100",
          "exportedAt": "2026-10-01T12:00:00Z",
          "transactions": []
        }
        """
        let data = futureJSON.data(using: .utf8)!
        XCTAssertThrowsError(try DataPortabilityService.validateBackupData(data)) { error in
            guard case DataPortabilityService.ImportError.futureFormat(let v) = error else {
                XCTFail("Expected futureFormat error, got: \(error)")
                return
            }
            XCTAssertEqual(v, 3)
        }
    }

    func testExistingUserUpgradeAndBootstrapFirstCloudBackupLifecycle() async throws {
        let tempCloudDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BootstrapTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempCloudDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempCloudDir) }

        let testDefaults = UserDefaults(suiteName: "test_bootstrap_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        // 1. Seed state matching pre-cloud build:
        let context = makeInMemoryContext()
        let tx = Transaction(
            amount: 120.0,
            merchant: "Supermarket",
            category: .groceries
        )
        context.insert(tx)

        let goalId = UUID()
        let goal = SavingsGoal(
            name: "Emergency Fund",
            icon: "🛡️",
            targetAmount: 5000.0,
            savedAmount: 1000.0,
            currency: "ILS",
            unlinkedBaseline: 1000.0,
            baselineCaptured: true
        )
        goal.id = goalId
        context.insert(goal)
        try context.save()

        testDefaults.set("Bini", forKey: "userName")
        testDefaults.set(4500.0, forKey: "monthly_budget")
        testDefaults.set(true, forKey: "hasCompletedOnboarding")
        let activeDays = ["2026-09-18", "2026-09-19", "2026-09-20"]
        TrackingActivityService(defaults: testDefaults).setActiveDays(activeDays)
        CityMapSelection.save(.urban, defaults: testDefaults)

        // Verify pre-cloud state: NO cloud backup exists anywhere
        let worker = CloudBackupStorageWorker(customContainerURL: tempCloudDir)
        let preCloudBackups = try await worker.availableBackups()
        XCTAssertTrue(preCloudBackups.isEmpty)
        XCTAssertNil(testDefaults.object(forKey: CloudBackupService.lastBackupDateKey))

        // 2. User updates to new version with CloudBackupService:
        let service = CloudBackupService(defaults: testDefaults, groupDefaults: testDefaults, worker: worker)

        // 3. System runs bootstrapFirstBackupIfNeeded:
        await service.bootstrapFirstBackupIfNeeded(context: context)

        // 4. Verify bootstrap succeeded:
        let postBootstrapBackups = try await worker.availableBackups()
        XCTAssertEqual(postBootstrapBackups.count, 1)
        let firstBackup = postBootstrapBackups.first!
        XCTAssertTrue(firstBackup.id.hasPrefix("SPENT-backup-"))
        XCTAssertNotNil(service.lastBackupDate)
        XCTAssertNotNil(testDefaults.object(forKey: CloudBackupService.lastBackupDateKey))

        // 5. Verify local data was NOT touched:
        let currentTxs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(currentTxs.count, 1)
        XCTAssertEqual(currentTxs[0].merchant, "Supermarket")
        XCTAssertEqual(testDefaults.string(forKey: "userName"), "Bini")

        // 6. SIMULATE APP DELETION:
        // Wipe in-memory context and clear all defaults
        for t in currentTxs { context.delete(t) }
        let currentGoals = try context.fetch(FetchDescriptor<SavingsGoal>())
        for g in currentGoals { context.delete(g) }
        try context.save()

        testDefaults.removeObject(forKey: "userName")
        testDefaults.removeObject(forKey: "monthly_budget")
        testDefaults.removeObject(forKey: "hasCompletedOnboarding")
        testDefaults.removeObject(forKey: "spent_tracking_active_days")
        testDefaults.removeObject(forKey: CityMapSelection.preferenceKey)
        testDefaults.removeObject(forKey: CloudBackupService.lastBackupDateKey)

        // 7. SIMULATE REINSTALL:
        // A fresh service instance against the same iCloud container
        let freshInstallService = CloudBackupService(defaults: testDefaults, groupDefaults: testDefaults, worker: worker)
        let cleanInstallBackup = await freshInstallService.discoverCleanInstallBackup()
        XCTAssertNotNil(cleanInstallBackup)
        XCTAssertEqual(cleanInstallBackup?.id, firstBackup.id)

        // 8. Restore from that cloud backup:
        let restoreSummary = try await freshInstallService.restoreLatestBackup(context: context)
        XCTAssertGreaterThan(restoreSummary.added, 0)

        // 9. Verify complete state is 100% recovered:
        let recoveredTxs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(recoveredTxs.count, 1)
        XCTAssertEqual(recoveredTxs[0].merchant, "Supermarket")

        let recoveredGoals = try context.fetch(FetchDescriptor<SavingsGoal>())
        XCTAssertEqual(recoveredGoals.count, 1)
        XCTAssertEqual(recoveredGoals[0].name, "Emergency Fund")
        XCTAssertEqual(recoveredGoals[0].savedAmount, 1000.0)

        XCTAssertEqual(testDefaults.string(forKey: "userName"), "Bini")
        XCTAssertEqual(testDefaults.double(forKey: "monthly_budget"), 4500.0)
        XCTAssertEqual(testDefaults.bool(forKey: "hasCompletedOnboarding"), true)
        XCTAssertEqual(TrackingActivityService(defaults: testDefaults).activeDays(), activeDays)
        XCTAssertEqual(CityMapSelection.currentStyle(defaults: testDefaults), .urban)
    }

    func testHasMeaningfulLocalStateEvaluatesWithOrLogic() throws {
        let context = makeInMemoryContext()
        let testDefaults = UserDefaults(suiteName: "test_or_logic_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        // Completely clean state
        XCTAssertFalse(CloudBackupService.hasMeaningfulLocalState(context: context, defaults: testDefaults, groupDefaults: testDefaults))

        // Scenario 1: ONLY onboarding is completed, 0 transactions, 0 goals, 0 budget
        testDefaults.set(true, forKey: "hasCompletedOnboarding")
        XCTAssertTrue(CloudBackupService.hasMeaningfulLocalState(context: context, defaults: testDefaults, groupDefaults: testDefaults))
        testDefaults.removeObject(forKey: "hasCompletedOnboarding")

        // Scenario 2: ONLY username is set
        testDefaults.set("Sarah", forKey: "userName")
        XCTAssertTrue(CloudBackupService.hasMeaningfulLocalState(context: context, defaults: testDefaults, groupDefaults: testDefaults))
        testDefaults.removeObject(forKey: "userName")

        // Scenario 3: ONLY monthly budget is set
        testDefaults.set(3000.0, forKey: "monthly_budget")
        XCTAssertTrue(CloudBackupService.hasMeaningfulLocalState(context: context, defaults: testDefaults, groupDefaults: testDefaults))
        testDefaults.removeObject(forKey: "monthly_budget")

        // Scenario 4: ONLY tracking active days (streak) exist
        testDefaults.set(["2026-09-20"], forKey: "spent_tracking_active_days")
        XCTAssertTrue(CloudBackupService.hasMeaningfulLocalState(context: context, defaults: testDefaults, groupDefaults: testDefaults))
        testDefaults.removeObject(forKey: "spent_tracking_active_days")

        // Scenario 5: ONLY map selection exists
        CityMapSelection.save(.israel, defaults: testDefaults)
        XCTAssertTrue(CloudBackupService.hasMeaningfulLocalState(context: context, defaults: testDefaults, groupDefaults: testDefaults))
        testDefaults.removeObject(forKey: CityMapSelection.preferenceKey)

        // Scenario 6: ONLY a savings goal exists in database (0 transactions)
        let goal = SavingsGoal(name: "Trip", icon: "✈️", targetAmount: 2000.0, savedAmount: 500.0)
        context.insert(goal)
        try context.save()
        XCTAssertTrue(CloudBackupService.hasMeaningfulLocalState(context: context, defaults: testDefaults, groupDefaults: testDefaults))
        context.delete(goal)
        try context.save()

        // Scenario 7: ONLY a recap snapshot exists in database
        let recap = RecapSnapshot(monthId: "2026-08", payloadJSON: "{}", frozenAt: Date())
        context.insert(recap)
        try context.save()
        XCTAssertTrue(CloudBackupService.hasMeaningfulLocalState(context: context, defaults: testDefaults, groupDefaults: testDefaults))
        context.delete(recap)
        try context.save()

        // Back to clean state
        XCTAssertFalse(CloudBackupService.hasMeaningfulLocalState(context: context, defaults: testDefaults, groupDefaults: testDefaults))
    }

    func testStartFreshDoesNotDeleteOrCorruptCloudBackups() async throws {
        let tempCloudDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StartFreshTest_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempCloudDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempCloudDir) }

        let testDefaults = UserDefaults(suiteName: "test_start_fresh_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        // Seed a cloud backup in worker
        let worker = CloudBackupStorageWorker(customContainerURL: tempCloudDir)
        let envelope = DataPortabilityService.EnvelopeV2(
            format: "moneycity.backup",
            formatVersion: 2,
            appVersion: "2.0",
            appBuild: "1",
            exportedAt: Date(),
            transactions: [],
            recurring: [],
            income: [],
            budgets: [],
            merchantRules: [],
            installments: [],
            savingsGoals: [DataPortabilityService.SavingsGoalDTO(
                id: UUID(), name: "Dream Car", icon: "🏎️",
                targetAmount: 50000.0, savedAmount: 10000.0, currency: "ILS",
                targetDate: nil, createdAt: Date(), completedAt: nil,
                unlinkedBaseline: 10000.0, baselineCaptured: true
            )],
            enrichments: [],
            recaps: [],
            preferences: nil
        )
        let data = try DataPortabilityService.makeEncoder().encode(envelope)
        let descriptor = try await worker.writeBackupData(data)

        // Verify cloud backup exists
        var available = try await worker.availableBackups()
        XCTAssertEqual(available.count, 1)
        XCTAssertEqual(available.first?.id, descriptor.id)

        // Simulating "Start Fresh": user chooses to start onboarding fresh instead of restoring
        testDefaults.set(true, forKey: "hasStartedOnboardingV2")

        // Assert: iCloud backups are completely intact!
        available = try await worker.availableBackups()
        XCTAssertEqual(available.count, 1)
        XCTAssertEqual(available.first?.id, descriptor.id)

        // Assert: It can still be discovered and restored manually later
        let freshService = CloudBackupService(defaults: testDefaults, groupDefaults: testDefaults, worker: worker)
        let discovered = await freshService.discoverCleanInstallBackup()
        XCTAssertNotNil(discovered)
        XCTAssertEqual(discovered?.id, descriptor.id)
    }

    func testPostRestoreRefreshUpdatesLocalizationAndPreferences() throws {
        let context = makeInMemoryContext()
        let testDefaults = UserDefaults(suiteName: "test_refresh_\(UUID().uuidString)")!
        defer { testDefaults.removePersistentDomain(forName: testDefaults.description) }

        var prefs = DataPortabilityService.AppPreferencesDTO()
        prefs.appLanguage = "en"
        prefs.appCurrency = "USD"
        prefs.userName = "Alice"
        prefs.monthlyBudget = 7500.0

        let envelope = DataPortabilityService.EnvelopeV2(
            format: "moneycity.backup",
            formatVersion: 2,
            appVersion: "2.0",
            appBuild: "1",
            exportedAt: Date(),
            transactions: [],
            recurring: [],
            income: [],
            budgets: [],
            merchantRules: [],
            installments: [],
            savingsGoals: [],
            enrichments: [],
            recaps: [],
            preferences: prefs
        )
        let data = try DataPortabilityService.makeEncoder().encode(envelope)

        // Import into context and restore preferences
        let summary = try DataPortabilityService.importData(
            data,
            into: context,
            defaults: testDefaults,
            groupDefaults: testDefaults,
            mode: .replace,
            restorePreferences: true
        )
        XCTAssertEqual(summary.added, 0)
        XCTAssertEqual(testDefaults.string(forKey: "app_language_pref"), "en")
        XCTAssertEqual(testDefaults.string(forKey: "app_currency_pref"), "USD")
        XCTAssertEqual(testDefaults.string(forKey: "userName"), "Alice")
        XCTAssertEqual(testDefaults.double(forKey: "monthly_budget"), 7500.0)
    }
}

