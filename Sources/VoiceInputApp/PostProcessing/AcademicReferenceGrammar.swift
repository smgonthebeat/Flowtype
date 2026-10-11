import Foundation

enum AcademicReferenceGrammar {
    enum TokenKind: Equatable {
        case latinWord
        case asciiIdentifier
        case digits
        case hanNumber
        case hanText
        case whitespace
        case punctuation
        case protected
    }

    struct Token: Equatable {
        let kind: TokenKind
        let text: String
        let range: Range<String.Index>
        let scope: Int
    }

    enum Evidence: Equatable {
        case explicitCompositeHead
        case explicitHead
        case featureEnabledSection
        case localSectionContext
        case impliedSectionAContext
        case academicList
        case omittedSectionAContext
    }

    /// An exercise or question number, optionally dotted (Exercise 1.2, Question 2.3).
    struct ReferenceNumber: Equatable, CustomStringConvertible {
        let major: Int
        var minor: String? = nil

        var description: String {
            minor.map { "\(major).\($0)" } ?? "\(major)"
        }
    }

    enum ReferenceKind: Equatable {
        case sheet(number: Int)
        case sheetExercise(sheet: Int?, exercise: ReferenceNumber)
        case exerciseSheet(number: Int)
        case exercise(number: ReferenceNumber)
        case exerciseQuestion(exercise: ReferenceNumber, question: ReferenceNumber)
        case questionSheet(number: Int)
        case question(number: ReferenceNumber, abbreviated: Bool)
        case section(label: Character, number: Int)
        case sectionWithPrefix(prefix: String, label: Character, number: Int)
        case academicListNumber(Int)
        case omittedSectionAMarker
    }

    struct Node: Equatable {
        let kind: ReferenceKind
        let subparts: [Character]
        let evidence: Evidence
        let sourceRange: Range<String.Index>
        /// The two subparts are the ends of a range (A to D → (a)–(d)).
        var isRange = false
        /// Second-level subpart in lowercase roman numerals (part B two → (b)(ii)).
        var romanSubpart: String? = nil
    }

    struct Match: Equatable {
        let node: Node
        let startToken: Int
        let endToken: Int
        let allowsScopeTransition: Bool
    }

    private struct ParsedNumber {
        let value: Int
        let endToken: Int
        let embeddedSubpart: Character?
        var minor: String? = nil

        var reference: ReferenceNumber { ReferenceNumber(major: value, minor: minor) }
    }

    private struct ParsedSubparts {
        let values: [Character]
        let endToken: Int
        let crossesStrongBoundary: Bool
        var isRange = false
        var romanSubpart: String? = nil
    }

    private enum SubpartParseResult {
        case none
        case parsed(ParsedSubparts)
        case invalid

        var parsed: ParsedSubparts? {
            guard case let .parsed(value) = self else { return nil }
            return value
        }

        var isInvalid: Bool {
            if case .invalid = self { return true }
            return false
        }
    }

    private struct ScopeContext {
        let hasSectionAContext: Bool
        let hasOmittedSectionAContext: Bool
    }

    private static let hanNumberCharacters = Set("零〇一二三四五六七八九十百两")
    private static let strongSentenceTerminators = Set("。.!?！？")
    private static let romanNumerals = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x"]
    /// Words that may follow a bare second-level number (Q3 part B two is hard). Anything else,
    /// such as a unit (B two marks), keeps the number out of the reference.
    private static let romanBoundaryWords: Set<String> = [
        "and", "or", "is", "was", "are", "were", "then", "please", "first", "next", "now", "too", "also", "again"
    ]

    static func normalize(_ text: String, context: NormalizationContext = NormalizationContext()) -> String {
        let nodes = recognize(in: text, context: context)
        guard !nodes.isEmpty else { return text }

        var result = text
        for node in nodes.sorted(by: { $0.sourceRange.lowerBound > $1.sourceRange.lowerBound }) {
            result.replaceSubrange(node.sourceRange, with: render(node))
        }
        return result
    }

    static func recognize(in text: String, context: NormalizationContext = NormalizationContext()) -> [Node] {
        let tokens = scan(text, protectedSpans: context.protectedSpans)
        guard !tokens.isEmpty else { return [] }

        let scopeContexts = makeScopeContexts(tokens: tokens)
        var matches: [Match] = []
        var tokenIndex = 0

        while tokenIndex < tokens.count {
            if tokens[tokenIndex].kind == .protected {
                tokenIndex += 1
                continue
            }

            let scopeContext = scopeContexts[tokens[tokenIndex].scope] ?? ScopeContext(
                hasSectionAContext: false,
                hasOmittedSectionAContext: false
            )

            let candidate =
                parseSheet(at: tokenIndex, tokens: tokens)
                ?? parseExercise(at: tokenIndex, tokens: tokens)
                ?? parseQuestion(at: tokenIndex, tokens: tokens)
                ?? parseImpliedSectionA(
                    at: tokenIndex,
                    tokens: tokens,
                    scopeContext: scopeContext
                )
                ?? parseSection(
                    at: tokenIndex,
                    tokens: tokens,
                    scopeContext: scopeContext
                )

            if let candidate {
                matches.append(candidate)
                tokenIndex = candidate.endToken
            } else {
                tokenIndex += 1
            }
        }

        matches.append(contentsOf: omittedSectionAMarkerMatches(
            in: text,
            tokens: tokens,
            scopeContexts: scopeContexts,
            existingMatches: matches
        ))
        matches.append(contentsOf: academicListNumberMatches(
            tokens: tokens,
            existingMatches: matches
        ))

        return selectNonOverlapping(matches).map(\.node)
    }

