import Foundation

/// One tree, two outputs (design.md 7). LaTeX spans are wrapped in $...$ by the stage (D1).
enum MathNodeRenderer {
    private typealias T = MathLexiconTables

    static func render(_ node: MathNode, format: MathNotationOutputFormat) -> String {
        format == .latex ? latex(node) : unicode(node)
    }

    // MARK: Tables

    private static let accentLatex: [MathAccent: String] = [
        .hat: #"\hat"#, .bar: #"\bar"#, .tilde: #"\tilde"#, .dot: #"\dot"#, .doubleDot: #"\ddot"#
    ]
    private static let accentUnicode: [MathAccent: String] = [
        .hat: "\u{0302}", .bar: "\u{0304}", .tilde: "\u{0303}", .dot: "\u{0307}", .doubleDot: "\u{0308}"
    ]
    static let subscripts: [Character: Character] = Dictionary(uniqueKeysWithValues: zip(
        "0123456789+-=()aehijklmnoprstuvx−", "₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ₋"
    ))
    static let superscripts: [Character: Character] = Dictionary(uniqueKeysWithValues: zip(
        "0123456789+-=()abcdefghijklmnoprstuvwxyz−", "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖʳˢᵗᵘᵛʷˣʸᶻ⁻"
    ))
    private static let relationLatex: [MathRelationOperator: String] = [
        .equal: "=", .notEqual: #"\neq"#, .less: "<", .greater: ">", .lessEqual: #"\leq"#, .greaterEqual: #"\geq"#,
        .approximately: #"\approx"#, .proportional: #"\propto"#, .distributedAs: #"\sim"#, .elementOf: #"\in"#,
        .tendsTo: #"\to"#, .implies: #"\Rightarrow"#, .convergesInDistribution: #"\xrightarrow{d}"#,
        .convergesInProbability: #"\xrightarrow{p}"#, .iidAs: #"\overset{\text{i.i.d.}}{\sim}"#
    ]
    private static let relationUnicode: [MathRelationOperator: String] = [
        .equal: "=", .notEqual: "≠", .less: "<", .greater: ">", .lessEqual: "≤", .greaterEqual: "≥",
        .approximately: "≈", .proportional: "∝", .distributedAs: "∼", .elementOf: "∈", .tendsTo: "→",
        .implies: "⇒", .convergesInDistribution: "→ᵈ", .convergesInProbability: "→ᵖ", .iidAs: "∼ i.i.d."
    ]
    private static let bigLatex: [MathBigOperatorKind: String] = [
        .sum: #"\sum"#, .product: #"\prod"#, .integral: #"\int"#, .limit: #"\lim"#, .argMax: #"\arg\max"#,
        .argMin: #"\arg\min"#
    ]
    private static let bigUnicode: [MathBigOperatorKind: String] = [
        .sum: "∑", .product: "∏", .integral: "∫", .limit: "lim", .argMax: "arg max", .argMin: "arg min"
    ]

    /// Length in code points, as the scripts and braces rules count it (x̂ is two).
    private static func length(_ s: String) -> Int { s.unicodeScalars.count }

    private static func brace(_ s: String) -> String { length(s) == 1 ? s : "{" + s + "}" }

    // MARK: LaTeX

