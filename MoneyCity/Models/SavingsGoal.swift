import Foundation
import SwiftData

/// Something the user is saving toward — a trip, a deposit, a replacement laptop.
///
/// The app could measure progress by summing every savings transfer, but one pool cannot
/// honestly fund two goals at once. Deposits are therefore explicit: money is assigned to
/// a goal, and the same action records the transfer.
@Model
public final class SavingsGoal: Identifiable {
    public var id: UUID = UUID()
    public var name: String = ""
    public var icon: String = "🎯"
    public var targetAmount: Double = 0.0
    public var savedAmount: Double = 0.0
    public var currency: String = "₪"
    public var targetDate: Date? = nil
    public var createdAt: Date = Date()
    public var completedAt: Date? = nil

    public var isComplete: Bool { savedAmount >= targetAmount && targetAmount > 0 }

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "🎯",
        targetAmount: Double,
        savedAmount: Double = 0.0,
        currency: String = "₪",
        targetDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.currency = currency
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