    static func scan(_ text: String, protectedSpans: [ProtectedSpan] = []) -> [Token] {
        let sortedProtectedSpans = protectedSpans.sorted { $0.range.lowerBound < $1.range.lowerBound }
        var protectedIndex = 0
        var tokens: [Token] = []
        var index = text.startIndex
        var scope = 0

        while index < text.endIndex {
            while protectedIndex < sortedProtectedSpans.count,
                  sortedProtectedSpans[protectedIndex].range.upperBound <= index {
                protectedIndex += 1
            }

            if protectedIndex < sortedProtectedSpans.count {
                let protectedSpan = sortedProtectedSpans[protectedIndex]
                if protectedSpan.range.lowerBound <= index {
                    let protectedRange = index..<protectedSpan.range.upperBound
                    let protectedText = String(text[protectedRange])
                    tokens.append(Token(
                        kind: .protected,
                        text: protectedText,
                        range: protectedRange,
                        scope: scope
                    ))
                    index = protectedSpan.range.upperBound
                    protectedIndex += 1
                    if protectedText.contains(where: \Character.isNewline) ||
                        protectedText.contains(where: { strongSentenceTerminators.contains($0) }) {
                        scope += 1
                    }
                    continue
                }
            }

            let start = index
            let scanLimit = protectedIndex < sortedProtectedSpans.count
                ? sortedProtectedSpans[protectedIndex].range.lowerBound
                : text.endIndex
            let character = text[index]
            let kind: TokenKind

            if isWhitespace(character) {
                index = advance(in: text, from: index, upTo: scanLimit) { isWhitespace($0) }
                kind = .whitespace
            } else if isASCIIWordStart(character) {
                index = advance(in: text, from: index, upTo: scanLimit) {
                    isASCIIWordContinuation($0)
                }
                let tokenText = String(text[start..<index])
                if tokenText.allSatisfy({ $0.isNumber }) {
                    kind = .digits
                } else if tokenText.contains(where: { $0.isNumber }) {
                    kind = .asciiIdentifier
                } else {
                    kind = .latinWord
                }
            } else if isHanNumber(character) {
                index = advance(in: text, from: index, upTo: scanLimit) { isHanNumber($0) }
                kind = .hanNumber
            } else if isHan(character) {
                index = advance(in: text, from: index, upTo: scanLimit) {
                    isHan($0) && !isHanNumber($0)
                }
                kind = .hanText
            } else {
                index = text.index(after: index)
                kind = .punctuation
            }

            let range = start..<index
            let tokenText = String(text[range])
            tokens.append(Token(kind: kind, text: tokenText, range: range, scope: scope))

            if kind == .whitespace, tokenText.contains(where: \Character.isNewline) {
                scope += 1
            } else if kind == .punctuation,
                      tokenText.contains(where: { strongSentenceTerminators.contains($0) }),
                      !isDecimalDot(tokenText, at: range, in: text) {
                scope += 1
            }
        }

        return tokens
    }

    private static func parseSheet(at start: Int, tokens: [Token]) -> Match? {
        guard isSheetHead(tokens[safe: start]) else { return nil }
        guard !hasWhitespaceSeparatedCompositeOwner(
            before: start,
            expected: "exercise",
            tokens: tokens
        ) else {
            return nil
        }

        let afterHead = start + 1
        let numberStart = skipWhitespace(from: afterHead, tokens: tokens)
        let sheetNumber = parseNumber(at: numberStart, tokens: tokens, allowSheetE: true)
        let exerciseSearchStart = sheetNumber?.endToken ?? afterHead
        let exerciseIndex = skipAcademicLinker(from: exerciseSearchStart, tokens: tokens)

        if isWord(tokens[safe: exerciseIndex], equalTo: "exercise") {
            let exerciseNumberStart = skipLocalPunctuationSeparators(
                from: exerciseIndex + 1,
                tokens: tokens
            )
            let exerciseNumber: ParsedNumber
            let crossesStrongBoundary: Bool
            if let directNumber = parseNumber(
                at: exerciseNumberStart,
                tokens: tokens,
                allowEmbeddedSubpart: true,
                allowDotted: true
            ) {
                exerciseNumber = directNumber
                crossesStrongBoundary = false
            } else if let segmentedNumberStart = segmentedTokenIndex(
                after: exerciseIndex + 1,
                sourceScope: tokens[exerciseIndex].scope,
                tokens: tokens
            ), tokens[segmentedNumberStart].scope == tokens[exerciseIndex].scope + 1,
               let segmentedNumber = parseNumber(
                   at: segmentedNumberStart,
                   tokens: tokens,
                   allowEmbeddedSubpart: true,
                   allowDotted: true
               ) {
                exerciseNumber = segmentedNumber
                crossesStrongBoundary = true
            } else {
                return nil
            }

            let subpartResult = parseSubparts(
                after: exerciseNumber.endToken,
                tokens: tokens,
                initial: exerciseNumber.embeddedSubpart.map { [$0] } ?? [],
                allowSingle: true,
                allowPunctuatedBNC: false
            )
            guard !subpartResult.isInvalid else { return nil }
            let subparts = subpartResult.parsed
            let end = subparts?.endToken ?? exerciseNumber.endToken
            return makeMatch(
                start: start,
                end: end,
                tokens: tokens,
                kind: .sheetExercise(
                    sheet: sheetNumber?.value,
                    exercise: exerciseNumber.reference
                ),
                subparts: subparts?.values ?? exerciseNumber.embeddedSubpart.map { [$0] } ?? [],
                parsedSubparts: subparts,
                evidence: .explicitCompositeHead,
                allowScopeTransition: crossesStrongBoundary
            )
        }

        guard let sheetNumber else { return nil }
        return makeMatch(
            start: start,
            end: sheetNumber.endToken,
            tokens: tokens,
            kind: .sheet(number: sheetNumber.value),
            evidence: .explicitHead
        )
    }

