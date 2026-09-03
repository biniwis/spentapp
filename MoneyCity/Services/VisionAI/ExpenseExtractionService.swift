import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Standalone orchestrator for expense extraction from receipts and screenshots.
/// Decouples Vision AI extractors from the legacy ReceiptOCRService.
public final class ExpenseExtractionService: Sendable {
    public static let shared = ExpenseExtractionService()

    private let primaryExtractor: VisionTransactionExtractor?

    public init(primaryExtractor: VisionTransactionExtractor? = GeminiTransactionExtractor()) {
        self.primaryExtractor = primaryExtractor
    }

    public struct ProcessedExpenseExtraction: Sendable {
        public let candidates: [ParsedTransactionCandidate]
        public let rawAIResponse: String?
        public let modelUsed: String
        public let duration: TimeInterval
        public let usedFallback: Bool

        public init(
            candidates: [ParsedTransactionCandidate],
            rawAIResponse: String? = nil,
            modelUsed: String,
            duration: TimeInterval,
            usedFallback: Bool
        ) {
            self.candidates = candidates
            self.rawAIResponse = rawAIResponse
            self.modelUsed = modelUsed
            self.duration = duration
            self.usedFallback = usedFallback
        }
    }

    #if canImport(UIKit)
    public func processImage(
        _ image: UIImage,
        rules: [MerchantRule] = [],
        allowFallback: Bool = false
    ) async throws -> ProcessedExpenseExtraction {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw GeminiTransactionExtractor.ExtractionError.invalidImageData
        }
        return try await processImageData(data, mimeType: "image/jpeg", rules: rules, allowFallback: allowFallback)
    }
    #endif

    public func processImageData(
        _ data: Data,
        mimeType: String = "image/jpeg",
        rules: [MerchantRule] = [],
        allowFallback: Bool = false
    ) async throws -> ProcessedExpenseExtraction {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. Try Primary Vision AI Extractor if available
        guard let extractor = primaryExtractor else {
            if allowFallback {
                let ocrResult = try await ReceiptOCRService.scanImage(data: data, rules: rules)
                return ProcessedExpenseExtraction(
                    candidates: ocrResult.candidates,
                    rawAIResponse: nil,
                    modelUsed: "AppleVision-LegacyOCR",
                    duration: CFAbsoluteTimeGetCurrent() - startTime,
                    usedFallback: true
                )
            }
            throw GeminiTransactionExtractor.ExtractionError.missingCredentials
        }

        do {
            let aiResult = try await extractor.extractTransactions(from: data, mimeType: mimeType)
            
            MoneyCityLog.sensitive("""
            [ExpenseExtractionService] AI RAW RESPONSE:
            ------------------------------------------
            \(aiResult.rawResponse)
            ------------------------------------------
            """)

            // Validate extracted candidates locally
            let validTransactions = ExtractedTransactionValidator.filterValidTransactions(aiResult.transactions)
            
            guard !validTransactions.isEmpty else {
                throw GeminiTransactionExtractor.ExtractionError.emptyResults
            }

            let candidates = validTransactions.map { raw -> ParsedTransactionCandidate in
                let merchantName: String
                if let m = raw.merchant?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
                    merchantName = m
                } else if let p = raw.product?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
                    merchantName = p
                } else {
                    merchantName = "הוצאה מצילום מסך"
                }
                
                let doubleAmount = NSDecimalNumber(decimal: raw.amount).doubleValue
                let classification = MerchantRuleService.classify(merchant: merchantName, amount: doubleAmount, rules: rules)
                
                return ParsedTransactionCandidate(
                    merchant: merchantName,
                    amount: doubleAmount,
                    currency: raw.currency,
                    date: raw.date,
                    category: classification.category,
                    buildingId: classification.buildingId,
                    confidence: raw.confidence,
                    sourceHint: raw.product,
                    rawEvidence: "Vision AI (\(extractor.modelIdentifier))"
                )
            }

            let duration = CFAbsoluteTimeGetCurrent() - startTime

            let candidateSummary = candidates.enumerated().map { idx, c in
                "  \(idx + 1). \(c.merchant) — \(c.currency)\(String(format: "%.2f", c.amount)) [\(c.category.displayName)] (Confidence: \(String(format: "%.2f", c.confidence)))"
            }.joined(separator: "\n")

            MoneyCityLog.sensitive("""
            [ExpenseExtractionService] PARSED TRANSACTIONS (\(String(format: "%.2fs", duration))):
            \(candidateSummary)
            """)

            return ProcessedExpenseExtraction(
                candidates: candidates,
                rawAIResponse: aiResult.rawResponse,
                modelUsed: extractor.modelIdentifier,
                duration: duration,
                usedFallback: false
            )
        } catch {
            MoneyCityLog.sensitive("[ExpenseExtractionService] Vision AI extractor failed: \(error.localizedDescription)")
            if allowFallback {
                let ocrResult = try await ReceiptOCRService.scanImage(data: data, rules: rules)
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                return ProcessedExpenseExtraction(
                    candidates: ocrResult.candidates,
                    rawAIResponse: nil,
                    modelUsed: "AppleVision-LegacyOCR",
                    duration: duration,
                    usedFallback: true
                )
            }
            throw error
        }
    }
}
