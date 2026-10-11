import Foundation

/// English number phrases: the maximal grammatical phrase converts as a whole or stays in words.
enum EnglishNumericRecognizer {
    struct Token {
        enum Kind { case word, digits }
        let kind: Kind
        let range: Range<Int>
        let original: String
        let lower: String
        let standalone: Bool

        var isTitle: Bool { original.first.map(CharClass.isASCIIUppercase) ?? false }
        var isWord: Bool { kind == .word }
    }

    static let labelNouns: Set<String> = [
        "version", "chapter", "step", "page", "number", "level", "phase", "question", "part", "section",
        "figure", "table", "exercise", "problem", "option", "item", "line", "row", "column", "port", "room",
        "day", "week", "set", "sheet", "lecture", "unit", "lesson", "round", "stage", "slide", "episode",
        "season", "track", "task", "grade", "floor", "gate", "bus", "route", "channel", "volume", "book",
        "verse", "act", "scene", "term", "group", "team", "player", "game", "test", "case", "rule", "note",
        "appendix", "lab", "assignment", "quiz", "module", "class", "release", "build", "iteration", "sprint",
        "milestone", "tier", "rank", "size", "box", "slot", "node", "worker", "camera", "screen", "tab"
    ]
    static let currencyAndClockWords: Set<String> = [
        "dollar", "dollars", "cent", "cents", "euro", "euros", "pound", "pounds", "yuan", "yen", "buck", "bucks",
        "pm"
    ]
    static let operatorWords: Set<String> = ["to", "through", "thru", "plus", "minus", "times", "over", "equals", "in", "or"]
    /// Plural decades and scales (the twenty twenties, hundreds): the phrase stays in words.
    static let pluralNumberWords: Set<String> = [
        "tens", "teens", "twenties", "thirties", "forties", "fifties", "sixties", "seventies", "eighties",
        "nineties", "hundreds", "thousands", "millions", "billions"
    ]
    static let fractionWords: Set<String> = [
        "half", "halves", "third", "thirds", "fourth", "fourths", "fifth", "fifths", "sixth", "sixths",
        "seventh", "sevenths", "eighth", "eighths", "ninth", "ninths", "tenth", "tenths", "quarter", "quarters"
    ]

    // MARK: - Tokens

    static func tokens(_ context: NumericContext) -> [Token] {
        let text = context.text
        var raw: [Token] = []
        var offset = 0
        while offset < text.count {
            let c = text[offset]
            if CharClass.isASCIILetter(c) {
                var end = offset
                while end < text.count, CharClass.isASCIILetter(text[end]) { end += 1 }
                let original = text.slice(offset..<end)
                raw.append(Token(kind: .word, range: offset..<end, original: original, lower: original.lowercased(),
                                 standalone: isStandaloneWord(offset..<end, text)))
                offset = end
            } else if CharClass.isASCIIDigit(c) {
                var end = offset
                while end < text.count, CharClass.isASCIIDigit(text[end])
                        || text[end] == "." && text.at(end + 1).map(CharClass.isASCIIDigit) == true { end += 1 }
                let original = text.slice(offset..<end)
                raw.append(Token(kind: .digits, range: offset..<end, original: original, lower: original,
                                 standalone: isStandaloneDigits(offset..<end, text)))
                offset = end
            } else {
                offset += 1
            }
        }
        // Merge tens-unit hyphen compounds ("twenty-one") into one standalone token.
        var merged: [Token] = []
        var index = 0
        while index < raw.count {
            if index + 1 < raw.count, raw[index].isWord, raw[index + 1].isWord,
               raw[index + 1].range.lowerBound == raw[index].range.upperBound + 1,
               text.at(raw[index].range.upperBound) == "-",
               EnglishNumberGrammar.splitCompound(raw[index].lower + "-" + raw[index + 1].lower) != nil {
                let range = raw[index].range.lowerBound..<raw[index + 1].range.upperBound
                let original = text.slice(range)
                let leftOK = raw[index].standalone || !leftAttached(range.lowerBound, text)
                let standalone = leftOK && isStandaloneWord(range, text)
                merged.append(Token(kind: .word, range: range, original: original, lower: original.lowercased(),
                                    standalone: standalone))
                index += 2
            } else {
                merged.append(raw[index])
                index += 1
            }
        }
        return merged
    }

