import XCTest
@testable import VoiceInputApp

final class MathSpeechParserTests: XCTestCase {
    func testParsesLatinStatisticsArgumentsAsUppercaseSymbols() {
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x"),
            .symbol(MathSymbolAtom(spoken: "x", latex: "X", unicode: "X"))
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("e"),
            .symbol(MathSymbolAtom(spoken: "e", latex: "E", unicode: "E"))
        )
    }

    func testParsesUnicodeGreekStatisticsArgumentsAsLowercaseSymbols() {
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("θ"),
            .symbol(MathSymbolAtom(spoken: "theta", latex: #"\theta"#, unicode: "θ"))
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("β"),
            .symbol(MathSymbolAtom(spoken: "beta", latex: #"\beta"#, unicode: "β"))
        )
    }

    func testParsesBetaAliasesAsCanonicalStatisticsArgument() {
        let beta = MathSymbolAtom(spoken: "beta", latex: #"\beta"#, unicode: "β")

        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("bita"),
            .symbol(beta)
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("β"),
            .symbol(beta)
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression(#"\beta"#),
            .symbol(beta)
        )
    }

    func testRecoversBetaHatASRNearMissesInStatisticsArguments() {
        let beta = MathSymbolAtom(spoken: "beta", latex: #"\beta"#, unicode: "β")

        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("better head"),
            .modified(base: .symbol(beta), modifier: .hat)
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("bad hat"),
            .modified(base: .symbol(beta), modifier: .hat)
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "SE better head", outputFormat: .unicode),
            "SE(β̂)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "standard error bad head", outputFormat: .latex),
            #"\mathrm{SE}(\hat{\beta})"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "standard arrow better hat", outputFormat: .unicode),
            "SE(β̂)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "standard arrow beta head", outputFormat: .latex),
            #"\mathrm{SE}(\hat{\beta})"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: #"if I say "SE," better head again"#, outputFormat: .unicode),
            "if I say SE(β̂) again"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "standard error, bad head", outputFormat: .unicode),
            "SE(β̂)"
        )
    }

    func testParsesCapitalLetterArguments() {
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("capital x"),
            .symbol(MathSymbolAtom(spoken: "capital x", latex: "X", unicode: "X"))
        )
    }

    func testParsesFullGreekCatalogForStatisticsArguments() {
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("rho"),
            .symbol(MathSymbolAtom(spoken: "rho", latex: #"\rho"#, unicode: "ρ"))
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("omega"),
            .symbol(MathSymbolAtom(spoken: "omega", latex: #"\omega"#, unicode: "ω"))
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("varphi"),
            .symbol(MathSymbolAtom(spoken: "varphi", latex: #"\varphi"#, unicode: "ϕ"))
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("capital omega"),
            .symbol(MathSymbolAtom(spoken: "capital omega", latex: #"\Omega"#, unicode: "Ω"))
        )
    }

    func testParsesModifiedArguments() {
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x bar"),
            .modified(
                base: .symbol(MathSymbolAtom(spoken: "x", latex: "X", unicode: "X")),
                modifier: .bar
            )
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("beta hat"),
            .modified(
                base: .symbol(MathSymbolAtom(spoken: "beta", latex: #"\beta"#, unicode: "β")),
                modifier: .hat
            )
        )
    }

    func testParsesOrderSensitiveModifierSuffixes() {
        let x = MathSymbolAtom(spoken: "x", latex: "X", unicode: "X")

        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x double prime"),
            .modified(base: .symbol(x), modifier: .doublePrime)
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x prime"),
            .modified(base: .symbol(x), modifier: .prime)
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x double dot"),
            .modified(base: .symbol(x), modifier: .doubleDot)
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x dot"),
            .modified(base: .symbol(x), modifier: .dot)
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x square"),
            .powered(
                base: .symbol(x),
                exponent: .symbol(MathSymbolAtom(spoken: "two", latex: "2", unicode: "2"))
            )
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x squared"),
            .powered(
                base: .symbol(x),
                exponent: .symbol(MathSymbolAtom(spoken: "two", latex: "2", unicode: "2"))
            )
        )
    }

    func testNormalizesASRCaseAndWhitespaceForModifiedArguments() {
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("  X   DOUBLE   PRIME  "),
            .modified(
                base: .symbol(MathSymbolAtom(spoken: "x", latex: "X", unicode: "X")),
                modifier: .doublePrime
            )
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("Beta   Hat"),
            .modified(
                base: .symbol(MathSymbolAtom(spoken: "beta", latex: #"\beta"#, unicode: "β")),
                modifier: .hat
            )
        )
    }

    func testParsesSubscriptAndPowerStatisticsArguments() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance x sub i", outputFormat: .unicode),
            "Var(Xᵢ)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance x sub i", outputFormat: .latex),
            #"\mathrm{Var}(X_i)"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance x sub i squared", outputFormat: .unicode),
            "Var(Xᵢ²)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance beta hat sub one", outputFormat: .latex),
            #"\mathrm{Var}(\hat{\beta}_1)"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance beta hat sub one", outputFormat: .unicode),
            "Var(β̂₁)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance x sub t", outputFormat: .unicode),
            "Var(Xₜ)"
        )
    }

    func testModifierAfterSubscriptAppliesToBaseSymbol() {
        let x = MathSymbolAtom(spoken: "x", latex: "X", unicode: "X")
        let i = MathSymbolAtom(spoken: "i", latex: "i", unicode: "i")
        let beta = MathSymbolAtom(spoken: "beta", latex: #"\beta"#, unicode: "β")
        let j = MathSymbolAtom(spoken: "j", latex: "j", unicode: "j")

        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x sub i hat"),
            .subscripted(
                base: .modified(base: .symbol(x), modifier: .hat),
                index: .symbol(i)
            )
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("x sub i head"),
            .subscripted(
                base: .modified(base: .symbol(x), modifier: .hat),
                index: .symbol(i)
            )
        )
        XCTAssertEqual(
            MathSpeechParser.parseArgumentExpression("beta sub j hat"),
            .subscripted(
                base: .modified(base: .symbol(beta), modifier: .hat),
                index: .symbol(j)
            )
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance x sub i hat", outputFormat: .unicode),
            "Var(X̂ᵢ)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance beta sub j hat", outputFormat: .latex),
            #"\mathrm{Var}(\hat{\beta}_j)"#
        )

        XCTAssertNil(MathSpeechParser.parseArgumentExpression("x squared hat"))
        XCTAssertNil(MathSpeechParser.parseArgumentExpression("x sub i bar"))

        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance x squared hat", outputFormat: .unicode),
            "Var(X²) hat"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance x sub i bar", outputFormat: .unicode),
            "Var(Xᵢ) bar"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance x sub i hat squared", outputFormat: .unicode),
            "Var(X̂ᵢ) squared"
        )
    }

    func testReplacesUnaryVarianceSpeech() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance e", outputFormat: .unicode),
            "Var(E)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "var y", outputFormat: .unicode),
            "Var(Y)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "Variants of Y.", outputFormat: .unicode),
            "Var(Y)."
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance of x bar", outputFormat: .latex),
            #"\mathrm{Var}(\bar{X})"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance θ", outputFormat: .unicode),
            "Var(θ)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance θ", outputFormat: .latex),
            #"\mathrm{Var}(\theta)"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "variance β", outputFormat: .unicode),
            "Var(β)"
        )
    }

    func testReplacesAdditionalUnaryStatisticsSpeech() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "expectation x", outputFormat: .unicode),
            "E[X]"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "E of X", outputFormat: .unicode),
            "E[X]"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "expected value of y bar", outputFormat: .latex),
            #"E[\bar{Y}]"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "standard deviation theta", outputFormat: .unicode),
            "SD(θ)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "standard error beta hat", outputFormat: .latex),
            #"\mathrm{SE}(\hat{\beta})"#
        )
    }

    func testReplacesAsrSpacedAndCompactedStandardDeviationSpeech() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "S D X̄", outputFormat: .unicode),
            "SD(X̄)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "S D Yᵢ", outputFormat: .unicode),
            "SD(Yᵢ)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "SDX bar", outputFormat: .unicode),
            "SD(X̄)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "SDY sub I", outputFormat: .unicode),
            "SD(Yᵢ)"
        )
    }

    func testDoesNotTreatPlainEnglishFunctionWordsAsMath() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "standard error message", outputFormat: .unicode),
            "standard error message"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "standard arrow message", outputFormat: .unicode),
            "standard arrow message"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "expectation is that x will rise", outputFormat: .unicode),
            "expectation is that x will rise"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "we expected y yesterday", outputFormat: .unicode),
            "we expected y yesterday"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "the expected x will rise", outputFormat: .unicode),
            "the expected x will rise"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "press e x to exit", outputFormat: .unicode),
            "press e x to exit"
        )
    }

    func testPhaseTwoParserKeepsCodeLikeContextsUnchanged() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "write standard error beta hat in Swift", outputFormat: .unicode),
            "write standard error beta hat in Swift"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "let expectation x = value", outputFormat: .unicode),
            "let expectation x = value"
        )
    }

    func testReplacesBinaryCorrelationAndCovarianceSpeech() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "correlation xy", outputFormat: .unicode),
            "Corr(X,Y)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "cor x y", outputFormat: .unicode),
            "Corr(X,Y)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "correlation yz", outputFormat: .unicode),
            "Corr(Y,Z)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "corr y z", outputFormat: .latex),
            #"\mathrm{Corr}(Y,Z)"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "covariance of x y", outputFormat: .unicode),
            "Cov(X,Y)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "cov x comma y", outputFormat: .unicode),
            "Cov(X,Y)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "cov x, comma y", outputFormat: .unicode),
            "Cov(X,Y)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "correlation x y in the sample", outputFormat: .unicode),
            "Corr(X,Y) in the sample"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "corr θ β", outputFormat: .unicode),
            "Corr(θ,β)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "corr θ β", outputFormat: .latex),
            #"\mathrm{Corr}(\theta,\beta)"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "Cor Better Hat γ̄", outputFormat: .unicode),
            "Corr(β̂,γ̄)"
        )
    }

    func testDoesNotTreatCodeLikeBinaryStatisticsAsMath() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "write corr y z in Swift", outputFormat: .unicode),
            "write corr y z in Swift"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "let corr y z in code", outputFormat: .unicode),
            "let corr y z in code"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "correlation is", outputFormat: .unicode),
            "correlation is"
        )
    }

    func testMovesModifierInsideExistingVarianceNotation() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "Var(X) bar", outputFormat: .unicode),
            "Var(X̄)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "Var(X) bar", outputFormat: .latex),
            #"\mathrm{Var}(\bar{X})"#
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "Var(X) bar.", outputFormat: .unicode),
            "Var(X̄)."
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "Var(X) bar and Var(Y) hat", outputFormat: .unicode),
            "Var(X̄) and Var(Ŷ)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "VAR(X) bar", outputFormat: .unicode),
            "Var(X̄)"
        )
    }

    func testDoesNotTreatCodeLikeVarAsVariance() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "var x = 1", outputFormat: .unicode),
            "var x = 1"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "Use `let var x y` in Swift", outputFormat: .unicode),
            "Use `let var x y` in Swift"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "declare var x.", outputFormat: .unicode),
            "declare var x."
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "use var x.", outputFormat: .unicode),
            "use var x."
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "var(x) bar", outputFormat: .unicode),
            "var(x) bar"
        )
    }
}