    private static func parseExercise(at start: Int, tokens: [Token]) -> Match? {
        guard isWord(tokens[safe: start], equalTo: "exercise") else { return nil }

        let afterHead = skipRequiredWhitespace(from: start + 1, tokens: tokens)
        if isSheetHead(tokens[safe: afterHead]) {
            let numberStart = skipRequiredWhitespace(from: afterHead + 1, tokens: tokens)
            guard let number = parseNumber(
                at: numberStart,
                tokens: tokens,
                allowEmbeddedSubpart: true
            ) else {
                return nil
            }
            let subpartResult = parseSubparts(
                after: number.endToken,
                tokens: tokens,
                initial: number.embeddedSubpart.map { [$0] } ?? [],
                allowSingle: true,
                allowPunctuatedBNC: false
            )
            guard !subpartResult.isInvalid else { return nil }
            let subparts = subpartResult.parsed
            return makeMatch(
                start: start,
                end: subparts?.endToken ?? number.endToken,
                tokens: tokens,
                kind: .exerciseSheet(number: number.value),
                subparts: subparts?.values ?? number.embeddedSubpart.map { [$0] } ?? [],
                parsedSubparts: subparts,
                evidence: .explicitCompositeHead
            )
        }

        let numberStart = skipWhitespace(from: start + 1, tokens: tokens)
        guard let exerciseNumber = parseNumber(
            at: numberStart,
            tokens: tokens,
            allowEmbeddedSubpart: true,
            allowDotted: true
        ) else {
            return nil
        }

        let questionIndex = skipWhitespace(from: exerciseNumber.endToken, tokens: tokens)
        if isQuestionHead(tokens[safe: questionIndex]) {
            guard let question = parseQuestion(at: questionIndex, tokens: tokens) else {
                return nil
            }
            guard case let .question(number, _) = question.node.kind else { return nil }
            return makeMatch(
                start: start,
                end: question.endToken,
                tokens: tokens,
                kind: .exerciseQuestion(exercise: exerciseNumber.reference, question: number),
                subparts: question.node.subparts,
                isRange: question.node.isRange,
                romanSubpart: question.node.romanSubpart,
                evidence: .explicitCompositeHead,
                allowScopeTransition: question.allowsScopeTransition
            )
        }

        let subpartResult = parseSubparts(
            after: exerciseNumber.endToken,
            tokens: tokens,
            initial: exerciseNumber.embeddedSubpart.map { [$0] } ?? [],
            allowSingle: true,
            allowPunctuatedBNC: false
        )
        guard !subpartResult.isInvalid else { return nil }
        let subparts = subpartResult.parsed
        let end = subparts?.endToken ?? exerciseNumber.endToken
        return makeMatch(
            start: start,
            end: end,
            tokens: tokens,
            kind: .exercise(number: exerciseNumber.reference),
            subparts: subparts?.values ?? exerciseNumber.embeddedSubpart.map { [$0] } ?? [],
            parsedSubparts: subparts,
            evidence: .explicitHead
        )
    }

    private static func parseQuestion(at start: Int, tokens: [Token]) -> Match? {
        guard let token = tokens[safe: start], token.kind != .protected else { return nil }

        if let compactQuestion = parseCompactQuestion(token.text) {
            let dotted = dottedMinor(after: start + 1, tokens: tokens)
            let numberEnd = dotted?.endToken ?? start + 1
            let subpartResult = parseSubparts(
                after: numberEnd,
                tokens: tokens,
                initial: dotted?.embeddedSubpart.map { [$0] } ?? [],
                allowSingle: true,
                allowPunctuatedBNC: true
            )
            guard !subpartResult.isInvalid else { return nil }
            let subparts = subpartResult.parsed
            return makeMatch(
                start: start,
                end: subparts?.endToken ?? numberEnd,
                tokens: tokens,
                kind: .question(
                    number: ReferenceNumber(major: compactQuestion, minor: dotted?.minor),
                    abbreviated: true
                ),
                subparts: subparts?.values ?? dotted?.embeddedSubpart.map { [$0] } ?? [],
                parsedSubparts: subparts,
                evidence: .explicitHead,
                allowScopeTransition: subparts?.crossesStrongBoundary ?? false
            )
        }

        let isShort = isWord(token, equalTo: "q")
        let isLong = isWord(token, equalTo: "question")
        guard isShort || isLong else { return nil }

        if isShort, let segmentedRepair = parseSegmentedQFourBNC(at: start, tokens: tokens) {
            return segmentedRepair
        }

        let afterHead = isLong
            ? skipRequiredWhitespace(from: start + 1, tokens: tokens)
            : skipWhitespace(from: start + 1, tokens: tokens)
        if isLong, isSheetHead(tokens[safe: afterHead]) {
            let numberStart = skipRequiredWhitespace(from: afterHead + 1, tokens: tokens)
            guard let number = parseNumber(at: numberStart, tokens: tokens) else { return nil }
            return makeMatch(
                start: start,
                end: number.endToken,
                tokens: tokens,
                kind: .questionSheet(number: number.value),
                evidence: .explicitCompositeHead
            )
        }

        let numberStart = isLong
            ? skipRequiredWhitespace(from: start + 1, tokens: tokens)
            : skipWhitespace(from: start + 1, tokens: tokens)

        let parsedNumber: ParsedNumber
        if let number = parseNumber(
            at: numberStart,
            tokens: tokens,
            allowEmbeddedSubpart: true,
            allowDotted: true
        ) {
            parsedNumber = number
        } else {
            return nil
        }

        let subpartResult = parseSubparts(
            after: parsedNumber.endToken,
            tokens: tokens,
            initial: parsedNumber.embeddedSubpart.map { [$0] } ?? [],
            allowSingle: true,
            allowPunctuatedBNC: isShort
        )
        guard !subpartResult.isInvalid else { return nil }
        let subparts = subpartResult.parsed
        return makeMatch(
            start: start,
            end: subparts?.endToken ?? parsedNumber.endToken,
            tokens: tokens,
            kind: .question(number: parsedNumber.reference, abbreviated: isShort),
            subparts: subparts?.values ?? parsedNumber.embeddedSubpart.map { [$0] } ?? [],
            parsedSubparts: subparts,
            evidence: .explicitHead,
            allowScopeTransition: subparts?.crossesStrongBoundary ?? false
        )
    }

