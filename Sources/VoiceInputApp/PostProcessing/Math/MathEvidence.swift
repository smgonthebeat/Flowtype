import Foundation

/// Per-span intent decision (design.md 6). Evidence is counted on the parsed tree; there is no
/// second keyword matcher.
enum MathEvidence {
    struct Tally {
        var strong = 0
        var medium = 0
        /// Distinct solid Latin letters (not a A B C D F I).
        var solidLetters = Set<String>()
        var greek = 0
        var alias = 0
        var hasConnector = false
        var hasAliasConnector = false
        var isStructured = false
        var atoms = 0
        var numbers = 0
        var pronouns = 0
        var properNames = 0
        var hasArithmetic = false
        var hasAmbiguousArgument = false

        /// design.md 6.1: strong 2 points, medium 1, up to two solid letters 1 each.
        var score: Int { 2 * strong + medium + min(2, solidLetters.count) }
    }

    struct Decision: Equatable {
        let accepted: Bool
        let reason: String
    }

    struct Context {
        /// The span is the whole sentence (ignoring punctuation).
        let isStandalone: Bool
        /// Another structured span in the same sentence was accepted (second pass).
        let hasSentenceBonus: Bool
        /// The previous word licenses a prose-common Greek name (parameter, where, 其中 ...).
        let hasCue: Bool
    }

    static func tally(_ node: MathNode) -> Tally {
        var tally = Tally()
        walk(node, into: &tally)
        return tally
    }

    private static func walk(_ node: MathNode, into tally: inout Tally) {
        switch node.content {
        case .symbol(let atom):
            tally.alias += (atom.isAlias ? 1 : 0) + atom.aliasModifierCount
            if atom.greekName != nil, !atom.isAlias {
                tally.greek += 1
                if atom.isProperName { tally.properNames += 1 }
            } else if let letter = atom.latinLetter, !atom.isAlias {
                if atom.isNamedNotation {
                    tally.strong += atom.isNamedNotationStrong ? 1 : 0
                    tally.hasConnector = true
                } else if !atom.isWeakLetter {
                    tally.solidLetters.insert(String(letter).lowercased())
                }
                if atom.isPronounI { tally.pronouns += 1 }
            }
            if atom.modifierCount > 0 {
                tally.hasConnector = true
                if !atom.isWeakLetter, !atom.isAlias { tally.strong += atom.modifierCount }
            }
            if atom.aliasModifierCount > 0 { tally.hasAliasConnector = true }
            // A misheard Greek name with a modifier (better head, betterhead) is two independent cues
            // that agree on one decorated symbol: medium evidence. A bare alias, or one after an article
            // (a bad hat), still counts nothing.
            if atom.isAlias, atom.greekName != nil, !atom.followsArticle, atom.modifierCount + atom.aliasModifierCount > 0 {
                tally.medium += 1
            }
            if atom.hasDecoration { tally.isStructured = true }
            tally.atoms += 1
            if let sub = atom.subscriptNode { walk(sub, into: &tally) }
            if let sup = atom.superscriptNode { walk(sup, into: &tally) }
            return
        case .number:
            tally.numbers += 1
            return
        case .text:
            return
        default:
            break
        }
        tally.isStructured = true
        if node.hasAmbiguousArgument { tally.hasAmbiguousArgument = true }
        switch node.content {
        case .binary, .product, .power, .fraction, .root, .factorial: tally.hasArithmetic = true
        default: break
        }
        switch node.content {
        case .juxtaposition, .index: break
        default: tally.hasConnector = tally.hasConnector || node.hasConnector
        }
        if node.isAlias {
            tally.alias += 1
        } else {
            tally.strong += node.strong
            tally.medium += node.medium
        }
        for child in node.children { walk(child, into: &tally) }
    }

    static func isLetterRun(_ node: MathNode) -> Bool {
        guard case .juxtaposition(let factors) = node.content else { return false }
        return factors.allSatisfy { factor in
            guard let atom = factor.atom else { return false }
            return atom.latinLetter != nil && !atom.hasDecoration && !atom.isCaseForced
        }
    }

    /// design.md 6.2, in order, with the alias rule of 6.3.
    static func decide(_ node: MathNode, context: Context) -> Decision {
        let ev = tally(node)
        // A run of bare Latin letters is spelling (U S A, x y z: design.md 5.2), so another formula
        // in the sentence does not turn it into a product.
        let bonus = context.hasSentenceBonus && !isLetterRun(node)
        if let atom = node.atom, !ev.isStructured {
            guard atom.greekName != nil, !atom.isAlias else { return Decision(accepted: false, reason: "bare letter") }
            if context.isStandalone { return Decision(accepted: true, reason: "standalone symbol") }
            if atom.isProperName || atom.followsArticle { return Decision(accepted: false, reason: "name or noun use") }
            if atom.isMathDominantGreek { return Decision(accepted: true, reason: "math-dominant Greek name") }
            let licensed = bonus || context.hasCue
            return Decision(accepted: licensed, reason: "prose-common Greek name" + (licensed ? " with context" : ""))
        }
        if let atom = node.atom, atom.greekName != nil, !atom.isAlias, atom.modifierCount == 0, atom.aliasModifierCount > 0 {
            // A real Greek name with only misheard modifiers (theta head, Sigma Squid). The modifier adds
            // no evidence, but it must not make the name weaker than it is bare; and a proper name is
            // not followed by head or squid, so capitals do not block it.
            if context.isStandalone { return Decision(accepted: true, reason: "standalone symbol") }
            if atom.followsArticle { return Decision(accepted: false, reason: "name or noun use") }
            let licensed = atom.isMathDominantGreek || bonus || context.hasCue
            return Decision(accepted: licensed, reason: "Greek name with a misheard modifier" + (licensed ? "" : " without context"))
        }
        if node.isNumber { return Decision(accepted: false, reason: "bare number") }
        if ev.hasAmbiguousArgument { return Decision(accepted: false, reason: "ambiguous function argument") }
        if let atom = node.atom, atom.isNamedNotation {
            if atom.isNamedNotationStrong, ev.isStructured { return Decision(accepted: true, reason: "named notation") }
            if !atom.isNamedNotationStrong {
                let licensed = context.isStandalone || bonus
                return Decision(accepted: licensed, reason: "hypothesis symbol" + (licensed ? " with context" : " without context"))
            }
        }
        if ev.pronouns > 0, ev.strong == 0 { return Decision(accepted: false, reason: "pronoun I") }
        if ev.greek > 0, ev.isStructured {
            if ev.hasConnector { return Decision(accepted: true, reason: "Greek symbol in a structure") }
            if ev.properNames == 0, ev.greek < ev.atoms + ev.numbers {
                return Decision(accepted: true, reason: "Greek symbol with a coefficient or index")
            }
        }
        if node.isRelation, ev.atoms == 0, !ev.hasArithmetic {
            return Decision(accepted: false, reason: "numbers only without arithmetic") // five is less than ten (D6)
        }
        let score = ev.score + (bonus ? 2 : 0)
        if score >= 3 { return Decision(accepted: true, reason: "evidence \(score)") }
        if context.isStandalone, ev.hasConnector || ev.hasAliasConnector {
            if ev.atoms == 0, ev.strong == 0 { return Decision(accepted: false, reason: "numbers only") }
            return Decision(accepted: true, reason: "standalone formula")
        }
        return Decision(accepted: false, reason: "evidence \(score)")
    }
}
