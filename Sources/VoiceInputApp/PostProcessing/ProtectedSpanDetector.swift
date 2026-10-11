import Foundation

enum ProtectedSpanDetector {
    private static let patterns: [(ProtectedSpanKind, NSRegularExpression)] = [
        // URL and path bodies are ASCII-only so Han text glued to them is not swallowed.
        (.url, try! NSRegularExpression(pattern: #"https?://[!-~]+"#)),
        (.email, try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)),
        (.filePath, try! NSRegularExpression(pattern: #"(?:~|/Users|/usr|/opt|/var|/tmp|/private)/[!-~]+"#)),
        (.modelID, try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9/])(?:[A-Z][A-Za-z0-9_.-]*/[A-Za-z0-9_.-]*[A-Z][A-Za-z0-9_.-]*|(?:anthropic|baai|cohere|deepseek-ai|facebook|google|huggingface|meta-llama|microsoft|mistralai|nvidia|openai|qwen|qwenlm|sentence-transformers|stabilityai|tiiuae)[A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*(?:-[A-Za-z0-9_.-]+)+)(?![A-Za-z0-9/])"#)),
        (.version, try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9])v[0-9]+(?:\.[0-9]+)+(?![A-Za-z0-9])"#)),
        (.courseCode, try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9])(?:STAT|ECON|MATH|CS|EE)[0-9]{2,6}(?![A-Za-z0-9])"#)),
        (.academicReference, try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9])(?:Exercise\s+[0-9]{1,3}|Ex[0-9]{1,3}|Q[0-9]{1,3}|[A-D][0-9]{1,3})\([a-z]\)(?![A-Za-z0-9])"#))
    ]

    static func detect(in text: String) -> [ProtectedSpan] {
        let source = text as NSString
        var spans: [ProtectedSpan] = []

        for (kind, regex) in patterns {
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
            for match in matches {
                let trimmedRange = trimTrailingDelimiters(from: match.range, kind: kind, in: source)
                guard trimmedRange.length > 0, let range = Range(trimmedRange, in: text) else { continue }
                spans.append(ProtectedSpan(range: range, kind: kind, text: String(text[range])))
            }
        }

        let selectedSpans = selectPreferredSpans(from: spans)

        let codeSpans = CodeSpanDetector.ranges(in: text).map { ProtectedSpan(range: $0, kind: .code, text: String(text[$0])) }
        let mathSpans = mathSpanRanges(in: text).map { ProtectedSpan(range: $0, kind: .mathSpan, text: String(text[$0])) }
        let others = (selectedSpans + codeSpans).filter { span in !mathSpans.contains { rangesOverlap($0.range, span.range) } }
        return (others + mathSpans).sorted { lhs, rhs in
            lhs.range.lowerBound < rhs.range.lowerBound
        }
    }

    /// Formulas rendered by MathStage: each one sits between its two sentinel characters
    /// (design.md 8.1). Later stages copy these spans verbatim. Text without sentinels has none,
    /// so the math-off path is unaffected.
    static func mathSpanRanges(in text: String) -> [Range<String.Index>] {
        guard text.contains(MathStage.openSentinel) else { return [] }
        var result: [Range<String.Index>] = []
        var index = text.startIndex
        while let open = text[index...].firstIndex(of: MathStage.openSentinel) {
            guard let close = text[text.index(after: open)...].firstIndex(of: MathStage.closeSentinel) else { break }
            let end = text.index(after: close)
            result.append(open..<end)
            index = end
        }
        return result
    }

    private static func trimTrailingDelimiters(from range: NSRange, kind: ProtectedSpanKind, in source: NSString) -> NSRange {
        let trailingDelimiters = trailingDelimiterCharacterSet(for: kind)
        var trimmedRange = range

        guard let trailingDelimiters else {
            return trimmedRange
        }

        while trimmedRange.length > 0 {
            let lastCharacter = source.substring(with: NSRange(location: trimmedRange.location + trimmedRange.length - 1, length: 1))
            guard lastCharacter.rangeOfCharacter(from: trailingDelimiters) != nil else {
                break
            }
            trimmedRange.length -= 1
        }

        return trimmedRange
    }

    private static func trailingDelimiterCharacterSet(for kind: ProtectedSpanKind) -> CharacterSet? {
        switch kind {
        case .url, .filePath, .email:
            return CharacterSet(charactersIn: #".,，。！？；：、)]}"'"#)
        case .code, .command, .modelID, .version, .courseCode, .academicReference, .spelledLetters, .numericCandidate,
             .knownTerm, .mathSpan:
            return nil
        }
    }

    private static func selectPreferredSpans(from spans: [ProtectedSpan]) -> [ProtectedSpan] {
        let prioritizedSpans = spans.sorted { lhs, rhs in
            let lhsPriority = priority(of: lhs.kind)
            let rhsPriority = priority(of: rhs.kind)

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            let lhsLength = lhs.text.count
            let rhsLength = rhs.text.count
            if lhsLength != rhsLength {
                return lhsLength > rhsLength
            }

            if lhs.range.lowerBound != rhs.range.lowerBound {
                return lhs.range.lowerBound < rhs.range.lowerBound
            }

            return lhs.range.upperBound < rhs.range.upperBound
        }

        var selected: [ProtectedSpan] = []

        for candidate in prioritizedSpans {
            guard selected.allSatisfy({ !rangesOverlap($0.range, candidate.range) }) else {
                continue
            }
            selected.append(candidate)
        }

        return selected
    }

    private static func priority(of kind: ProtectedSpanKind) -> Int {
        switch kind {
        case .mathSpan:
            return -2
        case .code:
            return -1
        case .url:
            return 0
        case .filePath:
            return 1
        case .email:
            return 2
        case .modelID:
            return 3
        case .courseCode:
            return 4
        case .academicReference:
            return 5
        case .numericCandidate:
            return 9
        case .spelledLetters:
            return 8
        case .version:
            return 6
        case .command:
            return 7
        case .knownTerm:
            return 10
        }
    }

    private static func rangesOverlap(_ lhs: Range<String.Index>, _ rhs: Range<String.Index>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }
}
