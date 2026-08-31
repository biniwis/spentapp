import Foundation
import SwiftData

/// A recurring monthly income — salary, freelance retainer, allowance.
///
/// This exists because the app previously had no concept of income at all: the entire
/// savings figure was derived from a hardcoded ₪8,000 "budget" the app invented for the
/// user. Without real income there is no cash flow and no honest answer to "how much is
/// left this month".
@Model
public final class IncomeSource: Identifiable {
    public var id: UUID = UUID()
    public var name: String = ""
    public var amount: Double = 0.0
    public var currency: String = "₪"

    /// 1...31, clamped to the month's length like fixed expenses.
    public var dayOfMonth: Int = 1
    public var isActive: Bool = true
    public var createdAt: Date = Date()

    public init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        currency: String = "₪",
        dayOfMonth: Int = 1,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currency = currency
        self.dayOfMonth = min(31, max(1, dayOfMonth))
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
