import Foundation

/// Recursive-descent parser for spoken formulas (design.md 4 and 5).
/// Precedence, lowest first: relation > additive (with the spoken-fraction rule, D9) > term (times)
/// > unit (juxtaposition) > factor (negation, Chinese postfix functions, choose, factorial) > primary.
/// Every recognition happens on tokens; nothing is rendered until the whole span is parsed.
final class MathSpanParser {
    typealias Parse = (node: MathNode, next: Int)
    private typealias T = MathLexiconTables
    private typealias ZhRole = MathLexiconTables.ZhRole

    /// Recursion depth and work limits (invariant I9).
    static let maxDepth = 60
    static let maxSpanTokens = 256
    static let stepBudget = 200_000

    let stream: MathTokenStream
    private let tokens: [MathToken]
    private var limit: Int
    private var inIntegral = 0
    private var stopChinesePostfixFunctions = false
    private var depth = 0
    private var budget = MathSpanParser.stepBudget

    init(_ stream: MathTokenStream) {
        self.stream = stream
        self.tokens = stream.tokens
        self.limit = stream.tokens.count
    }

    /// The longest expression that starts at token `start`.
    func parseSpan(at start: Int) -> Parse? {
        limit = min(tokens.count, start + Self.maxSpanTokens)
        budget = Self.stepBudget
        depth = 0
        inIntegral = 0
        stopChinesePostfixFunctions = false
        return relation(start)
    }

    // MARK: Phrase tables

    private enum P {
        static let relations = MathPhraseTable(T.relations.keys)
        static let additions = MathPhraseTable(T.additions.keys)
        static let multiplications = MathPhraseTable(T.multiplications.keys)
        static let divisions = MathPhraseTable(T.divisions.keys)
        static let accents = MathPhraseTable(T.accents.keys)
        static let marks = MathPhraseTable(T.marks.keys)
        static let markAliases = MathPhraseTable(T.markAliases.keys)
        static let powers = MathPhraseTable(T.powers.keys)
        static let functions = MathPhraseTable(T.functionPhrases.keys)
        static let distributions = MathPhraseTable(T.distributions.keys)
        static let follows = MathPhraseTable(T.follows)
        static let casePrefix = MathPhraseTable(["capital", "big", "upper case", "uppercase", "lowercase", "lower case"])
        static let upperPrefixes: Set<String> = ["capital", "big", "upper case", "uppercase"]
        static let toThePower = MathPhraseTable(["to the power of", "to the power", "raised to the power of", "raised to the", "to the"])
        static let degreesOfFreedom = MathPhraseTable(["degrees of freedom", "degree of freedom"])
        static let plusMinus = MathPhraseTable(["plus", "minus"])
        static let quantity = MathPhraseTable(["quantity"])
        static let openGroup = MathPhraseTable([
            "open paren", "open parenthesis", "left paren", "left parenthesis", "open bracket", "left bracket"
        ])
        static let closeGroup = MathPhraseTable([
            "end quantity", "close quantity", "close paren", "close parenthesis", "right paren", "right parenthesis",
            "close bracket", "right bracket"
        ])
        static let fraction = MathPhraseTable(["the fraction", "fraction"])
        static let roots: [String: Int] = [
            "square root of": 2, "square root": 2, "cube root of": 3, "cube root": 3, "root": 2, "sqrt": 2
        ]
        static let root = MathPhraseTable(roots.keys)
        static let absolute = MathPhraseTable(["absolute value of", "norm of"])
        static let named = MathPhraseTable([
            "adjusted r squared", "r squared", "h zero", "h naught", "h nought", "h one", "h a", "p value", "p-value"
        ])
        static let bigOperators: [String: MathBigOperatorKind] = [
            "sum": .sum, "summation": .sum, "product": .product, "integral": .integral, "limit": .limit, "lim": .limit
        ]
        static let bigOperator = MathPhraseTable(bigOperators.keys)
        static let limitArrow = MathPhraseTable(["goes to", "tends to", "approaches", "to", "goes"])
        static let argExtremes: [String: MathBigOperatorKind] = [
            "arg max over": .argMax, "arg min over": .argMin, "argmax over": .argMax, "argmin over": .argMin
        ]
        static let argExtreme = MathPhraseTable(argExtremes.keys)
        static let derivativeOf = MathPhraseTable(["derivative of", "partial derivative of"])
        static let withRespectTo = MathPhraseTable(["with respect to"])
        static let iid = MathPhraseTable(["i i d", "iid", "independent and identically distributed"])
        static let distributionParameterLead = MathPhraseTable(["mean", "parameters", "parameter", "rate", "probability"])
        static let secondParameter = MathPhraseTable(["variance", "standard deviation"])
        static let allPower = MathPhraseTable(["all squared", "all cubed"])
        static let allOperators = MathPhraseTable(["all squared", "all cubed", "all over"])
        static let operatorWords: Set<String> = [
            "given", "choose", "and", "comma", "of", "is", "follows", "follow", "has", "with", "to", "from", "as",
            "all", "by", "d", "the", "a", "an", "in", "for", "on", "at", "or"
        ]
        static let cardinalWords: Set<String> = Set(T.units.keys).union(T.teens.keys).union(T.tens.keys)
            .union(["hundred", "thousand", "million", "billion", "and"])
    }

    // MARK: Budget

    private func enter() -> Bool {
        budget -= 1
        guard budget > 0, depth < Self.maxDepth else { return false }
        depth += 1
        return true
    }

    private func leave() { depth -= 1 }

    // MARK: Token helpers

    private func tok(_ i: Int) -> MathToken? {
        i >= 0 && i < limit ? tokens[i] : nil
    }

    /// The lower-cased word at `i`, unless it belongs to a label.
    private func word(_ i: Int) -> String? {
        guard let t = tok(i), t.kind == .word, !t.isClaimedByLabel else { return nil }
        return t.lower
    }

    private func phrase(_ i: Int, _ table: MathPhraseTable) -> (key: String, next: Int)? {
        guard let match = table.match(at: i, word: word) else { return nil }
        return (match.phrase, i + match.length)
    }

    private func zh(_ i: Int) -> String? {
        guard let t = tok(i), t.kind == .zh else { return nil }
        return t.text
    }

    private func zh<V>(_ i: Int, in table: [String: V]) -> String? {
        guard let text = zh(i), table[text] != nil else { return nil }
        return text
    }

    private func zhw(_ i: Int, _ role: ZhRole) -> Bool {
        guard let text = zh(i) else { return false }
        return T.zhWords[text] == role
    }

    private func isNoise(_ i: Int, softOnly: Bool = false) -> Bool {
        guard let t = tok(i) else { return false }
        if t.kind == .punctuation {
            return softOnly ? (t.text == "," || t.text == "，") : [".", ",", "，", "。"].contains(t.text)
        }
        if t.kind == .word, T.hesitations.contains(t.lower) { return true }
        return t.kind == .zh && T.zhWords[t.text] == .noise
    }

    /// Skip recogniser punctuation and hesitations where the grammar still needs an operand (P8).
    private func need(_ i: Int) -> Int {
        var j = i
        while isNoise(j) { j += 1 }
        return j
    }

    /// A comma or a hesitation may precede an infix operator.
    private func beforeInfix(_ i: Int) -> Int {
        var j = i
        while isNoise(j, softOnly: true) || (tok(j).map { $0.kind == .word && T.hesitations.contains($0.lower) } ?? false) {
            j += 1
        }
        return j
    }

    private func isPunctuation(_ i: Int, _ characters: Set<String>) -> Bool {
        guard let t = tok(i), t.kind == .punctuation else { return false }
        return characters.contains(t.text)
    }

    private func isCardinalWord(_ word: String?) -> Bool {
        guard let word else { return false }
        return T.units[word] != nil || T.teens[word] != nil || T.tens[word] != nil
    }

    // MARK: Numbers

