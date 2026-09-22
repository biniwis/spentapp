import Foundation
import SwiftData

/// Represents a one-time scheduled expense that has not yet materialized into a Transaction.
@Model
public final class ScheduledExpense: Identifiable {
    public var id: UUID = UUID()
    public var merchant: String = ""
    public var amount: Double = 0.0
    public var currency: String = "₪"
    public var categoryRawValue: String = SpendingCategory.other.rawValue
    public var scheduledFor: Date = Date()
    public var createdAt: Date = Date()
    public var buildingIdRaw: String? = nil
    public var originalAmount: Double? = nil
    public var originalCurrency: String? = nil
    public var exchangeRate: Double? = nil
    public var materializedAt: Date? = nil
    public var materializedTransactionId: UUID? = nil

    public var category: SpendingCategory {
        get { SpendingCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    public var isMaterialized: Bool {
        materializedAt != nil
    }

    public var buildingId: String {
        if let raw = buildingIdRaw, !raw.isEmpty {
            return CityBuilding.normalizeBuildingId(raw, for: category)
        }
        return CategorizationEngine.shared.mapToBuildingId(category: category, merchant: merchant)
    }

    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        currency: String = "₪",
        category: SpendingCategory,
        scheduledFor: Date,
        createdAt: Date = Date(),
        buildingIdRaw: String? = nil,
        originalAmount: Double? = nil,
        originalCurrency: String? = nil,
        exchangeRate: Double? = nil,
        materializedAt: Date? = nil,
        materializedTransactionId: UUID? = nil
    ) {
        self.id = id
        self.merchant = InputSanitizer.sanitizeSingleLine(merchant, maxLength: InputSanitizer.maxMerchantLength)
        self.amount = MoneyAmount.sanitized(amount) ?? 0.0
        self.currency = InputSanitizer.sanitizeSingleLine(currency, maxLength: InputSanitizer.maxCurrencyLength)
        self.categoryRawValue = category.canonical.rawValue
        self.scheduledFor = scheduledFor
        self.createdAt = createdAt
        self.buildingIdRaw = buildingIdRaw.map { InputSanitizer.sanitizeIdentifier($0) }
        self.originalAmount = originalAmount.flatMap { MoneyAmount.sanitized($0) }
        self.originalCurrency = originalCurrency.map { InputSanitizer.sanitizeSingleLine($0, maxLength: InputSanitizer.maxCurrencyLength) }
        self.exchangeRate = exchangeRate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.materializedAt = materializedAt
        self.materializedTransactionId = materializedTransactionId
    }
}
