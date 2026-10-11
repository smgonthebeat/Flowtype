import Foundation

/// Entry point of the math layer (design.md 2): scan every start token, take the longest parse,
/// decide each span on its own evidence, and replace only the accepted spans.
enum MathStage {
    /// Private-use characters that wrap each rendered span so later stages leave it alone (design.md 8.1).
    static let openSentinel: Character = "\u{E010}"
    static let closeSentinel: Character = "\u{E011}"

    struct Span {
        /// Source range of the spoken formula in the stage input.
        let range: Range<String.Index>
        let source: String
        let rendered: String
        let decision: MathEvidence.Decision
    }

    struct Result {
        let text: String
        /// Every candidate span, accepted or not, in source order.
        let spans: [Span]
        let events: [PostProcessingEvent]

        var acceptedSpans: [Span] { spans.filter(\.decision.accepted) }
    }

    private typealias T = MathLexiconTables

    static func run(
        _ text: String,
        outputFormat: MathNotationOutputFormat,
        knownTerms: [String] = [],
        wrapInSentinels: Bool = false
    ) -> Result {
        let input = stripSentinels(text)
        let stream = MathLexer.lex(input, knownTerms: knownTerms)
        let tokens = stream.tokens
        let parser = MathSpanParser(stream)

        struct Candidate {
            let first: Int
            let last: Int
            let node: MathNode
            let isStandalone: Bool
            let hasCue: Bool
            let sentence: Int
            /// x sub zero to nine: the second index of the same letter and the source between the two.
            var rangeEnd: (node: MathNode, joiner: String)?
            var decision = MathEvidence.Decision(accepted: false, reason: "")
        }

        // Non-punctuation token counts per sentence, for the standalone test.
        var sentenceSizes: [Int: Int] = [:]
        for token in tokens where token.kind != .punctuation { sentenceSizes[token.sentence, default: 0] += 1 }

        var candidates: [Candidate] = []
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            guard [.word, .number, .zhNumber, .zh].contains(token.kind), !token.isClaimedByLabel, !isNoise(token) else {
                i += 1
                continue
            }
            guard let (node, spanEnd) = parser.parseSpan(at: i), spanEnd > i else {
                i += 1
                continue
            }
            var j = spanEnd
            // A formula followed by code punctuation is code (var x = 1).
            if j < tokens.count, tokens[j].kind == .symbol, "=:;{([".contains(tokens[j].text) {
                i += 1
                continue
            }
            // A juxtaposition that starts with an article or the pronoun I is prose.
            if node.isJuxtaposition, token.kind == .word, ["a", "A", "I"].contains(token.text) {
                i += 1
                continue
            }
            var rangeEnd: (node: MathNode, joiner: String)?
            if let r = indexRange(after: node, at: j, stream: stream, parser: parser) {
                rangeEnd = (r.node, stream.text(from: tokens[j - 1].end, to: tokens[j + 1].start))
                j = r.next
            }
            let inside = tokens[i..<j].filter { $0.kind != .punctuation && $0.sentence == token.sentence }.count
            let isStandalone = (sentenceSizes[token.sentence] ?? 0) == inside
            var hasCue = false
            if i > 0 {
                let previous = tokens[i - 1]
                if previous.kind == .word, T.greekCuePrevious.contains(previous.lower) {
                    hasCue = true
                } else if previous.kind == .hanProse {
                    let before = String(stream.characters[0..<token.start]).trimmingCharacters(in: .whitespacesAndNewlines)
                    hasCue = T.zhCuePrevious.contains { before.hasSuffix($0) }
                }
            }
            candidates.append(Candidate(first: i, last: j - 1, node: node, isStandalone: isStandalone, hasCue: hasCue,
                                        sentence: token.sentence, rangeEnd: rangeEnd))
            i = j
        }

        for k in candidates.indices {
            let c = candidates[k]
            candidates[k].decision = MathEvidence.decide(
                c.node, context: .init(isStandalone: c.isStandalone, hasSentenceBonus: false, hasCue: c.hasCue))
        }
        // Context bonus (second pass): a sentence with an accepted structured formula licenses its other spans.
        let strongSentences = Set(candidates.filter {
            $0.decision.accepted && MathEvidence.tally($0.node).isStructured
        }.map(\.sentence))
        for k in candidates.indices where !candidates[k].decision.accepted && strongSentences.contains(candidates[k].sentence) {
            let c = candidates[k]
            candidates[k].decision = MathEvidence.decide(
                c.node, context: .init(isStandalone: c.isStandalone, hasSentenceBonus: true, hasCue: c.hasCue))
        }

        var spans: [Span] = []
        var events: [PostProcessingEvent] = []
        for c in candidates {
            let start = tokens[c.first].start
            let end = tokens[c.last].end
            let source = stream.text(from: start, to: end)
            var rendered = c.decision.accepted ? render(c.node, outputFormat) : source
            if c.decision.accepted, let rangeEnd = c.rangeEnd {
                rendered += rangeEnd.joiner + render(rangeEnd.node, outputFormat)
            }
            spans.append(Span(range: stream.range(from: start, to: end), source: source, rendered: rendered,
                              decision: c.decision))
            events.append(PostProcessingEvent(
                ruleID: c.decision.accepted ? "math.span.accepted" : "math.span.rejected",
                rangeDescription: "chars:\(start)..<\(end)",
                before: source,
                after: rendered,
                reason: c.decision.reason,
                confidence: c.decision.accepted ? .high : .low
            ))
        }

