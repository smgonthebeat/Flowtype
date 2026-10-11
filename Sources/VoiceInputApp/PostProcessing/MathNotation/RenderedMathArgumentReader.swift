import Foundation

/// A finite inverse of emitted notation, including Unicode/LaTeX hybrid operands.
/// Recognition is case-sensitive and consumes the entire token; no LaTeX is executed.
enum RenderedMathArgumentReader {
    private static let atoms: [String: MathSymbolAtom] = {
        var result: [String: MathSymbolAtom] = [:]
        for definition in MathSymbolCatalog.allGreek {
            let atom = MathSymbolAtom(spoken: definition.spoken, latex: definition.latex, unicode: definition.unicode)
            result[definition.latex] = atom
            result[definition.unicode] = atom
        }
        return result
    }()

    private static let wrappers: [(String, MathModifier)] = [
        ("\\hat{", .hat), ("\\bar{", .bar), ("\\tilde{", .tilde),
        ("\\dot{", .dot), ("\\ddot{", .doubleDot)
    ]
    private static let modifiers: [(String, MathModifier)] = [
        ("^{-1}", .inverse), ("^\\top", .transpose), ("^*", .star), ("*", .star),
        ("''", .doublePrime), ("'", .prime),
        ("\u{0302}", .hat), ("\u{0304}", .bar), ("\u{0303}", .tilde),
        ("\u{0307}", .dot), ("\u{0308}", .doubleDot), ("″", .doublePrime),
        ("′", .prime), ("ᵀ", .transpose), ("⁻¹", .inverse)
    ]
    private static let powers = [("^2", "2"), ("^3", "3"), ("²", "2"), ("³", "3")]
    private static let scripts: [(String, MathExpression)] = MathScriptCatalog.subscriptIndices.map {
        let suffix = "_" + ($0.latex.count == 1 ? $0.latex : "{" + $0.latex + "}")
        let index = MathExpression.symbol(MathSymbolAtom(spoken: $0.primarySpoken, latex: $0.latex, unicode: $0.unicode))
        return (suffix, index)
    }
    private static let unicodeSubscripts: [Unicode.Scalar: String] = [
        "₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5",
        "₆": "6", "₇": "7", "₈": "8", "₉": "9", "₊": "+", "₋": "-",
        "ᵢ": "i", "ⱼ": "j", "ₖ": "k", "ₙ": "n", "ₜ": "t"
    ]
    private static let commandPattern = try! NSRegularExpression(pattern: #"\\[A-Za-z]+"#)
    private static let commands: Set<String> = {
        var result = Set(atoms.keys.filter { $0.hasPrefix("\\") })
        for (syntax, _) in wrappers + modifiers {
            for match in commandPattern.matches(in: syntax, range: NSRange(syntax.startIndex..., in: syntax)) {
                if let range = Range(match.range, in: syntax) { result.insert(String(syntax[range])) }
            }
        }
        return result
    }()

    static func containsOnlySupportedCommands(_ phrase: String) -> Bool {
        commandPattern.matches(in: phrase, range: NSRange(phrase.startIndex..., in: phrase)).allSatisfy {
            Range($0.range, in: phrase).map { commands.contains(String(phrase[$0])) } == true
        }
    }

    static func read(_ token: String) -> MathExpression? {
        guard !token.isEmpty, token.utf8.count <= 512 else { return nil }
        // Spoken phrases have their own grammar; avoid exploring rendered suffixes for them.
        guard !token.contains(where: \.isWhitespace) else { return nil }
        if token.utf8.count > 1, token.allSatisfy({ $0.isASCII && $0.isLetter }) { return nil }
        return read(token, depth: 0)
    }

    private static func read(_ token: String, depth: Int) -> MathExpression? {
        guard depth < 16, !token.isEmpty else { return nil }
        if let atom = atoms[token] { return .symbol(atom) }
        if token.utf8.count == 1, let character = token.first, character.isASCII, character.isLetter,
           let atom = MathLexicon.symbol(from: token, uppercaseLatinForStatistics: true) { return .symbol(atom) }
        for (prefix, modifier) in wrappers where token.hasPrefix(prefix) && token.hasSuffix("}") {
            guard let base = read(String(token.dropFirst(prefix.count).dropLast()), depth: depth + 1),
                  base.isAtomLikeModifiedBase else { return nil }
            return .modified(base: base, modifier: modifier)
        }
        for (suffix, modifier) in modifiers {
            guard let prefix = removingScalarSuffix(suffix, from: token),
                  let base = read(prefix, depth: depth + 1), base.isAtomLikeModifiedBase else { continue }
            return .modified(base: base, modifier: modifier)
        }
        for (suffix, index) in scripts where token.hasSuffix(suffix) {
            guard let base = read(String(token.dropLast(suffix.count)), depth: depth + 1) else { continue }
            return .subscripted(base: base, index: index)
        }
        for (suffix, power) in powers {
            guard let prefix = removingScalarSuffix(suffix, from: token),
                  let base = read(prefix, depth: depth + 1), let exponent = MathLexicon.exponent(from: power) else { continue }
            return .powered(base: base, exponent: exponent)
        }
        let scalars = token.unicodeScalars
        var end = scalars.endIndex
        var parts: [String] = []
        while end > scalars.startIndex {
            let previous = scalars.index(before: end)
            guard let part = unicodeSubscripts[scalars[previous]] else { break }
            parts.append(part)
            end = previous
        }
        if !parts.isEmpty, let base = read(String(scalars[..<end]), depth: depth + 1) {
            let index = parts.reversed().joined()
            return .subscripted(base: base, index: .symbol(MathSymbolAtom(spoken: index, latex: index, unicode: index)))
        }
        return nil
    }

    private static func removingScalarSuffix(_ suffix: String, from text: String) -> String? {
        let scalars = text.unicodeScalars
        guard scalars.elementsEqual(suffix.unicodeScalars) == false,
              scalars.suffix(suffix.unicodeScalars.count).elementsEqual(suffix.unicodeScalars) else { return nil }
        return String(scalars.dropLast(suffix.unicodeScalars.count))
    }
}
