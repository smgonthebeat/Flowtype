import Foundation

/// The single number grammar. It returns every reading a phrase supports; the construct
/// that consumes the phrase decides which reading (if any) is licensed.
enum ChineseNumberGrammar {
    struct Reading: Equatable {
        /// Digit-by-digit reading ("二零二六" -> "2026"); nil when 两 or a position character occurs.
        let digits: String?
        /// Positional cardinal ("一千二百" -> 1200, single digits included).
        let cardinal: Int?
        /// Colloquial elision of the last position ("一千五" -> 1500, "两万三" -> 23000).
        let isElided: Bool
        /// Adjacent ascending digits ("三四", "三四十", "十七八"): an approximation, never a value.
        let isApproximate: Bool

        /// A complete, explicit cardinal value.
        var isCompleteCardinal: Bool { cardinal != nil && !isApproximate && !isElided }
    }

    static func read<S: Collection>(_ characters: S) -> Reading where S.Element == Character {
        let chars = Array(characters)
        let parsed = cardinal(chars)
        return Reading(
            digits: digitString(chars),
            cardinal: parsed?.value,
            isElided: parsed?.elided ?? false,
            isApproximate: isApproximate(chars)
        )
    }

    static func digitString(_ chars: [Character]) -> String? {
        guard !chars.isEmpty else { return nil }
        var result = ""
        for c in chars {
            guard CharClass.isChineseRunDigit(c), let value = CharClass.chineseDigits[c] else { return nil }
            result += String(value)
        }
        return result
    }

    /// A digit run is bounded by position characters (三四十, 十七八), never split by 零,
    /// so a long identifier ending in …零一二 is not an approximation.
    static func isApproximate(_ chars: [Character]) -> Bool {
        var run: [Int] = []
        func check() -> Bool { run.count == 2 && run[0] > 0 && run[1] == run[0] + 1 }
        for c in chars {
            if let value = CharClass.chineseDigits[c], c != "幺" {
                run.append(value)
            } else {
                if check() { return true }
                run = []
            }
        }
        return check()
    }

    /// Positional cardinal up to 亿. Rejects digit runs ("二三"), misplaced 零 and repeated positions.
    static func cardinal(_ chars: [Character]) -> (value: Int, elided: Bool)? {
        guard !chars.isEmpty else { return nil }
        if chars.count == 1, let value = CharClass.chineseDigits[chars[0]] { return (value, false) }
        if let yi = chars.lastIndex(where: { CharClass.chinesePositions[$0] == 100_000_000 }) {
            guard yi > 0, let high = cardinalBelowYi(Array(chars[..<yi])), high.value > 0 else { return nil }
            let rest = Array(chars[(yi + 1)...])
            guard let low = remainder(rest, scale: 100_000_000) else { return nil }
            return (high.value * 100_000_000 + low.value, high.elided || low.elided)
        }
        return cardinalBelowYi(chars)
    }

    private static func cardinalBelowYi(_ chars: [Character]) -> (value: Int, elided: Bool)? {
        if let wan = chars.lastIndex(where: { CharClass.chinesePositions[$0] == 10_000 }) {
            guard wan > 0, let high = belowTenThousand(Array(chars[..<wan])), high.value > 0 else { return nil }
            let rest = Array(chars[(wan + 1)...])
            guard let low = remainder(rest, scale: 10_000) else { return nil }
            return (high.value * 10_000 + low.value, high.elided || low.elided)
        }
        return belowTenThousand(chars)
    }

    /// The part after 万/亿: empty, 零 + value, a single elided digit, or a full lower group.
    private static func remainder(_ chars: [Character], scale: Int) -> (value: Int, elided: Bool)? {
        if chars.isEmpty { return (0, false) }
        if chars.count == 1, let digit = CharClass.chineseDigits[chars[0]], digit > 0 {
            return (digit * scale / 10, true)
        }
        var body = chars
        if let first = body.first, CharClass.chineseDigits[first] == 0 { body.removeFirst() }
        guard let low = (scale == 10_000 ? belowTenThousand(body) : cardinalBelowYi(body)), low.value < scale else {
            return nil
        }
        return low
    }

    private static func belowTenThousand(_ chars: [Character]) -> (value: Int, elided: Bool)? {
        guard !chars.isEmpty else { return nil }
        if chars.count == 1, let value = CharClass.chineseDigits[chars[0]] { return (value, false) }
        var total = 0
        var lastUnit = 10_000
        var pending: Int?
        var sawZero = false
        for c in chars {
            if let digit = CharClass.chineseDigits[c] {
                if digit == 0 {
                    guard pending == nil, total > 0, !sawZero else { return nil }
                    sawZero = true
                    continue
                }
                guard pending == nil else { return nil }
                pending = digit
            } else if let unit = CharClass.chinesePositions[c], unit < 10_000 {
                guard unit < lastUnit else { return nil }
                let digit: Int
                if let pending {
                    digit = pending
                } else if unit == 10, total == 0, !sawZero {
                    digit = 1 // 十二
                } else {
                    return nil
                }
                if sawZero { guard unit * 10 < lastUnit else { return nil } }
                total += digit * unit
                lastUnit = unit
                pending = nil
                sawZero = false
            } else {
                return nil
            }
        }
        if let digit = pending {
            if sawZero || lastUnit == 10 {
                total += digit
            } else if lastUnit == 10_000 {
                return nil // two bare digits never form a cardinal
            } else {
                return (total + digit * lastUnit / 10, true)
            }
        } else if sawZero {
            return nil
        }
        return (total, false)
    }
}