    private static func leftAttached(_ start: Int, _ text: NumericText) -> Bool {
        guard let left = text.at(start - 1) else { return false }
        if CharClass.isASCIIWordChar(left) || "'’@/\\".contains(left) { return true }
        if left == "-" || left == ".", let before = text.at(start - 2),
           CharClass.isASCIILetter(before) || CharClass.isASCIIDigit(before) { return true }
        return false
    }

    /// A word joined to another word by a hyphen, apostrophe, dot, slash or underscore is not standalone.
    static func isStandaloneWord(_ range: Range<Int>, _ text: NumericText) -> Bool {
        if leftAttached(range.lowerBound, text) { return false }
        guard let right = text.at(range.upperBound) else { return true }
        if CharClass.isASCIIWordChar(right) || "@/\\".contains(right) { return false }
        if "'’".contains(right), let next = text.at(range.upperBound + 1), CharClass.isASCIILetter(next) { return false }
        if right == "-", let next = text.at(range.upperBound + 1), CharClass.isASCIILetter(next) { return false }
        if right == ".", let next = text.at(range.upperBound + 1),
           CharClass.isASCIILetter(next) || CharClass.isASCIIDigit(next) {
            return SentenceBoundary.isBoundary(at: range.upperBound, in: text)
        }
        return true
    }

    private static func isStandaloneDigits(_ range: Range<Int>, _ text: NumericText) -> Bool {
        if let left = text.at(range.lowerBound - 1) {
            if CharClass.isASCIIWordChar(left) || "./,\\".contains(left) && text.at(range.lowerBound - 2).map(CharClass.isASCIIWordChar) == true {
                return false
            }
            if left == "." || left == "/" { return false }
        }
        return true
    }

    static func adjacent(_ lhs: Token, _ rhs: Token, _ text: NumericText) -> Bool {
        guard rhs.range.lowerBound > lhs.range.upperBound else { return false }
        for offset in lhs.range.upperBound..<rhs.range.lowerBound where !CharClass.isHorizontalSpace(text[offset]) {
            return false
        }
        return true
    }

    /// End offset of a standalone "percent" / "per cent" marker starting at `offset`.
    static func percentMarkerEnd(at offset: Int, _ context: NumericContext) -> Int? {
        let text = context.text
        guard let first = text.at(offset), CharClass.isASCIILetter(first),
              !(text.at(offset - 1).map(CharClass.isASCIIWordChar) ?? false) else { return nil }
        var end = offset
        while end < text.count, CharClass.isASCIILetter(text[end]) { end += 1 }
        let word = text.slice(offset..<end).lowercased()
        var markerEnd: Int?
        if word == "percent" {
            markerEnd = end
        } else if word == "per" {
            let next = text.skipSpaces(from: end)
            if next > end, text.slice(next..<min(text.count, next + 4)).lowercased() == "cent",
               !(text.at(next + 4).map(CharClass.isASCIILetter) ?? false) {
                markerEnd = next + 4
            }
        }
        guard let markerEnd, !(text.at(markerEnd).map(CharClass.isASCIIWordChar) ?? false) else { return nil }
        // "percent points" / "percent sign" are ordinary prose.
        let after = text.skipSpaces(from: markerEnd)
        if after > markerEnd {
            var wordEnd = after
            while wordEnd < text.count, CharClass.isASCIILetter(text[wordEnd]) { wordEnd += 1 }
            if ["point", "points", "sign", "signs"].contains(text.slice(after..<wordEnd).lowercased()) { return nil }
        }
        return markerEnd
    }

    // MARK: - Scalar (used after 百分之)

    struct Scalar {
        let range: Range<Int>
        let value: String?
    }

