import Foundation

enum AcademicReferenceNormalizer: TranscriptNormalizer {
    static let id = "academic_reference"

    private static let spokenNumberPattern =
        #"(?:[0-9]{1,3}|[零〇一二三四五六七八九十百两]{1,6}|(?i:twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)(?:[\s-]+(?i:one|two|three|four|five|six|seven|eight|nine))?|(?i:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen))"#
    private static let sheetNumberPattern =
        #"(?:\#(spokenNumberPattern)|(?i:e))"#

    private static let subpartLetterPattern = #"[A-Ha-h]"#
    private static let subpartListPattern =
        #"(?:\#(subpartLetterPattern)(?:(?:\s+(?i:and)\s+|\s*和\s*)\#(subpartLetterPattern))*|(?i:BNC))"#

    private static let sheetExercisePattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])(?i:s?sheet|cheat)(?:\s*(\#(sheetNumberPattern)))?\s*(?:的\s*)?(?i:exercise)[\s，,、。！？!?.]*(\#(spokenNumberPattern))(?:\s*(\#(subpartListPattern)))?(?=$|[，,、。！？!?\.\s])"#
    )
    private static let exerciseSheetPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])(?i:exercise)\s+(?i:sheet|cheat)\s+(\#(spokenNumberPattern))(?:\s*(\#(subpartListPattern)))?(?=$|[，,、。！？!?\.\s])"#
    )
    private static let questionSheetPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])(?i:question)\s+(?i:sheet)\s+(\#(spokenNumberPattern))(?=$|[，,、。！？!?\.\s])"#
    )
    private static let standaloneExercisePattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])(?i:exercise)\s*(\#(spokenNumberPattern))(?:\s*(\#(subpartListPattern)))?(?=$|[，,、。！？!?\.\s])"#
    )
    private static let standaloneSheetPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])(?i:s?sheet|cheat)\s*(\#(spokenNumberPattern))(?=$|[，,、。！？!?\.\s])"#
    )
    private static let commandCheatSheetPattern = try! NSRegularExpression(
        pattern:
            #"((?:请)?打开\s+)(?i:cheat)\s+(\#(spokenNumberPattern))(?=$|[，,、。！？!?\.\s])"#
    )
    private static let shortQuestionPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])(?i:q)\s*(\#(spokenNumberPattern))(?:\s+(\#(subpartListPattern)))?(?=$|[，,、。！？!?\.\s])"#
    )
    private static let punctuatedBNCQuestionPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])(?i:q)\s*(\#(spokenNumberPattern))[\s，,、。！？!?\.]+(?i:BNC)(?=$|[，,、。！？!?\.\s])"#
    )
    private static let qFourShiBNCPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])(?i:q)[\s，,、。！？!?\.]*(?:四|是)[\s，,、。！？!?\.]*(?i:BNC)(?=$|[，,、。！？!?\.\s])"#
    )
    private static let longQuestionPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])(?i:question)\s+(\#(spokenNumberPattern))(?:\s+(\#(subpartListPattern)))?(?=$|[，,、。！？!?\.\s])"#
    )
    private static let explicitAcademicSubpartPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])((?i:bit)|[A-Za-z])\s*(\#(spokenNumberPattern))\s*(\#(subpartListPattern))(?=$|[，,、。！？!?\.\s])"#
    )
    private static let singleLetterNumberPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])((?i:bit)|[A-Za-z])\s*(\#(spokenNumberPattern))(?=$|[，,、。！？!?\.\s]|\p{Han})"#
    )
    private static let academicSectionNumberPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])([A-DQ])\s*(\#(spokenNumberPattern))(?=$|[，,、。！？!?\.\s])"#
    )
    private static let studySectionNumberPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])((?i:bit)|[A-Za-z])\s*(\#(spokenNumberPattern))(?=(?:要背|要记|需要背|需要记|的内容|内容))"#
    )
    private static let academicSectionNumberContextPattern = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])[A-DQ][0-9]{1,3}(?![A-Za-z0-9])"#
    )
    private static let isolatedAcademicListNumberPattern = try! NSRegularExpression(
        pattern:
            #"(^|[，,、。！？!?\s])(\#(spokenNumberPattern))(?=$|[，,、。！？!?\s])"#
    )
    private static let impliedSectionASubpartPattern = try! NSRegularExpression(
        pattern:
            #"(^|[，,。！？!?\s])(\#(spokenNumberPattern))\s*(\#(subpartListPattern))(?=$|[，,。！？!?\s])"#
    )
    private static let impliedSectionASubpartAfterGivePattern = try! NSRegularExpression(
        pattern:
            #"(给我)讲?(\#(spokenNumberPattern))\s*(\#(subpartListPattern))(?=$|[，,。！？!?\s])"#
    )
    private static let omittedSectionAPattern = try! NSRegularExpression(
        pattern: #"(^|[，,。！？!?\s])部分(?=(?:我)?会了)"#
    )
    private static let sectionAContextPattern = try! NSRegularExpression(
        pattern: #"(^|[，,。！？!?\s])(?:A部分|部分(?=(?:我)?会了))"#
    )

    static func normalize(_ text: String, context: NormalizationContext) -> String {
        let sheetExercisePass = replaceMatches(
            in: text,
            regex: sheetExercisePattern,
            protectedSpans: context.protectedSpans
        ) { match, source in
            guard
                let exerciseText = capture(2, in: match, source: source),
                let exercise = SpokenNumberParser.numberOrEnglishNumber(exerciseText)
            else {
                return nil
            }

            let base: String
            if
                let sheetText = capture(1, in: match, source: source),
                let sheet = academicSheetNumber(sheetText)
            {
                base = "Sheet \(sheet) Exercise \(exercise)"
            } else {
                base = "Sheet Exercise \(exercise)"
            }

            return referenceWithSubparts(
                base: base,
                subpartsText: capture(3, in: match, source: source)
            )
        }

        let exerciseSheetPass = replaceMatches(
            in: sheetExercisePass.text,
            regex: exerciseSheetPattern,
            protectedSpans: sheetExercisePass.protectedSpans
        ) { match, source in
            guard
                let numberText = capture(1, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return referenceWithSubparts(
                base: "Exercise Sheet \(number)",
                subpartsText: capture(2, in: match, source: source)
            )
        }

        let questionSheetPass = replaceMatches(
            in: exerciseSheetPass.text,
            regex: questionSheetPattern,
            protectedSpans: exerciseSheetPass.protectedSpans
        ) { match, source in
            guard
                let numberText = capture(1, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return "Question Sheet \(number)"
        }

        let standaloneExercisePass = replaceMatches(
            in: questionSheetPass.text,
            regex: standaloneExercisePattern,
            protectedSpans: questionSheetPass.protectedSpans
        ) { match, source in
            guard
                let numberText = capture(1, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return referenceWithSubparts(
                base: "Exercise \(number)",
                subpartsText: capture(2, in: match, source: source)
            )
        }

        let commandCheatSheetPass = replaceMatches(
            in: standaloneExercisePass.text,
            regex: commandCheatSheetPattern,
            protectedSpans: standaloneExercisePass.protectedSpans
        ) { match, source in
            guard
                let prefix = capture(1, in: match, source: source),
                let numberText = capture(2, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return "\(prefix)Sheet \(number)"
        }

        let standaloneSheetPass = replaceMatches(
            in: commandCheatSheetPass.text,
            regex: standaloneSheetPattern,
            protectedSpans: commandCheatSheetPass.protectedSpans
        ) { match, source in
            guard
                let numberText = capture(1, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return "Sheet \(number)"
        }

        let qFourShiBNCPass = replaceMatches(
            in: standaloneSheetPass.text,
            regex: qFourShiBNCPattern,
            protectedSpans: standaloneSheetPass.protectedSpans
        ) { _, _ in
            referenceWithSubparts(base: "Q4", subpartsText: "BNC")
        }

        let punctuatedBNCQuestionPass = replaceMatches(
            in: qFourShiBNCPass.text,
            regex: punctuatedBNCQuestionPattern,
            protectedSpans: qFourShiBNCPass.protectedSpans
        ) { match, source in
            guard
                let numberText = capture(1, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return referenceWithSubparts(base: "Q\(number)", subpartsText: "BNC")
        }

        let shortQuestionPass = replaceMatches(
            in: punctuatedBNCQuestionPass.text,
            regex: shortQuestionPattern,
            protectedSpans: punctuatedBNCQuestionPass.protectedSpans
        ) { match, source in
            guard
                let numberText = capture(1, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return referenceWithSubparts(
                base: "Q\(number)",
                subpartsText: capture(2, in: match, source: source)
            )
        }

        let longQuestionPass = replaceMatches(
            in: shortQuestionPass.text,
            regex: longQuestionPattern,
            protectedSpans: shortQuestionPass.protectedSpans
        ) { match, source in
            guard
                let numberText = capture(1, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return referenceWithSubparts(
                base: "Question \(number)",
                subpartsText: capture(2, in: match, source: source)
            )
        }

        let explicitAcademicPass = replaceMatches(
            in: longQuestionPass.text,
            regex: explicitAcademicSubpartPattern,
            protectedSpans: longQuestionPass.protectedSpans
        ) { match, source in
            guard
                let sectionText = capture(1, in: match, source: source),
                let numberText = capture(2, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            let section = canonicalLetter(sectionText)
            return referenceWithSubparts(
                base: "\(section)\(number)",
                subpartsText: capture(3, in: match, source: source)
            )
        }

        let singleLetterNumberPass = replaceMatches(
            in: explicitAcademicPass.text,
            regex: singleLetterNumberPattern,
            protectedSpans: explicitAcademicPass.protectedSpans
        ) { match, source in
            guard
                let letterText = capture(1, in: match, source: source),
                let numberText = capture(2, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            let letter = canonicalLetter(letterText)
            return "\(letter)\(number)"
        }

        let studySectionNumberPass = replaceMatches(
            in: singleLetterNumberPass.text,
            regex: studySectionNumberPattern,
            protectedSpans: singleLetterNumberPass.protectedSpans
        ) { match, source in
            guard
                let sectionText = capture(1, in: match, source: source),
                let numberText = capture(2, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return "\(canonicalLetter(sectionText))\(number)"
        }

        let sectionNumberPass = replaceMatches(
            in: studySectionNumberPass.text,
            regex: academicSectionNumberPattern,
            protectedSpans: studySectionNumberPass.protectedSpans
        ) { match, source in
            guard
                let section = capture(1, in: match, source: source),
                let numberText = capture(2, in: match, source: source),
                let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
            else {
                return nil
            }

            return "\(section.uppercased())\(number)"
        }

        var normalized = sectionNumberPass.text
        var protectedSpans = sectionNumberPass.protectedSpans

        if hasAcademicSectionNumberContext(normalized) {
            let listNumberPass = replaceMatches(
                in: normalized,
                regex: isolatedAcademicListNumberPattern,
                protectedSpans: protectedSpans
            ) { match, source in
                guard
                    let delimiter = capture(1, in: match, source: source),
                    let numberText = capture(2, in: match, source: source),
                    let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
                else {
                    return nil
                }

                return "\(delimiter)\(number)"
            }
            normalized = listNumberPass.text
            protectedSpans = listNumberPass.protectedSpans
        }

        if hasSectionAContext(normalized) {
            let givePass = replaceMatches(
                in: normalized,
                regex: impliedSectionASubpartAfterGivePattern,
                protectedSpans: protectedSpans
            ) { match, source in
                guard
                    let prefix = capture(1, in: match, source: source),
                    let numberText = capture(2, in: match, source: source),
                    let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
                else {
                    return nil
                }

                let reference = referenceWithSubparts(
                    base: "A\(number)",
                    subpartsText: capture(3, in: match, source: source)
                )
                return "\(prefix)\(reference)"
            }
            normalized = givePass.text
            protectedSpans = givePass.protectedSpans

            let impliedSectionPass = replaceMatches(
                in: normalized,
                regex: impliedSectionASubpartPattern,
                protectedSpans: protectedSpans
            ) { match, source in
                guard
                    let delimiter = capture(1, in: match, source: source),
                    let numberText = capture(2, in: match, source: source),
                    let number = SpokenNumberParser.numberOrEnglishNumber(numberText)
                else {
                    return nil
                }

                let reference = referenceWithSubparts(
                    base: "A\(number)",
                    subpartsText: capture(3, in: match, source: source)
                )
                return "\(delimiter)\(reference)"
            }
            normalized = impliedSectionPass.text
            protectedSpans = impliedSectionPass.protectedSpans

            let omittedSectionPass = replaceMatches(
                in: normalized,
                regex: omittedSectionAPattern,
                protectedSpans: protectedSpans
            ) { match, source in
                guard let delimiter = capture(1, in: match, source: source) else {
                    return nil
                }
                return "\(delimiter)A部分"
            }
            normalized = omittedSectionPass.text
        }

        return normalized
    }

    private static func referenceWithSubparts(base: String, subpartsText: String?) -> String {
        guard
            let subpartsText = subpartsText,
            let subparts = parsedSubparts(from: subpartsText),
            let first = subparts.first
        else {
            return base
        }

        let tail = subparts.dropFirst().map { "(\($0))" }.joined(separator: " and ")
        if tail.isEmpty {
            return "\(base)(\(first))"
        }
        return "\(base)(\(first)) and \(tail)"
    }

    private static func academicSheetNumber(_ text: String) -> Int? {
        if text.lowercased() == "e" {
            return 1
        }

        return SpokenNumberParser.numberOrEnglishNumber(text)
    }

    private static func canonicalLetter(_ text: String) -> String {
        if text.lowercased() == "bit" {
            return "B"
        }

        return text.uppercased()
    }

    private static func parsedSubparts(from text: String) -> [String]? {
        if text.lowercased() == "bnc" {
            return ["b", "c"]
        }

        let normalizedAnd = text.replacingOccurrences(
            of: #"\s+(?i:and)\s+"#,
            with: " ",
            options: .regularExpression
        )
        let normalized = normalizedAnd.replacingOccurrences(
            of: #"\s*和\s*"#,
            with: " ",
            options: .regularExpression
        )
        let parts = normalized.split(
            separator: " ",
            omittingEmptySubsequences: true
        )
        var subparts: [String] = []

        for part in parts {
            let token = String(part)
            guard token.count == 1, let scalar = token.unicodeScalars.first, CharacterSet.letters.contains(scalar) else {
                return nil
            }
            subparts.append(token.lowercased())
        }

        return subparts.isEmpty ? nil : subparts
    }

    private static func hasSectionAContext(_ text: String) -> Bool {
        let source = text as NSString
        return sectionAContextPattern.firstMatch(
            in: text,
            range: NSRange(location: 0, length: source.length)
        ) != nil
    }

    private static func hasAcademicSectionNumberContext(_ text: String) -> Bool {
        let source = text as NSString
        return academicSectionNumberContextPattern.firstMatch(
            in: text,
            range: NSRange(location: 0, length: source.length)
        ) != nil
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
            let utf16Index = text.utf16.index(
                text.utf16.startIndex,
                offsetBy: utf16Offset,
                limitedBy: text.utf16.endIndex
            ),
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
