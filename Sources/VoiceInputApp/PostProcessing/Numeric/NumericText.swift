import Foundation

/// Character-indexed view of one numeric-stage input. All numeric ranges are character offsets.
struct NumericText {
    let string: String
    let chars: [Character]
    private let indices: [String.Index]

    init(_ string: String) {
        self.string = string
        var chars: [Character] = []
        var indices: [String.Index] = []
        chars.reserveCapacity(string.count)
        var index = string.startIndex
        while index < string.endIndex {
            indices.append(index)
            chars.append(string[index])
            index = string.index(after: index)
        }
        indices.append(string.endIndex)
        self.chars = chars
        self.indices = indices
    }

    var count: Int { chars.count }

    subscript(_ offset: Int) -> Character { chars[offset] }

    /// Character at `offset`, or nil outside the text.
    func at(_ offset: Int) -> Character? {
        offset >= 0 && offset < chars.count ? chars[offset] : nil
    }

    func slice(_ range: Range<Int>) -> String {
        String(string[indices[range.lowerBound]..<indices[range.upperBound]])
    }

    func index(_ offset: Int) -> String.Index { indices[offset] }

    func offset(of index: String.Index) -> Int {
        var low = 0
        var high = indices.count - 1
        while low < high {
            let mid = (low + high) / 2
            if indices[mid] < index { low = mid + 1 } else { high = mid }
        }
        return low
    }

    func range(of stringRange: Range<String.Index>) -> Range<Int> {
        offset(of: stringRange.lowerBound)..<offset(of: stringRange.upperBound)
    }

    /// Offset after skipping horizontal whitespace forward from `offset`.
    func skipSpaces(from offset: Int) -> Int {
        var cursor = offset
        while cursor < chars.count, CharClass.isHorizontalSpace(chars[cursor]) { cursor += 1 }
        return cursor
    }

    /// Offset after skipping horizontal whitespace backward from `offset` (exclusive end).
    func skipSpacesBackward(from offset: Int) -> Int {
        var cursor = offset
        while cursor > 0, CharClass.isHorizontalSpace(chars[cursor - 1]) { cursor -= 1 }
        return cursor
    }

    func hasPrefix(_ prefix: String, at offset: Int) -> Bool {
        let prefixChars = Array(prefix)
        guard offset >= 0, offset + prefixChars.count <= chars.count else { return false }
        for (index, character) in prefixChars.enumerated() where chars[offset + index] != character {
            return false
        }
        return true
    }

    func hasSuffix(_ suffix: String, endingAt offset: Int) -> Bool {
        let count = suffix.count
        return offset - count >= 0 && hasPrefix(suffix, at: offset - count)
    }

    /// The text of the current clause before `offset` (back to the previous clause punctuation;
    /// a colon introduces a value and does not end the clause).
    func clausePrefix(before offset: Int) -> String {
        var cursor = offset
        while cursor > 0, !CharClass.isClauseBreak(chars[cursor - 1]) || ":：".contains(chars[cursor - 1]) { cursor -= 1 }
        return slice(cursor..<offset)
    }
}

enum CharClass {
    static let chineseDigits: [Character: Int] = [
        "零": 0, "〇": 0, "一": 1, "幺": 1, "二": 2, "两": 2, "兩": 2,
        "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
    ]
    static let chinesePositions: [Character: Int] = [
        "十": 10, "百": 100, "千": 1_000, "万": 10_000, "萬": 10_000, "亿": 100_000_000, "億": 100_000_000
    ]

    static func isChineseNumeral(_ c: Character) -> Bool {
        chineseDigits[c] != nil || chinesePositions[c] != nil
    }

    /// Digits that can be read one by one (两 never occurs in a digit run).
    static func isChineseRunDigit(_ c: Character) -> Bool {
        guard let value = chineseDigits[c] else { return false }
        _ = value
        return c != "两" && c != "兩"
    }

    static func isHan(_ c: Character) -> Bool {
        guard let scalar = c.unicodeScalars.first, c.unicodeScalars.count == 1 else { return false }
        switch scalar.value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F: return true
        default: return false
        }
    }

    static func isASCIILetter(_ c: Character) -> Bool {
        guard let ascii = c.asciiValue else { return false }
        return (65...90).contains(ascii) || (97...122).contains(ascii)
    }

    static func isASCIIUppercase(_ c: Character) -> Bool {
        guard let ascii = c.asciiValue else { return false }
        return (65...90).contains(ascii)
    }

    static func isASCIIDigit(_ c: Character) -> Bool {
        guard let ascii = c.asciiValue else { return false }
        return (48...57).contains(ascii)
    }

    static func isASCIIWordChar(_ c: Character) -> Bool {
        isASCIILetter(c) || isASCIIDigit(c) || c == "_"
    }

    static func isHorizontalSpace(_ c: Character) -> Bool {
        c == " " || c == "\t" || c == "\u{00A0}" || c == "\u{3000}"
    }

    static func isClauseBreak(_ c: Character) -> Bool {
        "，。！？；,.!?;\n：:".contains(c)
    }

    static let punctuation: Set<Character> = Set("，。！？；：、,.!?;:()（）[]{}【】《》〈〉「」『』“”‘’\"'`…—–-−~～·/／+×÷=<>")

    static func isPunctuation(_ c: Character) -> Bool {
        punctuation.contains(c)
    }

    /// End of a value: end of text, whitespace or punctuation.
    static func isCleanEnd(_ c: Character?) -> Bool {
        guard let c else { return true }
        return c.isWhitespace || isPunctuation(c)
    }
}