    /// Parses `cardinal [point fraction]` in English words starting at `offset`.
    static func scalar(from offset: Int, _ context: NumericContext) -> Scalar? {
        let all = tokens(context)
        guard let first = all.firstIndex(where: { $0.range.lowerBound == offset }) else { return nil }
        var words: [String] = []
        var index = first
        while index < all.count, all[index].isWord, all[index].standalone,
              index == first || adjacent(all[index - 1], all[index], context.text),
              EnglishNumberGrammar.isCardinalWord(all[index].lower)
                || EnglishNumberGrammar.splitCompound(all[index].lower) != nil
                || all[index].lower == "and" && !words.isEmpty {
            words += EnglishNumberGrammar.splitCompound(all[index].lower) ?? [all[index].lower]
            index += 1
        }
        guard index > first else { return nil }
        var end = all[index - 1].range.upperBound
        var value = EnglishNumberGrammar.cardinal(words).map(String.init)
        if index < all.count, all[index].lower == "point", adjacent(all[index - 1], all[index], context.text) {
            var fraction: [String] = []
            var cursor = index + 1
            while cursor < all.count, all[cursor].standalone, adjacent(all[cursor - 1], all[cursor], context.text),
                  isFractionToken(all[cursor]) {
                fraction.append(all[cursor].lower)
                cursor += 1
            }
            end = all[cursor - 1].range.upperBound
            if let digits = EnglishNumberGrammar.fractionDigits(fraction), !fraction.isEmpty {
                value = value.map { $0 + "." + digits }
            } else {
                value = nil
            }
        }
        return Scalar(range: offset..<end, value: value)
    }

    private static func isFractionToken(_ token: Token) -> Bool {
        if token.kind == .digits { return !token.original.contains(".") }
        let w = token.lower
        return EnglishNumberGrammar.units[w] != nil || w == "oh" || EnglishNumberGrammar.teens[w] != nil
            || EnglishNumberGrammar.tens[w] != nil
    }

    private static func isNumericToken(_ token: Token) -> Bool {
        token.kind == .digits || token.standalone && (isCardinalStart(token) || token.lower == "hundred"
            || EnglishNumberGrammar.scales[token.lower] != nil)
    }

    private static func isCardinalStart(_ token: Token) -> Bool {
        let w = token.lower
        return EnglishNumberGrammar.units[w] != nil || EnglishNumberGrammar.teens[w] != nil
            || EnglishNumberGrammar.tens[w] != nil || EnglishNumberGrammar.splitCompound(w) != nil
    }

    // MARK: - Recognition

    private struct Phrase {
        let first: Int
        let last: Int
        let isLoneOneOrZero: Bool
        var proposal: NumericProposal?
        var abstention: NumericAbstention?
    }

