import Foundation

struct DesignatorJoinResult {
    let text: String
    let events: [PostProcessingEvent]
}

/// One standalone capital letter spoken with a number is an identifier: S1, F1, A1, V4, M4, H0.
/// Both the number conversion (`DesignatorRecognizer`) and the join (`DesignatorJoiner`) ask this
/// rule, so one identifier can no longer come out as "S one", "S 2" and "S9" in the same list
/// (2026-10-25). The one exception is a number that counts what follows it: plan B 3 times,
/// vitamin C 500 mg, 方案 B 3 次.
enum DesignatorRule {
    static let countNouns: Set<String> = [
        "time", "times", "year", "years", "month", "months", "week", "weeks", "day", "days", "hour", "hours",
        "minute", "minutes", "second", "seconds", "point", "points", "piece", "pieces", "person", "people",
        "percent", "mg", "g", "kg", "ml", "l", "km", "m", "cm", "mm", "lb", "lbs", "oz", "am", "pm"
    ]
    /// Words ending in "s" that are not plural nouns.
    static let nonPluralS: Set<String> = [
        "this", "does", "plus", "minus", "thus", "always", "across", "less", "unless", "versus", "whereas",
        "perhaps", "sometimes", "series", "class", "pass", "process", "access", "address", "status", "focus",
        "bonus", "basis", "analysis", "thesis", "hypothesis", "yes", "its", "his", "has", "was", "is", "as", "us"
    ]

    /// The capital letter at `offset` stands alone: not part of a word and not the tail of a spaced
    /// letter run such as "G P T" (spelling joins that run into one word).
    static func isDesignatorLetter(at offset: Int, in text: NumericText) -> Bool {
        guard let c = text.at(offset), CharClass.isASCIIUppercase(c), c != "I" else { return false }
        if let right = text.at(offset + 1), CharClass.isASCIIWordChar(right) { return false }
        guard let left = text.at(offset - 1) else { return true }
        if CharClass.isASCIIWordChar(left) || "'’.-/".contains(left) { return false }
        // Only a capital starts a spelled run; "a B 2 B company" has the article before the letter.
        if left == " ", let before = text.at(offset - 2), CharClass.isASCIIUppercase(before),
           !(text.at(offset - 3).map(CharClass.isASCIILetter) ?? false) { return false }
        return true
    }

    /// Two to five capitals standing alone (COMP, MATH, STAT): the prefix of a course or product code.
    static func isCodePrefix(_ range: Range<Int>, in text: NumericText) -> Bool {
        guard (2...5).contains(range.count),
              range.allSatisfy({ CharClass.isASCIIUppercase(text[$0]) }) else { return false }
        if let left = text.at(range.lowerBound - 1), CharClass.isASCIIWordChar(left) || "'’.-/".contains(left) {
            return false
        }
        return !(text.at(range.upperBound).map(CharClass.isASCIIWordChar) ?? false)
    }

    /// The number ending at `numberEnd` counts the noun or measure word that follows it.
    static func countsFollowingNoun(letter: Int, numberEnd: Int, value: Int?, in text: NumericText) -> Bool {
        var offset = numberEnd
        while let c = text.at(offset), CharClass.isHorizontalSpace(c) { offset += 1 }
        guard let next = text.at(offset) else { return false }
        if CharClass.isHan(next) {
            guard startsMeasureWord(at: offset, text) else { return false }
            // 第 F 1 题: an ordinal label, not a count.
            var before = letter - 1
            while let c = text.at(before), CharClass.isHorizontalSpace(c) { before -= 1 }
            return text.at(before) != "第"
        }
        guard CharClass.isASCIILetter(next) else { return false }
        var end = offset
        while let c = text.at(end), CharClass.isASCIILetter(c) { end += 1 }
        let word = text.slice(offset..<end)
        let lower = word.lowercased()
        // "A five star hotel": before an English word, A is the article.
        if text.at(letter) == "A", word == lower { return true }
        if countNouns.contains(lower) || EnglishNumericRecognizer.currencyAndClockWords.contains(lower) { return true }
        // A plural noun after a number above one is what the number counts: C 2 students.
        return value != 1 && word == lower && lower.count >= 4 && lower.hasSuffix("s") && !nonPluralS.contains(lower)
    }

    static func startsMeasureWord(at offset: Int, _ text: NumericText) -> Bool {
        for length in stride(from: 3, through: 1, by: -1) where offset + length <= text.count {
            if ChineseLexicon.measureWords.contains(text.slice(offset..<(offset + length))) { return true }
        }
        return false
    }
}

