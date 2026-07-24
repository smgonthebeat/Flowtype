import XCTest
@testable import VoiceInputApp

final class TranscriptionContextBuilderTests: XCTestCase {
    func testHotwordsLeadTheContext() {
        let hotwords = [
            Hotword(text: "Claude Code", isEnabled: true),
            Hotword(text: "Qwen3-ASR", isEnabled: true)
        ]

        let context = TranscriptionContextBuilder.context(for: hotwords)

        XCTAssertEqual(context.payload, "Claude Code Qwen3-ASR")
        XCTAssertEqual(context.knownTerms, ["Claude Code", "Qwen3-ASR"])
        XCTAssertTrue(context.internalOnlySegments.isEmpty)
    }

    func testEmptyHotwordSetProducesEmptyQwenContext() {
        let context = TranscriptionContextBuilder.context(for: [])

        XCTAssertEqual(context, .empty)
    }

    func testRetiredStyleGuidanceIsNeverSentToQwen() {
        let context = TranscriptionContextBuilder.context(for: [Hotword(text: "Qwen", isEnabled: true)])

        XCTAssertFalse(context.payload.contains("Keep the text natural"))
        XCTAssertFalse(context.payload.contains("conversational"))
        XCTAssertFalse(context.payload.contains("punctuation"))
    }

    func testContextStaysWithinTotalBudgetWithManyHotwords() {
        let hotwords = (0..<40).map { Hotword(text: "term\($0)", isEnabled: true) }

        let context = TranscriptionContextBuilder.context(for: hotwords)

        XCTAssertLessThanOrEqual(context.payload.count, 700)
    }

    func testNonVocabularyPayloadIsAutomaticallyClassifiedAsInternal() {
        let context = QwenPromptContext(payload: "Be concise.")

        XCTAssertEqual(context.internalOnlySegments, ["Be concise."])
    }

    func testMixedInstructionAndVocabularyPayloadIsAutomaticallyClassifiedAsInternal() {
        let payload = "Important terms to preserve exactly: Qwen"
        let context = QwenPromptContext(payload: payload, knownTerms: ["Qwen"])

        XCTAssertEqual(context.internalOnlySegments, [payload])
    }
}