    static func recognize(_ context: NumericContext) -> NumericDecisions {
        let text = context.text
        let all = tokens(context)
        var phrases: [Phrase] = []
        var decisions = NumericDecisions()
        var index = 0

        func isAdjacentWord(_ i: Int, _ j: Int) -> Bool {
            j < all.count && i >= 0 && all[j].isWord && all[j].standalone && adjacent(all[i], all[j], text)
        }
        func span(_ first: Int, _ last: Int) -> Range<Int> {
            all[first].range.lowerBound..<all[last].range.upperBound
        }
        func markerEnd(after i: Int) -> Int? {
            guard i + 1 < all.count, all[i + 1].isWord, adjacent(all[i], all[i + 1], text) else { return nil }
            return percentMarkerEnd(at: all[i + 1].range.lowerBound, context)
        }
        func markerTokenCount(after i: Int) -> Int {
            guard let end = markerEnd(after: i) else { return 0 }
            var count = 0
            var cursor = i + 1
            while cursor < all.count, all[cursor].range.lowerBound < end { count += 1; cursor += 1 }
            return count
        }
        /// Duplicate marker after a percent marker ending at token `i` (25 percent percent, 3.5 percent%).
        func duplicateMarkerEnd(afterToken i: Int) -> Int? {
            let end = all[i].range.upperBound
            let next = text.skipSpaces(from: end)
            if let c = text.at(next), c == "%" || c == "％" { return next + 1 }
            return percentMarkerEnd(at: next, context).flatMap { next > end ? $0 : nil }
        }
        func nameEvidence(_ first: Int, _ last: Int) -> Bool {
            guard (first...last).contains(where: { all[$0].isWord && all[$0].isTitle }) else { return false }
            if first > 0, isAdjacentWord(first - 1, first) || all[first - 1].isWord && adjacent(all[first - 1], all[first], text) {
                var previous = all[first - 1]
                // A possessive belongs to the word before it (Ocean's Eleven).
                if previous.lower == "s", first > 1, let apostrophe = text.at(previous.range.lowerBound - 1),
                   "'’".contains(apostrophe), all[first - 2].range.upperBound == previous.range.lowerBound - 1 {
                    previous = all[first - 2]
                }
                if labelNouns.contains(previous.lower) { return false }
                if previous.isWord, previous.isTitle, previous.lower != "i", !isCardinalStart(previous),
                   !isSentenceInitial(previous) { return true }
            }
            if last + 1 < all.count, all[last + 1].isWord, adjacent(all[last], all[last + 1], text) {
                let next = all[last + 1]
                if next.isTitle, next.lower != "i", !isCardinalStart(next), next.lower != "point",
                   next.lower != "percent" { return true }
            }
            return false
        }
        func isSentenceInitial(_ token: Token) -> Bool {
            let before = text.skipSpacesBackward(from: token.range.lowerBound)
            guard let c = text.at(before - 1) else { return true }
            return ".!?。！？\n".contains(c) || CharClass.isHan(c) || "“\"‘'（(「".contains(c)
        }

        while index < all.count {
            let token = all[index]
            guard token.standalone || token.kind == .digits, !context.isProtected(token.range) else { index += 1; continue }

            // "a hundred percent"
            if token.isWord, token.lower == "a", isAdjacentWord(index, index + 1),
               ["hundred", "thousand"].contains(all[index + 1].lower), let end = markerEnd(after: index + 1) {
                let value = all[index + 1].lower == "hundred" ? "100%" : "1000%"
                let range = token.range.lowerBound..<end
                if !context.isProtected(range) {
                    decisions.propose(range, value, rule: "numeric.en.percent", evidence: "a hundred + percent")
                }
                index += 2 + markerTokenCount(after: index + 1)
                continue
            }

            // Bare "point five": only "point five percent" converts.
            if token.isWord, token.lower == "point" {
                var cursor = index + 1
                while cursor < all.count, all[cursor].standalone, adjacent(all[cursor - 1], all[cursor], text),
                      isFractionToken(all[cursor]) { cursor += 1 }
                if cursor > index + 1 {
                    let fraction = all[(index + 1)..<cursor].map(\.lower)
                    if let end = markerEnd(after: cursor - 1), let digits = EnglishNumberGrammar.fractionDigits(fraction) {
                        let range = token.range.lowerBound..<end
                        if !context.isProtected(range) {
                            decisions.propose(range, "0." + digits + "%", rule: "numeric.en.percent",
                                              evidence: "point + digits + percent")
                        }
                        index = cursor + markerTokenCount(after: cursor - 1)
                    } else {
                        decisions.abstain(span(index, cursor - 1), rule: "numeric.en.decimal.abstain",
                                          reason: "bare 'point N' without an integer stays in words")
                        index = cursor
                    }
                    continue
                }
                index += 1
                continue
            }

            // Digit tokens followed by point/percent.
            if token.kind == .digits {
                index = digitPhrase(at: index, all, context, &decisions)
                continue
            }

            guard token.isWord, isCardinalStart(token) else { index += 1; continue }

            // Integer part.
            var words: [String] = []
            var cursor = index
            while cursor < all.count, all[cursor].isWord, all[cursor].standalone,
                  cursor == index || adjacent(all[cursor - 1], all[cursor], text),
                  !context.isProtected(all[cursor].range) {
                let w = all[cursor].lower
                if let parts = EnglishNumberGrammar.splitCompound(w) {
                    words += parts
                } else if EnglishNumberGrammar.isCardinalWord(w) {
                    words.append(w)
                } else if w == "and", let last = words.last, last == "hundred" || EnglishNumberGrammar.scales[last] != nil,
                          isAdjacentWord(cursor, cursor + 1), isCardinalStart(all[cursor + 1]) {
                    words.append(w)
                } else if w == "oh", words.allSatisfy({ EnglishNumberGrammar.units[$0] != nil || $0 == "oh" }) {
                    words.append(w)
                } else {
                    break
                }
                cursor += 1
            }
            let first = index
            let last = cursor - 1
            let integerRange = span(first, last)
            let isLone = words == ["one"] || words == ["zero"]

            // Decimal: N point digits.
            if isAdjacentWord(last, cursor), all[cursor].lower == "point" {
                if isLone, words == ["one"], first > 0, all[first - 1].lower == "at",
                   adjacent(all[first - 1], all[first], text) {
                    decisions.abstain(span(first, cursor), rule: "numeric.en.decimal.abstain",
                                      reason: "'at one point' is not a decimal")
                    index = cursor + 1
                    continue
                }
                var fractionEnd = cursor + 1
                while fractionEnd < all.count, all[fractionEnd].standalone,
                      adjacent(all[fractionEnd - 1], all[fractionEnd], text), isFractionToken(all[fractionEnd]),
                      !context.isProtected(all[fractionEnd].range) { fractionEnd += 1 }
                if fractionEnd > cursor + 1 {
                    index = decimalPhrase(integerWords: words, integerDigits: nil, first: first, point: cursor,
                                          fractionEnd: fractionEnd, all, context, &decisions,
                                          nameEvidence: nameEvidence(first, fractionEnd - 1))
                    continue
                }
                // A number word right after "point" that belongs to a compound (point six-six):
                // the decimal is incomplete, so the whole phrase stays as dictated.
                if cursor + 1 < all.count, adjacent(all[cursor], all[cursor + 1], text), all[cursor + 1].isWord,
                   !all[cursor + 1].standalone, isFractionToken(all[cursor + 1]) {
                    var stop = all[cursor + 1].range.upperBound
                    while stop < text.count, CharClass.isASCIIWordChar(text[stop]) || text[stop] == "-" { stop += 1 }
                    decisions.abstain(all[first].range.lowerBound..<stop, rule: "numeric.en.decimal.abstain",
                                      reason: "fraction word is part of a compound")
                    index = cursor + 2
                    continue
                }
                if markerEnd(after: cursor) != nil {
                    let end = markerEnd(after: cursor)!
                    decisions.abstain(all[first].range.lowerBound..<end, rule: "numeric.en.percent.abstain",
                                      reason: "point without digits")
                    index = cursor + 1 + markerTokenCount(after: cursor)
                    continue
                }
            }

            // Percent.
            if let end = markerEnd(after: last) {
                var range = all[first].range.lowerBound..<end
                // Juxtaposed numbers before a percent (3.5 six percent) stay as dictated.
                let juxtaposed = first > 0 && adjacent(all[first - 1], all[first], text) && isNumericToken(all[first - 1])
                if juxtaposed { range = all[first - 1].range.lowerBound..<end }
                let markerTokens = markerTokenCount(after: last)
                let markerLast = last + markerTokens
                if let value = EnglishNumberGrammar.cardinal(words), duplicateMarkerEnd(afterToken: markerLast) == nil,
                   !nameEvidence(first, last), !juxtaposed {
                    decisions.propose(range, "\(value)%", rule: "numeric.en.percent", evidence: "cardinal + percent")
                } else {
                    let abstainEnd = duplicateMarkerEnd(afterToken: markerLast) ?? end
                    decisions.abstain(range.lowerBound..<abstainEnd, rule: "numeric.en.percent.abstain",
                                      reason: "not one cardinal, juxtaposed numbers, duplicate marker or a name")
                }
                index = markerLast + 1
                continue
            }

            // Compound ordinal: twenty first -> 21st.
            if words.count == 1, let ten = EnglishNumberGrammar.tens[words[0]], isAdjacentWord(last, cursor),
               let unit = EnglishNumberGrammar.ordinalUnits[all[cursor].lower] {
                let value = ten + unit
                let range = span(first, cursor)
                if nameEvidence(first, cursor) {
                    decisions.abstain(range, rule: "numeric.en.ordinal.abstain", reason: "name evidence")
                } else {
                    decisions.propose(range, "\(value)\(EnglishNumberGrammar.ordinalSuffix(value))",
                                      rule: "numeric.en.ordinal", evidence: "tens + ordinal")
                }
                index = cursor + 1
                continue
            }

            // Fractions and plural decades stay in words and are never split (two thirds, the twenty twenties).
            if isAdjacentWord(last, cursor),
               fractionWords.contains(all[cursor].lower) || pluralNumberWords.contains(all[cursor].lower) {
                decisions.abstain(span(first, cursor), rule: "numeric.en.fraction.abstain",
                                  reason: "fractions stay in words")
                index = cursor + 1
                continue
            }
            if isAdjacentWord(last, cursor), all[cursor].lower == "and", isAdjacentWord(cursor, cursor + 1),
               all[cursor + 1].lower == "a", isAdjacentWord(cursor + 1, cursor + 2),
               ["half", "quarter"].contains(all[cursor + 2].lower) {
                decisions.abstain(span(first, cursor + 2), rule: "numeric.en.fraction.abstain",
                                  reason: "fractions stay in words")
                index = cursor + 3
                continue
            }

            var phrase = Phrase(first: first, last: last, isLoneOneOrZero: isLone)
            if nameEvidence(first, last) {
                phrase.abstention = NumericAbstention(range: integerRange, ruleID: "numeric.en.cardinal.abstain",
                                                      reason: "name evidence (Title-Case neighbour)")
            } else if let value = EnglishNumberGrammar.cardinal(words) {
                if let scale = words.last, EnglishNumberGrammar.wordScales.contains(scale), words.count > 1,
                   let prefix = EnglishNumberGrammar.cardinal(Array(words.dropLast())), prefix < 1000,
                   !words.dropLast().contains(where: { EnglishNumberGrammar.scales[$0] != nil }) {
                    // Million and billion keep the scale word: three million -> 3 million.
                    phrase.proposal = NumericProposal(range: span(first, last - 1), replacement: String(prefix),
                                                      ruleID: "numeric.en.cardinal", evidence: "cardinal phrase")
                } else {
                    phrase.proposal = NumericProposal(range: integerRange, replacement: String(value),
                                                      ruleID: "numeric.en.cardinal", evidence: "cardinal phrase")
                }
            } else if let year = EnglishNumberGrammar.year(words) {
                phrase.proposal = NumericProposal(range: integerRange, replacement: String(year),
                                                  ruleID: "numeric.en.year", evidence: "two two-digit groups")
            } else if let digits = EnglishNumberGrammar.digitSequence(words) {
                phrase.proposal = NumericProposal(range: integerRange, replacement: digits,
                                                  ruleID: "numeric.en.digits", evidence: "three or more spoken digits")
            } else {
                phrase.abstention = NumericAbstention(range: integerRange, ruleID: "numeric.en.cardinal.abstain",
                                                      reason: "juxtaposed numbers stay in words")
            }
            phrases.append(phrase)
            index = cursor
        }

        // Lone one/zero need numeric evidence (label, currency/clock, or a range/arithmetic chain).
        for phraseIndex in phrases.indices where phrases[phraseIndex].isLoneOneOrZero && phrases[phraseIndex].proposal != nil {
            if !hasNumericEvidence(phraseIndex, phrases, all, text) {
                let phrase = phrases[phraseIndex]
                phrases[phraseIndex].proposal = nil
                phrases[phraseIndex].abstention = NumericAbstention(
                    range: span(phrase.first, phrase.last), ruleID: "numeric.en.one-zero.abstain",
                    reason: "lone one/zero without numeric evidence")
            }
        }
        for phrase in phrases {
            if let proposal = phrase.proposal {
                decisions.propose(proposal.range, proposal.replacement, rule: proposal.ruleID, evidence: proposal.evidence)
            }
            if let abstention = phrase.abstention {
                decisions.abstain(abstention.range, rule: abstention.ruleID, reason: abstention.reason)
            }
        }
        return decisions
    }

