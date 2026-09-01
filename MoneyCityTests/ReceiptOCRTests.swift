import XCTest
@testable import MoneyCity

final class ReceiptOCRTests: XCTestCase {

    // 1. Bit Payment Confirmation Screenshot
    func testBitPaymentScreenshotParsing() {
        let bitLines = [
            "העברת ליוני כהן",
            "סכום: ₪ 140.00",
            "תאריך: 15/08/2026",
            "אישור עסקה: 982341",
            "bit"
        ]

        let result = ReceiptOCRService.parseReceipt(from: bitLines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 140.0)
        XCTAssertEqual(result?.merchant, "יוני כהן")
    }

    // 2. Wolt Delivery Receipt
    func testWoltReceiptParsing() {
        let woltLines = [
            "Wolt",
            "הזמנה מביסטרו גוז׳ ודניאל",
            "פריטים: 2",
            "דמי משלוח: ₪14.00",
            "סך הכל לתשלום: ₪ 185.50",
            "שולם באמצעות Apple Pay"
        ]

        let result = ReceiptOCRService.parseReceipt(from: woltLines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 185.50)
        XCTAssertEqual(result?.merchant, "Wolt")
        XCTAssertEqual(result?.category, .food)
    }

    // 3. Shufersal Supermarket Invoice
    func testShufersalInvoiceParsing() {
        let superLines = [
            "שופרסל דיל סניף תל אביב",
            "חשבונית מס קבלה מקור",
            "חלב תנובה 3% ₪ 6.80",
            "לחם אחיד פרוס ₪ 7.20",
            "גבינה צהובה עמק ₪ 18.90",
            "סה\"כ לתשלום: 32.90 ש״ח",
            "תאריך 02/09/2026 שעה 14:35"
        ]

        let result = ReceiptOCRService.parseReceipt(from: superLines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 32.90)
        XCTAssertEqual(result?.merchant, "שופרסל")
        XCTAssertEqual(result?.category, .food)
    }

    // 4. ZARA Shopping Receipt
    func testZaraShoppingReceiptParsing() {
        let zaraLines = [
            "ZARA ISRAEL",
            "קניון רמת אביב",
            "חולצת כותנה טי שירט",
            "ג'ינס סקיני שחור",
            "TOTAL ₪ 349.00",
            "VISA **** 1234"
        ]

        let result = ReceiptOCRService.parseReceipt(from: zaraLines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 349.00)
        XCTAssertEqual(result?.merchant, "ZARA")
        XCTAssertEqual(result?.category, .shopping)
    }

    // 5. Credit Card SMS Screenshot
    func testCreditCardSMSScreenshot() {
        let smsLines = [
            "הודעה מאת Isracard",
            "עסקה בסך 78.00 ₪ ב-AM:PM",
            "אושרה בתאריך 28/08/2026"
        ]

        let result = ReceiptOCRService.parseReceipt(from: smsLines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 78.00)
        XCTAssertEqual(result?.merchant, "AM:PM")
        XCTAssertEqual(result?.category, .food)
    }

    // 6. Generic Shop Header Detection
    func testGenericShopHeaderDetection() {
        let lines = [
            "קפה נחת דיזינגוף",
            "חשבונית מס קבלה",
            "אספרסו כפול 14.00",
            "עוגיית שוקולד 16.00",
            "סך הכל: 30.00 ש\"ח"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 30.00)
        XCTAssertEqual(result?.merchant, "קפה נחת דיזינגוף")
    }

    // 7. Date Extraction Accuracy
    func testDateExtractionAccuracy() {
        let lines = [
            "קבלה מס 40912",
            "תאריך: 14.07.2026",
            "סך הכל: ₪ 55.00"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.date)
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let comps = calendar.dateComponents([.year, .month, .day], from: result!.date!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.day, 14)
    }

    // 8. Thousands Separator & Card Digits Guard
    func testThousandsSeparatorAndCardDigits() {
        let lines = [
            "MAX הודעת חיוב",
            "אושרה עסקתך ב-KSP בסך ₪1,299.00 בכרטיס מסתיים 4589",
            "תאריך: 31/08/2026 11:00"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 1299.0)
        XCTAssertEqual(result?.merchant, "KSP")
        XCTAssertEqual(result?.category, .shopping)
    }

