import XCTest
@testable import MoneyCity

/// The Wallet automation does not reliably fill the field it is mapped to. These cases use
/// the real merchant strings from Isracard's own notifications, because that is what the
/// payload actually looks like.
final class SalvageTests: XCTestCase {

    func testNormalPayloadPassesThrough() {
        let out = TransactionIngest.salvage(amount: 6.00, amountText: nil, merchant: "Chacoli")
        XCTAssertEqual(out.amount, 6.00)
        XCTAssertEqual(out.merchant, "Chacoli")
    }

    func testAmountArrivingOnlyAsTextIsRecovered() {
        let out = TransactionIngest.salvage(amount: 0, amountText: "6.00", merchant: "Chacoli")
        XCTAssertEqual(out.amount, 6.00)
    }

    func testWholeDescriptionInTheMerchantFieldIsSplitApart() {
        let out = TransactionIngest.salvage(amount: 0, amountText: nil, merchant: "Chacoli ₪6.00")
        XCTAssertEqual(out.amount, 6.00)
        XCTAssertEqual(out.merchant, "Chacoli")
    }

    func testWholeDescriptionInTheAmountTextFieldIsSplitApart() {
        let out = TransactionIngest.salvage(amount: 0, amountText: "Chacoli ₪6.00", merchant: nil)
        XCTAssertEqual(out.amount, 6.00)
        XCTAssertEqual(out.merchant, "Chacoli")
    }

    /// The important one: a number inside a shop's NAME must never become the charge.
    func testANumberInTheShopNameIsNotTreatedAsAnAmount() {
        let out = TransactionIngest.salvage(amount: 0, amountText: nil, merchant: "Kokpit 67")
        XCTAssertNil(out.amount, "₪67 would be invented instead of the real ₪115")
        XCTAssertEqual(out.merchant, "Kokpit")
    }

    func testTheSameShopWithARealAmountKeepsTheRealAmount() {
        let out = TransactionIngest.salvage(amount: 115.00, amountText: nil, merchant: "Kokpit 67")
        XCTAssertEqual(out.amount, 115.00)
    }

    func testPunctuatedNamesSurvive() {
        XCTAssertEqual(TransactionIngest.salvage(amount: 9.90, amountText: nil, merchant: "AM:PM").merchant, "AM:PM")
        XCTAssertEqual(TransactionIngest.salvage(amount: 13.00, amountText: nil, merchant: "k.j").merchant, "k.j")
        XCTAssertEqual(
            TransactionIngest.salvage(amount: 22.00, amountText: nil, merchant: "GMF* Toms And Ko Bam").merchant,
            "GMF* Toms And Ko Bam"
        )
    }

    func testAnEmptyPayloadYieldsNothingRatherThanAGuess() {
        let out = TransactionIngest.salvage(amount: 0, amountText: nil, merchant: nil)
        XCTAssertNil(out.amount)
        XCTAssertNil(out.merchant)

        let blanks = TransactionIngest.salvage(amount: 0, amountText: "", merchant: " ")
        XCTAssertNil(blanks.amount)
        XCTAssertNil(blanks.merchant)
    }

    func testAmountLikeValueRequiresAMoneyMarker() {
        // Decimal digits count as a money marker.
        XCTAssertEqual(TransactionIngest.amountLikeValue(in: "Toms 22.00"), 22.00)
        // A currency symbol counts.
        XCTAssertEqual(TransactionIngest.amountLikeValue(in: "Chacoli ₪6"), 6.00)
        // A bare integer does not.
        XCTAssertNil(TransactionIngest.amountLikeValue(in: "Kokpit 67"))
        XCTAssertNil(TransactionIngest.amountLikeValue(in: "Terminal 21"))
        XCTAssertNil(TransactionIngest.amountLikeValue(in: nil))
    }

    func testNameWithoutAmountRejectsTextThatIsOnlyANumber() {
        XCTAssertNil(TransactionIngest.nameWithoutAmount("₪6.00"))
        XCTAssertNil(TransactionIngest.nameWithoutAmount("  -  "))
        XCTAssertEqual(TransactionIngest.nameWithoutAmount("Chacoli ₪6.00"), "Chacoli")
    }
}

/// Shortcuts lets every parameter be mapped to the same transaction input. These guards
/// stop the whole description from being stored as a currency or a timestamp.
final class WrongFieldGuardTests: XCTestCase {

