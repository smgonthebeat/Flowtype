import XCTest
@testable import VoiceInputApp

final class MathNotationFormatterTests: XCTestCase {
    func testFormatsLatexNotation() {
        XCTAssertEqual(
            MathNotationFormatter.format("theta hat equals x bar and sigma squared", outputFormat: .latex),
            #"\hat{\theta} equals \bar{x} and \sigma^2"#
        )
    }

    func testFormatsUnicodeNotation() {
        XCTAssertEqual(
            MathNotationFormatter.format("theta hat equals x bar and sigma squared", outputFormat: .unicode),
            "θ̂ equals x̄ and σ²"
        )
    }

    func testFormatsLikelihoodExpressions() {
        XCTAssertEqual(
            MathNotationFormatter.format("capital L of theta and ell of theta", outputFormat: .latex),
            #"L(\theta) and \ell(\theta)"#
        )
    }

    func testFormatsSquareAlias() {
        XCTAssertEqual(
            MathNotationFormatter.format("sigma square and chi square", outputFormat: .latex),
            #"\sigma^2 and \chi^2"#
        )
    }

    func testDoesNotSquareTrailingLettersInsideWords() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "mean square equals SS over df, mean square error, x square, theta square",
                outputFormat: .unicode
            ),
            "mean square equals SS over df, mean square error, x², θ²"
        )
    }

    func testNormalizesExistingUnicodeToLatex() {
        XCTAssertEqual(
            MathNotationFormatter.format("θ̂, α β σ square", outputFormat: .latex),
            #"\hat{\theta}, \alpha \beta \sigma^2"#
        )
    }

    func testNormalizesExistingLatexToUnicode() {
        XCTAssertEqual(
            MathNotationFormatter.format(#"\hat{\theta}, \alpha \beta \sigma^2"#, outputFormat: .unicode),
            "θ̂, α β σ²"
        )
    }

    func testGenericTemplateRulesLatex() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "alpha hat, mu bar, epsilon tilde, x prime, x double prime, A transpose, A inverse, y cubed",
                outputFormat: .latex
            ),
            #"\hat{\alpha}, \bar{\mu}, \tilde{\epsilon}, x', x'', A^\top, A^{-1}, y^3"#
        )
    }

    func testGenericTemplateRulesUnicode() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "alpha head, mu bar, epsilon tilde, x prime, x double prime, A transpose, A inverse, y cubed",
                outputFormat: .unicode
            ),
            "α̂, μ̄, ε̃, x′, x″, Aᵀ, A⁻¹, y³"
        )
    }

    func testSubscriptTemplates() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "beta sub zero, theta sub n, x sub i, y i t, r t minus one, p t plus one",
                outputFormat: .latex
            ),
            #"\beta_0, \theta_n, x_i, y_{it}, r_{t-1}, p_{t+1}"#
        )
    }

    func testCompletesGreekCatalog() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "zeta eta iota kappa nu xi upsilon psi omega, capital gamma, big omega, curly epsilon, variant theta, final sigma, varphi",
                outputFormat: .latex
            ),
            #"\zeta \eta \iota \kappa \nu \xi \upsilon \psi \omega, \Gamma, \Omega, \varepsilon, \vartheta, \varsigma, \varphi"#
        )
    }

    func testDoesNotRewriteParserOnlyGreekAliases() {
        XCTAssertEqual(
            MathNotationFormatter.format("bita and mew stay plain, beta and mu convert", outputFormat: .unicode),
            "bita and mew stay plain, β and μ convert"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("bita and mew stay plain, beta and mu convert", outputFormat: .latex),
            #"bita and mew stay plain, \beta and \mu convert"#
        )
    }

    func testAddsStatisticsRegressionAndFinancePhrases() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "standard error, h zero, h one, h a, r squared, adjusted r squared, ordinary least squares, fixed effects, difference in differences, two stage least squares, risk free rate, market return, cap m, net present value, sharpe ratio, weighted average cost of capital",
                outputFormat: .latex
            ),
            #"\mathrm{SE}, H_0, H_1, H_a, R^2, \bar{R}^2, \mathrm{OLS}, \mathrm{FE}, \mathrm{DiD}, \mathrm{2SLS}, r_f, R_m, \mathrm{CAPM}, NPV, \mathrm{Sharpe}, WACC"#
        )
    }

    func testFormatsPhaseTwoStatisticsExpressionsThroughPublicFormatter() {
        XCTAssertEqual(
            MathNotationFormatter.format("variance omega bar and expectation x", outputFormat: .unicode),
            "Var(ω̄) and E[X]"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard error beta hat and variance x sub i", outputFormat: .latex),
            #"\mathrm{SE}(\hat{\beta}) and \mathrm{Var}(X_i)"#
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard error better head and SE bad hat", outputFormat: .unicode),
            "SE(β̂) and SE(β̂)"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard arrow better hat", outputFormat: .unicode),
            "SE(β̂)"
        )
        XCTAssertEqual(
            MathNotationFormatter.format(#"if I say "SE," better head again"#, outputFormat: .unicode),
            "if I say SE(β̂) again"
        )
    }

    func testFormatsStandaloneSubscriptThenHat() {
        XCTAssertEqual(
            MathNotationFormatter.format("x sub i hat", outputFormat: .unicode),
            "X̂ᵢ"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("x sub i head", outputFormat: .unicode),
            "X̂ᵢ"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("beta sub j hat", outputFormat: .latex),
            #"\hat{\beta}_j"#
        )
    }

    func testPhaseTwoParserAvoidsProtectedAndPlainEnglishFalsePositives() {
        XCTAssertEqual(
            MathNotationFormatter.format("open qwen/omega-alpha and expectation x", outputFormat: .unicode),
            "open qwen/omega-alpha and E[X]"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("Use `standard error beta hat` then standard error beta hat", outputFormat: .unicode),
            "Use `standard error beta hat` then SE(β̂)"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard error message and expectation is that x will rise", outputFormat: .unicode),
            "standard error message and expectation is that x will rise"
        )
    }

    func testDoesNotRewritePlainEnglishStandardErrorMessages() {
        XCTAssertEqual(
            MathNotationFormatter.format("standard error message", outputFormat: .unicode),
            "standard error message"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard arrow message", outputFormat: .unicode),
            "standard arrow message"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard error message", outputFormat: .latex),
            "standard error message"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard error of message", outputFormat: .unicode),
            "standard error of message"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard error of message", outputFormat: .latex),
            "standard error of message"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard error of log", outputFormat: .unicode),
            "standard error of log"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("standard error of log", outputFormat: .latex),
            "standard error of log"
        )
    }

    func testDoesNotRewritePlainEnglishExpectedSentences() {
        XCTAssertEqual(
            MathNotationFormatter.format("we expected y yesterday", outputFormat: .unicode),
            "we expected y yesterday"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("we expected y yesterday", outputFormat: .latex),
            "we expected y yesterday"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("the expected x will rise", outputFormat: .unicode),
            "the expected x will rise"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("the expected x will rise", outputFormat: .latex),
            "the expected x will rise"
        )
    }

    func testDoesNotApplySymbolModifiersInsidePlainEnglishWords() {
        XCTAssertEqual(
            MathNotationFormatter.format("this is a bad hat, not beta hat", outputFormat: .unicode),
            "this is a bad hat, not β̂"
        )
    }

    func testAddsDistributionPhrases() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "normal distribution, standard normal, x follows normal, binomial n p, poisson lambda, chi squared k, iid",
                outputFormat: .latex
            ),
            #"N(\mu,\sigma^2), N(0,1), X \sim N(\mu,\sigma^2), \mathrm{Bin}(n,p), \mathrm{Poisson}(\lambda), \chi^2_k, \mathrm{i.i.d.}"#
        )
    }

    func testFormatsAsrCasedTemplateSuffixes() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "θ Hat, β Hat, γ Hat, δ Hat, α Bar, θ Bar, X Bar, Capital X Bar",
                outputFormat: .unicode
            ),
            "θ̂, β̂, γ̂, δ̂, ᾱ, θ̄, X̄, X̄"
        )
    }

    func testFormatsGenericCompactASRTokens() {
        XCTAssertEqual(MathNotationFormatter.format("Nsubj", outputFormat: .unicode), "Nⱼ")
        XCTAssertEqual(MathNotationFormatter.format("Xsub10", outputFormat: .unicode), "X₁₀")
        XCTAssertEqual(MathNotationFormatter.format("NsubiNsubj", outputFormat: .unicode), "NᵢNⱼ")
        XCTAssertEqual(MathNotationFormatter.format("Xbar", outputFormat: .unicode), "X̄")
    }

    func testFormatsAsrTemplateAliases() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "theta head, beta head, bita, betasquared, gammasquared, capital x squared",
                outputFormat: .latex
            ),
            #"\hat{\theta}, \hat{\beta}, bita, \beta^2, \gamma^2, X^2"#
        )
    }

    func testFormatsAsrVarianceAndDistributionAliases() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "Variant of x, Variants of X, T distribution with new degrees of freedom",
                outputFormat: .unicode
            ),
            "Var(X), Var(X), t_ν"
        )
    }

    func testFormatsAsrSubscriptRangesAndCompactedSubscripts() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "x sub zero to nine, x sub 0 to 9, X0 to X9, YIT, XIT, RT minus 1, PT plus 1, XIXJXK",
                outputFormat: .unicode
            ),
            "x₀ to x₉, x₀ to x₉, X₀ to X₉, yᵢₜ, xᵢₜ, rₜ₋₁, pₜ₊₁, xᵢ xⱼ xₖ"
        )
    }

    func testFormatsAsrMathPronunciationAliases() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "kai squared, kai square k, 开 squared, 开 squid, 开 squared k, correlation of XY, Correlation of x, y, corr of x, y, corr of xy, Covariance of x, y, cov of X, Y, mew plus or minus sigma, Mul ± σ, Mil ± σ",
                outputFormat: .unicode
            ),
            "χ², χ²_k, χ², χ², χ²_k, Corr(X,Y), Corr(X,Y), Corr(X,Y), Corr(X,Y), Cov(X,Y), Cov(X,Y), μ ± σ, μ ± σ, μ ± σ"
        )
    }

    func testFormatsAsrMathPronunciationAliasesAsLatex() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "kai squared, 开 squid, kai squared k, correlation of XY, Correlation of x, y, corr of x, y, corr of xy, Covariance of x, y, cov of X, Y, mew plus or minus sigma",
                outputFormat: .latex
            ),
            #"\chi^2, \chi^2, \chi^2_k, \mathrm{Corr}(X,Y), \mathrm{Corr}(X,Y), \mathrm{Corr}(X,Y), \mathrm{Corr}(X,Y), \mathrm{Cov}(X,Y), \mathrm{Cov}(X,Y), \mu \pm \sigma"#
        )
    }

    func testFormatsLatestAsrSampleNearMisses() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "E of X, E of Y, Cov X, comma Y, Cor X Y, Cor Better Hat γ̄, S D X̄, S D Yᵢ, SDX bar, SDY sub I, alpha 2, K squared with 2 degrees of freedom, K² with 2 degrees of freedom",
                outputFormat: .unicode
            ),
            "E[X], E[Y], Cov(X,Y), Corr(X,Y), Corr(β̂,γ̄), SD(X̄), SD(Yᵢ), SD(X̄), SD(Yᵢ), α², χ² with 2 degrees of freedom, χ² with 2 degrees of freedom"
        )
    }

    func testMathEnglishRulesIgnoreRecognitionCasing() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "STANDARD NORMAL, X FOLLOWS NORMAL, Standard Error, P Value, Risk Free Rate, a Squared, A Squared, Capital A Squared, b Bar, Capital B Bar",
                outputFormat: .unicode
            ),
            "N(0,1), X ~ N(μ,σ²), SE, p-value, r_f, a², A², A², b̄, B̄"
        )
    }

    func testSubscriptRulesIgnoreRecognitionCasing() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "x SUB Zero, A Sub One, B sub I, X Sub T Minus One, x sub Zero TO Nine",
                outputFormat: .latex
            ),
            #"x_0, A_1, B_i, X_{t-1}, x_0 to x_9"#
        )
    }

    func testMathParserDoesNotRewriteProtectedSpans() {
        XCTAssertEqual(
            MathNotationFormatter.format(
                "Open https://example.com/theta and then variance x",
                outputFormat: .unicode
            ),
            "Open https://example.com/theta and then Var(X)"
        )

        XCTAssertEqual(
            MathNotationFormatter.format(
                "Check /tmp/alpha and then variance y",
                outputFormat: .unicode
            ),
            "Check /tmp/alpha and then Var(Y)"
        )

        XCTAssertEqual(
            MathNotationFormatter.format(
                "Use Qwen/Theta-Alpha and then variance x",
                outputFormat: .unicode
            ),
            "Use Qwen/Theta-Alpha and then Var(X)"
        )

        XCTAssertEqual(
            MathNotationFormatter.format(
                "open qwen/theta-alpha today and variance x",
                outputFormat: .unicode
            ),
            "open qwen/theta-alpha today and Var(X)"
        )
    }

    func testMathParserDoesNotRewriteCodeLikeVar() {
        XCTAssertEqual(
            MathNotationFormatter.format("Use `alpha` and `variance x` then variance y", outputFormat: .unicode),
            "Use `alpha` and `variance x` then Var(Y)"
        )

        XCTAssertEqual(
            MathNotationFormatter.format(
                """
                Keep:
                ```
                alpha
                ```
                Then variance y
                """,
                outputFormat: .unicode
            ),
            """
            Keep:
            ```
            alpha
            ```
            Then Var(Y)
            """
        )

        XCTAssertEqual(
            MathNotationFormatter.format(
                """
                Keep:
                ```
                alpha
                variance x
                """,
                outputFormat: .unicode
            ),
            """
            Keep:
            ```
            alpha
            variance x
            """
        )
    }

    func testMathParserDoesNotRewriteExistingLatexCommands() {
        XCTAssertEqual(
            MathNotationFormatter.format(#"Keep \bar{alpha} and then variance y"#, outputFormat: .unicode),
            #"Keep \bar{alpha} and then Var(Y)"#
        )

        XCTAssertEqual(
            MathNotationFormatter.format(#"Keep \mathrm{alpha}(X) and then variance y"#, outputFormat: .unicode),
            #"Keep \mathrm{alpha}(X) and then Var(Y)"#
        )

        XCTAssertEqual(
            MathNotationFormatter.format(#"Keep \frac{alpha}{beta} and variance y"#, outputFormat: .unicode),
            #"Keep \frac{alpha}{beta} and Var(Y)"#
        )

        XCTAssertEqual(
            MathNotationFormatter.format(#"Keep \frac{\hat{\theta}}{alpha} and variance y"#, outputFormat: .unicode),
            #"Keep \frac{\hat{\theta}}{alpha} and Var(Y)"#
        )
    }
}