    // 9. Loyalty Club Points & Barcode Noise Filtering
    func testLoyaltyPointsDoesNotOverrideTotal() {
        let lines = [
            "סופר-פארם סניף דיזנגוף סנטר",
            "שמפו הד אנד שולדרס ₪ 24.90",
            "משחת שיניים קולגייט ₪ 15.00",
            "סה\"כ לתשלום: ₪ 39.90",
            "שולם באשראי",
            "מועדון לייף סטייל: צברת 5,000 נקודות"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 39.90)
        XCTAssertEqual(result?.merchant, "סופר-פארם")
    }

    // 10. Pango Parking Receipt
    func testPangoParkingReceipt() {
        let lines = [
            "פנגו - סיום חניה בכחול לבן",
            "עיריית תל אביב",
            "משך החניה: שעה ו-20 דקות",
            "סכום החיוב: ₪ 18.50"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 18.50)
        XCTAssertEqual(result?.merchant, "פנגו Pango")
        XCTAssertEqual(result?.category, .transport)
    }
}

// MARK: - Regressions

/// Every amount over three digits without a thousands comma used to be divided by ten and
/// still look plausible, because the amount pattern's first alternative matched 1-3 digits
/// on its own and alternation is leftmost-first. OCR almost never produces a thousands
/// comma, so this hit most real receipts over ₪999.
final class ReceiptAmountTruncationTests: XCTestCase {

    private func amount(_ line: String) -> Double? {
        ReceiptOCRService.extractAmount(from: ["חשבונית מס", line, "תודה ולהתראות"])
    }

    func testFourDigitTotalIsNotTruncated() {
        XCTAssertEqual(amount("סך הכל לתשלום 1450.50 ₪"), 1450.50)
    }

    func testRoundThousandsTotalIsNotTruncated() {
        XCTAssertEqual(amount("סך הכל לתשלום ₪3200.00"), 3200.00)
    }

    func testWholeShekelThousandsTotalIsNotTruncated() {
        XCTAssertEqual(amount("סכום החיוב ₪ 8500"), 8500.00)
    }

    func testFiveDigitTotalIsNotTruncated() {
        XCTAssertEqual(amount("סה\"כ לתשלום 12500"), 12500.00)
    }

    func testGroupedThousandsStillParse() {
        XCTAssertEqual(amount("סך הכל לתשלום ₪1,450.50"), 1450.50)
    }

    func testCommaAsDecimalIsOneNumberNotTwo() {
        XCTAssertEqual(amount("סכום לתשלום 140,50 ₪"), 140.50)
    }

    func testSmallAmountsAreUnaffected() {
        XCTAssertEqual(amount("סה\"כ לתשלום ₪45.90"), 45.90)
        XCTAssertEqual(amount("סה\"כ לתשלום ₪999"), 999.00)
    }

    func testCardNumberDoesNotBecomeAnAmount() {
        // A 16-digit run used to be chopped into six plausible three-digit "amounts".
        XCTAssertNil(amount("כרטיס 4580123456781234"))
    }
}

/// Merchant keys as short as two Hebrew letters were matched with a plain `contains` over
/// the whole receipt, so "כרטיס אשראי" — which is on nearly every Israeli card slip —
/// matched "יס" and filed the purchase under a TV provider.
final class ReceiptMerchantTokenTests: XCTestCase {

    private func merchant(_ lines: [String]) -> String? {
        ReceiptOCRService.extractMerchant(from: lines)
    }

    func testCreditCardWordingIsNotReadAsYES() {
        XCTAssertNotEqual(merchant(["מסעדת הבית", "כרטיס אשראי 1234", "סה\"כ 120"]), "YES")
    }

    func testCardNumberLabelIsNotReadAsYES() {
        XCTAssertNotEqual(merchant(["פיצה מאמא", "מספר כרטיס", "סה\"כ 60"]), "YES")
    }

    func testRealYesBillIsStillRecognised() {
        XCTAssertEqual(merchant(["יס", "חיוב חודשי", "סה\"כ 219"]), "YES")
    }

    func testLongMerchantKeySurvivesHebrewPrefix() {
        XCTAssertEqual(merchant(["קניתי בסופרפארם דיזנגוף", "סה\"כ 88"]), "סופר-פארם")
    }
}
