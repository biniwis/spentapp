import Foundation

/// Remembers the derived values the main view reads over and over within a single render.
///
/// `currentCity`, `progressReport` and the month filter are computed properties, and SwiftUI
/// runs a computed property on every access — not once per render. `body` reaches for them
/// seven to thirteen times depending on what is expanded, and each run rebuilt the month
/// filter (one `Calendar.dateComponents` per transaction) and then the entire city
/// simulation (a `lowercased()` plus roughly twenty-five substring searches per transaction).
/// At a few hundred transactions that is tens of thousands of string operations per frame,
/// sitting directly on top of a live WebGL canvas — and it got worse as history grew.
///
/// Keyed on a cheap digest of the inputs rather than a change notification, so an edit that
/// leaves the transaction count the same still invalidates it.
/// Deliberately not marked `@MainActor`: it is only ever touched from `body`, which already
/// runs there, and annotating it would make the `@State` initialiser cross an isolation
/// boundary for no benefit.
final class CityDerivedCache {
    private var monthKey: Int?
    private var monthRows: [Transaction]?
    private var cityKey: Int?
    private var cachedCity: MonthlyCity?
    private var reportKey: Int?
    private var cachedReport: WeeklyProgressReport?

    func monthTransactions(key: Int, build: () -> [Transaction]) -> [Transaction] {
        if monthKey == key, let monthRows { return monthRows }
        let value = build()
        monthKey = key
        monthRows = value
        return value
    }

    func city(key: Int, build: () -> MonthlyCity) -> MonthlyCity {
        if cityKey == key, let cachedCity { return cachedCity }
        let value = build()
        cityKey = key
        cachedCity = value
        return value
    }

    func report(key: Int, build: () -> WeeklyProgressReport) -> WeeklyProgressReport {
        if reportKey == key, let cachedReport { return cachedReport }
        let value = build()
        reportKey = key
        cachedReport = value
        return value
    }
}
