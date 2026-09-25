import Foundation

/// Read-only input to the city. Creating a snapshot never inserts a personal transaction.
public protocol ExpenseReadable {
    var amount: Double { get }
    var merchant: String { get }
    var category: SpendingCategory { get }
    var buildingId: String { get }
    var buildingIdRaw: String? { get }
    var note: String? { get }
    var needsCategorization: Bool { get }
}
extension Transaction: ExpenseReadable {}

public struct ExpenseSnapshot: Sendable, Identifiable, ExpenseReadable {
    public let id: UUID
    public let amount: Double
    public let merchant: String
    public let category: SpendingCategory
    public let timestamp: Date
    public let buildingId: String
    public let isUnresolvedForeign: Bool
    public let paidBy: String?
    public let note: String?
    public var timeZoneID: String? = nil
    public var currency: String = "ILS"
    public var isConfirmed: Bool = true
    public var displayOriginalText: String? = nil
    public var buildingIdRaw: String? = nil
    public var needsCategorization: Bool = false
    public var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let timeZoneID { formatter.timeZone = TimeZone(identifier: timeZoneID) }
        return formatter.string(from: timestamp)
    }

    public init(_ transaction: Transaction) {
        id = transaction.id; amount = transaction.amount; merchant = transaction.merchant
        category = transaction.category; timestamp = transaction.timestamp
        buildingId = transaction.buildingId; isUnresolvedForeign = transaction.isUnresolvedForeign
        paidBy = nil
        note = transaction.note
        buildingIdRaw = transaction.buildingIdRaw
        needsCategorization = transaction.needsCategorization
        currency = transaction.currency
        isConfirmed = transaction.isConfirmed
        displayOriginalText = transaction.displayOriginalText
    }

    init(_ expense: SharedExpense) {
        id = expense.id; amount = expense.amount; merchant = expense.merchant
        category = expense.category; timestamp = expense.date; buildingId = expense.buildingID
        isUnresolvedForeign = false
        paidBy = expense.paidBy
        note = expense.note
        buildingIdRaw = expense.buildingID
        needsCategorization = expense.category == .other
        currency = expense.currencyCode
        if let original = expense.originalAmount, let code = expense.originalCurrency {
            displayOriginalText = code + " " + original
        }
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
        self.buildingIdRaw = buildingId
        self.isUnresolvedForeign = isUnresolvedForeign
        self.paidBy = paidBy
        self.note = note
    }
}
