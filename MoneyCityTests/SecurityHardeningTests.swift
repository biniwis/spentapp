import XCTest
import SwiftData
@testable import MoneyCity

final class SecurityHardeningTests: XCTestCase {

    // MARK: - InputSanitizer Tests

    func testInputSanitizerStripsControlCharactersAndNormalizesNFC() {
        // Strip ASCII control characters: null byte, bell, escape, DEL
        let dirty = "Hello\u{0000}\u{0007}World\u{001B}\u{007F}"
        let clean = InputSanitizer.sanitize(dirty)
        XCTAssertEqual(clean, "HelloWorld")

        // Preserve legitimate whitespace: newlines, carriage returns, tabs
        let multiline = "Line 1\nLine 2\r\n\tIndented"
        let preserved = InputSanitizer.sanitize(multiline, allowNewlines: true)
        XCTAssertEqual(preserved, "Line 1\nLine 2\r\n\tIndented")

        // Filter newlines when allowNewlines is false
        let singleLine = InputSanitizer.sanitize(multiline, allowNewlines: false)
        XCTAssertEqual(singleLine, "Line 1Line 2Indented")

        // Unicode NFC normalization (decomposed 'e' + acute -> composed 'é')
        let decomposed = "Cafe\u{0301}"
        let normalized = InputSanitizer.sanitize(decomposed)
        XCTAssertEqual(normalized, "Café")
        XCTAssertEqual(normalized.precomposedStringWithCanonicalMapping, normalized)
    }

    func testInputSanitizerPreservesUserCharactersWithoutNaiveBlacklisting() {
        // We must NEVER strip <, >, ", ', {, } blindly: user text must remain intact!
        let htmlPayload = "<script>alert('XSS')</script>"
        let sanitizedHtml = InputSanitizer.sanitizeMerchant(htmlPayload)
        XCTAssertEqual(sanitizedHtml, "<script>alert('XSS')</script>")

        let mathAndPunctuation = "5 > 3 & 2 < 4; 'quoted' \"double\" {json}"
        let sanitizedPunctuation = InputSanitizer.sanitizeNote(mathAndPunctuation)
        XCTAssertEqual(sanitizedPunctuation, "5 > 3 & 2 < 4; 'quoted' \"double\" {json}")

        let sqliPayload = "'; DROP TABLE transactions; --"
        let sanitizedSQL = InputSanitizer.sanitizeMerchant(sqliPayload)
        XCTAssertEqual(sanitizedSQL, "'; DROP TABLE transactions; --")

        // Hebrew, Arabic, currency symbols, emojis
        let hebrew = "סופר-פארם (סניף דיזנגוף) - ₪145.20"
        XCTAssertEqual(InputSanitizer.sanitizeMerchant(hebrew), hebrew)

        let arabic = "مطعم السلام & قهوة"
        XCTAssertEqual(InputSanitizer.sanitizeMerchant(arabic), arabic)

        let emojis = "Family: 👨‍👩‍👧‍👦 Grocery: 🛒 Coffee: ☕"
        XCTAssertEqual(InputSanitizer.sanitizeMerchant(emojis), emojis)
    }

    func testInputSanitizerBoundsStringLengths() {
        // Merchant length cap (200 characters)
        let hugeMerchant = String(repeating: "A", count: 500)
        let cleanMerchant = InputSanitizer.sanitizeMerchant(hugeMerchant)
        XCTAssertEqual(cleanMerchant.count, 200)

        // Note length cap (1000 characters)
        let hugeNote = String(repeating: "N", count: 2000)
        let cleanNote = InputSanitizer.sanitizeNote(hugeNote)
        XCTAssertEqual(cleanNote.count, 1000)

        // Identifier length cap (64 characters)
        let hugeIdentifier = String(repeating: "I", count: 200)
        let cleanIdentifier = InputSanitizer.sanitizeIdentifier(hugeIdentifier)
        XCTAssertEqual(cleanIdentifier.count, 64)

        // Currency length cap (8 characters)
        let hugeCurrency = "  US DOLLAR LONG  "
        let cleanCurrency = InputSanitizer.sanitizeCurrency(hugeCurrency)
        XCTAssertEqual(cleanCurrency, "US DOLLA")
        XCTAssertEqual(cleanCurrency.count, 8)
    }