    private static func hasNumericEvidence(_ index: Int, _ phrases: [Phrase], _ all: [Token], _ text: NumericText) -> Bool {
        let phrase = phrases[index]
        if phrase.first > 0, all[phrase.first - 1].isWord, labelNouns.contains(all[phrase.first - 1].lower),
           adjacent(all[phrase.first - 1], all[phrase.first], text) { return true }
        if phrase.last + 1 < all.count, adjacent(all[phrase.last], all[phrase.last + 1], text) {
            let next = all[phrase.last + 1]
            if currencyAndClockWords.contains(next.lower) { return true }
            let after = text.slice(next.range.lowerBound..<min(text.count, next.range.lowerBound + 7)).lowercased()
            if after.hasPrefix("p.m.") || after.hasPrefix("a.m.") || after.hasPrefix("o'clock") || after.hasPrefix("o’clock") {
                return true
            }
        }
        // Range/arithmetic chains: one plus one equals two, from one to ten.
        var visited: Set<Int> = [index]
        var queue = [index]
        while let current = queue.popLast() {
            let item = phrases[current]
            if !item.isLoneOneOrZero && item.proposal != nil { return true }
            for (opIndex, neighbourToken) in [(item.last + 1, item.last + 2), (item.first - 1, item.first - 2)] {
                guard opIndex >= 0, opIndex < all.count, neighbourToken >= 0, neighbourToken < all.count,
                      all[opIndex].isWord, operatorWords.contains(all[opIndex].lower) else { continue }
                let (lhs, rhs) = opIndex > item.last ? (item.last, opIndex) : (opIndex, item.first)
                guard adjacent(all[lhs], all[rhs], text) else { continue }
                if all[neighbourToken].kind == .digits { return true }
                if let neighbour = phrases.firstIndex(where: { $0.first == neighbourToken || $0.last == neighbourToken }),
                   !visited.contains(neighbour) {
                    visited.insert(neighbour)
                    queue.append(neighbour)
                }
            }
        }
        return false
    }

