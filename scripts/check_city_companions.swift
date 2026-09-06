import Foundation

@main
struct CompanionCheck {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        func day(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: start)! }
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            precondition(value(), message); print("PASS: \(message)")
        }
        check(!CityCompanions.isEligible(now: day(6), firstUse: start, lastReward: nil, calendar: calendar), "No first-day or two-purchase shortcut")
        check(CityCompanions.isEligible(now: day(7), firstUse: start, lastReward: nil, calendar: calendar), "First eligibility after seven days")
        check(!CityCompanions.isEligible(now: day(13), firstUse: start, lastReward: day(7), calendar: calendar), "Another calendar week cannot bypass cooldown")
        check(CityCompanions.isEligible(now: day(14), firstUse: start, lastReward: day(7), calendar: calendar), "Next seven-day cycle")
        check(!CityCompanions.isEligible(now: day(3), firstUse: start, lastReward: day(7), calendar: calendar), "Clock rollback never grants a reward")
        func event(_ id: String, _ amount: Double, _ date: Int, _ category: String = "food") -> CityCompanions.Expense {
            .init(id: id, amount: amount, date: day(date), category: category)
        }
        let expenses = [event("before", 800, 3), event("after", 450, 10)]
        let totals = CityCompanions.weeklyTotals(expenses, now: day(14), calendar: calendar)
        check(totals.current == 450 && totals.previous == 800, "Real decrease is 350, independent of month boundaries")
        var noisy = expenses + expenses
        noisy += [event("rent", 3000, 3, "housing"), event("doctor", 2000, 3, "health"), event("save", 200, 10, "savings"), event("bank", 200, 3, "finance"), event("subs", 200, 3, "subscriptions")]
        noisy += [event("refund", -800, 10), event("invalid", .nan, 10), event("infinity", .infinity, 10), event("future", 800, 15), event("old", 800, -1)]
        let cleaned = CityCompanions.weeklyTotals(noisy, now: day(14), calendar: calendar)
        check(cleaned.current == 450 && cleaned.previous == 800, "Essential/fixed costs, refunds, duplicate IDs, invalid and future rows do not fabricate progress")
        let empty = CityCompanions.weeklyTotals([], now: day(14), calendar: calendar)
        check(empty.current == 0 && empty.previous == 0, "Empty ledger has no invented baseline")
        let boundary = CityCompanions.weeklyTotals([event("boundary", 10, 7)], now: day(14), calendar: calendar)
        check(boundary.current == 10 && boundary.previous == 0, "Week boundary counted exactly once")
        check(CityCompanions.ids.count == 6 && !CityCompanions.ids.contains("repair_bench"), "Only six living rewards; no furniture")
    }
}
