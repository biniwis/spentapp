import Foundation

// MARK: - Recap 2.0 · Phase 5 · RecapInsightCurator
//
// Turns the candidate pool into the recap story. Pure data, like the engine: no views,
// no animation, no randomness. Phase 6 maps the result onto the existing shot sequence.
//
// The curator curates the *complete story*, not candidates in isolation:
// - Hero #1: the single strongest meaningful truth.
// - Noticed: 2–4 good observations with topic/semantic diversity (never more than one
//   per family, rows in one shot).
// - Hero #2: a strong insight from a family the rest of the story did not use.
// - MicroFact: the strongest unused good insight (small line on the final portrait).
//
// The fixed backbone content (Biggest Story District, Biggest Meaningful Moment)
// participates in the same overlap pass as the candidates: a discovery story that
// duplicates a backbone story is vetoed, one that shares evidence but means something
// different is only penalized. Slots are never filled with weak material — a shorter
// recap beats a padded one.

/// A fixed story the recap always tells. The curator treats it as already selected:
/// a discovery candidate duplicating it is vetoed; one that overlaps but means
/// something different is penalized.
struct RecapBackboneInsight: Identifiable, Sendable, Equatable {
    let id: String
    let profile: RecapInsightEngine.RecapStoryProfile

    init(id: String,
         isCategoryDominance: Bool,
         merchantKey: String? = nil,
         entityKey: String? = nil,
         categoryKey: SpendingCategory? = nil,
         transactionIDs: Set<UUID>) {
        self.id = id
        self.profile = RecapInsightEngine.RecapStoryProfile(
            id: id,
            kind: nil,
            isBackbone: true,
            isSingleSubject: true,
            isMerchantBound: false,
            isCategoryDominance: isCategoryDominance,
            merchantKey: merchantKey,
            entityKey: entityKey,
            categoryKey: categoryKey,
            transactionIDs: transactionIDs
        )
    }
}

/// The curated recap content. Phase 6 maps this onto the existing shot model.
struct RecapCuratedStory: Sendable, Equatable {
    let hero1: RecapInsight?
    let noticed: [RecapInsight]
    let hero2: RecapInsight?
    let microFact: RecapInsight?

    init(hero1: RecapInsight? = nil, noticed: [RecapInsight] = [], hero2: RecapInsight? = nil, microFact: RecapInsight? = nil) {
        self.hero1 = hero1
        self.noticed = noticed
        self.hero2 = hero2
        self.microFact = microFact
    }

    /// Everything that earned a slot, in selection order.
    var selectedInsights: [RecapInsight] {
        var out: [RecapInsight] = []
        if let hero1 { out.append(hero1) }
        out += noticed
        if let hero2 { out.append(hero2) }
        if let microFact { out.append(microFact) }
        return out
    }
}

/// Why a candidate did not reach the recap. Deterministic and data-driven; used by the
/// DEBUG Design Lab (Phase 10) and the Phase 5 review.
struct RecapCuratedRejection: Sendable, Equatable {
    let insightID: String
    let reason: String
}

enum RecapInsightCurator {

    /// A story must clear these bars to deserve a slot. Deliberately conservative:
    /// "never fill a slot with a weak insight" trumps filling every slot.
    static let heroThreshold: Double = 0.50
    static let noticedThreshold: Double = 0.35
    static let microFactThreshold: Double = 0.30
    static let maxNoticedRows = 4
    static let minNoticedRows = 2

    // MARK: Public API