/// Converts the number of an identifier in the numeric stage, including a lone one/zero
/// (F one -> F 1) and Chinese digits attached to the letter (V四、 -> V4、, C零三九 -> C039,
/// COMP零零零八 -> COMP0008). Its spans take precedence over every other numeric decision;
/// `DesignatorJoiner` then removes the space.
enum DesignatorRecognizer {
    static func recognize(_ context: NumericContext) -> NumericDecisions {
        var decisions = NumericDecisions()
        let text = context.text
        let all = EnglishNumericRecognizer.tokens(context)
        for (index, token) in all.enumerated() {
            guard token.isWord, token.standalone else { continue }
            let letter = token.range.lowerBound
            let isLetter = token.range.count == 1 && DesignatorRule.isDesignatorLetter(at: letter, in: text)
            let isCode = DesignatorRule.isCodePrefix(token.range, in: text)
            guard isLetter || isCode else { continue }
            if let run = chineseDigitRun(from: token.range.upperBound, in: text) {
                // 0.6B sometimes writes English-spoken digits as Chinese numerals (2026-10-25).
                let digits = String(text.slice(run).map { Character(String(CharClass.chineseDigits[$0]!)) })
                // A multi-letter prefix needs a code-shaped number: GPT四 stays, COMP零零零八 converts.
                if isCode, !(digits.count >= 2 && digits.hasPrefix("0")) { continue }
                guard !(text.at(run.upperBound).map(CharClass.isChineseNumeral) ?? false),
                      !context.isProtected(letter..<run.upperBound), !context.crossesWord(run),
                      !DesignatorRule.countsFollowingNoun(letter: letter, numberEnd: run.upperBound,
                                                          value: Int(digits), in: text)
                else { continue }
                // C零七二C零三九: keep the next code apart once both are digits.
                let separator = text.at(run.upperBound).map(CharClass.isASCIILetter) == true ? " " : ""
                decisions.propose(run, digits + separator, rule: "numeric.designator",
                                  evidence: "capital letter + Chinese digit identifier", specificity: 1)
                continue
            }
            guard isLetter else { continue }
            var words: [String] = []
            var cursor = index + 1
            while cursor < all.count, all[cursor].isWord, all[cursor].standalone,
                  EnglishNumericRecognizer.adjacent(all[cursor - 1], all[cursor], text) {
                if let parts = EnglishNumberGrammar.splitCompound(all[cursor].lower) {
                    words += parts
                } else if EnglishNumberGrammar.isCardinalWord(all[cursor].lower) {
                    words.append(all[cursor].lower)
                } else {
                    break
                }
                cursor += 1
            }
            guard cursor > index + 1, let value = EnglishNumberGrammar.cardinal(words), value < 1_000 else { continue }
            let range = all[index + 1].range.lowerBound..<all[cursor - 1].range.upperBound
            // "S one point five" is a decimal: the English recogniser converts it, the joiner joins it.
            if cursor < all.count, all[cursor].lower == "point" { continue }
            guard !context.isProtected(letter..<range.upperBound),
                  !DesignatorRule.countsFollowingNoun(letter: letter, numberEnd: range.upperBound, value: value, in: text)
            else { continue }
            decisions.propose(range, String(value), rule: "numeric.designator",
                              evidence: "capital letter + number identifier", specificity: 1)
        }
        return decisions
    }

    /// Chinese digits read one by one (零〇幺一…九, no 两 or 十) directly after `offset`.
    static func chineseDigitRun(from offset: Int, in text: NumericText) -> Range<Int>? {
        var end = offset
        while let c = text.at(end), CharClass.isChineseRunDigit(c) { end += 1 }
        return end > offset ? offset..<end : nil
    }
}

/// Joins a designator letter and its number (S 5 -> S5, B 2 B -> B2B). It runs after number
/// conversion and spelled-letter joining, so "V five" and "G P T five" are already settled.
enum DesignatorJoiner {
    static let partyLetters: Set<Character> = ["B", "C", "P", "D", "G", "M", "E"]

