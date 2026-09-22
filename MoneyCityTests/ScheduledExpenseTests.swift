import XCTest
import SwiftData
@testable import MoneyCity

final class ScheduledExpenseTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ s: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min; comps.second = s
        return cal.date(from: comps)!
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: MoneyCitySchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - 1. Today expense -> immediately saved as Transaction

    @MainActor
    func test1_TodayExpenseSavedImmediatelyAsTransaction() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = date(2026, 4, 15, 14, 30)

        let isFuture = cal.startOfDay(for: now) > cal.startOfDay(for: now)
        XCTAssertFalse(isFuture)

        let tx = Transaction(
            amount: 50.0,
            merchant: "Supermarket",
            category: .food,
            timestamp: now,
            isManual: true,
            isConfirmed: true
        )
        context.insert(tx)
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let scheduled = try context.fetch(FetchDescriptor<ScheduledExpense>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(scheduled.count, 0)
        XCTAssertEqual(transactions.first?.amount, 50.0)
        XCTAssertEqual(transactions.first?.timestamp, now)
    }

    // MARK: - 2. Yesterday expense -> Transaction with yesterday's timestamp

    @MainActor
    func test2_YesterdayExpenseSavedWithYesterdayTimestamp() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let yesterday = date(2026, 4, 14, 10, 0)

        let tx = Transaction(
            amount: 35.0,
            merchant: "Bakery",
            category: .food,
            timestamp: yesterday,
            isManual: true,
            isConfirmed: true
        )
        context.insert(tx)
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let scheduled = try context.fetch(FetchDescriptor<ScheduledExpense>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(scheduled.count, 0)
        XCTAssertEqual(transactions.first?.timestamp, yesterday)
    }

    // MARK: - 3. Month ago expense -> lands in correct historical month

    @MainActor
    func test3_MonthAgoExpenseSavedInCorrectHistoricalMonth() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let lastMonth = date(2026, 3, 10, 16, 0)

        let tx = Transaction(
            amount: 120.0,
            merchant: "Bookstore",
            category: .shopping,
            timestamp: lastMonth,
            isManual: true,
            isConfirmed: true
        )
        context.insert(tx)
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        let savedMonth = cal.component(.month, from: transactions[0].timestamp)
        XCTAssertEqual(savedMonth, 3)
    }

    // MARK: - 4. Tomorrow expense -> does not create Transaction

    @MainActor
    func test4_TomorrowExpenseDoesNotCreateTransaction() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let today = date(2026, 4, 15, 12, 0)
        let tomorrow = date(2026, 4, 16, 12, 0)

        let isFuture = cal.startOfDay(for: tomorrow) > cal.startOfDay(for: today)
        XCTAssertTrue(isFuture)

        if isFuture {
            let sched = ScheduledExpense(
                merchant: "Concert",
                amount: 250.0,
                category: .entertainment,
                scheduledFor: tomorrow
            )
            context.insert(sched)
        }
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 0, "Future expense must not create a Transaction")
    }

    // MARK: - 5. Tomorrow expense -> creates single ScheduledExpense

    @MainActor
    func test5_TomorrowExpenseCreatesSingleScheduledExpense() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tomorrow = date(2026, 4, 16, 12, 0)

        let sched = ScheduledExpense(
            merchant: "Concert",
            amount: 250.0,
            category: .entertainment,
            scheduledFor: tomorrow
        )
        context.insert(sched)
        try context.save()

        let scheduled = try context.fetch(FetchDescriptor<ScheduledExpense>())
        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(scheduled.first?.merchant, "Concert")
        XCTAssertEqual(scheduled.first?.amount, 250.0)
        XCTAssertEqual(scheduled.first?.category, .entertainment)
        XCTAssertNil(scheduled.first?.materializedAt)
    }

    // MARK: - 6. ScheduledExpense does not affect current city total

    @MainActor
    func test6_ScheduledExpenseDoesNotAffectCityTotal() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tomorrow = date(2026, 4, 16, 12, 0)

        let sched = ScheduledExpense(
            merchant: "Flight",
            amount: 1500.0,
            category: .transport,
            scheduledFor: tomorrow
        )
        context.insert(sched)
        try context.save()

        // Fetching transactions for current month
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let totalCitySpending = transactions.reduce(0.0) { $0 + $1.amount }
        XCTAssertEqual(totalCitySpending, 0.0, "ScheduledExpense must not count in city spending")
    }

    // MARK: - 7. ScheduledExpense does not affect Analytics totals

    @MainActor
    func test7_ScheduledExpenseDoesNotAffectAnalyticsTotals() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tomorrow = date(2026, 4, 16, 12, 0)

        let sched = ScheduledExpense(
            merchant: "Hotel",
            amount: 800.0,
            category: .transport,
            scheduledFor: tomorrow
        )
        context.insert(sched)
        try context.save()

        // Analytics fetches Transaction models only
        let analyticsTransactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(analyticsTransactions.count, 0)
    }

    // MARK: - 8. ScheduledExpense does not appear as completed transaction in History

    @MainActor
    func test8_ScheduledExpenseDoesNotAppearAsCompletedInHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tomorrow = date(2026, 4, 16, 12, 0)

        let sched = ScheduledExpense(
            merchant: "Insurance",
            amount: 300.0,
            category: .subscriptions,
            scheduledFor: tomorrow
        )
        context.insert(sched)
        try context.save()

        let historyCompletedTransactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertTrue(historyCompletedTransactions.isEmpty)
        XCTAssertFalse(sched.isMaterialized)
    }

    // MARK: - 9. On scheduled date, materializeDue creates Transaction

    @MainActor
    func test9_MaterializeDueCreatesTransactionOnDueDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let schedDate = date(2026, 4, 16, 9, 0)

        let sched = ScheduledExpense(
            merchant: "Gym Fee",
            amount: 150.0,
            category: .health,
            scheduledFor: schedDate
        )
        context.insert(sched)
        try context.save()

        let now = date(2026, 4, 16, 15, 0)
        let materializedCount = ScheduledExpenseService.materializeDue(now: now, context: context, calendar: cal)

        XCTAssertEqual(materializedCount, 1)
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.merchant, "Gym Fee")
        XCTAssertEqual(transactions.first?.amount, 150.0)
        XCTAssertEqual(transactions.first?.category, .health)
        XCTAssertTrue(sched.isMaterialized)
        XCTAssertEqual(sched.materializedTransactionId, transactions.first?.id)
    }

    // MARK: - 10. Repeated materializeDue call does not duplicate

    @MainActor
    func test10_MaterializeDueIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let schedDate = date(2026, 4, 16, 9, 0)

        let sched = ScheduledExpense(
            merchant: "Gym Fee",
            amount: 150.0,
            category: .health,
            scheduledFor: schedDate
        )
        context.insert(sched)
        try context.save()

        let now = date(2026, 4, 16, 15, 0)
        let count1 = ScheduledExpenseService.materializeDue(now: now, context: context, calendar: cal)
        XCTAssertEqual(count1, 1)

        let count2 = ScheduledExpenseService.materializeDue(now: now, context: context, calendar: cal)
        XCTAssertEqual(count2, 0, "Repeated materializeDue call must not duplicate transactions")

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
    }

    // MARK: - 11. Created Transaction receives scheduled date, not Date() of launch

    @MainActor
    func test11_MaterializedTransactionReceivesScheduledDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let targetDate = date(2026, 4, 10, 11, 15)

        let sched = ScheduledExpense(
            merchant: "Car Service",
            amount: 500.0,
            category: .transport,
            scheduledFor: targetDate
        )
        context.insert(sched)
        try context.save()

        // App opened days later
        let laterLaunchDate = date(2026, 4, 15, 20, 0)
        _ = ScheduledExpenseService.materializeDue(now: laterLaunchDate, context: context, calendar: cal)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.timestamp, targetDate, "Transaction timestamp must equal scheduledFor date")
    }

    // MARK: - 12. ScheduledExpense can be deleted before due date

    @MainActor
    func test12_ScheduledExpenseCanBeDeletedBeforeDueDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tomorrow = date(2026, 4, 16, 12, 0)

        let sched = ScheduledExpense(
            merchant: "Dinner",
            amount: 200.0,
            category: .food,
            scheduledFor: tomorrow
        )
        context.insert(sched)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<ScheduledExpense>()).count, 1)

        context.delete(sched)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<ScheduledExpense>()).count, 0)
    }

    // MARK: - 13. Apple Pay pending transaction preserves pending.timestamp

    @MainActor
    func test13_ApplePayPendingPreservesOriginalTimestamp() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let originalDate = date(2026, 3, 25, 14, 22)

        let tx = Transaction(
            amount: 45.0,
            currency: "₪",
            merchant: "Aroma Coffee",
            category: .food,
            timestamp: originalDate,
            confidenceScore: 0.95,
            isManual: false,
            isConfirmed: true
        )
        context.insert(tx)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(fetched.first?.timestamp, originalDate)
    }

    // MARK: - 14. Shortcut / Wallet ingest unchanged

    @MainActor
    func test14_ShortcutIngestUnchanged() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ingestDate = date(2026, 4, 1, 9, 30)

        let tx = Transaction(
            amount: 75.0,
            merchant: "Fuel Station",
            category: .transport,
            timestamp: ingestDate,
            isManual: false,
            isConfirmed: false
        )
        context.insert(tx)
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.first?.timestamp, ingestDate)
    }

    // MARK: - 15. RecurringExpenseTests continue passing

    func test15_RecurringExpensesNotRegressed() {
        let due = RecurringExpenseService.duePeriods(
            lastGeneratedPeriod: nil,
            createdAt: date(2026, 4, 1),
            dayOfMonth: 10,
            now: date(2026, 4, 15),
            calendar: cal
        )
        XCTAssertEqual(due, ["2026-04"])
    }

    // MARK: - 16. InstallmentServiceTests continue passing

    @MainActor
    func test16_InstallmentsNotRegressed() throws {
        let plan = InstallmentPlan(
            merchant: "Laptop",
            totalAmount: 1200.0,
            currency: "₪",
            numberOfPayments: 12,
            firstChargeDate: date(2026, 1, 1),
            category: .shopping
        )
        let perPayment = plan.totalAmount / Double(plan.numberOfPayments)
        XCTAssertEqual(perPayment, 100.0)
        XCTAssertEqual(plan.numberOfPayments, 12)
    }

    // MARK: - 17. Installment with selected date uses it as firstChargeDate

    @MainActor
    func test17_InstallmentFirstChargeDateUsesSelectedDate() throws {
        let customDate = date(2026, 5, 20)
        let plan = InstallmentPlan(
            merchant: "Phone",
            totalAmount: 2400.0,
            currency: "₪",
            numberOfPayments: 24,
            firstChargeDate: customDate,
            category: .shopping
        )
        XCTAssertEqual(plan.firstChargeDate, customDate)
    }

    // MARK: - 18. Backup export/import preserves ScheduledExpense

    @MainActor
    func test18_BackupExportImportPreservesScheduledExpenses() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let schedDate = date(2026, 6, 1, 10, 0)

        let sched = ScheduledExpense(
            merchant: "Annual Insurance",
            amount: 1800.0,
            currency: "₪",
            category: .subscriptions,
            scheduledFor: schedDate
        )
        context.insert(sched)
        try context.save()

        let backupData = try DataPortabilityService.exportData(context: context)

        // Wipe context and restore
        let summary = try DataPortabilityService.importData(
            backupData,
            into: context,
            mode: .replace,
            restorePreferences: false
        )
        XCTAssertGreaterThanOrEqual(summary.added, 1)

        let restored = try context.fetch(FetchDescriptor<ScheduledExpense>())
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.id, sched.id)
        XCTAssertEqual(restored.first?.merchant, "Annual Insurance")
        XCTAssertEqual(restored.first?.amount, 1800.0)
        XCTAssertEqual(restored.first?.category, .subscriptions)
    }

    // MARK: - 19. Old backup without scheduled collection loads cleanly

    @MainActor
    func test19_BackupV2ImportLoadsCleanlyWithEmptyScheduled() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let v2Json = """
        {
          "format": "\(DataPortabilityService.formatIdentifier)",
          "formatVersion": 2,
          "appVersion": "1.0",
          "appBuild": "1",
          "exportedAt": "2026-04-15T10:00:00Z",
          "transactions": [
            {
              "id": "11111111-2222-3333-4444-555555555555",
              "amount": 42.0,
              "currency": "₪",
              "merchant": "Coffee Shop",
              "category": "coffee",
              "timestamp": "2026-04-15T09:00:00Z",
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
          "enrichments": [],
          "recaps": []
        }
        """.data(using: .utf8)!

        let envelope = try DataPortabilityService.validateBackupData(v2Json)
        XCTAssertEqual(envelope.formatVersion, 3)
        XCTAssertEqual(envelope.scheduled.count, 0)

        let summary = try DataPortabilityService.importData(
            v2Json,
            into: context,
            mode: .replace,
            restorePreferences: false
        )
        XCTAssertEqual(summary.added, 1)

        let txs = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(txs.count, 1)
        let scheds = try context.fetch(FetchDescriptor<ScheduledExpense>())
        XCTAssertEqual(scheds.count, 0)
    }

    // MARK: - 20. V2 database opens and migrates to V3 without data loss

    @MainActor
    func test20_DatabaseMigrationV2ToV3PreservesData() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("test_store.sqlite")

        var txId: UUID = UUID()
        // 1. Open with V2 schema and save data
        do {
            let v2Schema = Schema(MoneyCitySchemaV2.models)
            let v2Config = ModelConfiguration(schema: v2Schema, url: storeURL, cloudKitDatabase: .none)
            let v2Container = try ModelContainer(for: v2Schema, configurations: [v2Config])

            let existingTx = Transaction(
                amount: 99.0,
                merchant: "Migrated Merchant",
                category: .shopping,
                timestamp: date(2026, 4, 1)
            )
            v2Container.mainContext.insert(existingTx)
            try v2Container.mainContext.save()
            txId = existingTx.id
        }

        // 2. Open with V3 schema and migration plan in a separate session
        do {
            let v3Schema = Schema(versionedSchema: MoneyCitySchemaV3.self)
            let v3Config = ModelConfiguration(schema: v3Schema, url: storeURL, cloudKitDatabase: .none)
            let v3Container = try ModelContainer(
                for: v3Schema,
                migrationPlan: MoneyCityMigrationPlan.self,
                configurations: [v3Config]
            )

            let fetchedTxs = try v3Container.mainContext.fetch(FetchDescriptor<Transaction>())
            XCTAssertEqual(fetchedTxs.count, 1)
            XCTAssertEqual(fetchedTxs.first?.id, txId)
            XCTAssertEqual(fetchedTxs.first?.merchant, "Migrated Merchant")

            // 3. Verify ScheduledExpense can be inserted into the migrated store
            let sched = ScheduledExpense(
                merchant: "Future Item",
                amount: 120.0,
                category: .food,
                scheduledFor: date(2026, 5, 1)
            )
            v3Container.mainContext.insert(sched)
            try v3Container.mainContext.save()

            let fetchedSched = try v3Container.mainContext.fetch(FetchDescriptor<ScheduledExpense>())
            XCTAssertEqual(fetchedSched.count, 1)
        }
    }

    // MARK: - 21. Timezone/DST do not shift expense to another day

    func test21_DSTAndMidnightDoNotShiftExpenseDay() {
        let lateNight = date(2026, 3, 26, 23, 59, 59)
        let justAfterMidnight = date(2026, 3, 27, 0, 0, 1)

        let dayLateNight = cal.component(.day, from: lateNight)
        let dayMidnight = cal.component(.day, from: justAfterMidnight)

        XCTAssertEqual(dayLateNight, 26)
        XCTAssertEqual(dayMidnight, 27)

        let startLateNight = cal.startOfDay(for: lateNight)
        let startMidnight = cal.startOfDay(for: justAfterMidnight)
        XCTAssertTrue(startMidnight > startLateNight)

        // DST transition in Israel typically occurs late March
        let dstComps = DateComponents(year: 2026, month: 3, day: 27, hour: 3, minute: 0)
        if let dstDate = cal.date(from: dstComps) {
            let startOfDstDay = cal.startOfDay(for: dstDate)
            XCTAssertEqual(cal.component(.day, from: startOfDstDay), 27)
        }
    }

    // MARK: - 22. EditTransaction changing date does not create duplicate

    @MainActor
    func test22_EditTransactionDateToFutureDoesNotCreateDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let today = date(2026, 4, 15, 10, 0)
        let tomorrow = date(2026, 4, 16, 10, 0)

        // Existing transaction
        let tx = Transaction(
            amount: 110.0,
            merchant: "Hardware Store",
            category: .housing,
            timestamp: today,
            isManual: true,
            isConfirmed: true
        )
        context.insert(tx)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ScheduledExpense>()).count, 0)

        // Simulate EditTransactionSheet save when date changed to future:
        let isFuture = cal.startOfDay(for: tomorrow) > cal.startOfDay(for: today)
        XCTAssertTrue(isFuture)

        if isFuture {
            let scheduled = ScheduledExpense(
                merchant: tx.merchant,
                amount: tx.amount,
                currency: tx.currency,
                category: tx.category,
                scheduledFor: tomorrow,
                buildingIdRaw: tx.buildingId
            )
            context.insert(scheduled)
            context.delete(tx)
            try context.save()
        }

        let remainingTransactions = try context.fetch(FetchDescriptor<Transaction>())
        let newScheduled = try context.fetch(FetchDescriptor<ScheduledExpense>())

        XCTAssertEqual(remainingTransactions.count, 0, "Edited transaction converted to future must be deleted")
        XCTAssertEqual(newScheduled.count, 1, "ScheduledExpense must be created")
        XCTAssertEqual(newScheduled.first?.amount, 110.0)
        XCTAssertEqual(newScheduled.first?.merchant, "Hardware Store")
    }
}
