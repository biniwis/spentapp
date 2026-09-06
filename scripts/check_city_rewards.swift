// Executes the production CityProgressEngine with plain DTOs instead of a SwiftData store.
import Foundation
public enum EnrichmentType: Sendable { case nature, repair, resident, pet, decoration, landmark }
public enum RewardTestCategory: String { case food, housing, health, subscriptions, savings, finance }
public struct Transaction {
    public let id: UUID
    public let amount: Double
    public let timestamp: Date
    public let category: RewardTestCategory
}
@main struct RewardEngineCheck {
    static func main() {
        let engine = CityProgressEngine.shared, now = Date()
        func tx(_ amount: Double, _ daysAgo: Int, _ category: RewardTestCategory = .food) -> Transaction {
            Transaction(id: UUID(), amount: amount, timestamp: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!, category: category)
        }
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            precondition(value(), message); print("PASS: \(message)")
        }
        func report(_ transactions: [Transaction]) -> WeeklyProgressReport {
            engine.evaluateProgress(transactions: transactions, unlockedItemIds: [], referenceDate: now)
        }
        check(!report([]).hasPositiveProgress, "An empty ledger cannot earn a progress gift")
        check(!report([tx(100, 2)]).hasPositiveProgress, "A previous week baseline is required")
        check(!report([tx(100, 10), tx(90, 2)]).hasPositiveProgress, "Exactly ten is below the existing reward threshold")
        check(report([tx(100, 10), tx(89, 2)]).hasPositiveProgress, "A real decrease over ten qualifies")
        check(!report([tx(100, 10), tx(150, 2)]).hasPositiveProgress, "Higher spending does not fabricate progress")
        let positive = report([tx(800, 10), tx(450, 2), tx(3500, 10, .housing), tx(1000, 10, .health)])
        check(positive.savedAmount == 350 && positive.progressTier == "medium", "Accurate progress excludes essential costs")
        check(Set(engine.allCatalogOptions.map(\.id)) == CityCompanions.ids, "Native catalog and scene companion identities agree")
        check(engine.allCatalogOptions.allSatisfy { $0.type == .resident || $0.type == .pet }, "No furniture or infrastructure rewards")
        let first = engine.availableWeeklyOptions(unlockedItemIds: [])
        check(first.count == 3, "At most three choices for one gift")
        let later = engine.availableWeeklyOptions(unlockedItemIds: Set(first.map(\.id)))
        check(later.count == 3 && !later.contains(where: { first.map(\.id).contains($0.id) }), "Previously earned friends are not offered twice")
        check(engine.availableWeeklyOptions(unlockedItemIds: CityCompanions.ids).isEmpty, "Completed collection has no invalid choice")
    }
}
