import XCTest
#if canImport(MoneyCity)
@testable import MoneyCity
#endif

final class CityRewardEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func date(_ offset: Int) -> Date { Calendar.current.date(byAdding: .day, value: offset, to: now)! }
    private func engine() -> CityRewardEngine {
        var result = CityRewardEngine()
        result.state = CityRewardState()
        return result
    }
    private func expense(_ offset: Int, _ amount: Double = 100, category: String = "food") -> CityCompanions.Expense {
        .init(id: "\(offset)", amount: amount, date: date(offset), category: category)
    }
    private var quietHistory: [CityCompanions.Expense] {
        (-23 ... -4).map { expense($0) } + [-3, -2, -1].map { expense($0, 10) }
    }
    func testPresenceDoesNotRequireSpendingReduction() {
        var e = engine()
        e.evaluate(expenses: [-6, -3, -1].map { expense($0, 500) }, firstUse: date(-7), latestClaim: nil, now: now)
        XCTAssertEqual(e.state.pending?.trigger, .weeklyPresence)
    }
    func testInstallationAloneAndEarlyActivityDoNotUnlock() {
        var e = engine()
        e.evaluate(expenses: [], firstUse: date(-30), latestClaim: nil, now: now)
        XCTAssertNil(e.state.pending)
        e.evaluate(expenses: [-3, -2, -1].map { expense($0) }, firstUse: date(-6), latestClaim: nil, now: now)
        XCTAssertNil(e.state.pending)
    }
    func testVisitsCountAndWeeklyWins() {
        var e = engine()
        for offset in [-5, -3, 0] { e.recordVisit(at: date(offset)) }
        e.evaluate(expenses: [], firstUse: date(-7), latestClaim: nil, now: now)
        XCTAssertEqual(e.state.pending?.trigger, .weeklyPresence)
        e = engine()
        e.evaluate(expenses: quietHistory, firstUse: date(-30), latestClaim: nil, now: now)
        XCTAssertEqual(e.state.pending?.trigger, .weeklyPresence)
    }
    func testIndependentSurpriseAndNoMissingDataReward() {
        var e = engine()
        e.state.lastWeeklyRewardDate = date(-5)
        e.state.lastAnyRewardDate = date(-5)
        e.evaluate(expenses: quietHistory, firstUse: date(-30), latestClaim: nil, now: now)
        XCTAssertEqual(e.state.pending?.trigger, .quietPeriod)
        e.state.pending = nil
        e.evaluate(expenses: Array(quietHistory.dropLast(3)), firstUse: date(-30), latestClaim: nil, now: now)
        XCTAssertNil(e.state.pending)
    }
    func testFixedCostsCannotCreateBaseline() {
        var e = engine()
        let history = (-23 ... -4).map { expense($0, category: "housing") } + [-3, -2, -1].map { expense($0, 10) }
        e.evaluate(expenses: history, firstUse: date(-5), latestClaim: nil, now: now)
        XCTAssertNil(e.state.pending)
    }
    func testClaimCooldownAndOneSurprisePerCycle() {
        var e = engine()
        e.state.lastWeeklyRewardDate = date(-5)
        e.evaluate(expenses: quietHistory, firstUse: date(-30), latestClaim: nil, now: now)
        e.claim(at: now)
        XCTAssertFalse(e.canClaim(at: now))
        e.evaluate(expenses: quietHistory, firstUse: date(-30), latestClaim: nil, now: now)
        XCTAssertNil(e.state.pending)
        e.state.lastWeeklyRewardDate = date(-1)
        e.state.lastSurpriseRewardDate = date(-3)
        e.state.lastAnyRewardDate = date(-3)
        e.evaluate(expenses: quietHistory, firstUse: date(-30), latestClaim: nil, now: now)
        XCTAssertNil(e.state.pending)
        e.state.lastWeeklyRewardDate = date(-6)
        e.state.lastSurpriseRewardDate = date(-5)
        e.state.lastAnyRewardDate = date(-5)
        e.evaluate(expenses: quietHistory, firstUse: date(-30), latestClaim: nil, now: now)
        XCTAssertNil(e.state.pending)
    }
    func testPendingSurvivesDismissalAndRelaunch() {
        let defaults = UserDefaults(suiteName: "CityRewardTests.\(UUID())")!
        defer { defaults.removeObject(forKey: CityRewardEngine.storageKey) }
        var e = engine()
        e.evaluate(expenses: [-6, -3, -1].map { expense($0) }, firstUse: date(-7), latestClaim: nil, now: now)
        let id = e.state.pending?.id
        e.markPresented(at: now)
        e.dismiss()
        e.save(defaults: defaults)
        e = CityRewardEngine(defaults: defaults)
        e.evaluate(expenses: [], firstUse: date(-7), latestClaim: nil, now: date(10))
        XCTAssertEqual(e.state.pending?.id, id)
        XCTAssertFalse(e.canPresent(at: date(10)))
        XCTAssertTrue(e.canClaim(at: date(10)))
    }
    func testLegacyClaimReconcilesWithoutDuplicate() {
        var e = engine()
        e.evaluate(expenses: quietHistory, firstUse: date(-30), latestClaim: now, now: now)
        XCTAssertNil(e.state.pending)
        XCTAssertEqual(e.state.lastWeeklyRewardDate, now)
    }
}