        var edits = spans.filter(\.decision.accepted).map { (range: $0.range, text: $0.rendered) }
        if wrapInSentinels {
            // Existing notation is inert here, and later stages must leave it inert too (I2):
            // $...$ spans (D1) and factorial marks that cleanup would turn into full stops.
            edits += existingNotationRanges(stream).map { (range: $0, text: String(input[$0])) }
        }
        var output = input
        for edit in edits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            let replacement = wrapInSentinels ? String(openSentinel) + edit.text + String(closeSentinel) : edit.text
            output.replaceSubrange(edit.range, with: replacement)
        }
        return Result(text: output, spans: spans, events: events)
    }

    /// x sub zero to nine, x sub one through n: a subscripted letter followed by a range word and a
    /// bare index means the same letter with that index (x₀ to x₉, owner decision 2026-10-09).
    private static func indexRange(after node: MathNode, at j: Int, stream: MathTokenStream,
                                   parser: MathSpanParser) -> (node: MathNode, next: Int)? {
        let tokens = stream.tokens
        guard let atom = node.atom, atom.superscriptNode == nil, let sub = atom.subscriptNode, j + 1 < tokens.count,
              isPlainIndex(sub) else { return nil }
        let joiner = tokens[j]
        let isJoiner = (joiner.kind == .word && T.indexRangeWords.contains(joiner.lower))
            || (joiner.kind == .zh && T.zhIndexRangeWords.contains(joiner.text))
        guard isJoiner, !tokens[j + 1].isClaimedByLabel else { return nil }
        let index: MathNode
        var next = j + 2
        if let r = parser.number(j + 1), let text = r.node.numberText, !text.isEmpty, text.count <= 3,
           text.allSatisfy({ MathLexer.isASCIIDigit($0) }) {
            index = r.node
            next = r.next
        } else if tokens[j + 1].kind == .word, tokens[j + 1].text.count == 1,
                  T.subscriptLetters.contains(tokens[j + 1].lower), let letter = tokens[j + 1].text.first {
            index = .symbol(MathAtom(.latin(Character(letter.lowercased()))))
        } else {
            return nil
        }
        let end = MathAtom(atom.base, upper: atom.isUpper)
        end.isVariant = atom.isVariant
        end.accents = atom.accents
        end.subscriptNode = index
        return (.symbol(end), next)
    }

    /// A number or a single letter: not x sub i plus one.
    private static func isPlainIndex(_ node: MathNode) -> Bool {
        if let text = node.numberText { return text.allSatisfy { MathLexer.isASCIIDigit($0) } }
        guard let atom = node.atom else { return false }
        return atom.latinLetter != nil && !atom.hasDecoration
    }

    /// Notation already in the text that later stages could damage: `$...$` spans, and a "!" glued
    /// to an operand (n!, 5!, (n − k)!) when it is followed by more notation or its sentence is
    /// notation only. A sentence-final "x!" in prose stays an exclamation mark, as with math off, and
    /// so does "a!" or "I!" (article and pronoun letters, design.md 6.1).
    private static func existingNotationRanges(_ stream: MathTokenStream) -> [Range<String.Index>] {
        let tokens = stream.tokens
        let chars = stream.characters
        var proseSentences = Set<Int>()
        for token in tokens {
            let isProseWord = (token.kind == .word || token.kind == .prose) && token.text.count > 1
            if isProseWord || token.kind == .zh || token.kind == .hanProse || token.kind == .zhNumber {
                proseSentences.insert(token.sentence)
            }
        }
        var result: [Range<String.Index>] = []
        for (k, token) in tokens.enumerated() {
            if token.kind == .barrier, token.text.hasPrefix("$"), token.text.hasSuffix("$") {
                result.append(stream.range(from: token.start, to: token.end))
                continue
            }
            guard token.kind == .punctuation, token.text == "!", k > 0, tokens[k - 1].end == token.start else { continue }
            let before = chars[token.start - 1]
            let previous = tokens[k - 1]
            let isOperand = MathLexer.isASCIIDigit(before) || before == ")" || !before.isASCII
                || (MathLexer.isASCIILetter(before) && previous.text.count == 1
                    && !MathLexiconTables.labelProneLetters.contains(before))
            guard isOperand else { continue }
            let followedByNotation = token.end < chars.count && !chars[token.end].isWhitespace
                && !chars[token.end].isPunctuation
            if followedByNotation || !proseSentences.contains(token.sentence) {
                result.append(stream.range(from: token.start, to: token.end))
            }
        }
        return result
    }

    static func render(_ node: MathNode, _ format: MathNotationOutputFormat) -> String {
        format == .latex ? "$" + MathNodeRenderer.latex(node) + "$" : MathNodeRenderer.unicode(node)
    }

    static func stripSentinels(_ text: String) -> String {
        guard text.contains(openSentinel) || text.contains(closeSentinel) else { return text }
        return String(text.filter { $0 != openSentinel && $0 != closeSentinel })
    }

    private static func isNoise(_ token: MathToken) -> Bool {
        switch token.kind {
        case .word: return T.hesitations.contains(token.lower)
        case .zh: return T.zhWords[token.text] == .noise
        default: return false
        }
    }
}
