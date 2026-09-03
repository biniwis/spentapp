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

// MARK: - Spatial Layout & Multi-Transaction Tests

final class SpatialReceiptTests: XCTestCase {

    func testAliExpressMultiStoreScreenshotWithCoupons() {
        let tokens: [OCRSpatialToken] = [
            // Store 1 Block (y: 0.10 -> 0.35)
            OCRSpatialToken(text: "Storage Global Store", boundingBox: CGRect(x: 0.05, y: 0.10, width: 0.40, height: 0.03), confidence: 0.99),
            OCRSpatialToken(text: "100% Original SanDisk Extreme PRO SD Card", boundingBox: CGRect(x: 0.05, y: 0.14, width: 0.70, height: 0.03), confidence: 0.98),
            OCRSpatialToken(text: "128GB", boundingBox: CGRect(x: 0.05, y: 0.18, width: 0.20, height: 0.02), confidence: 0.95),
            OCRSpatialToken(text: "₪133.37", boundingBox: CGRect(x: 0.70, y: 0.22, width: 0.25, height: 0.03), confidence: 0.99),
            OCRSpatialToken(text: "x1", boundingBox: CGRect(x: 0.75, y: 0.25, width: 0.10, height: 0.02), confidence: 0.95),
            OCRSpatialToken(text: "₪4 coupon if delayed", boundingBox: CGRect(x: 0.05, y: 0.28, width: 0.45, height: 0.02), confidence: 0.94),
            OCRSpatialToken(text: "Track status", boundingBox: CGRect(x: 0.50, y: 0.32, width: 0.20, height: 0.03), confidence: 0.95),
            OCRSpatialToken(text: "Confirm received", boundingBox: CGRect(x: 0.72, y: 0.32, width: 0.25, height: 0.03), confidence: 0.95),

            // Store 2 Block (y: 0.45 -> 0.70)
            OCRSpatialToken(text: "SU CHENG ZI Store", boundingBox: CGRect(x: 0.05, y: 0.45, width: 0.38, height: 0.03), confidence: 0.99),
            OCRSpatialToken(text: "1Pc 35mm Universal Wired In-Ear Earphones", boundingBox: CGRect(x: 0.05, y: 0.49, width: 0.65, height: 0.03), confidence: 0.97),
            OCRSpatialToken(text: "F-White-1.1m", boundingBox: CGRect(x: 0.05, y: 0.53, width: 0.22, height: 0.02), confidence: 0.92),
            OCRSpatialToken(text: "₪8.11", boundingBox: CGRect(x: 0.70, y: 0.57, width: 0.20, height: 0.03), confidence: 0.99),
            OCRSpatialToken(text: "x1", boundingBox: CGRect(x: 0.75, y: 0.60, width: 0.10, height: 0.02), confidence: 0.95),
            OCRSpatialToken(text: "Track status", boundingBox: CGRect(x: 0.60, y: 0.65, width: 0.25, height: 0.03), confidence: 0.95)
        ]

        let tagged = ReceiptOCRService.classifyTokenRoles(tokens)
        let blocks = ReceiptOCRService.clusterAdaptiveBlocks(tokens: tagged)
        let candidates = ReceiptOCRService.extractCandidates(from: blocks, fallbackTokens: tagged, rules: [])

        XCTAssertEqual(candidates.count, 2, "Should identify exactly 2 distinct store transactions")
        
        let first = candidates[0]
        XCTAssertEqual(first.merchant, "Storage Global Store")
        XCTAssertEqual(first.amount, 133.37)
        XCTAssertEqual(first.currency, "ILS")

        let second = candidates[1]
        XCTAssertEqual(second.merchant, "SU CHENG ZI Store")
        XCTAssertEqual(second.amount, 8.11)
        XCTAssertEqual(second.currency, "ILS")
    }

