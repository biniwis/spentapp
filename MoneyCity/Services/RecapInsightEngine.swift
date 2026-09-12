import Foundation

// MARK: - Recap 2.0 · Phase 2 (data layer) + Phase 3 (candidate generators)
//
// "Motion system stays. Content system evolves."
// This file is pure data: it knows how to look at a month and say what is going on.
// It does not know about views, shots, timing or animations. Curation (Phase 5) and
// presentation (Phase 6/7) sit above this and stay fully separate.
//
// Rules honoured from the start:
// - Deterministic: same input always produces the same candidate list, in the same order.
// - No real randomness anywhere. Copy-variant selection uses fixed seeds when it arrives.
// - Weak data never produces a candidate: eligibility is data-driven, never padded.
// - Everything is on-device. No network, no LLM.

/// Families keep the recap diverse. Two candidates from the same family can never both
/// win a slot in the curated recap (Phase 5), so families are the first line of
/// anti-duplication. Cross-month novelty (Phase 5/9) keys on family too, once a
/// `RecapSnapshot` exists.
enum RecapInsightFamily: String, Sendable, Equatable, CaseIterable, Codable {
    /// Many small purchases that silently added up. ("הדברים הקטנים הצטברו")
    case accumulation
    /// A habit or behaviour repeated enough to be a pattern. (deliveries, coffee, category)
    case repetition
    /// Something specific to one merchant or the relationship between merchants.
    case merchant
    /// When within the month things happened (day of week, a single day, time of day).
    case timing
    /// Consecutive days of silence (no-spend streak) or non-stop activity.
    case streak
    /// Directional movement over time (week-to-week, month-to-month trends).
    case trend
    /// Comparing two parts of the month or two kinds of behaviour against each other.
    case comparison
    /// A small number of purchases carrying a large share of the month.
    case concentration
    /// The opposite: many different places / many categories.
    case diversity
    /// One purchase that breaks the pattern of everything around it.
    case outlier
    /// A category that visibly changed versus its own baseline.
    case category
}

/// The concrete kind behind a candidate. Each kind is produced by exactly one generator
/// and determines the copy shape and (later, Phase 6) the presentation template.
enum RecapInsightKind: String, Sendable, Equatable, CaseIterable {
    case smallPurchasesAccumulation
    case repeatedMerchant
    case deliveryHabit
    case coffeeHabit
    case repeatedCategory
    case busiestDay
    case noSpendStreak
    case firstHalfVsSecondHalf
    case dayOfWeekPattern
    case spendingConcentration
    case merchantDiversity
    case categoryChange
    case bigVsFrequent
    case outlierPurchase
}

/// A single measurable piece of evidence that explains *why* a candidate was generated.
/// This is what lets a debug screen (Phase 10) and the Phase 3 review answer "why?".
struct RecapInsightBasis: Sendable, Equatable, Identifiable {
    let id: String
    let label: String
    let value: String

    init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

/// Percandidate signal scores. Zero by default: they are filled in by Phase 4 scoring.
struct RecapInsightScores: Sendable, Equatable {
    var surprise: Double = 0
    var relevance: Double = 0
    var contrast: Double = 0
    var confidence: Double = 0
    var novelty: Double = 0
    var total: Double = 0 // Phase 4 weighted blend

    init() {}

    init(surprise: Double, relevance: Double, contrast: Double, confidence: Double, novelty: Double, total: Double) {
        self.surprise = surprise
        self.relevance = relevance
        self.contrast = contrast
        self.confidence = confidence
        self.novelty = novelty
        self.total = total
    }
}

/// The concrete evidence behind a candidate: exactly which transactions back it and which
/// entities it anchors on. Overlap resolution (Phase 3.5) compares this, not families —
/// two candidates about the same underlying transactions/entity are the same story even
/// when their families differ.
struct RecapInsightEvidence: Sendable, Equatable {
    /// The stable IDs of the transactions the candidate is literally about.
    var transactionIDs: Set<UUID>
    /// Normalized merchant key (`MerchantRuleService.normalizedKey`) when the story is merchant-bound.
    var merchantKey: String?
    /// Canonical category when the story is category-bound.
    var categoryKey: SpendingCategory?
    /// Stable anchor for habit/pattern stories (habit kind, weekday, calendar day).
    var entityKey: String?

    init(transactionIDs: Set<UUID> = [], merchantKey: String? = nil,
         categoryKey: SpendingCategory? = nil, entityKey: String? = nil) {
        self.transactionIDs = transactionIDs
        self.merchantKey = merchantKey
        self.categoryKey = categoryKey
        self.entityKey = entityKey
    }
}

/// An insight candidate: everything the engine knows about one observation in a month.
/// The UI never sees this object directly; the curator (Phase 5) selects from a pool of
/// candidates and Phase 6 maps the winners onto the existing recap presentation.
struct RecapInsight: Identifiable, Sendable, Equatable {
    let id: String
    let family: RecapInsightFamily
    let kind: RecapInsightKind

    let headlineEn: String
    let headlineHe: String
    let valueEn: String?
    let valueHe: String?
    let supportEn: String?
    let supportHe: String?

    // Typed identifiers so scoring and curation can reason about overlap.
    let merchant: String?
    let category: SpendingCategory?
    let date: Date?
    let count: Int?
    let totalAmount: Double?
    let shareOfTotal: Double?
    let ratio: Double?
    let direction: Double? // +/- percent change where the insight has a direction

    let basis: [RecapInsightBasis]
    /// Provisional 0–1 magnitude for the Phase 3 review. Phase 4 replaces this with the
    /// calibrated weighted score.
    let strength: Double
    /// The transactions and entities this candidate is literally about. Overlap resolution
    /// compares this field — it decides whether two candidates tell the same story.
    let evidence: RecapInsightEvidence
    var scores = RecapInsightScores()

    init(id: String,
         family: RecapInsightFamily,
         kind: RecapInsightKind,
         headlineEn: String,
         headlineHe: String,
         valueEn: String? = nil,
         valueHe: String? = nil,
         supportEn: String? = nil,
         supportHe: String? = nil,
         merchant: String? = nil,
         category: SpendingCategory? = nil,
         date: Date? = nil,
         count: Int? = nil,
         totalAmount: Double? = nil,
         shareOfTotal: Double? = nil,
         ratio: Double? = nil,
         direction: Double? = nil,
         basis: [RecapInsightBasis],
         strength: Double,
         evidence: RecapInsightEvidence = RecapInsightEvidence()) {
        self.id = id
        self.family = family
        self.kind = kind
        self.headlineEn = headlineEn
        self.headlineHe = headlineHe
        self.valueEn = valueEn
        self.valueHe = valueHe
        self.supportEn = supportEn
        self.supportHe = supportHe
        self.merchant = merchant
        self.category = category
        self.date = date
        self.count = count
        self.totalAmount = totalAmount
        self.shareOfTotal = shareOfTotal
        self.ratio = ratio
        self.direction = direction
        self.basis = basis
        self.strength = strength
        self.evidence = evidence
    }
}

// MARK: - Engine

/// Looks at one month of transactions and produces a broad, deterministic pool of
/// candidates. It never decides what the recap shows — that is the curator's job.
enum RecapInsightEngine {

    /// Everything the generators need, computed once so all twelve share the same numbers.
    private struct MonthContext {
        let interval: DateInterval
        let calendar: Calendar
        let allTransactions: [Transaction]
        let spend: [Transaction]
        let variable: [Transaction]
        let total: Double
        let variableTotal: Double
        let spendDays: [Date] // sorted active spending days
        let now: Date
        let monthLength: Int

        var activeSpendDays: Int { spendDays.count }
    }

    // MARK: Public API