    func number(_ i: Int) -> Parse? {
        guard let t = tok(i), !t.isClaimedByLabel else { return nil }
        if t.kind == .number || t.kind == .zhNumber {
            var text = t.value ?? t.text
            var j = i + 1
            if word(j) == "percent" {
                text += "%"
                j += 1
            }
            return (.number(text), j)
        }
        if t.kind == .zh, T.zhWords[t.text] == .infinity { return (.number("inf"), i + 1) }
        guard t.kind == .word else { return nil }
        if t.lower == "infinity" { return (.number("inf"), i + 1) }
        guard let (value, afterCardinal) = cardinal(i) else { return nil }
        var text = String(value)
        var j = afterCardinal
        if word(j) == "point" {
            var k = j + 1
            var digitWords: [String] = []
            while let w = word(k), T.units[w] != nil || w == "oh" {
                digitWords.append(w == "naught" || w == "nought" ? "zero" : w)
                k += 1
            }
            if let digits = EnglishNumberGrammar.fractionDigits(digitWords) {
                text += "." + digits
                j = k
            }
        }
        if word(j) == "percent" {
            text += "%"
            j += 1
        }
        return (.number(text), j)
    }

    /// The longest cardinal phrase at `i`, read by the numeric layer's grammar.
    private func cardinal(_ i: Int) -> (Int, Int)? {
        guard isCardinalWord(word(i)) else { return nil }
        var words: [String] = []
        var k = i
        while words.count < 10, let w = word(k), P.cardinalWords.contains(w) || w == "naught" || w == "nought" {
            words.append(w == "naught" || w == "nought" ? "zero" : w)
            k += 1
        }
        for length in stride(from: words.count, through: 1, by: -1) {
            if let value = EnglishNumberGrammar.cardinal(Array(words[0..<length])) {
                return (value, i + length)
            }
        }
        return nil
    }

    // MARK: Symbols

    /// (Greek name, alias?, next) when token i is a Greek name not blocked by a collocation.
    private func greekAt(_ i: Int) -> (name: String, isAlias: Bool, next: Int)? {
        guard let t = tok(i), !t.isClaimedByLabel else { return nil }
        if t.kind == .zh {
            guard let name = T.zhGreek[t.text] ?? T.zhGreekAlias[t.text] else { return nil }
            if restStarts(after: t, with: T.zhGreekNextBlock) { return nil }
            return (name, T.zhGreekAlias[t.text] != nil, i + 1)
        }
        // PSI, ETA: an all-caps word is an acronym, not a Greek name.
        guard t.kind == .word, !(t.text.count > 1 && t.text == t.text.uppercased()) else { return nil }
        var name = T.greekSpokenExtra[t.lower] ?? t.lower
        var isAlias = false
        if let target = T.greekAlias[name] {
            name = target
            isAlias = true
        }
        guard T.greek[name] != nil else { return nil }
        let next = tok(i + 1)
        let previous = tok(i - 1)
        if let next, next.kind == .word || next.kind == .prose, T.greekNextBlock[name]?.contains(next.lower) == true,
           !(name == "pi" && next.lower == "zero") {
            return nil
        }
        if let next, next.kind == .number, T.greekNextBlock[name]?.contains(next.text) == true { return nil }
        if let next, next.kind == .hanProse, restStarts(after: t, with: T.zhGreekNextBlock) { return nil }
        if let previous, previous.kind == .word || previous.kind == .prose,
           T.greekPreviousBlock[name]?.contains(previous.lower) == true {
            return nil
        }
        return (name, isAlias, i + 1)
    }

    /// Whether the text right after the token (spaces skipped) starts with one of the words.
    private func restStarts(after token: MathToken, with words: [String]) -> Bool {
        let chars = stream.characters
        var k = token.end
        while k < chars.count, chars[k].isWhitespace { k += 1 }
        return words.contains { word in
            var m = k
            for c in word {
                guard m < chars.count, chars[m] == c else { return false }
                m += 1
            }
            return true
        }
    }

    /// A letter or Greek name with an optional case or variant prefix.
    private func baseSymbol(_ i: Int) -> Parse? {
        var force: Bool?
        var j = i
        if let (key, k) = phrase(j, P.casePrefix) {
            force = P.upperPrefixes.contains(key)
            j = k
        } else if zhw(j, .capital) || zhw(j, .lower) {
            force = zhw(j, .capital)
            j += 1
        }
        var isVariant = false
        if let w = word(j), let allowed = T.variantPrefixes[w], let g = greekAt(j + 1), T.greekVariant[g.name] != nil,
           allowed?.contains(g.name) ?? true {
            isVariant = true
            j += 1
        } else if let w = word(j), w.hasPrefix("var"), T.greekVariant[String(w.dropFirst(3))] != nil {
            let atom = MathAtom(.greek(String(w.dropFirst(3))))
            atom.isVariant = true
            atom.isMathDominantGreek = true
            return (.symbol(atom), j + 1)
        }
        let t = tok(j)
        if let g = greekAt(j), let t {
            let atom = MathAtom(.greek(g.name))
            atom.isAlias = g.isAlias
            atom.isVariant = isVariant
            atom.isMathDominantGreek = T.greek[g.name]?.isMathDominant ?? false
            let capitalised = t.kind == .word && t.text.first?.isUppercase == true
            if force == true {
                atom.isUpper = true
            } else if capitalised, !t.isSentenceInitial {
                atom.isProperName = true
            }
            if let next = tok(g.next), next.kind == .word, next.text.count > 1, next.text.first?.isUppercase == true,
               capitalised {
                atom.isProperName = true // Mu Online, Sigma Chi
            }
            atom.followsArticle = [tok(j - 1), tok(j - 2)].contains { $0?.kind == .word && ($0?.lower == "a" || $0?.lower == "an") }
            return (.symbol(atom), g.next)
        }
        if let t, t.kind == .word, t.text.count == 1, !t.isClaimedByLabel, let letter = t.text.first {
            // A single letter is lower case unless "capital" was spoken or the context makes it a random
            // variable (function arguments, events, the left side of "follows": uppercaseVariables). The
            // recogniser's capitals carry no meaning (default T11, owner decision 2026-10-10).
            let atom = MathAtom(.latin(letter), upper: false)
            if let force {
                atom.isUpper = force
                atom.isCaseForced = true
            }
            atom.isWeakLetter = T.labelProneLetters.contains(letter)
            atom.isPronounI = letter == "I" && force == nil
            return (.symbol(atom), j + 1)
        }
        return nil
    }

    /// Subscript content: an atom, juxtaposed index letters, comma lists, then +/- number or over number.
    private func index(_ start: Int) -> Parse? {
        let i = need(start)
        var node: MathNode
        var j: Int
        if let r = number(i) {
            (node, j) = r
        } else {
            guard let b = baseSymbol(i), let atom = b.node.atom else { return nil }
            (node, j) = b
            if let letter = atom.latinLetter {
                // A lone capital I in a subscript is the index i, not the pronoun (design.md 5.7).
                atom.isPronounI = false
                atom.isUpper = atom.isUpper && letter != "I" && atom.isCaseForced
            }
            var items = [node]
            while true {
                if let w = word(j), w.count == 1, T.subscriptLetters.contains(w), items.count < 3, atom.latinLetter != nil {
                    items.append(.symbol(MathAtom(.latin(Character(w)))))
                    j += 1
                } else if word(j) == "comma", let next = baseSymbol(j + 1) {
                    next.node.atom?.isUpper = false
                    items.append(MathNode(.text(",")))
                    items.append(next.node)
                    j = next.next
                } else {
                    break
                }
            }
            if items.count > 1 { node = MathNode(.index(items)) }
        }
        var op: MathAddOperator?
        var afterOp = j
        if let (key, k) = phrase(j, P.plusMinus) {
            op = key == "plus" ? .plus : .minus
            afterOp = k
        } else if let z = zh(j, in: T.zhAdditions), let entry = T.zhAdditions[z], entry.0 != .plusMinus {
            op = entry.0
            afterOp = j + 1
        }
        if let op, let r = number(afterOp) {
            node = MathNode(.binary(op, node, r.node, tight: true))
            j = r.next
        }
        if word(j) == "over", let r = number(j + 1) {
            node = MathNode(.fraction(node, r.node, inline: true))
            j = r.next
        }
        return (node, j)
    }

