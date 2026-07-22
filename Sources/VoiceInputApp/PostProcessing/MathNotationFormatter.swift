import Foundation

struct MathNotationFormattingResult: Equatable {
    let text: String
    let events: [PostProcessingEvent]
}

enum MathNotationFormatter {
    private struct Rule {
        let pattern: String
        let latexReplacement: String
        let unicodeReplacement: String
        let options: NSRegularExpression.Options

        init(
            pattern: String,
            latexReplacement: String,
            unicodeReplacement: String,
            options: NSRegularExpression.Options = []
        ) {
            self.pattern = pattern
            self.latexReplacement = latexReplacement
            self.unicodeReplacement = unicodeReplacement
            self.options = options
        }
    }

    private struct MathSymbol {
        let spoken: String
        let latex: String
        let unicode: String
    }

    private static func symbols(from definitions: [MathSymbolDefinition]) -> [MathSymbol] {
        definitions.flatMap { definition in
            definition.allFormatterSpokenForms.map { spokenForm in
                MathSymbol(spoken: spokenForm, latex: definition.latex, unicode: definition.unicode)
            }
        }
    }

    private typealias SubscriptIndex = MathScriptToken

    private enum SymbolModifier {
        case hat
        case bar
        case tilde
        case dot
        case doubleDot
        case prime
        case doublePrime
        case star
        case transpose
        case inverse
        case squared
        case cubed
    }

    private static let lowerGreekSymbols: [MathSymbol] = symbols(from: MathSymbolCatalog.lowerGreek)
    private static let upperGreekSymbols: [MathSymbol] = symbols(from: MathSymbolCatalog.upperGreek)
    private static let variantGreekSymbols: [MathSymbol] = symbols(from: MathSymbolCatalog.variantGreek)

    private static let allGreekSymbols = lowerGreekSymbols + upperGreekSymbols + variantGreekSymbols
    private static let templateGreekSymbols = lowerGreekSymbols + variantGreekSymbols
    private static let variantGreekBaseNames: Set<String> = [
        "epsilon",
        "theta",
        "pi",
        "rho",
        "sigma",
        "phi"
    ]

    private static let subscriptIndices: [SubscriptIndex] = MathScriptCatalog.subscriptIndices
    private static let compactASRChainSeparator = "\u{E000}"

