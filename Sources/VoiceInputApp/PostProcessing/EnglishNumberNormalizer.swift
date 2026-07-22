import Foundation

enum EnglishNumberNormalizer: TranscriptNormalizer {
    static let id = "english_number"

    private static let numberPattern = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_./\-])((?i:twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)(?:[\s-]+(?i:one|two|three|four|five|six|seven|eight|nine))?|(?i:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen))(?=$|[\s，,、。！？!?:;；：)\]]|\.(?:$|[\s]))"#
    )

    static func normalize(_ text: String, context: NormalizationContext) -> String {
        replaceMatches(
            in: text,
            regex: numberPattern,
            protectedSpans: context.protectedSpans
        ) { match, source in
            guard
                let numberText = capture(1, in: match, source: source),
                let value = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return "\(value)"
        }.text
    }

    private static func replaceMatches(
        in text: String,
        regex: NSRegularExpression,
        protectedSpans: [ProtectedSpan],
        replacement: (NSTextCheckingResult, NSString) -> String?
    ) -> (text: String, protectedSpans: [ProtectedSpan]) {
        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        var result = text
        var edits: [AppliedEdit] = []

        for match in matches.reversed() {
            guard !overlapsProtectedSpan(match.range, in: text, protectedSpans: protectedSpans) else {
                continue
            }
            guard let replacementText = replacement(match, source) else {
                continue
            }
            guard let range = Range(match.range, in: result) else {
                continue
            }

            edits.append(
                AppliedEdit(
                    location: match.range.location,
                    originalLength: match.range.length,
                    replacementLength: replacementText.utf16.count
                )
            )
            result.replaceSubrange(range, with: replacementText)
        }

        return (
            result,
            remapProtectedSpans(
                protectedSpans,
                through: edits,
                from: text,
                to: result
            )
        )
    }

    private static func overlapsProtectedSpan(
        _ matchRange: NSRange,
        in text: String,
        protectedSpans: [ProtectedSpan]
    ) -> Bool {
        guard let candidateRange = Range(matchRange, in: text) else {
            return false
        }

        return protectedSpans.contains { protectedSpan in
            rangesOverlap(candidateRange, protectedSpan.range)
        }
    }

    private static func rangesOverlap(_ lhs: Range<String.Index>, _ rhs: Range<String.Index>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    private static func remapProtectedSpans(
        _ protectedSpans: [ProtectedSpan],
        through edits: [AppliedEdit],
        from originalText: String,
        to updatedText: String
    ) -> [ProtectedSpan] {
        guard !protectedSpans.isEmpty, !edits.isEmpty else {
            return protectedSpans
        }

        let sortedEdits = edits.sorted { $0.location < $1.location }

        return protectedSpans.compactMap { protectedSpan in
            let originalLowerBound = protectedSpan.range.lowerBound.utf16Offset(in: originalText)
            let originalUpperBound = protectedSpan.range.upperBound.utf16Offset(in: originalText)

            let shiftedLowerBound = originalLowerBound + totalDelta(before: originalLowerBound, edits: sortedEdits)
            let shiftedUpperBound = originalUpperBound + totalDelta(before: originalUpperBound, edits: sortedEdits)

            guard
                let lowerIndex = stringIndex(utf16Offset: shiftedLowerBound, in: updatedText),
                let upperIndex = stringIndex(utf16Offset: shiftedUpperBound, in: updatedText)
            else {
                return nil
            }

            let range = lowerIndex..<upperIndex
            return ProtectedSpan(range: range, kind: protectedSpan.kind, text: String(updatedText[range]))
        }
    }

    private static func totalDelta(before location: Int, edits: [AppliedEdit]) -> Int {
        edits.reduce(into: 0) { delta, edit in
            if edit.location < location {
                delta += edit.replacementLength - edit.originalLength
            }
        }
    }

    private static func stringIndex(utf16Offset: Int, in text: String) -> String.Index? {
        guard
            utf16Offset >= 0,
            let utf16Index = text.utf16.index(text.utf16.startIndex, offsetBy: utf16Offset, limitedBy: text.utf16.endIndex),
            let index = String.Index(utf16Index, within: text)
        else {
            return nil
        }

        return index
    }

    private static func capture(_ index: Int, in match: NSTextCheckingResult, source: NSString) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return nil }
        return source.substring(with: range)
    }
}

private struct AppliedEdit {
    let location: Int
    let originalLength: Int
    let replacementLength: Int
}
