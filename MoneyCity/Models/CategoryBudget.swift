import Foundation
import SwiftData

/// A monthly spending ceiling for one category.
///
/// The app previously had a single global budget, which cannot answer the question people
/// actually open a budgeting app to ask: "how much do I have left for food this month?"
@Model
public final class CategoryBudget: Identifiable {
    public var id: UUID = UUID()

    /// Always stored canonically, so the legacy `groceries` / `coffee` aliases can never
    /// produce two competing budgets for what the user sees as one category.
    public var categoryRawValue: String = SpendingCategory.food.rawValue
    public var monthlyLimit: Double = 0.0
    public var createdAt: Date = Date()

    public var category: SpendingCategory {
        get { (SpendingCategory(rawValue: categoryRawValue) ?? .other).canonical }
        set { categoryRawValue = newValue.canonical.rawValue }
    }

    public init(
        id: UUID = UUID(),
        category: SpendingCategory,
        monthlyLimit: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.categoryRawValue = category.canonical.rawValue
        self.monthlyLimit = monthlyLimit
        self.createdAt = createdAt
    }
}
