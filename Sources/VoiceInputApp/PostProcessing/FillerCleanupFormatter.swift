import Foundation

enum FillerCleanupFormatter {
    private static let chineseClauseStartPattern = try! NSRegularExpression(
        pattern: #"(^|[\s，,。！？!?；;：:、])\s*(?:呃+|嗯+|额+|哦+|噢+|啊+|呀+|哎+|诶+|欸+|唉+)(?=$|[\s，,。！？!?；;：:、]|\p{Han}|[A-Za-z\\])[\s，,、]*"#
    )
    private static let chineseBetweenHanPattern = try! NSRegularExpression(
        pattern: #"(?<=\p{Han})(?:呃+|嗯+|额+|哦+|噢+|啊+|哎+|诶+|欸+|唉+)(?=\p{Han})"#
    )
    private static let chineseBeforeLatinPattern = try! NSRegularExpression(
        pattern: #"(?<=[\p{Han}A-Za-z0-9])(?:呃+|嗯+|额+|哦+|噢+|啊+|哎+|诶+|欸+|唉+)[\s，,、]+(?=[A-Za-z\\])"#
    )
    private static let chineseBeforePunctuationPattern = try! NSRegularExpression(
        pattern: #"(?<=[\p{Han}A-Za-z0-9])(?:呃+|嗯+|额+|哦+|噢+|啊+|哎+|诶+|欸+|唉+)(?=$|[\s，,。！？!?；;：:、])[\s，,、]*"#
    )
    private static let englishFillerPattern = try! NSRegularExpression(
        pattern: #"(?i)(^|[\s，,。\.！？!?；;：:、])(?:em+|um+|uh+|uhm+|erm+|ah+)(?=$|[\s，,。\.！？!?；;：:、]|\p{Han})[\s，,。\.！？!?；;：:、]*"#
    )

    static func format(_ text: String) -> String {
        var formatted = replaceMatches(in: text, regex: chineseClauseStartPattern, replacement: "$1")
        formatted = replaceMatches(in: formatted, regex: chineseBetweenHanPattern, replacement: "")
        formatted = replaceMatches(in: formatted, regex: chineseBeforeLatinPattern, replacement: " ")
        formatted = replaceMatches(in: formatted, regex: chineseBeforePunctuationPattern, replacement: "")
        formatted = replaceMatches(in: formatted, regex: englishFillerPattern, replacement: "$1")
        formatted = cleanupPunctuation(in: formatted)
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceMatches(
        in text: String,
        regex: NSRegularExpression,
        replacement: String
    ) -> String {
        regex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: replacement
        )
    }

    private static func cleanupPunctuation(in text: String) -> String {
        var cleaned = text.replacingOccurrences(
            of: #"[ \t]{2,}"#,
            with: " ",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"([，,。！？!?；;：:、])\s*([，,。！？!?；;：:、])+"#,
            with: "$1",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+([，,。！？!?；;：:、])"#,
            with: "$1",
            options: .regularExpression
        )
        return cleaned
    }
}