    /// All postfix modifiers of a symbol, in any spoken order.
    private func postfix(_ start: Parse) -> Parse {
        var (node, i) = start
        guard let atom = node.atom else { return start }
        let baseEnd = i
        while true {
            if let (key, k) = phrase(i, P.accents), let accent = T.accents[key] {
                atom.accents.append(accent)
                if i == baseEnd, let letter = atom.latinLetter, tok(i - 1)?.text.count == 1,
                   T.splitEnglishWords.contains(String(letter).lowercased() + key) {
                    // W hat, T hat: the recogniser split "What" / "That".
                    atom.isAlias = true
                    atom.aliasModifierCount += 1
                } else {
                    atom.modifierCount += 1
                }
                i = k
                continue
            }
            if let w = word(i), let accent = T.accentAliases[w] {
                atom.accents.append(accent)
                atom.aliasModifierCount += 1
                i += 1
                continue
            }
            if let (key, k) = phrase(i, P.markAliases), let mark = T.markAliases[key] {
                atom.apply(mark)
                atom.aliasModifierCount += 1
                i = k
                continue
            }
            if let (key, k) = phrase(i, P.marks), let mark = T.marks[key] {
                atom.apply(mark)
                atom.modifierCount += 1
                i = k
                continue
            }
            if let z = zh(i), let accent = T.zhAccents[z] {
                atom.accents.append(accent)
                atom.modifierCount += 1
                i += 1
                continue
            }
            if let z = zh(i), let mark = T.zhMarks[z] {
                atom.apply(mark)
                atom.modifierCount += 1
                i += 1
                continue
            }
            if word(i) == "sub" || word(i) == "subscript" || zhw(i, .subscriptWord) {
                guard atom.subscriptNode == nil, let r = index(i + 1) else { break }
                atom.subscriptNode = r.node
                i = r.next
                atom.modifierCount += 1
                continue
            }
            if let w = word(i), let value = T.powerAliases[w], atom.superscriptNode == nil {
                atom.superscriptNode = .number(value)
                atom.aliasModifierCount += 1
                i += 1
                continue
            }
            if let p = power(i), atom.superscriptNode == nil {
                atom.superscriptNode = p.node
                i = p.next
                atom.modifierCount += 1
                continue
            }
            if atom.subscriptNode == nil, atom.superscriptNode == nil, atom.primes == 0, let r = implicitIndex(atom, i) {
                atom.subscriptNode = r.node
                i = r.next
                continue
            }
            if atom.greekName == "chi", let sup = atom.superscriptNode, sup.numberText == "2", atom.subscriptNode == nil,
               word(i) == "with" || word(i) == "of", let r = degreesOfFreedom(i + 1),
               let spec = T.distributions["chi squared"] {
                // chi squared with k degrees of freedom (default T10)
                return (MathNode(.distribution(spec, params: r.params, iid: false), strong: 1, connector: true), r.next)
            }
            break
        }
        return (node, i)
    }

    private func implicitIndex(_ atom: MathAtom, _ i: Int) -> Parse? {
        guard let t = tok(i), !t.isClaimedByLabel else { return nil }
        if t.kind == .number || t.kind == .zhNumber
            || (t.kind == .word && (T.units[t.lower] != nil || T.teens[t.lower] != nil)) {
            guard let r = number(i), let text = r.node.numberText, !text.isEmpty, text.allSatisfy(\.isASCIIDigitCharacter),
                  let value = Int(text), value <= 20 else { return nil }
            if let w = word(r.next), ["point", "percent", "hundred", "thousand"].contains(w) { return nil }
            if let name = atom.greekName, let after = tok(r.next), after.kind == .word || after.kind == .prose,
               T.greekNextBlock[name]?.contains(after.lower) == true {
                return nil // beta two release
            }
            return r
        }
        let name: String
        switch atom.base {
        case .latin(let letter): name = String(letter).lowercased()
        case .greek(let greek): name = greek
        }
        if t.kind == .word, t.text.count == 1, T.indexLetters.contains(t.lower), !T.indexLetters.contains(name) {
            var items: [MathNode] = [.symbol(MathAtom(.latin(Character(t.lower))))]
            var j = i + 1
            if word(j) == "t", t.lower == "i" || t.lower == "j" {
                items.append(.symbol(MathAtom(.latin("t"))))
                j += 1
            }
            if word(j) == "of" { return nil }
            return (items.count == 1 ? items[0] : MathNode(.index(items)), j)
        }
        return nil
    }

    /// squared / cubed / to the power of n / to the n / to the minus one / 的平方 / 的 n 次方.
    private func power(_ i: Int) -> Parse? {
        if let w = word(i), let value = T.powers[w], !((w == "square" || w == "cube") && word(i + 1) == "root") {
            return (.number(value), i + 1)
        }
        if let z = zh(i), let value = T.zhPowers[z] { return (.number(value), i + 1) }
        if zhw(i, .de), let r = exponent(i + 1), zhw(r.next, .cifang) { return (r.node, r.next + 1) }
        guard let (_, k) = phrase(i, P.toThePower) else { return nil }
        if let w = word(k), let value = T.ordinalPowers[w] {
            var j = k + 1
            if word(j) == "power" { j += 1 }
            return (.number(value), j)
        }
        guard let r = exponent(k) else { return nil }
        var j = r.next
        if word(j) == "power" { j += 1 }
        return (r.node, j)
    }

    private func exponent(_ start: Int) -> Parse? {
        var i = start
        var negative = false
        if word(i) == "minus" || word(i) == "negative" || zhw(i, .negative) {
            negative = true
            i += 1
        }
        guard let r = unit(i, limit: 3) else { return nil }
        return (negative ? MathNode(.negate(r.node)) : r.node, r.next)
    }

    // MARK: Small expressions

    /// K degrees of freedom / M and N degrees of freedom.
    private func degreesOfFreedom(_ i: Int) -> (params: [MathNode], next: Int)? {
        guard let r = simpleExpression(i) else { return nil }
        var params = [r.node]
        var j = r.next
        if word(j) == "and", let second = simpleExpression(j + 1) {
            params.append(second.node)
            j = second.next
        }
        guard let (_, k) = phrase(j, P.degreesOfFreedom) else { return nil }
        return (params, k)
    }

    /// atom [+/- atom]: parameters such as n minus one.
    private func simpleExpression(_ i: Int) -> Parse? {
        guard var (node, j) = atomFactor(i) else { return nil }
        if let (key, k) = phrase(j, P.plusMinus), let right = atomFactor(k) {
            node = MathNode(.binary(key == "plus" ? .plus : .minus, node, right.node, tight: true), strong: 1)
            j = right.next
        }
        return (node, j)
    }

    private func atomFactor(_ i: Int) -> Parse? {
        if let r = number(i) { return r }
        guard let b = baseSymbol(i) else { return nil }
        return postfix(b)
    }

    private func signedUnit(_ start: Int) -> Parse? {
        var i = start
        if word(i) == "minus" || word(i) == "negative" || zhw(i, .negative) {
            guard let r = unit(i + 1, limit: 2) else { return nil }
            return (MathNode(.negate(r.node)), r.next)
        }
        if word(i) == "positive" || word(i) == "plus" { i += 1 }
        return simpleExpression(i)
    }

    // MARK: Primary