    static func latex(_ node: MathNode) -> String {
        switch node.content {
        case .number(let text):
            return text == "inf" ? #"\infty"# : text.replacingOccurrences(of: "%", with: #"\%"#)
        case .text(let text):
            return text
        case .index(let items):
            return items.map(latex).joined()
        case .symbol(let atom):
            return latex(atom)
        case .negate(let x):
            return "-" + latexWrapped(x)
        case .binary(let op, let l, let r, let tight):
            let symbol = op == .plus ? "+" : op == .minus ? "-" : #"\pm"#
            if tight { return latex(l) + symbol + latex(r) }
            return "\(latex(l)) \(symbol) \(op == .minus ? latexWrapped(r) : latex(r))"
        case .juxtaposition(let factors):
            var out = ""
            for (k, f) in factors.enumerated() {
                if k > 0, !(factors[k - 1].isNumber && !f.isNumber) { out += " " }
                out += latexWrapped(f)
            }
            return out
        case .product(let units):
            var out = latexWrapped(units[0])
            for (a, b) in zip(units, units.dropFirst()) {
                if b.isBigOperator {
                    out += " " + latexWrapped(b)
                    continue
                }
                let op = a.isNumber || b.isNumber ? #"\times"# : #"\cdot"#
                out += " \(op) \(latexWrapped(b))"
            }
            return out
        case .fraction(let n, let d, let inline):
            if inline { return latex(n) + "/" + latex(d) }
            return #"\frac{"# + latex(n) + "}{" + latex(d) + "}"
        case .group(let x):
            return "(" + latex(x) + ")"
        case .power(let base, let exponent):
            return latexPowerBase(base) + "^" + brace(latex(exponent))
        case .factorial(let x):
            return latexWrapped(x) + "!"
        case .root(let x, let degree):
            return (degree == 2 ? #"\sqrt{"# : #"\sqrt[3]{"#) + latex(x) + "}"
        case .absolute(let x, let norm):
            return norm ? #"\|"# + latex(x) + #"\|"# : "|" + latex(x) + "|"
        case .binomial(let n, let k):
            return #"\binom{"# + latex(n) + "}{" + latex(k) + "}"
        case .function(let head, let args, let given):
            let inner = args.map(latex).joined(separator: ", ")
            switch head {
            case .generic(let name):
                return latex(name) + "(" + inner + ")"
            case .named(let id):
                let spec = T.functions[id]!
                let condition = given.map { #" \mid "# + latex($0) } ?? ""
                return spec.latex + (spec.usesSquareBrackets ? "[" : "(") + inner + condition
                    + (spec.usesSquareBrackets ? "]" : ")")
            }
        case .relation(let first, let links):
            return links.reduce(latex(first)) { $0 + " \(relationLatex[$1.op]!) \(latex($1.rhs))" }
        case .distribution(let spec, let params, _):
            let parts = params.map(latex)
            switch spec.kind {
            case .studentT, .fisherF, .chiSquared:
                return spec.latexHead + "_" + brace(parts.joined(separator: ", "))
            default:
                return spec.latexHead + "(" + parts.joined(separator: ", ") + ")"
            }
        case .derivative(let partial, let of, let by):
            let d = partial ? #"\partial "# : "d"
            return #"\frac{"# + d + latex(of) + "}{" + d + latex(by) + "}"
        case .bigOperator(let op):
            var head = bigLatex[op.kind]!
            if op.kind == .limit, let variable = op.variable, let upper = op.upper {
                head += "_{" + latex(variable) + #" \to "# + latex(upper) + "}"
            } else if let lower = op.lower, let upper = op.upper {
                let low = op.variable.map { latex($0) + "=" + latex(lower) } ?? latex(lower)
                head += "_{" + low + "}^{" + latex(upper) + "}"
            } else if let variable = op.variable {
                head += "_{" + latex(variable) + "}"
            }
            guard let body = op.body else { return head }
            var out = head + " "
            if op.kind != .limit, case .binary = body.content {
                out += latexWrapped(body)
            } else {
                out += latex(body)
            }
            if let differential = op.differential { out += #"\,d"# + latex(differential) }
            return out
        }
    }

    private static func latex(_ atom: MathAtom) -> String {
        var base: String
        switch atom.base {
        case .greek(let name):
            if atom.isVariant, let variant = T.greekVariant[name] {
                base = variant.latex
            } else if atom.isUpper {
                base = T.greekUpper[name]?.latex ?? String(name.prefix(1)).uppercased()
            } else {
                base = T.greek[name]?.latex ?? name
            }
        case .latin(let letter):
            base = atom.isUpper ? String(letter).uppercased() : String(letter).lowercased()
        }
        for accent in atom.accents { base = accentLatex[accent]! + "{" + base + "}" }
        if let sub = atom.subscriptNode { base += "_" + brace(latex(sub)) }
        base += String(repeating: "'", count: atom.primes)
        var sups: [String] = []
        if atom.hasStar { sups.append("*") }
        if atom.isTransposed { sups.append(#"\top"#) }
        if atom.isInverse { sups.append("-1") }
        if let sup = atom.superscriptNode { sups.append(latex(sup)) }
        if !sups.isEmpty {
            let s = sups.joined()
            base += "^" + (length(s) == 1 || s == #"\top"# ? s : "{" + s + "}")
        }
        return base
    }

    private static func latexPowerBase(_ base: MathNode) -> String {
        switch base.content {
        case .group, .number, .function, .absolute: return latex(base)
        default: return "(" + latex(base) + ")"
        }
    }

    private static func latexWrapped(_ node: MathNode) -> String {
        node.isLooseBinaryOrRelation ? "(" + latex(node) + ")" : latex(node)
    }

    // MARK: Unicode

    /// Script characters when every character has one (D3); otherwise _x / _{...}.
    static func script(_ s: String, _ table: [Character: Character], marker: String) -> String {
        if !s.isEmpty, s.unicodeScalars.allSatisfy({ table[Character($0)] != nil }) {
            return String(s.unicodeScalars.map { table[Character($0)]! })
        }
        return marker + (length(s) == 1 ? s : "{" + s + "}")
    }

    private static func compact(_ s: String) -> String { s.replacingOccurrences(of: " ", with: "") }

    static func unicode(_ node: MathNode) -> String {
        switch node.content {
        case .number(let text):
            return text == "inf" ? "∞" : text
        case .text(let text):
            return text
        case .index(let items):
            return items.map(unicode).joined()
        case .symbol(let atom):
            return unicode(atom)
        case .negate(let x):
            return "−" + unicodeWrapped(x)
        case .binary(let op, let l, let r, let tight):
            let symbol = op == .plus ? "+" : op == .minus ? "−" : "±"
            if tight { return unicode(l) + symbol + unicode(r) }
            return "\(unicode(l)) \(symbol) \(op == .minus ? unicodeWrapped(r) : unicode(r))"
        case .juxtaposition(let factors):
            var out = ""
            for (k, f) in factors.enumerated() {
                let previous = k > 0 ? factors[k - 1] : nil
                let fIsSymbolOrRoot: Bool
                if f.isSymbol { fIsSymbolOrRoot = true } else if case .root = f.content { fIsSymbolOrRoot = true } else { fIsSymbolOrRoot = false }
                if let previous, !(fIsSymbolOrRoot && (previous.isSymbol || previous.isNumber)) { out += " " }
                out += unicodeWrapped(f, fraction: true)
            }
            return out
        case .product(let units):
            let last = units.count - 1
            var out = unicodeWrapped(units[0], fraction: last > 0)
            for k in 1..<units.count {
                let (a, b) = (units[k - 1], units[k])
                let piece = unicodeWrapped(b, fraction: k < last)
                if b.isBigOperator {
                    out += " " + piece
                } else if a.isNumber || b.isNumber {
                    out += " × " + piece
                } else {
                    out += "·" + piece
                }
            }
            return out
        case .fraction(let n, let d, _):
            func side(_ x: MathNode, denominator: Bool) -> String {
                let s = unicode(x)
                switch x.content {
                case .binary, .relation, .fraction, .product: return "(" + s + ")"
                case .juxtaposition where denominator: return "(" + s + ")"
                default: return s
                }
            }
            return side(n, denominator: false) + "/" + side(d, denominator: true)
        case .group(let x):
            return "(" + unicode(x) + ")"
        case .power(let base, let exponent):
            let baseText: String
            switch base.content {
            case .group, .number, .function, .absolute: baseText = unicode(base)
            default: baseText = "(" + unicode(base) + ")"
            }
            return baseText + script(compact(unicode(exponent)), superscripts, marker: "^")
        case .factorial(let x):
            return unicodeWrapped(x) + "!"
        case .root(let x, let degree):
            var inner = unicode(x)
            if !(x.isSymbol || x.isNumber) { inner = "(" + inner + ")" }
            return (degree == 2 ? "√" : "∛") + inner
        case .absolute(let x, let norm):
            return norm ? "‖" + unicode(x) + "‖" : "|" + unicode(x) + "|"
        case .binomial(let n, let k):
            return "C(" + unicode(n) + ", " + unicode(k) + ")"
        case .function(let head, let args, let given):
            let inner = args.map(unicode).joined(separator: ", ")
            switch head {
            case .generic(let name):
                return unicode(name) + "(" + inner + ")"
            case .named(let id):
                let spec = T.functions[id]!
                let condition = given.map { " | " + unicode($0) } ?? ""
                return spec.unicode + (spec.usesSquareBrackets ? "[" : "(") + inner + condition
                    + (spec.usesSquareBrackets ? "]" : ")")
            }
        case .relation(let first, let links):
            return links.reduce(unicode(first)) { $0 + " \(relationUnicode[$1.op]!) \(unicode($1.rhs))" }
        case .distribution(let spec, let params, _):
            let parts = params.map(unicode)
            switch spec.kind {
            case .studentT, .fisherF, .chiSquared:
                return spec.unicodeHead + script(compact(parts.joined(separator: ",")), subscripts, marker: "_")
            default:
                return spec.unicodeHead + "(" + parts.joined(separator: ", ") + ")"
            }
        case .derivative(let partial, let of, let by):
            let d = partial ? "∂" : "d"
            return d + unicode(of) + "/" + d + unicode(by)
        case .bigOperator(let op):
            var head = bigUnicode[op.kind]!
            if op.kind == .limit, let variable = op.variable, let upper = op.upper {
                head += "_{" + unicode(variable) + "→" + unicode(upper) + "}"
            } else if let lower = op.lower, let upper = op.upper {
                let low = compact(op.variable.map { unicode($0) + "=" + unicode(lower) } ?? unicode(lower))
                let high = compact(unicode(upper))
                if low.unicodeScalars.allSatisfy({ subscripts[Character($0)] != nil }),
                   high.unicodeScalars.allSatisfy({ superscripts[Character($0)] != nil }) {
                    head += String(low.unicodeScalars.map { subscripts[Character($0)]! })
                        + String(high.unicodeScalars.map { superscripts[Character($0)]! })
                } else {
                    head += "_{" + low + "}^{" + high + "}"
                }
            } else if let variable = op.variable {
                head += script(unicode(variable), subscripts, marker: "_")
            }
            guard let body = op.body else { return head }
            var out = head + " "
            if op.kind != .limit, case .binary = body.content {
                out += unicodeWrapped(body)
            } else {
                out += unicode(body)
            }
            if let differential = op.differential { out += " d" + unicode(differential) }
            return out
        }
    }

    private static func unicode(_ atom: MathAtom) -> String {
        var base: String
        switch atom.base {
        case .greek(let name):
            if atom.isVariant, let variant = T.greekVariant[name] {
                base = variant.unicode
            } else if atom.isUpper {
                base = T.greekUpper[name]?.unicode ?? String(name.prefix(1)).uppercased()
            } else {
                base = T.greek[name]?.unicode ?? name
            }
        case .latin(let letter):
            base = atom.isUpper ? String(letter).uppercased() : String(letter).lowercased()
        }
        for accent in atom.accents { base += accentUnicode[accent]! }
        base += String(repeating: "′", count: atom.primes)
        if let sub = atom.subscriptNode { base += script(compact(unicode(sub)), subscripts, marker: "_") }
        var sups = ""
        if atom.hasStar { base += "*" }
        if atom.isTransposed { base += "ᵀ" }
        if atom.isInverse { sups += "−1" }
        if let sup = atom.superscriptNode { sups += compact(unicode(sup)) }
        if !sups.isEmpty { base += script(sups, superscripts, marker: "^") }
        return base
    }

    private static func unicodeWrapped(_ node: MathNode, fraction: Bool = false) -> String {
        if node.isLooseBinaryOrRelation || (fraction && node.isFraction) { return "(" + unicode(node) + ")" }
        return unicode(node)
    }
}
