import Foundation
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Semantic Token Roles

public enum OCRTokenRole: String, Sendable, Equatable, CaseIterable {
    case merchantName
    case productDescription
    case amount
    case date
    case quantity         // e.g. "x1", "1Pc", "Qty: 2"
    case couponDiscount   // e.g. "₪4 coupon if delayed", "הנחה"
    case actionButton     // e.g. "Track status", "Confirm received", "Buy again"
    case orderMetadata    // e.g. "Order ID: 12345", "Tracking: LP000"
    case noise            // Battery, time, status bar, search header
}

// MARK: - Spatial OCR Token

public struct OCRSpatialToken: Sendable, Equatable {
    public let text: String
    public let boundingBox: CGRect      // Vision normalized coordinates (0.0...1.0, top-left origin)
    public let confidence: Float        // Vision OCR confidence (0.0 to 1.0)
    public let role: OCRTokenRole
    public let numericValue: Double?
    public let currencySymbol: String?
    public let lineHeight: CGFloat

    public init(
        text: String,
        boundingBox: CGRect,
        confidence: Float,
        role: OCRTokenRole = .noise,
        numericValue: Double? = nil,
        currencySymbol: String? = nil,
        lineHeight: CGFloat = 0.0
    ) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.role = role
        self.numericValue = numericValue
        self.currencySymbol = currencySymbol
        self.lineHeight = lineHeight > 0 ? lineHeight : boundingBox.height
    }
}

// MARK: - Visual Purchase Block

public struct VisualPurchaseBlock: Sendable, Equatable {
    public let id: UUID
    public let tokens: [OCRSpatialToken]
    public let boundingBox: CGRect
    public let storeCandidate: String?
    public let amountCandidate: Double?
    public let currency: String
    public let dateCandidate: Date?
    public let confidenceScore: Double

    public init(
        id: UUID = UUID(),
        tokens: [OCRSpatialToken],
        boundingBox: CGRect,
        storeCandidate: String?,
        amountCandidate: Double?,
        currency: String = "ILS",
        dateCandidate: Date? = nil,
        confidenceScore: Double = 0.8
    ) {
        self.id = id
        self.tokens = tokens
        self.boundingBox = boundingBox
        self.storeCandidate = storeCandidate
        self.amountCandidate = amountCandidate
        self.currency = currency
        self.dateCandidate = dateCandidate
        self.confidenceScore = confidenceScore
    }
}

// MARK: - Universal Parsed Transaction Candidate

public struct ParsedTransactionCandidate: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var merchant: String
    public var amount: Double
    public var currency: String
    public var date: Date?
    public var category: SpendingCategory
    public var buildingId: String
    public var confidence: Double
    public var sourceHint: String?
    public var rawEvidence: String

    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        currency: String = "ILS",
        date: Date? = nil,
        category: SpendingCategory = .other,
        buildingId: String = "food_bistro",
        confidence: Double = 0.85,
        sourceHint: String? = nil,
        rawEvidence: String = ""
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.date = date
        self.category = category
        self.buildingId = buildingId
        self.confidence = confidence
        self.sourceHint = sourceHint
        self.rawEvidence = rawEvidence
    }
}

// MARK: - Scan Diagnostic Trace (For Inspection & Debugging)

public struct ScanDiagnosticTrace: Sendable, Equatable {
    public let rawOCRCount: Int
    public let tokens: [OCRSpatialToken]
    public let blocks: [VisualPurchaseBlock]
    public let candidates: [ParsedTransactionCandidate]
    public let stageLogs: [String]

    public init(
        rawOCRCount: Int = 0,
        tokens: [OCRSpatialToken] = [],
        blocks: [VisualPurchaseBlock] = [],
        candidates: [ParsedTransactionCandidate] = [],
        stageLogs: [String] = []
    ) {
        self.rawOCRCount = rawOCRCount
        self.tokens = tokens
        self.blocks = blocks
        self.candidates = candidates
        self.stageLogs = stageLogs
    }
}

// MARK: - Universal Scan Result (Backward Compatible)

public struct ReceiptScanResult: Sendable, Equatable {
    public let candidates: [ParsedTransactionCandidate]
    public let diagnosticTrace: ScanDiagnosticTrace?

    public var primary: ParsedTransactionCandidate? {
        candidates.first
    }

    public var amount: Double {
        primary?.amount ?? 0.0
    }

    public var merchant: String {
        primary?.merchant ?? "הוצאה מצילום מסך"
    }

    public var date: Date? {
        primary?.date
    }

    public var category: SpendingCategory {
        primary?.category ?? .other
    }

    public var buildingId: String {
        primary?.buildingId ?? "food_bistro"
    }

    public var confidence: Double {
        primary?.confidence ?? 0.0
    }

    public let rawText: String

