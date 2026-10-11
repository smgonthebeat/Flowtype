import Foundation

/// Every word the math layer knows lives here, so vocabulary changes never touch the parser.
/// Contract: docs/specs/2026-10-03-math-notation-rebuild/design.md (sections 3-7).
/// Strength values feed the evidence score: 2 = strong, 1 = medium, 0 = weak (design.md 6.1).
enum MathLexiconTables {
    // MARK: Greek

    struct Greek {
        let latex: String
        let unicode: String
        /// Math-dominant names (class A) convert on their own in a sentence; prose-common names
        /// (class B) need context (design.md 6.2 rule 2, default T2).
        let isMathDominant: Bool
    }

    /// Ordered: compact splitting tries names in this order (thetahat -> theta hat).
    static let greekOrder: [String] = [
        "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu",
        "nu", "xi", "omicron", "pi", "rho", "sigma", "tau", "upsilon", "phi", "chi", "psi", "omega"
    ]

    /// LaTeX and Unicode values match MathSymbolCatalog.lowerGreek.
    static let greek: [String: Greek] = [
        "alpha": Greek(latex: #"\alpha"#, unicode: "α", isMathDominant: false),
        "beta": Greek(latex: #"\beta"#, unicode: "β", isMathDominant: false),
        "gamma": Greek(latex: #"\gamma"#, unicode: "γ", isMathDominant: false),
        "delta": Greek(latex: #"\delta"#, unicode: "δ", isMathDominant: false),
        "epsilon": Greek(latex: #"\epsilon"#, unicode: "ε", isMathDominant: true),
        "zeta": Greek(latex: #"\zeta"#, unicode: "ζ", isMathDominant: true),
        "eta": Greek(latex: #"\eta"#, unicode: "η", isMathDominant: false),
        "theta": Greek(latex: #"\theta"#, unicode: "θ", isMathDominant: true),
        "iota": Greek(latex: #"\iota"#, unicode: "ι", isMathDominant: false),
        "kappa": Greek(latex: #"\kappa"#, unicode: "κ", isMathDominant: false),
        "lambda": Greek(latex: #"\lambda"#, unicode: "λ", isMathDominant: true),
        "mu": Greek(latex: #"\mu"#, unicode: "μ", isMathDominant: true),
        "nu": Greek(latex: #"\nu"#, unicode: "ν", isMathDominant: false),
        "xi": Greek(latex: #"\xi"#, unicode: "ξ", isMathDominant: false),
        "omicron": Greek(latex: "o", unicode: "ο", isMathDominant: false),
        "pi": Greek(latex: #"\pi"#, unicode: "π", isMathDominant: false),
        "rho": Greek(latex: #"\rho"#, unicode: "ρ", isMathDominant: true),
        "sigma": Greek(latex: #"\sigma"#, unicode: "σ", isMathDominant: true),
        "tau": Greek(latex: #"\tau"#, unicode: "τ", isMathDominant: true),
        "upsilon": Greek(latex: #"\upsilon"#, unicode: "υ", isMathDominant: true),
        "phi": Greek(latex: #"\phi"#, unicode: "φ", isMathDominant: true),
        "chi": Greek(latex: #"\chi"#, unicode: "χ", isMathDominant: false),
        "psi": Greek(latex: #"\psi"#, unicode: "ψ", isMathDominant: false),
        "omega": Greek(latex: #"\omega"#, unicode: "ω", isMathDominant: false),
        // Not Greek, but a named letter used the same way (log-likelihood: ell of theta).
        "ell": Greek(latex: #"\ell"#, unicode: "ℓ", isMathDominant: true)
    ]
    /// Names that read as a function before "of" (phi of x, ell of theta), like the letters f, g, h.
    static let functionNames: Set<String> = ["phi", "psi", "ell"]

    /// Names without an entry render as the Latin capital (capital alpha -> A).
    static let greekUpper: [String: (latex: String, unicode: String)] = [
        "gamma": (#"\Gamma"#, "Γ"), "delta": (#"\Delta"#, "Δ"), "theta": (#"\Theta"#, "Θ"),
        "lambda": (#"\Lambda"#, "Λ"), "xi": (#"\Xi"#, "Ξ"), "pi": (#"\Pi"#, "Π"), "sigma": (#"\Sigma"#, "Σ"),
        "upsilon": (#"\Upsilon"#, "Υ"), "phi": (#"\Phi"#, "Φ"), "psi": (#"\Psi"#, "Ψ"), "omega": (#"\Omega"#, "Ω"),
        "ell": ("L", "L")
    ]

    /// Spoken after variant / curly, or glued as varepsilon (default T8).
    static let greekVariant: [String: (latex: String, unicode: String)] = [
        "epsilon": (#"\varepsilon"#, "ϵ"), "theta": (#"\vartheta"#, "ϑ"), "pi": (#"\varpi"#, "ϖ"),
        "rho": (#"\varrho"#, "ϱ"), "sigma": (#"\varsigma"#, "ς"), "phi": (#"\varphi"#, "ϕ")
    ]

    /// Prefixes for a variant form and the names they apply to (nil: every name in greekVariant).
    /// "final sigma" comes from MathSymbolCatalog.variantGreek.
    static let variantPrefixes: [String: Set<String>?] = ["variant": nil, "curly": nil, "final": ["sigma"]]
    static let greekSpokenExtra: [String: String] = ["lamda": "lambda", "ksi": "xi"]

    /// Mishearings. A component recognised through an alias contributes no evidence (design.md 6.3).
    static let greekAliasOrder: [String] = [
        "better", "beat", "bata", "bita", "bad", "muse", "mew", "miu", "myu", "moo",
        "new", "pie", "fi", "fee", "row", "roe", "sigh", "tao", "kai", "cai"
    ]
    /// A misheard Greek name alone after a full function name (write standard error better in Swift) is
    /// medium evidence only when the function name has no determiner (the standard error better is prose)
    /// and the next word is one of these, the end of the sentence or punctuation.
    static let determiners: Set<String> = [
        "the", "a", "an", "this", "that", "these", "those", "its", "your", "my", "our", "their", "his", "her", "whose"
    ]
    static let bareAliasArgumentFollowers: Set<String> = [
        "in", "for", "and", "or", "is", "are", "was", "were", "equals", "with", "on", "from", "under", "here", "then",
        "so", "which", "where"
    ]
    static let greekAlias: [String: String] = [
        "better": "beta", "beat": "beta", "bata": "beta", "bita": "beta", "bad": "beta",
        "muse": "mu", "mew": "mu", "miu": "mu", "myu": "mu", "moo": "mu",
        "new": "nu", "pie": "pi", "fi": "phi", "fee": "phi", "row": "rho", "roe": "rho",
        "sigh": "psi", "tao": "tau", "kai": "chi", "cai": "chi"
    ]

    static let zhGreek: [String: String] = [
        "阿尔法": "alpha", "贝塔": "beta", "伽马": "gamma", "伽玛": "gamma", "德尔塔": "delta",
        "艾普西隆": "epsilon", "伊普西隆": "epsilon", "西塔": "theta", "拉姆达": "lambda", "兰姆达": "lambda",
        "缪": "mu", "西格玛": "sigma", "欧米伽": "omega", "欧米茄": "omega"
    ]
    static let zhGreekAlias: [String: String] = [
        "谬": "mu", "派": "pi", "柔": "rho", "陶": "tau", "斐": "phi", "开": "chi", "凯": "chi"
    ]

    /// Collocations in which the Greek name is ordinary prose (checked on the next word).
    static let greekNextBlock: [String: Set<String>] = [
        "alpha": ["version", "versions", "release", "test", "tests", "testing", "tester", "testers", "build",
                  "builds", "phase", "stage", "male", "males", "channel", "romeo", "dog", "wolf", "geek"],
        "beta": ["version", "versions", "release", "test", "tests", "testing", "tester", "testers", "build",
                 "builds", "phase", "stage", "channel", "program", "programme", "feature", "features", "access",
                 "blocker", "blockers", "carotene", "fish"],
        "gamma": ["ray", "rays", "radiation", "knife"],
        "delta": ["airlines", "air", "flight", "flights", "variant", "force", "lounge", "region", "plane",
                  "blues", "between", "in", "is", "was"],
        "sigma": ["male", "males", "chi", "grindset", "level"],
        "lambda": ["function", "functions", "expression", "expressions", "calculus", "layer", "layers"],
        "pi": ["day", "zero", "pico", "board"],
        "omega": ["three", "3", "watch", "watches", "speedmaster", "seamaster"],
        "omicron": ["variant", "wave", "strain", "surge"],
        "chi": ["tea", "omega"],
        "kappa": ["alpha", "brand", "tracksuit", "jacket", "kappa"],
        "nu": ["skin", "metal"],
        "theta": ["tau", "chi"],
        "phi": ["beta", "delta"],
        "tau": ["beta"],
        "zeta": ["jones", "psi"],
        "iota": ["of"]
    ]
    /// Collocations in which the Greek name is ordinary prose (checked on the previous word).
    static let greekPreviousBlock: [String: Set<String>] = [
        "sigma": ["six", "lean"], "pi": ["raspberry", "magnum"], "chi": ["tai", "sigma", "theta"],
        "lambda": ["aws", "amazon"], "kappa": ["beta", "phi"], "beta": ["phi"], "iota": ["one", "an", "single"],
        "delta": ["the", "river", "mississippi", "nile", "a"], "omicron": ["the"], "alpha": ["the", "an"],
        "omega": ["the", "an"], "tau": ["theta"], "eta": ["your", "my", "the", "an", "our", "his", "her"],
        "psi": ["the"]
    ]
    static let zhGreekNextBlock: [String] = [
        "测试", "版", "阶段", "航空", "变种", "变异", "射线", "函数", "表达式", "男", "鱼油", "收益", "系数很", "客"
    ]
    /// A previous word that licenses a prose-common Greek name (design.md 6.2 rule 2).
    static let greekCuePrevious: Set<String> = [
        "parameter", "parameters", "coefficient", "coefficients", "estimator", "estimate", "estimates", "where",
        "let", "level", "rate", "constant", "denote", "denoted", "symbol"
    ]
    static let zhCuePrevious: [String] = ["参数", "系数", "其中", "设", "令", "记为", "符号"]

    // MARK: Latin letters

    /// Letters that are usually labels, grades, pronouns or articles in prose: weak evidence.
    static let labelProneLetters: Set<Character> = ["a", "A", "B", "C", "D", "F", "I"]
    /// A single letter or number right after one of these words belongs to the label (part B, Q three).
    static let labelWords: Set<String> = [
        "exercise", "sheet", "question", "q", "part", "problem", "homework", "chapter", "section", "lecture",
        "week", "page", "figure", "table", "example", "option", "plan", "grade", "vitamin", "model", "type",
        "step", "version", "item", "appendix", "class", "group", "level", "phase", "stage", "letter", "row",
        "column", "gate", "terminal", "room", "hepatitis", "generation", "gen", "iphone", "series", "tesla",
        "mr", "ms", "dr", "team", "side", "block", "unit", "module", "paper", "track", "route", "line", "exit",
        "zone", "tier", "rank", "size", "vitamins", "roman"
    ]
    /// Implicit letter subscripts: x i -> x_i.
    static let indexLetters: Set<String> = ["i", "j", "k"]
    /// Juxtaposed letters that may extend an explicit subscript: sub i j.
    static let subscriptLetters: Set<String> = ["i", "j", "k", "t", "n", "m"]
    /// A glued letter + modifier is never split when it is an English word.
    static let compactDenyList: Set<String> = ["what", "that", "chat", "phat", "ghat", "khat", "ahead", "shat", "abar"]
    static let compactSubscriptTails: Set<String> = ["i", "j", "k", "n", "t"]
    /// Letters that name random variables: a glued pair (XY) after expectation, covariance or
    /// correlation is read letter by letter, and a run of them after expectation is a product (E[XY]).
    static let randomVariableLetters: Set<Character> = ["x", "y", "z"]
    /// Words between two indices of one letter: x sub zero to nine -> x₀ to x₉ (owner decision 2026-10-09).
    static let indexRangeWords: Set<String> = ["to", "through"]
    static let zhIndexRangeWords: Set<String> = ["到"]
    /// Hyphenated spellings the recogniser writes for one math word; other hyphenated compounds are prose.
    static let hyphenatedWords: Set<String> = ["p-value", "co-variance"]
    /// English words the recogniser splits into a letter and an accent word (What -> W hat).
    /// Such a split counts as a mishearing alias: it carries no evidence of its own (design.md 6.3).
    static let splitEnglishWords: Set<String> = ["what", "that"]
    /// "E X" with no "of": expectation of a random-variable letter, only as a whole utterance
    /// (the bare letter name is an alias-strength cue; inside a sentence it is spelling, "what is E T").
    static let bareExpectationArguments: Set<String> = ["x", "y", "z", "t"]

    // MARK: Numbers

    static let units: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "naught": 0, "nought": 0
    ]
    static let teens: [String: Int] = EnglishNumberGrammar.teens
    static let tens: [String: Int] = EnglishNumberGrammar.tens
    static let ordinalPowers: [String: String] = [
        "second": "2", "third": "3", "fourth": "4", "fifth": "5", "sixth": "6", "seventh": "7",
        "eighth": "8", "ninth": "9", "tenth": "10", "nth": "n", "kth": "k", "mth": "m"
    ]
    /// Han characters that may form a numeral inside a formula.
    static let zhNumeralCharacters: Set<Character> = [
        "零", "〇", "一", "二", "两", "三", "四", "五", "六", "七", "八", "九", "十", "百", "千", "万"
    ]
    static let zhDigits: [Character: Int] = [
        "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
    ]

    // MARK: Operators (phrase -> (operator, strength))

    static let relations: [String: (MathRelationOperator, Int)] = [
        "equals": (.equal, 2), "is equal to": (.equal, 2), "equal to": (.equal, 2), "is equals to": (.equal, 2), "equals to": (.equal, 2),
        "is not equal to": (.notEqual, 2), "not equal to": (.notEqual, 2), "does not equal": (.notEqual, 2),
        "is greater than or equal to": (.greaterEqual, 2), "is less than or equal to": (.lessEqual, 2),
        "is greater than": (.greater, 2), "is less than": (.less, 2),
        "greater than or equal to": (.greaterEqual, 1), "less than or equal to": (.lessEqual, 1),
        // "equals to" is a common non-native form of "equal to" (owner test 2026-10-09).
        "is greater than or equals to": (.greaterEqual, 2), "is less than or equals to": (.lessEqual, 2),
        "greater than or equals to": (.greaterEqual, 1), "less than or equals to": (.lessEqual, 1),
        "greater than": (.greater, 1), "less than": (.less, 1),
        "is at least": (.greaterEqual, 1), "is at most": (.lessEqual, 1),
        "at least": (.greaterEqual, 0), "at most": (.lessEqual, 0),
        "is approximately equal to": (.approximately, 2), "approximately equal to": (.approximately, 2),
        "is approximately": (.approximately, 1), "approximately equals": (.approximately, 2),
        "is proportional to": (.proportional, 2), "proportional to": (.proportional, 1),
        "goes to": (.tendsTo, 1), "tends to": (.tendsTo, 1), "approaches": (.tendsTo, 1),
        "implies": (.implies, 1), "belongs to": (.elementOf, 1), "is an element of": (.elementOf, 2),
        "is in": (.elementOf, 0),
        "converges in distribution to": (.convergesInDistribution, 2),
        "converges in probability to": (.convergesInProbability, 2)
    ]
    static let zhRelations: [String: (MathRelationOperator, Int)] = [
        "等于": (.equal, 2), "不等于": (.notEqual, 2), "大于等于": (.greaterEqual, 2), "大于或等于": (.greaterEqual, 2),
        "小于等于": (.lessEqual, 2), "小于或等于": (.lessEqual, 2), "大于": (.greater, 1), "小于": (.less, 1),
        "约等于": (.approximately, 2), "正比于": (.proportional, 2), "趋于": (.tendsTo, 1), "趋向于": (.tendsTo, 1),
        "趋近于": (.tendsTo, 1), "属于": (.elementOf, 1), "依分布收敛于": (.convergesInDistribution, 2),
        "依概率收敛于": (.convergesInProbability, 2)
    ]
    static let additions: [String: (MathAddOperator, Int)] = [
        "plus or minus": (.plusMinus, 2), "plus minus": (.plusMinus, 2), "plus": (.plus, 2), "minus": (.minus, 2)
    ]
    static let zhAdditions: [String: (MathAddOperator, Int)] = [
        "正负": (.plusMinus, 2), "加减": (.plusMinus, 2), "加上": (.plus, 2), "加": (.plus, 2), "减去": (.minus, 2),
        "减": (.minus, 2)
    ]
    static let multiplications: [String: Int] = ["times": 1, "multiplied by": 2]
    static let zhMultiplications: [String: Int] = ["乘以": 2, "乘上": 2, "乘": 1]
    /// Division words: all over takes the whole additive expression as the numerator (design.md 5.5).
    static let divisions: [String: (isAllOver: Bool, strength: Int)] = [
        "all over": (true, 2), "divided by": (false, 2), "over": (false, 0)
    ]
    static let zhDivisions: [String: (isAllOver: Bool, strength: Int)] = ["除以": (false, 2)]

    // MARK: Postfix modifiers

    static let accents: [String: MathAccent] = [
        "hat": .hat, "bar": .bar, "overbar": .bar, "tilde": .tilde, "double dot": .doubleDot, "dot": .dot
    ]
    static let accentAliases: [String: MathAccent] = ["head": .hat]
    static let marks: [String: MathMark] = [
        "double prime": .doublePrime, "prime": .prime, "star": .star, "asterisk": .star,
        "transpose": .transpose, "inverse": .inverse
    ]
    /// Mishearings of a mark (capital A in verse). Like accentAliases, they carry no evidence (design.md 6.3).
    static let markAliases: [String: MathMark] = ["in verse": .inverse]
    static let powers: [String: String] = ["squared": "2", "cubed": "3", "square": "2", "cube": "3"]
    /// Mishearings of a power word (Sigma Squid). Like accentAliases, they carry no evidence (design.md 6.3).
    static let powerAliases: [String: String] = ["squid": "2"]
    static let zhAccents: [String: MathAccent] = ["帽子": .hat, "帽": .hat, "拔": .bar, "波浪号": .tilde, "波浪": .tilde]
    static let zhMarks: [String: MathMark] = ["一撇": .prime, "撇": .prime, "星": .star, "转置": .transpose, "的逆": .inverse]
    static let zhPowers: [String: String] = ["的平方": "2", "平方": "2", "的立方": "3", "立方": "3"]
    /// Words a Greek name may be glued to (thetahat, Xbar).
    static let compactModifiers: Set<String> = Set(accents.keys).union(accentAliases.keys).union(powers.keys)
        .union(["prime", "star", "tilde"])
    /// Han words that contain a math word but are ordinary text: area units, and percent phrases that
    /// belong to the numeric layer (百分之五十 is 50%, not the fraction 50/100). Order matters.
    static let zhUnitBlock: [String] = [
        "平方公里", "平方厘米", "平方英尺", "平方千米", "立方厘米", "平方米", "立方米", "百分之", "千分之", "万分之"
    ]

    // MARK: Functions

    struct FunctionSpec {
        let latex: String
        let unicode: String
        let usesSquareBrackets: Bool
        /// Statistics functions take random variables: their Latin arguments are upper case (D5).
        let uppercasesArguments: Bool
    }

    static let functions: [MathFunctionID: FunctionSpec] = [
        .expectation: FunctionSpec(latex: #"\mathbb{E}"#, unicode: "E", usesSquareBrackets: true, uppercasesArguments: true),
        .variance: FunctionSpec(latex: #"\operatorname{Var}"#, unicode: "Var", usesSquareBrackets: false, uppercasesArguments: true),
        .covariance: FunctionSpec(latex: #"\operatorname{Cov}"#, unicode: "Cov", usesSquareBrackets: false, uppercasesArguments: true),
        .correlation: FunctionSpec(latex: #"\operatorname{Corr}"#, unicode: "Corr", usesSquareBrackets: false, uppercasesArguments: true),
        .standardDeviation: FunctionSpec(latex: #"\operatorname{SD}"#, unicode: "SD", usesSquareBrackets: false, uppercasesArguments: true),
        .standardError: FunctionSpec(latex: #"\operatorname{SE}"#, unicode: "SE", usesSquareBrackets: false, uppercasesArguments: true),
        .probability: FunctionSpec(latex: "P", unicode: "P", usesSquareBrackets: false, uppercasesArguments: true),
        .log: FunctionSpec(latex: #"\log"#, unicode: "log", usesSquareBrackets: false, uppercasesArguments: false),
        .ln: FunctionSpec(latex: #"\ln"#, unicode: "ln", usesSquareBrackets: false, uppercasesArguments: false),
        .exp: FunctionSpec(latex: #"\exp"#, unicode: "exp", usesSquareBrackets: false, uppercasesArguments: false),
        .sin: FunctionSpec(latex: #"\sin"#, unicode: "sin", usesSquareBrackets: false, uppercasesArguments: false),
        .cos: FunctionSpec(latex: #"\cos"#, unicode: "cos", usesSquareBrackets: false, uppercasesArguments: false),
        .tan: FunctionSpec(latex: #"\tan"#, unicode: "tan", usesSquareBrackets: false, uppercasesArguments: false),
        .max: FunctionSpec(latex: #"\max"#, unicode: "max", usesSquareBrackets: false, uppercasesArguments: false),
        .min: FunctionSpec(latex: #"\min"#, unicode: "min", usesSquareBrackets: false, uppercasesArguments: false)
    ]

    struct FunctionPhrase {
        let id: MathFunctionID
        /// Short forms (var, cov, e of) take a single symbol and abstain before another letter.
        let isShortForm: Bool
        let isAlias: Bool
    }

    static let functionPhrases: [String: FunctionPhrase] = {
        var table: [String: FunctionPhrase] = [:]
        func add(_ id: MathFunctionID, short: Bool = false, alias: Bool = false, _ phrases: String...) {
            for phrase in phrases { table[phrase] = FunctionPhrase(id: id, isShortForm: short, isAlias: alias) }
        }
        add(.expectation, "expected value of", "expected value", "expectation of", "expectation")
        add(.expectation, short: true, "e of")
        add(.variance, "variance of", "variance", "var of")
        add(.variance, short: true, "var")
        add(.variance, alias: true, "variants of", "variant of")
        add(.covariance, "covariance of", "covariance", "cov of")
        add(.covariance, "co-variance of", "co-variance", "co variance of", "co variance")
        add(.covariance, short: true, "cov")
        add(.correlation, "correlation of", "correlation", "corr of")
        add(.correlation, short: true, "corr", "cor")
        add(.correlation, short: true, alias: true, "core")
        add(.standardDeviation, "standard deviation of", "standard deviation")
        add(.standardDeviation, short: true, "s d", "sd")
        add(.standardError, "standard error of", "standard error")
        add(.standardError, short: true, "s e", "se")
        add(.standardError, alias: true, "standard arrow of", "standard arrow", "standard era of", "standard era")
        add(.probability, "probability of", "probability that")
        add(.probability, short: true, "p of", "pr of")
        add(.ln, "natural log of", "natural log", "ln of", "ln")
        add(.log, "log of")
        add(.log, short: true, "log")
        add(.exp, "exp of")
        add(.exp, short: true, "exp")
        add(.sin, "sine of", "sine", "sin of")
        add(.sin, short: true, "sin")
        add(.cos, "cosine of", "cosine", "cos of")
        add(.cos, short: true, "cos")
        add(.tan, "tangent of", "tangent", "tan of")
        add(.max, "max of", "maximum of")
        add(.min, "min of", "minimum of")
        return table
    }()
    static let zhFunctions: [String: MathFunctionID] = [
        "期望": .expectation, "方差": .variance, "协方差": .covariance, "标准差": .standardDeviation,
        "标准误差": .standardError, "标准误": .standardError, "相关系数": .correlation, "概率": .probability,
        "自然对数": .ln, "对数": .log
    ]
    /// Letters that read as a function name before "of" (f of x); a, A and I never do.
    static let genericFunctionExcludedLetters: Set<Character> = ["a", "A", "I"]
    /// A short function name after one of these words is code or an instruction (var x = 1, press cos).
    static let codeCuePrevious: Set<String> = [
        "declare", "use", "using", "write", "type", "swift", "code", "let", "const", "function", "def", "press",
        "hit", "tap", "select", "choose", "run", "call"
    ]

    // MARK: Distributions

    struct DistributionSpec {
        let kind: MathDistributionKind
        let latexHead: String
        let unicodeHead: String
        let parameterCount: Int
    }

    static let distributions: [String: DistributionSpec] = [
        "standard normal": DistributionSpec(kind: .standardNormal, latexHead: "N", unicodeHead: "N", parameterCount: 0),
        "normal": DistributionSpec(kind: .normal, latexHead: "N", unicodeHead: "N", parameterCount: 2),
        "gaussian": DistributionSpec(kind: .normal, latexHead: "N", unicodeHead: "N", parameterCount: 2),
        "binomial": DistributionSpec(kind: .binomial, latexHead: #"\operatorname{Bin}"#, unicodeHead: "Bin", parameterCount: 2),
        "poisson": DistributionSpec(kind: .poisson, latexHead: #"\operatorname{Pois}"#, unicodeHead: "Pois", parameterCount: 1),
        "exponential": DistributionSpec(kind: .exponential, latexHead: #"\operatorname{Exp}"#, unicodeHead: "Exp", parameterCount: 1),
        "uniform": DistributionSpec(kind: .uniform, latexHead: "U", unicodeHead: "U", parameterCount: 2),
        "bernoulli": DistributionSpec(kind: .bernoulli, latexHead: #"\operatorname{Bernoulli}"#, unicodeHead: "Bernoulli", parameterCount: 1),
        "chi squared": DistributionSpec(kind: .chiSquared, latexHead: #"\chi^2"#, unicodeHead: "χ²", parameterCount: 1),
        "chi square": DistributionSpec(kind: .chiSquared, latexHead: #"\chi^2"#, unicodeHead: "χ²", parameterCount: 1),
        "student t": DistributionSpec(kind: .studentT, latexHead: "t", unicodeHead: "t", parameterCount: 1),
        "t": DistributionSpec(kind: .studentT, latexHead: "t", unicodeHead: "t", parameterCount: 1),
        "f": DistributionSpec(kind: .fisherF, latexHead: "F", unicodeHead: "F", parameterCount: 2),
        "beta": DistributionSpec(kind: .betaDistribution, latexHead: #"\operatorname{Beta}"#, unicodeHead: "Beta", parameterCount: 2),
        "gamma": DistributionSpec(kind: .gammaDistribution, latexHead: #"\operatorname{Gamma}"#, unicodeHead: "Gamma", parameterCount: 2)
    ]
    static let zhDistributions: [String: String] = [
        "标准正态分布": "standard normal", "正态分布": "normal", "二项分布": "binomial", "泊松分布": "poisson",
        "指数分布": "exponential", "均匀分布": "uniform", "卡方分布": "chi squared", "伯努利分布": "bernoulli"
    ]
    static let follows: Set<String> = ["is distributed as", "is distributed", "follows", "follow", "has", "is"]

    // MARK: Chinese structural words

    enum ZhRole {
        case sqrt, sqrtPostfix, negative, fenzhi, cifang, de, subscriptWord, sum, integral, limit, from, to, dui
        case dang, shi, infinity, follows, absolute, leftParen, rightParen, capital, lower, and, zai, condition
        case given, mean, variance, parameter, degreesOfFreedom, partial, point, product, chiSquared, noise
    }

    static let zhWords: [String: ZhRole] = [
        "根号": .sqrt, "开根号": .sqrtPostfix, "开方": .sqrtPostfix, "负": .negative, "分之": .fenzhi, "次方": .cifang,
        "的": .de, "下标": .subscriptWord, "求和": .sum, "积分": .integral, "极限": .limit, "从": .from, "到": .to,
        "对": .dui, "当": .dang, "时": .shi, "无穷大": .infinity, "正无穷": .infinity, "无穷": .infinity,
        "服从": .follows, "绝对值": .absolute, "括号": .leftParen, "左括号": .leftParen, "括回": .rightParen,
        "右括号": .rightParen, "反括号": .rightParen, "大写": .capital, "小写": .lower, "和": .and, "与": .and,
        "在": .zai, "的条件下": .condition, "条件下": .condition, "给定": .given, "均值为": .mean, "均值是": .mean,
        "均值": .mean, "方差为": .variance, "方差是": .variance, "参数为": .parameter, "参数是": .parameter,
        "自由度为": .degreesOfFreedom, "偏": .partial, "点": .point, "乘积": .product, "卡方": .chiSquared,
        "嗯": .noise, "呃": .noise, "额": .noise
    ]
    static let zhTendsTo: Set<String> = ["趋于", "趋向于", "趋近于"]
    static let hesitations: Set<String> = ["um", "uh", "uhm", "er", "erm", "hmm", "umm"]

    /// Every Han word the lexer matches (longest match first).
    static let zhVocabulary: Set<String> = {
        var words = Set<String>()
        words.formUnion(zhGreek.keys)
        words.formUnion(zhGreekAlias.keys)
        words.formUnion(zhRelations.keys)
        words.formUnion(zhAdditions.keys)
        words.formUnion(zhMultiplications.keys)
        words.formUnion(zhDivisions.keys)
        words.formUnion(zhAccents.keys)
        words.formUnion(zhMarks.keys)
        words.formUnion(zhPowers.keys)
        words.formUnion(zhFunctions.keys)
        words.formUnion(zhDistributions.keys)
        words.formUnion(zhWords.keys)
        return words
    }()
    static let zhVocabularyMaxLength: Int = zhVocabulary.map(\.count).max() ?? 1
}
