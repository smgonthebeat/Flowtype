import Foundation

struct DesignatorJoinResult {
    let text: String
    let events: [PostProcessingEvent]
}

/// Joins a single-letter designator and its number (V 5。 -> V5。). It runs after number
/// conversion and spelled-letter joining, so "V five" and "G P T five" are already settled.
enum DesignatorJoiner {
    static func join(_ text: String, knownTerms: [String]) -> DesignatorJoinResult {
        let numericText = NumericText(text)
        guard numericText.count >= 3 else { return DesignatorJoinResult(text: text, events: []) }
        let protected = SharedProtection.ranges(in: text, knownTerms: knownTerms).map { numericText.range(of: $0) }
        let hotwords = Set(knownTerms.map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        var spaces: [Int] = []
        var events: [PostProcessingEvent] = []
        for letter in 0..<(numericText.count - 2) {
            let c = numericText[letter]
            guard CharClass.isASCIIUppercase(c), c != "A", c != "I", numericText.at(letter + 1) == " ",
                  let first = numericText.at(letter + 2), CharClass.isASCIIDigit(first) else { continue }
            // The letter stands alone: not part of a word or of a spaced letter run (X Y 5).
            if let left = numericText.at(letter - 1) {
                if CharClass.isASCIIWordChar(left) || "'’.-/".contains(left) { continue }
                if left == " ", let before = numericText.at(letter - 2), CharClass.isASCIILetter(before),
                   !(numericText.at(letter - 3).map(CharClass.isASCIILetter) ?? false) { continue }
            }
            var end = letter + 2
            while end < numericText.count, CharClass.isASCIIDigit(numericText[end]) { end += 1 }
            let integerDigits = end - (letter + 2)
            guard integerDigits <= 3 else { continue }
            if numericText.at(end) == ".", let next = numericText.at(end + 1), CharClass.isASCIIDigit(next) {
                end += 1
                while end < numericText.count, CharClass.isASCIIDigit(numericText[end]) { end += 1 }
            }
            let range = letter..<end
            if protected.contains(where: { $0.overlaps(range) }) { continue }
            let joined = String(c) + numericText.slice((letter + 2)..<end)
            let next = numericText.at(end)
            let rightOK: Bool
            if hotwords.contains(joined.lowercased()) {
                rightOK = !(next.map(CharClass.isASCIIWordChar) ?? false)
            } else if let next {
                if CharClass.isASCIIWordChar(next) || next.isWhitespace {
                    rightOK = false
                } else if CharClass.isHan(next) {
                    rightOK = !startsMeasureWord(at: end, numericText)
                } else {
                    rightOK = CharClass.isPunctuation(next)
                }
            } else {
                rightOK = true
            }
            guard rightOK else { continue }
            spaces.append(letter + 1)
            events.append(PostProcessingEvent(
                ruleID: "numeric.designator-join",
                rangeDescription: "chars:\(range.lowerBound)..<\(range.upperBound)",
                before: numericText.slice(range),
                after: joined,
                reason: "single-letter designator + number at a value boundary",
                confidence: .high
            ))
        }
        guard !spaces.isEmpty else { return DesignatorJoinResult(text: text, events: []) }
        var output = text
        for space in spaces.reversed() {
            output.remove(at: numericText.index(space))
        }
        return DesignatorJoinResult(text: output, events: events)
    }

    private static func startsMeasureWord(at offset: Int, _ text: NumericText) -> Bool {
        for length in stride(from: 3, through: 1, by: -1) where offset + length <= text.count {
            if ChineseLexicon.measureWords.contains(text.slice(offset..<(offset + length))) { return true }
        }
        return false
    }
}
