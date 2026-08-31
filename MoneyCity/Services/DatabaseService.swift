import Foundation
import SwiftData

/// Centralized, production-grade database coordinator for SwiftData & SQLite storage.
@MainActor
public final class DatabaseService {
    public static let shared = DatabaseService()
    
    public let container: ModelContainer
    public var context: ModelContext {
        container.mainContext
    }
    
    private init() {
        let schema = Schema([
            Transaction.self,
            CityEnrichment.self,
            RecurringExpense.self,
            IncomeSource.self,
            CategoryBudget.self,
            MerchantRule.self,
            InstallmentPlan.self,
            SavingsGoal.self,
            IngestLogEntry.self
        ])
        
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ SwiftData on-disk container failed to initialize: \(error). Falling back to in-memory store.")
            do {
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.container = try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Critical: Failed to initialize SwiftData ModelContainer: \(error)")
            }
        }
    }
    
    // MARK: - Transaction CRUD
    
    public func save(transaction: Transaction) async throws {
        context.insert(transaction)
        try context.save()
    }
    
    public func save(transactions: [Transaction]) async throws {
        for t in transactions {
            context.insert(t)
        }
        try context.save()
    }
    
    public func delete(transaction: Transaction) async throws {
        context.delete(transaction)
        try context.save()
    }
    
    public func delete(transactions: [Transaction]) async throws {
        for t in transactions {
            context.delete(t)
        }
        try context.save()
    }
    
    public func deleteAllTransactions() async throws {
        let all = fetchAllTransactions()
        try await delete(transactions: all)
    }
    
    // MARK: - Queries
    
    public func fetchAllTransactions() -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching all transactions: \(error)")
            return []
        }
    }
    
    public func fetchTransactions(for month: Date = Date()) -> [Transaction] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= startOfMonth && $0.timestamp < nextMonth },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching month transactions: \(error)")
            return []
        }
    }
    
    public func fetchTransactions(for category: SpendingCategory, in month: Date = Date()) -> [Transaction] {
        let raw = category.rawValue
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= startOfMonth && $0.timestamp < nextMonth && $0.categoryRawValue == raw },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching category transactions: \(error)")
            return []
        }
    }
    
    public func fetchYearlyTransactions(for year: Int = Calendar.current.component(.year, from: Date())) -> [Transaction] {
        let calendar = Calendar.current
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let nextYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return []
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= startOfYear && $0.timestamp < nextYear },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching yearly transactions: \(error)")
            return []
        }
    }
    
    /// Recent rows only — used by the Wallet ingest path to detect a retried payment
    /// without loading the entire history.
    public func fetchRecentTransactions(within seconds: TimeInterval, of date: Date = Date()) -> [Transaction] {
        let lowerBound = date.addingTimeInterval(-seconds)
        let upperBound = date.addingTimeInterval(seconds)
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.timestamp >= lowerBound && $0.timestamp <= upperBound },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching recent transactions: \(error)")
            return []
        }
    }

    // MARK: - Ingest diagnostics

    /// Stores a raw-payload record immediately, so evidence survives even if the rest of
    /// the intent throws.
    public func record(_ entry: IngestLogEntry) {
        context.insert(entry)
        try? context.save()
        pruneIngestLog()
    }

    /// Saves changes made to an already-inserted object.
    public func persist() {
        try? context.save()
    }

    public func fetchIngestLog(limit: Int = 50) -> [IngestLogEntry] {
        var descriptor = FetchDescriptor<IngestLogEntry>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    public func clearIngestLog() {
        let all = (try? context.fetch(FetchDescriptor<IngestLogEntry>())) ?? []
        for entry in all { context.delete(entry) }
        try? context.save()
    }

    /// This is a diagnostic trail, not history — keep it small.
    private func pruneIngestLog() {
        let descriptor = FetchDescriptor<IngestLogEntry>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor), all.count > 100 else { return }
        for entry in all.dropFirst(100) { context.delete(entry) }
        try? context.save()
    }

    // MARK: - Aggregations
    
    public func fetchCategoryTotals(for month: Date = Date()) -> [SpendingCategory: Double] {
        let txs = fetchTransactions(for: month)
        var totals: [SpendingCategory: Double] = [:]
        for cat in SpendingCategory.allCases {
            totals[cat] = 0.0
        }
        for t in txs {
            totals[t.category, default: 0.0] += t.amount
        }
        return totals
    }
    
    public func fetchBuildingTotals(for month: Date = Date()) -> [String: Double] {
        let txs = fetchTransactions(for: month)
        var totals: [String: Double] = [
            "food_bistro": 0.0,
            "food_super": 0.0,
            "food_coffee": 0.0,
            "food_wolt": 0.0,
            "shop_boutique": 0.0,
            "shop_tech": 0.0,
            "shop_travel": 0.0,
            "shop_arcade": 0.0,
            "trans_station": 0.0,
            "house_tower": 0.0,
            "house_util": 0.0,
            "house_subs": 0.0,
            "savings_sanctuary": 0.0
        ]
        
        for t in txs {
            let bId = t.buildingId
            totals[bId, default: 0.0] += t.amount
        }
        return totals
    }
    
    // MARK: - Sample Data & Reset
    
    public static var sampleTransactions: [Transaction] {
        [
            Transaction(amount: 650.0, merchant: "שופרסל מרקט", category: .food, buildingId: "food_super"),
            Transaction(amount: 520.0, merchant: "מסעדת גוז׳ ודניאל", category: .food, buildingId: "food_bistro"),
            Transaction(amount: 180.0, merchant: "ארומה אספרסו בר", category: .food, buildingId: "food_coffee"),
            Transaction(amount: 130.0, merchant: "משלוח Wolt", category: .food, buildingId: "food_wolt"),
            Transaction(amount: 820.0, merchant: "זארה בגדים ונעליים", category: .shopping, buildingId: "shop_boutique"),
            Transaction(amount: 450.0, merchant: "KSP אלקטרוניקה וחשמל", category: .shopping, buildingId: "shop_tech"),
            Transaction(amount: 150.0, merchant: "סינמה סיטי קולנוע", category: .shopping, buildingId: "shop_arcade"),
            Transaction(amount: 320.0, merchant: "פז דלק ותדלוק", category: .transport),
            Transaction(amount: 1850.0, merchant: "שכירות דירה חודשית", category: .housing, buildingId: "house_tower"),
            Transaction(amount: 380.0, merchant: "חברת חשמל וארנונה", category: .housing, buildingId: "house_util"),
            Transaction(amount: 140.0, merchant: "נטפליקס וספוטיפיי", category: .housing, buildingId: "house_subs"),
            Transaction(amount: 1800.0, merchant: "הפקדה לחיסכון והשקעות", category: .savings, buildingId: "savings_sanctuary")
        ]
    }
    
    public func seedSampleData() async throws {
        try await deleteAllTransactions()
        try await save(transactions: Self.sampleTransactions)
    }
    
    public func resetAllData() async throws {
        try await deleteAllTransactions()

        // Fixed-expense templates are configuration, not data, so they survive a reset —
        // but their bookkeeping is rewound so a reset does not back-fill a year of rent.
        let recurringDescriptor = FetchDescriptor<RecurringExpense>()
        if let templates = try? context.fetch(recurringDescriptor) {
            for t in templates {
                t.lastGeneratedPeriod = nil
                t.createdAt = Date()
            }
        }
        
        let enrichDescriptor = FetchDescriptor<CityEnrichment>()
        if let enrichments = try? context.fetch(enrichDescriptor) {
            for e in enrichments {
                context.delete(e)
            }
            try context.save()
        }
    }

    // MARK: - Learned Merchant Rules
    
    public func rememberCorrection(merchant: String, category: SpendingCategory) {
        let existing = fetchMerchantRules()
        if let rule = MerchantRuleService.ruleAfterCorrection(merchant: merchant, category: category, existing: existing) {
            context.insert(rule)
        }
        try? context.save()
    }
    
    public func fetchMerchantRules() -> [MerchantRule] {
        let descriptor = FetchDescriptor<MerchantRule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching merchant rules: \(error)")
            return []
        }
    }
}
