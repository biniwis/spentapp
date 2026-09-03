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
        rules: [MerchantRule] = []
    ) async throws -> ProcessedExpenseExtraction {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw GeminiTransactionExtractor.ExtractionError.invalidImageData
        }
        return try await processImageData(data, mimeType: "image/jpeg", rules: rules)
    }
    #endif

    public func processImageData(
        _ data: Data,
        mimeType: String = "image/jpeg",
        rules: [MerchantRule] = []
    ) async throws -> ProcessedExpenseExtraction {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. Try Primary Vision AI Extractor if available
        if let extractor = primaryExtractor {
            do {
                let aiResult = try await extractor.extractTransactions(from: data, mimeType: mimeType)
                
                // Validate extracted candidates locally
                let validTransactions = ExtractedTransactionValidator.filterValidTransactions(aiResult.transactions)
                
                if !validTransactions.isEmpty {
                    // Map to ParsedTransactionCandidates using existing CategorizationEngine / Rules
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
                            rawEvidence: "Vision AI: \(extractor.modelIdentifier)"
                        )
                    }

                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    return ProcessedExpenseExtraction(
                        candidates: candidates,
                        rawAIResponse: aiResult.rawResponse,
                        modelUsed: extractor.modelIdentifier,
                        duration: duration,
                        usedFallback: false
                    )
                }
            } catch {
                // Log and gracefully fall through to fallback
                MoneyCityLog.sensitive("[ExpenseExtractionService] Vision AI extractor failed, falling back to legacy OCR: \(error)")
            }
        }

        // 2. Fallback to Legacy ReceiptOCRService (Apple Vision Spatial OCR)
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
}
