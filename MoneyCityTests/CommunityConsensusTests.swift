import XCTest
@testable import MoneyCity

final class CommunityConsensusTests: XCTestCase {

    let testHash = CommunityMerchantIdentity.merchantHash(for: "מכולת דוד")

    func testZeroVotesProducesNoConsensus() {
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: [])
        XCTAssertEqual(result.status, .none)
        XCTAssertNil(result.winnerCategory)
        XCTAssertEqual(result.winningVotes, 0)
        XCTAssertEqual(result.totalVotes, 0)
    }

    func testOneVoteIsInsufficientForGlobalSuggestionOrConfirmation() {
        let vote = CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue)
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: [vote])
        XCTAssertEqual(result.status, .none)
        XCTAssertEqual(result.winningVotes, 1)
        XCTAssertEqual(result.totalVotes, 1)
    }

    func testTwoIdenticalUniqueVotersProducesCommunitySuggestion() {
        let votes = [
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-2", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue)
        ]
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: votes)
        XCTAssertEqual(result.status, .suggestion)
        XCTAssertEqual(result.winnerCategory, .food)
        XCTAssertEqual(result.winningVotes, 2)
        XCTAssertEqual(result.totalVotes, 2)
    }

    func testThreeIdenticalUniqueVotersProducesCommunityConfirmed() {
        let votes = [
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-2", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-3", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue)
        ]
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: votes)
        XCTAssertEqual(result.status, .confirmed)
        XCTAssertEqual(result.winnerCategory, .food)
        XCTAssertEqual(result.winningVotes, 3)
        XCTAssertEqual(result.totalVotes, 3)
    }

    func testTwoFoodOneShoppingIsNotConfirmed() {
        let votes = [
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-2", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-3", merchantHash: testHash, categoryRawValue: SpendingCategory.shopping.rawValue)
        ]
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: votes)
        // With conflicts and < 5 total votes, 2 votes for food is a suggestion, but NOT confirmed
        XCTAssertEqual(result.status, .suggestion)
        XCTAssertEqual(result.winnerCategory, .food)
        XCTAssertEqual(result.winningVotes, 2)
        XCTAssertEqual(result.totalVotes, 3)
    }

    func testFourFoodOneShoppingConfirmsAtEightyPercent() {
        let votes = [
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-2", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-3", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-4", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-5", merchantHash: testHash, categoryRawValue: SpendingCategory.shopping.rawValue)
        ]
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: votes)
        // 4 / 5 = 80% with >= 5 votes -> confirmed
        XCTAssertEqual(result.status, .confirmed)
        XCTAssertEqual(result.winnerCategory, .food)
        XCTAssertEqual(result.winningVotes, 4)
        XCTAssertEqual(result.totalVotes, 5)
        XCTAssertEqual(result.agreementRatio, 0.80)
    }

    func testThreeFoodTwoShoppingDoesNotConfirm() {
        let votes = [
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-2", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-3", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-4", merchantHash: testHash, categoryRawValue: SpendingCategory.shopping.rawValue),
            CommunityVote(voterId: "user-5", merchantHash: testHash, categoryRawValue: SpendingCategory.shopping.rawValue)
        ]
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: votes)
        // 3 / 5 = 60% < 80% -> suggestion food, NOT confirmed
        XCTAssertEqual(result.status, .suggestion)
        XCTAssertEqual(result.winnerCategory, .food)
        XCTAssertEqual(result.winningVotes, 3)
        XCTAssertEqual(result.totalVotes, 5)
        XCTAssertEqual(result.agreementRatio, 0.60)
    }

    func testTieResultsInDisputedNoWinner() {
        let votes = [
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-2", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-3", merchantHash: testHash, categoryRawValue: SpendingCategory.shopping.rawValue),
            CommunityVote(voterId: "user-4", merchantHash: testHash, categoryRawValue: SpendingCategory.shopping.rawValue)
        ]
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: votes)
        XCTAssertEqual(result.status, .disputed)
        XCTAssertNil(result.winnerCategory)
        XCTAssertEqual(result.winningVotes, 2)
        XCTAssertEqual(result.totalVotes, 4)
    }

    func testInvalidCategoryRecordIsIgnored() {
        let votes = [
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: "totally_invalid_cat"),
            CommunityVote(voterId: "user-2", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-3", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue)
        ]
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: votes)
        // Only 2 valid votes -> suggestion food
        XCTAssertEqual(result.status, .suggestion)
        XCTAssertEqual(result.winnerCategory, .food)
        XCTAssertEqual(result.totalVotes, 2)
    }

    func testDuplicateVoterCountsOnce() {
        let votes = [
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue),
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue)
        ]
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: votes)
        // Only 1 unique voter -> .none
        XCTAssertEqual(result.totalVotes, 1)
        XCTAssertEqual(result.status, .none)
    }

    func testSameVoterChangingCategoryKeepsNewestVote() {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let newDate = Date(timeIntervalSince1970: 2000)
        let votes = [
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.food.rawValue, updatedAt: oldDate),
            CommunityVote(voterId: "user-1", merchantHash: testHash, categoryRawValue: SpendingCategory.shopping.rawValue, updatedAt: newDate),
            CommunityVote(voterId: "user-2", merchantHash: testHash, categoryRawValue: SpendingCategory.shopping.rawValue, updatedAt: newDate)
        ]
        let result = CommunityConsensusEngine.computeConsensus(merchantHash: testHash, votes: votes)
        // user-1 changed to shopping, plus user-2 shopping -> 2 unique shopping votes -> suggestion shopping
        XCTAssertEqual(result.totalVotes, 2)
        XCTAssertEqual(result.winnerCategory, .shopping)
        XCTAssertEqual(result.status, .suggestion)
    }

    // MARK: - Identity & One User = One Vote Tests

    func testStableVoterIdentityIsDeterministicAcrossInstalls() {
        let userA = "_1234567890abcdef"
        let identity1 = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: userA)
        let identity2 = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: userA)

        XCTAssertFalse(identity1.isEmpty)
        XCTAssertEqual(identity1, identity2, "Same CloudKit user record name must yield identical voter identity across relaunches/devices")
    }

    func testDifferentCloudKitUsersProduceDifferentVoteIdentities() {
        let userA = "_user_A_record_111"
        let userB = "_user_B_record_222"

        let voterA = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: userA)
        let voterB = CommunityMerchantIdentity.stableVoterIdentity(cloudKitUserRecordName: userB)
        XCTAssertNotEqual(voterA, voterB)

        let recordA = CommunityMerchantIdentity.voteRecordName(userRecordName: userA, merchantHash: testHash)
        let recordB = CommunityMerchantIdentity.voteRecordName(userRecordName: userB, merchantHash: testHash)
        XCTAssertNotEqual(recordA, recordB)
    }

    func testSameCloudKitUserSameMerchantProducesSameVoteRecordName() {
        let userA = "_user_A_record_111"
        let name1 = CommunityMerchantIdentity.voteRecordName(userRecordName: userA, merchantHash: testHash)
        let name2 = CommunityMerchantIdentity.voteRecordName(userRecordName: userA, merchantHash: testHash)

        XCTAssertEqual(name1, name2)
    }
}