    private static func parseSegmentedQFourBNC(at start: Int, tokens: [Token]) -> Match? {
        guard let head = tokens[safe: start], isWord(head, equalTo: "q") else { return nil }
        guard let shiIndex = segmentedTokenIndex(
            after: start + 1,
            sourceScope: head.scope,
            tokens: tokens
        ), isHanText(tokens[safe: shiIndex], equalTo: "是") else {
            return nil
        }
        guard let bncIndex = nextBNCIndex(after: shiIndex + 1, tokens: tokens) else {
            return nil
        }

        let crossesStrongBoundary = tokens[shiIndex].scope != head.scope
        return makeMatch(
            start: start,
            end: bncIndex + 1,
            tokens: tokens,
            kind: .question(number: ReferenceNumber(major: 4), abbreviated: true),
            subparts: ["b", "c"],
            evidence: .explicitHead,
            allowScopeTransition: crossesStrongBoundary
        )
    }

    private static func parseSection(
        at start: Int,
        tokens: [Token],
        scopeContext: ScopeContext
    ) -> Match? {
        guard let token = tokens[safe: start], token.kind != .protected else { return nil }

        let label: Character
        let number: ParsedNumber

        if let compact = parseCompactSection(token.text) {
            label = compact.label
            number = ParsedNumber(value: compact.number, endToken: start + 1, embeddedSubpart: nil)
        } else if let parsedLabel = parseSectionLabel(token) {
            label = parsedLabel
            let numberStart = skipWhitespace(from: start + 1, tokens: tokens)
            guard let parsedNumber = parseNumber(at: numberStart, tokens: tokens) else { return nil }
            number = parsedNumber
        } else {
            return nil
        }

        let subpartResult = parseSubparts(
            after: number.endToken,
            tokens: tokens,
            allowSingle: scopeContext.hasSectionAContext && label == "A",
            allowPunctuatedBNC: false
        )
        guard !subpartResult.isInvalid else { return nil }
        let subparts = subpartResult.parsed

        if subparts == nil, hasSpokenIdentifierLetterContinuation(after: number.endToken, tokens: tokens) {
            return nil
        }

        return makeMatch(
            start: start,
            end: subparts?.endToken ?? number.endToken,
            tokens: tokens,
            kind: .section(label: label, number: number.value),
            subparts: subparts?.values ?? [],
            parsedSubparts: subparts,
            evidence: subparts == nil ? .featureEnabledSection : .localSectionContext
        )
    }

    private static func parseImpliedSectionA(
        at start: Int,
        tokens: [Token],
        scopeContext: ScopeContext
    ) -> Match? {
        guard scopeContext.hasSectionAContext else { return nil }
        guard let number = parseNumber(at: start, tokens: tokens) else { return nil }
        let subpartResult = parseSubparts(
            after: number.endToken,
            tokens: tokens,
            allowSingle: true,
            allowPunctuatedBNC: false
        )
        guard case let .parsed(subparts) = subpartResult else {
            return nil
        }

        if let previous = tokens[safe: start - 1],
           previous.kind == .hanText,
           previous.range.upperBound == tokens[start].range.lowerBound,
           previous.text.hasSuffix("给我讲") {
            return makeMatch(
                start: start - 1,
                end: subparts.endToken,
                tokens: tokens,
                kind: .sectionWithPrefix(
                    prefix: String(previous.text.dropLast()),
                    label: "A",
                    number: number.value
                ),
                subparts: subparts.values,
                parsedSubparts: subparts,
                evidence: .impliedSectionAContext
            )
        }

        return makeMatch(
            start: start,
            end: subparts.endToken,
            tokens: tokens,
            kind: .section(label: "A", number: number.value),
            subparts: subparts.values,
            parsedSubparts: subparts,
            evidence: .impliedSectionAContext
        )
    }

    private static func parseNumber(
        at start: Int,
        tokens: [Token],
        allowSheetE: Bool = false,
        allowEmbeddedSubpart: Bool = false,
        allowDotted: Bool = false
    ) -> ParsedNumber? {
        guard let number = parseWholeNumber(
            at: start,
            tokens: tokens,
            allowSheetE: allowSheetE,
            allowEmbeddedSubpart: allowEmbeddedSubpart
        ) else {
            return nil
        }
        guard allowDotted, number.embeddedSubpart == nil,
              let dotted = dottedMinor(after: number.endToken, tokens: tokens) else {
            return number
        }
        return ParsedNumber(
            value: number.value,
            endToken: dotted.endToken,
            embeddedSubpart: dotted.embeddedSubpart,
            minor: dotted.minor
        )
    }

    /// `1.2`, `1.2b` (no spaces around the dot) or spoken `one point two` after a number.
    private static func dottedMinor(
        after end: Int,
        tokens: [Token]
    ) -> (minor: String, endToken: Int, embeddedSubpart: Character?)? {
        if let dot = tokens[safe: end], dot.kind == .punctuation, dot.text == ".",
           let previous = tokens[safe: end - 1], previous.range.upperBound == dot.range.lowerBound,
           let next = tokens[safe: end + 1], dot.range.upperBound == next.range.lowerBound {
            if next.kind == .digits {
                return (next.text, end + 2, nil)
            }
            if let compact = parseCompactNumberSubpart(next.text) {
                return (String(compact.number), end + 2, compact.subpart)
            }
            return nil
        }

        let pointIndex = skipWhitespace(from: end, tokens: tokens)
        guard pointIndex > end, isWord(tokens[safe: pointIndex], equalTo: "point") else { return nil }
        let minorIndex = skipWhitespace(from: pointIndex + 1, tokens: tokens)
        guard minorIndex > pointIndex + 1,
              let token = tokens[safe: minorIndex],
              token.kind == .latinWord || token.kind == .digits,
              let minor = SpokenNumberParser.numberOrEnglishNumber(token.text),
              (0...99).contains(minor)
        else {
            return nil
        }
        return (String(minor), minorIndex + 1, nil)
    }