    static func join(_ text: String, knownTerms: [String]) -> DesignatorJoinResult {
        let numericText = NumericText(text)
        guard numericText.count >= 3 else { return DesignatorJoinResult(text: text, events: []) }
        let protected = SharedProtection.ranges(in: text, knownTerms: knownTerms).map { numericText.range(of: $0) }
        let hotwords = Set(knownTerms.map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        var spaces: [Int] = []
        var events: [PostProcessingEvent] = []
        for letter in 0..<(numericText.count - 2) {
            let c = numericText[letter]
            guard DesignatorRule.isDesignatorLetter(at: letter, in: numericText), numericText.at(letter + 1) == " ",
                  let first = numericText.at(letter + 2), CharClass.isASCIIDigit(first) else { continue }
            var end = letter + 2
            while end < numericText.count, CharClass.isASCIIDigit(numericText[end]) { end += 1 }
            let integerDigits = end - (letter + 2)
            guard integerDigits <= 3 || first == "0" && integerDigits <= 6 else { continue }
            let value = Int(numericText.slice((letter + 2)..<end))
            if numericText.at(end) == ".", let next = numericText.at(end + 1), CharClass.isASCIIDigit(next) {
                end += 1
                while end < numericText.count, CharClass.isASCIIDigit(numericText[end]) { end += 1 }
            }
            var range = letter..<end
            if protected.contains(where: { $0.overlaps(range) }) { continue }
            if numericText.at(end).map(CharClass.isASCIIWordChar) ?? false { continue }
            let joined = String(c) + numericText.slice((letter + 2)..<end)
            if !hotwords.contains(joined.lowercased()),
               DesignatorRule.countsFollowingNoun(letter: letter, numberEnd: end, value: value, in: numericText) {
                continue
            }
            spaces.append(letter + 1)
            var after = joined
            // B 2 B / B 2 C / P 2 P: "2" read as "to" between two parties. Other letters stay apart
            // (Exercise 3 Q 2 H -> Q2 H: part H of question 2).
            if value == 2, partyLetters.contains(c), numericText.at(end) == " ", let tail = numericText.at(end + 1),
               partyLetters.contains(tail), !(numericText.at(end + 2).map(CharClass.isASCIIWordChar) ?? false),
               !startsNumber(at: end + 2, numericText), !protected.contains(where: { $0.contains(end + 1) }) {
                spaces.append(end)
                after += String(tail)
                range = letter..<(end + 2)
            }
            events.append(PostProcessingEvent(
                ruleID: "numeric.designator-join",
                rangeDescription: "chars:\(range.lowerBound)..<\(range.upperBound)",
                before: numericText.slice(range),
                after: after,
                reason: "capital letter + number identifier",
                confidence: .high
            ))
        }
        // COMP 0008 -> COMP0008: a code number starts with 0, so it is never a quantity (GPT 5, ISO 9001 stay).
        for space in 2..<numericText.count where numericText[space] == " " {
            var start = space
            while start > 0, CharClass.isASCIIUppercase(numericText[start - 1]) { start -= 1 }
            guard DesignatorRule.isCodePrefix(start..<space, in: numericText),
                  numericText.at(space + 1) == "0" else { continue }
            var end = space + 1
            while end < numericText.count, CharClass.isASCIIDigit(numericText[end]) { end += 1 }
            let range = start..<end
            guard (2...6).contains(end - space - 1), !(numericText.at(end).map(CharClass.isASCIIWordChar) ?? false),
                  !(numericText.at(end) == "." && numericText.at(end + 1).map(CharClass.isASCIIDigit) == true),
                  !protected.contains(where: { $0.overlaps(range) }) else { continue }
            spaces.append(space)
            events.append(PostProcessingEvent(
                ruleID: "numeric.code-join",
                rangeDescription: "chars:\(range.lowerBound)..<\(range.upperBound)",
                before: numericText.slice(range),
                after: numericText.slice(start..<space) + numericText.slice((space + 1)..<end),
                reason: "capital code prefix + number starting with 0",
                confidence: .high
            ))
        }
        guard !spaces.isEmpty else { return DesignatorJoinResult(text: text, events: []) }
        var output = text
        for space in spaces.sorted().reversed() {
            output.remove(at: numericText.index(space))
        }
        return DesignatorJoinResult(text: output, events: events)
    }

    /// A number (digits or a number word) follows after horizontal space.
    private static func startsNumber(at offset: Int, _ text: NumericText) -> Bool {
        var index = offset
        while let c = text.at(index), CharClass.isHorizontalSpace(c) { index += 1 }
        guard let c = text.at(index) else { return false }
        if CharClass.isASCIIDigit(c) { return true }
        var end = index
        while let next = text.at(end), CharClass.isASCIILetter(next) { end += 1 }
        return end > index && EnglishNumberGrammar.isCardinalWord(text.slice(index..<end).lowercased())
    }
}
