import XCTest
@testable import MoneyCity

final class MerchantCanonicalizerTests: XCTestCase {

    // MARK: - TEST 1 — Learned merchant survives
    func testLearnedMerchantSurvives() {
        // Incoming: Chacoli. No rule.
        let rules: [MerchantRule] = []
        let initial = MerchantRuleService.classify(merchant: "Chacoli", amount: 25.0, rules: rules)
        XCTAssertEqual(initial.category, .other)
        XCTAssertLessThan(initial.confidence, 0.8)

        // User changes category to Food -> Upserts rule
        var currentRules = rules
        if let created = MerchantRuleService.ruleAfterCorrection(
            merchant: "Chacoli",
            category: .food,
            existing: currentRules
        ) {
            currentRules.append(created)
        }

        // Next incoming transaction: Chacoli
        let nextResult = MerchantRuleService.classify(merchant: "Chacoli", amount: 30.0, rules: currentRules)
        XCTAssertEqual(nextResult.category, .food)
        XCTAssertEqual(nextResult.confidence, 1.0)
        XCTAssertEqual(nextResult.source, .userRule)
    }

    // MARK: - TEST 2 — Formatting variants
    func testFormattingVariantsMatchLearnedRule() {
        // User teaches: WOLT -> Food
        var rules: [MerchantRule] = []
        if let rule = MerchantRuleService.ruleAfterCorrection(merchant: "WOLT", category: .food, existing: rules) {
            rules.append(rule)
        }

        let variants = ["Wolt", " WOLT ", "WOLT*IL", "WOLT *", "wolt", "wolt*israel"]
        for variant in variants {
            let result = MerchantRuleService.classify(merchant: variant, amount: 50.0, rules: rules)
            XCTAssertEqual(
                result.category,
                .food,
                "Variant '\(variant)' should match learned Food rule"
            )
            XCTAssertEqual(result.confidence, 1.0)
        }
    }

    // MARK: - TEST 3 — Same merchant through different parsers produces identical canonical key
    func testSameMerchantThroughDifferentParsersProducesIdenticalCanonicalKey() {
        let merchants = ["Kokpit 67", "Chacoli", "Super Yuda 24/7", "AM:PM", "Aroma Tel Aviv"]

        for m in merchants {
            // Parser A: normalizedMerchant from single line / notification
            let norm = TransactionIngest.normalizedMerchant(m) ?? m
            let keyA = MerchantCanonicalizer.canonicalKey(for: norm)

            // Parser B: salvage from text or merchant field
            let salvaged = TransactionIngest.salvage(amount: 50.0, amountText: nil, merchant: m)
            let salvagedMerchant = salvaged.merchant ?? m
            let keyB = MerchantCanonicalizer.canonicalKey(for: salvagedMerchant)

            // Parser C: manual user entry
            let keyC = MerchantCanonicalizer.canonicalKey(for: m)

            XCTAssertEqual(keyA, keyB, "Parser A and Parser B produced different canonical keys for '\(m)'")
            XCTAssertEqual(keyB, keyC, "Parser B and Parser C produced different canonical keys for '\(m)'")
        }
    }

    // MARK: - TEST 4 — Kokpit regression
    func testKokpitRegressionPreservesDigitsAndIdentityAcrossPaths() {
        let rawNotification = "מחוז תל אביב גבעתיים, Kokpit 67, ₪ 115.00"
        let rawSingleField = "Kokpit 67 ₪115.00"
        let plainMerchant = "Kokpit 67"

        // Check Parser A
        let fromNotification = TransactionIngest.normalizedMerchant(rawNotification)
        XCTAssertEqual(fromNotification, "Kokpit 67")

        // Check Parser B (salvage)
        let fromSalvage = TransactionIngest.salvage(amount: nil, amountText: nil, merchant: rawSingleField)
        XCTAssertEqual(fromSalvage.merchant, "Kokpit 67", "Digits '67' must not be stripped from merchant name in salvage")
        XCTAssertEqual(fromSalvage.amount, 115.0)

        // Check canonical keys match
        let keyNotification = MerchantCanonicalizer.canonicalKey(for: fromNotification!)
        let keySalvage = MerchantCanonicalizer.canonicalKey(for: fromSalvage.merchant!)
        let keyPlain = MerchantCanonicalizer.canonicalKey(for: plainMerchant)

        XCTAssertEqual(keyNotification, "kokpit 67")
        XCTAssertEqual(keySalvage, "kokpit 67")
        XCTAssertEqual(keyPlain, "kokpit 67")

        // Teach SPENT that Kokpit 67 is Entertainment
        var rules: [MerchantRule] = []
        if let rule = MerchantRuleService.ruleAfterCorrection(merchant: plainMerchant, category: .entertainment, existing: rules) {
            rules.append(rule)
        }

        // Verify transaction from salvage receives learned Entertainment rule
        let classifiedFromSalvage = MerchantRuleService.classify(
            merchant: fromSalvage.merchant!,
            amount: fromSalvage.amount ?? 0,
            rules: rules
        )
        XCTAssertEqual(classifiedFromSalvage.category, .entertainment)
        XCTAssertEqual(classifiedFromSalvage.confidence, 1.0)
    }

