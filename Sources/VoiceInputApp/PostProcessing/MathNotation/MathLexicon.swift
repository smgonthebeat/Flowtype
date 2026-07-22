import Foundation

enum MathLexicon {
    private static let greekSymbols: [String: MathSymbolAtom] = {
        var symbols: [String: MathSymbolAtom] = [:]

        for definition in MathSymbolCatalog.allGreek {
            let atom = MathSymbolAtom(
                spoken: definition.spoken,
                latex: definition.latex,
                unicode: definition.unicode
            )
            for spokenForm in definition.allParserForms {
                symbols[normalizeSpaces(spokenForm)] = atom
            }
            symbols[definition.unicode] = atom
            symbols[definition.latex] = atom
        }

        return symbols
    }()

    static func symbol(from phrase: String, uppercaseLatinForStatistics: Bool) -> MathSymbolAtom? {
        let normalized = normalizeSpaces(phrase)
        if let greek = greekSymbols[normalized] {
            return greek
        }

        if normalized.hasPrefix("capital ") || normalized.hasPrefix("big ") {
            guard let letter = normalized.split(separator: " ").last, letter.count == 1 else {
                return nil
            }
            let rendered = String(letter).uppercased()
            return MathSymbolAtom(spoken: normalized, latex: rendered, unicode: rendered)
        }

        guard normalized.count == 1,
              let scalar = normalized.unicodeScalars.first,
              scalar.value >= UnicodeScalar("a").value,
              scalar.value <= UnicodeScalar("z").value else {
            return nil
        }

        let rendered = uppercaseLatinForStatistics ? String(UnicodeScalar(scalar.value - 32)!) : normalized
        return MathSymbolAtom(spoken: normalized, latex: rendered, unicode: rendered)
    }

    static func modifier(from phrase: String) -> MathModifier? {
        switch normalizeSpaces(phrase) {
        case "hat", "head":
            return .hat
        case "bar", "overbar":
            return .bar
        case "tilde":
            return .tilde
        case "dot":
            return .dot
        case "double dot":
            return .doubleDot
        case "prime":
            return .prime
        case "double prime":
            return .doublePrime
        case "star", "asterisk":
            return .star
        case "transpose":
            return .transpose
        case "inverse":
            return .inverse
        case "square", "squared":
            return .squared
        case "cube", "cubed":
            return .cubed
        default:
            return nil
        }
    }

    static func subscriptIndex(from phrase: String) -> MathExpression? {
        guard let token = MathScriptCatalog.subscriptIndex(from: phrase) else {
            return nil
        }
        return .symbol(
            MathSymbolAtom(
                spoken: token.primarySpoken,
                latex: token.latex,
                unicode: token.unicode
            )
        )
    }

    static func exponent(from phrase: String) -> MathExpression? {
        switch normalizeSpaces(phrase) {
        case "square", "squared", "two", "2":
            return .symbol(MathSymbolAtom(spoken: "two", latex: "2", unicode: "2"))
        case "cube", "cubed", "three", "3":
            return .symbol(MathSymbolAtom(spoken: "three", latex: "3", unicode: "3"))
        default:
            return nil
        }
    }

    static func function(from phrase: String) -> MathFunctionName? {
        switch normalizeSpaces(phrase) {
        case "expectation", "expected value", "e":
            return .expectation
        case "variance", "variant", "variants", "var":
            return .variance
        case "covariance", "cov":
            return .covariance
        case "correlation", "corr", "cor":
            return .correlation
        case "standard deviation", "sd", "s d":
            return .standardDeviation
        case "standard error", "standard arrow", "se", "s e":
            return .standardError
        default:
            return nil
        }
    }

    static func normalizeSpaces(_ phrase: String) -> String {
        phrase
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
