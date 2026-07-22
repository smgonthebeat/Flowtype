import Foundation

enum SemioticNumberNormalizer: TranscriptNormalizer {
    static let id = "semiotic_number"

    private static let datePattern = try! NSRegularExpression(
        pattern: "([0-9]{4}|[零〇一二三四五六七八九两]{4})年(?:的)?([0-9]{1,2}|[零〇一二三四五六七八九十两]{1,3})月([0-9]{1,2}|[零〇一二三四五六七八九十两]{1,3})(号|日)"
    )
    private static let percentPattern = try! NSRegularExpression(
        pattern: "百分之\\s*([0-9]+(?:\\.[0-9]+)?|[零〇一二三四五六七八九十百两点]+)"
    )
    private static let decimalWithUnitPattern = try! NSRegularExpression(
        pattern: "([零〇一二三四五六七八九十百两]+点[零〇一二三四五六七八九两]+)\\s*([A-Za-z%％])"
    )
    private static let identifierDigitPattern = try! NSRegularExpression(
        pattern: "(验证码|订单号|手机号|电话号码|电话|学号|账号|账户|编号|ID|id|代码|密码|邮编|房间号|航班号|快递单号|单号)(是|为|:|：)?([零〇一二三四五六七八九两]{2,})"
    )
    private static let problemNumberPattern = try! NSRegularExpression(
        pattern: "(第)?([零〇一二三四五六七八九十百两]{1,6})(道题|题|小题|大题|问)"
    )
    private static let approximateCountPairs: Set<String> = [
        "一两",
        "两三",
        "三四",
        "四五",
        "五六",
        "六七",
        "七八",
        "八九"
    ]

    static func normalize(_ text: String, context: NormalizationContext) -> String {
        let datePass = replaceMatches(
            in: text,
            regex: datePattern,
            protectedSpans: context.protectedSpans
        ) { match, source in
            guard
                let year = capture(1, in: match, source: source).flatMap(yearDigits),
                let monthText = capture(2, in: match, source: source),
                let month = SpokenNumberParser.number(monthText),
                let dayText = capture(3, in: match, source: source),
                let day = SpokenNumberParser.number(dayText),
                let suffix = capture(4, in: match, source: source)
            else {
                return nil
            }

            return "\(year)年\(month)月\(day)\(suffix)"
        }

        let percentPass = replaceMatches(
            in: datePass.text,
            regex: percentPattern,
            protectedSpans: datePass.protectedSpans
        ) { match, source in
            guard let numericText = capture(1, in: match, source: source).flatMap(SpokenNumberParser.decimal) else {
                return nil
            }
            return "\(numericText)%"
        }

        let decimalWithUnitPass = replaceMatches(
            in: percentPass.text,
            regex: decimalWithUnitPattern,
            protectedSpans: percentPass.protectedSpans
        ) { match, source in
            guard
                let decimal = capture(1, in: match, source: source).flatMap(SpokenNumberParser.decimal),
                let unit = capture(2, in: match, source: source)
            else {
                return nil
            }

            let normalizedUnit = unit == "％" ? "%" : unit
            return "\(decimal)\(normalizedUnit)"
        }

        let identifierDigitPass = replaceMatches(
            in: decimalWithUnitPass.text,
            regex: identifierDigitPattern,
            protectedSpans: decimalWithUnitPass.protectedSpans
        ) { match, source in
            guard
                let label = capture(1, in: match, source: source),
                let digitsText = capture(3, in: match, source: source),
                let digits = SpokenNumberParser.sequentialDigits(digitsText)
            else {
                return nil
            }

            let connector = capture(2, in: match, source: source) ?? ""
            return "\(label)\(connector)\(digits)"
        }

        return replaceMatches(
            in: identifierDigitPass.text,
            regex: problemNumberPattern,
            protectedSpans: identifierDigitPass.protectedSpans
        ) { match, source in
            guard
                let numberText = capture(2, in: match, source: source),
                !isApproximateCount(numberText),
                let value = SpokenNumberParser.number(numberText),
                let unit = capture(3, in: match, source: source)
            else {
                return nil
            }

            let prefix = capture(1, in: match, source: source) ?? ""
            return "\(prefix)\(value)\(unit)"
        }.text
    }

    private static func yearDigits(_ text: String) -> String? {
        if text.range(of: #"^[0-9]{4}$"#, options: .regularExpression) != nil {
            return text
        }

        return SpokenNumberParser.sequentialDigits(text)
    }

    private static func isApproximateCount(_ text: String) -> Bool {
        guard text.count == 2, !text.contains("十"), !text.contains("百") else {
            return false
        }

        return approximateCountPairs.contains(text)
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