    private static func parseWholeNumber(
        at start: Int,
        tokens: [Token],
        allowSheetE: Bool,
        allowEmbeddedSubpart: Bool
    ) -> ParsedNumber? {
        guard let token = tokens[safe: start], token.kind != .protected else { return nil }

        if allowSheetE, isWord(token, equalTo: "e") {
            return ParsedNumber(value: 1, endToken: start + 1, embeddedSubpart: nil)
        }

        if allowEmbeddedSubpart,
           let compact = parseCompactNumberSubpart(token.text) {
            return ParsedNumber(
                value: compact.number,
                endToken: start + 1,
                embeddedSubpart: compact.subpart
            )
        }

        if let value = SpokenNumberParser.numberOrEnglishNumber(token.text) {
            if let compoundEnd = nextWordToken(after: start + 1, tokens: tokens) {
                let compound = "\(token.text) \(tokens[compoundEnd].text)"
                if let compoundValue = SpokenNumberParser.numberOrEnglishNumber(compound) {
                    return ParsedNumber(
                        value: compoundValue,
                        endToken: compoundEnd + 1,
                        embeddedSubpart: nil
                    )
                }
            }
            return ParsedNumber(value: value, endToken: start + 1, embeddedSubpart: nil)
        }

        return nil
    }

    private static func parseSubparts(
        after start: Int,
        tokens: [Token],
        initial: [Character] = [],
        allowSingle: Bool,
        allowPunctuatedBNC: Bool
    ) -> SubpartParseResult {
        var values = initial
        var end = start
        var hasPartMarker = false
        var isRange = false

        if values.isEmpty {
            let bncStart = allowPunctuatedBNC
                ? skipLocalPunctuationSeparators(from: start, tokens: tokens)
                : skipWhitespace(from: start, tokens: tokens)
            if isWord(tokens[safe: bncStart], equalTo: "bnc") {
                return .parsed(ParsedSubparts(
                    values: ["b", "c"],
                    endToken: bncStart + 1,
                    crossesStrongBoundary: false
                ))
            }
            if allowPunctuatedBNC,
               let segmentedBNC = segmentedBNCIndex(after: start, tokens: tokens) {
                return .parsed(ParsedSubparts(
                    values: ["b", "c"],
                    endToken: segmentedBNC + 1,
                    crossesStrongBoundary: true
                ))
            }

            var firstIndex = skipWhitespace(from: start, tokens: tokens)
            // "Question 5 part A": the word part marks the letter as a subpart.
            if isWord(tokens[safe: firstIndex], equalTo: "part") {
                let letterIndex = skipWhitespace(from: firstIndex + 1, tokens: tokens)
                if letterIndex > firstIndex + 1, parseSubpartLetter(tokens[safe: letterIndex]) != nil {
                    firstIndex = letterIndex
                    hasPartMarker = true
                }
            }
            guard let first = parseSubpartLetter(tokens[safe: firstIndex]) else { return .none }
            values.append(first)
            end = firstIndex + 1
        }

        while true {
            let joinerIndex = skipWhitespace(from: end, tokens: tokens)
            // "Q4 A to D": an ascending pair joined by to/through/到 is a range of subparts.
            if values.count == 1, isSubpartRangeJoiner(tokens[safe: joinerIndex]) {
                let nextIndex = skipWhitespace(from: joinerIndex + 1, tokens: tokens)
                if let next = parseSubpartLetter(tokens[safe: nextIndex]) {
                    guard next > values[0] else { return .invalid }
                    values.append(next)
                    end = nextIndex + 1
                    isRange = true
                } else if isSingleASCIILetterToken(tokens[safe: nextIndex]) {
                    return .invalid
                }
                break
            }
            guard isSubpartJoiner(tokens[safe: joinerIndex]) else { break }

            let nextIndex = skipWhitespace(from: joinerIndex + 1, tokens: tokens)
            guard let next = parseSubpartLetter(tokens[safe: nextIndex]) else {
                if isSingleASCIILetterToken(tokens[safe: nextIndex]) {
                    return .invalid
                }
                if initial.isEmpty, values.count == 1 {
                    return .none
                }
                break
            }

            values.append(next)
            end = nextIndex + 1
        }

        guard !initial.isEmpty || allowSingle || hasPartMarker || values.count > 1 else { return .none }

        var romanSubpart: String?
        if values.count == 1, let roman = parseRomanSubpart(after: end, tokens: tokens) {
            romanSubpart = roman.value
            end = roman.endToken
        }
        return .parsed(ParsedSubparts(
            values: values,
            endToken: end,
            crossesStrongBoundary: false,
            isRange: isRange,
            romanSubpart: romanSubpart
        ))
    }

    /// Second-level subpart after a single letter: "B roman two", "B, Romance 2" (an ASR
    /// mishearing of roman), "B ii", or a bare "B two" when the reference ends there.
    private static func parseRomanSubpart(after start: Int, tokens: [Token]) -> (value: String, endToken: Int)? {
        var index = skipWhitespace(from: start, tokens: tokens)
        var probe = index
        if let comma = tokens[safe: probe], comma.kind == .punctuation, comma.text == "," || comma.text == "，" {
            probe = skipWhitespace(from: probe + 1, tokens: tokens)
        }
        let isExplicit = isWord(tokens[safe: probe], equalTo: "roman") || isWord(tokens[safe: probe], equalTo: "romance")
        if isExplicit {
            let numeralIndex = skipWhitespace(from: probe + 1, tokens: tokens)
            guard numeralIndex > probe + 1 else { return nil }
            index = numeralIndex
        } else if index == start {
            return nil
        }
        guard let token = tokens[safe: index], token.kind == .latinWord || token.kind == .digits else { return nil }

        let lower = token.text.lowercased()
        if romanNumerals.contains(lower), token.kind == .latinWord {
            // A bare single letter (I, V, X) is too ambiguous without the word roman.
            guard isExplicit || lower.count > 1 else { return nil }
            return (lower, index + 1)
        }
        guard let value = SpokenNumberParser.numberOrEnglishNumber(token.text),
              (1...romanNumerals.count).contains(value) else {
            return nil
        }
        if !isExplicit {
            let nextIndex = skipWhitespace(from: index + 1, tokens: tokens)
            if let next = tokens[safe: nextIndex] {
                let endsReference = next.kind == .punctuation || next.kind == .hanText ||
                    (next.kind == .latinWord && romanBoundaryWords.contains(next.text.lowercased()))
                guard endsReference else { return nil }
            }
        }
        return (romanNumerals[value - 1], index + 1)
    }

