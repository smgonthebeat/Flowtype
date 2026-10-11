import XCTest
@testable import VoiceInputApp

/// design.md 8: boundaries between the math layer and the other stages.
final class MathStageIntegrationTests: XCTestCase {
    private func process(
        _ text: String,
        _ format: MathNotationOutputFormat = .unicode,
        knownTerms: [String] = [],
        filler: Bool = false
    ) -> String {
        TranscriptPostProcessor.process(text, options: MathCorpusSupport.options(format, knownTerms: knownTerms, filler: filler))
    }

    func testNumbersNextToAFormulaAreStillConverted() {
        XCTAssertEqual(process("一共 n 个样本，n 等于三十，占百分之五十"), "一共 n 个样本，n = 30，占50%")
        XCTAssertEqual(process("I have twenty one tasks and x squared plus y squared equals z squared"),
                       "I have 21 tasks and x² + y² = z²")
        XCTAssertEqual(process("验证码是一二三四五六，然后算 x 的平方", .latex), "验证码是123456，然后算 $x^2$")
    }

    func testStudyReferencesAreStillConverted() {
        XCTAssertEqual(process("Exercise three Q two H asks for x bar minus mu"), "Exercise 3 Q2(h) asks for x̄ − μ")
        XCTAssertEqual(process("Q three part B"), process("Q three part B", knownTerms: []))
    }

    func testHotwordsAndCodeAreUntouched() {
        XCTAssertEqual(process("Beta Hat Labs uses x squared", knownTerms: ["Beta Hat Labs"]), "Beta Hat Labs uses x²")
        XCTAssertEqual(process("run `x plus y` then x squared"), "run `x plus y` then x²")
        XCTAssertEqual(process("we already have $x^2$ here"), "we already have $x^2$ here")
    }

    func testIndexRangeRepeatsTheLetter() {
        // Owner decision 2026-10-09: the second index of a range belongs to the same letter.
        XCTAssertEqual(process("x 下标 0 到 9"), "x₀ 到 x₉")
        XCTAssertEqual(process("x bar sub one through n"), "x̄₁ through x̄ₙ")
        // Only a plain index starts a range; a power after "to the" and a prose range are untouched.
        XCTAssertEqual(process("x sub i plus one to n"), "xᵢ₊₁ to n")
        XCTAssertEqual(process("x sub one to the power two"), "x₁²")
        XCTAssertEqual(process("we met from two to nine"), "we met from 2 to 9")
    }

    func testFactorialSurvivesFinalCleanup() {
        // Final cleanup turns a bare "!" into "." outside protected spans; formulas are protected.
        XCTAssertEqual(process("n factorial"), "n!")
        XCTAssertEqual(process("n choose k equals n factorial over k factorial", .latex),
                       #"$\binom{n}{k} = \frac{n!}{k!}$"#)
    }

    func testExistingFactorialAndLatexStayIntactOnASecondPass() {
        // I2: rendered factorials and $...$ spans are existing notation; later stages leave them alone.
        XCTAssertEqual(process("n!"), "n!")
        XCTAssertEqual(process("n!/k!"), "n!/k!")
        XCTAssertEqual(process("$e = m c^2$", .latex), "$e = m c^2$")
        // A sentence-final "x!" in prose is still an exclamation mark, as with math off.
        XCTAssertEqual(process("The result is x!"), "The result is x.")
        XCTAssertEqual(process("a!"), "a.")
    }

    func testSpacingNextToChineseIsKept() {
        // D7: no space is added or removed around a formula.
        XCTAssertEqual(process("这里sigma squared就是方差"), "这里σ²就是方差")
        XCTAssertEqual(process("这里 sigma squared 就是方差"), "这里 σ² 就是方差")
        XCTAssertEqual(process("这里 sigma squared 就是方差", .latex), #"这里 $\sigma^2$ 就是方差"#)
    }

    func testFillerAroundAFormula() {
        XCTAssertEqual(process("嗯，x squared um plus y squared", filler: true), "x² + y²")
        XCTAssertEqual(process("x squared um plus y squared", filler: false), "x² + y²")
    }

    func testSentinelsInTheInputAreRemovedWhenMathIsOn() {
        let input = "x\u{E010} squared\u{E011} plus one"
        let output = process(input)
        XCTAssertFalse(output.contains("\u{E010}") || output.contains("\u{E011}"))
        XCTAssertEqual(output, "x² + 1")
    }

    func testTraceShowsOneEventPerCandidateSpan() {
        let result = TranscriptPostProcessor.processWithTrace(
            "theta hat is unbiased. Call omega later.",
            options: MathCorpusSupport.options(.unicode, knownTerms: [])
        )
        let math = result.trace.stages.filter { $0.stage == .mathNotation }
        XCTAssertEqual(math.count, 1)
        XCTAssertEqual(math.first?.events.map(\.ruleID), ["math.span.accepted", "math.span.rejected"])
        XCTAssertEqual(math.first?.events.map(\.reason), ["Greek symbol in a structure", "prose-common Greek name"])
        XCTAssertFalse(result.trace.stages.contains { $0.stage == .candidateScoring })
        for stage in result.trace.stages {
            XCTAssertFalse(stage.input.contains("\u{E010}") || stage.output.contains("\u{E010}"))
        }
    }

    func testMathOffIgnoresSentinelsInTheInput() {
        // With the switch off the pipeline is unchanged (I4): nothing strips or adds sentinels.
        let options = MathCorpusSupport.options(.unicode, knownTerms: [], math: false)
        XCTAssertEqual(TranscriptPostProcessor.process("x squared", options: options), "x squared")
    }
}
