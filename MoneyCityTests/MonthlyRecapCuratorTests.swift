import XCTest
import SwiftData
import SwiftUI
@testable import MoneyCity

final class MonthlyRecapCuratorTests: XCTestCase {

    private func date(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0, second: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.second = second
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func tx(_ amount: Double, _ merchant: String, _ category: SpendingCategory,
                    day: Int, month: Int = 8, year: Int = 2026) -> MoneyCity.Transaction {
        MoneyCity.Transaction(amount: amount, merchant: merchant, category: category,
                    timestamp: date(year: year, month: month, day: day))
    }

    /// Builds a scored candidate by hand for direct curator tests.
    private func insight(_ id: String, family: RecapInsightFamily, kind: RecapInsightKind,
                         category: SpendingCategory? = nil, merchant: String? = nil,
                         entityKey: String? = nil, txs: Set<UUID>, total: Double) -> RecapInsight {
        var result = RecapInsight(
            id: id,
            family: family,
            kind: kind,
            headlineEn: id,
            headlineHe: id,
            merchant: merchant,
            category: category,
            basis: [],
            strength: 1.0,
            evidence: RecapInsightEvidence(
                transactionIDs: txs,
                merchantKey: merchant.map { MerchantRuleService.normalizedKey($0) },
                categoryKey: category,
                entityKey: entityKey
            )
        )
        result.scores.total = total
        return result
    }

    // MARK: - Determinism

    func testDeterministicAcrossRuns() {
        let all = normalMonthWithRent
        let month = date(year: 2026, month: 8, day: 1)

        let first = RecapInsightCurator.curate(for: month, allTransactions: all)
        let second = RecapInsightCurator.curate(for: month, allTransactions: all)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.selectedInsights.map { $0.id }, second.selectedInsights.map { $0.id })
    }

    // MARK: - No padding / no weak fills

    func testSparseMonthProducesEmptyStory() {
        let all = [
            tx(18, "Aroma", .food, day: 3),
            tx(150, "Zara", .shopping, day: 8),
        ]
        let month = date(year: 2026, month: 8, day: 1)

        let story = RecapInsightCurator.curate(for: month, allTransactions: all)
        XCTAssertTrue(story.selectedInsights.isEmpty)
    }

    func testWeakPoolYieldsNoStoryRatherThanPadding() {
        let candidates = [
            insight("weak-outlier", family: .outlier, kind: .outlierPurchase, txs: [UUID()], total: 0.42),
            insight("weak-accumulation", family: .accumulation, kind: .smallPurchasesAccumulation, txs: [UUID()], total: 0.20),
        ]
        let result = RecapInsightCurator.curate(candidates: candidates, backbone: [])
        XCTAssertTrue(result.story.selectedInsights.isEmpty)
        XCTAssertFalse(result.rejections.isEmpty)
    }

    // MARK: - The tuning requirement: veto vs penalty

    func testSameStoryOverlapIsVetoMerchantSubsumedByCategory() {
        let all = normalMonthWithRent
        let candidates = RecapInsightEngine.generateCandidates(for: date(year: 2026, month: 8, day: 1), allTransactions: all)

        // Aroma is entirely inside the food category story → same story → vetoed.
        XCTAssertFalse(candidates.contains { $0.kind == .repeatedMerchant && $0.merchant == "Aroma" })
        XCTAssertTrue(candidates.contains { $0.kind == .repeatedCategory })
    }

    func testAdjacentOverlapIsSmallPenaltyNotVeto() {
        let all = normalMonthWithRent
        let candidates = RecapInsightEngine.generateCandidates(for: date(year: 2026, month: 8, day: 1), allTransactions: all)

        // bigVsFrequent contrasts the most-visited vs the highest-spend merchant.
        // It shares most of its evidence with the food pattern (Aroma x4 + Zara) but
        // means something genuinely different — it must survive, not be vetoed.
        let contrast = candidates.first { $0.kind == .bigVsFrequent }
        XCTAssertNotNil(contrast)
        XCTAssertTrue(candidates.contains { $0.kind == .repeatedCategory })
        // Its score reflects the mild adjacent overlap penalty (weaker side of the pair).
        XCTAssertLessThan((contrast?.scores.total ?? 1), 0.42)
        XCTAssertGreaterThan((contrast?.scores.total ?? 0), 0.30)
    }