    private static func academicListNumberMatches(
        tokens: [Token],
        existingMatches: [Match]
    ) -> [Match] {
        let enablingScopes = Set(existingMatches.compactMap { match -> Int? in
            switch match.node.kind {
            case let .section(label, _):
                return ["A", "B", "C", "D", "Q"].contains(label) ? tokens[match.startToken].scope : nil
            case let .question(_, abbreviated):
                return abbreviated ? tokens[match.startToken].scope : nil
            default:
                return nil
            }
        })

        guard !enablingScopes.isEmpty else { return [] }
        var matches: [Match] = []
        var index = 0

        while index < tokens.count {
            guard enablingScopes.contains(tokens[index].scope),
                  !tokenIsCovered(index, by: existingMatches),
                  isDelimitedNumberStart(index, tokens: tokens),
                  let number = parseNumber(at: index, tokens: tokens),
                  isDelimitedNumberEnd(number.endToken, tokens: tokens)
            else {
                index += 1
                continue
            }

            if let match = makeMatch(
                start: index,
                end: number.endToken,
                tokens: tokens,
                kind: .academicListNumber(number.value),
                evidence: .academicList
            ) {
                matches.append(match)
            }
            index = number.endToken
        }
        return matches
    }

    private static func omittedSectionAMarkerMatches(
        in text: String,
        tokens: [Token],
        scopeContexts: [Int: ScopeContext],
        existingMatches: [Match]
    ) -> [Match] {
        var matches: [Match] = []
        for (index, token) in tokens.enumerated() {
            guard token.kind == .hanText,
                  scopeContexts[token.scope]?.hasOmittedSectionAContext == true,
                  isBoundedOmittedSectionAToken(at: index, tokens: tokens)
            else {
                continue
            }

            let markerEnd = text.index(token.range.lowerBound, offsetBy: 2)
            let markerRange = token.range.lowerBound..<markerEnd
            guard
                  !existingMatches.contains(where: { rangesOverlap($0.node.sourceRange, markerRange) })
            else {
                continue
            }

            matches.append(Match(
                node: Node(
                    kind: .omittedSectionAMarker,
                    subparts: [],
                    evidence: .omittedSectionAContext,
                    sourceRange: markerRange
                ),
                startToken: index,
                endToken: index + 1,
                allowsScopeTransition: false
            ))
        }
        return matches
    }

    private static func makeScopeContexts(tokens: [Token]) -> [Int: ScopeContext] {
        var explicitScopes = Set<Int>()
        var omittedScopes = Set<Int>()

        for index in tokens.indices {
            if isExplicitSectionAContext(at: index, tokens: tokens) {
                explicitScopes.insert(tokens[index].scope)
            }
            if isBoundedOmittedSectionAToken(at: index, tokens: tokens) {
                omittedScopes.insert(tokens[index].scope)
            }
        }

        var contexts: [Int: ScopeContext] = [:]
        for scope in Set(tokens.map(\.scope)) {
            let hasExplicit = explicitScopes.contains(scope)
            let hasOmitted = omittedScopes.contains(scope)
            contexts[scope] = ScopeContext(
                hasSectionAContext: hasExplicit || hasOmitted,
                hasOmittedSectionAContext: !hasExplicit && hasOmitted
            )
        }
        return contexts
    }

    private static func isExplicitSectionAContext(at index: Int, tokens: [Token]) -> Bool {
        guard isWord(tokens[safe: index], equalTo: "a"),
              let suffix = tokens[safe: index + 1],
              suffix.kind == .hanText,
              suffix.text.hasPrefix("部分"),
              tokens[index].scope == suffix.scope,
              tokens[index].range.upperBound == suffix.range.lowerBound
        else {
            return false
        }
        return true
    }

    private static func isBoundedOmittedSectionAToken(at index: Int, tokens: [Token]) -> Bool {
        guard let token = tokens[safe: index],
              token.kind == .hanText,
              token.text.hasPrefix("部分我会了") || token.text.hasPrefix("部分会了")
        else {
            return false
        }

        guard let previous = tokens[safe: index - 1] else { return true }
        return previous.scope != token.scope ||
            previous.kind == .whitespace ||
            previous.kind == .punctuation
    }

    private static func selectNonOverlapping(_ matches: [Match]) -> [Match] {
        let sorted = matches.sorted {
            if $0.node.sourceRange.lowerBound != $1.node.sourceRange.lowerBound {
                return $0.node.sourceRange.lowerBound < $1.node.sourceRange.lowerBound
            }
            return $0.node.sourceRange.upperBound > $1.node.sourceRange.upperBound
        }
        var selected: [Match] = []
        for candidate in sorted {
            guard selected.allSatisfy({ !rangesOverlap($0.node.sourceRange, candidate.node.sourceRange) }) else {
                continue
            }
            selected.append(candidate)
        }
        return selected
    }

