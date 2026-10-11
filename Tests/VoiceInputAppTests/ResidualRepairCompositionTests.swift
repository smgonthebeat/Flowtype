import XCTest
@testable import VoiceInputApp

final class ResidualRepairCompositionTests: XCTestCase {
    func testCanonicalArgumentSurvivesDictionaryBoundary() {
        // Math rebuild: notation the recogniser already wrote (β, \beta) is inert and is not converted
        // between formats (design.md 3 rule 3, D1). Formerly: β <-> \beta by output format.
        for input in ["S D β", #"S D \beta"#] {
            ResidualRepairAssertions.check(input, terms: ["S D"], when: { $0.isMathNotationEnabled },
                expected: { _ in input })
        }
    }
    func testWholeUnaryCandidateAbstains() {
        // Math rebuild: the function still abstains (the span is rejected as "ambiguous function
        // argument"), but SpelledLetterNormalizer has no math branch any more, so the unclaimed letter
        // run is spelled exactly as with math off (design.md 8.4). Formerly: letters kept apart.
        // "expectation X Y" moved to testExpectationOfRandomVariableRunIsProduct (owner decision 2026-10-09).
        for (input, expected) in [
            ("expectation E M", "expectation EM"), ("expectation of E M", "expectation of EM"),
            ("expected value E M", "expected value EM"),
            ("expectation E M hat", "expectation EM hat"), ("expectation β γ", "expectation β γ"),
            ("expectation E β", "expectation E β"), ("S D X Y", "SDXY"), ("variance X Y", "variance XY"),
            ("standard error X Y", "standard error XY")
        ] {
            ResidualRepairAssertions.check(input, when: { $0.isMathNotationEnabled }, expected: { _ in expected })
            ResidualRepairAssertions.check(input, when: { !$0.isMathNotationEnabled }, expected: { _ in expected })
        }
    }
    func testExpectationOfRandomVariableRunIsProduct() {
        // Owner decision 2026-10-09: after expectation, X Y (or a glued XY) is the product E[XY];
        // math off still spells the letters together.
        for input in ["expectation X Y", "Expectation XY"] {
            ResidualRepairAssertions.check(input, when: { $0.isMathNotationEnabled }, expected: { options in
                options.mathNotationOutputFormat == .latex ? #"$\mathbb{E}[X Y]$"# : "E[XY]"
            })
            ResidualRepairAssertions.check(input, when: { !$0.isMathNotationEnabled }, expected: { _ in
                input.hasPrefix("E") ? "Expectation XY" : "expectation XY"
            })
        }
    }

    func testInteriorFunctionAliasDoesNotVetoSpelling() {
        for (input, expected) in [("C E O a S O L", "CEOASOL"), ("C E O I S O L", "CEOISOL"), ("C E O", "CEO"), ("A I", "AI"), ("A S T R A", "ASTRA")] {
            ResidualRepairAssertions.check(input, expected: { _ in expected })
        }
    }
    func testExplicitUnaryAndIndependentFollowingMathRemainAvailable() {
        // Math rebuild: LaTeX is $...$ with \mathbb{E} / \operatorname (D1, D4); the abstained letter run
        // is spelled as with math off (design.md 8.4).
        ResidualRepairAssertions.check("expectation X", when: { $0.isMathNotationEnabled },
            expected: { $0.mathNotationOutputFormat == .latex ? #"$\mathbb{E}[X]$"# : "E[X]" })
        ResidualRepairAssertions.check("expectation of M", when: { $0.isMathNotationEnabled },
            expected: { $0.mathNotationOutputFormat == .latex ? #"$\mathbb{E}[M]$"# : "E[M]" })
        ResidualRepairAssertions.check("expectation E M, variance x", when: { $0.isMathNotationEnabled },
            expected: { $0.mathNotationOutputFormat == .latex ? #"expectation EM, $\operatorname{Var}(X)$"# : "expectation EM, Var(X)" })
    }
}
