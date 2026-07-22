import Foundation

struct MathSymbolDefinition: Equatable {
    let spoken: String
    let latex: String
    let unicode: String
    let parserAliases: [String]
    let formatterAliases: [String]

    init(
        spoken: String,
        latex: String,
        unicode: String,
        parserAliases: [String] = [],
        formatterAliases: [String] = []
    ) {
        self.spoken = spoken
        self.latex = latex
        self.unicode = unicode
        self.parserAliases = parserAliases
        self.formatterAliases = formatterAliases
    }

    var allParserForms: [String] {
        [spoken] + parserAliases + formatterAliases
    }

    var allFormatterSpokenForms: [String] {
        [spoken] + formatterAliases
    }
}

enum MathSymbolCatalog {
    static let lowerGreek: [MathSymbolDefinition] = [
        MathSymbolDefinition(spoken: "alpha", latex: #"\alpha"#, unicode: "α"),
        MathSymbolDefinition(spoken: "beta", latex: #"\beta"#, unicode: "β", parserAliases: ["bita"]),
        MathSymbolDefinition(spoken: "gamma", latex: #"\gamma"#, unicode: "γ"),
        MathSymbolDefinition(spoken: "delta", latex: #"\delta"#, unicode: "δ"),
        MathSymbolDefinition(spoken: "epsilon", latex: #"\epsilon"#, unicode: "ε"),
        MathSymbolDefinition(spoken: "zeta", latex: #"\zeta"#, unicode: "ζ"),
        MathSymbolDefinition(spoken: "eta", latex: #"\eta"#, unicode: "η"),
        MathSymbolDefinition(spoken: "theta", latex: #"\theta"#, unicode: "θ"),
        MathSymbolDefinition(spoken: "iota", latex: #"\iota"#, unicode: "ι"),
        MathSymbolDefinition(spoken: "kappa", latex: #"\kappa"#, unicode: "κ"),
        MathSymbolDefinition(spoken: "lambda", latex: #"\lambda"#, unicode: "λ"),
        MathSymbolDefinition(spoken: "mu", latex: #"\mu"#, unicode: "μ", parserAliases: ["mew"]),
        MathSymbolDefinition(spoken: "nu", latex: #"\nu"#, unicode: "ν"),
        MathSymbolDefinition(spoken: "xi", latex: #"\xi"#, unicode: "ξ"),
        MathSymbolDefinition(spoken: "omicron", latex: "o", unicode: "ο"),
        MathSymbolDefinition(spoken: "pi", latex: #"\pi"#, unicode: "π"),
        MathSymbolDefinition(spoken: "rho", latex: #"\rho"#, unicode: "ρ"),
        MathSymbolDefinition(spoken: "sigma", latex: #"\sigma"#, unicode: "σ"),
        MathSymbolDefinition(spoken: "tau", latex: #"\tau"#, unicode: "τ"),
        MathSymbolDefinition(spoken: "upsilon", latex: #"\upsilon"#, unicode: "υ"),
        MathSymbolDefinition(spoken: "phi", latex: #"\phi"#, unicode: "φ"),
        MathSymbolDefinition(spoken: "chi", latex: #"\chi"#, unicode: "χ"),
        MathSymbolDefinition(spoken: "psi", latex: #"\psi"#, unicode: "ψ"),
        MathSymbolDefinition(spoken: "omega", latex: #"\omega"#, unicode: "ω")
    ]

    static let upperGreek: [MathSymbolDefinition] = [
        MathSymbolDefinition(spoken: "capital gamma", latex: #"\Gamma"#, unicode: "Γ", formatterAliases: ["big gamma"]),
        MathSymbolDefinition(spoken: "capital delta", latex: #"\Delta"#, unicode: "Δ", formatterAliases: ["big delta"]),
        MathSymbolDefinition(spoken: "capital theta", latex: #"\Theta"#, unicode: "Θ", formatterAliases: ["big theta"]),
        MathSymbolDefinition(spoken: "capital lambda", latex: #"\Lambda"#, unicode: "Λ", formatterAliases: ["big lambda"]),
        MathSymbolDefinition(spoken: "capital xi", latex: #"\Xi"#, unicode: "Ξ", formatterAliases: ["big xi"]),
        MathSymbolDefinition(spoken: "capital pi", latex: #"\Pi"#, unicode: "Π", formatterAliases: ["big pi"]),
        MathSymbolDefinition(spoken: "capital sigma", latex: #"\Sigma"#, unicode: "Σ", formatterAliases: ["big sigma"]),
        MathSymbolDefinition(spoken: "capital upsilon", latex: #"\Upsilon"#, unicode: "Υ", formatterAliases: ["big upsilon"]),
        MathSymbolDefinition(spoken: "capital phi", latex: #"\Phi"#, unicode: "Φ", formatterAliases: ["big phi"]),
        MathSymbolDefinition(spoken: "capital psi", latex: #"\Psi"#, unicode: "Ψ", formatterAliases: ["big psi"]),
        MathSymbolDefinition(spoken: "capital omega", latex: #"\Omega"#, unicode: "Ω", formatterAliases: ["big omega"])
    ]

    static let variantGreek: [MathSymbolDefinition] = [
        MathSymbolDefinition(spoken: "varepsilon", latex: #"\varepsilon"#, unicode: "ϵ", formatterAliases: ["variant epsilon", "curly epsilon"]),
        MathSymbolDefinition(spoken: "vartheta", latex: #"\vartheta"#, unicode: "ϑ", formatterAliases: ["variant theta"]),
        MathSymbolDefinition(spoken: "varpi", latex: #"\varpi"#, unicode: "ϖ", formatterAliases: ["variant pi"]),
        MathSymbolDefinition(spoken: "varrho", latex: #"\varrho"#, unicode: "ϱ", formatterAliases: ["variant rho"]),
        MathSymbolDefinition(spoken: "varsigma", latex: #"\varsigma"#, unicode: "ς", formatterAliases: ["final sigma"]),
        MathSymbolDefinition(spoken: "varphi", latex: #"\varphi"#, unicode: "ϕ", formatterAliases: ["variant phi", "curly phi"])
    ]

    static let allGreek: [MathSymbolDefinition] = lowerGreek + upperGreek + variantGreek
    static let templateGreek: [MathSymbolDefinition] = lowerGreek + variantGreek
}

extension MathSymbolCatalog {
    static let asrArgumentSymbolPattern: String = {
        let greekAlternatives = allGreek
            .flatMap(\.allParserForms)
            .map(MathLexicon.normalizeSpaces)
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))

        return "(?:[A-Za-z]|\(greekAlternatives.joined(separator: "|")))"
    }()
}
