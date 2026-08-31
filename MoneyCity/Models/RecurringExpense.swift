import Foundation
import SwiftData

/// A fixed expense the user defines once — rent, a subscription, a utility bill —
/// which the app then materialises into a real Transaction every month.
///
/// This exists because the Wallet automation only captures tap-to-pay purchases.
/// The large, regular charges never reach it, and a month where the user forgets to
/// type them in silently inflates the savings park and understates the city.
@Model
public final class RecurringExpense: Identifiable {
    public var id: UUID = UUID()
    public var merchant: String = ""
    public var amount: Double = 0.0
    public var currency: String = "₪"
    public var categoryRawValue: String = SpendingCategory.housing.rawValue

    /// 1...31. Months that are shorter clamp to their last day.
    public var dayOfMonth: Int = 1

    public var isActive: Bool = true

    /// "yyyy-MM" of the most recent month this template already produced.
    /// nil means it has never run.
    public var lastGeneratedPeriod: String? = nil

    public var createdAt: Date = Date()

    public var category: SpendingCategory {
        get { SpendingCategory(rawValue: categoryRawValue) ?? .housing }
        set { categoryRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        currency: String = "₪",
        category: SpendingCategory,
        dayOfMonth: Int,
        isActive: Bool = true,
        lastGeneratedPeriod: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.categoryRawValue = category.rawValue
        self.dayOfMonth = min(31, max(1, dayOfMonth))
        self.isActive = isActive
        self.lastGeneratedPeriod = lastGeneratedPeriod
        self.createdAt = createdAt
    }
}