    private static let existingNotationRules: [Rule] = [
        Rule(pattern: #"(?i)\bK²(?=\s+with\s+(?:two|2)\s+degrees of freedom\b)"#, latexReplacement: #"\chi^2"#, unicodeReplacement: "χ²"),
        Rule(pattern: #"(?i)\\hat\{\\theta\}"#, latexReplacement: #"\hat{\theta}"#, unicodeReplacement: "θ̂"),
        Rule(pattern: #"(?i)\\hat\{\\beta\}"#, latexReplacement: #"\hat{\beta}"#, unicodeReplacement: "β̂"),
        Rule(pattern: #"(?i)\\sigma\^2\b"#, latexReplacement: #"\sigma^2"#, unicodeReplacement: "σ²"),
        Rule(pattern: #"θ̂"#, latexReplacement: #"\hat{\theta}"#, unicodeReplacement: "θ̂"),
        Rule(pattern: #"β̂"#, latexReplacement: #"\hat{\beta}"#, unicodeReplacement: "β̂")
    ]

    private static let standaloneExistingLatexCommands: Set<String> = [
        #"\hat{\theta}"#,
        #"\hat{\beta}"#
    ]

    private static let fixedPhraseRules: [Rule] = [
        Rule(pattern: #"(?i)\bnormal distribution\b"#, latexReplacement: #"N(\mu,\sigma^2)"#, unicodeReplacement: "N(μ,σ²)"),
        Rule(pattern: #"(?i)\bstandard normal\b"#, latexReplacement: #"N(0,1)"#, unicodeReplacement: "N(0,1)"),
        Rule(pattern: #"(?i)\bx follow normal\b"#, latexReplacement: #"X \sim N(\mu,\sigma^2)"#, unicodeReplacement: "X ~ N(μ,σ²)"),
        Rule(pattern: #"(?i)\bx follows normal\b"#, latexReplacement: #"X \sim N(\mu,\sigma^2)"#, unicodeReplacement: "X ~ N(μ,σ²)"),
        Rule(pattern: #"(?i)\bx is normally distributed\b"#, latexReplacement: #"X \sim N(\mu,\sigma^2)"#, unicodeReplacement: "X ~ N(μ,σ²)"),
        Rule(pattern: #"(?i)\bx distributed normal mu sigma squared\b"#, latexReplacement: #"X \sim N(\mu,\sigma^2)"#, unicodeReplacement: "X ~ N(μ,σ²)"),
        Rule(pattern: #"(?i)\bx follows normal zero one\b"#, latexReplacement: #"X \sim N(0,1)"#, unicodeReplacement: "X ~ N(0,1)"),
        Rule(pattern: #"(?i)\bbernoulli p\b"#, latexReplacement: #"\mathrm{Bernoulli}(p)"#, unicodeReplacement: "Bernoulli(p)"),
        Rule(pattern: #"(?i)\bbern p\b"#, latexReplacement: #"\mathrm{Bern}(p)"#, unicodeReplacement: "Bern(p)"),
        Rule(pattern: #"(?i)\bbinomial n p\b"#, latexReplacement: #"\mathrm{Bin}(n,p)"#, unicodeReplacement: "Bin(n,p)"),
        Rule(pattern: #"(?i)\bpoisson lambda\b"#, latexReplacement: #"\mathrm{Poisson}(\lambda)"#, unicodeReplacement: "Poisson(λ)"),
        Rule(pattern: #"(?i)\buniform a b\b"#, latexReplacement: #"\mathrm{Unif}(a,b)"#, unicodeReplacement: "Unif(a,b)"),
        Rule(pattern: #"(?i)\bexponential lambda\b"#, latexReplacement: #"\mathrm{Exp}(\lambda)"#, unicodeReplacement: "Exp(λ)"),
        Rule(pattern: #"(?i)\bchi squared? with k degrees of freedom\b"#, latexReplacement: #"\chi^2_k"#, unicodeReplacement: "χ²_k"),
        Rule(pattern: #"(?i)\bchi squared? k\b"#, latexReplacement: #"\chi^2_k"#, unicodeReplacement: "χ²_k"),
        Rule(pattern: #"(?i)\bk\s+squared?\s+with\s+(?:two|2)\s+degrees of freedom\b"#, latexReplacement: #"\chi^2 with 2 degrees of freedom"#, unicodeReplacement: "χ² with 2 degrees of freedom"),
        Rule(pattern: #"(?i)\b(?:kai|开)\s+(?:square|squared|squid)\s+k\b"#, latexReplacement: #"\chi^2_k"#, unicodeReplacement: "χ²_k"),
        Rule(pattern: #"(?i)\b(?:kai|开)\s+(?:square|squared|squid)\b"#, latexReplacement: #"\chi^2"#, unicodeReplacement: "χ²"),
        Rule(pattern: #"(?i)\bt distribution with new degrees of freedom\b"#, latexReplacement: #"t_\nu"#, unicodeReplacement: "t_ν"),
        Rule(pattern: #"(?i)\bt distribution with nu degrees of freedom\b"#, latexReplacement: #"t_\nu"#, unicodeReplacement: "t_ν"),
        Rule(pattern: #"(?i)\bt nu\b"#, latexReplacement: #"t_\nu"#, unicodeReplacement: "t_ν"),
        Rule(pattern: #"(?i)\biid\b"#, latexReplacement: #"\mathrm{i.i.d.}"#, unicodeReplacement: "i.i.d."),
        Rule(pattern: #"(?i)\bindependent and identically distributed\b"#, latexReplacement: #"\mathrm{i.i.d.}"#, unicodeReplacement: "i.i.d."),
        Rule(pattern: #"(?i)\bxixjxk\b"#, latexReplacement: #"x_i x_j x_k"#, unicodeReplacement: "xᵢ xⱼ xₖ"),

        Rule(pattern: #"(?i)\bstandard error of beta hat\b"#, latexReplacement: #"\mathrm{SE}(\hat{\beta})"#, unicodeReplacement: "SE(β̂)"),
        Rule(pattern: #"(?i)\balpha\s+(?:two|2)\b"#, latexReplacement: #"\alpha^2"#, unicodeReplacement: "α²"),
        Rule(pattern: #"α\s+(?:two|2)\b"#, latexReplacement: #"\alpha^2"#, unicodeReplacement: "α²"),
        Rule(pattern: #"(?i)\bbeta hat zero\b"#, latexReplacement: #"\hat{\beta}_0"#, unicodeReplacement: "β̂₀"),
        Rule(pattern: #"(?i)\bbeta hat 0\b"#, latexReplacement: #"\hat{\beta}_0"#, unicodeReplacement: "β̂₀"),
        Rule(pattern: #"(?i)\bbeta hat one\b"#, latexReplacement: #"\hat{\beta}_1"#, unicodeReplacement: "β̂₁"),
        Rule(pattern: #"(?i)\bbeta hat 1\b"#, latexReplacement: #"\hat{\beta}_1"#, unicodeReplacement: "β̂₁"),
        Rule(pattern: #"(?i)\btheta (?:zero|naught|0)\b"#, latexReplacement: #"\theta_0"#, unicodeReplacement: "θ₀"),
        Rule(pattern: #"(?i)\btheta (?:one|1)\b"#, latexReplacement: #"\theta_1"#, unicodeReplacement: "θ₁"),
        Rule(pattern: #"(?i)\bbeta (?:zero|naught|0)\b"#, latexReplacement: #"\beta_0"#, unicodeReplacement: "β₀"),
        Rule(pattern: #"(?i)\bbeta (?:one|1)\b"#, latexReplacement: #"\beta_1"#, unicodeReplacement: "β₁"),
        Rule(pattern: #"(?i)\bbeta (?:two|2)\b"#, latexReplacement: #"\beta_2"#, unicodeReplacement: "β₂"),
        Rule(pattern: #"(?i)\bbeta k\b"#, latexReplacement: #"\beta_k"#, unicodeReplacement: "β_k"),
        Rule(pattern: #"(?i)\bbeta j\b"#, latexReplacement: #"\beta_j"#, unicodeReplacement: "βⱼ"),
        Rule(pattern: #"(?i)\bstandard error\b(?!\s+(?:of\s+)?(?:message|messages|log|logs)\b)"#, latexReplacement: #"\mathrm{SE}"#, unicodeReplacement: "SE"),
        Rule(pattern: #"(?i)\bconfidence interval\b"#, latexReplacement: #"\mathrm{CI}"#, unicodeReplacement: "CI"),
        Rule(pattern: #"(?i)\bmargin of error\b"#, latexReplacement: #"\mathrm{ME}"#, unicodeReplacement: "ME"),
        Rule(pattern: #"(?i)\bh zero\b"#, latexReplacement: #"H_0"#, unicodeReplacement: "H₀"),
        Rule(pattern: #"(?i)\bh naught\b"#, latexReplacement: #"H_0"#, unicodeReplacement: "H₀"),
        Rule(pattern: #"(?i)\bnull hypothesis\b"#, latexReplacement: #"H_0"#, unicodeReplacement: "H₀"),
        Rule(pattern: #"(?i)\bh one\b"#, latexReplacement: #"H_1"#, unicodeReplacement: "H₁"),
        Rule(pattern: #"(?i)\balternative hypothesis\b"#, latexReplacement: #"H_1"#, unicodeReplacement: "H₁"),
        Rule(pattern: #"(?i)\bh a\b"#, latexReplacement: #"H_a"#, unicodeReplacement: "Hₐ"),
        Rule(pattern: #"(?i)\badjusted r squared\b"#, latexReplacement: #"\bar{R}^2"#, unicodeReplacement: "R̄²"),
        Rule(pattern: #"(?i)\br squared\b"#, latexReplacement: #"R^2"#, unicodeReplacement: "R²"),
        Rule(pattern: #"(?i)\bordinary least squares\b"#, latexReplacement: #"\mathrm{OLS}"#, unicodeReplacement: "OLS"),
        Rule(pattern: #"(?i)(?<![A-Za-z\\{])\bols\b(?![A-Za-z}])"#, latexReplacement: #"\mathrm{OLS}"#, unicodeReplacement: "OLS"),
        Rule(pattern: #"(?i)\bfixed effects\b"#, latexReplacement: #"\mathrm{FE}"#, unicodeReplacement: "FE"),
        Rule(pattern: #"(?i)\brandom effects\b"#, latexReplacement: #"\mathrm{RE}"#, unicodeReplacement: "RE"),
        Rule(pattern: #"(?i)\bdifference in differences\b"#, latexReplacement: #"\mathrm{DiD}"#, unicodeReplacement: "DiD"),
        Rule(pattern: #"(?i)\btwo stage least squares\b"#, latexReplacement: #"\mathrm{2SLS}"#, unicodeReplacement: "2SLS"),
        Rule(pattern: #"(?i)\by hat i\b"#, latexReplacement: #"\hat{y}_i"#, unicodeReplacement: "ŷᵢ"),
        Rule(pattern: #"(?i)\bresidual e i\b"#, latexReplacement: #"e_i"#, unicodeReplacement: "eᵢ"),

        Rule(pattern: #"(?i)\bexpected value of x\b"#, latexReplacement: #"E[X]"#, unicodeReplacement: "E[X]"),
        Rule(pattern: #"(?i)\bexpectation of x\b"#, latexReplacement: #"E[X]"#, unicodeReplacement: "E[X]"),
        Rule(pattern: #"(?i)\bsample mean of x\b"#, latexReplacement: #"\bar{x}"#, unicodeReplacement: "x̄"),
        Rule(pattern: #"(?i)\bpopulation mean\b"#, latexReplacement: #"\mu"#, unicodeReplacement: "μ"),
        Rule(pattern: #"(?i)\bvariants? of x\b"#, latexReplacement: #"\mathrm{Var}(X)"#, unicodeReplacement: "Var(X)"),
        Rule(pattern: #"(?i)\bvariance of x\b"#, latexReplacement: #"\mathrm{Var}(X)"#, unicodeReplacement: "Var(X)"),
        Rule(pattern: #"(?i)\bvar of x\b"#, latexReplacement: #"\mathrm{Var}(X)"#, unicodeReplacement: "Var(X)"),
        Rule(pattern: #"(?i)\bsample variance\b"#, latexReplacement: #"s^2"#, unicodeReplacement: "s²"),
        Rule(pattern: #"(?i)\bpopulation variance\b"#, latexReplacement: #"\sigma^2"#, unicodeReplacement: "σ²"),
        Rule(pattern: #"(?i)\bstandard deviation of x\b"#, latexReplacement: #"\mathrm{SD}(X)"#, unicodeReplacement: "SD(X)"),
        Rule(pattern: #"(?i)\bcovariance of x(?:\s*,\s*|\s+and\s+|\s*)y\b"#, latexReplacement: #"\mathrm{Cov}(X,Y)"#, unicodeReplacement: "Cov(X,Y)"),
        Rule(pattern: #"(?i)\bcov of x(?:\s*,\s*|\s+and\s+|\s*)y\b"#, latexReplacement: #"\mathrm{Cov}(X,Y)"#, unicodeReplacement: "Cov(X,Y)"),
        Rule(pattern: #"(?i)\bcorrelation of x(?:\s*,\s*|\s+and\s+|\s*)y\b"#, latexReplacement: #"\mathrm{Corr}(X,Y)"#, unicodeReplacement: "Corr(X,Y)"),
        Rule(pattern: #"(?i)\bcorr of x(?:\s*,\s*|\s+and\s+|\s*)y\b"#, latexReplacement: #"\mathrm{Corr}(X,Y)"#, unicodeReplacement: "Corr(X,Y)"),
        Rule(pattern: #"(?i)\bp[- ]value\b"#, latexReplacement: #"p-value"#, unicodeReplacement: "p-value"),
        Rule(pattern: #"(?i)\b(?:capital|big) l of theta\b"#, latexReplacement: #"L(\theta)"#, unicodeReplacement: "L(θ)"),
        Rule(pattern: #"(?i)\b(?:little l|ell|little ell) of theta\b"#, latexReplacement: #"\ell(\theta)"#, unicodeReplacement: "ℓ(θ)"),
        Rule(pattern: #"(?i)\blog likelihood\b"#, latexReplacement: #"\ell(\theta)"#, unicodeReplacement: "ℓ(θ)"),
        Rule(pattern: #"(?i)\blikelihood function\b"#, latexReplacement: #"L(\theta)"#, unicodeReplacement: "L(θ)"),
        Rule(pattern: #"(?i)\barg max over theta\b"#, latexReplacement: #"\arg\max_\theta"#, unicodeReplacement: "arg max_θ"),
        Rule(pattern: #"(?i)\barg min over theta\b"#, latexReplacement: #"\arg\min_\theta"#, unicodeReplacement: "arg min_θ"),

        Rule(pattern: #"(?i)\brisk free rate\b"#, latexReplacement: #"r_f"#, unicodeReplacement: "r_f"),
        Rule(pattern: #"(?i)\bmarket return\b"#, latexReplacement: #"R_m"#, unicodeReplacement: "R_m"),
        Rule(pattern: #"(?i)\bportfolio variance\b"#, latexReplacement: #"\sigma_p^2"#, unicodeReplacement: "σ_p²"),
        Rule(pattern: #"(?i)\bportfolio volatility\b"#, latexReplacement: #"\sigma_p"#, unicodeReplacement: "σ_p"),
        Rule(pattern: #"(?i)\bcap m\b"#, latexReplacement: #"\mathrm{CAPM}"#, unicodeReplacement: "CAPM"),
        Rule(pattern: #"(?i)\bcapital asset pricing model\b"#, latexReplacement: #"\mathrm{CAPM}"#, unicodeReplacement: "CAPM"),
        Rule(pattern: #"(?i)\bsharpe ratio\b"#, latexReplacement: #"\mathrm{Sharpe}"#, unicodeReplacement: "Sharpe"),
        Rule(pattern: #"(?i)\bnet present value\b"#, latexReplacement: #"NPV"#, unicodeReplacement: "NPV"),
        Rule(pattern: #"(?i)\bpresent value\b"#, latexReplacement: #"PV"#, unicodeReplacement: "PV"),
        Rule(pattern: #"(?i)\bfuture value\b"#, latexReplacement: #"FV"#, unicodeReplacement: "FV"),
        Rule(pattern: #"(?i)\binternal rate of return\b"#, latexReplacement: #"IRR"#, unicodeReplacement: "IRR"),
        Rule(pattern: #"(?i)\bweighted average cost of capital\b"#, latexReplacement: #"WACC"#, unicodeReplacement: "WACC"),
        Rule(pattern: #"(?i)\bebitda\b"#, latexReplacement: #"EBITDA"#, unicodeReplacement: "EBITDA"),
        Rule(pattern: #"(?i)\bearnings per share\b"#, latexReplacement: #"EPS"#, unicodeReplacement: "EPS"),

        Rule(pattern: #"(?i)\b(?:mu|mew|mul|mil)\s*(?:plus or minus|±)\s*(?:sigma|σ)\b"#, latexReplacement: #"\mu \pm \sigma"#, unicodeReplacement: "μ ± σ"),
        Rule(pattern: #"(?i)\bmu plus or minus sigma\b"#, latexReplacement: #"\mu \pm \sigma"#, unicodeReplacement: "μ ± σ"),
        Rule(pattern: #"(?i)\bplus or minus\b"#, latexReplacement: #"\pm"#, unicodeReplacement: "±"),
        Rule(pattern: #"(?i)\bis equal to zero\b"#, latexReplacement: #"is equal to 0"#, unicodeReplacement: "is equal to 0"),
        Rule(pattern: #"(?i)\bequal to zero\b"#, latexReplacement: #"equal to 0"#, unicodeReplacement: "equal to 0"),
        Rule(pattern: #"(?i)\bequals zero\b"#, latexReplacement: #"equals 0"#, unicodeReplacement: "equals 0"),
        Rule(pattern: #"(?i)\bx bar plus or minus standard error\b"#, latexReplacement: #"\bar{x} \pm \mathrm{SE}"#, unicodeReplacement: "x̄ ± SE"),
        Rule(pattern: #"(?i)\btheta hat minus theta\b"#, latexReplacement: #"\hat{\theta} - \theta"#, unicodeReplacement: "θ̂ - θ"),
        Rule(pattern: #"(?i)\bbeta hat minus beta\b"#, latexReplacement: #"\hat{\beta} - \beta"#, unicodeReplacement: "β̂ - β"),
        Rule(pattern: #"(?i)\bp hat minus p\b"#, latexReplacement: #"\hat{p} - p"#, unicodeReplacement: "p̂ - p"),
        Rule(pattern: #"(?i)\bx minus x bar\b"#, latexReplacement: #"x - \bar{x}"#, unicodeReplacement: "x - x̄"),
        Rule(pattern: #"(?i)\by minus y hat\b"#, latexReplacement: #"y - \hat{y}"#, unicodeReplacement: "y - ŷ"),
        Rule(pattern: #"(?i)\bone over n minus one\b"#, latexReplacement: #"\frac{1}{n-1}"#, unicodeReplacement: "1/(n-1)"),
        Rule(pattern: #"(?i)\bone over n\b"#, latexReplacement: #"\frac{1}{n}"#, unicodeReplacement: "1/n"),
        Rule(pattern: #"(?i)\bsquare root of n\b"#, latexReplacement: #"\sqrt{n}"#, unicodeReplacement: "√n"),
        Rule(pattern: #"(?i)\bsigma over square root n\b"#, latexReplacement: #"\frac{\sigma}{\sqrt{n}}"#, unicodeReplacement: "σ/√n"),
        Rule(pattern: #"(?i)\bs over square root n\b"#, latexReplacement: #"\frac{s}{\sqrt{n}}"#, unicodeReplacement: "s/√n")
    ]

    private static let templateSymbolPattern: String = {
        let spoken = templateGreekSymbols
            .map(\.spoken)
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let latex = templateGreekSymbols
            .filter { $0.latex.hasPrefix("\\") }
            .map { String($0.latex.dropFirst()) }
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let unicode = templateGreekSymbols
            .map(\.unicode)
            .joined()
        return #"(?<![A-Za-z\\])((?i:(?:capital|big)\s+[A-Za-z])|(?i:"# + spoken + #")|\\(?:"# + latex + #")|[A-Za-z]|["# + unicode + #"])"#
    }()

    private static let subscriptIndexPattern: String = MathScriptCatalog.subscriptPattern

    private static let greekBySpoken: [String: MathSymbol] = {
        var symbols: [String: MathSymbol] = [:]
        for symbol in allGreekSymbols {
            symbols[symbol.spoken] = symbol
        }
        return symbols
    }()

    private static let greekByLatex: [String: MathSymbol] = {
        var symbols: [String: MathSymbol] = [:]
        for symbol in allGreekSymbols where symbol.latex.hasPrefix("\\") && symbols[symbol.latex] == nil {
            symbols[symbol.latex] = symbol
        }
        return symbols
    }()

    private static let greekByUnicode: [String: MathSymbol] = {
        var symbols: [String: MathSymbol] = [:]
        for symbol in allGreekSymbols where symbols[symbol.unicode] == nil {
            symbols[symbol.unicode] = symbol
        }
        return symbols
    }()

    static func format(_ text: String, outputFormat: MathNotationOutputFormat) -> String {
        formatWithEvents(text, outputFormat: outputFormat).text
    }

    static func formatWithEvents(
        _ text: String,
        outputFormat: MathNotationOutputFormat,
        knownTerms: [String] = []
    ) -> MathNotationFormattingResult {
        var events: [PostProcessingEvent] = []

        let normalizedExistingNotation = MathProtectedSegmenter.formatUnprotectedSegments(
            in: text,
            unprotectedLatexCommands: standaloneExistingLatexCommands,
            knownTerms: knownTerms
        ) { segment in
            let before = segment
            let after = applyRules(existingNotationRules, to: segment, outputFormat: outputFormat)
            appendMathEvent(
                ruleID: "math.formatter.existing-notation",
                before: before,
                after: after,
                reason: "Normalize existing notation forms before downstream parsing.",
                events: &events
            )
            return after
        }

        let formatted = MathProtectedSegmenter.formatUnprotectedSegments(
            in: normalizedExistingNotation,
            knownTerms: knownTerms
        ) { segment in
            formatUnprotectedSegmentWithEvents(
                segment,
                outputFormat: outputFormat,
                normalizeExistingNotation: false,
                events: &events
            )
        }

        return MathNotationFormattingResult(text: formatted, events: events)
    }

    private static func formatUnprotectedSegment(
        _ text: String,
        outputFormat: MathNotationOutputFormat,
        normalizeExistingNotation: Bool = true
    ) -> String {
        var formatted = text
        if normalizeExistingNotation {
            formatted = applyRules(existingNotationRules, to: formatted, outputFormat: outputFormat)
        }
        formatted = CompactASRTokenNormalizer.normalize(
            formatted,
            chainedTermSeparator: compactASRChainSeparator
        )
        formatted = MathSpeechParser.replaceStatisticsFunctions(in: formatted, outputFormat: outputFormat)
        formatted = applyRules(fixedPhraseRules, to: formatted, outputFormat: outputFormat)
        formatted = applyTemplateRules(to: formatted, outputFormat: outputFormat)
        formatted = formatted.replacingOccurrences(of: compactASRChainSeparator, with: "")
        formatted = applyGreekLetterRules(to: formatted, outputFormat: outputFormat)
        return formatted
    }

    private static func formatUnprotectedSegmentWithEvents(
        _ text: String,
        outputFormat: MathNotationOutputFormat,
        normalizeExistingNotation: Bool = true,
        events: inout [PostProcessingEvent]
    ) -> String {
        var formatted = text
        if normalizeExistingNotation {
            let before = formatted
            formatted = applyRules(existingNotationRules, to: formatted, outputFormat: outputFormat)
            appendMathEvent(
                ruleID: "math.formatter.existing-notation",
                before: before,
                after: formatted,
                reason: "Normalize existing notation forms before downstream parsing.",
                events: &events
            )
        }

        do {
            let before = formatted
            formatted = CompactASRTokenNormalizer.normalize(
                formatted,
                chainedTermSeparator: compactASRChainSeparator
            )
            appendMathEvent(
                ruleID: "math.formatter.compact-asr-normalization",
                before: before,
                after: formatted.replacingOccurrences(of: compactASRChainSeparator, with: " "),
                reason: "Expand compact ASR math tokens before statistics parsing.",
                events: &events
            )
        }

        do {
            let before = formatted
            formatted = MathSpeechParser.replaceStatisticsFunctions(in: formatted, outputFormat: outputFormat)
            appendMathEvent(
                ruleID: "math.formatter.statistics-functions",
                before: before,
                after: formatted,
                reason: "Map spoken statistics functions into notation forms.",
                events: &events
            )
        }

        do {
            let before = formatted
            formatted = applyRules(fixedPhraseRules, to: formatted, outputFormat: outputFormat)
            appendMathEvent(
                ruleID: "math.formatter.fixed-phrases",
                before: before,
                after: formatted,
                reason: "Apply fixed phrase mappings for common math/statistics expressions.",
                events: &events
            )
        }

        do {
            let before = formatted
            formatted = applyTemplateRules(to: formatted, outputFormat: outputFormat)
            formatted = formatted.replacingOccurrences(of: compactASRChainSeparator, with: "")
            appendMathEvent(
                ruleID: "math.formatter.template-rules",
                before: before,
                after: formatted,
                reason: "Apply template-driven symbol, subscript, and modifier rules.",
                events: &events
            )
        }

        do {
            let before = formatted
            formatted = applyGreekLetterRules(to: formatted, outputFormat: outputFormat)
            appendMathEvent(
                ruleID: "math.formatter.greek-letter-rules",
                before: before,
                after: formatted,
                reason: "Normalize spoken, LaTeX, and unicode Greek letter variants.",
                events: &events
            )
        }

        return formatted
    }

    private static func appendMathEvent(
        ruleID: String,
        before: String,
        after: String,
        reason: String,
        events: inout [PostProcessingEvent]
    ) {
        guard before != after else {
            return
        }
        events.append(
            PostProcessingEvent(
                ruleID: ruleID,
                rangeDescription: "segment",
                before: before,
                after: after,
                reason: reason,
                confidence: .high
            )
        )
    }

    private static func applyRules(
        _ rules: [Rule],
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        var formatted = text
        for rule in rules {
            let regex = try! NSRegularExpression(pattern: rule.pattern, options: rule.options)
            let replacement = outputFormat == .latex ? rule.latexReplacement : rule.unicodeReplacement
            formatted = replacingMatches(in: formatted, using: regex, replacement: replacement)
        }
        return formatted
    }

    private static func applyTemplateRules(
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        var formatted = text
        formatted = applyCompactedAsrSubscriptRules(to: formatted, outputFormat: outputFormat)
        formatted = applySubscriptRangeRules(to: formatted, outputFormat: outputFormat)
        formatted = applyCombinedSubscriptPowerRule(to: formatted, outputFormat: outputFormat)
        formatted = applySubscriptThenHatRule(to: formatted, outputFormat: outputFormat)
        formatted = applyExplicitSubscriptRule(to: formatted, outputFormat: outputFormat)
        formatted = applyImplicitSubscriptRule(to: formatted, outputFormat: outputFormat)
        formatted = applyCompactedModifierRules(to: formatted, outputFormat: outputFormat)

        let suffixRules: [(String, SymbolModifier)] = [
            (#"(?i:\s+double\s+prime\b)"#, .doublePrime),
            (#"(?i:\s+double\s+dot\b)"#, .doubleDot),
            (#"(?i:\s+transpose\b)"#, .transpose),
            (#"(?i:\s+inverse\b)"#, .inverse),
            (#"(?i:\s+(?:square|squared)\b)"#, .squared),
            (#"(?i:\s+(?:cube|cubed)\b)"#, .cubed),
            (#"(?i:\s+(?:hat|head)\b)"#, .hat),
            (#"(?i:\s+bar\b)"#, .bar),
            (#"(?i:\s+tilde\b)"#, .tilde),
            (#"(?i:\s+dot\b)"#, .dot),
            (#"(?i:\s+prime\b)"#, .prime),
            (#"(?i:\s+(?:star|asterisk)\b)"#, .star)
        ]

        for (suffixPattern, modifier) in suffixRules {
            formatted = applySymbolModifierRule(
                to: formatted,
                suffixPattern: suffixPattern,
                modifier: modifier,
                outputFormat: outputFormat
            )
        }
        return formatted
    }

    private static func applySubscriptThenHatRule(
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let pattern = templateSymbolPattern + #"(?i:\s+sub\s+)("# + subscriptIndexPattern + #")(?i:\s+(hat|head)\b)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        return replacingMatches(in: text, using: regex) { match, source in
            guard let base = symbolAtom(from: group(1, in: match, source: source)),
                  let index = subscriptIndexExpression(from: group(2, in: match, source: source)),
                  MathLexicon.modifier(from: group(3, in: match, source: source)) == .hat else {
                return nil
            }

            let expression = MathExpression.subscripted(
                base: .modified(base: .symbol(base), modifier: .hat),
                index: index
            )
            return MathRenderer.render(expression, outputFormat: outputFormat)
        }
    }

    private static func applyCombinedSubscriptPowerRule(
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let pattern = templateSymbolPattern + #"(?i:\s+sub\s+)("# + subscriptIndexPattern + #")(?i:\s+(?:square|squared)\b)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        return replacingMatches(in: text, using: regex) { match, source in
            guard let symbol = symbol(from: group(1, in: match, source: source)),
                  let index = subscriptIndex(from: group(2, in: match, source: source)) else {
                return nil
            }
            let subscripted = formattedSubscript(symbol: symbol, index: index, outputFormat: outputFormat)
            return outputFormat == .latex ? "\(subscripted)^2" : "\(subscripted)²"
        }
    }

    private static func applyExplicitSubscriptRule(
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let pattern = templateSymbolPattern + #"(?i:\s+sub\s+)("# + subscriptIndexPattern + #")\b"#
        let regex = try! NSRegularExpression(pattern: pattern)
        return replacingMatches(in: text, using: regex) { match, source in
            guard let symbol = symbol(from: group(1, in: match, source: source)),
                  let index = subscriptIndex(from: group(2, in: match, source: source)) else {
                return nil
            }
            return formattedSubscript(symbol: symbol, index: index, outputFormat: outputFormat)
        }
    }

    private static func applyImplicitSubscriptRule(
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let pattern = templateSymbolPattern + #"(?i:\s+(i\s+t|j\s+t|t\s+minus\s+one|t\s+plus\s+one)\b)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        return replacingMatches(in: text, using: regex) { match, source in
            guard let symbol = symbol(from: group(1, in: match, source: source)),
                  let index = subscriptIndex(from: group(2, in: match, source: source)) else {
                return nil
            }
            return formattedSubscript(symbol: symbol, index: index, outputFormat: outputFormat)
        }
    }

    private static func applySubscriptRangeRules(
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        var formatted = text

        let explicitPattern = templateSymbolPattern + #"(?i:\s+sub\s+)("# + subscriptIndexPattern + #")(?i:\s+to\s+)("# + subscriptIndexPattern + #")\b"#
        let explicitRegex = try! NSRegularExpression(pattern: explicitPattern)
        formatted = replacingMatches(in: formatted, using: explicitRegex) { match, source in
            guard let symbol = symbol(from: group(1, in: match, source: source)),
                  let start = subscriptIndex(from: group(2, in: match, source: source)),
                  let end = subscriptIndex(from: group(3, in: match, source: source)) else {
                return nil
            }
            return formattedSubscriptRange(symbol: symbol, start: start, end: end, outputFormat: outputFormat)
        }

        let spokenPattern = templateSymbolPattern + #"\s+("# + subscriptIndexPattern + #")(?i:\s+to\s+)(?:"# + templateSymbolPattern + #"\s+)?("# + subscriptIndexPattern + #")\b"#
        let spokenRegex = try! NSRegularExpression(pattern: spokenPattern)
        formatted = replacingMatches(in: formatted, using: spokenRegex) { match, source in
            guard let symbol = symbol(from: group(1, in: match, source: source)),
                  let start = subscriptIndex(from: group(2, in: match, source: source)),
                  let end = subscriptIndex(from: group(4, in: match, source: source)) else {
                return nil
            }
            return formattedSubscriptRange(symbol: symbol, start: start, end: end, outputFormat: outputFormat)
        }

        let compactPattern = #"(?i)\b([A-Z])([0-9])\s+to\s+\1([0-9])\b"#
        let compactRegex = try! NSRegularExpression(pattern: compactPattern)
        formatted = replacingMatches(in: formatted, using: compactRegex) { match, source in
            guard let symbol = symbol(from: group(1, in: match, source: source)),
                  let start = subscriptIndex(from: group(2, in: match, source: source)),
                  let end = subscriptIndex(from: group(3, in: match, source: source)) else {
                return nil
            }
            return formattedSubscriptRange(symbol: symbol, start: start, end: end, outputFormat: outputFormat)
        }

        return formatted
    }

    private static func applyCompactedAsrSubscriptRules(
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        var formatted = text
        let compactRules: [(String, MathSymbol, String)] = [
            (#"(?i)\bYIT\b"#, MathSymbol(spoken: "y", latex: "y", unicode: "y"), "i t"),
            (#"(?i)\bXIT\b"#, MathSymbol(spoken: "x", latex: "x", unicode: "x"), "i t"),
            (#"(?i)\bRT\s+minus\s+1\b"#, MathSymbol(spoken: "r", latex: "r", unicode: "r"), "t minus one"),
            (#"(?i)\bPT\s+plus\s+1\b"#, MathSymbol(spoken: "p", latex: "p", unicode: "p"), "t plus one")
        ]

        for (pattern, symbol, indexPhrase) in compactRules {
            guard let index = subscriptIndex(from: indexPhrase) else {
                continue
            }
            let regex = try! NSRegularExpression(pattern: pattern)
            formatted = replacingMatches(
                in: formatted,
                using: regex,
                replacement: formattedSubscript(symbol: symbol, index: index, outputFormat: outputFormat)
            )
        }
        return formatted
    }

    private static func applyCompactedModifierRules(
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let compactModifiers: [(String, SymbolModifier)] = [
            ("doubleprime", .doublePrime),
            ("double dot", .doubleDot),
            ("doubledot", .doubleDot),
            ("transpose", .transpose),
            ("inverse", .inverse),
            ("squared", .squared),
            ("square", .squared),
            ("cubed", .cubed),
            ("cube", .cubed),
            ("head", .hat),
            ("hat", .hat),
            ("bar", .bar),
            ("tilde", .tilde),
            ("prime", .prime),
            ("star", .star),
            ("asterisk", .star)
        ]
        let spoken = templateGreekSymbols
            .map(\.spoken)
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let suffix = compactModifiers
            .map(\.0)
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let modifierBySuffix = Dictionary(uniqueKeysWithValues: compactModifiers)
        let regex = try! NSRegularExpression(pattern: #"(?i)\b("# + spoken + #")("# + suffix + #")\b"#)

        return replacingMatches(in: text, using: regex) { match, source in
            let symbolToken = group(1, in: match, source: source)
            let suffixToken = group(2, in: match, source: source)
                .lowercased()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            guard let symbol = symbol(from: symbolToken),
                  let modifier = modifierBySuffix[suffixToken] else {
                return nil
            }
            return formattedSymbol(symbol, modifier: modifier, outputFormat: outputFormat)
        }
    }

    private static func applySymbolModifierRule(
        to text: String,
        suffixPattern: String,
        modifier: SymbolModifier,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let regex = try! NSRegularExpression(pattern: templateSymbolPattern + suffixPattern)
        return replacingMatches(in: text, using: regex) { match, source in
            guard let symbol = symbol(from: group(1, in: match, source: source)) else {
                return nil
            }
            return formattedSymbol(symbol, modifier: modifier, outputFormat: outputFormat)
        }
    }

    private static func applyGreekLetterRules(
        to text: String,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let orderedSymbols = allGreekSymbols.sorted { $0.spoken.count > $1.spoken.count }
        let rules = orderedSymbols.flatMap { symbol in
            let plainEnglishContinuationGuard = symbol.spoken.hasPrefix("variant ")
                ? #"(?!\s+(?:is|are|means|refers)\b)"#
                : ""
            let variantPrefixGuard = variantGreekBaseNames.contains(symbol.spoken)
                ? #"(?<!variant )"#
                : ""
            var symbolRules = [
                Rule(
                    pattern: NSRegularExpression.escapedPattern(for: symbol.unicode),
                    latexReplacement: symbol.latex,
                    unicodeReplacement: symbol.unicode
                ),
                Rule(
                    pattern: #"(?i)(?<!\\)"# + variantPrefixGuard + #"\b"# + NSRegularExpression.escapedPattern(for: symbol.spoken) + #"\b"# + plainEnglishContinuationGuard,
                    latexReplacement: symbol.latex,
                    unicodeReplacement: symbol.unicode
                )
            ]
            if symbol.latex.hasPrefix("\\") {
                symbolRules.insert(
                    Rule(
                        pattern: NSRegularExpression.escapedPattern(for: symbol.latex) + #"\b"#,
                        latexReplacement: symbol.latex,
                        unicodeReplacement: symbol.unicode
                    ),
                    at: 0
                )
            }
            return symbolRules
        }
        return applyRules(rules, to: text, outputFormat: outputFormat)
    }

    private static func formattedSymbol(
        _ symbol: MathSymbol,
        modifier: SymbolModifier,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        switch (modifier, outputFormat) {
        case (.hat, .latex):
            return #"\hat{"# + symbol.latex + "}"
        case (.hat, .unicode):
            return symbol.unicode + "\u{0302}"
        case (.bar, .latex):
            return #"\bar{"# + symbol.latex + "}"
        case (.bar, .unicode):
            return symbol.unicode + "\u{0304}"
        case (.tilde, .latex):
            return #"\tilde{"# + symbol.latex + "}"
        case (.tilde, .unicode):
            return symbol.unicode + "\u{0303}"
        case (.dot, .latex):
            return #"\dot{"# + symbol.latex + "}"
        case (.dot, .unicode):
            return symbol.unicode + "\u{0307}"
        case (.doubleDot, .latex):
            return #"\ddot{"# + symbol.latex + "}"
        case (.doubleDot, .unicode):
            return symbol.unicode + "\u{0308}"
        case (.prime, .latex):
            return symbol.latex + "'"
        case (.prime, .unicode):
            return symbol.unicode + "′"
        case (.doublePrime, .latex):
            return symbol.latex + "''"
        case (.doublePrime, .unicode):
            return symbol.unicode + "″"
        case (.star, .latex):
            return symbol.latex + "^*"
        case (.star, .unicode):
            return symbol.unicode + "*"
        case (.transpose, .latex):
            return symbol.latex + #"^\top"#
        case (.transpose, .unicode):
            return symbol.unicode + "ᵀ"
        case (.inverse, .latex):
            return symbol.latex + "^{-1}"
        case (.inverse, .unicode):
            return symbol.unicode + "⁻¹"
        case (.squared, .latex):
            return symbol.latex + "^2"
        case (.squared, .unicode):
            return symbol.unicode + "²"
        case (.cubed, .latex):
            return symbol.latex + "^3"
        case (.cubed, .unicode):
            return symbol.unicode + "³"
        }
    }
    private static func formattedSubscript(
        symbol: MathSymbol,
        index: SubscriptIndex,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let expression = MathExpression.subscripted(
            base: .symbol(
                MathSymbolAtom(
                    spoken: symbol.spoken,
                    latex: symbol.latex,
                    unicode: symbol.unicode
                )
            ),
            index: .symbol(
                MathSymbolAtom(
                    spoken: index.primarySpoken,
                    latex: index.latex,
                    unicode: index.unicode
                )
            )
        )
        return MathRenderer.render(expression, outputFormat: outputFormat)
    }

    private static func formattedSubscriptRange(
        symbol: MathSymbol,
        start: SubscriptIndex,
        end: SubscriptIndex,
        outputFormat: MathNotationOutputFormat
    ) -> String {
        let startTerm = formattedSubscript(symbol: symbol, index: start, outputFormat: outputFormat)
        let endTerm = formattedSubscript(symbol: symbol, index: end, outputFormat: outputFormat)
        return "\(startTerm) to \(endTerm)"
    }

    private static func symbol(from token: String) -> MathSymbol? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("capital ") || lowercased.hasPrefix("big ") {
            guard let letter = trimmed.split(separator: " ").last?.uppercased(), letter.count == 1 else {
                return nil
            }
            return MathSymbol(spoken: letter, latex: letter, unicode: letter)
        }
        if let symbol = greekBySpoken[lowercased] {
            return symbol
        }
        if let symbol = greekByLatex[trimmed] {
            return symbol
        }
        if let symbol = greekByUnicode[trimmed] {
            return symbol
        }
        if trimmed.count == 1,
           let scalar = trimmed.unicodeScalars.first,
           CharacterSet.letters.contains(scalar) {
            return MathSymbol(spoken: trimmed, latex: trimmed, unicode: trimmed)
        }
        return nil
    }

    private static func subscriptIndex(from token: String) -> SubscriptIndex? {
        MathScriptCatalog.subscriptIndex(from: token)
    }

    private static func symbolAtom(from token: String) -> MathSymbolAtom? {
        MathLexicon.symbol(from: token, uppercaseLatinForStatistics: true)
    }

    private static func subscriptIndexExpression(from token: String) -> MathExpression? {
        guard let index = subscriptIndex(from: token) else {
            return nil
        }
        return .symbol(
            MathSymbolAtom(
                spoken: index.primarySpoken,
                latex: index.latex,
                unicode: index.unicode
            )
        )
    }

    private static func group(
        _ index: Int,
        in match: NSTextCheckingResult,
        source: NSString
    ) -> String {
        guard index < match.numberOfRanges else { return "" }
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return "" }
        return source.substring(with: range)
    }

    private static func replacingMatches(
        in text: String,
        using regex: NSRegularExpression,
        replacement: String
    ) -> String {
        replacingMatches(in: text, using: regex) { _, _ in replacement }
    }

    private static func replacingMatches(
        in text: String,
        using regex: NSRegularExpression,
        replacementProvider: (NSTextCheckingResult, NSString) -> String?
    ) -> String {
        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }

        let output = NSMutableString(string: text)
        for match in matches.reversed() {
            guard let replacement = replacementProvider(match, source) else { continue }
            output.replaceCharacters(in: match.range, with: replacement)
        }
        return output as String
    }
}