    /// Converts `integer point fraction [million] [percent]`; returns the next token index.
    private static func decimalPhrase(
        integerWords: [String]?,
        integerDigits: String?,
        first: Int,
        point: Int,
        fractionEnd: Int,
        _ all: [Token],
        _ context: NumericContext,
        _ decisions: inout NumericDecisions,
        nameEvidence: Bool
    ) -> Int {
        let text = context.text
        let lastFraction = fractionEnd - 1
        let rule = "numeric.en.decimal"
        var end = all[lastFraction].range.upperBound
        func abstain(_ reason: String, until: Int? = nil) -> Int {
            decisions.abstain(all[first].range.lowerBound..<(until ?? end), rule: rule + ".abstain", reason: reason)
            return fractionEnd
        }
        // Another point (one point two point three) or an unsupported magnitude (point six hundred).
        if fractionEnd < all.count, all[fractionEnd].isWord, adjacent(all[lastFraction], all[fractionEnd], text) {
            let next = all[fractionEnd].lower
            if next == "point" || next == "hundred" || next == "thousand" {
                var stop = fractionEnd + 1
                while stop < all.count, adjacent(all[stop - 1], all[stop], text), isFractionToken(all[stop]) { stop += 1 }
                _ = abstain("repeated point or unsupported magnitude", until: all[stop - 1].range.upperBound)
                return stop
            }
        }
        // Digits glued to Latin letters: only a unit may follow (5 point 6kg), never an identifier.
        if all[lastFraction].kind == .digits, let next = text.at(end), CharClass.isASCIILetter(next) || next == "_" {
            var tokenEnd = end
            while tokenEnd < text.count, CharClass.isASCIILetter(text[tokenEnd]) { tokenEnd += 1 }
            let unit = text.slice(end..<tokenEnd)
            let follow = text.at(tokenEnd)
            let isUnit = next != "_" && (UnitLexicon.latinUnits.contains(unit) || UnitLexicon.latinUnits.contains(unit.lowercased()))
                && !(follow.map { CharClass.isASCIIDigit($0) || $0 == "_" } ?? false)
            if !isUnit {
                var stop = end
                while stop < text.count, CharClass.isASCIIWordChar(text[stop]) { stop += 1 }
                return abstain("glued to an identifier", until: stop)
            }
        }
        if nameEvidence { return abstain("name evidence") }
        let integer: String?
        if let integerDigits {
            integer = integerDigits
        } else if let integerWords {
            integer = EnglishNumberGrammar.cardinal(integerWords).map(String.init)
        } else {
            integer = nil
        }
        let fractionWords = all[(point + 1)..<fractionEnd].map(\.lower)
        guard let integer, let digits = EnglishNumberGrammar.fractionDigits(fractionWords) else {
            return abstain("not a complete integer and digit fraction")
        }
        var value = integer + "." + digits
        var next = fractionEnd
        var replacementEnd = end
        // A following scale word stays (3.5 million); a percent marker joins (3.5%).
        var scaleLast = lastFraction
        if next < all.count, all[next].isWord, adjacent(all[lastFraction], all[next], text),
           EnglishNumberGrammar.wordScales.contains(all[next].lower) {
            scaleLast = next
            next += 1
        }
        if scaleLast == lastFraction, next < all.count, all[next].isWord, adjacent(all[lastFraction], all[next], text),
           let markerEnd = percentMarkerEnd(at: all[next].range.lowerBound, context) {
            let afterMarker = text.skipSpaces(from: markerEnd)
            let duplicate = text.at(afterMarker).map { $0 == "%" || $0 == "％" } == true
                || (afterMarker > markerEnd && percentMarkerEnd(at: afterMarker, context) != nil)
            while next < all.count, all[next].range.lowerBound < markerEnd { next += 1 }
            if duplicate {
                return abstain("duplicate percent marker", until: afterMarker + 1)
            }
            value += "%"
            end = markerEnd
            replacementEnd = markerEnd
        }
        let range = all[first].range.lowerBound..<replacementEnd
        guard !context.isProtected(range) else { return next }
        decisions.propose(range, value, rule: value.hasSuffix("%") ? "numeric.en.percent" : rule,
                          evidence: "integer + point + digits")
        return next
    }

