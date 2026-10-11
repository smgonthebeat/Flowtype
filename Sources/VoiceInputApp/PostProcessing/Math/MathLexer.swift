import Foundation

/// Text -> math tokens (design.md 3): protected spans become barriers, Han text is matched
/// against the lexicon (longest first), glued words are split, existing notation is inert,
/// sentences are marked, and label words claim the letter or number after them.
enum MathLexer {
    private typealias T = MathLexiconTables

    private static let sentenceEnd: Set<Character> = [".", "!", "?", "。", "！", "？", "\n"]
    private static let punctuation: Set<Character> = [
        ".", ",", ";", ":", "!", "?", "，", "。", "；", "：", "！", "？", "、", "\n", "\"", "“", "”", "‘", "’"
    ]
    private static let compoundJoiners: Set<Character> = ["'", "’", "-"]

    /// Backtick code (an unclosed backtick protects to the end) and existing $...$ notation.
    /// URLs, e-mail, paths, model IDs, versions and code come from ProtectedSpanDetector.
    private static let extraProtection = try! NSRegularExpression(pattern: #"`+[^`]*`+|`[^\n]*$|\$[^$\n]+\$"#)

    static func lex(_ text: String, knownTerms: [String] = []) -> MathTokenStream {
        let characters = Array(text)
        var indices = Array(text.indices)
        indices.append(text.endIndex)
        var stream = MathTokenStream(characters: characters, indices: indices, tokens: [])
        let protected = protectedOffsets(in: text, indices: indices, knownTerms: knownTerms)
        var tokens: [MathToken] = []
        var position = 0
        var protectedIndex = 0
        let count = characters.count

        while position < count {
            while protectedIndex < protected.count, protected[protectedIndex].upperBound <= position {
                protectedIndex += 1
            }
            if protectedIndex < protected.count, protected[protectedIndex].lowerBound <= position {
                let span = protected[protectedIndex]
                tokens.append(MathToken(.barrier, String(characters[span]), start: span.lowerBound, end: span.upperBound))
                position = span.upperBound
                continue
            }
            let c = characters[position]
            if c == "\n" {
                tokens.append(MathToken(.punctuation, "\n", start: position, end: position + 1))
                position += 1
            } else if c.isWhitespace {
                position += 1
            } else if isASCIILetter(c) {
                position = lexWord(characters, from: position, into: &tokens)
            } else if isASCIIDigit(c) {
                position = lexNumber(characters, from: position, into: &tokens)
            } else if isHan(c) {
                var end = position
                while end < count, isHan(characters[end]) { end += 1 }
                lexHan(characters, from: position, to: end, into: &tokens)
                position = end
            } else if punctuation.contains(c) {
                tokens.append(MathToken(.punctuation, String(c), start: position, end: position + 1))
                position += 1
            } else {
                tokens.append(MathToken(.symbol, String(c), start: position, end: position + 1))
                position += 1
            }
        }

        markExistingNotation(&tokens)
        tokens = splitCompacts(tokens)
        markSentences(&tokens)
        claimLabels(&tokens)
        stream.tokens = tokens
        return stream
    }

    // MARK: Protection

    private static func protectedOffsets(
        in text: String,
        indices: [String.Index],
        knownTerms: [String]
    ) -> [Range<Int>] {
        var ranges = ProtectedSpanDetector.detect(in: text).map(\.range)
        ranges += SharedProtection.hotwordRanges(in: text, knownTerms: knownTerms)
        let nsRange = NSRange(text.startIndex..., in: text)
        ranges += extraProtection.matches(in: text, range: nsRange).compactMap { Range($0.range, in: text) }
        return SharedProtection.merged(ranges).compactMap { range in
            let lower = offset(of: range.lowerBound, in: indices)
            let upper = offset(of: range.upperBound, in: indices, roundUp: true)
            return lower < upper ? lower..<upper : nil
        }
    }

    /// Character offset of a String.Index (rounded to a character boundary).
    static func offset(of index: String.Index, in indices: [String.Index], roundUp: Bool = false) -> Int {
        var low = 0
        var high = indices.count - 1
        while low < high {
            let mid = (low + high + (roundUp ? 0 : 1)) / 2
            if roundUp {
                if indices[mid] < index { low = mid + 1 } else { high = mid }
            } else {
                if indices[mid] <= index { low = mid } else { high = mid - 1 }
            }
        }
        return low
    }

    // MARK: Words and numbers

    private static func lexWord(_ chars: [Character], from start: Int, into tokens: inout [MathToken]) -> Int {
        let count = chars.count
        var end = start
        while end < count, isASCIILetter(chars[end]) { end += 1 }
        var isCompound = false
        while end + 1 < count, compoundJoiners.contains(chars[end]), isASCIIAlphanumeric(chars[end + 1]) {
            isCompound = true
            end += 1
            while end < count, isASCIIAlphanumeric(chars[end]) { end += 1 }
        }
        let word = String(chars[start..<end])
        if isCompound {
            // p-value and co-variance are spoken math words; other hyphenated or possessive compounds are prose.
            let isMathWord = T.hyphenatedWords.contains(word.lowercased())
            tokens.append(MathToken(isMathWord ? .word : .prose, word, start: start, end: end))
            return end
        }
        guard end < count, isASCIIDigit(chars[end]) else {
            tokens.append(MathToken(.word, word, start: start, end: end))
            return end
        }
        var digitsEnd = end
        while digitsEnd < count, isASCIIDigit(chars[digitsEnd]) { digitsEnd += 1 }
        let digits = String(chars[end..<digitsEnd])
        let closed = !(digitsEnd < count && (isAlphanumeric(chars[digitsEnd]) || chars[digitsEnd] == "."))
        if end - start == 1, digitsEnd - end <= 2, closed {
            // x1: a letter with a glued index.
            tokens.append(MathToken(.word, word, start: start, end: end))
            tokens.append(MathToken(.number, digits, start: end, end: digitsEnd, value: digits))
        } else if let first = word.first, first.isUppercase, word.dropFirst().lowercased() == "sub",
                  digitsEnd - end <= 2, closed {
            // Xsub1
            tokens.append(MathToken(.word, String(first), start: start, end: start + 1))
            tokens.append(MathToken(.word, String(word.dropFirst()), start: start + 1, end: end))
            tokens.append(MathToken(.number, digits, start: end, end: digitsEnd, value: digits))
        } else {
            while digitsEnd < count, isASCIIAlphanumeric(chars[digitsEnd]) { digitsEnd += 1 }
            tokens.append(MathToken(.prose, String(chars[start..<digitsEnd]), start: start, end: digitsEnd))
        }
        return digitsEnd
    }

    private static func lexNumber(_ chars: [Character], from start: Int, into tokens: inout [MathToken]) -> Int {
        let count = chars.count
        var end = start
        while end < count, isASCIIDigit(chars[end]) { end += 1 }
        if end + 1 < count, chars[end] == ".", isASCIIDigit(chars[end + 1]) {
            end += 1
            while end < count, isASCIIDigit(chars[end]) { end += 1 }
        }
        if end < count, isASCIILetter(chars[end]), !(end + 1 < count && isASCIIAlphanumeric(chars[end + 1])) {
            // 2x: a coefficient glued to one letter, the mirror of x1. Longer runs (4K, 5G, 2nd, 10am)
            // stay prose below.
            let digits = String(chars[start..<end])
            tokens.append(MathToken(.number, digits, start: start, end: end, value: digits))
            tokens.append(MathToken(.word, String(chars[end]), start: end, end: end + 1))
            return end + 1
        }
        if end < count, isASCIILetter(chars[end]) {
            while end < count, isASCIIAlphanumeric(chars[end]) { end += 1 }
            tokens.append(MathToken(.prose, String(chars[start..<end]), start: start, end: end))
        } else {
            let digits = String(chars[start..<end])
            tokens.append(MathToken(.number, digits, start: start, end: end, value: digits))
        }
        return end
    }

    // MARK: Han

    private static func lexHan(_ chars: [Character], from start: Int, to end: Int, into tokens: inout [MathToken]) {
        var position = start
        while position < end {
            if let block = T.zhUnitBlock.first(where: { hasPrefix(chars, $0, at: position, limit: end) }) {
                var stop = position + block.count
                if block.hasSuffix("分之") {
                    // The numeral after 百分之 belongs to the numeric layer too.
                    while stop < end, T.zhNumeralCharacters.contains(chars[stop]) || chars[stop] == "点" { stop += 1 }
                }
                tokens.append(MathToken(.hanProse, String(chars[position..<stop]), start: position, end: stop))
                position = stop
                continue
            }
            var match: String?
            for length in stride(from: min(T.zhVocabularyMaxLength, end - position), through: 1, by: -1) {
                let candidate = String(chars[position..<(position + length)])
                if T.zhVocabulary.contains(candidate) {
                    match = candidate
                    break
                }
            }
            if T.zhNumeralCharacters.contains(chars[position]), (match?.count ?? 0) <= 1 {
                var stop = position
                while stop < end, T.zhNumeralCharacters.contains(chars[stop]) { stop += 1 }
                if var value = chineseNumber(Array(chars[position..<stop])) {
                    if stop + 1 < end, chars[stop] == "点", T.zhDigits[chars[stop + 1]] != nil {
                        var decimalEnd = stop + 1
                        var decimals = ""
                        while decimalEnd < end, let digit = T.zhDigits[chars[decimalEnd]] {
                            decimals += String(digit)
                            decimalEnd += 1
                        }
                        value += "." + decimals
                        stop = decimalEnd
                    }
                    tokens.append(MathToken(.zhNumber, String(chars[position..<stop]), start: position, end: stop, value: value))
                    position = stop
                    continue
                }
            }
            if let match {
                tokens.append(MathToken(.zh, match, start: position, end: position + match.count))
                position += match.count
            } else {
                tokens.append(MathToken(.hanProse, String(chars[position]), start: position, end: position + 1))
                position += 1
            }
        }
    }

    /// A digit run reads digit by digit (二三 -> 23); anything else is a positional cardinal.
    /// Both readings come from the numeric layer's grammar.
    static func chineseNumber(_ run: [Character]) -> String? {
        if run.count == 1, let digit = T.zhDigits[run[0]] { return String(digit) }
        if let digits = ChineseNumberGrammar.digitString(run) { return digits }
        if let cardinal = ChineseNumberGrammar.cardinal(run) { return String(cardinal.value) }
        return nil
    }

    private static func hasPrefix(_ chars: [Character], _ word: String, at position: Int, limit: Int) -> Bool {
        var k = position
        for c in word {
            guard k < limit, chars[k] == c else { return false }
            k += 1
        }
        return true
    }

    // MARK: Post-passes

    /// A word or number glued to a notation character is existing notation, never spoken math
    /// (f(x), x², 5%, β₁x). This is what makes the stage idempotent.
    private static func markExistingNotation(_ tokens: inout [MathToken]) {
        for k in tokens.indices where tokens[k].kind == .word || tokens[k].kind == .number {
            let gluedBefore = k > 0 && tokens[k - 1].kind == .symbol && tokens[k - 1].end == tokens[k].start
            let gluedAfter = k + 1 < tokens.count && tokens[k + 1].kind == .symbol && tokens[k + 1].start == tokens[k].end
            if gluedBefore || gluedAfter { tokens[k].kind = .prose }
        }
    }

    /// thetahat -> theta hat, subzero -> sub zero, Xbar -> X bar. Single letters are never split
    /// from English words (what, that, chat).
    private static func splitCompacts(_ tokens: [MathToken]) -> [MathToken] {
        var result: [MathToken] = []
        result.reserveCapacity(tokens.count)
        for token in tokens {
            guard token.kind == .word, token.text.count > 3 else {
                result.append(token)
                continue
            }
            let text = Array(token.text)
            let low = token.lower
            let rest = String(low.dropFirst())
            if text[0].isUppercase, !T.compactDenyList.contains(low),
               T.compactModifiers.contains(rest) || isCompactSubscript(rest) {
                result.append(MathToken(.word, String(text[0]), start: token.start, end: token.start + 1))
                if rest.hasPrefix("sub") {
                    result.append(MathToken(.word, String(text[1..<4]), start: token.start + 1, end: token.start + 4))
                    result.append(MathToken(.word, String(text[4...]), start: token.start + 4, end: token.end))
                } else {
                    result.append(MathToken(.word, String(text[1...]), start: token.start + 1, end: token.end))
                }
                continue
            }
            if low.hasPrefix("sub"), isCompactSubscriptTail(String(low.dropFirst(3))) {
                result.append(MathToken(.word, String(text[0..<3]), start: token.start, end: token.start + 3))
                result.append(MathToken(.word, String(text[3...]), start: token.start + 3, end: token.end))
                continue
            }
            if let name = (T.greekOrder + T.greekAliasOrder).first(where: {
                $0.count > 1 && low.hasPrefix($0) && T.compactModifiers.contains(String(low.dropFirst($0.count)))
            }) {
                let k = name.count
                result.append(MathToken(.word, String(text[0..<k]), start: token.start, end: token.start + k))
                result.append(MathToken(.word, String(text[k...]), start: token.start + k, end: token.end))
                continue
            }
            result.append(token)
        }
        return result
    }

    private static func isCompactSubscript(_ rest: String) -> Bool {
        rest.hasPrefix("sub") && isCompactSubscriptTail(String(rest.dropFirst(3)))
    }

    private static func isCompactSubscriptTail(_ tail: String) -> Bool {
        (T.units[tail] != nil) || T.compactSubscriptTails.contains(tail)
    }

    private static func markSentences(_ tokens: inout [MathToken]) {
        var sentence = 0
        var first = true
        for k in tokens.indices {
            tokens[k].sentence = sentence
            if tokens[k].kind == .punctuation {
                if let c = tokens[k].text.first, sentenceEnd.contains(c) {
                    sentence += 1
                    first = true
                }
            } else {
                tokens[k].isSentenceInitial = first
                first = false
            }
        }
    }

    /// part B, Q three, vitamin C: the letter or number after a label word is not a math atom.
    private static func claimLabels(_ tokens: inout [MathToken]) {
        for k in tokens.indices where k + 1 < tokens.count {
            guard tokens[k].kind == .word, T.labelWords.contains(tokens[k].lower) else { continue }
            let next = tokens[k + 1]
            guard [.word, .number, .zhNumber].contains(next.kind) else { continue }
            if next.kind != .word || next.text.count == 1 || T.units[next.lower] != nil || T.teens[next.lower] != nil
                || T.tens[next.lower] != nil {
                tokens[k + 1].isClaimedByLabel = true
            }
        }
    }

    // MARK: Character classes

    static func isASCIILetter(_ c: Character) -> Bool {
        guard let ascii = c.asciiValue else { return false }
        return (65...90).contains(ascii) || (97...122).contains(ascii)
    }

    static func isASCIIDigit(_ c: Character) -> Bool {
        guard let ascii = c.asciiValue else { return false }
        return (48...57).contains(ascii)
    }

    static func isASCIIAlphanumeric(_ c: Character) -> Bool { isASCIILetter(c) || isASCIIDigit(c) }

    /// Any letter or digit, not only ASCII (x1的 is not a glued index).
    private static func isAlphanumeric(_ c: Character) -> Bool { c.isLetter || c.isNumber }

    static func isHan(_ c: Character) -> Bool {
        guard c.unicodeScalars.count == 1, let scalar = c.unicodeScalars.first else { return false }
        return (0x4E00...0x9FFF).contains(scalar.value) || c == "〇"
    }
}