    private func primary(_ i: Int, juxtaposed: Bool = false) -> Parse? {
        guard let t = tok(i), !t.isClaimedByLabel,
              [.word, .number, .zhNumber, .zh].contains(t.kind) else { return nil }
        guard enter() else { return nil }
        defer { leave() }
        let the = word(i) == "the" ? i + 1 : i

        // Grouping: the quantity ... [end quantity], open paren ... close paren, 括号 ... 括回.
        var groupStart: Int?
        if the > i, let (_, k) = phrase(the, P.quantity) {
            groupStart = k
        } else if let (_, k) = phrase(i, P.openGroup) {
            groupStart = k
        } else if zhw(i, .leftParen) {
            groupStart = i + 1
        }
        if let groupStart {
            guard let r = relation(need(groupStart)) else { return nil }
            var j = r.next
            if let (_, k) = phrase(j, P.closeGroup) {
                j = k
            } else if zhw(j, .rightParen) {
                j += 1
            }
            return groupPostfix((MathNode(.group(r.node), strong: 1, connector: true), j))
        }

        // The fraction a over b: always tight.
        if let (_, k) = phrase(i, P.fraction) {
            if let a = unit(need(k)), word(a.next) == "over", let b = unit(need(a.next + 1)) {
                return (MathNode(.fraction(a.node, b.node, inline: false), strong: 1, connector: true), b.next)
            }
            return nil
        }

        // Roots.
        var rootStart: (start: Int, degree: Int)?
        if let (key, k) = phrase(the, P.root) {
            rootStart = (k, P.roots[key] ?? 2)
        } else if zhw(i, .sqrt) {
            rootStart = (i + 1, 2)
        }
        if let rootStart {
            guard let r = unit(need(rootStart.start)) else { return nil }
            return groupPostfix((MathNode(.root(r.node, degree: rootStart.degree), strong: 1, connector: true), r.next))
        }

        // Absolute value and norm.
        var absoluteStart: (start: Int, norm: Bool)?
        if let (key, k) = phrase(the, P.absolute) {
            absoluteStart = (k, key == "norm of")
        } else if zhw(i, .absolute) {
            absoluteStart = (i + 1, false)
        }
        if let absoluteStart {
            guard let r = unit(need(absoluteStart.start)) else { return nil }
            return (MathNode(.absolute(r.node, norm: absoluteStart.norm), strong: 1, connector: true), r.next)
        }

        if let r = bigOperator(i, the: the) { return r }
        if let r = derivative(i, the: the) { return r }
        if let r = function(i, the: the) { return r }
        if let r = chineseConditional(i) { return r }
        if let r = distribution(i, statement: false) { return r }
        if !juxtaposed, let r = named(i) { return r }
        if let r = number(i) { return groupPostfix(r) }
        guard let b = baseSymbol(i) else { return nil }
        let (node, j) = postfix(b)
        guard let atom = node.atom else { return (node, j) }

        // Generic function application: f of x, f prime of x, phi of x.
        if word(j) == "of" {
            let isFunctionLetter = atom.latinLetter.map { !T.genericFunctionExcludedLetters.contains($0) } ?? false
            let isFunctionGreek = atom.greekName.map(T.functionNames.contains) ?? false
            if isFunctionLetter || atom.primes > 0 || isFunctionGreek, let args = arguments(need(j + 1), uppercase: false) {
                let fn = MathNode(.function(.generic(node), args: args.nodes, given: nil), strong: 1, connector: true)
                return groupPostfix((fn, args.next))
            }
        }
        return (node, j)
    }

    /// Powers and factorial on a non-symbol operand; 开根号 after any operand.
    private func groupPostfix(_ start: Parse) -> Parse {
        var (node, i) = start
        while true {
            if let p = power(i) {
                node = MathNode(.power(node, p.node), strong: 1, connector: true)
                i = p.next
                continue
            }
            if word(i) == "factorial" {
                node = MathNode(.factorial(node), strong: 1, connector: true)
                i += 1
                continue
            }
            if zhw(i, .sqrtPostfix) {
                node = MathNode(.root(node, degree: 2), strong: 1, connector: true)
                i += 1
                continue
            }
            return (node, i)
        }
    }

    /// r squared, adjusted r squared, h zero / h naught (default T9), p value.
    private func named(_ i: Int) -> Parse? {
        guard let (key, k) = phrase(i, P.named) else { return nil }
        let atom: MathAtom
        if key == "p value" || key == "p-value" {
            atom = MathAtom(.latin("p"))
        } else if key == "h a" {
            atom = MathAtom(.latin("H"), upper: true)
            atom.subscriptNode = .symbol(MathAtom(.latin("a")))
        } else if key.hasPrefix("h ") {
            atom = MathAtom(.latin("H"), upper: true)
            atom.subscriptNode = .number(key == "h one" ? "1" : "0")
        } else {
            atom = MathAtom(.latin("R"), upper: true)
            atom.superscriptNode = .number("2")
            if key.hasPrefix("adjusted") { atom.accents.append(.bar) }
        }
        atom.isCaseForced = true
        atom.isNamedNotation = true
        // h one and h a (alternative hypotheses) need context (default T9); h zero converts directly.
        atom.isNamedNotationStrong = key != "h one" && key != "h a"
        return (.symbol(atom), k)
    }

    /// term [(, | and | comma) term]*.
    private func arguments(_ i: Int, uppercase: Bool, single: Bool = false) -> (nodes: [MathNode], next: Int)? {
        guard let first = single ? atomFactor(i) : unit(i) else { return nil }
        var args = [first.node]
        var j = first.next
        while true {
            var k = j
            if isPunctuation(k, [",", "，"]) { k += 1 }
            if word(k) == "and" || word(k) == "comma" || zhw(k, .and) { k += 1 }
            if k == j, !single { break }
            guard let r = single ? atomFactor(k) : unit(k) else { break }
            if k == j, !r.node.isSymbol, !single { break }
            // f of x and g of y: a complete function application after "and" starts a new formula.
            if case .function = r.node.content { break }
            args.append(r.node)
            j = r.next
            if single, args.count == 2 { break }
        }
        if uppercase { args.forEach { $0.uppercaseVariables() } }
        return (args, j)
    }

    // MARK: Functions

    private func function(_ i: Int, the: Int) -> Parse? {
        let id: MathFunctionID
        let isShort: Bool
        let isAlias: Bool
        let start: Int
        var key: String?
        if let (phraseKey, k) = phrase(the, P.functions), let spec = T.functionPhrases[phraseKey] {
            if spec.isShortForm, the > i { return nil }
            if spec.isShortForm, let previous = tok(i - 1), previous.kind == .word,
               T.codeCuePrevious.contains(previous.lower) {
                return nil
            }
            (id, isShort, isAlias, start, key) = (spec.id, spec.isShortForm, spec.isAlias, need(k), phraseKey)
        } else if let z = zh(i, in: T.zhFunctions), let zid = T.zhFunctions[z] {
            (id, isShort, isAlias, start) = (zid, false, false, need(i + 1))
        } else if word(i) == "e", let t = tok(i + 1), t.kind == .word, !t.isClaimedByLabel,
                  T.bareExpectationArguments.contains(t.lower), tok(i + 2).map({ $0.kind == .punctuation }) ?? true {
            // E X: alias strength, so only a whole utterance converts (design.md 6.3).
            let argument = MathNode.symbol(MathAtom(.latin(Character(t.text)), upper: true))
            let fn = MathNode(.function(.named(.expectation), args: [argument], given: nil), strong: 1, connector: true)
            fn.isAlias = true
            return (fn, i + 2)
        } else {
            return nil
        }
        let uppercases = T.functions[id]?.uppercasesArguments ?? false
        var args: [MathNode]
        var j: Int
        if id == .covariance || id == .correlation {
            if let pair = gluedVariablePair(start) {
                args = pair
                j = start + 1
            } else {
                guard let r = arguments(start, uppercase: true, single: true), r.nodes.count == 2 else { return nil }
                (args, j) = r
            }
            // The two arguments are random variables; a bare index letter (i, j, k) is not one (core i d).
            let isIndexLetter = { (node: MathNode) -> Bool in
                guard let atom = node.atom, let letter = atom.latinLetter, !atom.hasDecoration else { return false }
                return T.indexLetters.contains(String(letter).lowercased())
            }
            if args.contains(where: isIndexLetter) { return nil }
        } else if id == .probability, key?.hasSuffix("that") == true {
            guard let r = relation(start) else { return nil } // probability that x is greater than two
            args = [r.node]
            j = r.next
            if case .relation(let first, _) = r.node.content {
                first.uppercaseVariables()
            } else {
                r.node.uppercaseVariables()
            }
        } else if id == .probability {
            guard let r = unit(start) else { return nil }
            args = [r.node]
            j = r.next
            r.node.uppercaseVariables()
        } else if id == .expectation, !isShort, let pair = gluedVariablePair(start) {
            // expectation XY: the product of two random variables (owner decision 2026-10-09).
            args = [MathNode(.juxtaposition(pair))]
            j = start + 1
        } else if isShort {
            guard let r = atomFactor(start) else { return nil }
            args = [r.node]
            j = r.next
            if let next = tok(j), next.kind == .word, next.text.count == 1, !next.isClaimedByLabel {
                return nil // e t n, var x y: an ambiguous letter run, abstain
            }
            if uppercases { r.node.uppercaseVariables() }
        } else {
            guard let r = unit(start) else { return nil }
            args = [r.node]
            j = r.next
            if uppercases { r.node.uppercaseVariables() }
        }
        let isAmbiguous = (id != .covariance && id != .correlation && key?.hasSuffix("that") != true)
            && args.count == 1 && (isAmbiguousSymbolRun(args[0]) || continuesWithWrittenSymbol(args[0], at: j))
            && !(id == .expectation && !isShort && isRandomVariableRun(args[0]))
        var given: MathNode?
        if id == .probability || id == .expectation, word(j) == "given" || zhw(j, .given),
           let r = unit(need(j + 1)) {
            given = r.node
            j = r.next
            r.node.uppercaseVariables()
        }
        let fn = MathNode(.function(.named(id), args: args, given: given), strong: 1, medium: given == nil ? 0 : 1,
                          connector: true)
        if !isAlias, !isShort, isBareAliasArgument(args, functionStart: i, phraseStart: the, next: j) { fn.medium += 1 }
        fn.isAlias = isAlias
        fn.hasAmbiguousArgument = isAmbiguous
        return groupPostfix((fn, j))
    }

