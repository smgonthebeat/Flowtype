import XCTest
@testable import VoiceInputApp

final class MathRendererTests: XCTestCase {
    func testRendersSymbols() {
        let expression = MathExpression.symbol(MathSymbolAtom(spoken: "alpha", latex: #"\alpha"#, unicode: "α"))

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "α")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), #"\alpha"#)
    }

    func testRendersAllModifiedSymbols() {
        let cases: [(modifier: MathModifier, unicode: String, latex: String)] = [
            (.hat, "X\u{0302}", #"\hat{X}"#),
            (.bar, "X\u{0304}", #"\bar{X}"#),
            (.tilde, "X\u{0303}", #"\tilde{X}"#),
            (.dot, "X\u{0307}", #"\dot{X}"#),
            (.doubleDot, "X\u{0308}", #"\ddot{X}"#),
            (.prime, "X′", "X'"),
            (.doublePrime, "X″", "X''"),
            (.star, "X*", "X^*"),
            (.transpose, "Xᵀ", #"X^\top"#),
            (.inverse, "X⁻¹", "X^{-1}"),
            (.squared, "X²", "X^2"),
            (.cubed, "X³", "X^3")
        ]

        for testCase in cases {
            let expression = MathExpression.modified(
                base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
                modifier: testCase.modifier
            )

            XCTAssertEqual(
                MathRenderer.render(expression, outputFormat: .unicode),
                testCase.unicode,
                "Unexpected unicode rendering for \(testCase.modifier)"
            )
            XCTAssertEqual(
                MathRenderer.render(expression, outputFormat: .latex),
                testCase.latex,
                "Unexpected LaTeX rendering for \(testCase.modifier)"
            )
        }
    }

    func testIdentifiesValidModifiedBases() {
        let symbol = MathExpression.symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X"))
        let nestedModified = MathExpression.modified(
            base: .modified(base: symbol, modifier: .hat),
            modifier: .bar
        )

        XCTAssertTrue(symbol.isAtomLikeModifiedBase)
        XCTAssertTrue(nestedModified.isAtomLikeModifiedBase)
    }

    func testIdentifiesInvalidModifiedBases() {
        let symbol = MathExpression.symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X"))
        let index = MathExpression.symbol(MathSymbolAtom(spoken: "i", latex: "i", unicode: "i"))
        let exponent = MathExpression.symbol(MathSymbolAtom(spoken: "two", latex: "2", unicode: "2"))
        let subscripted = MathExpression.subscripted(base: symbol, index: index)
        let powered = MathExpression.powered(base: symbol, exponent: exponent)
        let function = MathExpression.function(name: .variance, arguments: [symbol])

        XCTAssertFalse(subscripted.isAtomLikeModifiedBase)
        XCTAssertFalse(powered.isAtomLikeModifiedBase)
        XCTAssertFalse(function.isAtomLikeModifiedBase)
    }

    func testRendersSubscriptedSymbol() {
        let expression = MathExpression.subscripted(
            base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
            index: .symbol(MathSymbolAtom(spoken: "i", latex: "i", unicode: "i"))
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "Xᵢ")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), "X_i")
    }

    func testRendersTimeSubscriptWithUnicodeGlyph() {
        let expression = MathExpression.subscripted(
            base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
            index: .symbol(MathSymbolAtom(spoken: "t", latex: "t", unicode: "t"))
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "Xₜ")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), "X_t")
    }

    func testRendersLatexSubscriptsWithBracesForMultiCharacterIndices() {
        let expression = MathExpression.subscripted(
            base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
            index: .symbol(MathSymbolAtom(spoken: "i j", latex: "ij", unicode: "ij"))
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "Xᵢⱼ")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), "X_{ij}")
    }

    func testRendersUnicodeSubscriptsWithAsciiFallbackForUnsupportedIndices() {
        let singleCharacterIndex = MathExpression.subscripted(
            base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
            index: .symbol(MathSymbolAtom(spoken: "m", latex: "m", unicode: "m"))
        )
        let multiCharacterIndex = MathExpression.subscripted(
            base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
            index: .symbol(MathSymbolAtom(spoken: "beta", latex: "beta", unicode: "beta"))
        )

        XCTAssertEqual(MathRenderer.render(singleCharacterIndex, outputFormat: .unicode), "Xₘ")
        XCTAssertEqual(MathRenderer.render(multiCharacterIndex, outputFormat: .unicode), "X_{beta}")
    }

