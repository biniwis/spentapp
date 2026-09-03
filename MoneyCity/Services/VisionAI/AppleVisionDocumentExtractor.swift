import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 100% Free, On-Device Document Understanding Extractor using Apple Vision OCR + Spatial & Semantic Layout Parsing.
/// Requires NO API keys, NO external server, NO model download, and costs $0.
public final class AppleVisionDocumentExtractor: VisionTransactionExtractor, Sendable {
    public let modelIdentifier: String = "AppleVision-OnDeviceParser"

    public init() {}

    #if canImport(UIKit)
    public func extractTransactions(from image: UIImage) async throws -> VisionExtractionResult {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw ReceiptOCRService.OCRError.imageProcessingFailed
        }
        return try await extractTransactions(from: data, mimeType: "image/jpeg")
    }
    #endif

    public func extractTransactions(from imageData: Data, mimeType: String = "image/jpeg") async throws -> VisionExtractionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let rules = await DatabaseService.shared.fetchMerchantRules()

        let (scanResult, trace) = try await ReceiptOCRService.scanImageWithDiagnostics(data: imageData, rules: rules)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        let extracted = scanResult.candidates.map { c in
            ExtractedTransaction(
                merchant: c.merchant,
                amount: Decimal(string: String(c.amount)) ?? Decimal(c.amount),
                currency: c.currency,
                date: c.date,
                product: c.sourceHint,
                confidence: c.confidence
            )
        }

        let diagnosticSummary = """
        [AppleVision Diagnostic Trace]
        Tokens Detected: \(trace.rawOCRCount)
        Purchase Blocks Formed: \(trace.blocks.count)
        Transactions Extracted: \(extracted.count)
        Stages:
        \(trace.stageLogs.joined(separator: "\n"))
        """

        return VisionExtractionResult(
            transactions: extracted,
            rawResponse: diagnosticSummary,
            modelIdentifier: modelIdentifier,
            duration: duration
        )
    }
}
