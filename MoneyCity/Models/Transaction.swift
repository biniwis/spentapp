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

    /// The savings goal this transfer funded, when it funded one.
    ///
    /// Without it a deposit and its goal were two unrelated records holding the same
    /// number, and deleting the transfer from history left the goal claiming money that no
    /// longer existed anywhere.
    public var savingsGoalId: UUID? = nil
    
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
        exchangeRate: Double? = nil,
        savingsGoalId: UUID? = nil
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
        self.savingsGoalId = savingsGoalId
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
    
    /// Formatted date string (e.g. "14 אוג 2026")
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }
}

/// One place decides what a storable money amount is.
///
/// Without this, a long pasted number becomes a Double like 1e20, passes a bare `> 0` check and
/// is persisted. Every `Int(someDouble)` money display then traps — including the ones on the
/// root City screen — which bricks the app on launch with no way for the user to delete the row.
public enum MoneyAmount {
    /// Ceiling for anything the app will store. Far above any plausible personal transaction and
    /// far below the point where `Int(Double)` can overflow.
    public static let maximum: Double = 100_000_000

    /// The only way an amount should enter the store. Returns nil when the input cannot be trusted.
    public static func sanitized(_ value: Double?) -> Double? {
        guard let v = value, v.isFinite, v > 0, v <= maximum else { return nil }
        return (v * 100).rounded() / 100
    }

    /// Same rule, but keeps the sign — refunds are stored negative.
    public static func sanitizedSigned(_ value: Double?) -> Double? {
        guard let v = value, v.isFinite, v != 0, abs(v) <= maximum else { return nil }
        return (v * 100).rounded() / 100
    }

    /// Safe `Int` for display. A row that predates this guard, or arrives from an edited backup
    /// file, must never be able to trap the UI.
    public static func displayInt(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(min(max(value, -maximum), maximum))
    }
}
