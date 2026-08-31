import Foundation
import SwiftData

/// Represents a single recorded expense or savings transaction.
@Model
public final class Transaction: Identifiable {
    public var id: UUID = UUID()
    public var amount: Double = 0.0
    public var currency: String = "₪"
    public var merchant: String = ""
    public var categoryRawValue: String = SpendingCategory.other.rawValue
    public var timestamp: Date = Date()
    public var confidenceScore: Double = 1.0
    public var isManual: Bool = false
    public var isConfirmed: Bool = true
    public var note: String? = nil
    public var buildingIdRaw: String? = nil
    public var originalAmount: Double? = nil
    public var originalCurrency: String? = nil
    public var exchangeRate: Double? = nil
    
    public var category: SpendingCategory {
        get { SpendingCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }
    
    public var buildingId: String {
        if let raw = buildingIdRaw, !raw.isEmpty {
            return raw
        }
        return CategorizationEngine.shared.mapToBuildingId(category: category, merchant: merchant)
    }
    
    public var displayOriginalText: String? {
        guard let origAmt = originalAmount, let origCurr = originalCurrency, origCurr != currency else {
            return nil
        }
        return "\(origCurr)\(String(format: "%.2f", origAmt))"
    }
    
    public init(
        id: UUID = UUID(),
        amount: Double,
        currency: String = "₪",
        merchant: String,
        category: SpendingCategory,
        timestamp: Date = Date(),
        confidenceScore: Double = 1.0,
        isManual: Bool = false,
        isConfirmed: Bool = true,
        note: String? = nil,
        buildingId: String? = nil,
        originalAmount: Double? = nil,
        originalCurrency: String? = nil,
        exchangeRate: Double? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.categoryRawValue = category.rawValue
        self.timestamp = timestamp
        self.confidenceScore = confidenceScore
        self.isManual = isManual
        self.isConfirmed = isConfirmed
        self.note = note
        self.buildingIdRaw = buildingId
        self.originalAmount = originalAmount
        self.originalCurrency = originalCurrency
        self.exchangeRate = exchangeRate
    }
}

extension Transaction {
    /// Formatted localized currency string
    public var formattedAmount: String {
        return "\(currency)\(String(format: "%.2f", amount))"
    }
    
    /// Short display date
    public var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}