    func testInputSanitizerNumericValidation() {
        // Valid amounts
        XCTAssertEqual(InputSanitizer.sanitizeAmount(123.45), 123.45)
        XCTAssertEqual(InputSanitizer.sanitizeAmount(0.0), 0.0)

        // Non-finite amounts (NaN, Infinity, -Infinity)
        XCTAssertEqual(InputSanitizer.sanitizeAmount(Double.nan), 0.0)
        XCTAssertEqual(InputSanitizer.sanitizeAmount(Double.infinity), 0.0)
        XCTAssertEqual(InputSanitizer.sanitizeAmount(-Double.infinity), 0.0)

        // Negative clamp check
        XCTAssertEqual(InputSanitizer.sanitizeAmount(-50.0, allowNegative: false), 0.0)
        XCTAssertEqual(InputSanitizer.sanitizeAmount(-50.0, allowNegative: true), -50.0)

        // Upper clamp limit (1 billion)
        XCTAssertEqual(InputSanitizer.sanitizeAmount(2_000_000_000.0), 1_000_000_000.0)
    }

    // MARK: - Model Hardening Tests

    func testTransactionModelGuardsNonFiniteAmountsAndExcessiveStrings() {
        // Transaction init with NaN amount
        let nanTx = Transaction(amount: Double.nan, currency: "ILS", merchant: "Store", category: .groceries)
        XCTAssertEqual(nanTx.amount, 0.0)

        // Transaction init with Infinity amount
        let infTx = Transaction(amount: Double.infinity, currency: "ILS", merchant: "Store", category: .groceries)
        XCTAssertEqual(infTx.amount, 0.0)

        // Transaction with massive merchant string
        let longMerchant = String(repeating: "M", count: 1000)
        let longTx = Transaction(amount: 50.0, currency: "ILS", merchant: longMerchant, category: .groceries)
        XCTAssertEqual(longTx.merchant.count, 200)

        // Transaction with confidence score out of bounds
        let highConfTx = Transaction(amount: 10.0, currency: "ILS", merchant: "M", category: .groceries, confidenceScore: 5.5)
        XCTAssertEqual(highConfTx.confidenceScore, 1.0)

        let lowConfTx = Transaction(amount: 10.0, currency: "ILS", merchant: "M", category: .groceries, confidenceScore: -2.0)
        XCTAssertEqual(lowConfTx.confidenceScore, 0.0)
    }

    func testSavingsGoalModelGuards() {
        let goal = SavingsGoal(
            name: String(repeating: "G", count: 500),
            icon: "🎯",
            targetAmount: Double.nan,
            savedAmount: -500.0,
            currency: "ILS"
        )
        XCTAssertEqual(goal.targetAmount, 0.0)
        XCTAssertEqual(goal.savedAmount, 0.0)
        XCTAssertEqual(goal.name.count, 200)
    }

    func testInstallmentPlanModelGuards() {
        // Plan with excessive/invalid payment counts
        let planZero = InstallmentPlan(
            merchant: "Shop",
            totalAmount: 1200.0,
            currency: "ILS",
            numberOfPayments: 0,
            firstChargeDate: Date(),
            category: .shopping
        )
        XCTAssertEqual(planZero.numberOfPayments, 1)

        let planExcessive = InstallmentPlan(
            merchant: "Shop",
            totalAmount: Double.infinity,
            currency: "ILS",
            numberOfPayments: 9999,
            firstChargeDate: Date(),
            category: .shopping
        )
        XCTAssertEqual(planExcessive.numberOfPayments, 120)
        XCTAssertEqual(planExcessive.totalAmount, 0.0)
    }