    /// Runs the full Phase 3→4 pipeline: generate candidates → resolve evidence overlap →
    /// score. Returns the surviving, scored candidates in deterministic generator order.
    static func generateCandidates(
        for month: Date,
        allTransactions: [Transaction],
        now: Date = Date(),
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> [RecapInsight] {
        pipeline(for: month, allTransactions: allTransactions, now: now, calendar: calendar).kept
    }

    /// Human-readable dump of the whole pipeline: every candidate, its Phase 4 scores, and
    /// every overlap rejection with the winner it lost to. Used by the Phase 4 review and
    /// the DEBUG Design Lab (Phase 10). Deterministic.
    static func debugReport(for month: Date, allTransactions: [Transaction], now: Date = Date()) -> String {
        let result = pipeline(for: month, allTransactions: allTransactions, now: now, calendar: .init(identifier: .gregorian))
        var lines: [String] = []
        lines.append("=== \(RecapInsightEngine.monthTitle(month)) · \(result.generated.count) generated · \(result.kept.count) kept ===")
        if result.kept.isEmpty {
            lines.append("(no candidates — sparse or flat month, nothing inventing to say)")
            return lines.joined(separator: "\n")
        }
        for (index, c) in result.kept.enumerated() {
            lines.append("[\(index + 1)] \(c.kind.rawValue) · family=\(c.family.rawValue) · id=\(c.id)")
            let copy = c.headlineEn + (c.valueEn.map { " → \($0)" } ?? "") + (c.supportEn.map { "  [\($0)]" } ?? "")
            lines.append("    en: \(copy)")
            let whose = [c.merchant.map { "merchant=\($0)" }, c.category.map { "category=\($0.rawValue)" }]
                .compactMap { $0 }
            lines.append("    \(whose.joined(separator: " "))")
            let why = c.basis.map { "\($0.label)=\($0.value)" }.joined(separator: " · ")
            lines.append("    why: \(why) · strength \(String(format: "%.2f", c.strength))")
            let s = c.scores
            lines.append("    scores: surprise \(String(format: "%.2f", s.surprise)) · relevance \(String(format: "%.2f", s.relevance)) · contrast \(String(format: "%.2f", s.contrast)) · confidence \(String(format: "%.2f", s.confidence)) · novelty \(String(format: "%.2f", s.novelty)) → total \(String(format: "%.2f", s.total))")
        }
        if !result.rejections.isEmpty {
            lines.append("")
            lines.append("rejected (same story):")
            for rejection in result.rejections {
                lines.append("rejected: overlaps \(Int((rejection.fraction * 100).rounded()))% with \(rejection.winnerID) (\(rejection.reason))")
            }
        }
        if !result.penalties.isEmpty {
            lines.append("")
            lines.append("penalized (overlapping evidence, different story):")
            for penalty in result.penalties {
                lines.append("penalized: overlaps \(Int((penalty.fraction * 100).rounded()))% with \(penalty.partnerID) → total \(String(format: "%.2f", penalty.before)) → \(String(format: "%.2f", penalty.after))")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Pipeline

    private struct OverlapRejection {
        let loserID: String
        let winnerID: String
        let fraction: Double
        let reason: String
    }

    /// A candidate whose score was docked (not rejected) because it shares a large
    /// amount of evidence with a candidate that means something different.
    private struct OverlapPenalty {
        let loserID: String
        let partnerID: String
        let fraction: Double
        let before: Double
        let after: Double
    }

    private struct PipelineResult {
        let generated: [RecapInsight]
        /// Veto-deduped (Phase 3.5) and scored + penalized (Phase 4) candidates, generator order.
        let kept: [RecapInsight]
        let rejections: [OverlapRejection]
        let penalties: [OverlapPenalty]
    }

    private static func pipeline(
        for month: Date,
        allTransactions: [Transaction],
        now: Date,
        calendar: Calendar
    ) -> PipelineResult {
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            return PipelineResult(generated: [], kept: [], rejections: [], penalties: [])
        }

        let spend = allTransactions.filter {
            $0.timestamp >= interval.start && $0.timestamp < interval.end &&
            $0.amount.isFinite && $0.amount > 0 && $0.category.canonical != .savings
        }
        let total = spend.reduce(0) { $0 + $1.amount }
        let variable = spend.filter { !MonthlyRecapService.isLikelyRecurringOrFixed($0) }
        let variableTotal = variable.reduce(0) { $0 + $1.amount }

        let spendDays = Set(spend.map { calendar.startOfDay(for: $0.timestamp) })
            .sorted { $0 < $1 }
        let monthLength = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30

        let ctx = MonthContext(
            interval: interval,
            calendar: calendar,
            allTransactions: allTransactions,
            spend: spend,
            variable: variable,
            total: total,
            variableTotal: variableTotal,
            spendDays: spendDays,
            now: now,
            monthLength: monthLength
        )

        var candidates: [RecapInsight] = []
        if let c = smallPurchasesAccumulation(ctx) { candidates.append(c) }
        candidates.append(contentsOf: repeatedMerchants(ctx))
        candidates.append(contentsOf: repetitionCandidates(ctx))
        if let c = busiestDay(ctx) { candidates.append(c) }
        if let c = noSpendStreak(ctx) { candidates.append(c) }
        if let c = firstHalfVsSecondHalf(ctx) { candidates.append(c) }
        if let c = dayOfWeekPattern(ctx) { candidates.append(c) }
        if let c = spendingConcentration(ctx) { candidates.append(c) }
        if let c = merchantDiversity(ctx) { candidates.append(c) }
        candidates.append(contentsOf: categoryChanges(ctx))
        if let c = bigVsFrequent(ctx) { candidates.append(c) }
        if let c = outlierPurchase(ctx) { candidates.append(c) }

        let resolved = resolveOverlaps(candidates)
        let scored = resolved.kept.map { scoredCandidate($0, ctx: ctx) }
        let penalized = applyOverlapPenalties(scored)
        return PipelineResult(
            generated: candidates,
            kept: penalized.kept,
            rejections: resolved.rejections,
            penalties: penalized.penalties
        )
    }

    // MARK: - Evidence overlap (Phase 3.5 veto + Phase 5 different-meaning penalty)

    /// Minimum shared-evidence share before two stories are treated as overlapping.
    /// Internal so the Phase 5 curator applies identical rules to the backbone slots.
    static let recapOverlapFractionThreshold = 0.55
    /// Weight applied to the lower-scored side of a strong overlap (shared merchant/
    /// entity actor, genuinely different meaning): `total *= 1 - weight * fraction`.
    /// Overlap is a penalty, never a veto, when the two stories differ in meaning.
    static let recapOverlapPenaltyWeight = 0.30
    /// Weight for an adjacent overlap: same category but a different story or
    /// granularity (a category-wide pattern vs a single exceptional purchase, a
    /// behaviour vs the category's size). Deliberately mild — these coexist.
    static let recapOverlapAdjacentWeight = 0.10

    /// How two stories relate once they share most of the smaller side's evidence.
    enum OverlapRelation {
        case none
        /// The exact same story told twice: same transactions, same merchant/entity
        /// claim, or a merchant entirely contained in the category/habit that carries
        /// its purchases. The weaker side is rejected.
        case sameStory(fraction: Double)
        /// Same subject at close granularity but a genuinely different proposition
        /// (shared merchant/entity actor, different meaning). Docked hard.
        case strongOverlap(fraction: Double)
        /// Same category but a different story or granularity — a category-wide pattern
        /// vs a single exceptional purchase, a behaviour vs the category's size. Small
        /// dock or none: allowed to coexist.
        case adjacent(fraction: Double)
    }

    /// How much of the smaller story's evidence is also part of the larger one.
    static func overlapFraction(_ a: Set<UUID>, _ b: Set<UUID>) -> Double {
        let aCount = a.count
        let bCount = b.count
        guard aCount > 0, bCount > 0 else { return 0 }
        let shared = a.intersection(b).count
        return Double(shared) / Double(min(aCount, bCount))
    }

    /// Kinds whose story centres on one subject. Aggregate states (accumulation,
    /// concentration, whole-month splits) and relational compounds (bigVsFrequent,
    /// which contrasts two merchants) are deliberately excluded: they can never be a
    /// duplicate, only a penalized neighbour.
    private static let singleSubjectKinds: Set<RecapInsightKind> = [
        .repeatedMerchant, .repeatedCategory, .deliveryHabit, .coffeeHabit,
        .busiestDay, .dayOfWeekPattern, .categoryChange, .outlierPurchase,
    ]
    /// A merchant-bound story can be the exact same story as the category or habit that
    /// contains the same purchases.
    private static let merchantBoundKinds: Set<RecapInsightKind> = [.repeatedMerchant]
    /// "X dominated the month" propositions. Two of these on the same category are the
    /// same story; a change or habit proposition on the same category is not.
    private static let categoryDominanceKinds: Set<RecapInsightKind> = [.repeatedCategory]

    /// Canonical shape of "what is this story about", used for both candidates and the
    /// curator's fixed backbone slots so a single comparison function guards both.
    struct RecapStoryProfile: Sendable, Equatable {
        let id: String
        let kind: RecapInsightKind?
        let isBackbone: Bool
        let isSingleSubject: Bool
        let isMerchantBound: Bool
        let isCategoryDominance: Bool
        let merchantKey: String?
        let entityKey: String?
        let categoryKey: SpendingCategory?
        let transactionIDs: Set<UUID>
    }

    static func storyProfile(_ candidate: RecapInsight) -> RecapStoryProfile {
        RecapStoryProfile(
            id: candidate.id,
            kind: candidate.kind,
            isBackbone: false,
            isSingleSubject: singleSubjectKinds.contains(candidate.kind),
            isMerchantBound: merchantBoundKinds.contains(candidate.kind),
            isCategoryDominance: categoryDominanceKinds.contains(candidate.kind),
            merchantKey: candidate.evidence.merchantKey,
            entityKey: candidate.evidence.entityKey,
            categoryKey: candidate.evidence.categoryKey,
            transactionIDs: candidate.evidence.transactionIDs
        )
    }

    /// How two stories relate when most of the smaller story's evidence is shared.
    ///
    /// Three tiers, ordered from deadliest to mildest:
    /// - `.sameStory`: the two candidates are alternative phrasings of one concrete
    ///   proposition (exact same transactions, same merchant/entity claim, an "X
    ///   dominated" story on the same category, or a merchant fully inside the
    ///   category/habit that carries the same purchases). The weaker one is rejected.
    /// - `.strongOverlap`: the same actor but a genuinely different proposition (a
    ///   relational compound vs the merchant it features). Docked hard.
    /// - `.adjacent`: same category but a different story or granularity — a
    ///   category-wide pattern vs a single exceptional purchase, or a behaviour vs the
    ///   category's size. Small dock or none; the stories are allowed to coexist.
    static func overlapRelation(_ a: RecapStoryProfile, _ b: RecapStoryProfile) -> OverlapRelation {
        let fraction = overlapFraction(a.transactionIDs, b.transactionIDs)
        guard fraction >= recapOverlapFractionThreshold else { return .none }

        // ---- Same story (veto): only between two concrete single-subject claims.
        if a.isSingleSubject, b.isSingleSubject {
            // Exact same underlying transactions is the strongest duplicate signal — it
            // survives even when one side is a single transaction (e.g. an outlier that
            // is literally the biggest-purchase Moment).
            if !a.transactionIDs.isEmpty, a.transactionIDs == b.transactionIDs {
                return .sameStory(fraction: fraction)
            }
            if let keyA = a.merchantKey, let keyB = b.merchantKey, keyA == keyB, !keyA.isEmpty {
                return .sameStory(fraction: fraction)
            }
            if let keyA = a.entityKey, let keyB = b.entityKey, keyA == keyB, !keyA.isEmpty {
                return .sameStory(fraction: fraction)
            }

            // Two "X dominated" propositions on the same category are the same story.
            let aCount = a.transactionIDs.count
            let bCount = b.transactionIDs.count
            if aCount >= 2, bCount >= 2, let keyA = a.categoryKey, keyA == b.categoryKey,
               a.isCategoryDominance, b.isCategoryDominance {
                return .sameStory(fraction: fraction)
            }

            // A merchant story whose every purchase sits inside the category/habit story
            // that carries the same category is that story, retold.
            if containedMerchant(a, in: b) || containedMerchant(b, in: a) {
                return .sameStory(fraction: fraction)
            }

            // Same category but a different story or granularity (a category-wide pattern
            // vs a single exceptional purchase, a behaviour vs the category's size).
            if let keyA = a.categoryKey, keyA == b.categoryKey {
                return .adjacent(fraction: fraction)
            }
            return .none
        }

        // ---- At least one side is an aggregate/relational story.
        // Shared merchant/entity actor, different proposition → docked hard.
        if let keyA = a.merchantKey, let keyB = b.merchantKey, keyA == keyB, !keyA.isEmpty {
            return .strongOverlap(fraction: fraction)
        }
        if let keyA = a.entityKey, let keyB = b.entityKey, keyA == keyB, !keyA.isEmpty {
            return .strongOverlap(fraction: fraction)
        }
        // Shared category only → neighbouring, different granularity → small dock or none.
        if let keyA = a.categoryKey, keyA == b.categoryKey {
            return .adjacent(fraction: fraction)
        }
        return .none
    }

    private static func containedMerchant(_ merchant: RecapStoryProfile, in parent: RecapStoryProfile) -> Bool {
        guard merchant.isMerchantBound, parent.transactionIDs.count >= 2 else { return false }
        guard merchant.transactionIDs.count >= 2, !merchant.transactionIDs.isEmpty else { return false }
        guard let parentCategory = parent.categoryKey,
              let merchantCategory = merchant.categoryKey,
              parentCategory == merchantCategory else { return false }
        return merchant.transactionIDs.isSubset(of: parent.transactionIDs)
    }

    /// Greedy dedupe: keep the stronger candidate (strength, then id for stability) and
    /// reject anything that is literally the same story. Result is deterministic and
    /// re-ordered back into the original generator order.
    private static func resolveOverlaps(_ candidates: [RecapInsight]) -> (kept: [RecapInsight], rejections: [OverlapRejection]) {
        let ordered = candidates.sorted {
            if $0.strength != $1.strength { return $0.strength > $1.strength }
            return $0.id < $1.id
        }
        let orderByID = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset) })

        var kept: [RecapInsight] = []
        var rejections: [OverlapRejection] = []
        for candidate in ordered {
            let candidateProfile = storyProfile(candidate)
            if let winner = kept.first(where: {
                if case .sameStory = overlapRelation(storyProfile($0), candidateProfile) { return true }
                return false
            }) {
                rejections.append(OverlapRejection(
                    loserID: candidate.id,
                    winnerID: winner.id,
                    fraction: overlapFraction(candidate.evidence.transactionIDs, winner.evidence.transactionIDs),
                    reason: "same story"
                ))
            } else {
                kept.append(candidate)
            }
        }
        kept.sort { (orderByID[$0.id] ?? 0) < (orderByID[$1.id] ?? 0) }
        return (kept, rejections)
    }