    func testOutlierIsAllowedToCoexistWithDistrictStory() {
        let all = normalMonthWithRent
        let month = date(year: 2026, month: 8, day: 1)

        let curated = RecapInsightCurator.curate(
            candidates: RecapInsightEngine.generateCandidates(for: month, allTransactions: all),
            backbone: RecapInsightCurator.backbone(for: month, allTransactions: all)
        )
        // District = food is category-wide; the outlier is a genuine transaction-level
        // story inside it. They are allowed to coexist — and the outlier leads.
        XCTAssertEqual(curated.story.hero1?.id, "outlierPurchase:food")
        XCTAssertTrue(curated.story.selectedInsights.contains { $0.kind == .outlierPurchase })
        XCTAssertGreaterThan(curated.story.hero1?.scores.total ?? 0, 0.55)
        XCTAssertFalse(curated.rejections.contains { $0.reason.contains("outlierPurchase") })
    }

    func testOverlapGranularityTiers() {
        let ids = (0..<12).map { _ in UUID() }
        let ids8 = Set(ids[0...7])
        let ids6 = Set(ids[0...5])

        func profile(_ id: String, kind: RecapInsightKind?, single: Bool, dominance: Bool = false,
                     merchantKey: String? = nil, category: SpendingCategory? = nil,
                     txs: Set<UUID>) -> RecapInsightEngine.RecapStoryProfile {
            RecapInsightEngine.RecapStoryProfile(
                id: id, kind: kind, isBackbone: false,
                isSingleSubject: single,
                isMerchantBound: kind == .repeatedMerchant,
                isCategoryDominance: dominance,
                merchantKey: merchantKey, entityKey: nil, categoryKey: category, transactionIDs: txs
            )
        }

        let district = profile("district", kind: nil, single: true, dominance: true, category: .food, txs: ids8)
        let outlier = profile("outlier", kind: .outlierPurchase, single: true, category: .food, txs: [ids[5]])
        let repeatedCategory = profile("repeatedCategory:food", kind: .repeatedCategory, single: true, dominance: true, category: .food, txs: ids6)
        let aromaMerchant = profile("repeatedMerchant:aroma", kind: .repeatedMerchant, single: true, merchantKey: "aroma", category: .food, txs: Set([ids[0], ids[1], ids[2]]))
        let bigVsFrequent = profile("bigVsFrequent", kind: .bigVsFrequent, single: false, merchantKey: "aroma", category: .food, txs: Set([ids[0], ids[1], ids[2], ids[9]]))

        // Same category, transaction-level vs category-wide granularity → adjacent.
        if case .adjacent = RecapInsightEngine.overlapRelation(outlier, district) {} else {
            XCTFail("outlier vs district should be adjacent, not vetoed or ignored")
        }
        // A transaction-level outlier inside a category pattern is adjacent too.
        if case .adjacent = RecapInsightEngine.overlapRelation(outlier, repeatedCategory) {} else {
            XCTFail("outlier vs same-category pattern should be adjacent")
        }
        // A merchant fully inside its category pattern is the same story (veto).
        if case .sameStory = RecapInsightEngine.overlapRelation(aromaMerchant, repeatedCategory) {} else {
            XCTFail("a contained merchant is the same story as its category pattern")
        }
        // Shared actor (merchant) behind a relational compound → strong overlap.
        if case .strongOverlap = RecapInsightEngine.overlapRelation(bigVsFrequent, aromaMerchant) {} else {
            XCTFail("bigVsFrequent vs its featured merchant should be a strong overlap")
        }
        // Two "X dominated" claims on the same category → same story (veto).
        if case .sameStory = RecapInsightEngine.overlapRelation(repeatedCategory, district) {} else {
            XCTFail("two category-dominance claims on the same category must be the same story")
        }
        // Different categories sharing evidence → no relation.
        let shopping = profile("district", kind: nil, single: true, dominance: true, category: .shopping, txs: ids8)
        if case .none = RecapInsightEngine.overlapRelation(outlier, shopping) {} else {
            XCTFail("different categories should be unrelated")
        }
    }

