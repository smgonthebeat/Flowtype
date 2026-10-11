import XCTest
@testable import VoiceInputApp

final class MathNotationFormatterTests: XCTestCase {
    // Math rebuild (execution stage 6): the lists these tests used to join with commas are now
    // asserted phrase by phrase. The new noise tolerance (design.md 4, P8) lets a function name
    // reach across a comma ("standard error, h zero" is SE(H₀)), so a comma-joined list no longer
    // tests each phrase on its own. Every changed expectation names its contract clause.
    private func assertFormats(
        _ cases: [(String, String)],
        _ format: MathNotationOutputFormat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (input, expected) in cases {
            XCTAssertEqual(MathNotationFormatter.format(input, outputFormat: format), expected, input, file: file, line: line)
        }
    }

    func testFormatsLatexNotation() {
        // Math rebuild: "equals" is a relation (design.md 5.2); each formula is wrapped in $...$ (D1).
        XCTAssertEqual(
            MathNotationFormatter.format("theta hat equals x bar and sigma squared", outputFormat: .latex),
            #"$\hat{\theta} = \bar{x}$ and $\sigma^2$"#
        )
    }

    func testFormatsUnicodeNotation() {
        // Math rebuild: "equals" is a relation (design.md 5.2).
        XCTAssertEqual(
            MathNotationFormatter.format("theta hat equals x bar and sigma squared", outputFormat: .unicode),
            "θ̂ = x̄ and σ²"
        )
    }

    func testFormatsLikelihoodExpressions() {
        // Math rebuild: $...$ per formula (D1); ell is a lexicon letter that reads as a function name.
        XCTAssertEqual(
            MathNotationFormatter.format("capital L of theta and ell of theta", outputFormat: .latex),
            #"$L(\theta)$ and $\ell(\theta)$"#
        )
        assertFormats([("capital L of theta", "L(θ)"), ("ell of theta", "ℓ(θ)")], .unicode)
    }