    func testApplePaySpatialScreenshot() {
        let tokens: [OCRSpatialToken] = [
            OCRSpatialToken(text: "Super-Pharm", boundingBox: CGRect(x: 0.10, y: 0.15, width: 0.40, height: 0.04), confidence: 0.99),
            OCRSpatialToken(text: "דיזנגוף סנטר תל אביב", boundingBox: CGRect(x: 0.10, y: 0.20, width: 0.50, height: 0.03), confidence: 0.95),
            OCRSpatialToken(text: "₪ 84.90", boundingBox: CGRect(x: 0.10, y: 0.28, width: 0.35, height: 0.05), confidence: 0.99),
            OCRSpatialToken(text: "שולם באמצעות Apple Pay", boundingBox: CGRect(x: 0.10, y: 0.35, width: 0.60, height: 0.03), confidence: 0.97)
        ]

        let tagged = ReceiptOCRService.classifyTokenRoles(tokens)
        let blocks = ReceiptOCRService.clusterAdaptiveBlocks(tokens: tagged)
        let candidates = ReceiptOCRService.extractCandidates(from: blocks, fallbackTokens: tagged, rules: [])

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.merchant, "Super-Pharm")
        XCTAssertEqual(candidates.first?.amount, 84.90)
    }

    // MARK: - Exhaustive Real-World Edge Cases Suite

    // Case 1: Supermarket Receipt with Line Items, Club Discounts, and Cash/Change
    func testSupermarketWithDiscountsAndCashPayment() {
        let lines = [
            "יוחננוף - סניף רחובות",
            "חשבונית מס קבלה 84920",
            "חלב תנובה 3% 6.90 ₪",
            "לחם שיפון 14.50 ₪",
            "בשר בקר טרי 85.00 ₪",
            "יין אדום 45.00 ₪",
            "סה\"כ לפני הנחה 151.40 ₪",
            "הנחת מועדון 20.00- ₪",
            "מבצע 1+1 6.90- ₪",
            "סה\"כ לתשלום: 124.50 ₪",
            "שולם במזומן: 200.00 ₪",
            "עודף: 75.50 ₪"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 124.50, "Must extract the final paid total, not subtotal or cash paid")
        XCTAssertEqual(result?.merchant, "יוחננוף")
        XCTAssertEqual(result?.category, .food)
    }

    // Case 2: Israel Electric Company (חברת חשמל) with Arrears and Sub-charges
    func testElectricBillWithMultipleCharges() {
        let lines = [
            "חברת חשמל לישראל בע\"מ",
            "חשבון תקופתי עבור 07/2026 - 08/2026",
            "צריכת חשמל (650 קוט\"ש) 420.00 ₪",
            "תשלום קבוע 28.50 ₪",
            "ריבית פיגורים 4.20 ₪",
            "מע\"מ 18% 81.49 ₪",
            "סה\"כ לתשלום בש\"ח 534.19 ₪",
            "לתשלום עד 15/09/2026"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 534.19)
        XCTAssertEqual(result?.merchant, "חברת חשמל")
        XCTAssertEqual(result?.category, .housing)
    }

    // Case 3: Water Utility (מי אביבים / מי גבעתיים)
    func testWaterUtilityInvoice() {
        let lines = [
            "תאגיד מי אביבים מים וביוב תל אביב",
            "הודעת תשלום תקופתית",
            "שירותי מים (כמות בסיסית) 72.40 ₪",
            "שירותי ביוב 48.60 ₪",
            "היטל שמירה עירוני 19.50 ₪",
            "סה\"כ לתשלום בש\"ח: 140.50 ₪",
            "תאריך 18/08/2026"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 140.50)
        XCTAssertEqual(result?.merchant, "מי אביבים")
        XCTAssertEqual(result?.category, .housing)
    }

    // Case 4: Wolt Food Delivery with Delivery Fee, Service Fee, Coupon & Tip
    func testWoltWithFeesCouponsAndTips() {
        let lines = [
            "Wolt",
            "הזמנה ממקדונלד'ס דיזנגוף",
            "2x ארוחת מק רויאל 118.00 ₪",
            "1x פוטטו גדול 18.00 ₪",
            "דמי משלוח 16.00 ₪",
            "דמי תפעול 2.00 ₪",
            "קופון הנחה 25.00- ₪",
            "טיפ לשליח 10.00 ₪",
            "סה\"כ שולם: 139.00 ₪",
            "Mastercard מסתיים ב-8841"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 139.00)
        XCTAssertEqual(result?.category, .food)
    }

    // Case 5: Telecom Cellular Bill with Mobile Phone Number & ID
    func testCellcomBillWithSubscriberNumberAndId() {
        let lines = [
            "סלקום ישראל בע\"מ",
            "חשבונית חודשית לחודש אוגוסט 2026",
            "מספר מנוי: 052-9876543",
            "ח.פ: 511234567",
            "חבילת סלולר 5G 39.90 ₪",
            "חבילת חו\"ל 49.90 ₪",
            "מע\"מ 18% 16.16 ₪",
            "סך הכל חויב: 105.96 ₪"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 105.96)
        XCTAssertEqual(result?.merchant, "Cellcom")
        XCTAssertEqual(result?.category, .subscriptions)
    }

    // Case 6: Gas Station Slip (דור אלון / סונול / פז)
    func testGasStationSlip() {
        let lines = [
            "פז - תחנת תלפיות ירושלים",
            "בנזין 95 (38.45 ליטר) 289.14 ₪",
            "שטיפת רכב 25.00 ₪",
            "סה\"כ לתשלום: 314.14 ₪",
            "שולם באמצעות ויזה מסתיימת ב-4122"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 314.14)
        XCTAssertEqual(result?.merchant, "פז")
        XCTAssertEqual(result?.category, .transport)
    }

    // Case 7: Installments / Payments Split Bill (איקאה)
    func testIkeaInstallmentsReceipt() {
        let lines = [
            "איקאה ישראל - סניף ראשון לציון",
            "שולחן כתיבה + כיסא ארגונומי",
            "3 תשלומים של 300.00 ₪",
            "סך כל העסקה: 900.00 ₪",
            "תאריך: 10/08/2026"
        ]

        let result = ReceiptOCRService.parseReceipt(from: lines)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, 900.00)
        XCTAssertEqual(result?.merchant, "IKEA")
        XCTAssertEqual(result?.category, .shopping)
    }

    // Case 8: Heavily Distorted OCR Artifacts (m, 0 prefix, s'no typo)
    func testHeavilyDistortedOCRArtifacts() {
        // Shekel read as 'm', 'סה"כ' read as 's'no'
        let lines1 = [
            "שופרסל שלי",
            "s'no לתשלום: m215.80",
            "תאריך 05/08/2026"
        ]
        let res1 = ReceiptOCRService.parseReceipt(from: lines1)
        XCTAssertEqual(res1?.amount, 215.80)
        XCTAssertEqual(res1?.merchant, "שופרסל")

        // Shekel read as '0' prefix, 'סה"כ' read as 'ס'הכ'
        let lines2 = [
            "קפה לנדוור",
            "ארוחת בוקר זוגית",
            "ס'הכ: 0148.00",
            "תאריך 12/08/2026"
        ]
        let res2 = ReceiptOCRService.parseReceipt(from: lines2)
        XCTAssertEqual(res2?.amount, 148.00)
        XCTAssertEqual(res2?.merchant, "קפה לנדוור")
    }

    // Case 9: Multi-Currency International (Amazon USD, ASOS GBP)
    func testInternationalCurrenciesUSDAndGBP() {
        let amazonLines = [
            "Amazon.com Order Confirmation",
            "Sony WH-1000XM5 Headphones",
            "Order Total: $349.99",
            "Shipped via DHL Express"
        ]
        let resAmazon = ReceiptOCRService.parseReceipt(from: amazonLines)
        XCTAssertEqual(resAmazon?.amount, 349.99)
        XCTAssertEqual(resAmazon?.merchant, "Amazon")

        let asosLines = [
            "ASOS Official Store",
            "Summer Jacket - Navy / L",
            "Total Paid: £75.50",
            "Mastercard-3012"
        ]
        let resAsos = ReceiptOCRService.parseReceipt(from: asosLines)
        XCTAssertEqual(resAsos?.amount, 75.50)
    }

    // Case 10: Bit and PayBox P2P Payments
    func testP2PBitAndPayBox() {
        let bitLines = [
            "bit - העברת כספים",
            "העברת ל-נועה שרון",
            "סכום: ₪ 450.00",
            "עבור: מתנת יום הולדת",
            "אסמכתא: 90281920"
        ]
        let resBit = ReceiptOCRService.parseReceipt(from: bitLines)
        XCTAssertEqual(resBit?.amount, 450.00)
        XCTAssertEqual(resBit?.merchant, "נועה שרון")

        let payboxLines = [
            "PayBox",
            "שילמת ל-ועד בית בלפור 12",
            "סכום: 300.00 ש\"ח",
            "תאריך: 01/08/2026"
        ]
        let resPaybox = ReceiptOCRService.parseReceipt(from: payboxLines)
        XCTAssertEqual(resPaybox?.amount, 300.00)
    }
}
