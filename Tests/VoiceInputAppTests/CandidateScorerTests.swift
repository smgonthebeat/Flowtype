import XCTest
@testable import VoiceInputApp

final class CandidateScorerTests: XCTestCase {
    func testMathRenderedCandidateWinsWithStrongMathSignal() {
        let candidates = [
            TranscriptCandidate(text: "the variant of X is large", source: .original, transformations: []),
            TranscriptCandidate(text: "the variance of X is large", source: .confusionCorrected, transformations: []),
            TranscriptCandidate(text: "the Var(X) is large", source: .mathRendered, transformations: [])
        ]
        let context = CandidateScoringContext(
            profile: .mathStatistics,
            sourceText: "the variant of X is large",
            hasMathSignal: true,
            hasPlainEnglishBlocker: false,
            hasCodeLikeBlocker: false
        )

        let winner = CandidateScorer.choose(candidates, context: context)

        XCTAssertEqual(winner?.text, "the Var(X) is large")
        XCTAssertTrue(CandidateScorer.score(candidates[2], context: context).reasons.contains("math profile prefers rendered math"))
    }

    func testOriginalCandidateWinsWithPlainEnglishBlocker() {
        let candidates = [
            TranscriptCandidate(text: "the variant in my schedule is annoying", source: .original, transformations: []),
            TranscriptCandidate(text: "the variance in my schedule is annoying", source: .confusionCorrected, transformations: [])
        ]
        let context = CandidateScoringContext(
            profile: .mathStatistics,
            sourceText: "the variant in my schedule is annoying",
            hasMathSignal: false,
            hasPlainEnglishBlocker: true,
            hasCodeLikeBlocker: false
        )

        let winner = CandidateScorer.choose(candidates, context: context)

        XCTAssertEqual(winner?.text, "the variant in my schedule is annoying")
    }

    func testOriginalCandidateWinsInGeneralProfile() {
        let candidates = [
            TranscriptCandidate(text: "variant of X", source: .original, transformations: []),
            TranscriptCandidate(text: "variance of X", source: .confusionCorrected, transformations: [])
        ]
        let context = CandidateScoringContext(
            profile: .general,
            sourceText: "variant of X",
            hasMathSignal: true,
            hasPlainEnglishBlocker: false,
            hasCodeLikeBlocker: false
        )

        XCTAssertEqual(CandidateScorer.choose(candidates, context: context)?.text, "variant of X")
    }

    func testScoreOrderingIsDeterministic() {
        let original = TranscriptCandidate(text: "variant of X", source: .original, transformations: [])
        let corrected = TranscriptCandidate(text: "variance of X", source: .confusionCorrected, transformations: [])
        let context = CandidateScoringContext(
            profile: .mathStatistics,
            sourceText: "variant of X",
            hasMathSignal: true,
            hasPlainEnglishBlocker: false,
            hasCodeLikeBlocker: false
        )

        XCTAssertGreaterThan(
            CandidateScorer.score(corrected, context: context).value,
            CandidateScorer.score(original, context: context).value
        )
    }

    func testOriginalCandidateWinsWhenCodeLikeBlockerConflictsWithMathSignal() {
        let candidates = [
            TranscriptCandidate(
                text: "write standard error beta hat in Swift",
                source: .original,
                transformations: []
            ),
            TranscriptCandidate(
                text: "write SE(β̂) in Swift",
                source: .mathRendered,
                transformations: []
            )
        ]
        let context = CandidateScoringContext(
            profile: .mathStatistics,
            sourceText: "write standard error beta hat in Swift",
            hasMathSignal: true,
            hasPlainEnglishBlocker: false,
            hasCodeLikeBlocker: true
        )

        let winner = CandidateScorer.choose(candidates, context: context)

        XCTAssertEqual(winner?.text, "write standard error beta hat in Swift")
        XCTAssertTrue(
            CandidateScorer.score(candidates[1], context: context)
                .reasons
                .contains("code-like blocker")
        )
    }

    func testTieBreakKeepsFirstCandidateWhenScoresAndSourcePriorityAreEqual() {
        let candidates = [
            TranscriptCandidate(text: "first original", source: .original, transformations: []),
            TranscriptCandidate(text: "second original", source: .original, transformations: [])
        ]
        let context = CandidateScoringContext(
            profile: .general,
            sourceText: "source",
            hasMathSignal: false,
            hasPlainEnglishBlocker: false,
            hasCodeLikeBlocker: false
        )

        XCTAssertEqual(CandidateScorer.score(candidates[0], context: context).value, CandidateScorer.score(candidates[1], context: context).value)
        XCTAssertEqual(CandidateScorer.choose(candidates, context: context)?.text, "first original")
    }
}