    func testFormatsSquareAlias() {
        // Math rebuild: $...$ per formula (D1).
        XCTAssertEqual(
            MathNotationFormatter.format("sigma square and chi square", outputFormat: .latex),
            #"$\sigma^2$ and $\chi^2$"#
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
        // Math rebuild: notation already in the text is inert and is not converted between formats
        // (design.md 3 rule 3, D1). Formerly \hat{\theta}, \alpha \beta \sigma^2.
        XCTAssertEqual(
            MathNotationFormatter.format("θ̂, α β σ square", outputFormat: .latex),
            "θ̂, α β σ square"
        )
    }

    func testNormalizesExistingLatexToUnicode() {
        // Math rebuild: existing notation is inert (design.md 3 rule 3). Formerly θ̂, α β σ².
        XCTAssertEqual(
            MathNotationFormatter.format(#"\hat{\theta}, \alpha \beta \sigma^2"#, outputFormat: .unicode),
            #"\hat{\theta}, \alpha \beta \sigma^2"#
        )
    }

    func testGenericTemplateRulesLatex() {
        // Math rebuild: per phrase, $...$ (D1); a sentence-initial letter is lower case (D5: A transpose
        // -> a^\top; say "capital A" for a matrix).
        assertFormats([
            ("alpha hat", #"$\hat{\alpha}$"#), ("mu bar", #"$\bar{\mu}$"#), ("epsilon tilde", #"$\tilde{\epsilon}$"#),
            ("x prime", "$x'$"), ("x double prime", "$x''$"), ("A transpose", #"$a^\top$"#), ("A inverse", "$a^{-1}$"),
            ("capital A transpose", #"$A^\top$"#), ("y cubed", "$y^3$")
        ], .latex)
    }

    func testGenericTemplateRulesUnicode() {
        // Math rebuild: per phrase; x double prime is x′′ (corpus MC-0057); sentence-initial A is a (D5).
        assertFormats([
            ("alpha head", "α̂"), ("mu bar", "μ̄"), ("epsilon tilde", "ε̃"), ("x prime", "x′"), ("x double prime", "x′′"),
            ("A transpose", "aᵀ"), ("A inverse", "a⁻¹"), ("capital A inverse", "A⁻¹"), ("y cubed", "y³")
        ], .unicode)
    }

    func testSubscriptTemplates() {
        // Math rebuild: implicit letter subscripts are i, j, k (and it, jt) only (design.md 4), so
        // "r t minus one" is r·t − 1; say "r sub t minus one". A bare "y i t" has too little evidence on
        // its own (design.md 6.1) and converts inside a formula. Formerly y_{it}, r_{t-1}, p_{t+1}.
        assertFormats([
            ("beta sub zero", #"$\beta_0$"#), ("theta sub n", #"$\theta_n$"#), ("x sub i", "$x_i$"), ("y i t", "y i t"),
            ("y i t equals beta x i t", #"$y_{it} = \beta x_{it}$"#), ("r t minus one", "$r t - 1$"),
            ("r sub t minus one", "$r_{t-1}$"), ("p sub t plus one", "$p_{t+1}$")
        ], .latex)
    }

    func testCompletesGreekCatalog() {
        // Math rebuild: each name on its own; a run made only of Greek names is not a formula
        // (design.md 6.2 rule 4). Formerly the whole run converted.
        assertFormats([
            ("zeta", #"$\zeta$"#), ("eta", #"$\eta$"#), ("iota", #"$\iota$"#), ("kappa", #"$\kappa$"#), ("nu", #"$\nu$"#),
            ("xi", #"$\xi$"#), ("upsilon", #"$\upsilon$"#), ("psi", #"$\psi$"#), ("omega", #"$\omega$"#),
            ("capital gamma", #"$\Gamma$"#), ("big omega", #"$\Omega$"#), ("curly epsilon", #"$\varepsilon$"#),
            ("variant theta", #"$\vartheta$"#), ("final sigma", #"$\varsigma$"#), ("varphi", #"$\varphi$"#),
            ("zeta eta iota kappa nu xi upsilon psi omega", "zeta eta iota kappa nu xi upsilon psi omega")
        ], .latex)
    }

    func testDoesNotRewriteParserOnlyGreekAliases() {
        // Math rebuild: beta is a prose-common name and needs a cue word or another formula in the
        // sentence (design.md 6.2 rule 2); mu is math-dominant. bita and mew are aliases without
        // evidence of their own (design.md 6.3). Formerly "β and μ convert".
        XCTAssertEqual(
            MathNotationFormatter.format("bita and mew stay plain, beta and mu convert", outputFormat: .unicode),
            "bita and mew stay plain, beta and μ convert"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("bita and mew stay plain, beta and mu convert", outputFormat: .latex),
            #"bita and mew stay plain, beta and $\mu$ convert"#
        )
        assertFormats([("beta", "β"), ("the coefficient beta", "the coefficient β")], .unicode)
    }

    func testAddsStatisticsRegressionAndFinancePhrases() {
        // Math rebuild: terms stay words unless spoken as notation or with an argument (D8): standard
        // error, OLS, fixed effects, DiD, 2SLS, risk free rate, market return, CAPM, NPV, Sharpe, WACC
        // stay as spoken (formerly \mathrm{SE}, \mathrm{OLS}, r_f, R_m ...). h a is H_a like h one.
        assertFormats([
            ("standard error", "standard error"), ("h zero", "$H_0$"), ("h one", "$H_1$"), ("h a", "$H_a$"),
            ("r squared", "$R^2$"), ("adjusted r squared", #"$\bar{R}^2$"#),
            ("ordinary least squares", "ordinary least squares"), ("fixed effects", "fixed effects"),
            ("difference in differences", "difference in differences"),
            ("two stage least squares", "two stage least squares"), ("risk free rate", "risk free rate"),
            ("market return", "market return"), ("cap m", "cap m"), ("net present value", "net present value"),
            ("sharpe ratio", "sharpe ratio"), ("weighted average cost of capital", "weighted average cost of capital"),
            ("standard error of beta hat", #"$\operatorname{SE}(\hat{\beta})$"#)
        ], .latex)
    }

    func testFormatsPhaseTwoStatisticsExpressionsThroughPublicFormatter() {
        XCTAssertEqual(
            MathNotationFormatter.format("variance omega bar and expectation x", outputFormat: .unicode),
            "Var(ω̄) and E[X]"
        )
        // Math rebuild: $...$ and \operatorname (D1, D4).
        XCTAssertEqual(
            MathNotationFormatter.format("standard error beta hat and variance x sub i", outputFormat: .latex),
            #"$\operatorname{SE}(\hat{\beta})$ and $\operatorname{Var}(X_i)$"#
        )
        // Math rebuild: a misheard Greek name with a modifier (better head, bad hat) is medium
        // evidence, so with a function head it converts inside a sentence (owner test 2026-10-09:
        // "write standard error, better head in Swift"). This restores the former SE(β̂) and SE(β̂);
        // the 2026-10-03 migration had kept the sentence as spoken.
        XCTAssertEqual(
            MathNotationFormatter.format("standard error better head and SE bad hat", outputFormat: .unicode),
            "SE(β̂) and SE(β̂)"
        )
        assertFormats([("standard error better head", "SE(β̂)"), ("SE bad hat", "SE(β̂)")], .unicode)
        XCTAssertEqual(
            MathNotationFormatter.format("standard arrow better hat", outputFormat: .unicode),
            "SE(β̂)"
        )
        XCTAssertEqual(
            MathNotationFormatter.format(#"if I say "SE," better head again"#, outputFormat: .unicode),
            #"if I say "SE," better head again"#
        )
    }

    func testFormatsStandaloneSubscriptThenHat() {
        // Math rebuild: a sentence-initial letter is lower case (D5; design.md 5.1 "x sub i hat" -> x̂ᵢ);
        // LaTeX $...$ (D1). Formerly X̂ᵢ and \hat{\beta}_j.
        XCTAssertEqual(
            MathNotationFormatter.format("x sub i hat", outputFormat: .unicode),
            "x̂ᵢ"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("x sub i head", outputFormat: .unicode),
            "x̂ᵢ"
        )
        XCTAssertEqual(
            MathNotationFormatter.format("beta sub j hat", outputFormat: .latex),
            #"$\hat{\beta}_j$"#
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
        // Math rebuild: a distribution name without parameters stays a word (D8, design.md 5.6:
        // normal distribution, standard normal, x follows normal, iid); Pois / \operatorname (D4);
        // chi squared needs "with k degrees of freedom" for the index (5.6). Formerly N(\mu,\sigma^2),
        // N(0,1), X \sim N(\mu,\sigma^2), \mathrm{Poisson}(\lambda), \chi^2_k, \mathrm{i.i.d.}
        assertFormats([
            ("normal distribution", "normal distribution"), ("standard normal", "standard normal"),
            ("x follows normal", "x follows normal"), ("binomial n p", #"$\operatorname{Bin}(n, p)$"#),
            ("poisson lambda", #"$\operatorname{Pois}(\lambda)$"#), ("chi squared k", #"$\chi^2 k$"#),
            ("chi squared with k degrees of freedom", #"$\chi^2_k$"#), ("iid", "iid"),
            ("z follows a standard normal distribution", "$Z \\sim N(0, 1)$"),
            ("x follows a normal distribution with mean mu and variance sigma squared", #"$X \sim N(\mu, \sigma^2)$"#)
        ], .latex)
    }

    func testFormatsAsrCasedTemplateSuffixes() {
        // Math rebuild: a Greek character the recogniser already wrote is inert, so a spoken accent is
        // not attached to it (design.md 3 rule 3); spoken names are. Sentence-initial X is x (D5).
        // Formerly θ̂, β̂, γ̂, δ̂, ᾱ, θ̄, X̄, X̄.
        assertFormats([
            ("θ Hat", "θ Hat"), ("β Hat", "β Hat"), ("Theta Hat", "θ̂"), ("Alpha Bar", "ᾱ"), ("X Bar", "x̄"),
            // Owner decision 2026-10-10 (T11): a recogniser capital mid-sentence is lower case too;
            // the 2026-10-03 migration had "then X̄". Spoken "capital" still gives X̄.
            ("then X Bar", "then x̄"), ("Capital X Bar", "X̄")
        ], .unicode)
    }

    func testFormatsGenericCompactASRTokens() {
        // Math rebuild: a sentence-initial letter is lower case (D5); compact splitting covers Xbar,
        // Xsub1, subzero and x1 (design.md 3 rule 4), not runs such as NsubiNsubj. Formerly Nⱼ, X₁₀,
        // NᵢNⱼ, X̄.
        assertFormats([
            ("Nsubj", "nⱼ"), ("Xsub10", "x₁₀"), ("NsubiNsubj", "NsubiNsubj"), ("Xbar", "x̄"),
            // Owner decision 2026-10-10 (T11): lower case mid-sentence too; the migration had "then X̄".
            ("then Xbar", "then x̄")
        ], .unicode)
    }

    func testFormatsAsrTemplateAliases() {
        // Math rebuild: per phrase, $...$ (D1).
        assertFormats([
            ("theta head", #"$\hat{\theta}$"#), ("beta head", #"$\hat{\beta}$"#), ("bita", "bita"),
            ("betasquared", #"$\beta^2$"#), ("gammasquared", #"$\gamma^2$"#), ("capital x squared", "$X^2$")
        ], .latex)
    }

    func testFormatsAsrVarianceAndDistributionAliases() {
        // Math rebuild: per phrase (alias spans need a whole utterance or other evidence, design.md 6.3).
        assertFormats([
            ("Variant of x", "Var(X)"), ("Variants of X", "Var(X)"), ("T distribution with new degrees of freedom", "t_ν")
        ], .unicode)
    }

    func testFormatsAsrSubscriptRangesAndCompactedSubscripts() {
        // Math rebuild: "x sub zero to nine" is an index range, x₀ to x₉ (owner decision 2026-10-09,
        // restoring the former result; the 2026-10-03 migration had x₀ to nine). An all-caps word is an
        // acronym, never split (YIT, RT, XIXJXK: design.md 3 rule 3); a bare glued index next to "to"
        // has too little evidence (x one alone stays, design.md 5.1). Formerly X₀ to X₉,
        // yᵢₜ, xᵢₜ, rₜ₋₁, pₜ₊₁, xᵢ xⱼ xₖ.
        assertFormats([
            ("x sub zero to nine", "x₀ to x₉"), ("x sub 0 to 9", "x₀ to x₉"), ("X0 to X9", "X0 to X9"), ("YIT", "YIT"),
            ("XIT", "XIT"), ("RT minus 1", "RT minus 1"), ("PT plus 1", "PT plus 1"), ("XIXJXK", "XIXJXK"),
            ("y sub i t", "yᵢₜ"), ("r sub t minus one", "rₜ₋₁"), ("x sub zero plus x sub nine", "x₀ + x₉")
        ], .unicode)
    }

    func testFormatsAsrMathPronunciationAliases() {
        // Math rebuild: per phrase; Corr(X, Y) with a space (D4); "chi squared k" has no index without
        // "degrees of freedom" (5.6). "squid" is a misheard "squared" (owner test 2026-10-09: "Sigma
        // Squid"), so "开 squid" is χ² again as it was formerly; the 2026-10-03 migration had kept it.
        // "Mul ± σ" is a recogniser artefact: existing ± σ is inert (design.md 3 rule 3). Formerly χ²_k,
        // μ ± σ.
        assertFormats([
            ("kai squared", "χ²"), ("kai square k", "χ²k"), ("开 squared", "χ²"), ("开 squid", "χ²"),
            ("开 squared k", "χ²k"), ("correlation of XY", "Corr(X, Y)"), ("Correlation of x, y", "Corr(X, Y)"),
            ("corr of x, y", "Corr(X, Y)"), ("corr of xy", "Corr(X, Y)"), ("Covariance of x, y", "Cov(X, Y)"),
            ("cov of X, Y", "Cov(X, Y)"), ("mew plus or minus sigma", "μ ± σ"), ("Mul ± σ", "Mul ± σ")
        ], .unicode)
    }

    func testFormatsAsrMathPronunciationAliasesAsLatex() {
        // Math rebuild: per phrase, $...$ and \operatorname (D1, D4); see the Unicode test above
        // (开 squid: owner test 2026-10-09).
        assertFormats([
            ("kai squared", #"$\chi^2$"#), ("开 squid", #"$\chi^2$"#), ("kai squared k", #"$\chi^2 k$"#),
            ("correlation of XY", #"$\operatorname{Corr}(X, Y)$"#), ("Correlation of x, y", #"$\operatorname{Corr}(X, Y)$"#),
            ("corr of x, y", #"$\operatorname{Corr}(X, Y)$"#), ("corr of xy", #"$\operatorname{Corr}(X, Y)$"#),
            ("Covariance of x, y", #"$\operatorname{Cov}(X, Y)$"#), ("cov of X, Y", #"$\operatorname{Cov}(X, Y)$"#),
            ("mew plus or minus sigma", #"$\mu \pm \sigma$"#)
        ], .latex)
    }

    func testFormatsLatestAsrSampleNearMisses() {
        // Math rebuild: per phrase. Arguments the recogniser already rendered (γ̄, X̄, Yᵢ) are inert
        // (design.md 3 rule 3); glued all-caps words (SDX, SDY) are not split (3 rule 3); "alpha 2" is
        // an implicit subscript α₂ (design.md 4); K squared becomes χ² only through ASRConfusionCorrector
        // in the pipeline (asr-confusion golden CONF010). Formerly Corr(β̂,γ̄), SD(X̄), SD(Yᵢ), SD(X̄),
        // SD(Yᵢ), α², χ² with 2 degrees of freedom.
        assertFormats([
            ("E of X", "E[X]"), ("E of Y", "E[Y]"), ("Cov X, comma Y", "Cov(X, Y)"), ("Cor X Y", "Corr(X, Y)"),
            ("Cor Better Hat γ̄", "Cor Better Hat γ̄"), ("S D X̄", "S D X̄"), ("S D Yᵢ", "S D Yᵢ"), ("SDX bar", "SDX bar"),
            ("SDY sub I", "SDY sub I"), ("S D X bar", "SD(X̄)"), ("alpha 2", "α₂"),
            ("K squared with 2 degrees of freedom", "k² with 2 degrees of freedom"),
            ("K² with 2 degrees of freedom", "K² with 2 degrees of freedom")
        ], .unicode)
    }

    func testMathEnglishRulesIgnoreRecognitionCasing() {
        // Math rebuild: terms without parameters stay words (D8: standard normal, follows normal,
        // standard error, risk free rate); a bare "p value" stays (design.md 5.1); a sentence-initial
        // letter is lower case (D5: A Squared -> a²). Spoken words still match case-insensitively.
        // Formerly N(0,1), X ~ N(μ,σ²), SE, p-value, r_f, A².
        assertFormats([
            ("STANDARD NORMAL", "STANDARD NORMAL"), ("X FOLLOWS NORMAL", "X FOLLOWS NORMAL"),
            ("Standard Error", "Standard Error"), ("P Value", "P Value"), ("Risk Free Rate", "Risk Free Rate"),
            ("a Squared", "a²"), ("A Squared", "a²"), ("Capital A Squared", "A²"), ("b Bar", "b̄"),
            ("Capital B Bar", "B̄"), ("Variance Of X", "Var(X)"), ("X Follows A Normal Distribution With Mean Mu And Variance Sigma Squared", "X ∼ N(μ, σ²)")
        ], .unicode)
    }

    func testSubscriptRulesIgnoreRecognitionCasing() {
        // Math rebuild: per phrase, $...$ (D1); sentence-initial letters are lower case and capitals
        // inside the formula are now lower case too (owner decision 2026-10-10, T11: X Sub T Minus One
        // -> x_{t-1}; the 2026-10-03 migration had x_{T-1}, formerly X_{t-1}); an index range
        // renders each end as its own formula and keeps the spoken joiner (owner decision 2026-10-09).
        // Formerly A_1, B_i, X_{t-1}, x_0 to x_9; the 2026-10-03 migration had "$x_0$ TO Nine".
        assertFormats([
            ("x SUB Zero", "$x_0$"), ("A Sub One", "$a_1$"), ("B sub I", "$b_i$"), ("X Sub T Minus One", "$x_{t-1}$"),
            ("x sub Zero TO Nine", "$x_0$ TO $x_9$")
        ], .latex)
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
