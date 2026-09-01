import XCTest
@testable import MoneyCity

/// Snapshots are the app's rollback for the one failure that actually happens — a new build
/// whose migration does not go through. The naming and retention rules are what make the
/// folder a usable history instead of an unbounded second copy of the database.
final class StoreSnapshotNamingTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0, _ sec: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi, second: sec))!
    }

    func testFolderNamesSortChronologicallyAsText() {
        // The listing sorts by name; if that ever stopped matching time order, "restore the
        // newest" would quietly restore something else.
        let older = StoreSnapshotService.folderName(for: date(2026, 9, 1, 9), build: "40")
        let newer = StoreSnapshotService.folderName(for: date(2026, 9, 1, 17), build: "41")
        let nextYear = StoreSnapshotService.folderName(for: date(2027, 1, 3, 8), build: "42")
        XCTAssertLessThan(older, newer)
        XCTAssertLessThan(newer, nextYear)
    }

    func testFolderNameCarriesTheBuild() {
        XCTAssertTrue(StoreSnapshotService.folderName(for: date(2026, 9, 1), build: "47").hasSuffix("-build47"))
    }

    func testFolderNameSurvivesAnEmptyBuildNumber() {
        XCTAssertTrue(StoreSnapshotService.folderName(for: date(2026, 9, 1), build: "").hasSuffix("-build0"))
    }

    func testNothingIsPrunedWhileUnderTheLimit() {
        let names = ["2026-09-01-100000-build1", "2026-09-02-100000-build2"]
        XCTAssertTrue(StoreSnapshotService.foldersToPrune(names, keep: 3).isEmpty)
    }

    func testTheOldestAreDroppedFirst() {
        let names = [
            "2026-09-01-100000-build1",
            "2026-09-02-100000-build2",
            "2026-09-03-100000-build3",
            "2026-09-04-100000-build4",
            "2026-09-05-100000-build5"
        ]
        XCTAssertEqual(
            StoreSnapshotService.foldersToPrune(names, keep: 3).sorted(),
            ["2026-09-01-100000-build1", "2026-09-02-100000-build2"]
        )
    }

    func testPruningIsIndependentOfListingOrder() {
        let shuffled = ["2026-09-03-100000-build3", "2026-09-01-100000-build1", "2026-09-02-100000-build2"]
        XCTAssertEqual(StoreSnapshotService.foldersToPrune(shuffled, keep: 2), ["2026-09-01-100000-build1"])
    }

    func testKeepingNoneDropsEverything() {
        let names = ["2026-09-01-100000-build1", "2026-09-02-100000-build2"]
        XCTAssertEqual(StoreSnapshotService.foldersToPrune(names, keep: 0).count, 2)
    }

    func testTheStoreJournalFilesAreIncluded() {
        // Copying default.store on its own can capture a torn write; the -wal file is part
        // of the database, not a temporary.
        XCTAssertTrue(StoreSnapshotService.storeFileNames.contains("default.store"))
        XCTAssertTrue(StoreSnapshotService.storeFileNames.contains("default.store-wal"))
        XCTAssertTrue(StoreSnapshotService.storeFileNames.contains("default.store-shm"))
    }
}

/// The export file is the only copy of the user's data that is readable without this app, so
/// its shape has to survive a round trip exactly, and a file that is not ours has to be
/// refused rather than half-imported.
final class BackupEnvelopeTests: XCTestCase {

    private func envelope(transactions: [DataPortabilityService.TransactionDTO] = []) -> DataPortabilityService.Envelope {
        DataPortabilityService.Envelope(
            format: DataPortabilityService.formatIdentifier,
            formatVersion: DataPortabilityService.formatVersion,
            appVersion: "1.0", appBuild: "47",
            exportedAt: Date(timeIntervalSince1970: 1_788_000_000),
            transactions: transactions, recurring: [], income: [], budgets: [],
            merchantRules: [], installments: [], savingsGoals: [], enrichments: []
        )
    }

    private func sampleTransaction() -> DataPortabilityService.TransactionDTO {
        DataPortabilityService.TransactionDTO(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            amount: 1450.50, currency: "₪", merchant: "סופר-פארם",
            category: "groceries", timestamp: Date(timeIntervalSince1970: 1_787_900_000),
            confidenceScore: 0.94, isManual: false, isConfirmed: true,
            note: "הערה", buildingId: "food_super",
            originalAmount: 380.0, originalCurrency: "$", exchangeRate: 3.81,
            savingsGoalId: nil
        )
    }

    func testATransactionSurvivesTheRoundTripExactly() throws {
        let original = envelope(transactions: [sampleTransaction()])
        let data = try DataPortabilityService.makeEncoder().encode(original)
        let back = try DataPortabilityService.makeDecoder()
            .decode(DataPortabilityService.Envelope.self, from: data)

        XCTAssertEqual(back.transactions.count, 1)
        let t = back.transactions[0]
        XCTAssertEqual(t.id, original.transactions[0].id)
        XCTAssertEqual(t.amount, 1450.50, accuracy: 0.0001)
        XCTAssertEqual(t.merchant, "סופר-פארם")
        XCTAssertEqual(t.currency, "₪")
        XCTAssertEqual(t.category, "groceries")
        XCTAssertEqual(t.note, "הערה")
        XCTAssertEqual(t.originalCurrency, "$")
        XCTAssertEqual(t.exchangeRate, 3.81)
        XCTAssertEqual(t.timestamp.timeIntervalSince1970,
                       original.transactions[0].timestamp.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    func testDatesAreWrittenAsReadableISO8601() throws {
        // A backup should still make sense to a person, and to a reader that is not this
        // build, years from now — not as a floating-point offset from 2001.
        let data = try DataPortabilityService.makeEncoder().encode(envelope())
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("2026-"), "expected an ISO-8601 date, got: \(text.prefix(300))")
    }

    func testTheEnvelopeIdentifiesItself() throws {
        let data = try DataPortabilityService.makeEncoder().encode(envelope())
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("moneycity.backup"))
    }

    func testAFileThatIsNotABackupIsRejected() throws {
        let foreign = #"{"format":"something.else","formatVersion":1}"#.data(using: .utf8)!
        XCTAssertThrowsError(
            try DataPortabilityService.makeDecoder()
                .decode(DataPortabilityService.Envelope.self, from: foreign)
        )
    }

    func testTotalRecordsCountsEveryKind() {
        var e = envelope(transactions: [sampleTransaction(), sampleTransaction()])
        e.savingsGoals = [
            DataPortabilityService.SavingsGoalDTO(
                id: UUID(), name: "טיול", icon: "✈️", targetAmount: 4000, savedAmount: 500,
                currency: "₪", targetDate: nil, createdAt: Date(), completedAt: nil,
                unlinkedBaseline: 0, baselineCaptured: true
            )
        ]
        XCTAssertEqual(e.totalRecords, 3)
    }

    func testSuggestedFileNameSortsAndSaysWhatItIs() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        let d = c.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 14, minute: 32))!
        let name = DataPortabilityService.suggestedFileName(now: d)
        XCTAssertTrue(name.hasPrefix("MoneyCity-2026-09-01-"))
        XCTAssertTrue(name.hasSuffix(".json"))
    }
}
