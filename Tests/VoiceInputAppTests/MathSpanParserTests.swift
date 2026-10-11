import XCTest
@testable import VoiceInputApp

/// design.md sections 4 and 5: parse + render, without the evidence decision.
final class MathSpanParserTests: XCTestCase {
    /// Longest parse from the first token, rendered, plus whatever text follows the span.
    private func parseAndRender(_ text: String, _ format: MathNotationOutputFormat) -> String? {
        let stream = MathLexer.lex(text)
        guard let (node, next) = MathSpanParser(stream).parseSpan(at: 0), next > 0 else { return nil }
        let rest = stream.text(from: stream.tokens[next - 1].end, to: stream.characters.count)
        // Only whole-row formulas: what is left must be punctuation or spaces.
        guard rest.allSatisfy({ $0.isWhitespace || $0.isPunctuation }) else { return nil }
        return MathStage.render(node, format) + rest
    }

    private func assertParses(_ text: String, unicode: String, latex: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(parseAndRender(text, .unicode), unicode, text, file: file, line: line)
        if let latex { XCTAssertEqual(parseAndRender(text, .latex), latex, text, file: file, line: line) }
    }

    func testCorpusFormulasParseAndRender() throws {
        let categories: Set<String> = [
            // stage 3
            "modifier", "modifier-order", "subscript", "power", "root", "arithmetic", "relation", "fraction", "case",
            // stage 4
            "function", "probability", "bigop", "derivative", "binomial", "distribution", "grouping", "zh"
        ]
        let rows = try MathCorpusSupport.corpus().filter { $0.isMustChange && !$0.isPipelineScope && categories.contains($0.category) }
        var checked = 0
        for row in rows {
            guard let unicode = parseAndRender(row.input, .unicode) else { continue }
            checked += 1
            XCTAssertEqual(unicode, row.expectedUnicode, "\(row.id) \(row.input)")
            XCTAssertEqual(parseAndRender(row.input, .latex), row.expectedLatex, "\(row.id) \(row.input)")
        }
        // Rows whose whole input is one formula; the rest are sentences checked by MathStageCorpusTests.
        XCTAssertGreaterThan(checked, 380, "whole-row formulas checked")
    }

    func testSpokenFractionRule() {
        // design.md 5.5: every example of the table.
        assertParses("x bar minus mu over sigma", unicode: "(x̄ − μ)/σ", latex: #"$\frac{\bar{x} - \mu}{\sigma}$"#)
        assertParses("x bar 减 mu 除以 sigma", unicode: "(x̄ − μ)/σ")
        assertParses("one over n minus one", unicode: "1/(n − 1)", latex: #"$\frac{1}{n - 1}$"#)
        assertParses("one over n times the sum from i equals one to n of x sub i", unicode: "(1/n) ∑ᵢ₌₁ⁿ xᵢ")
        assertParses("z times sigma over root n", unicode: "z·σ/√n")
        assertParses("sigma squared over n plus tau squared over m", unicode: "σ²/n + τ²/m")
        assertParses("one plus r over n", unicode: "(1 + r)/n")
        assertParses("one plus the fraction r over n", unicode: "1 + r/n")
        assertParses("二分之一", unicode: "1/2")
        assertParses("n 分之一", unicode: "1/n")
        assertParses("x plus y all over two", unicode: "(x + y)/2")
    }

    func testModifierOrderDoesNotMatter() {
        for spoken in ["beta hat one", "beta one hat", "beta hat sub one", "beta sub one hat"] {
            assertParses(spoken, unicode: "β̂₁", latex: #"$\hat{\beta}_1$"#)
        }
        for spoken in ["x hat sub i", "x sub i hat"] {
            assertParses(spoken, unicode: "x̂ᵢ")
        }
        assertParses("x sub i squared", unicode: "xᵢ²")
    }

    func testOperatorsAndRelations() {
        assertParses("x squared plus y squared equals z squared", unicode: "x² + y² = z²", latex: "$x^2 + y^2 = z^2$")
        assertParses("two x plus three y equals seven", unicode: "2x + 3y = 7")
        assertParses("x times y", unicode: "x·y")
        assertParses("two times x", unicode: "2 × x")
        assertParses("x is greater than or equal to zero", unicode: "x ≥ 0")
        assertParses("x 大于等于零", unicode: "x ≥ 0")
        assertParses("zero less than x less than one", unicode: "0 < x < 1")
    }

    func testNoiseTolerance() {
        // P8: punctuation and hesitations where an operand is still needed.
        assertParses("x squared, plus y squared", unicode: "x² + y²")
        assertParses("x squared um plus y squared", unicode: "x² + y²")
        assertParses("SE. Beta hat.", unicode: "SE(β̂).")
    }

    func testCaseRules() {
        // D5: sentence-initial letters are lower case; capital forces upper case; subscript I is i.
        assertParses("X bar", unicode: "x̄")
        assertParses("capital X bar", unicode: "X̄")
        assertParses("x hat sub I", unicode: "x̂ᵢ")
        assertParses("variance of x", unicode: "Var(X)")
    }

    func testFunctionsDistributionsAndBigOperators() {
        assertParses("expected value of y given x", unicode: "E[Y | X]")
        assertParses("covariance of x and y", unicode: "Cov(X, Y)")
        assertParses("probability of A given B", unicode: "P(A | B)")
        assertParses("f prime of x", unicode: "f′(x)")
        assertParses("integral from zero to one of f of x dx", unicode: "∫₀¹ f(x) dx", latex: #"$\int_{0}^{1} f(x)\,dx$"#)
        assertParses("limit as n goes to infinity", unicode: "lim_{n→∞}")
        assertParses("partial f partial x", unicode: "∂f/∂x")
        assertParses("n choose k", unicode: "C(n, k)", latex: #"$\binom{n}{k}$"#)
        assertParses("X follows a normal distribution with mean mu and variance sigma squared", unicode: "X ∼ N(μ, σ²)")
        assertParses("t distribution with n minus one degrees of freedom", unicode: "tₙ₋₁")
        assertParses("the sum from i equals one to n of x sub i minus x bar all squared", unicode: "∑ᵢ₌₁ⁿ (xᵢ − x̄)²")
        assertParses("x 的期望等于 mu", unicode: "E[X] = μ")
        assertParses("在 B 的条件下 A 的概率", unicode: "P(A | B)")
    }

    func testLimitsGuardAgainstPathologicalInput() {
        // I9: deep nesting and long chains terminate.
        let nested = String(repeating: "the quantity ", count: 200) + "x"
        let stream = MathLexer.lex(nested)
        _ = MathSpanParser(stream).parseSpan(at: 0)
        let chain = String(repeating: "x plus ", count: 500) + "x"
        let parsed = MathSpanParser(MathLexer.lex(chain)).parseSpan(at: 0)
        XCTAssertNotNil(parsed)
        XCTAssertLessThanOrEqual(parsed?.next ?? 0, MathSpanParser.maxSpanTokens)
    }
}