    private static func render(_ node: Node) -> String {
        let base: String
        switch node.kind {
        case let .sheet(number):
            base = "Sheet \(number)"
        case let .sheetExercise(sheet, exercise):
            if let sheet {
                base = "Sheet \(sheet) Exercise \(exercise)"
            } else {
                base = "Sheet Exercise \(exercise)"
            }
        case let .exerciseSheet(number):
            base = "Exercise Sheet \(number)"
        case let .exercise(number):
            base = "Exercise \(number)"
        case let .exerciseQuestion(exercise, question):
            base = "Exercise \(exercise) Q\(question)"
        case let .questionSheet(number):
            base = "Question Sheet \(number)"
        case let .question(number, abbreviated):
            base = abbreviated ? "Q\(number)" : "Question \(number)"
        case let .section(label, number):
            base = "\(label)\(number)"
        case let .sectionWithPrefix(prefix, label, number):
            base = "\(prefix)\(label)\(number)"
        case let .academicListNumber(number):
            base = "\(number)"
        case .omittedSectionAMarker:
            base = "A部分"
        }

        guard let first = node.subparts.first else { return base }
        let roman = node.romanSubpart.map { "(\($0))" } ?? ""
        if node.isRange, let last = node.subparts.last {
            return "\(base)(\(first))–(\(last))"
        }
        let remaining = node.subparts.dropFirst().map { "(\($0))" }.joined(separator: " and ")
        if remaining.isEmpty {
            return "\(base)(\(first))\(roman)"
        }
        return "\(base)(\(first)) and \(remaining)"
    }

    private static func makeMatch(
        start: Int,
        end: Int,
        tokens: [Token],
        kind: ReferenceKind,
        subparts: [Character] = [],
        parsedSubparts: ParsedSubparts? = nil,
        isRange: Bool = false,
        romanSubpart: String? = nil,
        evidence: Evidence,
        allowScopeTransition: Bool = false
    ) -> Match? {
        guard start >= 0, end > start, end <= tokens.count else { return nil }
        let matchedTokens = tokens[start..<end]
        let matchedScopes = Set(matchedTokens.map(\.scope))
        if allowScopeTransition {
            guard matchedScopes.count <= 2,
                  let firstScope = matchedScopes.min(),
                  let lastScope = matchedScopes.max(),
                  lastScope - firstScope <= 1
            else {
                return nil
            }
        } else {
            guard matchedScopes.count == 1 else { return nil }
        }
        let range = tokens[start].range.lowerBound..<tokens[end - 1].range.upperBound
        guard !matchedTokens.contains(where: { $0.kind == .protected }) else { return nil }
        return Match(
            node: Node(
                kind: kind,
                subparts: subparts,
                evidence: evidence,
                sourceRange: range,
                isRange: parsedSubparts?.isRange ?? isRange,
                romanSubpart: parsedSubparts?.romanSubpart ?? romanSubpart
            ),
            startToken: start,
            endToken: end,
            allowsScopeTransition: allowScopeTransition
        )
    }

    private static func parseCompactQuestion(_ text: String) -> Int? {
        let characters = Array(text)
        guard characters.count >= 2, characters[0].lowercased() == "q" else { return nil }
        let digits = String(characters.dropFirst())
        guard digits.allSatisfy(\.isNumber) else { return nil }
        return Int(digits)
    }

    private static func parseCompactSection(_ text: String) -> (label: Character, number: Int)? {
        let characters = Array(text)
        guard characters.count >= 2,
              characters[0].isLetter,
              characters[0].isASCII,
              characters.dropFirst().allSatisfy(\.isNumber),
              let number = Int(String(characters.dropFirst()))
        else {
            return nil
        }
        return (Character(characters[0].uppercased()), number)
    }

    private static func parseCompactNumberSubpart(_ text: String) -> (number: Int, subpart: Character)? {
        let characters = Array(text)
        guard characters.count >= 2,
              let last = characters.last,
              let subpart = validatedSubpart(last),
              characters.dropLast().allSatisfy(\.isNumber),
              let number = Int(String(characters.dropLast()))
        else {
            return nil
        }
        return (number, subpart)
    }

    private static func parseSectionLabel(_ token: Token) -> Character? {
        if token.text.lowercased() == "bit" {
            return "B"
        }
        let characters = Array(token.text)
        guard characters.count == 1,
              let character = characters.first,
              character.isASCII,
              character.isLetter
        else {
            return nil
        }
        return Character(character.uppercased())
    }

    private static func parseSubpartLetter(_ token: Token?) -> Character? {
        guard let token else { return nil }
        let characters = Array(token.text)
        guard characters.count == 1, let character = characters.first else { return nil }
        return validatedSubpart(character)
    }

    private static func validatedSubpart(_ character: Character) -> Character? {
        let lower = Character(character.lowercased())
        return ("a"..."h").contains(lower) ? lower : nil
    }

    private static func nextBNCIndex(after start: Int, tokens: [Token]) -> Int? {
        let index = skipLocalPunctuationSeparators(from: start, tokens: tokens)
        return isWord(tokens[safe: index], equalTo: "bnc") ? index : nil
    }

    private static func segmentedBNCIndex(after start: Int, tokens: [Token]) -> Int? {
        guard let precedingToken = tokens[safe: start - 1] else { return nil }
        guard let candidateIndex = segmentedTokenIndex(
            after: start,
            sourceScope: precedingToken.scope,
            tokens: tokens
        ), tokens[candidateIndex].scope == precedingToken.scope + 1,
           isWord(tokens[candidateIndex], equalTo: "bnc")
        else {
            return nil
        }
        return candidateIndex
    }

    private static func segmentedTokenIndex(
        after start: Int,
        sourceScope: Int,
        tokens: [Token]
    ) -> Int? {
        var index = start
        while index < tokens.count {
            let token = tokens[index]
            guard token.scope <= sourceScope + 1 else { return nil }

            if token.kind == .whitespace {
                guard !token.text.contains(where: \Character.isNewline) else { return nil }
                index += 1
                continue
            }
            if token.kind == .punctuation {
                index += 1
                continue
            }
            return index
        }
        return nil
    }

    private static func nextWordToken(after start: Int, tokens: [Token]) -> Int? {
        let index = skipWhitespace(from: start, tokens: tokens)
        guard index > start, let token = tokens[safe: index], token.kind == .latinWord else {
            return nil
        }
        return index
    }