    /// An argument that is a run of symbols starting with a bare one (variance X Y, expectation E M,
    /// expectation beta gamma) is as ambiguous as the short form before another letter (design.md 4,
    /// "var x y"): a product, an acronym or two arguments.
    private func isAmbiguousSymbolRun(_ node: MathNode) -> Bool {
        guard case .juxtaposition(let factors) = node.content, let first = factors.first?.atom else { return false }
        return !first.hasDecoration && factors.allSatisfy(\.isSymbol)
    }

    /// standard error better (beta): a lone misheard Greek name after a full function name, with no
    /// determiner before the function and a clause boundary after the name (design.md 6.3).
    private func isBareAliasArgument(_ args: [MathNode], functionStart i: Int, phraseStart the: Int, next j: Int) -> Bool {
        guard args.count == 1, let atom = args[0].atom, atom.isAlias, atom.greekName != nil, !atom.hasDecoration,
              !atom.followsArticle, the == i else { return false }
        if let previous = word(i - 1), T.determiners.contains(previous) { return false }
        guard let next = tok(j), next.sentence == tok(j - 1)?.sentence else { return true }
        if next.kind == .punctuation { return true }
        return next.kind == .word && T.bareAliasArgumentFollowers.contains(next.lower)
    }

    /// XY, xz: a glued pair of random-variable letters, read letter by letter as upper case.
    private func gluedVariablePair(_ i: Int) -> [MathNode]? {
        guard let t = tok(i), t.kind == .word, !t.isClaimedByLabel, t.text.count == 2,
              t.lower.allSatisfy({ T.randomVariableLetters.contains($0) }) else { return nil }
        return t.text.map { .symbol(MathAtom(.latin($0), upper: true)) }
    }

    /// expectation X Y: a run of bare random-variable letters is their product (E[XY]), not an
    /// acronym; other runs (expectation E M, variance X Y) stay ambiguous (owner decision 2026-10-09).
    private func isRandomVariableRun(_ node: MathNode) -> Bool {
        guard case .juxtaposition(let factors) = node.content, factors.count <= 3 else { return false }
        return factors.allSatisfy { factor in
            guard let atom = factor.atom, let letter = atom.latinLetter, !atom.hasDecoration else { return false }
            return T.randomVariableLetters.contains(Character(letter.lowercased()))
        }
    }

    /// A bare-letter argument followed by a letter the recogniser already wrote (expectation E β).
    private func continuesWithWrittenSymbol(_ node: MathNode, at j: Int) -> Bool {
        guard let atom = node.atom, !atom.hasDecoration, let next = tok(j), next.kind == .symbol else { return false }
        return next.text.first?.isLetter == true
    }

    /// 在 B 的条件下 A 的概率 -> P(A | B).
    private func chineseConditional(_ i: Int) -> Parse? {
        guard zhw(i, .zai), let b = relation(i + 1), zhw(b.next, .condition) else { return nil }
        var j = b.next + 1
        while isNoise(j) { j += 1 }
        guard let a = relation(j, stopChinesePostfixFunctions: true), zhw(a.next, .de),
              zh(a.next + 1) == "概率" else { return nil }
        a.node.uppercaseVariables()
        b.node.uppercaseVariables()
        let fn = MathNode(.function(.named(.probability), args: [a.node], given: b.node), strong: 1, connector: true)
        return (fn, a.next + 2)
    }

    // MARK: Big operators

    private func bigOperator(_ i: Int, the: Int) -> Parse? {
        if let (key, k) = phrase(the, P.bigOperator), let kind = P.bigOperators[key] {
            var variable: MathNode?
            var lower: MathNode?
            var upper: MathNode?
            var j = k
            if kind == .limit {
                if word(j) == "as" { j += 1 }
                guard let b = baseSymbol(j), let (_, arrowEnd) = phrase(b.next, P.limitArrow),
                      let r = signedUnit(need(arrowEnd)) else { return nil }
                variable = b.node
                upper = r.node
                j = r.next
            } else if let bounds = bounds(j) {
                (variable, lower, upper, j) = bounds
            } else if kind == .product {
                return nil
            }
            if word(j) == "of" { j += 1 }
            if kind == .integral { inIntegral += 1 }
            let body = additive(need(j))
            if kind == .integral { inIntegral -= 1 }
            guard let body else {
                guard kind == .limit else { return nil }
                let op = MathBigOperator(kind: kind, variable: variable, lower: lower, upper: upper, body: nil, differential: nil)
                return (MathNode(.bigOperator(op), strong: 1, connector: true), j)
            }
            j = body.next
            if lower == nil, kind == .sum, variable == nil {
                guard let late = bounds(j) else { return nil }
                (variable, lower, upper, j) = late
            }
            var differential: MathNode?
            if kind == .integral, let d = self.differential(j) {
                differential = d.node
                j = d.next
            }
            let op = MathBigOperator(kind: kind, variable: variable, lower: lower, upper: upper, body: body.node,
                                     differential: differential)
            return (MathNode(.bigOperator(op), strong: 1, connector: true), j)
        }
        if let (key, k) = phrase(i, P.argExtreme), let kind = P.argExtremes[key] {
            guard let b = baseSymbol(k) else { return nil }
            var j = b.next
            var body: MathNode?
            if word(j) == "of", let r = unit(need(j + 1)) {
                body = r.node
                j = r.next
            }
            let op = MathBigOperator(kind: kind, variable: b.node, lower: nil, upper: nil, body: body, differential: nil)
            return (MathNode(.bigOperator(op), strong: 1, connector: true), j)
        }
        return chineseBigOperator(i)
    }

    /// from i equals one to n | over i | from zero to one.
    private func bounds(_ start: Int) -> (MathNode?, MathNode?, MathNode?, Int)? {
        var j = start
        if word(j) == "over" {
            guard let b = baseSymbol(j + 1) else { return nil }
            return (b.node, nil, nil, b.next)
        }
        guard word(j) == "from" else { return nil }
        j += 1
        var variable: MathNode?
        if let b = baseSymbol(j), ["equals", "equal", "is"].contains(word(b.next) ?? "") || zh(b.next) == "等于" {
            variable = b.node
            j = b.next + 1
            if word(j) == "to", word(j - 1) == "equal" { j += 1 }
        }
        if let lower = signedUnit(need(j)), let w = word(lower.next), ["to", "through", "until"].contains(w),
           let upper = signedUnit(need(lower.next + 1)) {
            return (variable, lower.node, upper.node, upper.next)
        }
        // from i equals one to the n: inside bounds "to the" is the upper-bound word, not a power.
        guard let lower = number(need(j)) ?? baseSymbol(need(j)), word(lower.next) == "to", word(lower.next + 1) == "the",
              let upper = signedUnit(need(lower.next + 2)) else { return nil }
        return (variable, lower.node, upper.node, upper.next)
    }