    /// Full Phase 5 pipeline: generate candidates, compute the fixed backbone slots,
    /// run the shared overlap pass, then select the story slots.
    static func curate(
        for month: Date,
        allTransactions: [Transaction],
        now: Date = Date(),
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> RecapCuratedStory {
        let candidates = RecapInsightEngine.generateCandidates(
            for: month, allTransactions: allTransactions, now: now, calendar: calendar
        )
        let slots = backbone(for: month, allTransactions: allTransactions, now: now, calendar: calendar)
        return curate(candidates: candidates, backbone: slots).story
    }

    /// Curates an arbitrary candidate pool against an arbitrary backbone. Testable and
    /// the integration seam Phase 6 uses.
    static func curate(
        candidates: [RecapInsight],
        backbone: [RecapBackboneInsight]
    ) -> (story: RecapCuratedStory, rejections: [RecapCuratedRejection]) {
        var rejections: [RecapCuratedRejection] = []

        // 1. Backbone overlap pass: same story → veto, strong overlap → hard dock,
        //    adjacent (same category, different story/granularity) → mild dock or none.
        var pool: [RecapInsight] = []
        for candidate in candidates {
            let profile = RecapInsightEngine.storyProfile(candidate)
            var weakestFactor = 1.0
            var blockedBy: String?
            for slot in backbone {
                switch RecapInsightEngine.overlapRelation(profile, slot.profile) {
                case .sameStory:
                    blockedBy = slot.id
                case .strongOverlap(let fraction):
                    weakestFactor = min(weakestFactor, 1 - RecapInsightEngine.recapOverlapPenaltyWeight * fraction)
                case .adjacent(let fraction):
                    weakestFactor = min(weakestFactor, 1 - RecapInsightEngine.recapOverlapAdjacentWeight * fraction)
                case .none:
                    break
                }
            }
            if let slotID = blockedBy {
                rejections.append(.init(insightID: candidate.id, reason: "duplicates backbone \(slotID)"))
                continue
            }
            var accepted = candidate
            if weakestFactor < 1 {
                accepted.scores.total = min(1, max(0, accepted.scores.total * weakestFactor))
            }
            pool.append(accepted)
        }

        // 2. Selection in score order, family-diverse, nothing weak.
        let ranked = pool.sorted {
            if $0.scores.total != $1.scores.total { return $0.scores.total > $1.scores.total }
            return $0.id < $1.id
        }.map { $0 }

        guard let hero = ranked.first, hero.scores.total >= heroThreshold else {
            for candidate in ranked {
                rejections.append(.init(
                    insightID: candidate.id,
                    reason: String(format: "below hero bar (%.2f < %.2f)", candidate.scores.total, heroThreshold)
                ))
            }
            return (RecapCuratedStory(), rejections)
        }
        let hero1 = hero
        let remaining = ranked.filter { $0.id != hero1.id }
        var usedFamilies: Set<RecapInsightFamily> = [hero1.family]

        // Noticed rows: best remaining, one per family, 2–4 of them or the shot is skipped.
        var noticed: [RecapInsight] = []
        for candidate in remaining {
            guard noticed.count < maxNoticedRows else { break }
            guard candidate.scores.total >= noticedThreshold else {
                rejections.append(.init(insightID: candidate.id, reason: "below noticed bar"))
                break
            }
            guard !usedFamilies.contains(candidate.family) else {
                rejections.append(.init(insightID: candidate.id, reason: "same family as an earlier story"))
                continue
            }
            noticed.append(candidate)
            usedFamilies.insert(candidate.family)
        }
        if noticed.count < minNoticedRows {
            // Too thin to be a credible "things we noticed" shot; let the rows fall back
            // into the hero2 / microFact pools instead of padding the recap.
            for row in noticed {
                rejections.append(.init(insightID: row.id, reason: "noticed shot needs ≥\(minNoticedRows) diverse rows"))
            }
            for candidate in ranked where noticed.contains(where: { $0.id == candidate.id }) {
                usedFamilies.remove(candidate.family)
            }
            noticed = []
        }

        // Hero #2: a strong insight from a family the rest of the story did not use.
        var hero2: RecapInsight?
        for candidate in ranked where candidate.id != hero1.id {
            guard candidate.scores.total >= heroThreshold else { break }
            guard !usedFamilies.contains(candidate.family) else {
                rejections.append(.init(insightID: candidate.id, reason: "hero2 same family as an earlier story"))
                continue
            }
            hero2 = candidate
            usedFamilies.insert(candidate.family)
            break
        }
        if hero2 == nil {
            rejections.append(.init(
                insightID: hero1.id,
                reason: "no hero2 story cleared the bar in an unused family"
            ))
        }

        // MicroFact: the strongest genuinely unused good insight. A micro fact never
        // repeats a story the recap already tells: it may not be the same story as the
        // backbone, the hero, a noticed row, or the second hero.
        var microFact: RecapInsight?
        let chosenIDs = Set(ranked.compactMap { candidate -> String? in
            if candidate.id == hero1.id { return candidate.id }
            if candidate.id == hero2?.id { return candidate.id }
            if noticed.contains(where: { $0.id == candidate.id }) { return candidate.id }
            return nil
        })
        var shownProfiles = backbone.map { $0.profile }
        shownProfiles.append(RecapInsightEngine.storyProfile(hero1))
        if let hero2 { shownProfiles.append(RecapInsightEngine.storyProfile(hero2)) }
        for row in noticed { shownProfiles.append(RecapInsightEngine.storyProfile(row)) }
        for candidate in ranked where !chosenIDs.contains(candidate.id) {
            guard candidate.scores.total >= microFactThreshold else {
                rejections.append(.init(insightID: candidate.id, reason: "below micro-fact bar"))
                break
            }
            let profile = RecapInsightEngine.storyProfile(candidate)
            let duplicatesShown = shownProfiles.contains { shown in
                if case .sameStory = RecapInsightEngine.overlapRelation(profile, shown) { return true }
                return false
            }
            if duplicatesShown {
                rejections.append(.init(insightID: candidate.id, reason: "micro fact duplicates a story already shown"))
                continue
            }
            microFact = candidate
            break
        }

        return (
            RecapCuratedStory(hero1: hero1, noticed: noticed, hero2: hero2, microFact: microFact),
            rejections
        )
    }

    // MARK: - Fixed backbone content (Phase 6 maps these onto the existing shots)

    /// Big Story District is computed for storytelling (variable spend only), exactly the
    /// same way `MonthlyRecapService` separates `biggestDistrict` (accounting truth) from
    /// its storytelling variant. The Moment is the single largest non-recurring purchase.
    static func backbone(
        for month: Date,
        allTransactions: [Transaction],
        now: Date = Date(),
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> [RecapBackboneInsight] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let spend = allTransactions.filter {
            $0.timestamp >= interval.start && $0.timestamp < interval.end &&
            $0.amount.isFinite && $0.amount > 0 && $0.category.canonical != .savings
        }
        let variable = spend.filter { !MonthlyRecapService.isLikelyRecurringOrFixed($0) }
        guard !variable.isEmpty else { return [] }

        var slots: [RecapBackboneInsight] = []

        let byCategory = Dictionary(grouping: variable) { $0.category.canonical }
        let ranked = byCategory.map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }, txs: $0.value) }
            .sorted {
                if $0.total != $1.total { return $0.total > $1.total }
                return $0.category.rawValue < $1.category.rawValue
            }
        if let top = ranked.first {
            slots.append(RecapBackboneInsight(
                id: "biggestStoryDistrict:" + top.category.rawValue,
                isCategoryDominance: true,
                categoryKey: top.category,
                transactionIDs: Set(top.txs.map { $0.id })
            ))
        }

        let tallest = variable.sorted {
            if $0.amount != $1.amount { return $0.amount > $1.amount }
            if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
            return $0.merchant + $0.category.rawValue < $1.merchant + $1.category.rawValue
        }.first
        if let purchase = tallest {
            let name = purchase.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.isEmpty ? nil : MerchantRuleService.normalizedKey(name)
            slots.append(RecapBackboneInsight(
                id: "moment:biggestPurchase",
                isCategoryDominance: false,
                merchantKey: key,
                categoryKey: purchase.category.canonical,
                transactionIDs: [purchase.id]
            ))
        }
        return slots
    }

    // MARK: - Debug

    /// Deterministic multi-line dump of the curated story: selected slots with scores,
    /// families used, backbone computed, and every rejection reason.
    static func debugCuratorReport(
        for month: Date,
        allTransactions: [Transaction],
        now: Date = Date()
    ) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let candidates = RecapInsightEngine.generateCandidates(
            for: month, allTransactions: allTransactions, now: now, calendar: calendar
        )
        let slots = backbone(for: month, allTransactions: allTransactions, now: now, calendar: calendar)
        let result = curate(candidates: candidates, backbone: slots)

        var lines: [String] = []
        lines.append("=== \(RecapInsightEngine.debugMonthTitle(month)) · curated ===")
        lines.append("backbone:")
        for slot in slots {
            lines.append("  [\(slot.id)] category=\(slot.profile.categoryKey?.rawValue ?? "—") txs=\(slot.profile.transactionIDs.count)")
        }
        if result.story.selectedInsights.isEmpty {
            lines.append("(no story — nothing cleared the bars)")
            for rejection in result.rejections {
                lines.append("  skipped: \(rejection.insightID) — \(rejection.reason)")
            }
            return lines.joined(separator: "\n")
        }
        let sorted = result.story.selectedInsights.sorted {
            $0.scoreOrder() == $1.scoreOrder() ? $0.id < $1.id : $0.scoreOrder() < $1.scoreOrder()
        }
        for insight in sorted {
            let role = result.story.roleOf(insight.id)
            let s = insight.scores
            lines.append("[\(role)] \(insight.kind.rawValue) · family=\(insight.family.rawValue) · total \(String(format: "%.2f", s.total))")
        }
        if !result.story.noticed.isEmpty {
            lines.append("noticed rows: \(result.story.noticed.count)")
            for row in result.story.noticed {
                lines.append("  [noticed] \(row.kind.rawValue) · family=\(row.family.rawValue) · total \(String(format: "%.2f", row.scores.total))")
            }
        }
        if !result.rejections.isEmpty {
            lines.append("")
            lines.append("skipped:")
            for rejection in result.rejections {
                lines.append("  \(rejection.insightID) — \(rejection.reason)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

private extension RecapInsight {
    func scoreOrder() -> Double { scores.total }
}

private extension RecapCuratedStory {
    func roleOf(_ id: String) -> String {
        if hero1?.id == id { return "Hero1" }
        if hero2?.id == id { return "Hero2" }
        if microFact?.id == id { return "MicroFact" }
        return "Noticed"
    }
}