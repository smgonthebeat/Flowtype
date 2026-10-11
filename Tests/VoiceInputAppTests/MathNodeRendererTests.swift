import XCTest
@testable import VoiceInputApp

/// design.md section 7, one or more cases per row, both formats, on hand-built trees.
final class MathNodeRendererTests: XCTestCase {
    private typealias N = MathNode

    private func latin(_ c: Character, upper: Bool = false, _ configure: (MathAtom) -> Void = { _ in }) -> N {
        let atom = MathAtom(.latin(c), upper: upper)
        configure(atom)
        return .symbol(atom)
    }

    private func greek(_ name: String, _ configure: (MathAtom) -> Void = { _ in }) -> N {
        let atom = MathAtom(.greek(name))
        configure(atom)
        return .symbol(atom)
    }

    private func assertRenders(_ node: N, unicode: String, latex: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(MathNodeRenderer.unicode(node), unicode, file: file, line: line)
        XCTAssertEqual(MathNodeRenderer.latex(node), latex, file: file, line: line)
    }

    func testWholeSpanDelimiters() {
        // D1: LaTeX spans are wrapped in $...$; Unicode spans have no delimiters.
        XCTAssertEqual(MathStage.render(greek("theta"), .latex), #"$\theta$"#)
        XCTAssertEqual(MathStage.render(greek("theta"), .unicode), "θ")
    }

    func testGreekCaseAndVariant() {
        assertRenders(greek("theta"), unicode: "θ", latex: #"\theta"#)
        assertRenders(greek("sigma") { $0.isUpper = true }, unicode: "Σ", latex: #"\Sigma"#)
        assertRenders(greek("alpha") { $0.isUpper = true }, unicode: "A", latex: "A")
        assertRenders(greek("epsilon") { $0.isVariant = true }, unicode: "ϵ", latex: #"\varepsilon"#)
        assertRenders(greek("epsilon"), unicode: "ε", latex: #"\epsilon"#)
    }

    func testAccents() {
        assertRenders(latin("x") { $0.accents = [.hat] }, unicode: "x\u{0302}", latex: #"\hat{x}"#)
        assertRenders(latin("x") { $0.accents = [.bar] }, unicode: "x̄", latex: #"\bar{x}"#)
        assertRenders(latin("x") { $0.accents = [.tilde] }, unicode: "x̃", latex: #"\tilde{x}"#)
        assertRenders(latin("x") { $0.accents = [.dot] }, unicode: "ẋ", latex: #"\dot{x}"#)
        assertRenders(latin("x") { $0.accents = [.doubleDot] }, unicode: "ẍ", latex: #"\ddot{x}"#)
    }

    func testMarks() {
        assertRenders(latin("x") { $0.primes = 1 }, unicode: "x′", latex: "x'")
        assertRenders(latin("x") { $0.hasStar = true }, unicode: "x*", latex: "x^*")
        assertRenders(latin("X", upper: true) { $0.isTransposed = true }, unicode: "Xᵀ", latex: #"X^\top"#)
        assertRenders(latin("X", upper: true) { $0.isInverse = true }, unicode: "X⁻¹", latex: "X^{-1}")
    }

    func testScripts() {
        assertRenders(latin("x") { $0.subscriptNode = self.latin("i") }, unicode: "xᵢ", latex: "x_i")
        assertRenders(latin("x") { $0.subscriptNode = N(.index([self.latin("i"), self.latin("j")])) },
                      unicode: "xᵢⱼ", latex: "x_{ij}")
        assertRenders(latin("x") {
            $0.subscriptNode = self.latin("i")
            $0.superscriptNode = .number("2")
        }, unicode: "xᵢ²", latex: "x_i^2")
        assertRenders(greek("beta") {
            $0.accents = [.hat]
            $0.subscriptNode = .number("1")
        }, unicode: "β̂₁", latex: #"\hat{\beta}_1"#)
        // Fallback when a character has no script form (D3).
        assertRenders(latin("z") {
            $0.subscriptNode = N(.fraction(self.greek("alpha"), .number("2"), inline: true))
        }, unicode: "z_{α/2}", latex: #"z_{\alpha/2}"#)
        assertRenders(latin("e") { $0.superscriptNode = N(.negate(N(.juxtaposition([self.greek("lambda"), self.latin("t")])))) },
                      unicode: "e^{−λt}", latex: #"e^{-\lambda t}"#)
    }

    func testAdditionAndSubtraction() {
        assertRenders(N(.binary(.plus, latin("a"), latin("b"), tight: false)), unicode: "a + b", latex: "a + b")
        assertRenders(N(.binary(.minus, latin("a"), latin("b"), tight: false)), unicode: "a − b", latex: "a - b")
        assertRenders(N(.binary(.plusMinus, greek("mu"), greek("sigma"), tight: false)), unicode: "μ ± σ", latex: #"\mu \pm \sigma"#)
        // A subtracted sum is parenthesised.
        let inner = N(.binary(.plus, latin("b"), latin("c"), tight: false))
        assertRenders(N(.binary(.minus, latin("a"), inner, tight: false)), unicode: "a − (b + c)", latex: "a - (b + c)")
        assertRenders(latin("x") { $0.subscriptNode = N(.binary(.plus, self.latin("n"), .number("1"), tight: true)) },
                      unicode: "xₙ₊₁", latex: "x_{n+1}")
    }

    func testMultiplication() {
        let beta1 = greek("beta") { $0.subscriptNode = .number("1") }
        assertRenders(N(.juxtaposition([.number("2"), latin("x")])), unicode: "2x", latex: "2x")
        assertRenders(N(.juxtaposition([beta1, latin("x")])), unicode: "β₁x", latex: #"\beta_1 x"#)
        assertRenders(N(.product([.number("2"), latin("x")])), unicode: "2 × x", latex: #"2 \times x"#)
        assertRenders(N(.product([latin("x"), latin("y")])), unicode: "x·y", latex: #"x \cdot y"#)
        // A fraction that is not the last factor is parenthesised (D2).
        let sum = MathBigOperator(kind: .sum, variable: latin("i"), lower: .number("1"), upper: latin("n"),
                                  body: latin("x") { $0.subscriptNode = self.latin("i") }, differential: nil)
        assertRenders(N(.product([N(.fraction(.number("1"), latin("n"), inline: false)), N(.bigOperator(sum))])),
                      unicode: "(1/n) ∑ᵢ₌₁ⁿ xᵢ", latex: #"\frac{1}{n} \sum_{i=1}^{n} x_i"#)
    }

    func testFractions() {
        assertRenders(N(.fraction(latin("a"), latin("b"), inline: false)), unicode: "a/b", latex: #"\frac{a}{b}"#)
        let xbar = latin("x") { $0.accents = [.bar] }
        assertRenders(N(.fraction(N(.binary(.minus, xbar, greek("mu"), tight: false)), greek("sigma"), inline: false)),
                      unicode: "(x̄ − μ)/σ", latex: #"\frac{\bar{x} - \mu}{\sigma}"#)
        assertRenders(N(.fraction(.number("1"), N(.binary(.minus, latin("n"), .number("1"), tight: false)), inline: false)),
                      unicode: "1/(n − 1)", latex: #"\frac{1}{n - 1}"#)
        assertRenders(N(.fraction(greek("sigma"), N(.root(latin("n"), degree: 2)), inline: false)),
                      unicode: "σ/√n", latex: #"\frac{\sigma}{\sqrt{n}}"#)
    }

    func testRelations() {
        let cases: [(MathRelationOperator, String, String)] = [
            (.equal, "=", "="), (.notEqual, "≠", #"\neq"#), (.less, "<", "<"), (.greater, ">", ">"),
            (.lessEqual, "≤", #"\leq"#), (.greaterEqual, "≥", #"\geq"#), (.approximately, "≈", #"\approx"#),
            (.proportional, "∝", #"\propto"#), (.distributedAs, "∼", #"\sim"#), (.elementOf, "∈", #"\in"#),
            (.tendsTo, "→", #"\to"#), (.implies, "⇒", #"\Rightarrow"#),
            (.convergesInDistribution, "→ᵈ", #"\xrightarrow{d}"#), (.convergesInProbability, "→ᵖ", #"\xrightarrow{p}"#)
        ]
        for (op, u, l) in cases {
            let node = N(.relation(latin("x"), [MathRelationLink(op: op, strength: 2, rhs: latin("y"))]))
            assertRenders(node, unicode: "x \(u) y", latex: "x \(l) y")
        }
        let chain = N(.relation(.number("0"), [
            MathRelationLink(op: .less, strength: 1, rhs: latin("x")), MathRelationLink(op: .less, strength: 1, rhs: .number("1"))
        ]))
        assertRenders(chain, unicode: "0 < x < 1", latex: "0 < x < 1")
    }

    func testFunctions() {
        let x = latin("X", upper: true)
        assertRenders(N(.function(.named(.expectation), args: [x], given: nil)), unicode: "E[X]", latex: #"\mathbb{E}[X]"#)
        assertRenders(N(.function(.named(.variance), args: [x], given: nil)), unicode: "Var(X)", latex: #"\operatorname{Var}(X)"#)
        assertRenders(N(.function(.named(.covariance), args: [x, latin("Y", upper: true)], given: nil)),
                      unicode: "Cov(X, Y)", latex: #"\operatorname{Cov}(X, Y)"#)
        assertRenders(N(.function(.named(.probability), args: [latin("A", upper: true)], given: latin("B", upper: true))),
                      unicode: "P(A | B)", latex: #"P(A \mid B)"#)
        assertRenders(N(.function(.named(.log), args: [latin("x")], given: nil)), unicode: "log(x)", latex: #"\log(x)"#)
        assertRenders(N(.function(.named(.sin), args: [greek("theta")], given: nil)), unicode: "sin(θ)", latex: #"\sin(\theta)"#)
        assertRenders(N(.function(.generic(latin("f")), args: [latin("x"), latin("y")], given: nil)),
                      unicode: "f(x, y)", latex: "f(x, y)")
    }

    func testRootsAbsoluteFactorialBinomial() {
        assertRenders(N(.root(latin("n"), degree: 2)), unicode: "√n", latex: #"\sqrt{n}"#)
        assertRenders(N(.root(N(.binary(.minus, latin("n"), .number("1"), tight: false)), degree: 2)),
                      unicode: "√(n − 1)", latex: #"\sqrt{n - 1}"#)
        assertRenders(N(.root(latin("x"), degree: 3)), unicode: "∛x", latex: #"\sqrt[3]{x}"#)
        assertRenders(N(.absolute(latin("x"), norm: false)), unicode: "|x|", latex: "|x|")
        assertRenders(N(.factorial(latin("n"))), unicode: "n!", latex: "n!")
        assertRenders(N(.binomial(latin("n"), latin("k"))), unicode: "C(n, k)", latex: #"\binom{n}{k}"#)
    }

    func testBigOperators() {
        let xi = { self.latin("x") { $0.subscriptNode = self.latin("i") } }
        let sum = MathBigOperator(kind: .sum, variable: latin("i"), lower: .number("1"), upper: latin("n"), body: xi(), differential: nil)
        assertRenders(N(.bigOperator(sum)), unicode: "∑ᵢ₌₁ⁿ xᵢ", latex: #"\sum_{i=1}^{n} x_i"#)
        let infinite = MathBigOperator(kind: .sum, variable: latin("i"), lower: .number("1"), upper: .number("inf"), body: xi(), differential: nil)
        assertRenders(N(.bigOperator(infinite)), unicode: "∑_{i=1}^{∞} xᵢ", latex: #"\sum_{i=1}^{\infty} x_i"#)
        let fx = N(.function(.generic(latin("f")), args: [latin("x")], given: nil))
        let integral = MathBigOperator(kind: .integral, variable: nil, lower: .number("0"), upper: .number("1"), body: fx, differential: latin("x"))
        assertRenders(N(.bigOperator(integral)), unicode: "∫₀¹ f(x) dx", latex: #"\int_{0}^{1} f(x)\,dx"#)
        let limit = MathBigOperator(kind: .limit, variable: latin("n"), lower: nil, upper: .number("inf"), body: nil, differential: nil)
        assertRenders(N(.bigOperator(limit)), unicode: "lim_{n→∞}", latex: #"\lim_{n \to \infty}"#)
    }

    func testDerivatives() {
        assertRenders(N(.derivative(partial: false, of: latin("y"), by: latin("x"))), unicode: "dy/dx", latex: #"\frac{dy}{dx}"#)
        assertRenders(N(.derivative(partial: true, of: latin("f"), by: latin("x"))), unicode: "∂f/∂x", latex: #"\frac{\partial f}{\partial x}"#)
    }

    func testDistributions() {
        let T = MathLexiconTables.distributions
        let sigma2 = greek("sigma") { $0.superscriptNode = .number("2") }
        assertRenders(N(.distribution(T["normal"]!, params: [greek("mu"), sigma2], iid: false)),
                      unicode: "N(μ, σ²)", latex: #"N(\mu, \sigma^2)"#)
        assertRenders(N(.distribution(T["binomial"]!, params: [latin("n"), latin("p")], iid: false)),
                      unicode: "Bin(n, p)", latex: #"\operatorname{Bin}(n, p)"#)
        assertRenders(N(.distribution(T["poisson"]!, params: [greek("lambda")], iid: false)),
                      unicode: "Pois(λ)", latex: #"\operatorname{Pois}(\lambda)"#)
        assertRenders(N(.distribution(T["t"]!, params: [N(.binary(.minus, latin("n"), .number("1"), tight: true))], iid: false)),
                      unicode: "tₙ₋₁", latex: "t_{n-1}")
        assertRenders(N(.distribution(T["chi squared"]!, params: [latin("k")], iid: false)), unicode: "χ²ₖ", latex: #"\chi^2_k"#)
        assertRenders(N(.distribution(T["f"]!, params: [latin("m"), latin("n")], iid: false)), unicode: "F_{m,n}", latex: "F_{m, n}")
    }

    func testAutomaticParentheses() {
        let sum = N(.binary(.plus, latin("x"), latin("y"), tight: false))
        assertRenders(N(.product([sum, latin("z")])), unicode: "(x + y)·z", latex: #"(x + y) \cdot z"#)
        assertRenders(N(.power(N(.group(sum)), .number("2"))), unicode: "(x + y)²", latex: "(x + y)^2")
        assertRenders(N(.negate(sum)), unicode: "−(x + y)", latex: "-(x + y)")
    }
}
