import Foundation

enum MathProtectedSegmenter {
    static func syntaxProtectedRanges(in text: String) -> [Range<String.Index>] {
        mergedProtectedRanges(
            in: text, protectLatexCommands: true,
            unprotectedLatexCommands: [], knownTerms: []
        )
    }

    static func formatUnprotectedSegments(
        in text: String,
        protectLatexCommands: Bool = true,
        unprotectedLatexCommands: Set<String> = [],
        knownTerms: [String] = [],
        protectSpelledNames: Bool = false,
        using transform: (String) -> String
    ) -> String {
        var protectedRanges = mergedProtectedRanges(
            in: text,
            protectLatexCommands: protectLatexCommands,
            unprotectedLatexCommands: unprotectedLatexCommands,
            knownTerms: knownTerms
        )
        protectedRanges = merge(protectedRanges + MathSpeechParser.ambiguousUnaryOperandRanges(in: text))
        if protectSpelledNames {
            // Resolve ambiguous raw spelling against the complete input before
            // strong protection splits it into formatter segments.
            protectedRanges = merge(protectedRanges + SpelledLetterNormalizer.ambiguousLetterRanges(in: text))
        }
        return transformUnprotected(in: text, ranges: protectedRanges) { segment in
            guard protectSpelledNames else { return transform(segment) }
            // Strong protection splits the input before math/name arbitration.
            return transformUnprotected(in: segment, ranges: SpelledLetterNormalizer.nameRanges(in: segment), using: transform)
        }
    }

    private static func transformUnprotected(
        in text: String, ranges protectedRanges: [Range<String.Index>], using transform: (String) -> String
    ) -> String {
        guard !protectedRanges.isEmpty else {
            return transform(text)
        }

        var result = ""
        var cursor = text.startIndex

        for range in protectedRanges {
            if cursor < range.lowerBound {
                result += transform(String(text[cursor..<range.lowerBound]))
            }

            result += String(text[range])
            cursor = range.upperBound
        }

        if cursor < text.endIndex {
            result += transform(String(text[cursor..<text.endIndex]))
        }

        return result
    }

    private static func mergedProtectedRanges(
        in text: String,
        protectLatexCommands: Bool,
        unprotectedLatexCommands: Set<String>,
        knownTerms: [String]
    ) -> [Range<String.Index>] {
        let detectedRanges = ProtectedSpanDetector.detect(in: text).map(\.range)
        var protectedRanges = detectedRanges
        protectedRanges += knownTermRanges(in: text, knownTerms: knownTerms)

        if protectLatexCommands {
            protectedRanges += latexCommandRanges(in: text).filter { range in
                !unprotectedLatexCommands.contains(String(text[range]))
            }
        }

        return merge(protectedRanges)
    }

    private static func knownTermRanges(in text: String, knownTerms: [String]) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []

        for rawTerm in knownTerms {
            let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty else {
                continue
            }

            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let matchRange = text.range(
                      of: term,
                      options: [.caseInsensitive, .literal],
                      range: searchStart..<text.endIndex
                  ) {
                ranges.append(matchRange)
                if matchRange.isEmpty {
                    searchStart = text.index(after: matchRange.lowerBound)
                } else {
                    searchStart = matchRange.upperBound
                }
            }
        }

        return ranges
    }

    private static func regexRanges(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> [Range<String.Index>] {
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        let source = text as NSString
        return regex
            .matches(in: text, range: NSRange(location: 0, length: source.length))
            .compactMap { Range($0.range, in: text) }
    }

    private static func latexCommandRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var cursor = text.startIndex

        while let commandStart = text[cursor..<text.endIndex].firstIndex(of: "\\") {
            var commandEnd = text.index(after: commandStart)
            guard commandEnd < text.endIndex, isASCIILetter(text[commandEnd]) else {
                cursor = commandEnd
                continue
            }

            while commandEnd < text.endIndex, isASCIILetter(text[commandEnd]) {
                commandEnd = text.index(after: commandEnd)
            }

            var argumentEnd = commandEnd
            var consumedArgument = false
            while argumentEnd < text.endIndex, text[argumentEnd] == "{" {
                guard let balancedEnd = balancedBracedArgumentEnd(in: text, openingBrace: argumentEnd) else {
                    ranges.append(commandStart..<text.endIndex)
                    return ranges
                }
                argumentEnd = balancedEnd
                consumedArgument = true
            }

            if consumedArgument {
                ranges.append(commandStart..<argumentEnd)
                cursor = argumentEnd
            } else {
                cursor = commandEnd
            }
        }

        return ranges
    }

    private static func balancedBracedArgumentEnd(
        in text: String,
        openingBrace: String.Index
    ) -> String.Index? {
        var depth = 0
        var cursor = openingBrace

        while cursor < text.endIndex {
            if text[cursor] == "{" {
                depth += 1
            } else if text[cursor] == "}" {
                depth -= 1
                if depth == 0 {
                    return text.index(after: cursor)
                }
            }
            cursor = text.index(after: cursor)
        }

        return nil
    }

    private static func isASCIILetter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return false
        }
        return ("A"..."Z").contains(scalar) || ("a"..."z").contains(scalar)
    }

    private static func merge(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        let sortedRanges = ranges
            .filter { !$0.isEmpty }
            .sorted { lhs, rhs in
                if lhs.lowerBound != rhs.lowerBound {
                    return lhs.lowerBound < rhs.lowerBound
                }
                return lhs.upperBound < rhs.upperBound
            }

        var merged: [Range<String.Index>] = []

        for range in sortedRanges {
            guard let last = merged.last else {
                merged.append(range)
                continue
            }

            if range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }

        return merged
    }
}