    private func differential(_ j: Int) -> Parse? {
        guard let w = word(j) else { return nil }
        if w == "d", let b = baseSymbol(j + 1) { return b }
        let chars = Array(w)
        if chars.count == 2, chars[0] == "d", MathLexer.isASCIILetter(chars[1]) {
            return (.symbol(MathAtom(.latin(chars[1]))), j + 1)
        }
        if w.hasPrefix("d"), T.greek[String(w.dropFirst())] != nil {
            return (.symbol(MathAtom(.greek(String(w.dropFirst())))), j + 1)
        }
        return nil
    }

    private func chineseBounds(_ start: Int) -> (MathNode?, MathNode, MathNode, Int)? {
        guard zhw(start, .from) else { return nil }
        var j = start + 1
        var variable: MathNode?
        if let b = baseSymbol(j), zh(b.next) == "等于" {
            variable = b.node
            j = b.next + 1
        }
        guard let lower = signedUnit(j), zhw(lower.next, .to), let upper = signedUnit(lower.next + 1) else { return nil }
        return (variable, lower.node, upper.node, upper.next)
    }

    private func chineseBigOperator(_ i: Int) -> Parse? {
        if zhw(i, .dui) { // 对 BODY 从 L 到 U 求和
            guard let body = additive(i + 1), let b = chineseBounds(body.next), zhw(b.3, .sum) else { return nil }
            let op = MathBigOperator(kind: .sum, variable: b.0, lower: b.1, upper: b.2, body: body.node, differential: nil)
            return (MathNode(.bigOperator(op), strong: 1, connector: true), b.3 + 1)
        }
        var variable: MathNode?
        var lower: MathNode?
        var upper: MathNode?
        var j = i
        let leadingBounds = chineseBounds(j)
        if let b = leadingBounds { (variable, lower, upper, j) = (b.0, b.1, b.2, b.3) }
        let kind: MathBigOperatorKind? = zhw(j, .sum) ? .sum : zhw(j, .integral) ? .integral : nil
        guard let kind else {
            // 当 n 趋于无穷时 BODY 的极限
            let startsWithTendsTo = leadingBounds == nil && baseSymbol(i).map { T.zhTendsTo.contains(zh($0.next) ?? "") } == true
            guard zhw(i, .dang) || startsWithTendsTo else { return nil }
            let k = zhw(i, .dang) ? i + 1 : i
            guard let v = baseSymbol(k), T.zhTendsTo.contains(zh(v.next) ?? ""), let to = signedUnit(v.next + 1) else {
                return nil
            }
            var m = to.next
            if zhw(m, .shi) { m += 1 }
            while isNoise(m) { m += 1 }
            guard let body = additive(m), zhw(body.next, .de), zhw(body.next + 1, .limit) else { return nil }
            let op = MathBigOperator(kind: .limit, variable: v.node, lower: nil, upper: to.node, body: body.node, differential: nil)
            return (MathNode(.bigOperator(op), strong: 1, connector: true), body.next + 2)
        }
        j += 1
        if leadingBounds == nil {
            if let late = chineseBounds(j) {
                (variable, lower, upper, j) = (late.0, late.1, late.2, late.3)
            } else if kind == .sum {
                return nil
            }
        }
        if kind == .integral { inIntegral += 1 }
        let body = additive(j)
        if kind == .integral { inIntegral -= 1 }
        guard let body else { return nil }
        j = body.next
        var differential: MathNode?
        if kind == .integral, let d = self.differential(j) {
            differential = d.node
            j = d.next
        }
        let op = MathBigOperator(kind: kind, variable: variable, lower: lower, upper: upper, body: body.node,
                                 differential: differential)
        return (MathNode(.bigOperator(op), strong: 1, connector: true), j)
    }

    // MARK: Derivatives

    private func derivative(_ i: Int, the: Int) -> Parse? {
        if the > i, let (key, k) = phrase(the, P.derivativeOf) {
            guard let f = atomFactor(k), let (_, wrt) = phrase(f.next, P.withRespectTo), let x = atomFactor(wrt) else {
                return nil
            }
            let node = MathNode(.derivative(partial: key == "partial derivative of", of: f.node, by: x.node),
                                strong: 1, connector: true)
            return (node, x.next)
        }
        if word(i) == "partial" || zhw(i, .partial) {
            guard let f = atomFactor(i + 1) else { return nil }
            var j = need(f.next)
            if word(j) == "over" || word(j) == "by" { j += 1 }
            guard word(j) == "partial" || zhw(j, .partial), let x = atomFactor(j + 1) else { return nil }
            return (MathNode(.derivative(partial: true, of: f.node, by: x.node), strong: 1, connector: true), x.next)
        }
        if inIntegral == 0, let d1 = differential(i) {
            var j = d1.next
            if word(j) == "over" || word(j) == "by" { j += 1 }
            if let d2 = differential(j) {
                return (MathNode(.derivative(partial: false, of: d1.node, by: d2.node), strong: 1, connector: true), d2.next)
            }
        }
        return nil
    }

    // MARK: Distributions

    /// normal zero one, binomial n p, t distribution with k degrees of freedom; statements add
    /// standard normal and the Chinese 均值为 ... 的正态分布 form.
    private func distribution(_ i: Int, statement: Bool) -> Parse? {
        var j = i
        if let w = word(j), ["a", "an", "the"].contains(w) {
            guard statement else { return nil }
            j += 1
        }
        var iid = false
        if let (_, k) = phrase(j, P.iid) {
            iid = true
            j = k
        }
        var zhName = zh(j, in: T.zhDistributions)
        var prefixed: (params: [MathNode], next: Int)?
        if zhName == nil, statement, let pre = chineseDistributionParameters(j), zhw(pre.next, .de),
           let name = zh(pre.next + 1, in: T.zhDistributions) {
            zhName = name
            prefixed = pre
            j = pre.next + 1
        }
        let spec: MathLexiconTables.DistributionSpec
        if let zhName, let english = T.zhDistributions[zhName], let found = T.distributions[english] {
            spec = found
            j += 1
        } else if let (key, k) = phrase(j, P.distributions), let found = T.distributions[key] {
            spec = found
            j = k
        } else {
            return nil
        }
        var hasWord = false
        if word(j) == "distribution" || word(j) == "distributed" {
            hasWord = true
            j += 1
        }
        let needsWord: Set<MathDistributionKind> = [.studentT, .fisherF, .betaDistribution, .gammaDistribution, .chiSquared]
        if !statement, !hasWord, needsWord.contains(spec.kind) { return nil }
        var params = prefixed?.params ?? []
        if params.isEmpty {
            var r = distributionParameters(j, spec, statement: statement)
            if r == nil, zhName != nil { r = chineseDistributionParameters(need(j)) }
            if let r { (params, j) = r }
        }
        if spec.kind == .standardNormal {
            guard statement else { return nil }
            params = [.number("0"), .number("1")]
        } else if params.isEmpty {
            return nil
        }
        return (MathNode(.distribution(spec, params: params, iid: iid), strong: 1, connector: true), j)
    }

