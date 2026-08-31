import Foundation
import SwiftData

/// A purchase split across monthly payments — the Israeli credit-card norm.
///
/// A ₪3,000 buy in 6 payments is one decision and six charges. Treating it as six
/// unrelated expenses hides the commitment; treating it as one ₪3,000 expense in month one
/// misstates every month after. This model keeps both truths.
@Model
public final class InstallmentPlan: Identifiable {
    public var id: UUID = UUID()
    public var merchant: String = ""
    public var totalAmount: Double = 0.0
    public var currency: String = "₪"
    public var numberOfPayments: Int = 1
    public var firstChargeDate: Date = Date()
    public var categoryRawValue: String = SpendingCategory.shopping.rawValue
    public var createdAt: Date = Date()

    public var category: SpendingCategory {
        get { SpendingCategory(rawValue: categoryRawValue) ?? .shopping }
        set { categoryRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        merchant: String,
        totalAmount: Double,
        currency: String = "₪",
        numberOfPayments: Int,
        firstChargeDate: Date = Date(),
        category: SpendingCategory,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.merchant = merchant
        self.totalAmount = totalAmount
        self.currency = currency
        self.numberOfPayments = max(1, numberOfPayments)
        self.firstChargeDate = firstChargeDate
        self.categoryRawValue = category.rawValue
        self.createdAt = createdAt
    }
}