    private static func hasSpokenIdentifierLetterContinuation(
        after start: Int,
        tokens: [Token]
    ) -> Bool {
        let index = skipWhitespace(from: start, tokens: tokens)
        return isSingleASCIILetterToken(tokens[safe: index])
    }

    private static func isSingleASCIILetterToken(_ token: Token?) -> Bool {
        guard let token, token.kind == .latinWord else { return false }
        let characters = Array(token.text)
        return characters.count == 1 && characters[0].isASCII && characters[0].isLetter
    }

    private static func isDelimitedNumberStart(_ index: Int, tokens: [Token]) -> Bool {
        guard index > 0 else { return true }
        return tokens[index - 1].kind == .whitespace || tokens[index - 1].kind == .punctuation
    }

    private static func isDelimitedNumberEnd(_ index: Int, tokens: [Token]) -> Bool {
        guard index < tokens.count else { return true }
        return tokens[index].kind == .whitespace || tokens[index].kind == .punctuation
    }

    private static func tokenIsCovered(_ index: Int, by matches: [Match]) -> Bool {
        matches.contains { index >= $0.startToken && index < $0.endToken }
    }

    private static func skipRequiredWhitespace(from start: Int, tokens: [Token]) -> Int {
        guard let token = tokens[safe: start], token.kind == .whitespace else {
            return tokens.count
        }
        return skipWhitespace(from: start, tokens: tokens)
    }

    private static func skipAcademicLinker(from start: Int, tokens: [Token]) -> Int {
        let afterWhitespace = skipWhitespace(from: start, tokens: tokens)
        guard isHanText(tokens[safe: afterWhitespace], equalTo: "的") else {
            return afterWhitespace
        }
        return skipWhitespace(from: afterWhitespace + 1, tokens: tokens)
    }

    private static func skipWhitespace(from start: Int, tokens: [Token]) -> Int {
        guard start < tokens.count else { return start }
        let scope = tokens[start].scope
        var index = start
        while index < tokens.count,
              tokens[index].scope == scope,
              tokens[index].kind == .whitespace {
            index += 1
        }
        if index < tokens.count, tokens[index].scope != scope {
            return tokens.count
        }
        return index
    }

    private static func skipLocalPunctuationSeparators(
        from start: Int,
        tokens: [Token]
    ) -> Int {
        guard start < tokens.count else { return start }
        let scope = tokens[start].scope
        var index = start
        while index < tokens.count, tokens[index].scope == scope {
            let token = tokens[index]
            if token.kind == .whitespace || token.kind == .punctuation {
                index += 1
                continue
            }
            break
        }
        if index < tokens.count, tokens[index].scope != scope {
            return tokens.count
        }
        return index
    }

    private static func isSheetHead(_ token: Token?) -> Bool {
        guard let token else { return false }
        return ["sheet", "ssheet", "cheat"].contains(token.text.lowercased())
    }

    private static func isQuestionHead(_ token: Token?) -> Bool {
        guard let token else { return false }
        return parseCompactQuestion(token.text) != nil ||
            isWord(token, equalTo: "q") ||
            isWord(token, equalTo: "question")
    }

    private static func hasWhitespaceSeparatedCompositeOwner(
        before start: Int,
        expected: String,
        tokens: [Token]
    ) -> Bool {
        guard start > 0 else { return false }
        var index = start - 1
        while index >= 0, tokens[index].kind == .whitespace {
            index -= 1
        }
        guard index >= 0,
              tokens[index].scope == tokens[start].scope,
              isWord(tokens[index], equalTo: expected)
        else {
            return false
        }
        return tokens[(index + 1)..<start].allSatisfy { $0.kind == .whitespace }
    }

    private static func isWord(_ token: Token?, equalTo expected: String) -> Bool {
        guard let token, token.kind == .latinWord || token.kind == .asciiIdentifier else {
            return false
        }
        return token.text.caseInsensitiveCompare(expected) == .orderedSame
    }

    private static func isHanText(_ token: Token?, equalTo expected: String) -> Bool {
        guard let token, token.kind == .hanText else { return false }
        return token.text == expected
    }

    private static func isSubpartRangeJoiner(_ token: Token?) -> Bool {
        guard let token else { return false }
        return isWord(token, equalTo: "to") || isWord(token, equalTo: "through") ||
            (token.kind == .hanText && token.text == "到")
    }

    /// The dot in `1.2` is a decimal point, not a sentence end.
    private static func isDecimalDot(_ tokenText: String, at range: Range<String.Index>, in text: String) -> Bool {
        guard tokenText == ".", range.lowerBound > text.startIndex, range.upperBound < text.endIndex else {
            return false
        }
        let previous = text[text.index(before: range.lowerBound)]
        let next = text[range.upperBound]
        return previous.isASCII && previous.isNumber && next.isASCII && next.isNumber
    }

    private static func isSubpartJoiner(_ token: Token?) -> Bool {
        guard let token else { return false }
        return isWord(token, equalTo: "and") || (token.kind == .hanText && token.text == "和")
    }

    private static func rangesOverlap(_ lhs: Range<String.Index>, _ rhs: Range<String.Index>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    private static func advance(
        in text: String,
        from start: String.Index,
        upTo limit: String.Index,
        while predicate: (Character) -> Bool
    ) -> String.Index {
        var index = start
        while index < limit, predicate(text[index]) {
            index = text.index(after: index)
        }
        return index
    }

    private static func isWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    private static func isASCIIWordStart(_ character: Character) -> Bool {
        guard character.isASCII else { return false }
        return character.isLetter || character.isNumber || character == "_"
    }

    private static func isASCIIWordContinuation(_ character: Character) -> Bool {
        isASCIIWordStart(character) || character == "-"
    }

    private static func isHanNumber(_ character: Character) -> Bool {
        hanNumberCharacters.contains(character)
    }

    private static func isHan(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(\.properties.isIdeographic)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