    /// Docks the score of the weaker side of every strong/adjacent overlap. Adjacent
    /// evidence is allowed to coexist, but the recap should not get it for free twice.
    private static func applyOverlapPenalties(_ scored: [RecapInsight]) -> (kept: [RecapInsight], penalties: [OverlapPenalty]) {
        var result = scored
        var penalties: [OverlapPenalty] = []
        let profiles = result.map { storyProfile($0) }

        for i in 0..<result.count {
            var weakestFactor = 1.0
            var worstFraction = 0.0
            var partnerID: String?
            for j in 0..<result.count where i != j {
                let relation = overlapRelation(profiles[i], profiles[j])
                let weight: Double
                let fraction: Double
                switch relation {
                case .strongOverlap(let f):
                    weight = recapOverlapPenaltyWeight
                    fraction = f
                case .adjacent(let f):
                    weight = recapOverlapAdjacentWeight
                    fraction = f
                case .none, .sameStory:
                    continue
                }
                let own = result[i].scores.total
                let other = result[j].scores.total
                let isWeakerSide = own < other || (own == other && result[i].id > result[j].id)
                guard isWeakerSide else { continue }
                let factor = 1 - weight * fraction
                if factor < weakestFactor {
                    weakestFactor = factor
                    worstFraction = fraction
                    partnerID = result[j].id
                }
            }
            if let partner = partnerID {
                let before = result[i].scores.total
                result[i].scores.total = min(1, max(0, before * weakestFactor))
                penalties.append(OverlapPenalty(
                    loserID: result[i].id,
                    partnerID: partner,
                    fraction: worstFraction,
                    before: before,
                    after: result[i].scores.total
                ))
            }
        }
        return (result, penalties)
    }

