import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Core Extraction Model

public struct ExtractedTransaction: Codable, Sendable, Equatable {
    public let merchant: String?
    public let amount: Decimal
    public let currency: String
    public let date: Date?
    public let product: String?
    public let confidence: Double

    public init(
        merchant: String?,
        amount: Decimal,
        currency: String = "ILS",
        date: Date? = nil,
        product: String? = nil,
        confidence: Double = 0.9
    ) {
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.date = date
        self.product = product
        self.confidence = confidence
    }
    
    // Custom Decodable to cleanly handle string-formatted numbers and dates
    enum CodingKeys: String, CodingKey {
        case merchant
        case amount
        case currency
        case date
        case product
        case confidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.merchant = try container.decodeIfPresent(String.self, forKey: .merchant)
        
        if let strAmount = try? container.decode(String.self, forKey: .amount),
                  let parsed = Decimal(string: strAmount.replacingOccurrences(of: ",", with: "")) {
            self.amount = parsed
        } else if let dblAmount = try? container.decode(Double.self, forKey: .amount) {
            self.amount = Decimal(string: String(dblAmount)) ?? Decimal(dblAmount)
        } else if let decAmount = try? container.decode(Decimal.self, forKey: .amount) {
            self.amount = decAmount
        } else {
            self.amount = 0
        }
        
        self.currency = (try? container.decode(String.self, forKey: .currency)) ?? "ILS"
        
        if let dateStr = try? container.decodeIfPresent(String.self, forKey: .date) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            self.date = formatter.date(from: dateStr)
        } else {
            self.date = nil
        }
        
        self.product = try container.decodeIfPresent(String.self, forKey: .product)
        self.confidence = (try? container.decode(Double.self, forKey: .confidence)) ?? 0.85
    }
}

// MARK: - Extraction Result & Debug Info

public struct VisionExtractionResult: Sendable, Equatable {
    public let transactions: [ExtractedTransaction]
    public let rawResponse: String
    public let modelIdentifier: String
    public let duration: TimeInterval

    public init(
        transactions: [ExtractedTransaction],
        rawResponse: String,
        modelIdentifier: String,
        duration: TimeInterval
    ) {
        self.transactions = transactions
        self.rawResponse = rawResponse
        self.modelIdentifier = modelIdentifier
        self.duration = duration
    }
}

// MARK: - Vision Transaction Extractor Protocol

public protocol VisionTransactionExtractor: Sendable {
    var modelIdentifier: String { get }
    
    #if canImport(UIKit)
    func extractTransactions(from image: UIImage) async throws -> VisionExtractionResult
    #endif
    
    func extractTransactions(from imageData: Data, mimeType: String) async throws -> VisionExtractionResult
}

// MARK: - Local Validation Rules

public struct ExtractedTransactionValidator: Sendable {
    public static let allowedCurrencies: Set<String> = [
        "ILS", "₪", "NIS", "USD", "$", "EUR", "€", "GBP", "£", "AED", "CAD", "AUD", "JPY"
    ]

    public enum ValidationError: Error, Equatable {
        case nonPositiveAmount(Decimal)
        case invalidCurrency(String)
        case unreasonableAmount(Decimal)
        case futureDate(Date)
    }

    public static func validate(_ tx: ExtractedTransaction, now: Date = Date()) throws {
        // 1. Amount must be strictly positive
        guard tx.amount > 0 else {
            throw ValidationError.nonPositiveAmount(tx.amount)
        }

        // 2. Amount must not look like an unformatted order ID or phone number (> 1,000,000)
        guard tx.amount < 1_000_000 else {
            throw ValidationError.unreasonableAmount(tx.amount)
        }

        // 3. Currency must be a recognized symbol/ISO code
        let normalizedCurr = tx.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard allowedCurrencies.contains(normalizedCurr) || allowedCurrencies.contains(tx.currency) else {
            throw ValidationError.invalidCurrency(tx.currency)
        }

        // 4. Date validation (must not be far in the future)
        if let date = tx.date {
            let maxFuture: TimeInterval = 2 * 24 * 60 * 60 // 2 days buffer for timezone
            if date.timeIntervalSince(now) > maxFuture {
                throw ValidationError.futureDate(date)
            }
        }
    }

    public static func filterValidTransactions(_ list: [ExtractedTransaction]) -> [ExtractedTransaction] {
        return list.filter { tx in
            (try? validate(tx)) != nil
        }
    }
}
