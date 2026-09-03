import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class GeminiTransactionExtractor: VisionTransactionExtractor, @unchecked Sendable {
    public let modelIdentifier: String
    private let apiKey: String?
    private let customEndpointURL: URL?
    private let session: URLSession

    public static let universalSystemPrompt = """
    You are a financial document understanding system for an expense tracking application.

    Analyze the provided image and identify ALL REAL FINANCIAL TRANSACTIONS visible in it.

    The image may be:
    - a physical receipt
    - a screenshot of an online store
    - an order confirmation
    - a payment confirmation
    - a banking screen
    - an email receipt
    - an invoice
    - a digital receipt
    - a payment app screen
    - any other image containing financial transaction information

    Your task is to extract actual transactions, not simply numbers.

    For each transaction identify:

    - merchant: the merchant, seller, business, service provider, or payment recipient
    - amount: the actual amount charged/paid
    - currency
    - date: the transaction/order/payment date if clearly available
    - product: the purchased product/service if clearly available
    - confidence: your confidence from 0.0 to 1.0

    IMPORTANT:

    Do NOT treat the following as transaction amounts:
    - product quantities
    - number of items
    - order IDs
    - transaction IDs
    - tracking numbers
    - reference numbers
    - phone numbers
    - card numbers
    - account numbers
    - invoice numbers
    - tax amounts when they are not the final amount charged
    - VAT amounts
    - discounts
    - coupons
    - original prices when a final charged price is shown
    - estimated prices
    - shipping estimates
    - balances
    - unrelated numbers
    - dates or times

    If the image contains multiple independent transactions, return ALL of them separately.

    Never combine multiple transactions into one transaction.

    For example, if an AliExpress screenshot contains two separate purchases of:
    - ₪133.37
    - ₪8.11

    return two transactions.

    If merchant and amount appear in completely different areas of the image, use the visual structure and semantic meaning of the document to determine their relationship.

    Do not require merchant and amount to be physically adjacent.

    For digital receipts, distinguish the actual amount charged from:
    - VAT
    - tax
    - product quantity
    - credits
    - subscription metadata
    - order IDs
    - payment method information

    Never invent missing information.

    If a field is not clearly available, return null.

    Return ONLY valid JSON matching this schema:

    {
      "transactions": [
        {
          "merchant": "string or null",
          "amount": 0.0,
          "currency": "ILS",
          "date": "YYYY-MM-DD or null",
          "product": "string or null",
          "confidence": 0.0
        }
      ]
    }
    """

    public enum ExtractionError: Error, LocalizedError, Equatable {
        case missingCredentials
        case invalidImageData
        case networkFailure(String)
        case invalidResponseCode(Int, String)
        case jsonParsingFailed(String)
        case emptyResults

        public var errorDescription: String? {
            switch self {
            case .missingCredentials:
                return "Gemini API key is not configured. For POC testing, set GEMINI_API_KEY environment variable or pass it to the constructor."
            case .invalidImageData:
                return "Failed to process image data into a valid format."
            case .networkFailure(let msg):
                return "Vision AI network request failed: \(msg)"
            case .invalidResponseCode(let code, let body):
                return "Vision AI returned HTTP \(code): \(body)"
            case .jsonParsingFailed(let raw):
                return "Failed to parse structured JSON from Vision AI response: \(raw)"
            case .emptyResults:
                return "Vision AI did not detect any valid transactions in the image."
            }
        }
    }

    public init(
        modelIdentifier: String = "gemini-2.0-flash",
        apiKey: String? = nil,
        customEndpointURL: URL? = nil,
        session: URLSession = .shared
    ) {
        self.modelIdentifier = modelIdentifier
        self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        self.customEndpointURL = customEndpointURL
        self.session = session
    }

    #if canImport(UIKit)
    public func extractTransactions(from image: UIImage) async throws -> VisionExtractionResult {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw ExtractionError.invalidImageData
        }
        return try await extractTransactions(from: data, mimeType: "image/jpeg")
    }
    #endif

    public func extractTransactions(from imageData: Data, mimeType: String = "image/jpeg") async throws -> VisionExtractionResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        let endpoint: URL
        if let custom = customEndpointURL {
            endpoint = custom
        } else {
            guard let key = apiKey, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ExtractionError.missingCredentials
            }
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelIdentifier):generateContent?key=\(key)"
            guard let url = URL(string: urlString) else {
                throw ExtractionError.missingCredentials
            }
            endpoint = url
        }

        let base64Image = imageData.base64EncodedString()

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": Self.universalSystemPrompt
                        ],
                        [
                            "inline_data": [
                                "mime_type": mimeType,
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.1
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ExtractionError.networkFailure(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExtractionError.invalidResponseCode(-1, "Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw ExtractionError.invalidResponseCode(httpResponse.statusCode, errorText)
        }

        let rawResponseString = String(data: data, encoding: .utf8) ?? ""
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        let transactions = try parseGeminiResponse(data: data)

        return VisionExtractionResult(
            transactions: transactions,
            rawResponse: rawResponseString,
            modelIdentifier: modelIdentifier,
            duration: duration
        )
    }

    public func parseGeminiResponse(data: Data) throws -> [ExtractedTransaction] {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExtractionError.jsonParsingFailed(String(data: data, encoding: .utf8) ?? "")
        }

        var rawText: String? = nil
        if let candidates = jsonObject["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            rawText = text
        } else if let directTransactions = jsonObject["transactions"] as? [[String: Any]] {
            let directData = try JSONSerialization.data(withJSONObject: ["transactions": directTransactions])
            let decoded = try JSONDecoder().decode(GeminiTransactionsEnvelope.self, from: directData)
            return decoded.transactions
        }

        guard let payloadText = rawText else {
            throw ExtractionError.jsonParsingFailed(String(data: data, encoding: .utf8) ?? "")
        }

        var cleanJson = payloadText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanJson.hasPrefix("```json") {
            cleanJson = String(cleanJson.dropFirst(7))
        }
        if cleanJson.hasPrefix("```") {
            cleanJson = String(cleanJson.dropFirst(3))
        }
        if cleanJson.hasSuffix("```") {
            cleanJson = String(cleanJson.dropLast(3))
        }
        cleanJson = cleanJson.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanJson.data(using: .utf8) else {
            throw ExtractionError.jsonParsingFailed(payloadText)
        }

        let envelope: GeminiTransactionsEnvelope
        do {
            envelope = try JSONDecoder().decode(GeminiTransactionsEnvelope.self, from: jsonData)
        } catch {
            if let array = try? JSONDecoder().decode([ExtractedTransaction].self, from: jsonData) {
                return array
            }
            throw ExtractionError.jsonParsingFailed(cleanJson)
        }

        return envelope.transactions
    }
}

private struct GeminiTransactionsEnvelope: Codable {
    let transactions: [ExtractedTransaction]
}