    func testMerchantRuleModelGuards() {
        let rule = MerchantRule(
            merchantKey: "  Shufersal  ",
            displayName: "Shufersal Deal",
            category: .groceries,
            buildingId: "food_super",
            hitCount: -5
        )
        XCTAssertEqual(rule.merchantKey, "Shufersal")
        XCTAssertEqual(rule.hitCount, 0)
    }

    // MARK: - Backup & Restore Hardening Tests

    @MainActor
    func testBackupImportRejectsOversizedPayload() {
        // 16 MB of junk data (exceeds maxBackupFileSize = 15 MB)
        let oversizedData = Data(count: 16 * 1024 * 1024)
        let schema = Schema([Transaction.self, SavingsGoal.self, InstallmentPlan.self, MerchantRule.self, CityEnrichment.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        XCTAssertThrowsError(try DataPortabilityService.importData(oversizedData, into: context)) { error in
            guard let importError = error as? DataPortabilityService.ImportError else {
                XCTFail("Expected ImportError, got \(error)")
                return
            }
            if case .fileTooLarge = importError {
                // Success
            } else {
                XCTFail("Expected .fileTooLarge, got \(importError)")
            }
        }
    }

    @MainActor
    func testBackupImportRejectsCorruptJSON() {
        let corruptData = "{\"format\": \"moneycity.backup\", invalid_json".data(using: .utf8)!
        let schema = Schema([Transaction.self, SavingsGoal.self, InstallmentPlan.self, MerchantRule.self, CityEnrichment.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        XCTAssertThrowsError(try DataPortabilityService.importData(corruptData, into: context)) { error in
            // Corrupt JSON will fail at JSONDecoder step with DecodingError
            XCTAssertTrue(error is DecodingError || error is DataPortabilityService.ImportError)
        }
    }

    @MainActor
    func testBackupImportRejectsExcessiveRecordCount() throws {
        // Create an envelope that claims > 50,000 records
        let fakeTransactions = (0..<50_001).map { i in
            DataPortabilityService.TransactionDTO(
                id: UUID(),
                amount: 10.0,
                currency: "ILS",
                merchant: "M\(i)",
                category: "groceries",
                timestamp: Date(),
                confidenceScore: 1.0,
                isManual: true,
                isConfirmed: true,
                note: nil,
                buildingId: nil,
                originalAmount: nil,
                originalCurrency: nil,
                exchangeRate: nil,
                savingsGoalId: nil,
                installmentPlanId: nil,
                installmentIndex: nil
            )
        }

        let envelope = DataPortabilityService.Envelope(
            format: DataPortabilityService.formatIdentifier,
            formatVersion: DataPortabilityService.formatVersion,
            appVersion: "1.0",
            appBuild: "1",
            exportedAt: Date(),
            transactions: fakeTransactions,
            recurring: [],
            income: [],
            budgets: [],
            merchantRules: [],
            installments: [],
            savingsGoals: [],
            enrichments: []
        )

        let data = try DataPortabilityService.makeEncoder().encode(envelope)
        let schema = Schema([Transaction.self, SavingsGoal.self, InstallmentPlan.self, MerchantRule.self, CityEnrichment.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        XCTAssertThrowsError(try DataPortabilityService.importData(data, into: context)) { error in
            guard let importError = error as? DataPortabilityService.ImportError else {
                XCTFail("Expected ImportError, got \(error)")
                return
            }
            if case .tooManyRecords = importError {
                // Success
            } else {
                XCTFail("Expected .tooManyRecords, got \(importError)")
            }
        }
    }

    @MainActor
    func testBackupImportSanitizesMalformedDTOs() throws {
        // DTO with unknown category, malicious script in merchant, invalid buildingId
        let malformedDTO = DataPortabilityService.TransactionDTO(
            id: UUID(),
            amount: 150.0,
            currency: "ILS",
            merchant: "<script>alert('pwn')</script>",
            category: "invalid_category_does_not_exist",
            timestamp: Date(timeIntervalSince1970: 0), // prehistoric timestamp
            confidenceScore: 99.0,
            isManual: true,
            isConfirmed: true,
            note: "Valid note with \u{0000} stripped",
            buildingId: "../../../etc/passwd", // invalid building ID
            originalAmount: nil,
            originalCurrency: nil,
            exchangeRate: nil,
            savingsGoalId: nil,
            installmentPlanId: nil,
            installmentIndex: nil
        )

        let envelope = DataPortabilityService.Envelope(
            format: DataPortabilityService.formatIdentifier,
            formatVersion: DataPortabilityService.formatVersion,
            appVersion: "1.0",
            appBuild: "1",
            exportedAt: Date(),
            transactions: [malformedDTO],
            recurring: [],
            income: [],
            budgets: [],
            merchantRules: [],
            installments: [],
            savingsGoals: [],
            enrichments: []
        )

        let data = try DataPortabilityService.makeEncoder().encode(envelope)
        let schema = Schema([Transaction.self, SavingsGoal.self, InstallmentPlan.self, MerchantRule.self, CityEnrichment.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let summary = try DataPortabilityService.importData(data, into: context, mode: .replace)
        XCTAssertEqual(summary.added, 1)

        let fetched = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(fetched.count, 1)
        let tx = fetched[0]

        // Verified: Amount imported correctly
        XCTAssertEqual(tx.amount, 150.0)
        // Verified: Merchant preserved without executing code
        XCTAssertEqual(tx.merchant, "<script>alert('pwn')</script>")
        // Verified: Category safely defaulted to .other
        XCTAssertEqual(tx.category, .other)
        // Verified: Unknown building ID rejected (set to nil)
        XCTAssertNil(tx.buildingIdRaw)
        // Verified: Control character stripped from note
        XCTAssertEqual(tx.note, "Valid note with  stripped")
        // Verified: Confidence clamped to 1.0
        XCTAssertEqual(tx.confidenceScore, 1.0)
    }

    // MARK: - WKWebView & Diorama Bridge Safeguards

    func testCityBuildingWhitelistRejectsArbitraryStrings() {
        // Legitimate building IDs
        XCTAssertTrue(CityBuilding.allKnownBuildingIds.contains("food_coffee"))
        XCTAssertTrue(CityBuilding.allKnownBuildingIds.contains("food_super"))
        XCTAssertTrue(CityBuilding.allKnownBuildingIds.contains("savings_sanctuary"))

        // Malicious injection strings
        XCTAssertFalse(CityBuilding.allKnownBuildingIds.contains("<script>alert(1)</script>"))
        XCTAssertFalse(CityBuilding.allKnownBuildingIds.contains("../../system/library"))
        XCTAssertFalse(CityBuilding.allKnownBuildingIds.contains("'; DROP TABLE--"))
        XCTAssertFalse(CityBuilding.allKnownBuildingIds.contains(""))
    }

    func testThreeDioramaViewJSONLiteralEscapesMaliciousPayloads() {
        // Test that dangerous characters are properly serialized as JSON string literals
        let dangerousString = #""; alert('hacked'); // <script>"#
        let encoded = ThreeDioramaView.jsonLiteral(dangerousString)

        // Encoded must be wrapped in quotes and escaped
        XCTAssertTrue(encoded.hasPrefix("\""))
        XCTAssertTrue(encoded.hasSuffix("\""))
        XCTAssertTrue(encoded.contains("\\\"")) // escaped quote

        // Decoding it back yields the exact original string
        let decoded = try? JSONDecoder().decode(String.self, from: encoded.data(using: .utf8)!)
        XCTAssertEqual(decoded, dangerousString)
    }
}
