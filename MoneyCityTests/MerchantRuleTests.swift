import XCTest
@testable import MoneyCity

/// A rule that fires too eagerly silently misfiles every future transaction — worse than
/// having no rule at all. These tests pin down exactly when one is allowed to match.
final class MerchantRuleTests: XCTestCase {

    func testKeyNormalisationHandlesWalletsInconsistentFormatting() {
        XCTAssertEqual(MerchantRuleService.normalizedKey("  ARoma  Tel Aviv "), "aroma tel aviv")
        XCTAssertEqual(MerchantRuleService.normalizedKey("שופרסל   דיל"), "שופרסל דיל")
        XCTAssertEqual(MerchantRuleService.normalizedKey("   "), "")
    }

    func testExactMatchWins() {
        let rules = [
            MerchantRule(merchantKey: "ארומה", displayName: "ארומה", category: .food),
            MerchantRule(merchantKey: "ארומה סניף 12", displayName: "ארומה סניף 12", category: .entertainment)
        ]
        let hit = MerchantRuleService.rule(for: "ארומה סניף 12", in: rules)
        XCTAssertEqual(hit?.category, .entertainment)
    }

    func testLongerKeyWinsAmongSubstringMatches() {
        let rules = [
            MerchantRule(merchantKey: "רמי", displayName: "רמי", category: .other),
            MerchantRule(merchantKey: "רמי לוי", displayName: "רמי לוי", category: .food)
        ]
        let hit = MerchantRuleService.rule(for: "רמי לוי שיווק השקמה", in: rules)
        XCTAssertEqual(hit?.category, .food)
    }

    func testVeryShortKeysOnlyMatchExactlySoTheyCannotSwallowHistory() {
        let rules = [MerchantRule(merchantKey: "בר", displayName: "בר", category: .entertainment)]
        // Would be a substring of "סופרמרקט בר כוכבא" — must not fire.
        XCTAssertNil(MerchantRuleService.rule(for: "סופרמרקט בר כוכבא", in: rules))
        // Exact still works.
        XCTAssertNotNil(MerchantRuleService.rule(for: "בר", in: rules))
    }

    func testARuleOverridesTheKeywordEngineAndCountsAsCertain() {
        // "ארומה" is a coffee keyword in the built-in dictionary.
        let plain = CategorizationEngine.shared.classify(merchant: "ארומה", amount: 24)
        XCTAssertEqual(plain.category, .food)

        let rules = [MerchantRule(merchantKey: "ארומה", displayName: "ארומה", category: .entertainment)]
        let ruled = MerchantRuleService.classify(merchant: "ארומה", amount: 24, rules: rules)
        XCTAssertEqual(ruled.category, .entertainment)
        // The user said so, so it is not a guess and needs no confirmation.
        XCTAssertEqual(ruled.confidence, 1.0)
    }

    func testKeywordEngineStillHandlesUnknownMerchants() {
        let result = MerchantRuleService.classify(merchant: "שופרסל", amount: 300, rules: [])
        XCTAssertEqual(result.category, .food)
    }

    func testCorrectingAnExistingRuleUpdatesItInsteadOfAddingASecond() {
        let existing = [MerchantRule(merchantKey: "ארומה", displayName: "ארומה", category: .food)]
        let created = MerchantRuleService.ruleAfterCorrection(
            merchant: "  ארומה  ",
            category: .entertainment,
            existing: existing
        )
        XCTAssertNil(created, "an existing rule must be updated, not duplicated")
        XCTAssertEqual(existing[0].category, .entertainment)
    }

    func testCorrectingANewMerchantProducesARule() {
        let created = MerchantRuleService.ruleAfterCorrection(
            merchant: "חניון עזריאלי",
            category: .transport,
            existing: []
        )
        XCTAssertNotNil(created)
        XCTAssertEqual(created?.merchantKey, "חניון עזריאלי")
        XCTAssertEqual(created?.category, .transport)
    }

    func testBlankMerchantProducesNoRule() {
        XCTAssertNil(MerchantRuleService.ruleAfterCorrection(merchant: "   ", category: .food, existing: []))
    }
}