    // MARK: - Scoring (Phase 4)

    private static func scoredCandidate(_ candidate: RecapInsight, ctx: MonthContext) -> RecapInsight {
        var copy = candidate
        copy.scores = score(candidate, ctx: ctx)
        return copy
    }

    private static func score(_ candidate: RecapInsight, ctx: MonthContext) -> RecapInsightScores {
        let variableTotal = ctx.variableTotal

        let surprise: Double
        switch candidate.kind {
        case .outlierPurchase:
            surprise = min(1, (candidate.ratio ?? 1) / 8)
        case .dayOfWeekPattern:
            surprise = min(1, max(0, (candidate.ratio ?? 1) - 1) / 3)
        case .busiestDay:
            surprise = min(1, Double(candidate.count ?? 0) / 6)
        case .repeatedMerchant, .bigVsFrequent:
            surprise = min(1, max(0, Double(candidate.count ?? 0) - 2) * 0.15)
        case .smallPurchasesAccumulation:
            surprise = min(1, max(0, Double(candidate.count ?? 0) - 6) * 0.08)
        case .noSpendStreak:
            surprise = min(1, Double(candidate.count ?? 0) * 0.15)
        case .categoryChange:
            surprise = min(1, abs(candidate.direction ?? 0) / 120)
        case .firstHalfVsSecondHalf:
            // `direction` is the relative half-vs-half difference (0.9 = 90%), so the
            // scale is 0→1 over a 2x belt: flat months stay weak, ~100% differences
            // read clearly, extreme months saturate.
            surprise = min(1, max(0, abs(candidate.direction ?? 0) / 2.0))
        case .repeatedCategory, .deliveryHabit, .coffeeHabit:
            surprise = min(1, Double(candidate.count ?? 0) * 0.07)
        case .spendingConcentration:
            surprise = min(1, (candidate.shareOfTotal ?? 0) * 1.2)
        case .merchantDiversity:
            surprise = min(1, Double(candidate.count ?? 0) / 12)
        }

        // Relevance = how big a chunk of the month this explains.
        let relevance: Double
        if let totalAmount = candidate.totalAmount, variableTotal > 0 {
            relevance = min(1, totalAmount / (0.22 * variableTotal))
        } else if let share = candidate.shareOfTotal {
            relevance = min(1, share * 2.5)
        } else {
            relevance = 0.5
        }

        // Contrast = how far from the month's baseline this sits.
        let contrast: Double
        if let ratio = candidate.ratio {
            contrast = min(1, max(0, ratio - 1) / 4)
        } else if let direction = candidate.direction {
            contrast = candidate.kind == .firstHalfVsSecondHalf
                // Relative half-vs-half belt: ~150% difference reads strongly.
                ? min(1, max(0, abs(direction) / 1.5))
                : min(1, abs(direction) / 140)
        } else if let share = candidate.shareOfTotal {
            contrast = min(1, share / 0.6)
        } else {
            contrast = 0.5
        }

        let confidence: Double
        if candidate.kind == .firstHalfVsSecondHalf {
            // A half-vs-half read is only trustable when spread across enough active
            // days; a handful of days can be pure noise. 25+ active days ⇒ confident.
            confidence = min(1, Double(candidate.count ?? 0) / 25)
        } else if let count = candidate.count {
            confidence = min(1, 0.2 + Double(count) * 0.08)
        } else {
            confidence = 0.6
        }

        // Cross-month novelty is deferred until a RecapSnapshot exists (Phase 9).
        // Intra-recap diversity is the curator's job (Phase 5), not part of scoring.
        let novelty = 0.0

        // Phase 4 initial calibration; weights are revisited after curation integrates.
        let total = min(1, surprise * 0.30 + relevance * 0.25 + contrast * 0.20 + confidence * 0.15 + novelty * 0.10)
        return RecapInsightScores(
            surprise: surprise,
            relevance: relevance,
            contrast: contrast,
            confidence: confidence,
            novelty: novelty,
            total: total
        )
    }

    // MARK: - 1. Small Purchases Accumulation (accumulation)

    private static func smallPurchasesAccumulation(_ ctx: MonthContext) -> RecapInsight? {
        let txs = ctx.variable
        guard txs.count >= 6 else { return nil }
        let sorted = txs.sorted { $0.amount < $1.amount }
        let mid = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1].amount + sorted[mid].amount) / 2
            : sorted[mid].amount
        // "Small" scales with the month's own typical purchase so it works for any budget.
        let cap = min(80, max(20, median * 1.6))
        let small = txs.filter { $0.amount <= cap }
        let smallTotal = small.reduce(0) { $0 + $1.amount }
        let share = ctx.variableTotal > 0 ? smallTotal / ctx.variableTotal : 0
        guard small.count >= 6,
              Double(small.count) >= 0.3 * Double(txs.count),
              smallTotal >= max(150, 0.12 * ctx.variableTotal) else { return nil }

