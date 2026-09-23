import Foundation

/// Read-only input to the city. Creating a snapshot never inserts a personal transaction.
public struct ExpenseSnapshot: Sendable {
    public let id: UUID
    public let amount: Double
    public let merchant: String
    public let category: SpendingCategory
    public let timestamp: Date
    public let buildingId: String
    public let isUnresolvedForeign: Bool

    public init(_ transaction: Transaction) {
        id = transaction.id; amount = transaction.amount; merchant = transaction.merchant
        category = transaction.category; timestamp = transaction.timestamp
        buildingId = transaction.buildingId; isUnresolvedForeign = transaction.isUnresolvedForeign
    }

    init(_ expense: SharedExpense) {
        id = expense.id; amount = expense.amount; merchant = expense.merchant
        category = expense.category; timestamp = expense.date; buildingId = expense.buildingID
        isUnresolvedForeign = false
    }
}
