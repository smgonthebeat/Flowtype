import Foundation

struct MathSymbolAtom: Equatable {
    let spoken: String
    let latex: String
    let unicode: String
}

enum MathModifier: Equatable {
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

enum MathFunctionName: Equatable {
    case expectation
    case variance
    case covariance
    case correlation
    case standardDeviation
    case standardError

    var unicodeName: String {
        switch self {
        case .expectation:
            return "E"
        case .variance:
            return "Var"
        case .covariance:
            return "Cov"
        case .correlation:
            return "Corr"
        case .standardDeviation:
            return "SD"
        case .standardError:
            return "SE"
        }
    }

    var latexName: String {
        switch self {
        case .expectation:
            return "E"
        case .variance:
            return #"\mathrm{Var}"#
        case .covariance:
            return #"\mathrm{Cov}"#
        case .correlation:
            return #"\mathrm{Corr}"#
        case .standardDeviation:
            return #"\mathrm{SD}"#
        case .standardError:
            return #"\mathrm{SE}"#
        }
    }
}

indirect enum MathExpression: Equatable {
    case symbol(MathSymbolAtom)

    /// Applies a modifier to an atom-like expression.
    ///
    /// Caller contract: construct modified expressions only around symbols or
    /// other modified expressions whose root base is a symbol. Rendering
    /// modifiers around composite expressions, including subscripts, powers, or
    /// functions, is undefined for this parser slice because unicode prefix
    /// modifiers use combining marks that attach to the final rendered scalar.
    case modified(base: MathExpression, modifier: MathModifier)

    case subscripted(base: MathExpression, index: MathExpression)
    case powered(base: MathExpression, exponent: MathExpression)

    case function(name: MathFunctionName, arguments: [MathExpression])
}

extension MathExpression {
    var isAtomLikeModifiedBase: Bool {
        switch self {
        case .symbol:
            return true
        case .modified(let base, _):
            return base.isAtomLikeModifiedBase
        case .subscripted, .powered:
            return false
        case .function:
            return false
        }
    }
}
