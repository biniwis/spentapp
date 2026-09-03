import XCTest
import Foundation
@testable import MoneyCity

final class VisionTransactionExtractorTests: XCTestCase {

    func testSingleTransactionJSONParsing() throws {
        let json = """
        {
          "transactions": [
            {
              "merchant": "Super-Pharm",
              "amount": 45.90,
              "currency": "ILS",
              "date": "2026-09-03",
              "product": "Pharmacy Goods",
              "confidence": 0.95
            }
          ]
        }
        """

        let extractor = GeminiTransactionExtractor(apiKey: "TEST_MOCK_KEY")
        let data = json.data(using: .utf8)!
        let parsed = try extractor.parseGeminiResponse(data: data)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].merchant, "Super-Pharm")
        XCTAssertEqual(parsed[0].amount, 45.90)
        XCTAssertEqual(parsed[0].currency, "ILS")
        XCTAssertEqual(parsed[0].product, "Pharmacy Goods")
        XCTAssertEqual(parsed[0].confidence, 0.95)
    }

    func testMultipleTransactionsAliExpressCase() throws {
        let json = """
        {
          "transactions": [
            {
              "merchant": "Storage Global Store",
              "amount": 133.37,
              "currency": "ILS",
              "date": "2026-09-01",
              "product": "SSD Drive",
              "confidence": 0.96
            },
            {
              "merchant": "SU CHENG ZI Store",
              "amount": 8.11,
              "currency": "ILS",
              "date": "2026-09-01",
              "product": "Cable Organizer",
              "confidence": 0.92
            }
          ]
        }
        """

        let extractor = GeminiTransactionExtractor(apiKey: "TEST_MOCK_KEY")
        let data = json.data(using: .utf8)!
        let parsed = try extractor.parseGeminiResponse(data: data)

        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].merchant, "Storage Global Store")
        XCTAssertEqual(parsed[0].amount, 133.37)
        XCTAssertEqual(parsed[1].merchant, "SU CHENG ZI Store")
        XCTAssertEqual(parsed[1].amount, 8.11)
    }

    func testGeminiCandidateNestedJSONParsing() throws {
        let geminiResponseJson = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "```json\\n{\\n  \\"transactions\\": [\\n    {\\n      \\"merchant\\": \\"Wolt\\",\\n      \\"amount\\": 78.50,\\n      \\"currency\\": \\"ILS\\",\\n      \\"date\\": \\"2026-09-03\\",\\n      \\"product\\": \\"Dinner\\",\\n      \\"confidence\\": 0.98\\n    }\\n  ]\\n}\\n```"
                  }
                ]
              }
            }
          ]
        }
        """

        let extractor = GeminiTransactionExtractor(apiKey: "TEST_MOCK_KEY")
        let data = geminiResponseJson.data(using: .utf8)!
        let parsed = try extractor.parseGeminiResponse(data: data)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].merchant, "Wolt")
        XCTAssertEqual(parsed[0].amount, 78.50)
    }

    func testValidationRejectsNonPositiveAmount() {
        let zeroTx = ExtractedTransaction(merchant: "Test", amount: 0.0, currency: "ILS")
        let negativeTx = ExtractedTransaction(merchant: "Test", amount: -15.0, currency: "ILS")

        XCTAssertThrowsError(try ExtractedTransactionValidator.validate(zeroTx))
        XCTAssertThrowsError(try ExtractedTransactionValidator.validate(negativeTx))
    }

    func testValidationRejectsUnreasonableOrderIdAsAmount() {
        let orderIdTx = ExtractedTransaction(merchant: "AliExpress", amount: 849302910482, currency: "ILS")
        XCTAssertThrowsError(try ExtractedTransactionValidator.validate(orderIdTx))
    }

    func testValidationRejectsInvalidCurrency() {
        let badCurrencyTx = ExtractedTransaction(merchant: "Shop", amount: 50.0, currency: "XYZ99")
        XCTAssertThrowsError(try ExtractedTransactionValidator.validate(badCurrencyTx))
    }

    func testValidationAcceptsStandardCurrencies() {
        for curr in ["ILS", "₪", "USD", "$", "EUR", "€", "GBP", "£"] {
            let validTx = ExtractedTransaction(merchant: "Shop", amount: 25.0, currency: curr)
            XCTAssertNoThrow(try ExtractedTransactionValidator.validate(validTx))
        }
    }

    func testOrchestratorCategorizationMapping() async throws {
        struct MockExtractor: VisionTransactionExtractor {
            var modelIdentifier: String = "mock-vision-model"

            func extractTransactions(from imageData: Data, mimeType: String) async throws -> VisionExtractionResult {
                let txs = [
                    ExtractedTransaction(merchant: "שופרסל דיל", amount: 245.50, currency: "ILS"),
                    ExtractedTransaction(merchant: "זארה", amount: 199.90, currency: "ILS")
                ]
                return VisionExtractionResult(
                    transactions: txs,
                    rawResponse: "mock-raw-response",
                    modelIdentifier: modelIdentifier,
                    duration: 0.05
                )
            }
        }

        let orchestrator = ExpenseExtractionService(primaryExtractor: MockExtractor())
        let result = try await orchestrator.processImageData(Data([0x00, 0x01]))

        XCTAssertFalse(result.usedFallback)
        XCTAssertEqual(result.modelUsed, "mock-vision-model")
        XCTAssertEqual(result.candidates.count, 2)

        // Verify CategorizationEngine integration
        XCTAssertEqual(result.candidates[0].merchant, "שופרסל דיל")
        XCTAssertEqual(result.candidates[0].amount, 245.50)
        XCTAssertEqual(result.candidates[0].category, .food)

        XCTAssertEqual(result.candidates[1].merchant, "זארה")
        XCTAssertEqual(result.candidates[1].amount, 199.90)
        XCTAssertEqual(result.candidates[1].category, .shopping)
    }

    func testThreeRealReceiptsDiagnostics() async throws {
        let userDir = "/Users/bnymynwysmn/.gemini/antigravity/brain/e9943d74-3a89-462b-b134-96b059d8549e/.user_uploaded"
        let fileURL = URL(fileURLWithPath: userDir).appendingPathComponent("media_1788469079044.png")
        guard let data = try? Data(contentsOf: fileURL) else { return }

        let tokens = try await ReceiptOCRService.recognizeSpatialTokens(from: data)
        let tagged = ReceiptOCRService.classifyTokenRoles(tokens)
        print("===== TOKENS AND ROLES (\(tagged.count)) =====")
        for (i, t) in tagged.enumerated() {
            print(String(format: "[%02d] (Y: %.3f) %-15@ | '%@' | num: %@", i, t.boundingBox.origin.y, t.role.rawValue, t.text, String(describing: t.numericValue)))
        }

        let (result, trace) = try await ReceiptOCRService.scanImageWithDiagnostics(data: data)
        print("===== CANDIDATES (\(result.candidates.count)) =====")
        for c in result.candidates {
            print("Candidate: '\(c.merchant)' | Amount: \(c.currency)\(c.amount) | Confidence: \(c.confidence)")
        }
    }
}
