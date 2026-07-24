import XCTest
@testable import VoiceInputApp

final class QwenContextEchoDetectorTests: XCTestCase {
    private let historicalInternalPrompts = [
        "Important terms to preserve exactly:",
        "Transcribe faithfully. Preserve the user's wording and mixed Chinese-English content.",
        "Keep the text natural, clear, and conversational. Remove obvious filler words only when they do not change meaning.",
        "Keep the text natural, clear, and conversational. Stay close to the spoken wording. Use conservative punctuation. Do not use exclamation marks. Remove obvious filler words only when they do not change meaning.",
        "Use clear written punctuation and a calm formal tone. Avoid excessive exclamation marks. Do not add new content.",
        "Use clear written punctuation and a calm formal tone. Use conservative punctuation. Do not use exclamation marks. Do not add new content.",
        "Follow the user's style guidance while preserving meaning and mixed Chinese-English terms.",
        "User style guidance:"
    ]
    private let hotwordList = "DEMO1001, TEST2045, Qwen, alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota, kappa, lambda, markdown, parser, renderer, sample phrase, test fixture, workflow, Example University."
    private let terms = ["DEMO1001", "TEST2045", "Qwen", "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "markdown", "parser", "renderer", "sample phrase", "test fixture", "workflow", "Example University"]

    private var context: QwenPromptContext {
        QwenPromptContext(payload: terms.joined(separator: " "), knownTerms: terms)
    }

    func testFlagsPromptPrefixEvenWhenTranscriptIsShort() {
        let legacyContext = QwenPromptContext(
            payload: "Important terms to preserve exactly: Qwen",
            knownTerms: ["Qwen"],
            internalOnlySegments: ["Important terms to preserve exactly:"]
        )

        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                "Important terms to preserve exactly:",
                context: legacyContext,
                recordingDuration: 30
            )
        )
    }

    func testDetectsShortHotwordListEcho() {
        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                hotwordList,
                context: context,
                recordingDuration: 1.4
            )
        )
    }

    func testDoesNotFlagShortTranscriptWithOneHotword() {
        XCTAssertFalse(
            QwenContextEchoDetector.isLikelyEcho(
                "Open the Qwen cheat sheet.",
                context: context,
                recordingDuration: 1.4
            )
        )
    }

    func testFlagsLongRecordingWhenItIsOnlyHotwordList() {
        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                hotwordList,
                context: context,
                recordingDuration: 30
            )
        )
    }

    func testFlagsCompleteHotwordListAfterLongSpokenPrefix() {
        let spokenPrefix = String(repeating: "This is genuine spoken content before an injected dictionary tail. ", count: 8)

        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                spokenPrefix + hotwordList,
                context: context,
                recordingDuration: 45
            )
        )
    }

    func testFlagsTheExactRetiredStylePromptPrefixFromIncident() {
        let fullGuidance = "Keep the text natural, clear, and conversational. Stay close to the spoken wording. Use conservative punctuation. Do not use exclamation marks. Remove obvious filler words only when they do not change meaning."
        let leakedPrefix = "Keep the text natural, clear, and conversational. Stay close to the spoken wording."
        let styleContext = QwenPromptContext(
            payload: fullGuidance,
            internalOnlySegments: [fullGuidance]
        )

        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                leakedPrefix,
                context: styleContext,
                recordingDuration: 1.785625
            )
        )
    }

    func testFlagsAnySentenceFromRetiredInternalInstruction() {
        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                "Stay close to the spoken wording.",
                context: .empty,
                recordingDuration: 1.5
            )
        )
    }

    func testDetectsAppendedInternalSentenceDespiteCaseWhitespaceAndPunctuationChanges() {
        XCTAssertTrue(
            QwenContextEchoDetector.containsInternalContextEchoTail(
                "X bar; STAY   CLOSE TO THE SPOKEN WORDING",
                context: .empty
            )
        )
    }

    func testDetectsAppendedTruncatedInternalInstructionPrefix() {
        XCTAssertTrue(
            QwenContextEchoDetector.containsInternalContextEchoTail(
                "X bar. Keep the text natural, clear",
                context: .empty
            )
        )
    }

    func testDetectsAppendedTruncatedCJKInternalInstructionPrefix() {
        let guidance = "请保持原始措辞并准确转写用户说出的内容，不要添加任何新信息。"
        let context = QwenPromptContext(payload: guidance)

        XCTAssertTrue(
            QwenContextEchoDetector.containsInternalContextEchoTail(
                "X bar. 请保持原始措辞并准确转写用户说出的内容",
                context: context
            )
        )
    }

    func testDoesNotFlagShortCJKOverlapAsInternalInstruction() {
        let guidance = "请保持原始措辞并准确转写用户说出的内容，不要添加任何新信息。"
        let context = QwenPromptContext(payload: guidance)

        XCTAssertFalse(
            QwenContextEchoDetector.containsInternalContextEchoTail(
                "X bar. 请保持原始措辞",
                context: context
            )
        )
    }

    func testDetectsShortDynamicInternalInstructionAtTail() {
        let context = QwenPromptContext(payload: "Be concise.")

        XCTAssertTrue(
            QwenContextEchoDetector.containsInternalContextEchoTail(
                "X bar. Be concise.",
                context: context
            )
        )
    }

    func testDetectsFullWidthAndZeroWidthInternalInstructionVariants() {
        XCTAssertTrue(
            QwenContextEchoDetector.containsInternalContextEchoTail(
                "X bar. Ｋｅｅｐ the text natural, clear",
                context: .empty
            )
        )
        XCTAssertTrue(
            QwenContextEchoDetector.containsInternalContextEchoTail(
                "X bar. Ke\u{200B}ep the text natural, clear",
                context: .empty
            )
        )
    }

    func testDetectsDiacriticInternalInstructionVariant() {
        XCTAssertTrue(
            QwenContextEchoDetector.containsInternalContextEchoTail(
                "X bar. K\u{00E9}ep the text natural, clear",
                context: .empty
            )
        )
    }

    func testFlagsExactSingleVocabularyPayloadSoItCanBeVerifiedWithoutContext() {
        let singleTermContext = QwenPromptContext(payload: "Qwen", knownTerms: ["Qwen"])

        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                "Qwen",
                context: singleTermContext,
                recordingDuration: 1
            )
        )
    }

    func testFlagsHighCoverageTruncatedSmallVocabularyPayload() {
        let threeTermContext = QwenPromptContext(
            payload: "alpha beta gamma",
            knownTerms: ["alpha", "beta", "gamma"]
        )
        let fourTermContext = QwenPromptContext(
            payload: "alpha beta gamma delta",
            knownTerms: ["alpha", "beta", "gamma", "delta"]
        )

        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                "alpha beta",
                context: threeTermContext,
                recordingDuration: 1
            )
        )
        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                "alpha beta gamma",
                context: fourTermContext,
                recordingDuration: 1
            )
        )
    }

    func testFlagsShortOrderedPrefixFromLargeVocabularyPayload() {
        let largeTerms = [
            "alpha", "beta", "gamma", "delta", "epsilon",
            "zeta", "eta", "theta", "iota", "kappa"
        ]
        let largeContext = QwenPromptContext(
            payload: largeTerms.joined(separator: " "),
            knownTerms: largeTerms
        )

        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                "alpha beta gamma",
                context: largeContext,
                recordingDuration: 1
            )
        )
        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                "Genuine opening. gamma delta epsilon zeta omega",
                context: largeContext,
                recordingDuration: 4
            )
        )
    }

    func testDoesNotFlagLargeVocabularyTermsScatteredAcrossLongNaturalTranscript() {
        let largeTerms = [
            "alpha", "beta", "gamma", "delta", "epsilon",
            "zeta", "eta", "theta", "iota", "kappa"
        ]
        let largeContext = QwenPromptContext(
            payload: largeTerms.joined(separator: " "),
            knownTerms: largeTerms
        )
        let text = "alpha appears in one section with substantial explanation, beta appears much later after another detailed paragraph, gamma belongs to a separate example, delta is discussed after more ordinary prose, epsilon follows a different argument, and zeta closes the long natural transcript"

        XCTAssertFalse(
            QwenContextEchoDetector.isLikelyEcho(
                text,
                context: largeContext,
                recordingDuration: 45
            )
        )
    }

    func testNormalizesKnownTermWidthAndDiacritics() {
        let accentedContext = QwenPromptContext(
            payload: "r\u{00E9}sum\u{00E9} na\u{00EF}ve Caf\u{00E9}",
            knownTerms: ["r\u{00E9}sum\u{00E9}", "na\u{00EF}ve", "Caf\u{00E9}"]
        )

        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                "resume naive cafe",
                context: accentedContext,
                recordingDuration: 2
            )
        )
    }

    func testDoesNotFlagUnrelatedTranscriptForSymbolOnlyKnownTerms() {
        let emojiContext = QwenPromptContext(
            payload: "🎙️ 🧠 ✨ 🔒",
            knownTerms: ["🎙️", "🧠", "✨", "🔒"]
        )

        XCTAssertFalse(
            QwenContextEchoDetector.isLikelyEcho(
                "ordinary transcript",
                context: emojiContext,
                recordingDuration: 2
            )
        )
    }

    func testFlagsCompleteSymbolOnlyVocabularyPayload() {
        let emojiContext = QwenPromptContext(
            payload: "🎙️ 🧠 ✨ 🔒",
            knownTerms: ["🎙️", "🧠", "✨", "🔒"]
        )

        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                "🎙, 🧠 ✨ 🔒",
                context: emojiContext,
                recordingDuration: 1
            )
        )
    }

    func testCommitGuardBlocksInternalPromptsAndLargeListsButAllowsSmallVocabularySpeech() {
        let largeContext = QwenPromptContext(
            payload: "alpha beta gamma delta",
            knownTerms: ["alpha", "beta", "gamma", "delta"]
        )
        let smallContext = QwenPromptContext(
            payload: "Qwen Flowtype",
            knownTerms: ["Qwen", "Flowtype"]
        )

        XCTAssertThrowsError(
            try SensitiveTranscriptCommitGuard.validate(
                "X bar. Keep the text natural, clear",
                context: .empty
            )
        )
        XCTAssertThrowsError(
            try SensitiveTranscriptCommitGuard.validate(
                "alpha beta gamma",
                context: largeContext
            )
        )
        XCTAssertNoThrow(
            try SensitiveTranscriptCommitGuard.validate(
                "Qwen Flowtype",
                context: smallContext
            )
        )
    }

    func testDoesNotFlagOrdinaryXBarTranscript() {
        XCTAssertFalse(
            QwenContextEchoDetector.isLikelyEcho(
                "X bar.",
                context: context,
                recordingDuration: 1.785625
            )
        )
    }

    func testEveryHistoricalInternalPromptHasIndependentLeakCoverage() {
        for prompt in historicalInternalPrompts {
            XCTAssertTrue(
                QwenContextEchoDetector.isLikelyEcho(
                    prompt,
                    context: .empty,
                    recordingDuration: 30
                ),
                "Historical prompt must remain blocked: \(prompt)"
            )
        }
    }


    func testEveryHistoricalInternalPromptSentenceHasIndependentLeakCoverage() {
        for prompt in historicalInternalPrompts {
            let sentences = prompt.split(whereSeparator: { ".!?".contains($0) })
            for sentence in sentences {
                let candidate = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !candidate.isEmpty else { continue }
                XCTAssertTrue(
                    QwenContextEchoDetector.isLikelyEcho(
                        candidate,
                        context: .empty,
                        recordingDuration: 30
                    ),
                    "Historical prompt sentence must remain blocked: \(candidate)"
                )
            }
        }
    }
}
