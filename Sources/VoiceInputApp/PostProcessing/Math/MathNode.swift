import Foundation

/// The expression tree of one spoken formula (design.md 2.2). Recognition and the evidence
/// decision both read this one tree; rendering happens once, from the tree.
enum MathAccent: Equatable {
    case hat, bar, tilde, dot, doubleDot
}

enum MathMark: Equatable {
    case prime, doublePrime, star, transpose, inverse
}

enum MathAddOperator: Equatable {
    case plus, minus, plusMinus
}

enum MathRelationOperator: Equatable {
    case equal, notEqual, less, greater, lessEqual, greaterEqual, approximately, proportional
    case tendsTo, implies, elementOf, convergesInDistribution, convergesInProbability, distributedAs, iidAs
}

enum MathFunctionID: Equatable {
    case expectation, variance, covariance, correlation, standardDeviation, standardError, probability
    case log, ln, exp, sin, cos, tan, max, min
}

enum MathDistributionKind: Equatable {
    case standardNormal, normal, binomial, poisson, exponential, uniform, bernoulli, chiSquared, studentT
    case fisherF, betaDistribution, gammaDistribution
}

enum MathBigOperatorKind: Equatable {
    case sum, product, integral, limit, argMax, argMin
}

/// A letter or Greek name with all of its modifiers on fields, so modifier order never matters
/// (beta hat one = beta one hat = beta hat sub one).
final class MathAtom {
    enum Base: Equatable {
        case latin(Character)
        case greek(String)
    }

    var base: Base
    var isUpper: Bool
    /// Case was spoken (capital X, lowercase x) and wins over every case rule.
    var isCaseForced = false
    var isVariant = false
    var accents: [MathAccent] = []
    var primes = 0
    var hasStar = false
    var isTransposed = false
    var isInverse = false
    var subscriptNode: MathNode?
    var superscriptNode: MathNode?

    // Evidence carried by the atom (design.md 6.1-6.3).
    /// Explicit modifiers spoken directly (hat, sub, squared ...).
    var modifierCount = 0
    /// Modifiers recognised through a mishearing alias (head -> hat).
    var aliasModifierCount = 0
    var isAlias = false
    /// A capitalised Greek name inside a sentence, or one followed by a capitalised word (Mu Online).
    var isProperName = false
    var followsArticle = false
    var isMathDominantGreek = false
    /// r squared, h zero, p value.
    var isNamedNotation = false
    var isNamedNotationStrong = true
    /// a A B C D F I: usually a label, grade, article or pronoun.
    var isWeakLetter = false
    var isPronounI = false

    init(_ base: Base, upper: Bool = false) {
        self.base = base
        self.isUpper = upper
    }

    var latinLetter: Character? {
        if case .latin(let letter) = base { return letter }
        return nil
    }

    var greekName: String? {
        if case .greek(let name) = base { return name }
        return nil
    }

    var hasDecoration: Bool {
        subscriptNode != nil || superscriptNode != nil || !accents.isEmpty || primes > 0 || hasStar
            || isTransposed || isInverse
    }

    func apply(_ mark: MathMark) {
        switch mark {
        case .prime: primes += 1
        case .doublePrime: primes += 2
        case .star: hasStar = true
        case .transpose: isTransposed = true
        case .inverse: isInverse = true
        }
    }
}

struct MathRelationLink {
    let op: MathRelationOperator
    let strength: Int
    let rhs: MathNode
}

struct MathBigOperator {
    let kind: MathBigOperatorKind
    let variable: MathNode?
    let lower: MathNode?
    let upper: MathNode?
    let body: MathNode?
    let differential: MathNode?
}

enum MathFunctionHead {
    case named(MathFunctionID)
    /// f of x, f prime of x, phi of x.
    case generic(MathNode)
}

final class MathNode {
    indirect enum Content {
        /// Digits, a decimal, "5%" or "inf".
        case number(String)
        /// Literal separator inside a subscript list (sub i comma j).
        case text(String)
        /// A multi-part subscript (ij, it, i,j).
        case index([MathNode])
        case symbol(MathAtom)
        case negate(MathNode)
        /// `tight` binaries live inside scripts and parameters and render without spaces (x_{n+1}).
        case binary(MathAddOperator, MathNode, MathNode, tight: Bool)
        case juxtaposition([MathNode])
        case product([MathNode])
        /// `inline` fractions live inside subscripts (z_{α/2}).
        case fraction(MathNode, MathNode, inline: Bool)
        case group(MathNode)
        case power(MathNode, MathNode)
        case factorial(MathNode)
        case root(MathNode, degree: Int)
        case absolute(MathNode, norm: Bool)
        case binomial(MathNode, MathNode)
        case function(MathFunctionHead, args: [MathNode], given: MathNode?)
        case relation(MathNode, [MathRelationLink])
        case distribution(MathLexiconTables.DistributionSpec, params: [MathNode], iid: Bool)
        case derivative(partial: Bool, of: MathNode, by: MathNode)
        case bigOperator(MathBigOperator)
    }

