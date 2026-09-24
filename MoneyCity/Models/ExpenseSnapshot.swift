import Foundation

/// Read-only input to the city. Creating a snapshot never inserts a personal transaction.
public struct ExpenseSnapshot: Sendable, Identifiable {
    public let id: UUID
    public let amount: Double
    public let merchant: String
    public let category: SpendingCategory
    public let timestamp: Date
    public let buildingId: String
    public let isUnresolvedForeign: Bool
    public let paidBy: String?
    public let note: String?

    public init(_ transaction: Transaction) {
        id = transaction.id; amount = transaction.amount; merchant = transaction.merchant
        category = transaction.category; timestamp = transaction.timestamp
        buildingId = transaction.buildingId; isUnresolvedForeign = transaction.isUnresolvedForeign
        paidBy = nil
        note = transaction.note
    }

    init(_ expense: SharedExpense) {
        id = expense.id; amount = expense.amount; merchant = expense.merchant
        category = expense.category; timestamp = expense.date; buildingId = expense.buildingID
        isUnresolvedForeign = false
        paidBy = expense.paidBy
        note = expense.note
    }

    public init(
        id: UUID = UUID(),
        amount: Double,
        merchant: String,
        category: SpendingCategory,
        timestamp: Date,
        buildingId: String,
        isUnresolvedForeign: Bool = false,
        paidBy: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.timestamp = timestamp
        self.buildingId = buildingId
        self.isUnresolvedForeign = isUnresolvedForeign
        self.paidBy = paidBy
        self.note = note
    }
}
