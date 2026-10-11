import Foundation

struct SpelledLetterNormalizationResult {
    let text: String
    let events: [PostProcessingEvent]
}

/// Format letter runs conservatively; explicit math syntax retains its arguments.
enum SpelledLetterNormalizer {
    private static let spellingPattern = try! NSRegularExpression(
        // An apostrophe is word-internal: a contraction tail (It's) never starts a letter run.
        pattern: #"(?<![A-Za-z0-9_'’])(?:[A-Za-z][ \t]+)+[A-Za-z](?![A-Za-z0-9_'’])"#
    )
    private static let namePattern = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_])[A-Z]{2,}(?![A-Za-z0-9_])"#
    )

    /// Reserve entire raw candidates before other stages can consume their letters.
    /// Syntax overlaps are retained here because reservation does not rewrite text.
    static func rawLetterRanges(in text: String) -> [Range<String.Index>] {
        spellingPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text) }
    }

    /// Only complete candidates outside strong syntax are eligible for spelling.
    /// These ranges belong to this input and are never reused after a rewrite.
    static func letterRanges(in text: String) -> [Range<String.Index>] {
        let ranges = rawLetterRanges(in: text)
        guard !ranges.isEmpty else { return [] }
        let protected = MathProtectedSegmenter.syntaxProtectedRanges(in: text)
        var protectedIndex = 0
        var result: [Range<String.Index>] = []
        for range in ranges {
            while protectedIndex < protected.count, protected[protectedIndex].upperBound <= range.lowerBound {
                protectedIndex += 1
            }
            if protectedIndex == protected.count || !protected[protectedIndex].overlaps(range) {
                result.append(range)
            }
        }
        return result
    }

    /// Formulas are protected spans of the math layer (design.md 8.4), so spelling no longer
    /// needs a math-aware branch: unprotected text is treated the same with the math switch on or off.
    static func normalize(
        _ text: String,
        protectedRanges: [Range<String.Index>] = []
    ) -> SpelledLetterNormalizationResult {
        let ranges = letterRanges(in: text).filter { !SharedProtection.overlaps($0, protectedRanges) }
        guard !ranges.isEmpty else { return SpelledLetterNormalizationResult(text: text, events: []) }
        var result = text
        var events: [PostProcessingEvent] = []
        for range in ranges.reversed() {
            guard !hasAmbiguousWordBoundary(in: text, range: range) else { continue }
            let original = String(text[range])
            let replacement = original.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined().uppercased()
            result.replaceSubrange(range, with: replacement)
            let match = NSRange(range, in: text)
            events.append(PostProcessingEvent(
                ruleID: "spelling.join-letters",
                rangeDescription: "segment:\(match.location)..<\(match.location + match.length)",
                before: original,
                after: replacement,
                reason: "Apply the letter-spelling convention without an ambiguous word boundary.",
                confidence: .medium
            ))
        }
        return SpelledLetterNormalizationResult(text: result, events: events)
    }

    /// Keep the same abstention decision when a later formatter processes the text.
    /// In particular, protected-segment boundaries do not create standalone utterances.
    static func ambiguousLetterRanges(in text: String) -> [Range<String.Index>] {
        let ranges = letterRanges(in: text)
        guard !ranges.isEmpty else { return [] }
        let candidates = MathSpeechParser.statisticsCandidates(in: text)
        return ranges.filter {
            hasAmbiguousWordBoundary(in: text, range: $0)
                && !hasMathContext(in: text, range: $0, candidates: candidates)
        }
    }

    private static func hasAmbiguousWordBoundary(in text: String, range: Range<String.Index>) -> Bool {
        let tokens = text[range].lowercased().split(whereSeparator: { $0 == " " || $0 == "\t" })
        let wordEdges: Set<Substring> = ["a", "i"]
        guard tokens.first.map(wordEdges.contains) == true || tokens.last.map(wordEdges.contains) == true else {
            return false
        }
        guard text[..<range.lowerBound].allSatisfy(\.isWhitespace) else { return true }
        let suffix = text[range.upperBound...].drop(while: \.isWhitespace)
        guard let first = suffix.first else { return false }
        return !".。!！?？".contains(first) || !suffix.dropFirst().allSatisfy(\.isWhitespace)
    }

    /// Re-detect exact token ranges on each math pass, including already compact names.
    /// This keeps repeated processing stable without persistent Dictionary mutations.
    static func nameRanges(in text: String) -> [Range<String.Index>] {
        let matches = namePattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return [] }
        let candidates = MathSpeechParser.statisticsCandidates(in: text)
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text), !hasMathContext(in: text, range: range, candidates: candidates) else { return nil }
            return range
        }
    }

    private static func hasMathContext(in text: String, range: Range<String.Index>, candidates: [MathSpeechParser.StatisticsCandidate]) -> Bool {
        // A strict internal match (E O inside C E O) cannot override the whole name.
        let letters = text[range].lowercased().split(whereSeparator: { $0 == " " || $0 == "\t" })
        let ambiguousExpectation = letters.count == 2 && letters[0] == "e"
            && !["x", "y", "z", "t"].contains(String(letters[1]))
        if !ambiguousExpectation,
           candidates.contains(where: { $0.range.lowerBound <= range.lowerBound && $0.range.upperBound >= range.upperBound }) { return true }
        let prefix = String(text[..<range.lowerBound].suffix(100))
        let suffix = String(text[range.upperBound...].prefix(100))
        let preceding = #"(?:[=+*/^_({-]|\b(?:let|variables?|matrix|vector|variance|covariance|correlation|expectation|cov|corr|var|sd|se)|\b(?:variance|covariance|correlation|expectation|standard deviation|standard error)\s+(?:of\s+)?|(?:变量|矩阵|向量|设))\s*$"#
        let following = #"^\s*(?:[=+*/^_})-]|\b(?:hat|head|bar|tilde|prime|dot|squared|cubed|sub|transpose|inverse|plus|minus|times|over|equals)\b)"#
        if prefix.range(of: preceding, options: [.regularExpression, .caseInsensitive]) != nil ||
            suffix.range(of: following, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        // Probability shorthand is rendered outside the statistics parser; retain its existing boundary.
        let isolated = prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && suffix.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).isEmpty
        return isolated && letters.count == 2 && letters[0] == "p"
            && ["x", "y", "z", "t"].contains(String(letters[1]))
    }
}