    private func distributionParameters(
        _ j: Int, _ spec: MathLexiconTables.DistributionSpec, statement: Bool = false
    ) -> (params: [MathNode], next: Int)? {
        let freedomKinds: Set<MathDistributionKind> = [.studentT, .chiSquared, .fisherF]
        // A recogniser comma before "with" (a normal distribution, with mean mu ...).
        let j = isPunctuation(j, [",", "，"]) && word(j + 1) == "with" ? j + 1 : j
        if word(j) == "with" {
            var k = j + 1
            if freedomKinds.contains(spec.kind) { return degreesOfFreedom(k) }
            if let w = word(k), ["a", "an", "the"].contains(w) { k += 1 } // with a mean mu
            guard let (_, afterLead) = phrase(k, P.distributionParameterLead), let a = unit(need(afterLead)) else {
                return nil
            }
            var params = [a.node]
            var m = a.next
            if spec.parameterCount == 2 {
                if isPunctuation(m, [",", "，"]) { m += 1 }
                if word(m) == "and" { m += 1 }
                if let w = word(m), ["a", "an", "the"].contains(w), phrase(m + 1, P.secondParameter) != nil { m += 1 }
                let second = phrase(m, P.secondParameter)
                if let second { m = second.next }
                guard let b = unit(need(m)) else { return nil }
                var node = b.node
                if second?.key == "standard deviation" {
                    if let atom = node.atom, atom.superscriptNode == nil {
                        atom.superscriptNode = .number("2")
                    } else {
                        node = MathNode(.power(MathNode(.group(node)), .number("2")))
                    }
                }
                params.append(node)
                m = b.next
            }
            return (params, m)
        }
        if freedomKinds.contains(spec.kind) { return nil }
        if spec.parameterCount == 2, statement, let t = tok(j), t.kind == .word, !t.isClaimedByLabel, t.text.count == 2,
           t.text.allSatisfy({ MathLexer.isASCIILetter($0) && $0.isUppercase }), greekAt(j) == nil {
            // X follows a binomial NP: two glued capital letters the recogniser wrote for "n p", only in a
            // "follows" statement (a normal BP reading stays prose; mu and nu are Greek names).
            // Parameters are lower case (D5).
            return (t.text.map { .symbol(MathAtom(.latin(Character($0.lowercased())))) }, j + 1)
        }
        if spec.parameterCount == 2 {
            guard let r = arguments(j, uppercase: false, single: true), r.nodes.count == 2 else { return nil }
            return (r.nodes, r.next)
        }
        guard let a = atomFactor(j) else { return nil }
        return ([a.node], a.next)
    }

    /// 均值为 A 方差为 B | 参数为 A | 自由度为 K.
    private func chineseDistributionParameters(_ j: Int) -> (params: [MathNode], next: Int)? {
        if zhw(j, .mean) {
            guard let a = unit(j + 1) else { return nil }
            var k = a.next
            while isNoise(k) { k += 1 }
            if let z = zh(k), z == "方差为" || z == "方差是" || z == "方差", let b = unit(k + 1) {
                return ([a.node, b.node], b.next)
            }
            return nil
        }
        if zhw(j, .parameter) || zhw(j, .degreesOfFreedom), let a = simpleExpression(j + 1) {
            return ([a.node], a.next)
        }
        return nil
    }

    // MARK: Multiplicative level

    private func factor(_ start: Int, juxtaposed: Bool = false) -> Parse? {
        var i = start
        var negative = false
        if !juxtaposed, word(i) == "minus" || word(i) == "negative" || zhw(i, .negative) {
            negative = true
            i += 1
        }
        guard var (node, j) = primary(i, juxtaposed: juxtaposed) else { return nil }
        // Chinese postfix functions: X 的期望, X 和 Y 的协方差, X 的绝对值.
        while true {
            if zhw(j, .de), let z = zh(j + 1, in: T.zhFunctions), let id = T.zhFunctions[z], !stopChinesePostfixFunctions {
                if id == .covariance || id == .correlation { break }
                if T.functions[id]?.uppercasesArguments == true { node.uppercaseVariables() }
                node = MathNode(.function(.named(id), args: [node], given: nil), strong: 1, connector: true)
                j += 2
                continue
            }
            if zhw(j, .and), !stopChinesePostfixFunctions, let other = atomFactor(j + 1), zhw(other.next, .de),
               let z = zh(other.next + 1), z == "协方差" || z == "相关系数", let id = T.zhFunctions[z] {
                node.uppercaseVariables()
                other.node.uppercaseVariables()
                node = MathNode(.function(.named(id), args: [node, other.node], given: nil), strong: 1, connector: true)
                j = other.next + 2
                continue
            }
            if zhw(j, .de), zhw(j + 1, .absolute) {
                node = MathNode(.absolute(node, norm: false), strong: 1, connector: true)
                j += 2
                continue
            }
            break
        }
        if word(j) == "factorial" {
            node = MathNode(.factorial(node), strong: 1, connector: true)
            j += 1
        }
        if word(j) == "choose", let r = primary(j + 1) {
            node = MathNode(.binomial(node, r.node), medium: 1, connector: true)
            j = r.next
        }
        if negative {
            node = MathNode(.negate(node), strong: node.isNumber ? 0 : 1, connector: true)
        }
        return (node, j)
    }

    /// Juxtaposed factors: two pi r, beta one x. A number may only lead.
    private func unit(_ i: Int, limit: Int = 6) -> Parse? {
        guard let first = factor(i) else { return nil }
        var factors = [first.node]
        var j = first.next
        var last = first.node
        while factors.count < limit, !(last.atom.map { $0.isNamedNotation && $0.latinLetter == "H" } ?? false) {
            guard let t = tok(j), t.kind == .word || t.kind == .zh, !t.isClaimedByLabel else { break }
            if inIntegral > 0, differential(j) != nil { break }
            if t.kind == .word, isCardinalWord(t.lower) || t.lower == "infinity" { break }
            if t.kind == .word, ["a", "A", "I"].contains(t.text), !continuesAfterLetter(j + 1) { break }
            if isOperatorStart(j) { break }
            guard let r = factor(j, juxtaposed: true), !r.node.isDistribution else { break }
            factors.append(r.node)
            last = r.node
            j = r.next
        }
        return factors.count == 1 ? (factors[0], j) : (MathNode(.juxtaposition(factors)), j)
    }

    /// A juxtaposed a / A / I is a variable only when an operator or modifier follows it.
    private func continuesAfterLetter(_ j: Int) -> Bool {
        for table in [P.relations, P.additions, P.multiplications, P.divisions, P.accents, P.powers]
            where phrase(j, table) != nil {
            return true
        }
        return word(j) == "sub" || word(j) == "to" || zh(j) != nil
    }

    private func isOperatorStart(_ j: Int) -> Bool {
        for table in [P.relations, P.additions, P.multiplications, P.divisions] where phrase(j, table) != nil {
            return true
        }
        if let w = word(j), P.operatorWords.contains(w) { return true }
        return phrase(j, P.allOperators) != nil
    }

    /// unit ((times) unit)*.
    private func term(_ i: Int) -> Parse? {
        guard let first = unit(i) else { return nil }
        var units = [first.node]
        var j = first.next
        var strength = 0
        while true {
            let k = beforeInfix(j)
            let s: Int
            let operandStart: Int
            if let (key, kk) = phrase(k, P.multiplications), let value = T.multiplications[key] {
                (s, operandStart) = (value, kk)
            } else if let z = zh(k, in: T.zhMultiplications), let value = T.zhMultiplications[z] {
                (s, operandStart) = (value, k + 1)
            } else {
                break
            }
            guard let r = unit(need(operandStart)) else { break }
            units.append(r.node)
            strength += s
            j = r.next
        }
        if units.count == 1 { return (units[0], j) }
        return (MathNode(.product(units), strong: strength / 2, medium: strength % 2, connector: true), j)
    }

    // MARK: Additive level with the spoken-fraction rule (D9)

    private enum InfixOperator {
        case add(MathAddOperator)
        case over(strength: Int)
        case allOver
        case fenzhi

        var isAddOrSubtract: Bool {
            if case .add(let op) = self { return op != .plusMinus }
            return false
        }
    }

    private func additive(_ i: Int) -> Parse? {
        guard enter() else { return nil }
        defer { leave() }
        guard let first = term(i) else { return nil }
        var terms = [first.node]
        var ops: [InfixOperator] = []
        var j = first.next
        while true {
            let k = beforeInfix(j)
            var op: InfixOperator?
            var operandStart = k
            if let (key, kk) = phrase(k, P.additions), let entry = T.additions[key] {
                (op, operandStart) = (.add(entry.0), kk)
            } else if let z = zh(k, in: T.zhAdditions), let entry = T.zhAdditions[z] {
                (op, operandStart) = (.add(entry.0), k + 1)
            } else if let (key, kk) = phrase(k, P.divisions), let entry = T.divisions[key] {
                (op, operandStart) = (entry.isAllOver ? .allOver : .over(strength: entry.strength), kk)
            } else if let z = zh(k, in: T.zhDivisions), let entry = T.zhDivisions[z] {
                (op, operandStart) = (.over(strength: entry.strength), k + 1)
            } else if zhw(k, .fenzhi) {
                (op, operandStart) = (.fenzhi, k + 1)
            }
            guard let op else {
                if let (key, kk) = phrase(k, P.allPower) {
                    let whole = MathNode(.group(fold(terms, ops)))
                    let node = MathNode(.power(whole, .number(key == "all squared" ? "2" : "3")), strong: 1, connector: true)
                    terms = [node]
                    ops = []
                    j = kk
                    continue
                }
                break
            }
            guard let r = term(need(operandStart)) else { break }
            terms.append(r.node)
            ops.append(op)
            j = r.next
        }
        return (fold(terms, ops), j)
    }