    let content: Content
    /// Strong (2 points) and medium (1 point) constructs introduced by this node (design.md 6.1).
    var strong = 0
    var medium = 0
    /// Recognised through a mishearing alias: contributes no evidence of its own.
    var isAlias = false
    /// A real connector: operator, function, explicit structure.
    var hasConnector = false
    /// A function whose argument is ambiguous (variance X Y): the span is kept as spoken.
    var hasAmbiguousArgument = false

    init(_ content: Content, strong: Int = 0, medium: Int = 0, connector: Bool = false) {
        self.content = content
        self.strong = strong
        self.medium = medium
        self.hasConnector = connector
    }

    static func number(_ text: String) -> MathNode { MathNode(.number(text)) }
    static func symbol(_ atom: MathAtom) -> MathNode { MathNode(.symbol(atom)) }

    var atom: MathAtom? {
        if case .symbol(let atom) = content { return atom }
        return nil
    }

    var isNumber: Bool {
        if case .number = content { return true }
        return false
    }

    var isSymbol: Bool { atom != nil }

    var numberText: String? {
        if case .number(let text) = content { return text }
        return nil
    }

    var isRelation: Bool {
        if case .relation = content { return true }
        return false
    }

    var isJuxtaposition: Bool {
        if case .juxtaposition = content { return true }
        return false
    }

    var isProduct: Bool {
        if case .product = content { return true }
        return false
    }

    var isFraction: Bool {
        if case .fraction = content { return true }
        return false
    }

    var isDistribution: Bool {
        if case .distribution = content { return true }
        return false
    }

    var isBigOperator: Bool {
        if case .bigOperator = content { return true }
        return false
    }

    /// A binary that is not tight, or a relation: wrapped in parentheses inside products.
    var isLooseBinaryOrRelation: Bool {
        switch content {
        case .binary(_, _, _, let tight): return !tight
        case .relation: return true
        default: return false
        }
    }

    /// Product factors, for splitting around a fraction bar.
    var productFactors: [MathNode]? {
        if case .product(let factors) = content { return factors }
        return nil
    }

    /// Every child node, for evidence walks.
    var children: [MathNode] {
        switch content {
        case .number, .text: return []
        case .index(let items): return items
        case .symbol(let atom): return [atom.subscriptNode, atom.superscriptNode].compactMap { $0 }
        case .negate(let x), .group(let x), .factorial(let x): return [x]
        case .root(let x, _), .absolute(let x, _): return [x]
        case .binary(_, let l, let r, _): return [l, r]
        case .juxtaposition(let items), .product(let items): return items
        case .fraction(let n, let d, _): return [n, d]
        case .power(let base, let exponent): return [base, exponent]
        case .binomial(let n, let k): return [n, k]
        case .function(let head, let args, let given):
            var result: [MathNode] = []
            if case .generic(let node) = head { result.append(node) }
            return result + args + [given].compactMap { $0 }
        case .relation(let first, let links): return [first] + links.map(\.rhs)
        case .distribution(_, let params, _): return params
        case .derivative(_, let of, let by): return [of, by]
        case .bigOperator(let op):
            return [op.variable, op.lower, op.upper, op.body, op.differential].compactMap { $0 }
        }
    }

    /// Function arguments and distribution variables are random variables: upper-case Latin letters (D5).
    func uppercaseVariables() {
        switch content {
        case .symbol(let atom):
            if atom.latinLetter != nil, !atom.isCaseForced { atom.isUpper = true }
        case .negate(let x), .group(let x), .factorial(let x), .root(let x, _), .absolute(let x, _):
            x.uppercaseVariables()
        case .power(let base, _):
            base.uppercaseVariables()
        case .binary(_, let l, let r, _):
            l.uppercaseVariables()
            r.uppercaseVariables()
        case .fraction(let n, let d, _):
            n.uppercaseVariables()
            d.uppercaseVariables()
        case .binomial(let n, let k):
            n.uppercaseVariables()
            k.uppercaseVariables()
        case .juxtaposition(let items), .product(let items):
            items.forEach { $0.uppercaseVariables() }
        case .function(_, let args, _):
            args.forEach { $0.uppercaseVariables() }
        case .relation(let first, let links):
            first.uppercaseVariables()
            links.forEach { $0.rhs.uppercaseVariables() }
        case .bigOperator(let op):
            op.body?.uppercaseVariables()
        case .number, .text, .index, .distribution, .derivative:
            break
        }
    }
}
