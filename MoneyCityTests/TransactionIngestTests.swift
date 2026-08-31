import XCTest
@testable import MoneyCity

/// Covers the Apple Pay / Wallet ingest path — the part of the app that runs unattended,
/// where a bad payload turns into a wrong number in someone's finances.
final class TransactionIngestTests: XCTestCase {

    // MARK: - Amount recovery

    func testAmountUsesNumericParameterWhenValid() {
        XCTAssertEqual(TransactionIngest.normalizedAmount(85.5, nil), 85.5)
        // A text fallback must never override a good numeric value.
        XCTAssertEqual(TransactionIngest.normalizedAmount(85.5, "999"), 85.5)
    }

    func testAmountFallsBackToTextWhenShortcutsSendsZero() {
        // The documented Shortcuts defect: Double arrives as 0.0.
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "24.00"), 24.0)
        XCTAssertEqual(TransactionIngest.normalizedAmount(nil, "24.00"), 24.0)
    }

    func testAmountParsesLocalisedAndCurrencyDecoratedText() {
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "₪45.90"), 45.90)
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "24,00"), 24.0)          // decimal comma
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "1,234.50"), 1234.50)    // US grouping
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "1.234,50"), 1234.50)    // EU grouping
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "1,234"), 1234.0)        // grouping, no decimals
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, " 320 ₪ "), 320.0)
    }

    /// The Wallet text payload is not clean. Each of these produced a WRONG number or a
    /// silent drop before the parser was rewritten.
    func testAmountIgnoresDigitsThatAreNotThePrice() {
        // A card suffix used to fuse onto the amount: "Visa 1234 - 45.90" -> 123445.90
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "Visa 1234 - 45.90"), 45.90)
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "2 items 45.90"), 45.90)
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "45.90 for 2 items"), 45.90)
    }

    func testGroupingWithoutDecimalsIsNotMistakenForAFraction() {
        // "1.850" is 1850 in EU notation; it used to parse as 1.85.
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "1.850"), 1850.0)
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "1.234.567"), 1234567.0)
    }

    func testRefundsAreRefusedRatherThanBookedAsCharges() {
        // The minus sign used to be stripped, turning a ₪450 refund into a ₪450 expense.
        XCTAssertNil(TransactionIngest.normalizedAmount(0, "-450.00"))
        XCTAssertNil(TransactionIngest.normalizedAmount(0, "\u{2212}450.00"))
        XCTAssertNil(TransactionIngest.normalizedAmount(0, "(450.00)"))
    }

    func testNonLatinDigitsAreUnderstoodRatherThanDropped() {
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "٣٢٠"), 320.0)
        XCTAssertEqual(TransactionIngest.normalizedAmount(0, "45.90 ½"), 45.90)
    }

    func testGenuinelyAmbiguousTextIsRefusedRatherThanGuessed() {
        // Two bare numbers, no separator to tell them apart — refuse, do not pick one.
        XCTAssertNil(TransactionIngest.normalizedAmount(0, "Visa 1234 - 450"))
    }

    func testAmountRejectsUnusableInput() {
        XCTAssertNil(TransactionIngest.normalizedAmount(0, nil))
        XCTAssertNil(TransactionIngest.normalizedAmount(0, ""))
        XCTAssertNil(TransactionIngest.normalizedAmount(0, "   "))
        XCTAssertNil(TransactionIngest.normalizedAmount(0, "abc"))
        XCTAssertNil(TransactionIngest.normalizedAmount(-5, nil))
        XCTAssertNil(TransactionIngest.normalizedAmount(0, "-45.90"))
        XCTAssertNil(TransactionIngest.normalizedAmount(0, "0"))
        XCTAssertNil(TransactionIngest.normalizedAmount(0, "0.00"))
    }

    // MARK: - Merchant recovery

    func testMerchantTrimsAndRejectsBlank() {
        XCTAssertEqual(TransactionIngest.normalizedMerchant("  ארומה קפה  "), "ארומה קפה")
        XCTAssertNil(TransactionIngest.normalizedMerchant(nil))
        XCTAssertNil(TransactionIngest.normalizedMerchant(""))
        // Wallet is reported to send a single space rather than a name.
        XCTAssertNil(TransactionIngest.normalizedMerchant(" "))
    }

    func testIsraeliApplePayNotificationFormats() {
        // 1. Isracard with district prefix and trailing price
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("Isracard\nמחוז תל אביב תל אביב-יפו, Chacoli, ₪ 6.00"),
            "Chacoli"
        )
        // 2. Gateway prefix GMF* and location prefix with ellipsis
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("מחוז... גבעתיים, GMF* Toms And Ko Bam, ₪ 22.00"),
            "GMF* Toms And Ko Bam"
        )
        // 3. District with street number in name
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("מחוז תל אביב גבעתיים, Kokpit 67, ₪ 115.00"),
            "Kokpit 67"
        )
        // 4. District with known merchant AM:PM
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("מחוז תל אביב תל אביב-יפו, AM:PM, ₪ 9.90"),
            "AM:PM"
        )
        // 5. Payment processor prefix without district
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("PAY* ארומה דיזינגוף"),
            "PAY* ארומה דיזינגוף"
        )
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("Z- רמי לוי שיווק השקמה"),
            "Z- רמי לוי שיווק השקמה"
        )
        // 5. Payment processor prefix without district
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("מחוז תל אביב גבעתיים, k.j, ₪ 13.00"),
            "k.j"
        )
        // 6. CAL format
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("Cal: חיוב בסך 120.00 ש\"ח ב-ZARA TLV"),
            "ZARA TLV"
        )
        // 7. MAX push notification
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("מקס: עסקה באפל פיי בסך 58.00 ש״ח ב-AM:PM"),
            "AM:PM"
        )
        // 8. Bank SMS sentence format
        XCTAssertEqual(
            TransactionIngest.normalizedMerchant("לאומי: אושרה עסקה ע״ס 89.90 ₪ בבית העסק Wolt"),
            "Wolt"
        )
    }

    func testExtractAmountFromMerchantStringWhenAmountIsNil() throws {
        // 1. User's exact payload where Shortcuts passes the full notification into merchant with amount = nil
        let tx1 = try TransactionIngest.makeTransaction(
            amount: nil,
            amountText: nil,
            merchant: "Isracard\nמחוז תל אביב גבעתיים, k.j,\n₪ 13.00",
            currency: "₪",
            date: Date(),
            existing: []
        )
        XCTAssertEqual(tx1.amount, 13.0)
        XCTAssertEqual(tx1.merchant, "k.j")

        // 2. CAL notification text
        let tx2 = try TransactionIngest.makeTransaction(
            amount: nil,
            amountText: nil,
            merchant: "Cal: חיוב בסך 120.00 ש\"ח ב-ZARA",
            currency: "₪",
            date: Date(),
            existing: []
        )
        XCTAssertEqual(tx2.amount, 120.0)
        XCTAssertEqual(tx2.merchant, "ZARA")

        // 3. MAX notification text
        let tx3 = try TransactionIngest.makeTransaction(
            amount: nil,
            amountText: nil,
            merchant: "מקס - עסקה בסך 24.50 ש״ח ב-ארומה אספרסו בר",
            currency: "₪",
            date: Date(),
            existing: []
        )
        XCTAssertEqual(tx3.amount, 24.50)
        XCTAssertEqual(tx3.merchant, "ארומה אספרסו בר")
    }

    // MARK: - Refusals

    func testEmptyMerchantFallsBackAndRequiresReview() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: 85, amountText: nil, merchant: " ",
            currency: "₪", date: Date(), existing: []
        )
        XCTAssertEqual(tx.amount, 85)
        XCTAssertEqual(tx.merchant, "Apple Pay (לא זוהה)")
        XCTAssertFalse(tx.isConfirmed)
        XCTAssertEqual(tx.confidenceScore, 0.0)
    }

    func testZeroAmountIsRefused() {
        XCTAssertThrowsError(
            try TransactionIngest.makeTransaction(
                amount: 0, amountText: nil, merchant: "שופרסל",
                currency: "₪", date: Date(), existing: []
            )
        ) { error in
            XCTAssertEqual(error as? TransactionIngestError, .missingAmount)
        }
    }

    // MARK: - Duplicate protection

    func testRetriedAutomationDoesNotDoubleCharge() throws {
        let now = Date()
        let first = try TransactionIngest.makeTransaction(
            amount: 85, amountText: nil, merchant: "Wolt משלוחים",
            currency: "₪", date: now, existing: []
        )

        XCTAssertThrowsError(
            try TransactionIngest.makeTransaction(
                amount: 85, amountText: nil, merchant: "Wolt משלוחים",
                currency: "₪", date: now.addingTimeInterval(20), existing: [first]
            )
        ) { error in
            XCTAssertEqual(error as? TransactionIngestError, .duplicate)
        }
    }

    func testGenuineSecondPurchaseLaterIsAccepted() throws {
        let now = Date()
        let first = try TransactionIngest.makeTransaction(
            amount: 24, amountText: nil, merchant: "ארומה קפה",
            currency: "₪", date: now, existing: []
        )
        // Same coffee, hours later — a real second purchase, not a retry.
        let second = try TransactionIngest.makeTransaction(
            amount: 24, amountText: nil, merchant: "ארומה קפה",
            currency: "₪", date: now.addingTimeInterval(3600), existing: [first]
        )
        XCTAssertEqual(second.amount, 24)
    }

    func testDifferentAmountAtSameMerchantIsNotADuplicate() throws {
        let now = Date()
        let first = try TransactionIngest.makeTransaction(
            amount: 24, amountText: nil, merchant: "ארומה קפה",
            currency: "₪", date: now, existing: []
        )
        let second = try TransactionIngest.makeTransaction(
            amount: 31, amountText: nil, merchant: "ארומה קפה",
            currency: "₪", date: now.addingTimeInterval(10), existing: [first]
        )
        XCTAssertEqual(second.amount, 31)
    }

    // MARK: - Classification wiring

    func testKnownMerchantIsClassifiedAndAutoConfirmed() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: 85, amountText: nil, merchant: "Wolt משלוחים",
            currency: "₪", date: Date(), existing: []
        )
        XCTAssertEqual(tx.category, .food)
        XCTAssertEqual(tx.buildingId, "food_wolt")
        XCTAssertFalse(tx.isManual)
        XCTAssertTrue(tx.isConfirmed)
    }

    func testUnknownMerchantIsParkedForUserReview() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: 63, amountText: nil, merchant: "QRT-9912 עסק לא מוכר",
            currency: "₪", date: Date(), existing: []
        )
        // The engine guessed; the user must get a chance to correct it.
        XCTAssertLessThan(tx.confidenceScore, 0.8)
        XCTAssertFalse(tx.isConfirmed)
    }

    func testCurrencyIsCarriedThrough() throws {
        let tx = try TransactionIngest.makeTransaction(
            amount: 12, amountText: nil, merchant: "Netflix",
            currency: "$", date: Date(), existing: []
        )
        XCTAssertEqual(tx.originalCurrency, "$")
        XCTAssertEqual(tx.originalAmount, 12.0)
        XCTAssertEqual(tx.currency, "₪")
        XCTAssertGreaterThan(tx.amount, 12.0)
        XCTAssertEqual(tx.category, .subscriptions)
    }
}