    func testNoticedShotAcceptsTwoStrongRows() {
        let all = deliveryHeavyMonth
        let month = date(year: 2026, month: 8, day: 1)

        let rooted = RecapInsightCurator.curate(
            candidates: RecapInsightEngine.generateCandidates(for: month, allTransactions: all),
            backbone: RecapInsightCurator.backbone(for: month, allTransactions: all)
        )
        // Hero (deliveryHabit) + exactly two strong, diverse rows → the shot fires.
        XCTAssertEqual(rooted.story.noticed.count, RecapInsightCurator.minNoticedRows)
        for row in rooted.story.noticed {
            XCTAssertGreaterThanOrEqual(row.scores.total, RecapInsightCurator.noticedThreshold,
                                        "never lower the bar to fill the shot")
        }
        let families = Set(rooted.story.noticed.map { $0.family })
        XCTAssertEqual(families.count, rooted.story.noticed.count, "noticed rows must be topic-diverse")
    }

    func testMomentVetoesOutlierOfTheSameTransaction() {
        let all = [
            tx(18, "Aroma", .food, day: 3),
            tx(18, "Aroma", .food, day: 7),
            tx(18, "Aroma", .food, day: 12),
            tx(18, "Aroma", .food, day: 15),
            tx(150, "Shufersal", .food, day: 2),
        ]
        let month = date(year: 2026, month: 8, day: 1)

        let curated = RecapInsightCurator.curate(
            candidates: RecapInsightEngine.generateCandidates(for: month, allTransactions: all),
            backbone: RecapInsightCurator.backbone(for: month, allTransactions: all)
        )
        // Shufersal 150 is both the biggest-purchase Moment and the category outlier —
        // one story, retold. The Moment already tells it.
        XCTAssertFalse(curated.story.selectedInsights.contains { $0.kind == .outlierPurchase })
        XCTAssertTrue(curated.rejections.contains { $0.reason.contains("moment:biggestPurchase") })
    }

    func testHabitSurvivesDistrictOverlapAsDifferentMeaning() {
        var all: [MoneyCity.Transaction] = []
        for i in 0..<10 {
            all.append(tx(48, "Wolt", .food, day: 2 + i * 2))
        }
        all.append(tx(150, "Shufersal", .food, day: 6))
        all.append(tx(60, "Pharm", .health, day: 10))
        let month = date(year: 2026, month: 8, day: 1)

        let curated = RecapInsightCurator.curate(
            candidates: RecapInsightEngine.generateCandidates(for: month, allTransactions: all),
            backbone: RecapInsightCurator.backbone(for: month, allTransactions: all)
        )
        // biggestStoryDistrict is food, and the delivery habit is food — but the habit is
        // a behavior story, not the same proposition as "food was the biggest district".
        XCTAssertTrue(curated.story.selectedInsights.contains { $0.kind == .deliveryHabit })
        // The 150 Shufersal is the tallest building AND the outlier: vetoed.
        XCTAssertFalse(curated.story.selectedInsights.contains { $0.kind == .outlierPurchase })
    }

    func testDistrictVetoesCategoryDominanceStory() {
        let all = normalMonthWithRent
        let month = date(year: 2026, month: 8, day: 1)

        let curated = RecapInsightCurator.curate(
            candidates: RecapInsightEngine.generateCandidates(for: month, allTransactions: all),
            backbone: RecapInsightCurator.backbone(for: month, allTransactions: all)
        )
        // Accounting district = housing (rent), but the storytelling district = food.
        // The food dominance story is the same proposition as the district card → vetoed.
        XCTAssertFalse(curated.story.selectedInsights.contains { $0.kind == .repeatedCategory })
        XCTAssertTrue(curated.rejections.contains { $0.reason.contains("biggestStoryDistrict") })
    }

    // MARK: - Slot selection

