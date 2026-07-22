import Foundation

enum CompactASRTokenNormalizer {
    private struct SubscriptSuffix {
        let compact: String
        let spoken: String
    }

    private struct ModifierSuffix {
        let compact: String
        let spoken: String
    }

    private static let subscriptSuffixes: [SubscriptSuffix] = {
        var suffixes: [SubscriptSuffix] = []
        var seen: Set<String> = []

        for token in MathScriptCatalog.subscriptIndices {
            for spokenForm in token.spokenForms {
                let spoken = MathScriptCatalog.normalize(spokenForm)
                let compact = spoken.replacingOccurrences(of: " ", with: "")
                guard !compact.isEmpty, seen.insert(compact).inserted else {
                    continue
                }
                suffixes.append(SubscriptSuffix(compact: compact, spoken: spoken))
            }
        }

        return suffixes.sorted { lhs, rhs in
            lhs.compact.count > rhs.compact.count
        }
    }()

    private static let modifierSuffixes: [ModifierSuffix] = [
        ModifierSuffix(compact: "doubleprime", spoken: "double prime"),
        ModifierSuffix(compact: "doubledot", spoken: "double dot"),
        ModifierSuffix(compact: "transpose", spoken: "transpose"),
        ModifierSuffix(compact: "inverse", spoken: "inverse"),
        ModifierSuffix(compact: "squared", spoken: "squared"),
        ModifierSuffix(compact: "square", spoken: "squared"),
        ModifierSuffix(compact: "cubed", spoken: "cubed"),
        ModifierSuffix(compact: "cube", spoken: "cubed"),
        ModifierSuffix(compact: "overbar", spoken: "bar"),
        ModifierSuffix(compact: "head", spoken: "hat"),
        ModifierSuffix(compact: "hat", spoken: "hat"),
        ModifierSuffix(compact: "bar", spoken: "bar"),
        ModifierSuffix(compact: "tilde", spoken: "tilde"),
        ModifierSuffix(compact: "prime", spoken: "prime"),
        ModifierSuffix(compact: "dot", spoken: "dot"),
        ModifierSuffix(compact: "star", spoken: "star"),
        ModifierSuffix(compact: "asterisk", spoken: "star")
    ].sorted { lhs, rhs in
        lhs.compact.count > rhs.compact.count
    }

    static func normalize(_ text: String) -> String {
        normalize(text, chainedTermSeparator: " ")
    }

    static func normalize(_ text: String, chainedTermSeparator: String) -> String {
        var result = ""
        var token = ""

        for character in text {
            if character.isASCIIAlphaNumeric {
                token.append(character)
                continue
            }

            result += normalizeToken(token, chainedTermSeparator: chainedTermSeparator)
            token.removeAll(keepingCapacity: true)
            result.append(character)
        }

        result += normalizeToken(token, chainedTermSeparator: chainedTermSeparator)
        return result
    }

    private static func normalizeToken(_ token: String, chainedTermSeparator: String) -> String {
        guard !token.isEmpty,
              let normalized = parseCompactToken(token, chainedTermSeparator: chainedTermSeparator) else {
            return token
        }
        return normalized
    }

    private static func parseCompactToken(_ token: String, chainedTermSeparator: String) -> String? {
        let characters = Array(token)
        var cursor = 0
        var terms: [String] = []

        while cursor < characters.count {
            guard let base = parseBase(in: characters, at: cursor),
                  let operation = parseOperation(in: characters, after: cursor + 1) else {
                return nil
            }

            terms.append("\(base) \(operation.spoken)")
            cursor = operation.end
        }

        return terms.joined(separator: chainedTermSeparator)
    }

    private static func parseBase(in characters: [Character], at cursor: Int) -> String? {
        guard cursor < characters.count,
              let scalar = characters[cursor].unicodeScalars.first,
              scalar.value >= UnicodeScalar("A").value,
              scalar.value <= UnicodeScalar("Z").value else {
            return nil
        }
        return String(characters[cursor])
    }

    private static func parseOperation(
        in characters: [Character],
        after cursor: Int
    ) -> (spoken: String, end: Int)? {
        if let subscriptOperation = parseSubscriptOperation(in: characters, after: cursor) {
            return subscriptOperation
        }
        return parseModifierOperation(in: characters, after: cursor)
    }

    private static func parseSubscriptOperation(
        in characters: [Character],
        after cursor: Int
    ) -> (spoken: String, end: Int)? {
        guard matches("sub", in: characters, at: cursor) else {
            return nil
        }

        let suffixStart = cursor + 3
        for suffix in subscriptSuffixes {
            guard matches(suffix.compact, in: characters, at: suffixStart) else {
                continue
            }
            return ("sub \(suffix.spoken)", suffixStart + suffix.compact.count)
        }

        return nil
    }

    private static func parseModifierOperation(
        in characters: [Character],
        after cursor: Int
    ) -> (spoken: String, end: Int)? {
        for suffix in modifierSuffixes {
            guard matches(suffix.compact, in: characters, at: cursor) else {
                continue
            }
            return (suffix.spoken, cursor + suffix.compact.count)
        }

        return nil
    }

    private static func matches(
        _ needle: String,
        in characters: [Character],
        at cursor: Int
    ) -> Bool {
        let needleCharacters = Array(needle)
        guard cursor + needleCharacters.count <= characters.count else {
            return false
        }

        for offset in needleCharacters.indices {
            guard characters[cursor + offset].lowercased() == String(needleCharacters[offset]) else {
                return false
            }
        }

        return true
    }
}

private extension Character {
    var isASCIIAlphaNumeric: Bool {
        guard let scalar = unicodeScalars.first, unicodeScalars.count == 1 else {
            return false
        }
        return (scalar.value >= UnicodeScalar("A").value && scalar.value <= UnicodeScalar("Z").value)
            || (scalar.value >= UnicodeScalar("a").value && scalar.value <= UnicodeScalar("z").value)
            || (scalar.value >= UnicodeScalar("0").value && scalar.value <= UnicodeScalar("9").value)
    }
}
