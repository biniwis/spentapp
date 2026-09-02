import Foundation
import SwiftData

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
    public static let formatVersion = 1
    public static let formatIdentifier = "moneycity.backup"

    // MARK: - The file

    public struct Envelope: Codable {
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

        public var totalRecords: Int {
            transactions.count + recurring.count + income.count + budgets.count
                + merchantRules.count + installments.count + savingsGoals.count + enrichments.count
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

    // MARK: - Export

    @MainActor
    public static func buildEnvelope(context: ModelContext, now: Date = Date()) -> Envelope {
        func all<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }

        return Envelope(
            format: formatIdentifier,
            formatVersion: formatVersion,
            appVersion: StoreSnapshotService.currentVersion(),
            appBuild: StoreSnapshotService.currentBuild(),
            exportedAt: now,
            transactions: all(Transaction.self).map {
                TransactionDTO(
                    id: $0.id, amount: $0.amount, currency: $0.currency, merchant: $0.merchant,
                    category: $0.categoryRawValue, timestamp: $0.timestamp,
                    confidenceScore: $0.confidenceScore, isManual: $0.isManual,
                    isConfirmed: $0.isConfirmed, note: $0.note, buildingId: $0.buildingIdRaw,
                    originalAmount: $0.originalAmount, originalCurrency: $0.originalCurrency,
                    exchangeRate: $0.exchangeRate, savingsGoalId: $0.savingsGoalId
                )
            },
            recurring: all(RecurringExpense.self).map {
                RecurringDTO(
                    id: $0.id, merchant: $0.merchant, amount: $0.amount, currency: $0.currency,
                    category: $0.categoryRawValue, dayOfMonth: $0.dayOfMonth,
                    isActive: $0.isActive, lastGeneratedPeriod: $0.lastGeneratedPeriod,
                    createdAt: $0.createdAt
                )
            },
            income: all(IncomeSource.self).map {
                IncomeDTO(
                    id: $0.id, name: $0.name, amount: $0.amount, currency: $0.currency,
                    dayOfMonth: $0.dayOfMonth, isActive: $0.isActive, createdAt: $0.createdAt
                )
            },
            budgets: all(CategoryBudget.self).map {
                BudgetDTO(
                    id: $0.id, category: $0.categoryRawValue,
                    monthlyLimit: $0.monthlyLimit, createdAt: $0.createdAt
                )
            },
            merchantRules: all(MerchantRule.self).map {
                MerchantRuleDTO(
                    id: $0.id, merchantKey: $0.merchantKey, displayName: $0.displayName,
                    category: $0.categoryRawValue, buildingId: $0.buildingIdRaw,
                    hitCount: $0.hitCount, createdAt: $0.createdAt
                )
            },
            installments: all(InstallmentPlan.self).map {
                InstallmentDTO(
                    id: $0.id, merchant: $0.merchant, totalAmount: $0.totalAmount,
                    currency: $0.currency, numberOfPayments: $0.numberOfPayments,
                    firstChargeDate: $0.firstChargeDate, category: $0.categoryRawValue,
                    createdAt: $0.createdAt
                )
            },
            savingsGoals: all(SavingsGoal.self).map {
                SavingsGoalDTO(
                    id: $0.id, name: $0.name, icon: $0.icon, targetAmount: $0.targetAmount,
                    savedAmount: $0.savedAmount, currency: $0.currency, targetDate: $0.targetDate,
                    createdAt: $0.createdAt, completedAt: $0.completedAt,
                    unlinkedBaseline: $0.unlinkedBaseline, baselineCaptured: $0.baselineCaptured
                )
            },
            enrichments: all(CityEnrichment.self).map {
                EnrichmentDTO(
                    id: $0.id, itemId: $0.itemId, name: $0.name, subtitle: $0.subtitle,
                    icon: $0.icon, type: $0.typeRawValue, tier: $0.tierRawValue,
                    unlockedDate: $0.unlockedDate, savedAmount: $0.savedAmount,
                    districtId: $0.districtId, isApplied: $0.isApplied,
                    placedSlotId: $0.placedSlotId
                )
            }
        )
    }

    @MainActor
    public static func exportData(context: ModelContext, now: Date = Date()) throws -> Data {
        try makeEncoder().encode(buildEnvelope(context: context, now: now))
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

    public enum ImportError: LocalizedError {
        case notABackup
        case futureFormat(Int)

        public var errorDescription: String? {
            switch self {
            case .notABackup:
                return "הקובץ הזה אינו גיבוי של MoneyCity."
            case .futureFormat(let v):
                return "הגיבוי נוצר בגרסה חדשה יותר של האפליקציה (פורמט \(v))."
            }
        }
    }

    public struct ImportSummary: Equatable {
        public var added = 0
        public var skipped = 0
        public var exportedAt: Date? = nil
    }

    @MainActor
    public static func importData(
        _ data: Data,
        into context: ModelContext,
        mode: ImportMode = .merge
    ) throws -> ImportSummary {
        let envelope = try makeDecoder().decode(Envelope.self, from: data)
        guard envelope.format == formatIdentifier else { throw ImportError.notABackup }
        guard envelope.formatVersion <= formatVersion else {
            throw ImportError.futureFormat(envelope.formatVersion)
        }

        var summary = ImportSummary()
        summary.exportedAt = envelope.exportedAt

        func existingIds<T: PersistentModel>(_ type: T.Type, _ id: (T) -> UUID) -> Set<UUID> {
            Set(((try? context.fetch(FetchDescriptor<T>())) ?? []).map(id))
        }
        func wipe<T: PersistentModel>(_ type: T.Type) {
            for object in ((try? context.fetch(FetchDescriptor<T>())) ?? []) {
                context.delete(object)
            }
        }

        if mode == .replace {
            wipe(Transaction.self); wipe(RecurringExpense.self); wipe(IncomeSource.self)
            wipe(CategoryBudget.self); wipe(MerchantRule.self); wipe(InstallmentPlan.self)
            wipe(SavingsGoal.self); wipe(CityEnrichment.self)
        }

        let txIds = mode == .replace ? Set<UUID>() : existingIds(Transaction.self) { $0.id }
        for dto in envelope.transactions {
            guard !txIds.contains(dto.id) else { summary.skipped += 1; continue }
            let t = Transaction(
                amount: MoneyAmount.sanitizedSigned(dto.amount) ?? 0,
                merchant: dto.merchant,
                category: SpendingCategory(rawValue: dto.category) ?? .other
            )
            t.id = dto.id
            t.currency = dto.currency
            t.categoryRawValue = dto.category
            t.timestamp = dto.timestamp
            t.confidenceScore = dto.confidenceScore
            t.isManual = dto.isManual
            t.isConfirmed = dto.isConfirmed
            t.note = dto.note
            t.buildingIdRaw = dto.buildingId
            t.originalAmount = dto.originalAmount
            t.originalCurrency = dto.originalCurrency
            t.exchangeRate = dto.exchangeRate
            t.savingsGoalId = dto.savingsGoalId
            context.insert(t)
            summary.added += 1
        }

        let recIds = mode == .replace ? Set<UUID>() : existingIds(RecurringExpense.self) { $0.id }
        for dto in envelope.recurring {
            guard !recIds.contains(dto.id) else { summary.skipped += 1; continue }
            let r = RecurringExpense(
                merchant: dto.merchant, amount: MoneyAmount.sanitized(dto.amount) ?? 0,
                category: SpendingCategory(rawValue: dto.category) ?? .other,
                dayOfMonth: dto.dayOfMonth
            )
            r.id = dto.id
            r.currency = dto.currency
            r.categoryRawValue = dto.category
            r.isActive = dto.isActive
            r.lastGeneratedPeriod = dto.lastGeneratedPeriod
            r.createdAt = dto.createdAt
            context.insert(r)
            summary.added += 1
        }

        let incIds = mode == .replace ? Set<UUID>() : existingIds(IncomeSource.self) { $0.id }
        for dto in envelope.income {
            guard !incIds.contains(dto.id) else { summary.skipped += 1; continue }
            let i = IncomeSource(name: dto.name, amount: MoneyAmount.sanitized(dto.amount) ?? 0, dayOfMonth: dto.dayOfMonth)
            i.id = dto.id
            i.currency = dto.currency
            i.isActive = dto.isActive
            i.createdAt = dto.createdAt
            context.insert(i)
            summary.added += 1
        }

        let budIds = mode == .replace ? Set<UUID>() : existingIds(CategoryBudget.self) { $0.id }
        for dto in envelope.budgets {
            guard !budIds.contains(dto.id) else { summary.skipped += 1; continue }
            let b = CategoryBudget(
                category: SpendingCategory(rawValue: dto.category) ?? .other,
                monthlyLimit: dto.monthlyLimit
            )
            b.id = dto.id
            b.categoryRawValue = dto.category
            b.createdAt = dto.createdAt
            context.insert(b)
            summary.added += 1
        }

        let ruleIds = mode == .replace ? Set<UUID>() : existingIds(MerchantRule.self) { $0.id }
        for dto in envelope.merchantRules {
            guard !ruleIds.contains(dto.id) else { summary.skipped += 1; continue }
            let r = MerchantRule(
                merchantKey: dto.merchantKey,
                displayName: dto.displayName,
                category: SpendingCategory(rawValue: dto.category) ?? .other
            )
            r.id = dto.id
            r.categoryRawValue = dto.category
            r.buildingIdRaw = dto.buildingId
            r.hitCount = dto.hitCount
            r.createdAt = dto.createdAt
            context.insert(r)
            summary.added += 1
        }

        let planIds = mode == .replace ? Set<UUID>() : existingIds(InstallmentPlan.self) { $0.id }
        for dto in envelope.installments {
            guard !planIds.contains(dto.id) else { summary.skipped += 1; continue }
            let p = InstallmentPlan(
                merchant: dto.merchant,
                totalAmount: MoneyAmount.sanitized(dto.totalAmount) ?? 0,
                numberOfPayments: dto.numberOfPayments,
                firstChargeDate: dto.firstChargeDate,
                category: SpendingCategory(rawValue: dto.category) ?? .other
            )
            p.id = dto.id
            p.currency = dto.currency
            p.categoryRawValue = dto.category
            p.createdAt = dto.createdAt
            context.insert(p)
            summary.added += 1
        }

        let goalIds = mode == .replace ? Set<UUID>() : existingIds(SavingsGoal.self) { $0.id }
        for dto in envelope.savingsGoals {
            guard !goalIds.contains(dto.id) else { summary.skipped += 1; continue }
            let g = SavingsGoal(name: dto.name, targetAmount: dto.targetAmount)
            g.id = dto.id
            g.icon = dto.icon
            g.savedAmount = dto.savedAmount
            g.currency = dto.currency
            g.targetDate = dto.targetDate
            g.createdAt = dto.createdAt
            g.completedAt = dto.completedAt
            g.unlinkedBaseline = dto.unlinkedBaseline
            g.baselineCaptured = dto.baselineCaptured
            context.insert(g)
            summary.added += 1
        }

        let enrIds = mode == .replace ? Set<UUID>() : existingIds(CityEnrichment.self) { $0.id }
        for dto in envelope.enrichments {
            guard !enrIds.contains(dto.id) else { summary.skipped += 1; continue }
            let e = CityEnrichment(
                itemId: dto.itemId,
                name: dto.name,
                icon: dto.icon,
                type: EnrichmentType(rawValue: dto.type) ?? .decoration
            )
            e.id = dto.id
            e.subtitle = dto.subtitle
            e.typeRawValue = dto.type
            e.tierRawValue = dto.tier
            e.unlockedDate = dto.unlockedDate
            e.savedAmount = dto.savedAmount
            e.districtId = dto.districtId
            e.isApplied = dto.isApplied
            e.placedSlotId = dto.placedSlotId
            context.insert(e)
            summary.added += 1
        }

        do {
            try context.save()
        } catch {
            // In .replace mode every existing row has already been deleted on this context. Leaving
            // that staged means the next unrelated save in the app silently commits the wipe.
            context.rollback()
            throw error
        }
        return summary
    }
}