    func testHero1IsTheStrongestMeaningfulTruth() {
        let month = date(year: 2026, month: 8, day: 1)
        let candidates = RecapInsightEngine.generateCandidates(for: month, allTransactions: normalMonthWithRent)
        // With no backbone interference, hero1 is simply the strongest candidate.
        let noBackbone = RecapInsightCurator.curate(candidates: candidates, backbone: [])
        let strongest = candidates.sorted {
            $0.scores.total == $1.scores.total ? $0.id < $1.id : $0.scores.total > $1.scores.total
        }.first!
        XCTAssertEqual(noBackbone.story.hero1?.id, strongest.id)

        // In the full pipeline the backbone may dock an overlapping candidate's score,
        // so the strongest *surviving* candidate is the hero — never a weak filler.
        let full = RecapInsightCurator.curate(for: month, allTransactions: normalMonthWithRent)
        XCTAssertNotNil(full.hero1)
        XCTAssertGreaterThanOrEqual(full.hero1?.scores.total ?? 0, RecapInsightCurator.heroThreshold)
        for other in full.selectedInsights where other.id != full.hero1?.id {
            XCTAssertLessThanOrEqual(other.scores.total, full.hero1?.scores.total ?? 1,
                                     "hero1 must be the strongest surviving story")
        }
    }

    func testNoticedRowsAreFamilyDiverseAndCapped() {
        let month = date(year: 2026, month: 8, day: 1)
        let story = RecapInsightCurator.curate(for: month, allTransactions: normalMonthWithRent)

        XCTAssertLessThanOrEqual(story.noticed.count, RecapInsightCurator.maxNoticedRows)
        if story.noticed.count >= 2 {
            let families = Set(story.noticed.map { $0.family })
            XCTAssertEqual(families.count, story.noticed.count, "noticed rows must be topic-diverse")
        }
    }

    func testHero2ComesFromAnUnusedFamily() {
        let month = date(year: 2026, month: 8, day: 1)
        let story = RecapInsightCurator.curate(for: month, allTransactions: normalMonthWithRent)

        if let hero2 = story.hero2 {
            XCTAssertNotEqual(hero2.family, story.hero1?.family)
            XCTAssertFalse(story.noticed.contains { $0.family == hero2.family })
        }
    }

    func testEveryStrongInsightFitsTheCap() {
        let months: [[MoneyCity.Transaction]] = [
            normalMonthWithRent,
            largeAccumulationMonth,
            deliveryHeavyMonth,
        ]
        for all in months {
            let story = RecapInsightCurator.curate(for: date(year: 2026, month: 8, day: 1), allTransactions: all)
            let count = story.selectedInsights.count
            XCTAssertLessThanOrEqual(count, RecapInsightCurator.maxNoticedRows + 3, "1 hero + 1 hero2 + 1 microfact + up to 4 noticed")
            for insight in story.selectedInsights {
                XCTAssertGreaterThanOrEqual(insight.scores.total, RecapInsightCurator.microFactThreshold,
                                            "never fill a slot with a weak insight")
            }
        }
    }

    // MARK: - Backbone computation

    func testBackboneIdentifiesStoryDistrictAndMoment() {
        let all = normalMonthWithRent
        let month = date(year: 2026, month: 8, day: 1)
        let slots = RecapInsightCurator.backbone(for: month, allTransactions: all, now: Date(), calendar: .init(identifier: .gregorian))

        // Rent (housing) is the accounting biggest district but excluded from the
        // storytelling district, which should land on food.
        XCTAssertTrue(slots.contains { $0.id == "biggestStoryDistrict:food" })
        // The Moment is the tallest non-recurring purchase = Zara 150.
        XCTAssertTrue(slots.contains { $0.id == "moment:biggestPurchase" && $0.profile.categoryKey == .shopping })
    }

    // MARK: - Phase 5 review output (printed to the test log for the review gate)

    func testPrintPhase5Review() {
        let month = date(year: 2026, month: 8, day: 1)
        let months: [(String, [MoneyCity.Transaction])] = [
            ("review-normal", normalMonthWithRent),
            ("review-accumulation", largeAccumulationMonth),
            ("review-delivery", deliveryHeavyMonth),
        ]
        for (label, all) in months {
            print("\n▶▶▶ \(label)")
            print(RecapInsightEngine.debugReport(for: month, allTransactions: all))
            print(RecapInsightCurator.debugCuratorReport(for: month, allTransactions: all))
        }
        let sparse = RecapInsightEngine.debugReport(for: month, allTransactions: [
            tx(20, "Aroma", .food, day: 3),
            tx(150, "Zara", .shopping, day: 8),
        ])
        XCTAssertTrue(!sparse.isEmpty)
    }

