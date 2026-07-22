import XCTest
@testable import VoiceInputApp

final class CompactASRTokenNormalizerTests: XCTestCase {
    func testNormalizesCompactSubscriptTokens() {
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("Nsubj"), "N sub j")
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("Xsub10"), "X sub 10")
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("Zsubt"), "Z sub t")
    }

    func testNormalizesChainedCompactSubscriptTokens() {
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("NsubiNsubj"), "N sub i N sub j")
    }

    func testNormalizesCompactModifierTokens() {
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("Xbar"), "X bar")
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("Yhat"), "Y hat")
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("Nprime"), "N prime")
    }

    func testLeavesPlainEnglishAlone() {
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("subway"), "subway")
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("barbecue"), "barbecue")
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("the X factor"), "the X factor")
        XCTAssertEqual(CompactASRTokenNormalizer.normalize("core ideas are useful"), "core ideas are useful")
    }
}
