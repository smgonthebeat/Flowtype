import XCTest
@testable import VoiceInputApp

final class MathIntentGateTests: XCTestCase {
    func testKeepsOriginalForDefinitionQuestionWithWeakMathEvents() {
        let decision = MathIntentGate.evaluate(
            original: "W hat does E T N stand for in financial products?",
            rendered: "Ŵ does E[T] N stand for in financial products?",
            events: [
                event(before: "W hat", after: "Ŵ", ruleID: "math.template.symbol-modifier"),
                event(before: "E T", after: "E[T]", ruleID: "math.speech.function.expectation")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "W hat does E T N stand for in financial products?")
        XCTAssertEqual(decision.selectedCandidate, .original)
        XCTAssertEqual(decision.outcome, .keptOriginal)
        XCTAssertTrue(decision.decisionEvent.reason.contains("plain-English blocker"))
    }

    func testKeepsOriginalForCodeLikeCommandEvenWithStatisticsPhrase() {
        let decision = MathIntentGate.evaluate(
            original: "write standard error beta hat in Swift",
            rendered: "write SE(β̂) in Swift",
            events: [
                event(before: "standard error beta hat", after: "SE(β̂)", ruleID: "math.speech.statistics.standard-error")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "write standard error beta hat in Swift")
        XCTAssertEqual(decision.selectedCandidate, .original)
        XCTAssertEqual(decision.outcome, .keptOriginal)
        XCTAssertTrue(decision.decisionEvent.reason.contains("code-like blocker"))
    }

    func testAcceptsShortFormulaDenseUtterance() {
        let decision = MathIntentGate.evaluate(
            original: "E T",
            rendered: "E[T]",
            events: [
                event(before: "E T", after: "E[T]", ruleID: "math.speech.function.expectation")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "E[T]")
        XCTAssertEqual(decision.selectedCandidate, .mathRendered)
        XCTAssertEqual(decision.outcome, .acceptedMath)
        XCTAssertTrue(decision.decisionEvent.reason.contains("short formula"))
    }

    func testAcceptsExplicitFormulaAnchor() {
        let decision = MathIntentGate.evaluate(
            original: "C hat equals beta",
            rendered: "Ĉ equals β",
            events: [
                event(before: "C hat", after: "Ĉ", ruleID: "math.template.symbol-modifier"),
                event(before: "beta", after: "β", ruleID: "math.template.symbol")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "Ĉ equals β")
        XCTAssertEqual(decision.selectedCandidate, .mathRendered)
        XCTAssertEqual(decision.outcome, .acceptedMath)
        XCTAssertTrue(decision.decisionEvent.reason.contains("formula anchor"))
    }

    func testFormulaAnchorOverridesPlainEnglishBlocker() {
        let decision = MathIntentGate.evaluate(
            original: "what is C hat equals beta?",
            rendered: "what is Ĉ equals β?",
            events: [
                event(before: "C hat", after: "Ĉ", ruleID: "math.template.symbol-modifier"),
                event(before: "beta", after: "β", ruleID: "math.template.symbol")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "what is Ĉ equals β?")
        XCTAssertEqual(decision.selectedCandidate, .mathRendered)
        XCTAssertEqual(decision.outcome, .acceptedMath)
        XCTAssertTrue(decision.decisionEvent.reason.contains("formula anchor"))
        XCTAssertTrue(decision.decisionEvent.reason.contains("plain-English blocker"))
    }

    func testKeepsOriginalForEmbeddedHyphenSearchFalsePositive() {
        let decision = MathIntentGate.evaluate(
            original: "search for alpha-beta",
            rendered: "search for α-β",
            events: [
                event(before: "alpha", after: "α", ruleID: "math.template.symbol"),
                event(before: "beta", after: "β", ruleID: "math.template.symbol")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "search for alpha-beta")
        XCTAssertEqual(decision.selectedCandidate, .original)
        XCTAssertEqual(decision.outcome, .keptOriginal)
    }

    func testKeepsOriginalForEmbeddedSlashPathFalsePositive() {
        let decision = MathIntentGate.evaluate(
            original: "open docs/alpha",
            rendered: "open docs/α",
            events: [
                event(before: "alpha", after: "α", ruleID: "math.template.symbol")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "open docs/alpha")
        XCTAssertEqual(decision.selectedCandidate, .original)
        XCTAssertEqual(decision.outcome, .keptOriginal)
    }

    func testAcceptsLongerFormulaLikeSequence() {
        let decision = MathIntentGate.evaluate(
            original: "alpha hat and x sub i",
            rendered: #"\hat{\alpha} and x_i"#,
            events: [
                event(before: "alpha hat", after: #"\hat{\alpha}"#, ruleID: "math.template.symbol-modifier"),
                event(before: "x sub i", after: "x_i", ruleID: "math.template.subscript")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, #"\hat{\alpha} and x_i"#)
        XCTAssertEqual(decision.selectedCandidate, .mathRendered)
        XCTAssertEqual(decision.outcome, .acceptedMath)
        XCTAssertTrue(decision.decisionEvent.reason.contains("formula-like sequence"))
    }

    func testKeepsOriginalForLongWeakRewriteWithoutSupportingMathSignal() {
        let decision = MathIntentGate.evaluate(
            original: "alpha remains significant in this model",
            rendered: "α remains significant in this model",
            events: [
                event(before: "alpha", after: "α", ruleID: "math.template.symbol")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "alpha remains significant in this model")
        XCTAssertEqual(decision.selectedCandidate, .original)
        XCTAssertEqual(decision.outcome, .keptOriginal)
        XCTAssertTrue(decision.decisionEvent.reason.contains("no supporting signal"))
    }

    func testKeepsShortProsePredicateFromBecomingFormulaDense() {
        let decision = MathIntentGate.evaluate(
            original: "alpha is significant",
            rendered: "α is significant",
            events: [
                event(before: "alpha", after: "α", ruleID: "math.template.symbol")
            ],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "alpha is significant")
        XCTAssertEqual(decision.selectedCandidate, .original)
        XCTAssertEqual(decision.outcome, .keptOriginal)
        XCTAssertTrue(
            decision.decisionEvent.reason.contains("no supporting signal")
                || decision.decisionEvent.reason.contains("prose predicate")
        )
    }

    func testNoopRenderingKeepsOriginalWithoutInventingMath() {
        let decision = MathIntentGate.evaluate(
            original: "plain text",
            rendered: "plain text",
            events: [],
            profile: .mathStatistics
        )

        XCTAssertEqual(decision.text, "plain text")
        XCTAssertEqual(decision.selectedCandidate, .original)
        XCTAssertEqual(decision.outcome, .keptOriginal)
        XCTAssertTrue(decision.decisionEvent.reason.contains("no math notation change"))
    }

    private func event(before: String, after: String, ruleID: String) -> PostProcessingEvent {
        PostProcessingEvent(
            ruleID: ruleID,
            rangeDescription: "whole-transcript",
            before: before,
            after: after,
            reason: "test event",
            confidence: .medium
        )
    }
}