    // MARK: - Phase 6–8 integration (curated story → shot sequence)

    private func shotLabel(_ shot: RecapEditorialShot) -> String {
        switch shot {
        case .opening: return "opening"
        case .total: return "total"
        case .activity: return "activity"
        case .district: return "district"
        case .insight(let i):
            return i.copyVariant == "moment"
                ? "insight(moment·\(i.merchant ?? "-")·₪\(Int(i.primaryValue)))"
                : "insight(curated·\(i.family ?? "-")·\(Int(i.score * 100)))"
        case .noticed(let rows):
            return "noticed(\(rows.map { "\($0.family ?? "-")·\(Int($0.score * 100))" }.joined(separator: ", ")))"
        case .portrait: return "portrait"
        }
    }

    private func curatedLine(_ i: MonthlyRecapDynamicInsight) -> String {
        let he = i.headlineHe ?? ""
        let val = i.valueHe ?? ""
        return "\(i.family ?? "-") | \(i.type.rawValue) | \(he) \(val) @\(String(format: "%.2f", i.score))"
    }

    func testPhase678ShotSequencesAndGuards() {
        let month = date(year: 2026, month: 8, day: 1)
        let months: [(String, [MoneyCity.Transaction])] = [
            ("normal", normalMonthWithRent),
            ("accumulation", largeAccumulationMonth),
            ("delivery", deliveryHeavyMonth),
        ]
        for (label, all) in months {
            let recap = MonthlyRecapService.generateRecap(for: month, allTransactions: all, monthlyBudget: 8000)
            let shots = RecapEditorialShot.sequence(for: recap)

            print("\n▶▶▶ shots-\(label)")
            print("  dynamic: \(recap.dynamicInsights.map(curatedLine))")
            print("  noticed: \(recap.noticedInsights.map(curatedLine))")
            print("  micro:   \(recap.microFactInsight.map(curatedLine) ?? "none")")
            print("  sequence: \(shots.map(shotLabel))")

            XCTAssertLessThanOrEqual(shots.count, 9, "\(label) must respect the 9-shot cap")
            XCTAssertEqual(shots.first, RecapEditorialShot.opening)
            XCTAssertEqual(shots.last, RecapEditorialShot.portrait)
            XCTAssertEqual(shots.filter { $0 == .district }.count, 1)

            // The moment (fixed backbone shot) is always the first dynamic insight.
            XCTAssertEqual(recap.dynamicInsights.first?.copyVariant, "moment")
            // Noticed rows are capped at 4 and only present in their single grouped shot.
            XCTAssertLessThanOrEqual(recap.noticedInsights.count, RecapInsightCurator.maxNoticedRows)
            if !recap.noticedInsights.isEmpty {
                XCTAssertEqual(shots.filter { $0 == .noticed(recap.noticedInsights) }.count, 1)
            }
        }

        // Sparse months stay at the five editorial anchors.
        for input in [[], [tx(20, "Coffee", .food, day: 1)]] {
            let sparse = MonthlyRecapService.generateRecap(for: month, allTransactions: input)
            XCTAssertTrue(sparse.dynamicInsights.isEmpty)
            XCTAssertTrue(sparse.noticedInsights.isEmpty)
            XCTAssertNil(sparse.microFactInsight)
            XCTAssertEqual(
                RecapEditorialShot.sequence(for: sparse),
                [.opening, .total, .activity, .district, .portrait]
            )
        }
    }

    /// Phase 8 gate for the share frame: the Final Portrait still renders at the share
    /// resolution with real curated content (including the Micro Fact) in both languages.
    @MainActor func testPortraitExportWithMicroFactBothLanguages() throws {
        let recap = MonthlyRecapService.generateRecap(for: date(year: 2026, month: 8, day: 1),
                                                      allTransactions: normalMonthWithRent)
        for he in [true, false] {
            let content = RecapSceneFrame(shot: .portrait, recap: recap, time: 8.0, he: he, currency: "₪", export: true)
                .frame(width: 390, height: 650)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 3
            renderer.isOpaque = true
            let image = try XCTUnwrap(renderer.uiImage)
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(cgImage.width, 1170)
            XCTAssertEqual(cgImage.height, 1950)
            XCTAssertNotNil(image.pngData())
        }
    }

// MARK: - firstHalfVsSecondHalf recalibration

