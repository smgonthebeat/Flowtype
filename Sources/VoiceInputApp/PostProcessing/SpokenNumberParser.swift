import Foundation

/// Compatibility facade over the shared number grammar for the academic and ASR-confusion
/// stages. It keeps their established reading preference (digit-by-digit before cardinal);
/// the numeric layer itself never uses this preference.
enum SpokenNumberParser {
    static func sequentialDigits(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        var result = ""
        for character in text {
            guard let value = CharClass.chineseDigits[character] else { return nil }
            result += String(value)
        }
        return result
    }

    static func number(_ text: String) -> Int? {
        if !text.isEmpty, text.allSatisfy(CharClass.isASCIIDigit) {
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

    static func decimal(_ text: String) -> String? {
        if text.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil {
            return text
        }

        let components = text.split(separator: "点", maxSplits: 1, omittingEmptySubsequences: false)
        if components.count == 2 {
            let fractionText = String(components[1])
            let fraction: String?
            if !fractionText.isEmpty, fractionText.allSatisfy(CharClass.isASCIIDigit) {
                fraction = fractionText
            } else {
                fraction = sequentialDigits(fractionText)
            }
            guard let fraction, !fraction.isEmpty else { return nil }

            let integerText = String(components[0])
            if integerText.isEmpty { return "0.\(fraction)" }
            guard let integer = number(integerText) else { return nil }
            return "\(integer).\(fraction)"
        }

        return chineseNumber(text).map(String.init)
    }

    private static func chineseNumber(_ text: String) -> Int? {
        guard !text.isEmpty else { return nil }
        if let digits = sequentialDigits(text), let value = Int(digits) {
            return value
        }
        return ChineseNumberGrammar.cardinal(Array(text))?.value
    }

    private static func englishNumber(_ text: String) -> Int? {
        let words = text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map(String.init)
        guard !words.isEmpty, words.count <= 2 else { return nil }
        if words == ["zero"] { return 0 }
        return EnglishNumberGrammar.belowHundred(words)
    }
}