    /// ASCII digits followed by "point" digits or a percent marker; returns the next token index.
    private static func digitPhrase(at index: Int, _ all: [Token], _ context: NumericContext,
                                    _ decisions: inout NumericDecisions) -> Int {
        let text = context.text
        let token = all[index]
        let isDecimalLiteral = token.original.contains(".")
        let malformed = token.original.filter { $0 == "." }.count > 1
        // Percent marker directly after the number.
        let markerStart = text.skipSpaces(from: token.range.upperBound)
        if markerStart > token.range.upperBound, let markerEnd = percentMarkerEnd(at: markerStart, context) {
            var start = token.range.lowerBound
            var attached = !token.standalone || malformed
            // Never salvage the numeric tail of an attached identifier (v3.5, rate_3.5, 1,000, 1/2).
            while start > 0, CharClass.isASCIIWordChar(text[start - 1]) || ".,/".contains(text[start - 1]) {
                start -= 1
                attached = true
            }
            let afterMarker = text.skipSpaces(from: markerEnd)
            let duplicate = text.at(afterMarker).map { $0 == "%" || $0 == "％" } == true
                || (afterMarker > markerEnd && percentMarkerEnd(at: afterMarker, context) != nil)
            var abstainEnd = markerEnd
            if duplicate {
                abstainEnd = text.at(afterMarker).map { $0 == "%" || $0 == "％" } == true
                    ? afterMarker + 1 : (percentMarkerEnd(at: afterMarker, context) ?? markerEnd)
            }
            // A Chinese marker before the number already claims it (百分之3.5 percent).
            let beforeNumber = text.skipSpacesBackward(from: start)
            if text.hasSuffix("百分之", endingAt: beforeNumber) { attached = true; start = beforeNumber - 3 }
            // Juxtaposed numbers before a percent (3.5 60 percent): which one is the percentage is unknown.
            if index > 0, adjacent(all[index - 1], token, text), isNumericToken(all[index - 1]) {
                attached = true
                start = all[index - 1].range.lowerBound
            }
            var next = index + 1
            while next < all.count, all[next].range.lowerBound < abstainEnd { next += 1 }
            let range = start..<abstainEnd
            guard !context.isProtected(range) else { return next }
            if attached || duplicate {
                decisions.abstain(range, rule: "numeric.en.percent.abstain",
                                  reason: "attached identifier, malformed number or duplicate marker")
            } else {
                decisions.propose(start..<markerEnd, token.original + "%", rule: "numeric.en.percent",
                                  evidence: "number + percent")
            }
            return next
        }
        // N point digits (a separator such as / or , before the number is not an identifier).
        let leftGlued = text.at(token.range.lowerBound - 1).map { CharClass.isASCIIWordChar($0) || $0 == "." } ?? false
        guard !leftGlued, !isDecimalLiteral, index + 1 < all.count, all[index + 1].isWord,
              all[index + 1].lower == "point", adjacent(token, all[index + 1], text) else { return index + 1 }
        var fractionEnd = index + 2
        while fractionEnd < all.count, all[fractionEnd].standalone || all[fractionEnd].kind == .digits,
              adjacent(all[fractionEnd - 1], all[fractionEnd], text), isFractionToken(all[fractionEnd]),
              !context.isProtected(all[fractionEnd].range) { fractionEnd += 1 }
        guard fractionEnd > index + 2 else { return index + 2 }
        return decimalPhrase(integerWords: nil, integerDigits: token.original, first: index, point: index + 1,
                             fractionEnd: fractionEnd, all, context, &decisions, nameEvidence: false)
    }
}