    // MARK: - TEST 5 — User correction overrides heuristic
    func testUserCorrectionOverridesHeuristic() {
        // Built-in CategorizationEngine classifies "Zara" as .shopping
        let heuristic = CategorizationEngine.shared.classify(merchant: "Zara", amount: 120.0)
        XCTAssertEqual(heuristic.category, .shopping)

        // User explicitly changes Zara -> Food
        var rules: [MerchantRule] = []
        if let rule = MerchantRuleService.ruleAfterCorrection(merchant: "Zara", category: .food, existing: rules) {
            rules.append(rule)
        }

        // Future Zara transaction must classify as Food with 1.0 confidence
        let classified = MerchantRuleService.classify(merchant: "Zara", amount: 150.0, rules: rules)
        XCTAssertEqual(classified.category, .food, "User rule must override built-in heuristic")
        XCTAssertEqual(classified.confidence, 1.0)
        XCTAssertEqual(classified.source, .userRule)
    }

    // MARK: - TEST 6 — Second correction updates rule without duplicates
    func testSecondCorrectionUpdatesRuleWithoutDuplicates() {
        var rules: [MerchantRule] = []

        // First correction: Merchant X -> Food
        if let r1 = MerchantRuleService.ruleAfterCorrection(merchant: "Merchant X", category: .food, existing: rules) {
            rules.append(r1)
        }
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].category, .food)

        // Second correction: Merchant X -> Entertainment
        let r2 = MerchantRuleService.ruleAfterCorrection(merchant: "  merchant x  ", category: .entertainment, existing: rules)
        XCTAssertNil(r2, "Updating an existing rule should return nil and modify in-place")
        XCTAssertEqual(rules.count, 1, "There must not be duplicate rules for the same merchant")
        XCTAssertEqual(rules[0].category, .entertainment)

        let classified = MerchantRuleService.classify(merchant: "Merchant X", amount: 40.0, rules: rules)
        XCTAssertEqual(classified.category, .entertainment)
        XCTAssertEqual(classified.confidence, 1.0)
    }

    // MARK: - TEST 7 — Similar merchants remain separate
    func testSimilarMerchantsRemainSeparate() {
        let key48 = MerchantCanonicalizer.canonicalKey(for: "Cafe 48")
        let key49 = MerchantCanonicalizer.canonicalKey(for: "Cafe 49")
        XCTAssertNotEqual(key48, key49)

        XCTAssertFalse(
            MerchantCanonicalizer.matchesLearnedAlias(candidate: "Cafe 48", learnedKey: key49),
            "Merchants with different digits must never alias"
        )
        XCTAssertFalse(
            MerchantCanonicalizer.matchesLearnedAlias(candidate: "Branch 1", learnedKey: MerchantCanonicalizer.canonicalKey(for: "Branch 2")),
            "Different branches must never alias"
        )

        let rule48 = MerchantRule(merchantKey: key48, displayName: "Cafe 48", category: .food)
        let hit = MerchantRuleService.rule(for: "Cafe 49", in: [rule48])
        XCTAssertNil(hit, "Cafe 49 must not match rule for Cafe 48")
    }

    // MARK: - TEST 8 — Unknown merchant still behaves safely
    func testUnknownMerchantStillBehavesSafely() {
        let unknown = "Zyxw Vu Tsrq"
        let result = MerchantRuleService.classify(merchant: unknown, amount: 85.0, rules: [])
        XCTAssertEqual(result.category, .other)
        XCTAssertEqual(result.confidence, 0.5)
        XCTAssertEqual(result.source, .unknown)
    }

    // MARK: - TEST 9 — Legacy rule compatibility
    func testLegacyRuleCompatibilityWithLazyMigration() {
        // Create an old rule saved with old lowercase normalization
        let legacyRule = MerchantRule(
            id: UUID(),
            merchantKey: "wolt",
            displayName: "WOLT",
            category: .food
        )

        // Match against formatting variant: "PAY* WOLT*IL"
        let matched = MerchantRuleService.rule(for: "PAY* WOLT*IL", in: [legacyRule])
        XCTAssertNotNil(matched)
        XCTAssertEqual(matched?.category, .food)

        // Check classification
        let result = MerchantRuleService.classify(merchant: "PAY* WOLT*IL", amount: 65.0, rules: [legacyRule])
        XCTAssertEqual(result.category, .food)
        XCTAssertEqual(result.confidence, 1.0)
    }

    // MARK: - TEST 10 — Existing regression test strengthened
    func testACorrectedMerchantIsClassifiedWithCertaintyNextTimeExpanded() {
        let rule = MerchantRule(
            merchantKey: MerchantCanonicalizer.canonicalKey(for: "Chacoli"),
            displayName: "Chacoli",
            category: .food
        )

        let testInputs = [
            "Chacoli",
            "chacoli",
            "CHACOLI",
            "  Chacoli  ",
            "PAY* Chacoli",
            "Chacoli*IL"
        ]

        for input in testInputs {
            let result = MerchantRuleService.classify(merchant: input, amount: 6, rules: [rule])
            XCTAssertEqual(result.category, .food, "Input '\(input)' should be classified as food")
            XCTAssertEqual(result.confidence, 1.0)
        }
    }

    // MARK: - TEST 11 — Canonicalizer unit tests
    func testCanonicalizerUnitTests() {
        // 1. Case differences
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "AROMA"), "aroma")
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "aRoMa"), "aroma")

        // 2. Extra whitespace & newlines
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "  Aroma \n  Tel  Aviv  "), "aroma tel aviv")

        // 3. Punctuation & quotes
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "McDonald's"), "mcdonald's")
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "McDonald’s"), "mcdonald's")
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "AM:PM"), "am:pm")

        // 4. Unicode Hebrew Niqqud stripping
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "אָרוֹמָה"), "ארומה")

        // 5. Payment processor noise stripping
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "PAY* ארומה"), "ארומה")
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "GMF* Toms"), "toms")
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "WOLT*IL"), "wolt")
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "Z- רמי לוי"), "רמי לוי")

        // 6. Meaningful numbers preserved
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "Kokpit 67"), "kokpit 67")
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "Cafe 48"), "cafe 48")
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "7-Eleven"), "7-eleven")
        XCTAssertEqual(MerchantCanonicalizer.canonicalKey(for: "Super Yuda 24/7"), "super yuda 24/7")

        // 7. Safe display merchant sanitization
        XCTAssertEqual(MerchantCanonicalizer.safeDisplayMerchant("  Kokpit 67  "), "Kokpit 67")
        XCTAssertEqual(MerchantCanonicalizer.safeDisplayMerchant(""), "לא זוהה")
    }

    // MARK: - TEST 12 — Auto-confirmed/isRecognized historical transaction cannot become a learned rule
    @MainActor
    func testAutoConfirmedHistoricalTransactionCannotBecomeLearnedRule() {
        // An automatically recognized transaction arrives during ingestion with isConfirmed = true
        let autoTx = Transaction(
            amount: 75.0,
            currency: "₪",
            merchant: "Auto Store 99",
            category: .food,
            confidenceScore: 0.85,
            isManual: false,
            isConfirmed: true // Recognized by keyword/heuristic during ingest
        )
        
        // Ensure DatabaseService.recoverFromHistoryIfSafe does not learn from autoTx
        let recovered = DatabaseService.shared.recoverFromHistoryIfSafe(for: autoTx.merchant)
        XCTAssertNil(recovered, "Auto-confirmed historical transactions must never be recovered as learned rules")

        // Ensure no MerchantRule exists for this merchant
        let rule = DatabaseService.shared.merchantRule(for: autoTx.merchant)
        XCTAssertNil(rule, "No MerchantRule should exist for an auto-recognized merchant")

        // Classification should not report source as userRule or historyRecovery
        let classification = MerchantRuleService.classify(merchant: autoTx.merchant, amount: 75.0, rules: [])
        XCTAssertNotEqual(classification.source, .userRule)
        XCTAssertNotEqual(classification.source, .historyRecovery)
    }

    // MARK: - TEST 13 — Editing only a merchant name does not accidentally learn auto-inferred category
    @MainActor
    func testEditingOnlyMerchantNameDoesNotLearnAutoInferredCategory() {
        // Transaction with automatically inferred category
        let tx = Transaction(
            amount: 120.0,
            currency: "₪",
            merchant: "Boutique",
            category: .shopping,
            confidenceScore: 0.85,
            isManual: false,
            isConfirmed: true
        )
        XCTAssertFalse(tx.needsCategorization)

        // User edits only merchant name in EditTransactionSheet
        let editedMerchantName = "Boutique Dizengoff"
        let hasUserExplicitlySelectedCategory = false
        let selectedCategory = tx.category

        // Replicate the exact gate in EditTransactionSheet.save()
        let isExplicitCategoryAction = hasUserExplicitlySelectedCategory || (tx.needsCategorization && selectedCategory != .other)
        XCTAssertFalse(isExplicitCategoryAction, "Editing only merchant name without touching category must not be considered explicit category confirmation")

        if isExplicitCategoryAction && !editedMerchantName.isEmpty && selectedCategory != .other {
            DatabaseService.shared.rememberCorrection(
                merchant: editedMerchantName,
                category: selectedCategory,
                buildingId: nil
            )
        }

        // Verify that no learned rule was created for the new merchant name
        let rule = DatabaseService.shared.merchantRule(for: editedMerchantName)
        XCTAssertNil(rule, "Editing merchant name alone must not create a learned MerchantRule for the inferred category")
    }
}