    private func firstHalfTotal(_ all: [MoneyCity.Transaction]) -> Double? {
        let pool = RecapInsightEngine.generateCandidates(
            for: date(year: 2026, month: 8, day: 1), allTransactions: all
        )
        return pool.first { $0.kind == .firstHalfVsSecondHalf }?.scores.total
    }

    func testFirstHalfFlatStaysWeak() {
        // ~44% relative half difference across only 8 active days: a real but shallow
        // lean. It should score well below the noticed bar.
        let all = [
            tx(100, "Market", .food, day: 1),
            tx(100, "Market", .food, day: 4),
            tx(100, "Market", .food, day: 7),
            tx(100, "Market", .food, day: 10),
            tx(100, "Market", .food, day: 13),
            tx(100, "Pharm", .health, day: 18),
            tx(100, "Pharm", .health, day: 22),
            tx(100, "Pharm", .health, day: 26),
        ]
        XCTAssertNotNil(firstHalfTotal(all), "a 44% lean must still generate")
        XCTAssertLessThan(firstHalfTotal(all) ?? 1, RecapInsightCurator.noticedThreshold)
    }

    func testFirstHalfMeaningfulBecomesGood() {
        // The normal month: ~90% front-loaded across 10 active days.
        let total = firstHalfTotal(normalMonthWithRent)
        XCTAssertNotNil(total)
        XCTAssertGreaterThanOrEqual(total ?? 0, RecapInsightCurator.noticedThreshold)
        XCTAssertLessThan(total ?? 1, RecapInsightCurator.heroThreshold)
    }

    func testFirstHalfExtremeBecomesHero() {
        // The month built up to the end 11.5x: extreme and clearly hero-worthy.
        var all: [MoneyCity.Transaction] = []
        for d in [2, 6, 10] { all.append(tx(20, "Cafe", .food, day: d)) }
        for d in [17, 19, 21, 23, 25, 27, 29, 30] { all.append(tx(100, "Zara", .shopping, day: d)) }
        XCTAssertNotNil(firstHalfTotal(all))
        XCTAssertGreaterThanOrEqual(firstHalfTotal(all) ?? 0, RecapInsightCurator.heroThreshold)
    }

    // MARK: - Datasets

    /// Housing rent included: accounting district = housing, story district = food.
    /// Contains a food pattern (Aroma x4 inside it), a bigVsFrequent contrast and an
    /// outlier — everything the overlap rules reason about.
    private var normalMonthWithRent: [MoneyCity.Transaction] {
        [
            tx(20, "Aroma", .food, day: 3),
            tx(20, "Aroma", .food, day: 7),
            tx(20, "Aroma", .food, day: 12),
            tx(20, "Aroma", .food, day: 15),
            tx(45, "Wolt", .food, day: 5),
            tx(35, "Falafel", .food, day: 10),
            tx(120, "Shufersal", .food, day: 2),
            tx(80, "Super Yuda", .food, day: 14),
            tx(150, "Zara", .shopping, day: 8),
            tx(60, "Pharm", .health, day: 9),
            tx(60, "Pharm", .health, day: 16),
            tx(3200, "Rent Landlord", .housing, day: 1),
        ]
    }

    private var largeAccumulationMonth: [MoneyCity.Transaction] {
        let merchants = ["Cafe A", "Bakery", "Bus", "Market", "News", "Yoga", "Parking", "Shoes", "Gift", "Snack"]
        return (1...20).map { i in
            tx(Double(12 + (i * 7) % 25), merchants[i % merchants.count],
               [.food, .transport, .shopping][i % 3], day: 1 + (i % 27))
        }
    }

    private var deliveryHeavyMonth: [MoneyCity.Transaction] {
        var all: [MoneyCity.Transaction] = []
        for i in 0..<10 {
            all.append(tx(48, "Wolt", .food, day: 2 + i * 2))
        }
        all.append(tx(150, "Shufersal", .food, day: 6))
        all.append(tx(60, "Pharm", .health, day: 10))
        return all
    }
}