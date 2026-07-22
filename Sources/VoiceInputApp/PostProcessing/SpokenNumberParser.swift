import Foundation

enum SpokenNumberParser {
    private static let sequentialDigitMap: [Character: String] = [
        "零": "0",
        "〇": "0",
        "一": "1",
        "二": "2",
        "两": "2",
        "三": "3",
        "四": "4",
        "五": "5",
        "六": "6",
        "七": "7",
        "八": "8",
        "九": "9"
    ]

    private static let englishOnes: [String: Int] = [
        "zero": 0,
        "one": 1,
        "two": 2,
        "three": 3,
        "four": 4,
        "five": 5,
        "six": 6,
        "seven": 7,
        "eight": 8,
        "nine": 9
    ]

    private static let englishTeens: [String: Int] = [
        "ten": 10,
        "eleven": 11,
        "twelve": 12,
        "thirteen": 13,
        "fourteen": 14,
        "fifteen": 15,
        "sixteen": 16,
        "seventeen": 17,
        "eighteen": 18,
        "nineteen": 19
    ]

    private static let englishTens: [String: Int] = [
        "twenty": 20,
        "thirty": 30,
        "forty": 40,
        "fifty": 50,
        "sixty": 60,
        "seventy": 70,
        "eighty": 80,
        "ninety": 90
    ]

    static func sequentialDigits(_ text: String) -> String? {
        let digits = text.compactMap { sequentialDigitMap[$0] }
        guard digits.count == text.count else { return nil }
        return digits.joined()
    }

    static func number(_ text: String) -> Int? {
        if text.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil {
            return Int(text)
        }

        return chineseNumber(text)
    }

    static func numberOrEnglishNumber(_ text: String) -> Int? {
        if let value = number(text) {
            return value
        }

        return englishNumber(text)
    }

    private static func englishNumber(_ text: String) -> Int? {
        let tokens = text
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map(String.init)

        guard !tokens.isEmpty, tokens.count <= 2 else {
            return nil
        }

        if tokens.count == 1 {
            let token = tokens[0]
            return englishOnes[token] ?? englishTeens[token] ?? englishTens[token]
        }

        guard
            let tens = englishTens[tokens[0]],
            let ones = englishOnes[tokens[1]],
            ones > 0
        else {
            return nil
        }

        return tens + ones
    }

    static func decimal(_ text: String) -> String? {
        if text.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil {
            return text
        }

        let components = text.split(separator: "点", maxSplits: 1, omittingEmptySubsequences: false)
        if components.count == 2 {
            guard
                let fractional = fractionalDigits(String(components[1])),
                !fractional.isEmpty
            else {
                return nil
            }

            let integerText = String(components[0])
            let integer: Int
            if integerText.isEmpty {
                integer = 0
            } else {
                guard let value = number(integerText) else {
                    return nil
                }
                integer = value
            }
            return "\(integer).\(fractional)"
        }

        return chineseNumber(text).map(String.init)
    }

    private static func chineseNumber(_ text: String) -> Int? {
        guard !text.isEmpty else { return nil }

        if let digits = sequentialDigits(text), let value = Int(digits) {
            return value
        }

        return parseHundreds(text)
    }

    private static func parseHundreds(_ text: String) -> Int? {
        let components = text.split(separator: "百", maxSplits: 1, omittingEmptySubsequences: false)
        if components.count == 1 {
            return parseTens(text)
        }

        guard
            components.count == 2,
            let hundredsDigit = nonZeroDigit(String(components[0]))
        else {
            return nil
        }

        let remainder = String(components[1])
        if remainder.isEmpty {
            return hundredsDigit * 100
        }

        if remainder.first == "零" || remainder.first == "〇" {
            let trimmed = String(remainder.dropFirst())
            guard let value = nonZeroDigit(trimmed) else {
                return nil
            }
            return hundredsDigit * 100 + value
        }

        if let colloquialTensDigit = nonZeroDigit(remainder) {
            return hundredsDigit * 100 + colloquialTensDigit * 10
        }

        guard let value = parseTens(remainder) else {
            return nil
        }
        return hundredsDigit * 100 + value
    }

    private static func parseTens(_ text: String) -> Int? {
        let components = text.split(separator: "十", maxSplits: 1, omittingEmptySubsequences: false)
        if components.count == 1 {
            return singleDigit(text)
        }

        guard components.count == 2 else { return nil }

        let tensText = String(components[0])
        let tens: Int
        if tensText.isEmpty {
            tens = 1
        } else {
            guard let value = nonZeroDigit(tensText) else {
                return nil
            }
            tens = value
        }

        let onesText = String(components[1])
        if onesText.isEmpty {
            return tens * 10
        }

        guard let ones = nonZeroDigit(onesText) else {
            return nil
        }
        return tens * 10 + ones
    }

    private static func singleDigit(_ text: String) -> Int? {
        guard text.count == 1 else { return nil }
        guard let value = sequentialDigits(text).flatMap(Int.init) else { return nil }
        return value
    }

    private static func nonZeroDigit(_ text: String) -> Int? {
        guard let value = singleDigit(text), value > 0 else { return nil }
        return value
    }

    private static func fractionalDigits(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }

        if text.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil {
            return text
        }

        return sequentialDigits(text)
    }
}
