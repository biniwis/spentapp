import XCTest
import SwiftData
@testable import MoneyCity

final class IngestStateMachineTests: XCTestCase {
    @MainActor
    private func fixture() throws -> (ModelContainer, PendingWalletStore) {
        let schema = Schema([Transaction.self, MerchantRule.self])
        let container = try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let defaults = UserDefaults(suiteName: "IngestTests.\(UUID())")!
        return (container, PendingWalletStore(defaults: defaults))
    }
    @MainActor
    private func receive(_ machine: IngestStateMachine, amount: Double?, date: Date,
                         currency: String = "₪", pending: String? = nil) throws -> IngestStateMachine.Outcome {
        try machine.receive(amount: amount, amountText: nil, merchant: "Wolt", currency: currency,
                            date: date, source: "test", pendingID: pending)
    }
    @MainActor
    func testFullReportThenOldNotificationDoesNotDoubleCharge() throws {
        let (container, store) = try fixture()
        let context = ModelContext(container)
        let machine = IngestStateMachine(context: context, pendingStore: store)
        let date = Date()
        guard case .pending(let pending, true) = try receive(machine, amount: nil, date: date) else {
            return XCTFail("Missing amount must wait")
        }
        _ = try receive(machine, amount: 42, date: date)
        guard case .duplicate = try receive(machine, amount: 42, date: date, pending: pending.id) else {
            return XCTFail("Old notification must deduplicate")
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Transaction>()), 1)
        XCTAssertNil(store.get(id: pending.id))
        XCTAssertEqual(machine.states, [.received, .normalized, .duplicate])
    }
    @MainActor
    func testCompletionAndRepeatedResponseKeepOneStableIdentity() throws {
        let (container, store) = try fixture()
        let context = ModelContext(container)
        let machine = IngestStateMachine(context: context, pendingStore: store)
        let date = Date()
        guard case .pending(let pending, _) = try receive(machine, amount: nil, date: date) else { return XCTFail() }
        guard case .finalized(let tx) = try receive(machine, amount: 42, date: date, pending: pending.id) else { return XCTFail() }
        XCTAssertEqual(tx.id.uuidString, pending.id)
        guard case .duplicate = try receive(machine, amount: 42, date: date, pending: pending.id) else { return XCTFail() }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Transaction>()), 1)
    }
    @MainActor
    func testSaveFailureKeepsPendingAndRetrySucceeds() throws {
        enum Failure: Error { case disk }
        let (container, store) = try fixture()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let machine = IngestStateMachine(context: context, pendingStore: store)
        let date = Date()
        guard case .pending(let pending, _) = try receive(machine, amount: nil, date: date) else { return XCTFail() }
        let failing = IngestStateMachine(context: context, pendingStore: store, commit: { _ in throw Failure.disk })
        XCTAssertThrowsError(try receive(failing, amount: 42, date: date, pending: pending.id))
        XCTAssertEqual(failing.states.last, .failed)
        XCTAssertNotNil(store.get(id: pending.id))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Transaction>()), 0)
        _ = try receive(machine, amount: 42, date: date, pending: pending.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Transaction>()), 1)
    }
    @MainActor
    func testCompletionUsesCurrencyConversionAndUnknownMerchantReview() throws {
        let (container, store) = try fixture()
        let machine = IngestStateMachine(context: ModelContext(container), pendingStore: store)
        let pending = store.findOrRegister(merchant: "UnknownMerchantXYZ", currency: "USD",
            categoryRawValue: SpendingCategory.other.rawValue, buildingId: nil, date: Date()).ingest
        guard case .finalized(let tx) = try receive(machine, amount: 12, date: pending.timestamp, pending: pending.id) else { return XCTFail() }
        XCTAssertEqual(tx.originalAmount, 12)
        XCTAssertEqual(tx.originalCurrency, "$")
        XCTAssertFalse(tx.isConfirmed)
        guard case .duplicate = try machine.receive(amount: 12, amountText: nil, merchant: pending.merchant,
            currency: "USD", date: pending.timestamp, source: "retry") else { return XCTFail("FX retry") }
    }
    func testDuplicateCurrencyRefundAndBoundaryRules() {
        let date = Date()
        let tx = Transaction(amount: -38, currency: "₪", merchant: "Wolt", category: .food,
                             timestamp: date, originalAmount: 10, originalCurrency: "$")
        XCTAssertTrue(TransactionIngest.isDuplicate(merchant: " Wolt ", amount: -10, currency: "USD", date: date.addingTimeInterval(15), in: [tx]))
        XCTAssertFalse(TransactionIngest.isDuplicate(merchant: "Wolt", amount: 10, currency: "USD", date: date, in: [tx]))
        XCTAssertFalse(TransactionIngest.isDuplicate(merchant: "Wolt", amount: -10, currency: "EUR", date: date, in: [tx]))
        XCTAssertFalse(TransactionIngest.isDuplicate(merchant: "Wolt", amount: -10, currency: "USD", date: date.addingTimeInterval(16), in: [tx]))
    }
    func testPendingDedupUsesCurrencyAliasesAcrossTimeBuckets() {
        let store = PendingWalletStore(defaults: UserDefaults(suiteName: "IngestTests.\(UUID())")!)
        let date = Date()
        let first = store.findOrRegister(merchant: " Wolt ", currency: "USD", categoryRawValue: "food", buildingId: nil, date: date)
        let retry = store.findOrRegister(merchant: "wolt", currency: "$", categoryRawValue: "food", buildingId: nil, date: date.addingTimeInterval(15), source: "otherIntent")
        XCTAssertFalse(retry.isNew)
        XCTAssertEqual(first.ingest.id, retry.ingest.id)
    }
}

