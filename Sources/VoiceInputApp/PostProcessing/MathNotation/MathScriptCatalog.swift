import Foundation

struct MathScriptToken: Equatable {
    let spokenForms: [String]
    let latex: String
    let unicode: String

    var primarySpoken: String { spokenForms[0] }
}

enum MathScriptCatalog {
    static let subscriptIndices: [MathScriptToken] = {
        let compositeTokens: [MathScriptToken] = [
            MathScriptToken(spokenForms: ["t minus one", "t minus 1", "t-1"], latex: "t-1", unicode: "t-1"),
            MathScriptToken(spokenForms: ["t plus one", "t plus 1", "t+1"], latex: "t+1", unicode: "t+1"),
            MathScriptToken(spokenForms: ["i comma t", "i,t"], latex: "i,t", unicode: "i,t"),
            MathScriptToken(spokenForms: ["j comma t", "j,t"], latex: "j,t", unicode: "j,t"),
            MathScriptToken(spokenForms: ["i t", "it"], latex: "it", unicode: "it"),
            MathScriptToken(spokenForms: ["j t", "jt"], latex: "jt", unicode: "jt")
        ]

        let numberWords: [String] = [
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
            "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
            "twenty"
        ]
        let numericTokens = numberWords.enumerated().map { number, word in
            MathScriptToken(spokenForms: [word, String(number)], latex: String(number), unicode: String(number))
        }

        let letterTokens: [MathScriptToken] = [
            "i", "j", "k", "m", "n", "p", "q", "r", "s", "t", "x", "y", "z", "f"
        ].map { letter in
            MathScriptToken(spokenForms: [letter], latex: letter, unicode: letter)
        }

        return compositeTokens + numericTokens + letterTokens
    }()

    static let subscriptLookup: [String: MathScriptToken] = {
        var lookup: [String: MathScriptToken] = [:]
        for token in subscriptIndices {
            for spokenForm in token.spokenForms {
                lookup[normalize(spokenForm)] = token
            }
        }
        return lookup
    }()

    static let subscriptPattern: String = {
        let alternatives = subscriptIndices
            .flatMap(\.spokenForms)
            .map(normalize)
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: #"\\ "#, with: #"\s+"#) }
            .joined(separator: "|")
        return "(?i:\(alternatives))"
    }()

    static func subscriptIndex(from phrase: String) -> MathScriptToken? {
        subscriptLookup[normalize(phrase)]
    }

    static func normalize(_ phrase: String) -> String {
        phrase
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