    public init(
        candidates: [ParsedTransactionCandidate],
        rawText: String = "",
        diagnosticTrace: ScanDiagnosticTrace? = nil
    ) {
        self.candidates = candidates
        self.rawText = rawText
        self.diagnosticTrace = diagnosticTrace
    }

    public init(
        amount: Double,
        merchant: String,
        date: Date?,
        category: SpendingCategory,
        buildingId: String,
        confidence: Double,
        rawText: String
    ) {
        let singleCandidate = ParsedTransactionCandidate(
            merchant: merchant,
            amount: amount,
            currency: "ILS",
            date: date,
            category: category,
            buildingId: buildingId,
            confidence: confidence,
            rawEvidence: rawText
        )
        self.candidates = [singleCandidate]
        self.rawText = rawText
        self.diagnosticTrace = nil
    }
}

// MARK: - Advanced Universal Expense Recognition Engine

public enum ReceiptOCRService {

    public enum OCRError: LocalizedError {
        case imageProcessingFailed
        case noTextFound
        case parsingFailed

        public var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Failed to process the screenshot or receipt image."
            case .noTextFound:
                return "No readable text was found in the image."
            case .parsingFailed:
                return "Could not detect any valid transaction in the image."
            }
        }
    }

    // MARK: - Public Entry Points

    /// Scans an image payload, executes spatial layout OCR, and extracts all transaction candidates.
    public static func scanImage(data: Data, rules: [MerchantRule] = []) async throws -> ReceiptScanResult {
        let (result, _) = try await scanImageWithDiagnostics(data: data, rules: rules)
        return result
    }

    /// Full pipeline execution with complete diagnostic stage tracing.
    public static func scanImageWithDiagnostics(
        data: Data,
        rules: [MerchantRule] = []
    ) async throws -> (result: ReceiptScanResult, trace: ScanDiagnosticTrace) {
        var logs: [String] = []

        // Stage 1: Spatial OCR Token Extraction
        let rawTokens = try await recognizeSpatialTokens(from: data)
        logs.append("[Stage 1: Raw OCR] Detected \(rawTokens.count) spatial text elements")
        guard !rawTokens.isEmpty else {
            throw OCRError.noTextFound
        }

        // Stage 2: Semantic Role Classification
        let taggedTokens = classifyTokenRoles(rawTokens)
        logs.append("[Stage 2: Semantic Tagging] Tagged \(taggedTokens.count) tokens into semantic roles")

        // Stage 3: Adaptive Spatial & Semantic Block Clustering
        let blocks = clusterAdaptiveBlocks(tokens: taggedTokens)
        logs.append("[Stage 3: Adaptive Clustering] Formed \(blocks.count) purchase candidate blocks")

        // Stage 4: Candidate Extraction & Noise Rejection
        let rawText = taggedTokens.map(\.text).joined(separator: "\n")
        let candidates = extractCandidates(from: blocks, fallbackTokens: taggedTokens, rules: rules)
        logs.append("[Stage 4: Extraction] Extracted \(candidates.count) transaction candidates")

        // Stage 5: Validation & Filtering
        let validatedCandidates = validateCandidates(candidates)
        logs.append("[Stage 5: Validation] \(validatedCandidates.count) valid transactions passed all assertions")

        guard !validatedCandidates.isEmpty else {
            throw OCRError.parsingFailed
        }

        let trace = ScanDiagnosticTrace(
            rawOCRCount: rawTokens.count,
            tokens: taggedTokens,
            blocks: blocks,
            candidates: validatedCandidates,
            stageLogs: logs
        )

        // Debug logging for developers
        for log in logs {
            MoneyCityLog.debug(log)
        }

        let result = ReceiptScanResult(
            candidates: validatedCandidates,
            rawText: rawText,
            diagnosticTrace: trace
        )

        return (result, trace)
    }

    // MARK: - Stage 1: Spatial OCR Token Recognition

    /// Executes Apple Vision OCR and preserves spatial bounding boxes, normalized coordinates, and confidence.
    public static func recognizeSpatialTokens(from data: Data) async throws -> [OCRSpatialToken] {
        #if canImport(Vision) && canImport(CoreGraphics)
        return try await withCheckedThrowingContinuation { continuation in
            let resumed = OCRResumeLatch()
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    if resumed.claim() { continuation.resume(throwing: error) }
                    return
                }

                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    if resumed.claim() { continuation.resume(returning: []) }
                    return
                }

                // Apple Vision boundingBox has (0,0) at bottom-left.
                // We convert to standard top-left origin (Y increases downwards) for natural reading layout.
                var tokens: [OCRSpatialToken] = []
                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    let box = obs.boundingBox
                    let standardRect = CGRect(
                        x: box.origin.x,
                        y: 1.0 - (box.origin.y + box.height), // Invert Y to top-down
                        width: box.width,
                        height: box.height
                    )

                    let rawText = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !rawText.isEmpty else { continue }

                    tokens.append(OCRSpatialToken(
                        text: rawText,
                        boundingBox: standardRect,
                        confidence: candidate.confidence,
                        lineHeight: standardRect.height
                    ))
                }

                // Sort primarily top-to-bottom, secondarily left-to-right
                let sortedTokens = tokens.sorted { a, b in
                    let diffY = a.boundingBox.origin.y - b.boundingBox.origin.y
                    if abs(diffY) > (a.lineHeight * 0.5) {
                        return a.boundingBox.origin.y < b.boundingBox.origin.y
                    }
                    return a.boundingBox.origin.x < b.boundingBox.origin.x
                }

                if resumed.claim() { continuation.resume(returning: sortedTokens) }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["he-IL", "en-US"]

            let handler = VNImageRequestHandler(data: data, options: [:])
            do {
                try handler.perform([request])
            } catch {
                if resumed.claim() { continuation.resume(throwing: error) }
            }
        }
        #else
        return []
        #endif
    }

    // MARK: - Stage 2: Semantic Token Classification

    public static func classifyTokenRoles(_ tokens: [OCRSpatialToken]) -> [OCRSpatialToken] {
        return tokens.map { token in
            let text = token.text
            let lower = text.lowercased()

            // 1. Check Coupon / Discount
            if isCouponOrDiscount(lower) {
                let nums = extractNumbers(from: text)
                return OCRSpatialToken(
                    text: text,
                    boundingBox: token.boundingBox,
                    confidence: token.confidence,
                    role: .couponDiscount,
                    numericValue: nums.first,
                    currencySymbol: detectCurrencySymbol(text),
                    lineHeight: token.lineHeight
                )
            }

            // 2. Check Quantity (e.g. "x1", "1Pc", "Qty 2")
            if isQuantity(lower) {
                return OCRSpatialToken(
                    text: text,
                    boundingBox: token.boundingBox,
                    confidence: token.confidence,
                    role: .quantity,
                    lineHeight: token.lineHeight
                )
            }

            // 3. Check Action Button / Navigation UI
            if isActionButton(lower) {
                return OCRSpatialToken(
                    text: text,
                    boundingBox: token.boundingBox,
                    confidence: token.confidence,
                    role: .actionButton,
                    lineHeight: token.lineHeight
                )
            }

            // 4. Check Order Metadata / Tracking
            if isOrderMetadata(lower) {
                return OCRSpatialToken(
                    text: text,
                    boundingBox: token.boundingBox,
                    confidence: token.confidence,
                    role: .orderMetadata,
                    lineHeight: token.lineHeight
                )
            }

            // 5. Check Date
            if extractDate(from: [text]) != nil {
                return OCRSpatialToken(
                    text: text,
                    boundingBox: token.boundingBox,
                    confidence: token.confidence,
                    role: .date,
                    lineHeight: token.lineHeight
                )
            }

            // 6. Check Amount
            let numbers = extractNumbers(from: text)
            let curr = detectCurrencySymbol(text)
            if !numbers.isEmpty && (curr != nil || isAmountIndicator(lower)) && !isPhoneOrBarcode(lower, numbers: numbers) {
                return OCRSpatialToken(
                    text: text,
                    boundingBox: token.boundingBox,
                    confidence: token.confidence,
                    role: .amount,
                    numericValue: numbers.first,
                    currencySymbol: curr ?? "ILS",
                    lineHeight: token.lineHeight
                )
            }

            // 7. Check Store / Merchant Anchor
            if isStoreAnchor(text) {
                return OCRSpatialToken(
                    text: text,
                    boundingBox: token.boundingBox,
                    confidence: token.confidence,
                    role: .merchantName,
                    lineHeight: token.lineHeight
                )
            }

            // 8. General Product / Line
            if text.contains(where: { $0.isLetter }) {
                return OCRSpatialToken(
                    text: text,
                    boundingBox: token.boundingBox,
                    confidence: token.confidence,
                    role: .productDescription,
                    lineHeight: token.lineHeight
                )
            }

            return OCRSpatialToken(
                text: text,
                boundingBox: token.boundingBox,
                confidence: token.confidence,
                role: .noise,
                lineHeight: token.lineHeight
            )
        }
    }

    // MARK: - Stage 3: Adaptive Spatial & Semantic Block Clustering

    /// Clusters tokens into purchase blocks using adaptive vertical spacing relative to line heights
    /// and semantic boundaries (Store headers and Action button delimiters).
    public static func clusterAdaptiveBlocks(tokens: [OCRSpatialToken]) -> [VisualPurchaseBlock] {
        var blocks: [VisualPurchaseBlock] = []
        var currentTokens: [OCRSpatialToken] = []

        for token in tokens {
            // Ignore system noise (battery bar, header search)
            if token.role == .noise && token.boundingBox.origin.y < 0.05 {
                continue
            }

            // If we encounter a new distinct store anchor and already have tokens with an amount
            if token.role == .merchantName && !currentTokens.isEmpty {
                let hasAmount = currentTokens.contains { $0.role == .amount && ($0.numericValue ?? 0) > 0 }
                if hasAmount {
                    if let block = makeBlock(from: currentTokens) {
                        blocks.append(block)
                    }
                    currentTokens.removeAll()
                }
            }

            // Check adaptive vertical gap
            if let lastToken = currentTokens.last {
                let verticalGap = token.boundingBox.origin.y - (lastToken.boundingBox.origin.y + lastToken.boundingBox.height)
                let avgLineHeight = max((lastToken.lineHeight + token.lineHeight) / 2.0, 0.015)

                // Adaptive threshold: max 4.5x line height or explicit action button delimiter
                let isLargeGap = verticalGap > (avgLineHeight * 4.5)
                let isDelimitingAction = lastToken.role == .actionButton && token.role == .merchantName

                if (isLargeGap || isDelimitingAction) && !currentTokens.isEmpty {
                    let hasAmount = currentTokens.contains { $0.role == .amount && ($0.numericValue ?? 0) > 0 }
                    if hasAmount {
                        if let block = makeBlock(from: currentTokens) {
                            blocks.append(block)
                        }
                        currentTokens.removeAll()
                    }
                }
            }

            currentTokens.append(token)
        }

        // Flush remaining tokens
        if !currentTokens.isEmpty {
            if let block = makeBlock(from: currentTokens) {
                blocks.append(block)
            }
        }

        return blocks
    }

    private static func makeBlock(from tokens: [OCRSpatialToken]) -> VisualPurchaseBlock? {
        guard !tokens.isEmpty else { return nil }

        let blockLines = tokens.map(\.text)

        // Determine bounding box union
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = CGFloat.leastNormalMagnitude
        var maxY = CGFloat.leastNormalMagnitude

        for t in tokens {
            minX = min(minX, t.boundingBox.minX)
            minY = min(minY, t.boundingBox.minY)
            maxX = max(maxX, t.boundingBox.maxX)
            maxY = max(maxY, t.boundingBox.maxY)
        }
        let unionRect = CGRect(x: minX, y: minY, width: max(maxX - minX, 0.01), height: max(maxY - minY, 0.01))

        // Store candidate: first check extractMerchant from block lines
        var storeName: String? = extractMerchant(from: blockLines)
        if storeName == nil {
            for t in tokens {
                if t.role == .merchantName {
                    storeName = sanitizeMerchantName(t.text)
                    break
                }
            }
        }
        if storeName == nil {
            for t in tokens {
                if t.role == .productDescription && !isGenericBoilerplate(t.text.lowercased()) {
                    storeName = sanitizeMerchantName(t.text)
                    break
                }
            }
        }

        // Amount candidate: first try block-level extractAmount, otherwise find best amount token
        var bestAmount: Double? = extractAmount(from: blockLines)
        var detectedCurrency = "ILS"

        if bestAmount == nil {
            var bestScore: Int = -100
            for t in tokens where t.role == .amount {
                guard let val = t.numericValue, val > 0, val < 500_000 else { continue }
                var score = 50
                if t.currencySymbol != nil { score += 50 }
                if val >= 5.0 && val <= 10_000.0 { score += 20 }

                if score > bestScore {
                    bestScore = score
                    bestAmount = val
                    detectedCurrency = t.currencySymbol ?? "ILS"
                }
            }
        }

        for t in tokens where t.role == .amount {
            if let c = t.currencySymbol {
                detectedCurrency = c
                break
            }
        }

        // Date candidate
        let blockDate: Date? = extractDate(from: blockLines)

        return VisualPurchaseBlock(
            tokens: tokens,
            boundingBox: unionRect,
            storeCandidate: storeName,
            amountCandidate: bestAmount,
            currency: detectedCurrency,
            dateCandidate: blockDate,
            confidenceScore: bestAmount != nil ? 0.90 : 0.60
        )
    }

    // MARK: - Stage 4: Candidate Extraction

    public static func extractCandidates(
        from blocks: [VisualPurchaseBlock],
        fallbackTokens: [OCRSpatialToken],
        rules: [MerchantRule]
    ) -> [ParsedTransactionCandidate] {
        var candidates: [ParsedTransactionCandidate] = []

        // If blocks have valid candidates, extract each
        for block in blocks {
            if let amount = block.amountCandidate, amount > 0 {
                let merchant = block.storeCandidate ?? "הוצאה מצילום מסך"
                let classification = MerchantRuleService.classify(merchant: merchant, amount: amount, rules: rules)
                let evidence = block.tokens.map(\.text).joined(separator: " | ")

                let candidate = ParsedTransactionCandidate(
                    merchant: merchant,
                    amount: amount,
                    currency: block.currency,
                    date: block.dateCandidate,
                    category: classification.category,
                    buildingId: classification.buildingId,
                    confidence: max(block.confidenceScore, classification.confidence),
                    sourceHint: detectSourceHint(from: evidence),
                    rawEvidence: evidence
                )
                candidates.append(candidate)
            }
        }

        // Fallback: If block clustering yielded 0 candidates, run global heuristic parser on tokens
        if candidates.isEmpty {
            let lines = fallbackTokens.map(\.text)
            if let legacy = parseReceipt(from: lines, rules: rules) {
                candidates.append(contentsOf: legacy.candidates)
            }
        }

        return candidates
    }

    // MARK: - Stage 5: Validation & Filtering

    public static func validateCandidates(_ candidates: [ParsedTransactionCandidate]) -> [ParsedTransactionCandidate] {
        var valid: [ParsedTransactionCandidate] = []
        var seenKeys: Set<String> = []

        for c in candidates {
            // Assert positive amount
            guard c.amount > 0.01 else { continue }

            // Deduplicate exact duplicate items within the same scan
            let amtStr = String(format: "%.2f", c.amount)
            let key = "\(c.merchant.lowercased())_\(amtStr)"
            if seenKeys.contains(key) {
                continue
            }
            seenKeys.insert(key)
            valid.append(c)
        }

        return valid
    }

    // MARK: - Legacy / Flat String Support (Backwards Compatibility)

    /// Parses flat lines into structured transaction result.
    public static func parseReceipt(from lines: [String], rules: [MerchantRule] = []) -> ReceiptScanResult? {
        let cleanedLines = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedLines.isEmpty else { return nil }

        // Check if there is an overall grand total and merchant for the document
        let docMerchant = extractMerchant(from: cleanedLines)
        let docAmount = extractAmount(from: cleanedLines)
        let docDate = extractDate(from: cleanedLines)

        // Synthesize spatial tokens with proportional Y positions for legacy feeds
        var syntheticTokens: [OCRSpatialToken] = []
        let totalCount = CGFloat(max(cleanedLines.count, 1))
        for (i, line) in cleanedLines.enumerated() {
            let y = CGFloat(i) / totalCount
            let box = CGRect(x: 0.1, y: y, width: 0.8, height: 1.0 / totalCount)
            syntheticTokens.append(OCRSpatialToken(text: line, boundingBox: box, confidence: 1.0))
        }

        let tagged = classifyTokenRoles(syntheticTokens)
        let blocks = clusterAdaptiveBlocks(tokens: tagged)
        var candidates: [ParsedTransactionCandidate] = []

        // If multiple distinct store anchors exist, extract multi-candidates
        let storeAnchorsCount = tagged.filter { $0.role == .merchantName }.count
        if storeAnchorsCount > 1 && blocks.count > 1 {
            candidates = extractCandidates(from: blocks, fallbackTokens: tagged, rules: rules)
        }

        // Single receipt / invoice / SMS with clear grand total
        if candidates.isEmpty {
            guard let amount = docAmount else { return nil }
            let merchant = docMerchant ?? "הוצאה מצילום מסך"
            let classification = MerchantRuleService.classify(
                merchant: merchant,
                amount: amount,
                rules: rules
            )
            let single = ParsedTransactionCandidate(
                merchant: merchant,
                amount: amount,
                currency: "ILS",
                date: docDate,
                category: classification.category,
                buildingId: classification.buildingId,
                confidence: classification.confidence,
                sourceHint: detectSourceHint(from: cleanedLines.joined(separator: " ")),
                rawEvidence: cleanedLines.joined(separator: "\n")
            )
            candidates = [single]
        }

        return ReceiptScanResult(
            candidates: candidates,
            rawText: cleanedLines.joined(separator: "\n")
        )
    }

    // MARK: - Amount Extraction Logic

    public static func extractAmount(from lines: [String]) -> Double? {
        var bestCandidate: Double? = nil
        var highestScore: Int = -100

        let primaryTotalKeywords = [
            "סה\"כ לתשלום", "סה״כ לתשלום", "סך הכל לתשלום", "סך-הכל לתשלום",
            "סך הכל", "סה\"כ", "סה״כ", "סך-הכל", "סהכ",
            "סכום לתשלום", "סכום החיוב", "סכום העסקה", "סכום שחויב", "סכום ההעברה",
            "סכום סופי", "סך לתשלום", "לתשלום", "חויב", "חוייב", "חויבת בסך",
            "total amount", "grand total", "amount paid", "amount due",
            "total paid", "total due", "charged", "total"
        ]

        let secondaryKeywords = [
            "אשראי", "כרטיס", "שולם ב-", "שולם באמצעות", "העברת", "סכום",
            "ע\"ס", "ע״ס", "בסך", "בסכום", "paid with", "visa", "mastercard"
        ]

        let negativeKeywords = [
            "הנחה", "discount", "coupon", "קופון", "מע\"מ", "מע״מ", "vat", "tax",
            "דמי משלוח", "משלוח", "delivery", "טיפ", "tip", "subtotal", "יתרה", "balance"
        ]

        for line in lines {
            let lower = line.lowercased()
            if isNoiseLine(lower) { continue }

            let numbers = extractNumbers(from: line)
            guard !numbers.isEmpty else { continue }

            var score = 0
            let hasPrimaryKeyword = primaryTotalKeywords.contains(where: { lower.contains($0) })
            let hasSecondaryKeyword = secondaryKeywords.contains(where: { lower.contains($0) })
            let hasCurrency = lower.contains("₪") || lower.contains("ש״ח") || lower.contains("ש\"ח") || lower.contains("ils") || lower.contains("nis") || lower.contains("$") || lower.contains("usd") || lower.contains("€") || lower.contains("eur") || lower.contains("£")

            // Strict rule: MUST have either an explicit financial keyword or a currency symbol
            guard hasPrimaryKeyword || hasSecondaryKeyword || hasCurrency else {
                continue
            }

            if hasPrimaryKeyword {
                score += 200
            } else if hasSecondaryKeyword {
                score += 90
            }

            if hasCurrency {
                score += 70
            }

            if negativeKeywords.contains(where: { lower.contains($0) }) {
                score -= 150
            }

            for num in numbers {
                var candidateScore = score
                if num >= 1.0 && num <= 25_000.0 { candidateScore += 20 }
                if candidateScore > highestScore && candidateScore >= 50 {
                    highestScore = candidateScore
                    bestCandidate = num
                }
            }
        }

        if bestCandidate == nil {
            // Fallback: only check lines with explicit currency symbols (not bare numbers)
            for line in lines.reversed() {
                let lower = line.lowercased()
                let hasCurrency = lower.contains("₪") || lower.contains("ש״ח") || lower.contains("ש\"ח") || lower.contains("ils") || lower.contains("$") || lower.contains("€") || lower.contains("£")
                if hasCurrency && !isNoiseLine(lower) && !isCouponOrDiscount(lower) {
                    if let val = extractNumbers(from: line).last, val > 0.1, val < 250_000 {
                        return val
                    }
                }
            }
        }

        return bestCandidate
    }

    // MARK: - Helper Classifiers

    private static func isNoiseLine(_ lower: String) -> Bool {
        if lower.contains("טלפון") || lower.contains("פקס") || lower.contains("phone") { return true }
        if lower.contains("battery") || lower.contains("issue") || lower.contains("debug") || lower.contains("xcode") || lower.contains("ingest") { return true }
        if lower.contains("%") { return true }
        if lower.range(of: #"^\s*(?:\d{1,2}[./\-]\d{1,2}[./\-]\d{2,4}|\d{1,2}:\d{2})\s*$"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #"[x*]{3,}\s*[-]?\s*\d{4}"#, options: .regularExpression) != nil && !lower.contains("סה") { return true }
        return false
    }

    private static func isCouponOrDiscount(_ lower: String) -> Bool {
        return lower.contains("coupon") || lower.contains("קופון") ||
               lower.contains("הנחה") || lower.contains("discount") ||
               lower.contains("החזר") || lower.contains("cashback") ||
               lower.contains("coupon if delayed")
    }

    private static func isQuantity(_ lower: String) -> Bool {
        return lower.range(of: #"^(?:x\s*\d+|\d+\s*pc|\d+\s*pcs|qty:?\s*\d+)$"#, options: .regularExpression) != nil ||
               lower == "x1" || lower == "x2" || lower == "x3" || lower == "1pc" || lower == "2pcs"
    }

    private static func isActionButton(_ lower: String) -> Bool {
        return lower.contains("track status") || lower.contains("track order") ||
               lower.contains("confirm received") || lower.contains("buy again") ||
               lower.contains("leave feedback") || lower.contains("view details") ||
               lower.contains("מעקב משלוח") || lower.contains("אישור קבלה")
    }

    private static func isOrderMetadata(_ lower: String) -> Bool {
        return lower.contains("order id") || lower.contains("order no") ||
               lower.contains("tracking no") || lower.contains("מספר הזמנה") ||
               lower.contains("מספר משלוח") || lower.contains("delivery period")
    }

    private static func isStoreAnchor(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("store") || lower.contains("shop") || lower.contains("official") || lower.contains("חנות") {
            return true
        }
        if matchKnownMerchant(in: text) != nil {
            return true
        }
        return false
    }

    private static func isAmountIndicator(_ lower: String) -> Bool {
        return lower.contains("סך") || lower.contains("סה\"כ") || lower.contains("סה״כ") ||
               lower.contains("לתשלום") || lower.contains("חויב") || lower.contains("total") ||
               lower.contains("price") || lower.contains("מחיר")
    }

    private static func isPhoneOrBarcode(_ lower: String, numbers: [Double]) -> Bool {
        if lower.contains("050") || lower.contains("052") || lower.contains("054") || lower.contains("053") || lower.contains("03-") {
            return true
        }
        return false
    }

    private static func isGenericBoilerplate(_ lower: String) -> Bool {
        let generic = [
            "חשבונית מס", "קבלה", "אישור תשלום", "תודה שקניתם", "פרטי תשלום",
            "receipt", "invoice", "payment", "order summary", "thank you", "total"
        ]
        return generic.contains { lower.contains($0) }
    }

    private static func detectCurrencySymbol(_ text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("₪") || lower.contains("ש״ח") || lower.contains("ש\"ח") || lower.contains("ils") || lower.contains("nis") {
            return "ILS"
        }
        if lower.contains("$") || lower.contains("usd") {
            return "USD"
        }
        if lower.contains("€") || lower.contains("eur") {
            return "EUR"
        }
        return nil
    }

    private static func detectSourceHint(from text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("aliexpress") || lower.contains("עלי אקספרס") { return "AliExpress" }
        if lower.contains("amazon") || lower.contains("אמזון") { return "Amazon" }
        if lower.contains("wolt") || lower.contains("וולט") { return "Wolt" }
        if lower.contains("apple pay") { return "Apple Pay" }
        if lower.contains("bit") || lower.contains("ביט") { return "Bit" }
        if lower.contains("paybox") || lower.contains("פייבוקס") { return "PayBox" }
        return nil
    }

    private static func sanitizeMerchantName(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n-–—,.·:;|/\"'״׳*#0123456789"))
        if let known = matchKnownMerchant(in: clean) {
            return known
        }
        return clean
    }

    // MARK: - Numbers & Date Regex Parsers

    private static func extractNumbers(from text: String) -> [Double] {
        let pattern = #"(?:₪|\$|€|ILS|NIS)?\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        var results: [Double] = []
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            var raw = nsString.substring(with: match.range(at: 1))
            if raw.contains(",") && raw.contains(".") {
                raw = raw.replacingOccurrences(of: ",", with: "")
            } else if raw.contains(",") {
                let parts = raw.split(separator: ",")
                if parts.count == 2 && parts[1].count <= 2 {
                    raw = raw.replacingOccurrences(of: ",", with: ".")
                } else {
                    raw = raw.replacingOccurrences(of: ",", with: "")
                }
            }

            if let val = Double(raw), val > 0, val < 500_000 {
                results.append(val)
            }
        }
        return results
    }

    public static func extractMerchant(from lines: [String]) -> String? {
        let genericBoilerplate = [
            "חשבונית מס", "חשבונית עסקה", "קבלה", "מקור", "העתק", "אישור תשלום",
            "פרטי העסקה", "סיכום הזמנה", "פרטי תשלום", "תודה שקניתם", "ברוכים הבאים",
            "מספר עוסק", "ח.פ", "ע.מ", "טלפון", "פקס", "כתובת", "תאריך", "שעה",
            "כרטיס אשראי", "מספר אישור", "סך הכל", "תשלומים", "receipt", "invoice",
            "tax invoice", "payment confirmation", "order summary", "thank you",
            "הודעה מאת", "אושרה בתאריך", "כרטיס מסתיים", "בכרטיס", "עסקה חדשה"
        ]

        let fullText = lines.joined(separator: "\n")

        for line in lines {
            if let range = line.range(of: #"(?:העברת ל|העברה ל|העברה אל|שילמת ל|שולם ל)\s*([^\d\n\r,.:;]+)"#, options: .regularExpression) {
                let match = String(line[range])
                    .replacingOccurrences(of: #"^(?:העברת ל|העברה ל|העברה אל|שילמת ל|שולם ל)\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if match.count >= 2 { return match }
            }
        }

        let smsPatterns = [
            #"(?:עסקתך ב-|עסקה ב-|רכשת ב-|שילמת ב-|חיוב מ-|הזמנה מ-|הזמנה ב-|חויבת ב-)\s*([^\d\n\r,;]{2,30}?)(?:\s+ע[״"][ס|ש]|\s+בסך|\s+בסכום|\s+בכרטיס|\s+באמצעות|\s+בתאריך|\s+ב-|\s+₪|\s+\d|$)"#,
            #"(?:ב-|מ-)([A-Za-z0-9א-ת\s\-&'׳״]{2,25}?)(?:\s+ע[״"][ס|ש]|\s+בסך|\s+על סך|\s+בסכום)"#
        ]

        for pattern in smsPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                for line in lines {
                    let ns = line as NSString
                    if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges > 1 {
                        let extracted = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                        if extracted.count >= 2 && !genericBoilerplate.contains(where: { extracted.lowercased().contains($0) }) {
                            return normalizeMerchantName(extracted)
                        }
                    }
                }
            }
        }

        if let known = matchKnownMerchant(in: fullText) {
            return known
        }

        for line in lines.prefix(6) {
            let lower = line.lowercased()
            let isBoilerplate = genericBoilerplate.contains { lower.contains($0) }
            if !isBoilerplate && line.contains(where: { $0.isLetter }) {
                let cleaned = TransactionIngest.nameWithoutAmount(line) ?? line
                let candidate = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n-–—,.·:;|/\"'״׳*#0123456789"))
                if candidate.count >= 2 && !genericBoilerplate.contains(where: { candidate.lowercased().contains($0) }) {
                    return candidate
                }
            }
        }

        return nil
    }

    private static func matchKnownMerchant(in text: String) -> String? {
        let lower = text.lowercased()
        let dictionary: [(key: String, name: String)] = [
            ("שופרסל", "שופרסל"), ("רמי לוי", "רמי לוי"), ("ויקטורי", "ויקטורי"),
            ("יוחננוף", "יוחננוף"), ("אושר עד", "אושר עד"), ("טיב טעם", "טיב טעם"),
            ("חצי חינם", "חצי חינם"), ("מחסני השוק", "מחסני השוק"), ("am:pm", "AM:PM"),
            ("ampm", "AM:PM"), ("סופר יודה", "סופר יודה"), ("קארפור", "Carrefour"),
            ("carrefour", "Carrefour"), ("מגה בעיר", "מגה בעיר"), ("wolt", "Wolt"),
            ("וולט", "Wolt"), ("10bis", "10bis תן ביס"), ("תן ביס", "10bis תן ביס"),
            ("מקדונלד", "מקדונלד'ס"), ("mcdonald", "McDonald's"), ("ארומה", "ארומה"),
            ("aroma", "ארומה"), ("קפה גרג", "קפה גרג"), ("לנדוור", "קפה לנדוור"),
            ("סופר-פארם", "סופר-פארם"), ("סופר פארם", "סופר-פארם"), ("סופרפארם", "סופר-פארם"),
            ("super-pharm", "Super-Pharm"), ("super pharm", "Super-Pharm"), ("superpharm", "Super-Pharm"),
            ("zara", "ZARA"), ("זארה", "ZARA"), ("h&m", "H&M"), ("aliexpress", "AliExpress"),
            ("amazon", "Amazon"), ("אמזון", "Amazon"), ("ksp", "KSP"), ("איקאה", "IKEA"),
            ("pango", "פנגו Pango"), ("פנגו", "פנגו Pango"), ("netflix", "Netflix"), ("spotify", "Spotify"),
            ("יס", "YES"), ("yes", "YES"), ("הוט", "HOT"), ("hot", "HOT"),
            ("פרטנר", "Partner"), ("partner", "Partner"), ("סלקום", "Cellcom"), ("cellcom", "Cellcom"),
            ("פלאפון", "Pelephone"), ("pelephone", "Pelephone"), ("בזק", "בזק"), ("bezeq", "בזק")
        ]

        for (key, display) in dictionary.sorted(by: { $0.0.count > $1.0.count }) {
            if containsMerchantToken(lower, key: key) {
                return display
            }
        }
        return nil
    }

    private static func containsMerchantToken(_ text: String, key: String) -> Bool {
        if key.count >= 4 { return text.contains(key) }
        let escaped = NSRegularExpression.escapedPattern(for: key)
        let bounded = "(?<![\\p{L}\\p{N}])" + escaped + "(?![\\p{L}\\p{N}])"
        return text.range(of: bounded, options: .regularExpression) != nil
    }

    private static func normalizeMerchantName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n-–—,.·:;|/\"'״׳"))
        if let match = matchKnownMerchant(in: trimmed) { return match }
        return trimmed
    }

    public static func extractDate(from lines: [String]) -> Date? {
        let datePatterns = [
            #"[0-3]?[0-9][./\-][0-1]?[0-9][./\-](?:20)?[0-9]{2}"#,
            #"[0-9]{4}[./\-][0-1]?[0-9][./\-][0-3]?[0-9]"#
        ]
        let formats = [
            "dd/MM/yyyy", "dd.MM.yyyy", "dd-MM-yyyy",
            "dd/MM/yy", "dd.MM.yy", "dd-MM-yy",
            "yyyy-MM-dd", "yyyy/MM/dd"
        ]

        for line in lines {
            for pattern in datePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let nsString = line as NSString
                if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                    let dateStr = nsString.substring(with: match.range)
                    for fmt in formats {
                        let df = DateFormatter()
                        df.dateFormat = fmt
                        df.locale = Locale(identifier: "en_US_POSIX")
                        df.timeZone = TimeZone(secondsFromGMT: 0)
                        if let d = df.date(from: dateStr) {
                            return TransactionIngest.sanitizedDate(d)
                        }
                    }
                }
            }
        }
        return nil
    }
}

/// Thread-safe latch to ensure CheckedContinuation is resumed exactly once.
private final class OCRResumeLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