#if canImport(JavaScriptCore)
import JavaScriptCore

final class DioramaContractTests: XCTestCase {
    func testSwiftPayloadPassesRendererContractAndInvalidPayloadIsRejected() throws {
        let payload = ThreeDioramaView.DioramaDataPayload(
            food: 0, foodSub: .init(restaurant: 0, groceries: 0, coffee: 0, delivery: 0),
            shopping: 0, shoppingSub: .init(fashion: 0, tech: 0, travel: 0, entertainment: 0),
            housing: 0, housingSub: .init(rent: 0, utilities: 0, subs: 0), transport: 0, savings: 0,
            savingsTarget: 0, parkHealth: 1, otherAmount: 0, museumAmount: 0, healthAmount: 0, financeAmount: 0,
            districts: [.init(id: "food", amount: 0, share: 0, activity: 0, prominence: "active")],
            venues: [], pendingSortingCount: 0, targetDistrict: nil, language: "he", enrichments: [],
            newlyUnlockedId: nil, slotPlacements: [:],
            habits: .init(woltCount: 0, coffeeCount: 0, onlinePackagesCount: 0, hasTravelOrFlight: false, activeSubscriptionsCount: 0))
        let json = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
        let htmlURL = try XCTUnwrap(Bundle.main.url(forResource: "diorama", withExtension: "html"))
        let html = try String(contentsOf: htmlURL)
        func section(_ start: String, _ end: String) throws -> String {
            let a = try XCTUnwrap(html.range(of: start)).lowerBound
            let b = try XCTUnwrap(html.range(of: end, range: a..<html.endIndex)).lowerBound
            return String(html[a..<b])
        }
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript(try section("const buildingDistrictKeys =", "let districtStates"))
        context.evaluateScript(try section("function validateDioramaPayload", "function reportDioramaError"))
        context.evaluateScript("var payload = \(json); validateDioramaPayload(payload);")
        XCTAssertNil(context.exception, "Swift encoding must satisfy the shipped JS validator")
        for mutation in ["payload.schemaVersion = 99", "payload.food = 'invalid'",
                         "payload.districts[0].id = 'unknown'", "payload.districts.push(payload.districts[0])",
                         "payload.venues = [{id:'unknown'}]", "delete payload.habits",
                         "payload.tutorialBuildingId = 'unknown'", "payload.tutorialBuildingId = 42"] {
            context.exception = nil
            context.evaluateScript("payload = \(json); \(mutation); validateDioramaPayload(payload);")
            XCTAssertNotNil(context.exception, mutation)
        }
        context.exception = nil
        context.evaluateScript("payload = \(json); payload.tutorialBuildingId = 'food_coffee'; validateDioramaPayload(payload);")
        XCTAssertNil(context.exception)
    }
}
#endif
