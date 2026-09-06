// Compile with the production, Foundation-only CityLifeState.swift (no UI test host).
import Foundation

@main
struct CityLifeRulesCheck {
    static func main() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        let month = cal.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        func events(_ venue: String, _ count: Int, _ total: Double, spread: Bool = true) -> [CityLifeEvent] {
            (0..<count).map { i in
                CityLifeEvent(id: "\(venue)-\(i)", venueID: venue, amount: total / Double(count),
                    date: cal.date(byAdding: .day, value: spread ? i % 28 : 0, to: month)!,
                    merchant: i % 2 == 0 ? " Cafe A " : "CAFE A")
            }
        }
        func states(_ e: [CityLifeEvent]) -> [CityVenueState] { CityLifeEngine.states(for: e, in: month, calendar: cal) }
        func state(_ e: [CityLifeEvent], _ id: String = "food_coffee") -> CityVenueState { states(e).first { $0.id == id }! }
        func check(_ ok: @autoclosure () -> Bool, _ message: String) {
            precondition(ok(), message)
            print("PASS: \(message)")
        }
        let empty = states([])
        check(empty.count == CityLifeEngine.venueIDs.count, "Every financial destination exists on day one")
        check(empty.allSatisfy { $0.amount == 0 && $0.activity == 0 && $0.additionalPlaces == 0 }, "Zero spending is quiet, not invented activity")
        let onceEvents = events("food_coffee", 1, 600), dailyEvents = events("food_coffee", 20, 600)
        let once = state(onceEvents), daily = state(dailyEvents)
        check(once.amount == daily.amount && once.share == daily.share, "Equal money keeps equal anchor mass inputs")
        check(once.additionalPlaces == 0 && daily.additionalPlaces == 3, "Repeated daily purchases, not one expensive purchase, add places")
        check(daily.activity > once.activity + 0.5, "Daily purchases create visibly more footfall")
        let oneDay = state(events("food_coffee", 20, 600, spread: false))
        check(oneDay.additionalPlaces == 0 && oneDay.activity < daily.activity, "One shopping day is not a sustained habit")
        check(daily.merchantCount == 1 && daily.activeDays == 20 && daily.purchaseCount == 20, "Merchant normalization and real visit/day counts")
        let duplicated = state(dailyEvents + dailyEvents)
        check(duplicated == daily, "Duplicate source IDs never multiply spend or visits")
        let refund = CityLifeEvent(id: "refund", venueID: "food_coffee", amount: -600, date: month, merchant: "Cafe A")
        let refunded = state(dailyEvents + [refund])
        check(refunded.amount == 0 && refunded.activity == 0 && refunded.additionalPlaces == 0, "Refunds do not count as purchases or leave phantom development")
        let invalid = [Double.nan, Double.infinity].enumerated().map {
            CityLifeEvent(id: "invalid-\($0.offset)", venueID: "food_coffee", amount: $0.element, date: month, merchant: "Invalid")
        }
        check(state(onceEvents + invalid) == once, "Non-finite input is ignored")
        let october = cal.date(byAdding: .month, value: 1, to: month)!
        let outside = CityLifeEvent(id: "next-month", venueID: "food_coffee", amount: 999, date: october, merchant: "Later")
        check(state(onceEvents + [outside]) == once, "A month never imports the next month's purchases")
        check(states(dailyEvents.reversed()) == states(dailyEvents), "Input order does not change the city")
        let rentEvents = events("house_tower", 1, 3200) + events("food_coffee", 3, 100)
        let rent = state(rentEvents, "house_tower")
        check(rent.additionalPlaces == 2 && rent.activity < 0.18, "Rent creates residential presence without fictitious shopping crowds")
        check(state(events("house_subs", 20, 600), "house_subs").additionalPlaces == 0, "Subscriptions do not open duplicate venues")
        let encoded = try JSONEncoder().encode(daily)
        let decoded = try JSONDecoder().decode(CityVenueState.self, from: encoded)
        check(decoded == daily, "Native state survives the JSON bridge")
        let fixtures = ["empty": empty, "once": states(onceEvents), "daily": states(dailyEvents),
            "delivery": states(events("food_wolt", 20, 600)), "housing": states(rentEvents),
            "food": states(events("food_bistro", 12, 1800) + events("food_coffee", 20, 750)
                + events("food_super", 4, 350) + events("house_tower", 1, 400) + events("trans_station", 8, 150)),
            "all": states(CityLifeEngine.venueIDs.flatMap { events($0, 20, 600) })]
        if CommandLine.arguments.count > 1 {
            try JSONEncoder().encode(fixtures).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
        print("City life checks complete. Fixtures use production Swift rules, no copied JavaScript formula.")
    }
}
