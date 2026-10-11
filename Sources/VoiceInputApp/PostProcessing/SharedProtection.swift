import Foundation

/// One protected-span set for every rewriting stage: URLs, e-mail, paths, code, model IDs,
/// versions and dictionary hotwords. Each stage recomputes it on its own input; protected
/// text is never edited, so the recomputed set is the same spans moved by earlier edits.
enum SharedProtection {
    static func spans(in text: String, knownTerms: [String]) -> [ProtectedSpan] {
        let detected = ProtectedSpanDetector.detect(in: text)
        let hotwords = hotwordRanges(in: text, knownTerms: knownTerms).map {
            ProtectedSpan(range: $0, kind: .knownTerm, text: String(text[$0]))
        }
        return (detected + hotwords).sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    static func ranges(in text: String, knownTerms: [String]) -> [Range<String.Index>] {
        spans(in: text, knownTerms: knownTerms).map(\.range)
    }

    /// Case-insensitive hotword occurrences. An ASCII letter or digit at a term edge must not
    /// continue into a neighbouring ASCII word; Han edges need no boundary.
    static func hotwordRanges(in text: String, knownTerms: [String]) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        for term in knownTerms {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let found = text.range(of: trimmed, options: [.caseInsensitive], range: searchStart..<text.endIndex) {
                if isTokenBounded(found, in: text) { result.append(found) }
                searchStart = text.index(after: found.lowerBound)
            }
        }
        return result.sorted { $0.lowerBound < $1.lowerBound }
    }

    private static func isTokenBounded(_ range: Range<String.Index>, in text: String) -> Bool {
        if let first = text[range].first, CharClass.isASCIIWordChar(first), range.lowerBound > text.startIndex,
           CharClass.isASCIIWordChar(text[text.index(before: range.lowerBound)]) {
            return false
        }
        if let last = text[range].last, CharClass.isASCIIWordChar(last), range.upperBound < text.endIndex,
           CharClass.isASCIIWordChar(text[range.upperBound]) {
            return false
        }
        return true
    }

    static func overlaps(_ range: Range<String.Index>, _ protected: [Range<String.Index>]) -> Bool {
        protected.contains { $0.overlaps(range) }
    }

    /// Applies `transform` to every unprotected segment, copying protected text verbatim.
    static func transformUnprotected(
        in text: String,
        knownTerms: [String],
        using transform: (String) -> String
    ) -> String {
        let protected = merged(ranges(in: text, knownTerms: knownTerms))
        guard !protected.isEmpty else { return transform(text) }
        var result = ""
        var cursor = text.startIndex
        for range in protected {
            if cursor < range.lowerBound { result += transform(String(text[cursor..<range.lowerBound])) }
            result += text[range]
            cursor = range.upperBound
        }
        if cursor < text.endIndex { result += transform(String(text[cursor...])) }
        return result
    }

    static func merged(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, last.upperBound >= range.lowerBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }
}