        return RecapInsight(
            id: RecapInsightKind.smallPurchasesAccumulation.rawValue,
            family: .accumulation,
            kind: .smallPurchasesAccumulation,
            headlineEn: "\(small.count) small purchases under \(money(cap)) added up.",
            headlineHe: "\(small.count) רכישות קטנות מתחת ל\(money(cap)) הצטברו.",
            valueEn: money(smallTotal),
            valueHe: money(smallTotal),
            supportEn: "\(pct(share)) of this month's variable spending",
            supportHe: "\(pct(share)) מההוצאות המשתנות החודש",
            count: small.count,
            totalAmount: smallTotal,
            shareOfTotal: share,
            basis: [
                .init(id: "count", label: "small purchases", value: "\(small.count)"),
                .init(id: "cap", label: "threshold per purchase", value: money(cap)),
                .init(id: "total", label: "combined total", value: money(smallTotal)),
                .init(id: "share", label: "share of variable spend", value: pct(share)),
            ],
            strength: min(0.95, 0.30 + Double(small.count) * 0.025 + share * 0.5),
            evidence: RecapInsightEvidence(transactionIDs: Set(small.map { $0.id }))
        )
    }

    // MARK: - 2. Repeated Merchant (merchant)

    private struct MerchantStat {
        let key: String
        let name: String
        let count: Int
        let total: Double
        let category: SpendingCategory
        let transactionIDs: Set<UUID>
    }

    private static func merchantStats(_ txs: [Transaction]) -> [MerchantStat] {
        var groups: [String: (name: String, count: Int, total: Double, category: SpendingCategory, transactionIDs: Set<UUID>)] = [:]
        for tx in txs {
            let raw = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }
            let key = MerchantRuleService.normalizedKey(raw)
            var entry = groups[key, default: (raw, 0, 0, tx.category.canonical, [])]
            entry.count += 1
            entry.total += tx.amount
            entry.transactionIDs.insert(tx.id)
            if raw.count < entry.name.count { entry.name = raw }
            groups[key] = entry
        }
        return groups.map { MerchantStat(key: $0.key, name: $0.value.name, count: $0.value.count, total: $0.value.total, category: $0.value.category, transactionIDs: $0.value.transactionIDs) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                if $0.total != $1.total { return $0.total > $1.total }
                return $0.name < $1.name
            }
    }

    private static func repeatedMerchants(_ ctx: MonthContext) -> [RecapInsight] {
        let ranked = merchantStats(ctx.variable)
        guard ranked.count >= 2 else { return [] }
        let top = ranked[0]
        let second = ranked[1].count
        let totalCount = ctx.variable.count
        let share = Double(top.count) / Double(totalCount)
        let qualifies = top.count >= 3 &&
            share >= 0.12 &&
            (top.count >= 5 || share >= 0.25 || Double(top.count) >= Double(max(2, second)) * 1.5)
        guard qualifies else { return [] }

        var result: [RecapInsight] = [makeMerchantCandidate(top, secondCount: second, share: share)]
        if let runner = ranked[safe: 1],
           runner.count >= 3,
           Double(runner.count) / Double(totalCount) >= 0.12,
           Double(runner.count) >= 0.6 * Double(top.count) {
            let runnerSecond = ranked[safe: 2]?.count ?? 0
            result.append(makeMerchantCandidate(runner, secondCount: runnerSecond, share: Double(runner.count) / Double(totalCount)))
        }
        return result
    }

    private static func makeMerchantCandidate(_ stat: MerchantStat, secondCount: Int, share: Double) -> RecapInsight {
        RecapInsight(
            id: RecapInsightKind.repeatedMerchant.rawValue + ":" + stat.key,
            family: .merchant,
            kind: .repeatedMerchant,
            headlineEn: "\(stat.name)\ncalled you back again and again.",
            headlineHe: "חזרת ל\(stat.name)\nשוב ושוב.",
            valueEn: "\(stat.count) visits",
            valueHe: "\(stat.count) ביקורים",
            supportEn: money(stat.total) + " built up · " + pct(share) + " of purchases",
            supportHe: money(stat.total) + " הצטברו · " + pct(share) + " מהרכישות",
            merchant: stat.name,
            category: stat.category,
            count: stat.count,
            totalAmount: stat.total,
            shareOfTotal: share,
            basis: [
                .init(id: "visits", label: "visits", value: "\(stat.count)"),
                .init(id: "total", label: "combined total", value: money(stat.total)),
                .init(id: "share", label: "share of purchases", value: pct(share)),
                .init(id: "runner_up", label: "runner-up visits", value: "\(secondCount)"),
            ],
            strength: min(0.95, 0.30 + Double(stat.count) * 0.08 + share * 0.3),
            evidence: RecapInsightEvidence(
                transactionIDs: stat.transactionIDs,
                merchantKey: stat.key,
                categoryKey: stat.category
            )
        )
    }

    // MARK: - 3. Repetition / habit (repetition)

    // Conservative keyword lists. Wordy on purpose: a false "delivery" story is worse
    // than missing one. These are the only place keyword magic numbers live.
    private static let deliveryKeywords = ["wolt", "bolt food", "ten bis", "tien bis", "תן ביס", "delivery", "משלוח"]
    private static let coffeeKeywords = ["קפה", "ארומה", "קופיקס", "coffee", "arom", "cophix", "starbucks"]

    private static func matchesAny(_ keywords: [String], in text: String) -> Bool {
        let search = text.lowercased()
        return keywords.contains { search.contains($0) }
    }

    private static func habit(_ name: String, keywords: [String], kind: RecapInsightKind,
                              family: RecapInsightFamily, ctx: MonthContext) -> RecapInsight? {
        let matches = ctx.variable.filter {
            matchesAny(keywords, in: $0.merchant + " " + ($0.note ?? ""))
        }
        guard matches.count >= 6 else { return nil }
        let days = Set(matches.map { ctx.calendar.startOfDay(for: $0.timestamp) })
        let share = Double(matches.count) / Double(ctx.variable.count)
        let total = matches.reduce(0) { $0 + $1.amount }
        guard days.count >= 4, share >= 0.18 else { return nil }

        return RecapInsight(
            id: kind.rawValue,
            family: family,
            kind: kind,
            headlineEn: name + " became a fixture of the month.",
            headlineHe: name + " הפך לחלק קבוע מהחודש.",
            valueEn: "\(matches.count) orders · \(days.count) different days",
            valueHe: "\(matches.count) הזמנות · \(days.count) ימים שונים",
            supportEn: money(total) + " in total",
            supportHe: money(total) + " ביחד",
            count: matches.count,
            totalAmount: total,
            shareOfTotal: share,
            basis: [
                .init(id: "count", label: "orders/visits", value: "\(matches.count)"),
                .init(id: "active_days", label: "different days", value: "\(days.count)"),
                .init(id: "total", label: "combined total", value: money(total)),
                .init(id: "share", label: "share of purchases", value: pct(share)),
            ],
            strength: min(0.95, 0.30 + Double(matches.count) * 0.04 + Double(days.count) * 0.03),
            evidence: RecapInsightEvidence(
                transactionIDs: Set(matches.map { $0.id }),
                categoryKey: .food,
                entityKey: kind.rawValue
            )
        )
    }

    private static func repeatedCategory(_ ctx: MonthContext) -> RecapInsight? {
        // The overall leading category already has its own card; do not double-sell it.
        let topCategory = categoryTotals(ctx.spend).max {
            $0.value == $1.value ? $0.key.rawValue > $1.key.rawValue : $0.value < $1.value
        }?.key

        var categoryRuns: [(category: SpendingCategory, count: Int, days: Int, total: Double)] = []
        let groups = Dictionary(grouping: ctx.variable) { $0.category.canonical }
        for (category, txs) in groups {
            guard category != topCategory, category != .housing, category != .subscriptions else { continue }
            let days = Set(txs.map { ctx.calendar.startOfDay(for: $0.timestamp) })
            let total = txs.reduce(0) { $0 + $1.amount }
            categoryRuns.append((category, txs.count, days.count, total))
        }
        let best = categoryRuns.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            if $0.days != $1.days { return $0.days > $1.days }
            return $0.category.rawValue < $1.category.rawValue
        }.first
        guard let run = best,
              run.count >= 8,
              run.days >= 5,
              Double(run.count) / Double(ctx.variable.count) >= 0.20 else { return nil }
        let runTxs = groups[run.category] ?? []
        let name = run.category.shortNameEn
        let nameHe = run.category.shortName(for: .hebrew)

        return RecapInsight(
            id: RecapInsightKind.repeatedCategory.rawValue + ":" + run.category.rawValue,
            family: .repetition,
            kind: .repeatedCategory,
            headlineEn: "\(name) showed up \(run.count) times.",
            headlineHe: "\(nameHe) הופיע \(run.count) פעמים.",
            valueEn: "\(run.days) different days",
            valueHe: "\(run.days) ימים שונים",
            supportEn: money(run.total) + " across the month",
            supportHe: money(run.total) + " על פני החודש",
            category: run.category,
            count: run.count,
            totalAmount: run.total,
            basis: [
                .init(id: "count", label: "purchases", value: "\(run.count)"),
                .init(id: "active_days", label: "different days", value: "\(run.days)"),
                .init(id: "total", label: "combined total", value: money(run.total)),
            ],
            strength: min(0.95, 0.35 + Double(run.count) * 0.03 + Double(run.days) * 0.02),
            evidence: RecapInsightEvidence(
                transactionIDs: Set(runTxs.map { $0.id }),
                categoryKey: run.category
            )
        )
    }

    private static func repetitionCandidates(_ ctx: MonthContext) -> [RecapInsight] {
        var options: [RecapInsight] = []
        if let delivery = habit("Delivery", keywords: deliveryKeywords, kind: .deliveryHabit, family: .repetition, ctx: ctx) {
            options.append(delivery)
        }
        if let coffee = habit("Coffee", keywords: coffeeKeywords, kind: .coffeeHabit, family: .repetition, ctx: ctx) {
            options.append(coffee)
        }
        if let category = repeatedCategory(ctx) { options.append(category) }
        return options.sorted {
            $0.strength == $1.strength ? $0.id < $1.id : $0.strength > $1.strength
        }.prefix(2).map { $0 }
    }

    // MARK: - 4. Busiest Day (timing)

    private static func busiestDay(_ ctx: MonthContext) -> RecapInsight? {
        guard ctx.activeSpendDays >= 4, ctx.variable.count >= 6 else { return nil }
        let byDay = Dictionary(grouping: ctx.variable) { ctx.calendar.startOfDay(for: $0.timestamp) }
        let average = Double(ctx.variable.count) / Double(ctx.activeSpendDays)
        let ranked = byDay.map { (day, txsOnDay) -> (date: Date, count: Int, total: Double, categories: Int) in
            let categories = Set(txsOnDay.map { $0.category.canonical }).count
            return (day, txsOnDay.count, txsOnDay.reduce(0) { $0 + $1.amount }, categories)
        }.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.date < $1.date
        }
        guard let top = ranked.first,
              top.count >= 3,
              Double(top.count) >= 1.5 * average,
              top.categories >= 2,
              let topTxs = byDay[top.date] else { return nil }
        let f = DateFormatter()
        f.calendar = ctx.calendar
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMM d"

        return RecapInsight(
            id: RecapInsightKind.busiestDay.rawValue + ":" + isoDay(top.date),
            family: .timing,
            kind: .busiestDay,
            headlineEn: "\(top.count) purchases happened on the \(f.string(from: top.date)).",
            headlineHe: "ב\(isoDay(top.date)) בוצעו \(top.count) רכישות.",
            valueEn: "\(top.categories) categories that day · " + money(top.total),
            valueHe: "\(top.categories) קטגוריות באותו יום · " + money(top.total),
            date: top.date,
            count: top.count,
            totalAmount: top.total,
            basis: [
                .init(id: "count", label: "purchases that day", value: "\(top.count)"),
                .init(id: "average", label: "typical daily purchases", value: String(format: "%.1f", average)),
                .init(id: "categories", label: "categories that day", value: "\(top.categories)"),
                .init(id: "day_total", label: "that day's spend", value: money(top.total)),
            ],
            strength: min(0.95, 0.35 + Double(top.count) * 0.06 + Double(top.categories) * 0.04),
            evidence: RecapInsightEvidence(
                transactionIDs: Set(topTxs.map { $0.id }),
                entityKey: "day:" + isoDay(top.date)
            )
        )
    }

    // MARK: - 5. No-Spend Streak (streak)

    private static func noSpendStreak(_ ctx: MonthContext) -> RecapInsight? {
        let days = ctx.spendDays
        guard days.count >= 5, ctx.spend.count >= 5 else { return nil }
        guard let first = days.first, let last = days.last else { return nil }
        let span = ctx.calendar.dateComponents([.day], from: first, to: last).day ?? 0
        let spanDays = span + 1
        guard spanDays >= 8 else { return nil }

        var currentRun = 0
        var bestRun = 0
        if spanDays > 0 {
            for offset in 0...span {
                let day = ctx.calendar.date(byAdding: .day, value: offset, to: first)!
                if days.contains(where: { ctx.calendar.isDate($0, inSameDayAs: day) }) {
                    currentRun = 0
                } else {
                    currentRun += 1
                    bestRun = max(bestRun, currentRun)
                }
            }
        }
        guard bestRun >= 3 else { return nil }
        let share = Double(bestRun) / Double(spanDays)

        return RecapInsight(
            id: RecapInsightKind.noSpendStreak.rawValue,
            family: .streak,
            kind: .noSpendStreak,
            headlineEn: "The city fell quiet.",
            headlineHe: "העיר הייתה שקטה.",
            valueEn: "\(bestRun) days in a row without spending",
            valueHe: "\(bestRun) ימים ברצף בלי הוצאה",
            supportEn: "out of \(spanDays) active days tracked",
            supportHe: "מתוך \(spanDays) ימים שנמדדו",
            count: bestRun,
            shareOfTotal: share,
            basis: [
                .init(id: "run", label: "consecutive quiet days", value: "\(bestRun)"),
                .init(id: "span", label: "first→last spend day", value: "\(spanDays)"),
                .init(id: "purchases", label: "total purchases", value: "\(ctx.spend.count)"),
            ],
            strength: min(0.95, 0.30 + Double(bestRun) * 0.10 + share * 0.4),
            evidence: RecapInsightEvidence(transactionIDs: Set(ctx.spend.map { $0.id }))
        )
    }

    // MARK: - 6. First Half vs Second Half (comparison)

    private static func firstHalfVsSecondHalf(_ ctx: MonthContext) -> RecapInsight? {
        let txs = ctx.variable
        guard txs.count >= 8 else { return nil }
        let firstThreshold = 15
        let firstDays = min(firstThreshold, ctx.monthLength)
        let secondDays = ctx.monthLength - firstDays
        guard secondDays > 0 else { return nil }

        let first = txs.filter { ctx.calendar.component(.day, from: $0.timestamp) <= firstThreshold }
        let second = txs.filter { ctx.calendar.component(.day, from: $0.timestamp) > firstThreshold }
        let firstTotal = first.reduce(0) { $0 + $1.amount }
        let secondTotal = second.reduce(0) { $0 + $1.amount }
        guard firstTotal > 0, secondTotal > 0 else { return nil }
        let firstAvg = firstTotal / Double(firstDays)
        let secondAvg = secondTotal / Double(secondDays)
        let diff = (secondAvg - firstAvg) / firstAvg
        guard abs(diff) >= 0.25 else { return nil }

        let secondHeavier = diff > 0
        return RecapInsight(
            id: RecapInsightKind.firstHalfVsSecondHalf.rawValue,
            family: .comparison,
            kind: .firstHalfVsSecondHalf,
            headlineEn: secondHeavier ? "The month built up toward the end." : "The month front-loaded its spending.",
            headlineHe: secondHeavier ? "החודש התגבר לקראת הסוף." : "החודש הוציא את עיקר הכסף בהתחלה.",
            valueEn: pct(abs(diff)) + " per-day difference",
            valueHe: pct(abs(diff)) + " הפרש בהוצאה היומית",
            supportEn: secondHeavier ? "second half averaged " + money(secondAvg) + " / day" : "first half averaged " + money(firstAvg) + " / day",
            supportHe: secondHeavier ? "החצי השני בממוצע " + money(secondAvg) + " ליום" : "החצי הראשון בממוצע " + money(firstAvg) + " ליום",
            count: ctx.spendDays.count,
            direction: diff,
            basis: [
                .init(id: "first_avg", label: "first half daily avg", value: money(firstAvg)),
                .init(id: "second_avg", label: "second half daily avg", value: money(secondAvg)),
                .init(id: "diff", label: "per-day difference", value: pct(abs(diff))),
            ],
            strength: min(0.95, 0.35 + abs(diff) * 0.6),
            evidence: RecapInsightEvidence(transactionIDs: Set(txs.map { $0.id }))
        )
    }

    // MARK: - 7. Day of Week Pattern (timing)

    private static func dayOfWeekPattern(_ ctx: MonthContext) -> RecapInsight? {
        let txs = ctx.variable
        guard txs.count >= 8 else { return nil }

        struct WeekdayStat {
            let weekday: Int
            let count: Int
            let weeksSeen: Int
            let total: Double
            let averagePerWeek: Double
        }

        var byWeekday: [Int: [Transaction]] = [:]
        for tx in txs {
            byWeekday[ctx.calendar.component(.weekday, from: tx.timestamp), default: []].append(tx)
        }

        var stats: [WeekdayStat] = []
        for (weekday, group) in byWeekday {
            let weeks = Set(group.map { ctx.calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: $0.timestamp) })
            let total = group.reduce(0) { $0 + $1.amount }
            stats.append(WeekdayStat(weekday: weekday, count: group.count, weeksSeen: weeks.count, total: total, averagePerWeek: total / Double(max(1, weeks.count))))
        }
        let eligible = stats.filter { $0.count >= 3 && $0.weeksSeen >= 2 }
        guard eligible.count >= 2 else { return nil }
        let top = eligible.sorted {
            if $0.averagePerWeek != $1.averagePerWeek { return $0.averagePerWeek > $1.averagePerWeek }
            return $0.weekday < $1.weekday
        }.first!
        let others = eligible.filter { $0.weekday != top.weekday }.map { $0.averagePerWeek }.sorted()
        guard !others.isEmpty else { return nil }
        let medianOther = others.count.isMultiple(of: 2)
            ? (others[others.count / 2 - 1] + others[others.count / 2]) / 2
            : others[others.count / 2]
        guard medianOther > 0 else { return nil }
        let ratio = top.averagePerWeek / medianOther
        guard ratio >= 1.5 else { return nil }

        let dayName = weekdayName(top.weekday, in: ctx, locale: "en_US")
        let dayNameHe = weekdayName(top.weekday, in: ctx, locale: "he_IL")
        let topTxs = byWeekday[top.weekday] ?? []

        return RecapInsight(
            id: RecapInsightKind.dayOfWeekPattern.rawValue + ":" + String(top.weekday),
            family: .timing,
            kind: .dayOfWeekPattern,
            headlineEn: "\(dayName)s stood apart this month.",
            headlineHe: "ימי \(dayNameHe) בלטו החודש.",
            valueEn: String(format: "%.1f", ratio) + "x your typical such day",
            valueHe: String(format: "%.1f", ratio) + " פי מיום אופייני",
            supportEn: money(top.averagePerWeek) + " on those days across " + String(top.weeksSeen) + " weeks",
            supportHe: money(top.averagePerWeek) + " בימים האלה לאורך " + String(top.weeksSeen) + " שבועות",
            count: top.count,
            totalAmount: top.total,
            ratio: ratio,
            basis: [
                .init(id: "weekday", label: "peak day of week", value: dayName),
                .init(id: "average_per_week", label: "avg spend on that day", value: money(top.averagePerWeek)),
                .init(id: "median_other", label: "typical other weekday", value: money(medianOther)),
                .init(id: "ratio", label: "ratio", value: String(format: "%.2f", ratio)),
                .init(id: "weeks_seen", label: "weeks observed", value: "\(top.weeksSeen)"),
            ],
            strength: min(0.95, 0.35 + (ratio - 1.0) * 0.45 + Double(top.weeksSeen) * 0.04),
            evidence: RecapInsightEvidence(
                transactionIDs: Set(topTxs.map { $0.id }),
                entityKey: "dayOfWeek:" + String(top.weekday)
            )
        )
    }

    // MARK: - 8. Spending Concentration (concentration)

    private static func spendingConcentration(_ ctx: MonthContext) -> RecapInsight? {
        let txs = ctx.variable
        guard txs.count >= 10, ctx.variableTotal > 0 else { return nil }
        let sorted = txs.sorted {
            if $0.amount != $1.amount { return $0.amount > $1.amount }
            if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
            return $0.merchant + $0.category.rawValue < $1.merchant + $1.category.rawValue
        }
        let maxTop = max(2, Int(Double(txs.count) * 0.30))
        var total = 0.0
        var k = 0
        var shareAtK = 0.0
        for (index, tx) in sorted.enumerated() {
            total += tx.amount
            if total >= 0.40 * ctx.variableTotal {
                k = index + 1
                shareAtK = total / ctx.variableTotal
                break
            }
        }
        guard k >= 2, k <= maxTop, shareAtK > 0 else { return nil }
        let topK = Array(sorted.prefix(k))

        return RecapInsight(
            id: RecapInsightKind.spendingConcentration.rawValue,
            family: .concentration,
            kind: .spendingConcentration,
            headlineEn: "A handful of purchases carried the month.",
            headlineHe: "קומץ רכישות נשא את החודש.",
            valueEn: "\(k) purchases · " + pct(shareAtK) + " of the month",
            valueHe: "\(k) רכישות · " + pct(shareAtK) + " מהחודש",
            supportEn: money(total) + " among " + String(txs.count) + " purchases",
            supportHe: money(total) + " מתוך " + String(txs.count) + " רכישות",
            count: k,
            totalAmount: total,
            shareOfTotal: shareAtK,
            basis: [
                .init(id: "k", label: "smallest top-k", value: "\(k)"),
                .init(id: "share", label: "share carried", value: pct(shareAtK)),
                .init(id: "sum", label: "their combined spend", value: money(total)),
                .init(id: "total_purchases", label: "total purchases", value: "\(txs.count)"),
            ],
            strength: min(0.95, 0.30 + (Double(k) * 0.03) + shareAtK * 0.7),
            evidence: RecapInsightEvidence(transactionIDs: Set(topK.map { $0.id }))
        )
    }

    // MARK: - 9. Merchant Diversity (diversity)

    private static func merchantDiversity(_ ctx: MonthContext) -> RecapInsight? {
        let txs = ctx.variable
        guard txs.count >= 12 else { return nil }
        let merchants = merchantStats(ctx.variable)
        guard merchants.count >= 7 else { return nil }
        let categories = Set(txs.map { $0.category.canonical })
        let share = Double(merchants.count) / Double(txs.count)
        guard share >= 0.5, categories.count >= 3 else { return nil }

        return RecapInsight(
            id: RecapInsightKind.merchantDiversity.rawValue,
            family: .diversity,
            kind: .merchantDiversity,
            headlineEn: "This month toured a lot of places.",
            headlineHe: "החודש הסתובב בהרבה מקומות.",
            valueEn: "\(merchants.count) different places · \(txs.count) purchases",
            valueHe: "\(merchants.count) מקומות שונים · \(txs.count) רכישות",
            supportEn: "across \(categories.count) categories",
            supportHe: "בין \(categories.count) קטגוריות",
            count: merchants.count,
            shareOfTotal: share,
            basis: [
                .init(id: "places", label: "distinct places", value: "\(merchants.count)"),
                .init(id: "purchases", label: "total purchases", value: "\(txs.count)"),
                .init(id: "share", label: "places per purchase", value: pct(share)),
                .init(id: "categories", label: "distinct categories", value: "\(categories.count)"),
            ],
            strength: min(0.95, 0.35 + Double(merchants.count) * 0.02 + share * 0.3),
            evidence: RecapInsightEvidence(transactionIDs: Set(txs.map { $0.id }))
        )
    }

    // MARK: - 10. Category Change (category)

    private static func categoryTotals(_ txs: [Transaction]) -> [SpendingCategory: Double] {
        var totals: [SpendingCategory: Double] = [:]
        for tx in txs {
            let cat = tx.category.canonical
            totals[cat, default: 0] += tx.amount
        }
        return totals
    }

    private static func spend(in interval: DateInterval, calendar: Calendar, from all: [Transaction]) -> [Transaction] {
        all.filter {
            $0.timestamp >= interval.start && $0.timestamp < interval.end &&
            $0.amount.isFinite && $0.amount > 0 && $0.category.canonical != .savings
        }
    }

    private static func categoryChanges(_ ctx: MonthContext) -> [RecapInsight] {
        // Only tell change stories for a month that is actually over — the current month
        // is still in progress and any comparison would be misleading.
        guard ctx.interval.end <= ctx.now,
              let previousDate = ctx.calendar.date(byAdding: .month, value: -1, to: ctx.interval.start),
              let previousInterval = ctx.calendar.dateInterval(of: .month, for: previousDate) else { return [] }

        let previous = spend(in: previousInterval, calendar: ctx.calendar, from: ctx.allTransactions)
        let previousTotal = previous.reduce(0) { $0 + $1.amount }
        guard previousTotal > 0 else { return [] }

        let current = categoryTotals(ctx.spend)
        let past = categoryTotals(previous)
        let currentByCategory = Dictionary(grouping: ctx.spend) { $0.category.canonical }
        // The leading category is already the "biggest district" story; never double-sell it.
        let leading = current.max { $0.value == $1.value ? $0.key.rawValue > $1.key.rawValue : $0.value < $1.value }?.key

        var changes: [(category: SpendingCategory, direction: Double, previous: Double, current: Double, txs: [Transaction])] = []
        for (category, old) in past {
            guard category != leading, old >= max(50, previousTotal * 0.02) else { continue }
            let now = current[category] ?? 0
            let pctChange = (now - old) / old * 100
            guard abs(pctChange) >= 40, abs(now - old) >= max(50, ctx.total * 0.05) else { continue }
            changes.append((category, pctChange, old, now, currentByCategory[category] ?? []))
        }

        let ranked = changes.sorted {
            if abs($0.direction) != abs($1.direction) { return abs($0.direction) > abs($1.direction) }
            return $0.category.rawValue < $1.category.rawValue
        }

        var result: [RecapInsight] = []
        if let top = ranked.first {
            result.append(makeCategoryChange(top))
            // A quiet counter-story (spend up in one category, down in another) is a good
            // second candidate and keeps the pool varied.
            if let counter = ranked.dropFirst().first(where: { ($0.direction < 0) != (top.direction < 0) }) {
                result.append(makeCategoryChange(counter))
            }
        }
        return result
    }

    private static func makeCategoryChange(_ change: (category: SpendingCategory, direction: Double, previous: Double, current: Double, txs: [Transaction])) -> RecapInsight {
        let up = change.direction > 0
        let magnitude = Int(abs(change.direction).rounded())
        let name = change.category.shortNameEn
        let nameHe = change.category.shortName(for: .hebrew)
        let directionWord = up ? "more" : "less"
        let directionWordHe = up ? "יותר" : "פחות"

        return RecapInsight(
            id: "categoryChange:" + change.category.rawValue + ":" + (up ? "up" : "down"),
            family: .category,
            kind: .categoryChange,
            headlineEn: "\(name) took up \(magnitude)% \(directionWord) space.",
            headlineHe: "\(nameHe) תפס \(magnitude)% \(directionWordHe) מקום.",
            valueEn: (up ? "+" : "−") + String(magnitude) + "%",
            valueHe: (up ? "+" : "−") + String(magnitude) + "%",
            supportEn: money(change.current) + " now vs " + money(change.previous) + " last month",
            supportHe: money(change.current) + " עכשיו לעומת " + money(change.previous) + " בחודש הקודם",
            category: change.category,
            totalAmount: change.current,
            direction: change.direction,
            basis: [
                .init(id: "change", label: "percent change", value: (up ? "+" : "−") + String(magnitude) + "%"),
                .init(id: "previous", label: "last month", value: money(change.previous)),
                .init(id: "current", label: "this month", value: money(change.current)),
            ],
            strength: min(0.95, 0.30 + (abs(change.direction) / 100) * 0.8),
            evidence: RecapInsightEvidence(
                transactionIDs: Set(change.txs.map { $0.id }),
                categoryKey: change.category
            )
        )
    }

    // MARK: - 11. Big vs Frequent (merchant)

    private static func bigVsFrequent(_ ctx: MonthContext) -> RecapInsight? {
        let stats = merchantStats(ctx.variable)
        guard stats.count >= 2 else { return nil }
        let mostVisited = stats[0]
        let biggestTotal = stats.sorted {
            if $0.total != $1.total { return $0.total > $1.total }
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.name < $1.name
        }.first!
        guard mostVisited.key != biggestTotal.key,
              mostVisited.count >= 3,
              biggestTotal.total >= 1.5 * mostVisited.total,
              biggestTotal.total >= max(80, 0.08 * ctx.variableTotal) else { return nil }

        return RecapInsight(
            id: RecapInsightKind.bigVsFrequent.rawValue,
            family: .merchant,
            kind: .bigVsFrequent,
            headlineEn: "The places you return to aren't the places that cost the most.",
            headlineHe: "המקומות שחוזרים אליהם\nלא המקומות שמוציאים עליהם הכי הרבה.",
            valueEn: mostVisited.name + " ×\(mostVisited.count)   vs   " + biggestTotal.name,
            valueHe: mostVisited.name + " ×\(mostVisited.count)   לעומת   " + biggestTotal.name,
            supportEn: "\(biggestTotal.name): " + money(biggestTotal.total),
            supportHe: "\(biggestTotal.name): " + money(biggestTotal.total),
            merchant: mostVisited.name,
            totalAmount: biggestTotal.total,
            ratio: biggestTotal.total / mostVisited.total,
            basis: [
                .init(id: "most_visited", label: "most visited", value: "\(mostVisited.name) ×\(mostVisited.count)"),
                .init(id: "biggest_spend", label: "biggest spend", value: "\(biggestTotal.name) " + money(biggestTotal.total)),
                .init(id: "ratio", label: "spend ratio", value: String(format: "%.1f", biggestTotal.total / mostVisited.total)),
            ],
            strength: min(0.95, 0.40 + (biggestTotal.total / max(1, mostVisited.total) - 1.5) * 0.15),
            evidence: RecapInsightEvidence(
                transactionIDs: mostVisited.transactionIDs.union(biggestTotal.transactionIDs),
                merchantKey: mostVisited.key,
                categoryKey: mostVisited.category
            )
        )
    }

    // MARK: - 12. Outlier Purchase (outlier)

    private static func outlierPurchase(_ ctx: MonthContext) -> RecapInsight? {
        guard ctx.variable.count >= 5 else { return nil }
        struct Outlier {
            let transaction: Transaction
            let category: SpendingCategory
            let typical: Double
            let ratio: Double
            let othersCount: Int
        }
        var best: Outlier?
        let grouped = Dictionary(grouping: ctx.variable) { $0.category.canonical }
        for (category, txs) in grouped {
            guard txs.count >= 4 else { continue }
            let sorted = txs.sorted { $0.amount < $1.amount }
            guard let max = sorted.last else { continue }
            let others = sorted.dropLast()
            let otherMedian = others.count.isMultiple(of: 2)
                ? (others[others.count / 2 - 1].amount + others[others.count / 2].amount) / 2
                : others[others.count / 2].amount
            guard otherMedian >= 10, max.amount >= 80 else { continue }
            let ratio = max.amount / otherMedian
            guard ratio >= 3.0 else { continue }
            let candidate = Outlier(transaction: max, category: category, typical: otherMedian, ratio: ratio, othersCount: others.count)
            if best == nil
                || candidate.ratio > best!.ratio
                || (candidate.ratio == best!.ratio && candidate.category.rawValue < best!.category.rawValue) {
                best = candidate
            }
        }
        guard let hit = best else { return nil }
        let merchant = hit.transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let merchantKey = merchant.isEmpty ? nil : MerchantRuleService.normalizedKey(merchant)

        return RecapInsight(
            id: RecapInsightKind.outlierPurchase.rawValue + ":" + hit.category.rawValue,
            family: .outlier,
            kind: .outlierPurchase,
            headlineEn: "One purchase broke the pattern.",
            headlineHe: "רכישה אחת שברה את התבנית.",
            valueEn: money(hit.transaction.amount),
            valueHe: money(hit.transaction.amount),
            supportEn: "typical " + hit.category.shortNameEn.lowercased() + " ≈ " + money(hit.typical) + " · " + String(format: "%.1f", hit.ratio) + "x",
            supportHe: "ארוחות טיפוסיות ≈ " + money(hit.typical) + " · פי " + String(format: "%.1f", hit.ratio),
            merchant: merchant.isEmpty ? nil : merchant,
            category: hit.category,
            date: hit.transaction.timestamp,
            totalAmount: hit.transaction.amount,
            ratio: hit.ratio,
            basis: [
                .init(id: "merchant", label: "merchant", value: merchant.isEmpty ? hit.category.rawValue : merchant),
                .init(id: "amount", label: "the outlier", value: money(hit.transaction.amount)),
                .init(id: "typical", label: "typical purchase", value: money(hit.typical)),
                .init(id: "ratio", label: "ratio", value: String(format: "%.1f", hit.ratio)),
                .init(id: "sample", label: "comparable purchases", value: "\(hit.othersCount)"),
            ],
            strength: min(0.95, 0.35 + hit.ratio * 0.10),
            evidence: RecapInsightEvidence(
                transactionIDs: [hit.transaction.id],
                merchantKey: merchantKey,
                categoryKey: hit.category
            )
        )
    }

    // MARK: - Shared formatting helpers

    private static func money(_ value: Double) -> String {
        "₪" + String(Int((value).rounded()))
    }

    private static func pct(_ fraction: Double) -> String {
        String(format: "%.0f%%", fraction * 100)
    }

    private static func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func weekdayName(_ weekday: Int, in ctx: MonthContext, locale: String) -> String {
        var probe = ctx.interval.start
        while ctx.calendar.component(.weekday, from: probe) != weekday {
            guard let next = ctx.calendar.date(byAdding: .day, value: 1, to: probe) else { break }
            probe = next
        }
        let f = DateFormatter()
        f.calendar = ctx.calendar
        f.locale = Locale(identifier: locale)
        f.dateFormat = "EEEE"
        return f.string(from: probe)
    }

    private static func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    /// Curator/debug access to the same month title.
    static func debugMonthTitle(_ date: Date) -> String {
        monthTitle(date)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}