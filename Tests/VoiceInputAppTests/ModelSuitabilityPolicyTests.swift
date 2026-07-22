import XCTest
@testable import VoiceInputApp

final class ModelSuitabilityPolicyTests: XCTestCase {
    func testSixteenGBStronglyRecommendsSmallModelAndDiscouragesLargeModel() {
        let hardware = HardwareSummary(machine: "MacBookPro18,3", processor: "Apple M1 Pro", physicalMemoryGB: 16, isAppleSilicon: true)
        let policy = ModelSuitabilityPolicy()

        XCTAssertEqual(policy.recommendation(hardware: hardware, model: .qwen3ASR06B).level, .recommended)
        XCTAssertEqual(policy.recommendation(hardware: hardware, model: .qwen3ASR17B).level, .stronglyDiscouraged)
        XCTAssertEqual(policy.recommendation(hardware: hardware, model: .qwen3ASR17B).physicalMemoryGB, 16)
        XCTAssertTrue(policy.requiresConfirmation(hardware: hardware, model: .qwen3ASR17B))
    }

    func testTwentyFourGBWarnsButAllowsLargeModel() {
        let hardware = HardwareSummary(machine: "Mac14,7", processor: "Apple M2 Pro", physicalMemoryGB: 24, isAppleSilicon: true)
        let policy = ModelSuitabilityPolicy()

        let recommendation = policy.recommendation(hardware: hardware, model: .qwen3ASR17B)

        XCTAssertEqual(recommendation.level, .allowedWithWarning)
        XCTAssertTrue(policy.requiresConfirmation(hardware: hardware, model: .qwen3ASR17B))
    }

    func testThirtyTwoGBAllowsLargeModelAsOptIn() {
        let hardware = HardwareSummary(machine: "Mac15,9", processor: "Apple M3 Pro", physicalMemoryGB: 32, isAppleSilicon: true)
        let policy = ModelSuitabilityPolicy()

        let recommendation = policy.recommendation(hardware: hardware, model: .qwen3ASR17B)

        XCTAssertEqual(recommendation.level, .reasonableOptIn)
        XCTAssertFalse(policy.requiresConfirmation(hardware: hardware, model: .qwen3ASR17B))
    }

    func testFortyEightGBMarksLargeModelSuitable() {
        let hardware = HardwareSummary(machine: "Mac16,5", processor: "Apple M4 Max", physicalMemoryGB: 48, isAppleSilicon: true)
        let policy = ModelSuitabilityPolicy()

        XCTAssertEqual(policy.recommendation(hardware: hardware, model: .qwen3ASR17B).level, .suitable)
    }
}
