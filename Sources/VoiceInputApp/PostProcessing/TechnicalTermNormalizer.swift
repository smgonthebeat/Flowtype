import Foundation

struct TechnicalTermNormalizationResult: Equatable {
    let text: String
    let events: [PostProcessingEvent]
}

enum TechnicalTermNormalizer {
    private struct Rule {
        let regex: NSRegularExpression
        let replacement: String
        let ruleID: String
        let reason: String
    }

    private static let rules: [Rule] = [
        Rule(
            regex: try! NSRegularExpression(
                pattern: #"\bc\s+(?:hat|head)\s+g\s*p\s*t\b"#,
                options: [.caseInsensitive]
            ),
            replacement: "ChatGPT",
            ruleID: "technical-term.chatgpt.c-hat-gpt",
            reason: "Normalize high-confidence ChatGPT ASR near-miss before math notation."
        ),
        Rule(
            regex: try! NSRegularExpression(
                pattern: #"\bchat\s*g\s*p\s*t\b"#,
                options: [.caseInsensitive]
            ),
            replacement: "ChatGPT",
            ruleID: "technical-term.chatgpt.spaced-gpt",
            reason: "Normalize ChatGPT casing and spaced GPT variants before math notation."
        )
    ]

    static func normalize(_ text: String) -> TechnicalTermNormalizationResult {
        var current = text
        var events: [PostProcessingEvent] = []

        for rule in rules {
            let result = replaceMatches(in: current, using: rule)
            current = result.text
            events.append(contentsOf: result.events)
        }

        return TechnicalTermNormalizationResult(text: current, events: events)
    }

    private static func replaceMatches(in text: String, using rule: Rule) -> TechnicalTermNormalizationResult {
        var result = ""
        var searchStart = text.startIndex
        var events: [PostProcessingEvent] = []
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        rule.regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range, in: text),
                  matchRange.lowerBound >= searchStart else {
                return
            }

            let before = String(text[matchRange])
            result += text[searchStart..<matchRange.lowerBound]
            result += rule.replacement

            if before != rule.replacement {
                events.append(
                    PostProcessingEvent(
                        ruleID: rule.ruleID,
                        rangeDescription: "segment:\(match.range.location)..<\(match.range.location + match.range.length)",
                        before: before,
                        after: rule.replacement,
                        reason: rule.reason,
                        confidence: .high
                    )
                )
            }

            searchStart = matchRange.upperBound
        }

        result += text[searchStart..<text.endIndex]
        return TechnicalTermNormalizationResult(text: result, events: events)
    }
}
