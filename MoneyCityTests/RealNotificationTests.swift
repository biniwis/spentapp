import XCTest
@testable import MoneyCity

/// End-to-end cases built from the actual Isracard notifications on the user's lock screen.
///
/// These are not invented samples. Each one is a real payment that the automation failed to
/// record, and each payload shape below is a plausible thing Shortcuts hands the intent
/// depending on how the input is mapped. The pipeline has to produce the right number, or a
/// clean refusal, in every one of them.
final class RealNotificationTests: XCTestCase {

    private struct Payment {
        let merchant: String
        let amount: Double
        let location: String
        /// What the merchant should be called once the location prefix is stripped.
        let expectedName: String
    }

    private let payments: [Payment] = [
        Payment(merchant: "Chacoli",              amount: 6.00,   location: "מחוז תל אביב תל אביב-יפו", expectedName: "Chacoli"),
        Payment(merchant: "GMF* Toms And Ko Bam", amount: 22.00,  location: "מחוז גבעתיים",             expectedName: "GMF* Toms And Ko Bam"),
        Payment(merchant: "Kokpit 67",            amount: 115.00, location: "מחוז תל אביב גבעתיים",     expectedName: "Kokpit"),
        Payment(merchant: "AM:PM",                amount: 9.90,   location: "מחוז תל אביב תל אביב-יפו", expectedName: "AM:PM"),
        Payment(merchant: "k.j",                  amount: 13.00,  location: "מחוז תל אביב גבעתיים",     expectedName: "k.j"),
        Payment(merchant: "שופרסל",                amount: 47.25,  location: "גבעתיים, מחוז תל אביב",     expectedName: "שופרסל"),
        Payment(merchant: "Homos Givatayim",      amount: 18.00,  location: "מחוז תל אביב גבעתיים",     expectedName: "Homos Givatayim")
    ]

    /// Mirrors LogWalletPaymentIntent: one free-text field, strict amount detection.
    private func viaSingleField(_ payload: String?) -> TransactionIngest.Salvaged {
        TransactionIngest.salvage(amount: nil, amountText: nil, merchant: payload)
    }

    // MARK: - Shape 1: the automation maps Amount and Merchant separately

    func testSeparateFieldsRecordEveryPayment() {
        for p in payments {
            let out = TransactionIngest.salvage(amount: p.amount, amountText: nil, merchant: p.merchant)
            XCTAssertEqual(out.amount, p.amount, "\(p.merchant)")
            XCTAssertEqual(out.merchant, p.expectedName, "\(p.merchant)")
        }
    }

    // MARK: - Shape 2: one field holding "name + amount"

    func testOneFieldWithNameAndAmount() {
        for p in payments {
            let out = viaSingleField("\(p.merchant) ₪\(String(format: "%.2f", p.amount))")
            XCTAssertEqual(out.amount, p.amount, "\(p.merchant)")
            XCTAssertEqual(out.merchant, p.expectedName, "\(p.merchant)")
        }
    }

    // MARK: - Shape 3: one field holding the whole notification line

    func testOneFieldWithTheFullNotificationLine() {
        for p in payments {
            // e.g. "מחוז תל אביב תל אביב-יפו, Chacoli ₪ 6.00"
            let line = "\(p.location), \(p.merchant) ₪ \(String(format: "%.2f", p.amount))"
            let out = viaSingleField(line)
            XCTAssertEqual(out.amount, p.amount, "\(p.merchant)")
            // The district prefix must not become part of the shop's name.
            XCTAssertEqual(out.merchant, p.expectedName, "\(p.merchant)")
        }
    }

    // MARK: - Shape 4: only the merchant arrives

    func testNameOnlyIsParkedForReviewInsteadOfInventingAnAmount() {
        for p in payments {
            let out = viaSingleField(p.merchant)
            XCTAssertNil(out.amount, "\(p.merchant) — a number in a shop name is not a charge")
            XCTAssertEqual(out.merchant, p.expectedName)
        }
    }

    /// The specific regression: "Kokpit 67" is a bar with a house number, not a ₪67 charge.
    func testAHouseNumberIsNeverBookedAsTheAmount() {
        XCTAssertNil(viaSingleField("Kokpit 67").amount)
        XCTAssertEqual(viaSingleField("Kokpit 67").merchant, "Kokpit")
        // With a real amount attached it must still come through untouched.
        XCTAssertEqual(viaSingleField("Kokpit 67 ₪115.00").amount, 115.00)
    }

    // MARK: - Classification

    func testAnUnknownMerchantIsNotFiledAsFood() {
        // Defaulting to food raised a restaurant in the city for every unrecognised shop.
        let result = CategorizationEngine.shared.classify(merchant: "Chacoli", amount: 6)
        XCTAssertEqual(result.category, .other)
        XCTAssertLessThan(result.confidence, 0.8, "an unknown merchant must go to the review list")
    }

    func testAKnownMerchantIsStillRecognised() {
        // "am:pm" is in the food dictionary.
        let result = CategorizationEngine.shared.classify(merchant: "AM:PM", amount: 9.90)
        XCTAssertEqual(result.category, .food)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.8)
    }

    // MARK: - The whole pipeline

    func testEveryPaymentBecomesACorrectTransaction() throws {
        for p in payments {
            let line = "\(p.location), \(p.merchant) ₪ \(String(format: "%.2f", p.amount))"
            let salvaged = viaSingleField(line)

            let tx = try TransactionIngest.makeTransaction(
                amount: salvaged.amount,
                amountText: nil,
                merchant: salvaged.merchant,
                currency: "₪",
                date: Date(),
                existing: [],
                rules: []
            )

            XCTAssertEqual(tx.amount, p.amount, accuracy: 0.001, "\(p.merchant)")
            XCTAssertEqual(tx.merchant, p.expectedName)
            XCTAssertEqual(tx.currency, "₪")
            XCTAssertFalse(tx.isManual, "this came from the automation, not by hand")
        }
    }

    /// Once the user corrects a merchant, the next payment from it must land correctly and
    /// stop asking — that is the whole point of remembering the correction.
    func testACorrectedMerchantIsClassifiedWithCertaintyNextTime() {
        let rule = MerchantRule(
            merchantKey: MerchantRuleService.normalizedKey("Chacoli"),
            displayName: "Chacoli",
            category: .food
        )
        let result = MerchantRuleService.classify(merchant: "Chacoli", amount: 6, rules: [rule])
        XCTAssertEqual(result.category, .food)
        XCTAssertEqual(result.confidence, 1.0)
    }
}
