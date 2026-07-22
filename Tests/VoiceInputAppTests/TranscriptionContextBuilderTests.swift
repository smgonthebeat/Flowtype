import XCTest
@testable import VoiceInputApp

final class TranscriptionContextBuilderTests: XCTestCase {
    func testHotwordsLeadTheContext() {
        let hotwords = [
            Hotword(text: "Claude Code", isEnabled: true),
            Hotword(text: "Qwen3-ASR", isEnabled: true)
        ]

        let context = TranscriptionContextBuilder.context(for: hotwords)

        XCTAssertTrue(context.hasPrefix("Important terms to preserve exactly: Claude Code, Qwen3-ASR."))
    }

    func testBaselineStyleGuidanceMatchesFormerNaturalPreset() {
        let context = TranscriptionContextBuilder.context(for: [])

        XCTAssertTrue(context.contains("Keep the text natural, clear, and conversational."))
        XCTAssertTrue(context.contains("Use conservative punctuation"))
        XCTAssertTrue(context.contains("Do not use exclamation marks"))
        XCTAssertTrue(context.contains("Remove obvious filler words only when they do not change meaning."))
    }

    func testContextStaysWithinTotalBudgetWithManyHotwords() {
        let hotwords = (0..<40).map { Hotword(text: "term\($0)", isEnabled: true) }

        let context = TranscriptionContextBuilder.context(for: hotwords)

        XCTAssertTrue(context.hasPrefix("Important terms to preserve exactly:"))
        XCTAssertLessThanOrEqual(context.count, 900)
    }
}