    func testARealCurrencyIsAccepted() {
        XCTAssertEqual(TransactionIngest.sanitizedCurrency("₪"), "₪")
        XCTAssertEqual(TransactionIngest.sanitizedCurrency(" USD "), "USD")
        XCTAssertEqual(TransactionIngest.sanitizedCurrency("$"), "$")
    }

    func testTheWholeDescriptionIsRefusedAsACurrency() {
        // Mapping Shortcut Input to the currency field used to store this verbatim.
        XCTAssertNil(TransactionIngest.sanitizedCurrency("Chacoli ₪6.00"))
        XCTAssertNil(TransactionIngest.sanitizedCurrency("Kokpit 67"))
        XCTAssertNil(TransactionIngest.sanitizedCurrency("6.00"))
        XCTAssertNil(TransactionIngest.sanitizedCurrency(""))
        XCTAssertNil(TransactionIngest.sanitizedCurrency("   "))
        XCTAssertNil(TransactionIngest.sanitizedCurrency(nil))
    }

    func testAPlausibleDateIsKept() {
        let now = Date()
        XCTAssertNotNil(TransactionIngest.sanitizedDate(now, now: now))
        XCTAssertNotNil(TransactionIngest.sanitizedDate(now.addingTimeInterval(-86_400 * 30), now: now))
    }

    func testAnImplausibleDateIsRefusedSoItCannotCorruptAMonth() {
        let now = Date()
        XCTAssertNil(TransactionIngest.sanitizedDate(Date(timeIntervalSince1970: 0), now: now))
        XCTAssertNil(TransactionIngest.sanitizedDate(now.addingTimeInterval(86_400 * 800), now: now))
        XCTAssertNil(TransactionIngest.sanitizedDate(nil, now: now))
    }
}

/// The single-field action hands the same payload to both text slots and relies entirely on
/// salvage. These pin down that one field really is enough.
final class SingleFieldPayloadTests: XCTestCase {

    private func viaSingleField(_ payload: String?) -> TransactionIngest.Salvaged {
        // Mirrors LogWalletPaymentIntent: one value, given to both slots.
        TransactionIngest.salvage(amount: nil, amountText: payload, merchant: payload)
    }

    func testOneFieldCarryingTheWholeDescriptionIsEnough() {
        let out = viaSingleField("Chacoli ₪6.00")
        XCTAssertEqual(out.amount, 6.00)
        XCTAssertEqual(out.merchant, "Chacoli")
    }

    func testRealPayloadsFromTheLockScreen() {
        XCTAssertEqual(viaSingleField("Kokpit 67 ₪115.00").amount, 115.00)
        XCTAssertEqual(viaSingleField("Kokpit 67 ₪115.00").merchant, "Kokpit")
        XCTAssertEqual(viaSingleField("AM:PM ₪9.90").amount, 9.90)
        XCTAssertEqual(viaSingleField("AM:PM ₪9.90").merchant, "AM:PM")
        XCTAssertEqual(viaSingleField("GMF* Toms And Ko Bam ₪22.00").amount, 22.00)
    }

    func testAMerchantOnlyPayloadStillYieldsAMerchant() {
        let out = viaSingleField("Chacoli")
        XCTAssertNil(out.amount)
        XCTAssertEqual(out.merchant, "Chacoli")
    }

    func testAnAmountOnlyPayloadStillYieldsAnAmount() {
        let out = viaSingleField("6.00")
        XCTAssertEqual(out.amount, 6.00)
        XCTAssertNil(out.merchant, "digits alone are not a shop name")
    }

    func testAnEmptyPayloadYieldsNothing() {
        XCTAssertNil(viaSingleField(nil).amount)
        XCTAssertNil(viaSingleField("").merchant)
    }

    func testJSONPayloadsAreDecodedCorrectly() {
        let jsonStr = #"{"amount": 45.90, "merchant": "AM:PM", "card": "Visa"}"#
        let out = viaSingleField(jsonStr)
        XCTAssertEqual(out.amount, 45.90)
        XCTAssertEqual(out.merchant, "AM:PM")

        let jsonAlternate = #"{"Amount": "12.90", "Name": "Cofix"}"#
        let out2 = viaSingleField(jsonAlternate)
        XCTAssertEqual(out2.amount, 12.90)
        XCTAssertEqual(out2.merchant, "Cofix")
    }
}