    private func isSimple(_ node: MathNode) -> Bool {
        if node.isSymbol || node.isNumber { return true }
        switch node.content {
        case .root(let x, _), .negate(let x): return x.isSymbol || x.isNumber
        default: return false
        }
    }

    private func makeFraction(_ numerator: MathNode, _ denominator: MathNode, strength: Int) -> MathNode {
        MathNode(.fraction(numerator, denominator, inline: false), strong: strength == 2 ? 1 : 0, connector: true)
    }

    /// (prefix or nil, last factor)
    private func splitLast(_ node: MathNode) -> (MathNode?, MathNode) {
        guard let factors = node.productFactors else { return (nil, node) }
        let rest = Array(factors.dropLast())
        let head = rest.count == 1 ? rest[0] : MathNode(.product(rest), strong: node.strong, medium: node.medium, connector: true)
        return (head, factors[factors.count - 1])
    }

    /// (first factor, rest or nil)
    private func splitFirst(_ node: MathNode) -> (MathNode, MathNode?) {
        guard let factors = node.productFactors else { return (node, nil) }
        let rest = Array(factors.dropFirst())
        let tail = rest.count == 1 ? rest[0] : MathNode(.product(rest), strong: node.strong, medium: node.medium, connector: true)
        return (factors[0], tail)
    }

    private func times(_ a: MathNode, _ b: MathNode, source: MathNode) -> MathNode {
        MathNode(.product([a, b]), strong: source.strong, medium: source.medium, connector: true)
    }

    private func overStrength(_ op: InfixOperator) -> Int {
        if case .over(let strength) = op { return strength }
        return 2
    }

    /// Applies the fraction bars of one additive expression (design.md 5.5), then the + / - chain.
    private func fold(_ initialTerms: [MathNode], _ initialOps: [InfixOperator]) -> MathNode {
        var terms = initialTerms
        var ops = initialOps

        // all over: everything so far is the numerator.
        while let k = ops.firstIndex(where: { if case .allOver = $0 { return true }; return false }) {
            let numerator = fold(Array(terms[0...k]), Array(ops[0..<k]))
            let (first, rest) = splitFirst(terms[k + 1])
            let f = makeFraction(numerator, first, strength: 2)
            terms = [rest.map { times(f, $0, source: terms[k + 1]) } ?? f] + Array(terms[(k + 2)...])
            ops = Array(ops[(k + 1)...])
        }
        // 分之: the denominator is on the left.
        while let k = ops.firstIndex(where: { if case .fenzhi = $0 { return true }; return false }) {
            let denominator: MathNode
            let low: Int
            if k == 1, ops[0].isAddOrSubtract, isSimple(terms[0]), isSimple(terms[1]) {
                denominator = fold(Array(terms[0..<2]), Array(ops[0..<1]))
                low = 0
            } else {
                denominator = terms[k]
                low = k
            }
            let (first, rest) = splitFirst(terms[k + 1])
            let f = makeFraction(first, denominator, strength: 2)
            terms = Array(terms[0..<low]) + [rest.map { times(f, $0, source: terms[k + 1]) } ?? f] + Array(terms[(k + 2)...])
            ops = Array(ops[0..<low]) + Array(ops[(k + 1)...])
        }
        let overs = ops.indices.filter { if case .over = ops[$0] { return true }; return false }
        if overs.count == 1 {
            let k = overs[0]
            let strength = overStrength(ops[k])
            var left = Array(terms[0...k])
            let right = Array(terms[(k + 1)...])
            var leftOps = Array(ops[0..<k])
            let rightOps = Array(ops[(k + 1)...])
            let numerator: MathNode
            var lead: MathNode?
            if left.count <= 2, left.allSatisfy(isSimple), leftOps.allSatisfy(\.isAddOrSubtract) {
                numerator = fold(left, leftOps)
                left = []
                leftOps = []
            } else {
                let split = splitLast(left[left.count - 1])
                lead = split.0
                numerator = split.1
                left.removeLast()
            }
            var (denominator, tail) = splitFirst(right[0])
            var used = 1
            if tail == nil, let firstRightOp = rightOps.first, case .add(let addOp) = firstRightOp, addOp != .plusMinus,
               right.count > 1, isSimple(denominator) {
                let (next, nextTail) = splitFirst(right[1])
                if isSimple(next) {
                    denominator = MathNode(.binary(addOp, denominator, next, tight: false), strong: 1)
                    tail = nextTail
                    used = 2
                }
            }
            var f = makeFraction(numerator, denominator, strength: strength)
            if let tail { f = times(f, tail, source: right[used - 1]) }
            if let lead { f = times(lead, f, source: terms[k]) }
            terms = left + [f] + Array(right[used...])
            ops = leftOps + Array(rightOps[(used - 1)...])
        } else if overs.count > 1 {
            for (done, original) in overs.enumerated() {
                let k = original - done
                let (lead, numerator) = splitLast(terms[k])
                let (denominator, tail) = splitFirst(terms[k + 1])
                var f = makeFraction(numerator, denominator, strength: overStrength(ops[k]))
                if let tail { f = times(f, tail, source: terms[k + 1]) }
                if let lead { f = times(lead, f, source: terms[k]) }
                terms.replaceSubrange(k...(k + 1), with: [f])
                ops.remove(at: k)
            }
        }
        var node = terms[0]
        for (op, rhs) in zip(ops, terms.dropFirst()) {
            let addOp: MathAddOperator
            if case .add(let value) = op { addOp = value } else { addOp = .plus }
            node = MathNode(.binary(addOp, node, rhs, tight: false), strong: 1, connector: true)
        }
        return node
    }

    // MARK: Relation level

    func relation(_ i: Int, stopChinesePostfixFunctions stop: Bool = false) -> Parse? {
        guard enter() else { return nil }
        defer { leave() }
        let saved = stopChinesePostfixFunctions
        if stop { stopChinesePostfixFunctions = true }
        let left = additive(i)
        stopChinesePostfixFunctions = saved
        guard let left else { return nil }
        var links: [MathRelationLink] = []
        var j = left.next
        while true {
            let k = beforeInfix(j)
            var found: (MathRelationOperator, Int, Int)?
            if let (key, kk) = phrase(k, P.relations), let entry = T.relations[key] {
                found = (entry.0, entry.1, kk)
            } else if let z = zh(k, in: T.zhRelations), let entry = T.zhRelations[z] {
                found = (entry.0, entry.1, k + 1)
            }
            if let (op, strength, operandStart) = found {
                guard let r = additive(need(operandStart)) else { break }
                links.append(MathRelationLink(op: op, strength: strength, rhs: r.node))
                j = r.next
                continue
            }
            // Distribution statement: X follows a normal distribution with mean mu and variance sigma squared.
            var follows: (key: String, next: Int)?
            if let (key, kk) = phrase(k, P.follows) {
                follows = (key, kk)
            } else if zhw(k, .follows) {
                follows = ("follows", k + 1)
            }
            if let follows, links.isEmpty, let d = distribution(follows.next, statement: true),
               case .distribution(let spec, _, let iid) = d.node.content,
               !(["is", "has"].contains(follows.key) && spec.kind == .studentT) {
                left.node.uppercaseVariables()
                links.append(MathRelationLink(op: iid ? .iidAs : .distributedAs, strength: 2, rhs: d.node))
                j = d.next
                continue
            }
            break
        }
        if links.isEmpty { return left }
        let node = MathNode(.relation(left.node, links), strong: links.filter { $0.strength == 2 }.count,
                            medium: links.filter { $0.strength == 1 }.count, connector: true)
        return (node, j)
    }
}

private extension Character {
    var isASCIIDigitCharacter: Bool { MathLexer.isASCIIDigit(self) }
}