enum EnglishNumberGrammar {
    static let units: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9
    ]
    static let teens: [String: Int] = [
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19
    ]
    static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]
    static let scales: [String: Int] = ["thousand": 1_000, "million": 1_000_000, "billion": 1_000_000_000]
    /// Scales that stay as words after a decimal or a cardinal (3 million, 3.5 billion).
    static let wordScales: Set<String> = ["million", "billion"]
    static let ordinalUnits: [String: Int] = [
        "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
        "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9
    ]

    /// Words that can be part of a cardinal phrase (hyphenated tens-units are split by the caller).
    static func isCardinalWord(_ word: String) -> Bool {
        units[word] != nil || teens[word] != nil || tens[word] != nil || word == "hundred" || scales[word] != nil
    }

    /// Splits a valid tens-unit compound ("twenty-one", or ASR-glued "twentyone") into its words.
    static func splitCompound(_ word: String) -> [String]? {
        if !word.contains("-") {
            for ten in tens.keys where word.hasPrefix(ten) && word.count > ten.count {
                let rest = String(word.dropFirst(ten.count))
                if let unit = units[rest], unit > 0 { return [ten, rest] }
            }
            return nil
        }
        let parts = word.split(separator: "-").map(String.init)
        guard parts.count == 2, tens[parts[0]] != nil, let unit = units[parts[1]], unit > 0 else { return nil }
        return parts
    }

    static func cardinal(_ words: [String]) -> Int? {
        guard !words.isEmpty else { return nil }
        if words == ["zero"] { return 0 }
        var total = 0
        var lastScale = Int.max
        var group: [String] = []
        for word in words {
            if let scale = scales[word] {
                guard scale < lastScale, let value = subThousand(group), value > 0 else { return nil }
                total += value * scale
                lastScale = scale
                group = []
            } else {
                group.append(word)
            }
        }
        if group.isEmpty { return total > 0 ? total : nil }
        if group.first == "and" {
            guard total > 0 else { return nil }
            group.removeFirst()
            guard !group.isEmpty else { return nil }
        }
        guard let rest = subThousand(group) else { return nil }
        return total + rest
    }

    static func subThousand(_ words: [String]) -> Int? {
        guard !words.isEmpty else { return nil }
        if let hundred = words.firstIndex(of: "hundred") {
            guard hundred == 1, let digit = units[words[0]], digit >= 1 else { return nil }
            var tail = Array(words.dropFirst(2))
            if tail.first == "and" {
                tail.removeFirst()
                guard !tail.isEmpty else { return nil }
            }
            guard let rest = tail.isEmpty ? 0 : belowHundred(tail) else { return nil }
            return digit * 100 + rest
        }
        return belowHundred(words)
    }

    static func belowHundred(_ words: [String]) -> Int? {
        switch words.count {
        case 1:
            if let unit = units[words[0]], unit > 0 { return unit }
            return teens[words[0]] ?? tens[words[0]]
        case 2:
            guard let ten = tens[words[0]], let unit = units[words[1]], unit > 0 else { return nil }
            return ten + unit
        default:
            return nil
        }
    }

    /// 10...99 spoken as one group (teen, tens, tens-unit).
    static func twoDigitGroup(_ words: [String]) -> Int? {
        guard let value = belowHundred(words), value >= 10 else { return nil }
        return value
    }

    /// Two juxtaposed two-digit groups forming a plausible year. The first group is limited to
    /// 13...20 because 10-12 + minutes is how clock times are spoken ("eleven thirty").
    static func year(_ words: [String]) -> Int? {
        guard words.count >= 2, words.count <= 4 else { return nil }
        for split in 1..<words.count {
            guard let high = twoDigitGroup(Array(words[..<split])), (13...20).contains(high),
                  let low = twoDigitGroup(Array(words[split...])) else { continue }
            return high * 100 + low
        }
        return nil
    }

    /// Three or more single digits (oh counts as zero after the first).
    static func digitSequence(_ words: [String]) -> String? {
        guard words.count >= 3 else { return nil }
        var result = ""
        for (index, word) in words.enumerated() {
            if let unit = units[word] {
                result += String(unit)
            } else if word == "oh", index > 0 {
                result += "0"
            } else {
                return nil
            }
        }
        return result
    }

    /// Digits after "point": single digits (oh = 0), teens and tens concatenated, ASCII digits.
    static func fractionDigits(_ words: [String]) -> String? {
        guard !words.isEmpty else { return nil }
        var result = ""
        var index = 0
        while index < words.count {
            let word = words[index]
            if let unit = units[word] {
                result += String(unit)
            } else if word == "oh" {
                result += "0"
            } else if let teen = teens[word] {
                result += String(teen)
            } else if let ten = tens[word] {
                if index + 1 < words.count, let unit = units[words[index + 1]], unit > 0 {
                    result += String(ten + unit)
                    index += 1
                } else {
                    result += String(ten)
                }
            } else if !word.isEmpty, word.allSatisfy(CharClass.isASCIIDigit) {
                result += word
            } else {
                return nil
            }
            index += 1
        }
        return result
    }

    static func ordinalSuffix(_ value: Int) -> String {
        let lastTwo = value % 100
        if (11...13).contains(lastTwo) { return "th" }
        switch value % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