    func testRendersLatexNestedSubscriptsWithBracedBase() {
        let expression = MathExpression.subscripted(
            base: .subscripted(
                base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
                index: .symbol(MathSymbolAtom(spoken: "i", latex: "i", unicode: "i"))
            ),
            index: .symbol(MathSymbolAtom(spoken: "j", latex: "j", unicode: "j"))
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "Xᵢⱼ")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), "{X_i}_j")
    }

    func testRendersPoweredSymbol() {
        let expression = MathExpression.powered(
            base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
            exponent: .symbol(MathSymbolAtom(spoken: "two", latex: "2", unicode: "2"))
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "X²")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), "X^2")
    }

    func testRendersLatexPowersWithBracesForMultiCharacterExponents() {
        let expression = MathExpression.powered(
            base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
            exponent: .symbol(MathSymbolAtom(spoken: "ten", latex: "10", unicode: "10"))
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "X¹⁰")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), "X^{10}")
    }

    func testRendersUnicodePowersWithAsciiFallbackForUnsupportedExponents() {
        let singleCharacterExponent = MathExpression.powered(
            base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
            exponent: .symbol(MathSymbolAtom(spoken: "j", latex: "j", unicode: "j"))
        )
        let multiCharacterExponent = MathExpression.powered(
            base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
            exponent: .symbol(MathSymbolAtom(spoken: "beta", latex: "beta", unicode: "beta"))
        )

        XCTAssertEqual(MathRenderer.render(singleCharacterExponent, outputFormat: .unicode), "X^j")
        XCTAssertEqual(MathRenderer.render(multiCharacterExponent, outputFormat: .unicode), "X^{beta}")
    }

    func testRendersLatexNestedPowersWithBracedBase() {
        let expression = MathExpression.powered(
            base: .powered(
                base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
                exponent: .symbol(MathSymbolAtom(spoken: "two", latex: "2", unicode: "2"))
            ),
            exponent: .symbol(MathSymbolAtom(spoken: "three", latex: "3", unicode: "3"))
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "X²³")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), "{X^2}^3")
    }

    func testRendersSubscriptedThenPoweredSymbol() {
        let expression = MathExpression.powered(
            base: .subscripted(
                base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
                index: .symbol(MathSymbolAtom(spoken: "i", latex: "i", unicode: "i"))
            ),
            exponent: .symbol(MathSymbolAtom(spoken: "two", latex: "2", unicode: "2"))
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "Xᵢ²")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), "X_i^2")
    }

    func testRendersSubscriptedModifiedBetaHat() {
        let expression = MathExpression.subscripted(
            base: .modified(
                base: .symbol(MathSymbolAtom(spoken: "beta", latex: #"\beta"#, unicode: "β")),
                modifier: .hat
            ),
            index: .symbol(MathSymbolAtom(spoken: "one", latex: "1", unicode: "1"))
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "β\u{0302}₁")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), #"\hat{\beta}_1"#)
    }

    func testRendersUnaryStatisticsFunction() {
        let expression = MathExpression.function(
            name: .variance,
            arguments: [
                .modified(
                    base: .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
                    modifier: .bar
                )
            ]
        )

        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), "Var(X̄)")
        XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), #"\mathrm{Var}(\bar{X})"#)
    }

    func testRendersAdditionalUnaryStatisticsFunctions() {
        let argument = MathExpression.symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X"))
        let cases: [(name: MathFunctionName, unicode: String, latex: String)] = [
            (.expectation, "E[X]", "E[X]"),
            (.standardDeviation, "SD(X)", #"\mathrm{SD}(X)"#),
            (.standardError, "SE(X)", #"\mathrm{SE}(X)"#)
        ]

        for testCase in cases {
            let expression = MathExpression.function(name: testCase.name, arguments: [argument])
            XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), testCase.unicode)
            XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), testCase.latex)
        }
    }

    func testRendersBinaryStatisticsFunctions() {
        let cases: [(name: MathFunctionName, unicode: String, latex: String)] = [
            (.covariance, "Cov(X,Y)", #"\mathrm{Cov}(X,Y)"#),
            (.correlation, "Corr(X,Y)", #"\mathrm{Corr}(X,Y)"#)
        ]

        for testCase in cases {
            let expression = MathExpression.function(
                name: testCase.name,
                arguments: [
                    .symbol(MathSymbolAtom(spoken: "X", latex: "X", unicode: "X")),
                    .symbol(MathSymbolAtom(spoken: "Y", latex: "Y", unicode: "Y"))
                ]
            )

            XCTAssertEqual(MathRenderer.render(expression, outputFormat: .unicode), testCase.unicode)
            XCTAssertEqual(MathRenderer.render(expression, outputFormat: .latex), testCase.latex)
        }
    }
}
