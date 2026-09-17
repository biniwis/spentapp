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
    public static func buildEnvelope(context: ModelContext, now: Date = Date()) throws -> Envelope {
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
            }
        )
    }

    @MainActor
    public static func exportData(context: ModelContext, now: Date = Date()) throws -> Data {
        try makeEncoder().encode(try buildEnvelope(context: context, now: now))
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

    @MainActor
    public static func importData(
        _ data: Data,
        into context: ModelContext,
        mode: ImportMode = .merge
    ) throws -> ImportSummary {
        guard data.count <= maxBackupFileSize else {
            throw ImportError.fileTooLarge
        }

        let envelope = try makeDecoder().decode(Envelope.self, from: data)
        guard envelope.format == formatIdentifier else { throw ImportError.notABackup }
        guard envelope.formatVersion <= formatVersion else {
            throw ImportError.futureFormat(envelope.formatVersion)
        }
        guard envelope.totalRecords <= maxRecordCount else {
            throw ImportError.tooManyRecords
        }

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
            try wipe(SavingsGoal.self); try wipe(CityEnrichment.self)
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
