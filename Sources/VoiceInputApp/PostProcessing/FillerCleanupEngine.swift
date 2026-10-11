import Foundation

enum FillerCleanupEngine {
    private enum CaseStyle {
        case lowercase
        case titlecase
        case unsupported
    }

    private enum BridgeKind {
        case comma
        case softSeparator
        case horizontalGap
        case fullStop
        case ellipsis
    }

    private enum LeftTopology {
        case start
        case newClause
        case softSeparator
        case horizontalGap
        case unsupported
    }

    private enum RightTopology {
        case comma
        case softSeparator
        case horizontalGap
        case fullStop
        case ellipsis
        case end
        case expressive
        case quoteOrBracket
        case lineBreak
        case unsupported
    }

    private struct ProvisionalCandidate {
        let candidate: FillerCandidate
        let caseStyle: CaseStyle
    }

    private struct InternalBridge {
        let range: Range<String.Index>
        let kind: BridgeKind
    }

    private struct LeftContext {
        let topology: LeftTopology
        let evidence: FillerBoundaryEvidence
        let bridgeRange: Range<String.Index>?
        let sameClauseContent: Bool
        let neighbourToken: FillerToken?
    }

    private struct RightContext {
        let topology: RightTopology
        let evidence: FillerBoundaryEvidence
        let bridgeRange: Range<String.Index>
        let anchorRange: Range<String.Index>?
        let continuationIndex: String.Index?
        let continuationToken: FillerToken?
    }

    private struct AcceptedPlan {
        struct Edit {
            let sourceRange: Range<String.Index>
            let replacement: String
        }
        let edit: Edit
        let ruleID: String

        init(edit: FillerEdit, ruleID: String) {
            self.edit = Edit(sourceRange: edit.sourceRange, replacement: edit.replacement)
            self.ruleID = ruleID
        }

        init(range: Range<String.Index>, ruleID: String) {
            self.edit = Edit(sourceRange: range, replacement: "")
            self.ruleID = ruleID
        }
    }

    static func clean(
        _ text: String,
        context: NormalizationContext = NormalizationContext()
    ) -> FillerCleanupResult {
        guard !text.isEmpty else {
            return FillerCleanupResult(text: text, events: [])
        }

        let opaqueRanges = mergedOpaqueRanges(in: text, context: context)
        let staticMask = FillerProtectionScanner.staticRanges(in: text)
        // Recognition always sees original tokens, never boundaries created by protection.
        let originalTokens = scan(text)
        var provisional: [ProvisionalCandidate] = []
        for token in originalTokens { recognizeCandidates(in: token, source: text, into: &provisional) }
        let mask = FillerProtectionMask(opaqueRanges + staticMask.ranges +
            FillerProtectionScanner.cueRanges(in: text, candidates: provisional.map(\.candidate)))
        let opaqueMask = FillerProtectionMask(opaqueRanges)
        let tokens = opaqueRanges.isEmpty ? originalTokens : originalTokens.map { item in
            opaqueMask.overlaps(item.range)
                ? FillerToken(kind: item.kind, text: item.text, range: item.range, isProtected: true) : item
        }
        let legacy = provisional.filter { isLegacyCandidate($0) }
        let chains = assembleChains(legacy, source: text, mask: mask)
        let legacyPlans = chains.compactMap { chain -> AcceptedPlan? in
            guard !chain.contains(where: { mask.overlaps($0.candidate.sourceRange) }) else { return nil }
            return validateAndPlan(chain, source: text, tokens: tokens)
        }
        let attachedPlans = provisional.compactMap {
            planAttached($0, source: text, mask: mask)
        }
        let plans = (legacyPlans + attachedPlans).filter { !mask.overlaps($0.edit.sourceRange) }
        let nonOverlappingPlans = plans.sorted {
            $0.edit.sourceRange.lowerBound < $1.edit.sourceRange.lowerBound
        }

        guard !nonOverlappingPlans.isEmpty else { return FillerCleanupResult(text: text, events: []) }
        guard editsDoNotOverlap(nonOverlappingPlans),
              let offsets = validatedOffsets(nonOverlappingPlans, source: text) else {
            return FillerCleanupResult(text: text, events: [])
        }

        // Plan from the original input and collect edits backwards without repeatedly
        // copying the entire growing string for dense transcripts.
        var pieces: [Substring] = []
        pieces.reserveCapacity(nonOverlappingPlans.count * 2 + 1)
        var end = text.endIndex
        for plan in nonOverlappingPlans.reversed() {
            pieces.append(text[plan.edit.sourceRange.upperBound..<end])
            pieces.append(plan.edit.replacement[...])
            end = plan.edit.sourceRange.lowerBound
        }
        pieces.append(text[text.startIndex..<end])
        let rendered = pieces.reversed().joined()

        let events = zip(nonOverlappingPlans, offsets).map { plan, offset in
            let range = plan.edit.sourceRange
            let lowerOffset = offset.lowerBound
            let upperOffset = offset.upperBound
            return PostProcessingEvent(
                ruleID: plan.ruleID,
                rangeDescription: "segment:\(lowerOffset)..<\(upperOffset)",
                before: String(text[range]),
                after: plan.edit.replacement,
                reason: "Accepted a filler edit under the structural and protection rules.",
                confidence: .medium
            )
        }

        return FillerCleanupResult(text: rendered, events: events)
    }

    private static func mergedOpaqueRanges(
        in text: String,
        context: NormalizationContext
    ) -> [Range<String.Index>] {
        var ranges = context.protectedSpans.map(\.range)

        for term in context.knownTerms where !term.isEmpty {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let match = text.range(
                    of: term,
                    options: [.literal],
                    range: searchStart..<text.endIndex
                  ) {
                ranges.append(match)
                searchStart = text.index(after: match.lowerBound)
            }
        }

        let sorted = ranges.sorted {
            if $0.lowerBound != $1.lowerBound {
                return $0.lowerBound < $1.lowerBound
            }
            return $0.upperBound < $1.upperBound
        }
        var merged: [Range<String.Index>] = []

        for range in sorted {
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

    private static func scan(
        _ text: String
    ) -> [FillerToken] {
        var tokens: [FillerToken] = []
        var index = text.startIndex
        while index < text.endIndex {
            let segmentLimit = text.endIndex
            let start = index
            let character = text[index]

            if isHorizontalWhitespace(character) {
                index = consume(from: index, until: segmentLimit, in: text) {
                    isHorizontalWhitespace($0)
                }
                tokens.append(token(.whitespace, range: start..<index, source: text))
                continue
            }

            if isLineBreak(character) {
                index = text.index(after: index)
                tokens.append(token(.whitespace, range: start..<index, source: text))
                continue
            }

            if isHan(character) {
                index = consume(from: index, until: segmentLimit, in: text, while: isHan)
                tokens.append(token(.hanRun, range: start..<index, source: text))
                continue
            }

            // Common separators cannot be identifier characters. Classify them before
            // Unicode letter/number checks on punctuation-heavy transcripts.
            if commaSeparators.contains(character) || softSeparators.contains(character) ||
                character == "。" || character == "、" || isQuoteOrBracket(character) {
                index = text.index(after: index)
                tokens.append(token(.punctuation, range: start..<index, source: text))
                continue
            }

            if isIdentifierCharacter(character) {
                index = consume(from: index, until: segmentLimit, in: text) {
                    isIdentifierCharacter($0)
                }
                let value = text[start..<index]
                let kind: FillerTokenKind
                if value.allSatisfy(isDigit) {
                    kind = .number
                } else if value.allSatisfy(isLatinLetter) {
                    kind = .latinWord
                } else {
                    kind = .identifier
                }
                tokens.append(token(kind, range: start..<index, source: text))
                continue
            }

            if character == "." {
                index = consume(from: index, until: segmentLimit, in: text) { $0 == "." }
                tokens.append(token(.punctuation, range: start..<index, source: text))
                continue
            }

            if character == "…" {
                index = consume(from: index, until: segmentLimit, in: text) { $0 == "…" }
                tokens.append(token(.punctuation, range: start..<index, source: text))
                continue
            }

            if isExpressivePunctuation(character) {
                index = consume(from: index, until: segmentLimit, in: text) {
                    isExpressivePunctuation($0)
                }
                tokens.append(token(.punctuation, range: start..<index, source: text))
                continue
            }

            index = text.index(after: index)
            let kind: FillerTokenKind = isPunctuation(character) ? .punctuation : .other
            tokens.append(token(kind, range: start..<index, source: text))
        }

        return tokens
    }

    private static func token(
        _ kind: FillerTokenKind,
        range: Range<String.Index>,
        source: String
    ) -> FillerToken {
        FillerToken(kind: kind, text: source[range], range: range)
    }

    private static func consume(
        from start: String.Index,
        until limit: String.Index,
        in text: String,
        while predicate: (Character) -> Bool
    ) -> String.Index {
        var index = start
        while index < limit, predicate(text[index]) {
            index = text.index(after: index)
        }
        return index
    }

    private static func recognizeCandidates(
        in token: FillerToken,
        source: String,
        into items: inout [ProvisionalCandidate]
    ) {
        if token.kind == .latinWord {
            guard let item = recognizeEnglishCandidate(in: token) else { return }
            let mixed = (token.range.lowerBound > source.startIndex &&
                isHan(source[source.index(before: token.range.lowerBound)])) ||
                (token.range.upperBound < source.endIndex && isHan(source[token.range.upperBound]))
            guard mixed else { items.append(item); return }
            items.append(provisional(range: token.range, form: item.candidate.canonicalForm,
                language: .english, role: item.candidate.role, shape: .wholeToken,
                evidence: item.candidate.evidence.union([.mixedBoundary]),
                vetoes: item.candidate.vetoes.union([.insufficientBoundaryEvidence]),
                caseStyle: item.caseStyle))
            return
        }
        guard token.kind == .hanRun else { return }
        // Preserve the semantic-interjection veto for a whole mixed filler run.
        if token.text.allSatisfy({ allFillerAndInterjectionCharacters.contains($0) }),
           Set(token.text).count > 1, let old = recognizeHanCandidate(in: token, source: source) {
            items.append(old); return
        }
        var cursor = token.range.lowerBound
        while cursor < token.range.upperBound {
            let char = source[cursor]
            guard char == "呃" || char == "嗯" || char == "额" else {
                cursor = source.index(after: cursor); continue
            }
            let start = cursor
            cursor = consume(from: cursor, until: token.range.upperBound, in: source) { $0 == char }
            let range = start..<cursor
            let shape: FillerCandidateShape
            if start == token.range.lowerBound && cursor == token.range.upperBound { shape = .wholeToken }
            else if start == token.range.lowerBound { shape = .leadingHanEdge }
            else if cursor == token.range.upperBound { shape = .trailingHanEdge }
            else { shape = .internalHan }
            var evidence: Set<FillerEvidence> = shape == .wholeToken ? [.exactWholeToken] : []
            let repeated = source.index(after: start) != cursor
            if repeated { evidence.insert(.repeatedHesitationForm) }
            var vetoes: Set<FillerVeto> = []
            if char != "呃" && repeated { vetoes.insert(.unsupportedHanSubrange) }
            if shape == .trailingHanEdge && char == "呃" {
                if contentHan(source[source.index(before: start)]) { evidence.insert(.closedTrailingHanEdge) }
                else { vetoes.insert(.unsupportedHanSubrange) }
            }
            items.append(provisional(range: range, form: char == "呃" ? "呃" : (char == "嗯" ? "嗯" : "额"), language: .chinese,
                role: char == "呃" ? .canonicalFilledPause : (char == "嗯" ? .contextualFilledPause : .asrHesitationVariant),
                shape: shape, evidence: evidence, vetoes: vetoes))
        }
    }

    private static func isLegacyCandidate(_ item: ProvisionalCandidate) -> Bool {
        item.candidate.shape == .wholeToken ||
            (item.candidate.shape == .trailingHanEdge && item.candidate.canonicalForm == "呃")
    }

    private static func contentHan(_ char: Character) -> Bool {
        isHan(char) && !allFillerAndInterjectionCharacters.contains(char)
    }

    private static func planAttached(
        _ item: ProvisionalCandidate, source: String, mask: FillerProtectionMask
    ) -> AcceptedPlan? {
        let candidate = item.candidate
        let range = candidate.sourceRange
        guard candidate.vetoes.isEmpty, !mask.overlaps(range),
              range.lowerBound > source.startIndex,
              contentHan(source[source.index(before: range.lowerBound)]) else { return nil }
        let ruleID: String
        if candidate.shape == .internalHan && candidate.canonicalForm == "呃" {
            guard range.upperBound < source.endIndex, contentHan(source[range.upperBound]) else { return nil }
            ruleID = "filler.canonical.internal-han"
        } else if candidate.shape == .trailingHanEdge && candidate.canonicalForm == "嗯" {
            var cursor = range.upperBound
            while cursor < source.endIndex, isHorizontalWhitespace(source[cursor]) { cursor = source.index(after: cursor) }
            guard cursor < source.endIndex, commaSeparators.contains(source[cursor]) else { return nil }
            cursor = source.index(after: cursor)
            while cursor < source.endIndex, isHorizontalWhitespace(source[cursor]) { cursor = source.index(after: cursor) }
            guard cursor < source.endIndex, isHan(source[cursor]) || isLatinLetter(source[cursor]),
                  !mask.overlaps(cursor..<source.index(after: cursor)) else { return nil }
            ruleID = "filler.contextual.attached-comma"
        } else { return nil }
        return AcceptedPlan(range: range, ruleID: ruleID)
    }

    private static func validatedOffsets(_ plans: [AcceptedPlan], source: String) -> [Range<Int>]? {
        var cursor = source.startIndex
        var offset = 0
        var ranges: [Range<Int>] = []
        ranges.reserveCapacity(plans.count)
        func advance(to target: String.Index) -> Bool {
            while cursor < target && cursor < source.endIndex {
                offset += source[cursor].utf16.count
                cursor = source.index(after: cursor)
            }
            return cursor == target
        }
        for plan in plans {
            let range = plan.edit.sourceRange
            guard !range.isEmpty, advance(to: range.lowerBound) else { return nil }
            let lower = offset
            guard advance(to: range.upperBound) else { return nil }
            ranges.append(lower..<offset)
        }
        return ranges
    }

    private static func recognizeHanCandidate(
        in token: FillerToken,
        source: String
    ) -> ProvisionalCandidate? {
        let value = String(token.text)
        let characters = Array(value)

        if !characters.isEmpty,
           characters.allSatisfy({ allFillerAndInterjectionCharacters.contains($0) }) {
            let semantic = characters.contains { semanticInterjectionCharacters.contains($0) }
            return provisional(
                range: token.range,
                form: value,
                language: .chinese,
                role: .contextualFilledPause,
                shape: .wholeToken,
                evidence: [.exactWholeToken],
                vetoes: [semantic ? .semanticInterjection : .unsupportedHanSubrange]
            )
        }

        return nil
    }

    private static func recognizeEnglishCandidate(
        in token: FillerToken
    ) -> ProvisionalCandidate? {
        let lower = token.text.lowercased()
        let style = caseStyle(of: String(token.text))

        if matchesAh(lower) {
            return provisional(
                range: token.range,
                form: "ah",
                language: .english,
                role: .canonicalFilledPause,
                shape: .wholeToken,
                evidence: [.exactWholeToken],
                vetoes: [.semanticInterjection],
                caseStyle: style
            )
        }

        if matchesCanonicalEnglish(lower) {
            var evidence: Set<FillerEvidence> = [.exactWholeToken]
            if lower.count > 3 {
                evidence.insert(.repeatedHesitationForm)
            }
            let vetoes: Set<FillerVeto> = style == .unsupported
                ? [.uppercaseOrIdentifierShape]
                : []
            return provisional(
                range: token.range,
                form: lower,
                language: .english,
                role: .canonicalFilledPause,
                shape: .wholeToken,
                evidence: evidence,
                vetoes: vetoes,
                caseStyle: style
            )
        }

        if matchesEm(lower) {
            var evidence: Set<FillerEvidence> = [.exactWholeToken]
            if lower.count > 2 {
                evidence.insert(.repeatedHesitationForm)
            }
            let vetoes: Set<FillerVeto> = style == .lowercase
                ? []
                : [.uppercaseOrIdentifierShape]
            return provisional(
                range: token.range,
                form: lower,
                language: .english,
                role: .ambiguousEnglishHomograph,
                shape: .wholeToken,
                evidence: evidence,
                vetoes: vetoes,
                caseStyle: style
            )
        }

        return nil
    }

    private static func provisional(
        range: Range<String.Index>,
        form: String,
        language: FillerLanguage,
        role: FillerCandidateRole,
        shape: FillerCandidateShape,
        evidence: Set<FillerEvidence>,
        vetoes: Set<FillerVeto> = [],
        caseStyle: CaseStyle = .lowercase
    ) -> ProvisionalCandidate {
        ProvisionalCandidate(
            candidate: FillerCandidate(
                sourceRange: range,
                canonicalForm: form,
                language: language,
                role: role,
                shape: shape,
                evidence: evidence,
                vetoes: vetoes
            ),
            caseStyle: caseStyle
        )
    }

    private static func assembleChains(
        _ candidates: [ProvisionalCandidate],
        source: String,
        mask: FillerProtectionMask
    ) -> [[ProvisionalCandidate]] {
        guard !candidates.isEmpty else { return [] }
        let sorted = candidates.sorted {
            $0.candidate.sourceRange.lowerBound < $1.candidate.sourceRange.lowerBound
        }
        var chains: [[ProvisionalCandidate]] = []
        var current = [sorted[0]]

        for candidate in sorted.dropFirst() {
            let previous = current[current.count - 1]
            let between = previous.candidate.sourceRange.upperBound..<candidate.candidate.sourceRange.lowerBound
            if !mask.overlaps(previous.candidate.sourceRange),
               !mask.overlaps(candidate.candidate.sourceRange), !mask.overlaps(between),
               parseInternalBridge(between, source: source) != nil {
                current.append(candidate)
            } else {
                chains.append(current)
                current = [candidate]
            }
        }
        chains.append(current)
        return chains
    }

    private static func validateAndPlan(
        _ chain: [ProvisionalCandidate],
        source: String,
        tokens: [FillerToken]
    ) -> AcceptedPlan? {
        guard !chain.isEmpty,
              chain.allSatisfy({ $0.candidate.vetoes.isEmpty }) else {
            return nil
        }

        let bridges = zip(chain, chain.dropFirst()).compactMap { left, right in
            parseInternalBridge(
                left.candidate.sourceRange.upperBound..<right.candidate.sourceRange.lowerBound,
                source: source
            )
        }
        guard bridges.count == max(0, chain.count - 1) else { return nil }

        let first = chain[0]
        let last = chain[chain.count - 1]
        let left = classifyLeft(
            at: first.candidate.sourceRange.lowerBound,
            source: source,
            tokens: tokens
        )
        let right = classifyRight(
            at: last.candidate.sourceRange.upperBound,
            source: source,
            tokens: tokens
        )

        if chain.dropFirst().contains(where: { $0.candidate.shape == .trailingHanEdge }) {
            return nil
        }

        if first.candidate.shape == .trailingHanEdge {
            // Removing this bridge must not turn a retained leading filler into
            // a newly authorized internal candidate on a second pass.
            if let endpoint = right.continuationToken, endpoint.kind == .hanRun,
               let firstCharacter = endpoint.text.first,
               allFillerAndInterjectionCharacters.contains(firstCharacter) { return nil }
            guard validateEdgeLedChain(
                chain,
                bridges: bridges,
                right: right
            ) else {
                return nil
            }
        } else {
            guard validateWholeTokenChain(
                chain,
                bridges: bridges,
                left: left,
                right: right,
                tokens: tokens
            ) else {
                return nil
            }
        }

        let validatedCandidates = chain.enumerated().map { offset, item in
            var evidence = item.candidate.evidence
            if offset == 0 {
                evidence.insert(.leftBoundary(left.evidence))
            }
            if offset == chain.count - 1 {
                evidence.insert(.rightBoundary(right.evidence))
            }
            if right.continuationToken != nil {
                evidence.insert(.rightContinuation)
            }
            if left.sameClauseContent {
                evidence.insert(.sameClauseLeftContent)
            }
            return FillerCandidate(
                sourceRange: item.candidate.sourceRange,
                canonicalForm: item.candidate.canonicalForm,
                language: item.candidate.language,
                role: item.candidate.role,
                shape: item.candidate.shape,
                evidence: evidence,
                vetoes: item.candidate.vetoes
            )
        }

        let sequence = FillerSequence(
            sourceRange: first.candidate.sourceRange.lowerBound..<last.candidate.sourceRange.upperBound,
            candidates: validatedCandidates,
            leftBoundary: left.evidence,
            rightBoundary: right.evidence
        )
        guard let edit = planEdit(
            sequence: sequence,
            first: first,
            left: left,
            right: right,
            source: source
        ) else {
            return nil
        }

        return AcceptedPlan(
            edit: edit,
            ruleID: ruleID(for: chain, first: first, left: left, right: right)
        )
    }

    private static func validateEdgeLedChain(
        _ chain: [ProvisionalCandidate],
        bridges: [InternalBridge],
        right: RightContext
    ) -> Bool {
        guard chain[0].candidate.shape == .trailingHanEdge,
              let endpoint = right.continuationToken,
              (!endpoint.isProtected && (endpoint.kind == .hanRun || endpoint.kind == .latinWord))
                || startsMathSpan(endpoint),
              right.topology == .comma ||
                right.topology == .softSeparator ||
                right.topology == .horizontalGap else {
            return false
        }

        for index in chain.indices {
            let candidate = chain[index]
            if index > 0 {
                guard allowedLeft(candidate, bridge: bridges[index - 1]) else { return false }
            }
            if index < bridges.count {
                if index == 0 {
                    switch bridges[index].kind {
                    case .comma, .softSeparator, .horizontalGap:
                        break
                    case .fullStop, .ellipsis:
                        return false
                    }
                }
                guard allowedRight(candidate, bridge: bridges[index]) else { return false }
            } else {
                guard allowedRight(candidate, context: right) else { return false }
            }
        }
        return true
    }

    private static func validateWholeTokenChain(
        _ chain: [ProvisionalCandidate],
        bridges: [InternalBridge],
        left: LeftContext,
        right: RightContext,
        tokens: [FillerToken]
    ) -> Bool {
        guard allowedLeft(chain[0], context: left) else { return false }

        for index in chain.indices {
            let candidate = chain[index]
            if index > 0 {
                guard allowedLeft(candidate, bridge: bridges[index - 1]) else { return false }
            }
            if index < bridges.count {
                guard allowedRight(candidate, bridge: bridges[index]) else { return false }
            }
        }

        let isTerminal = right.topology == .end ||
            (right.topology == .fullStop && right.continuationToken == nil)
        if isTerminal {
            guard left.topology == .softSeparator || left.topology == .horizontalGap,
                  left.sameClauseContent,
                  chain.allSatisfy(terminalEligible) else {
                return false
            }
        } else {
            guard right.continuationToken.map(isSubstantive) == true,
                  allowedRight(chain[chain.count - 1], context: right) else {
                return false
            }
        }

        if chain.contains(where: requiresNumericNeighbourVeto) {
            let hasImmediateLeftNumericNeighbour =
                (left.topology == .softSeparator || left.topology == .horizontalGap) &&
                left.neighbourToken.map(isNumericOrIdentifier) == true
            if hasImmediateLeftNumericNeighbour ||
                right.continuationToken.map(isNumericOrIdentifier) == true {
                return false
            }
        }
        return true
    }

    private static func allowedLeft(
        _ candidate: ProvisionalCandidate,
        context: LeftContext
    ) -> Bool {
        switch context.topology {
        case .start:
            return allowsStartOrNewClause(candidate)
        case .newClause:
            return allowsStartOrNewClause(candidate)
        case .softSeparator:
            return allowsSoftLeft(candidate, anchor: context.evidence.anchor)
        case .horizontalGap:
            return allowsHorizontalLeft(candidate)
        case .unsupported:
            return false
        }
    }

    private static func allowedLeft(
        _ candidate: ProvisionalCandidate,
        bridge: InternalBridge
    ) -> Bool {
        switch bridge.kind {
        case .comma:
            return allowsSoftLeft(candidate, anchor: .commaSeparator)
        case .softSeparator:
            return allowsSoftLeft(candidate, anchor: .otherSoftSeparator)
        case .horizontalGap:
            return allowsHorizontalLeft(candidate)
        case .fullStop:
            return allowsStartOrNewClause(candidate)
        case .ellipsis:
            return false
        }
    }

    private static func allowsStartOrNewClause(_ candidate: ProvisionalCandidate) -> Bool {
        candidate.candidate.shape == .wholeToken
    }

    private static func allowsSoftLeft(
        _ candidate: ProvisionalCandidate,
        anchor: FillerBoundaryAnchor
    ) -> Bool {
        guard candidate.candidate.shape == .wholeToken else { return false }
        if candidate.caseStyle == .titlecase { return false }
        switch candidate.candidate.role {
        case .canonicalFilledPause, .contextualFilledPause:
            return true
        case .asrHesitationVariant, .ambiguousEnglishHomograph:
            return anchor == .commaSeparator
        }
    }

    private static func allowsHorizontalLeft(_ candidate: ProvisionalCandidate) -> Bool {
        guard candidate.candidate.shape == .wholeToken,
              candidate.caseStyle != .titlecase else {
            return false
        }
        switch candidate.candidate.role {
        case .canonicalFilledPause, .contextualFilledPause:
            return true
        case .asrHesitationVariant, .ambiguousEnglishHomograph:
            return false
        }
    }

    private static func allowedRight(
        _ candidate: ProvisionalCandidate,
        bridge: InternalBridge
    ) -> Bool {
        switch bridge.kind {
        case .comma:
            return allowsRight(candidate, commaOnly: true)
        case .softSeparator:
            return allowsRight(candidate, commaOnly: false)
        case .horizontalGap:
            return allowsBroadRight(candidate)
        case .fullStop, .ellipsis:
            return allowsBroadRight(candidate)
        }
    }

    private static func allowedRight(
        _ candidate: ProvisionalCandidate,
        context: RightContext
    ) -> Bool {
        switch context.topology {
        case .comma:
            return allowsRight(candidate, commaOnly: true)
        case .softSeparator:
            return allowsRight(candidate, commaOnly: false)
        case .horizontalGap, .fullStop, .ellipsis:
            return allowsBroadRight(candidate)
        case .end, .expressive, .quoteOrBracket, .lineBreak, .unsupported:
            return false
        }
    }

    private static func allowsRight(
        _ candidate: ProvisionalCandidate,
        commaOnly: Bool
    ) -> Bool {
        switch candidate.candidate.role {
        case .canonicalFilledPause, .contextualFilledPause:
            return true
        case .asrHesitationVariant, .ambiguousEnglishHomograph:
            return commaOnly
        }
    }

    private static func allowsBroadRight(_ candidate: ProvisionalCandidate) -> Bool {
        switch candidate.candidate.role {
        case .canonicalFilledPause, .contextualFilledPause:
            return true
        case .asrHesitationVariant, .ambiguousEnglishHomograph:
            return false
        }
    }

    private static func terminalEligible(_ candidate: ProvisionalCandidate) -> Bool {
        guard candidate.candidate.shape == .wholeToken,
              candidate.caseStyle != .titlecase else {
            return false
        }
        switch candidate.candidate.role {
        case .canonicalFilledPause:
            return true
        case .contextualFilledPause:
            return candidate.candidate.language == .chinese
        case .asrHesitationVariant, .ambiguousEnglishHomograph:
            return false
        }
    }

    private static func requiresNumericNeighbourVeto(
        _ candidate: ProvisionalCandidate
    ) -> Bool {
        candidate.candidate.language == .english ||
            candidate.candidate.role == .asrHesitationVariant
    }

    private static func planEdit(
        sequence: FillerSequence,
        first: ProvisionalCandidate,
        left: LeftContext,
        right: RightContext,
        source: String
    ) -> FillerEdit? {
        if first.candidate.shape == .trailingHanEdge {
            guard let continuationIndex = right.continuationIndex,
                  let continuationToken = right.continuationToken else {
                return nil
            }
            let replacement = continuationToken.kind == .latinWord || startsMathSpan(continuationToken) ? " " : ""
            return FillerEdit(
                sourceRange: first.candidate.sourceRange.lowerBound..<continuationIndex,
                replacement: replacement,
                sequence: sequence
            )
        }

        let isTerminalFullStop = right.topology == .fullStop && right.continuationToken == nil
        if isTerminalFullStop {
            guard let leftBridge = left.bridgeRange,
                  let anchor = right.anchorRange else {
                return nil
            }
            return FillerEdit(
                sourceRange: leftBridge.lowerBound..<right.bridgeRange.upperBound,
                replacement: String(source[anchor]),
                sequence: sequence
            )
        }

        if right.topology == .end {
            guard let leftBridge = left.bridgeRange else { return nil }
            return FillerEdit(
                sourceRange: leftBridge.lowerBound..<right.bridgeRange.upperBound,
                replacement: "",
                sequence: sequence
            )
        }

        guard let continuationIndex = right.continuationIndex else { return nil }

        switch left.topology {
        case .start, .newClause:
            return FillerEdit(
                sourceRange: sequence.sourceRange.lowerBound..<continuationIndex,
                replacement: "",
                sequence: sequence
            )
        case .softSeparator:
            if right.topology == .fullStop,
               let leftBridge = left.bridgeRange,
               let anchor = right.anchorRange {
                return FillerEdit(
                    sourceRange: leftBridge.lowerBound..<anchor.upperBound,
                    replacement: String(source[anchor]),
                    sequence: sequence
                )
            }
            return FillerEdit(
                sourceRange: sequence.sourceRange.lowerBound..<continuationIndex,
                replacement: "",
                sequence: sequence
            )
        case .horizontalGap:
            if right.topology == .fullStop,
               let leftBridge = left.bridgeRange,
               let anchor = right.anchorRange {
                return FillerEdit(
                    sourceRange: leftBridge.lowerBound..<anchor.upperBound,
                    replacement: String(source[anchor]),
                    sequence: sequence
                )
            }
            guard let leftBridge = left.bridgeRange else { return nil }
            let preservedGapEnd = source.index(after: leftBridge.lowerBound)
            return FillerEdit(
                sourceRange: preservedGapEnd..<continuationIndex,
                replacement: "",
                sequence: sequence
            )
        case .unsupported:
            return nil
        }
    }

    private static func ruleID(
        for chain: [ProvisionalCandidate],
        first: ProvisionalCandidate,
        left: LeftContext,
        right: RightContext
    ) -> String {
        let roles = Set(chain.map(\.candidate.role))
        let role: String
        if roles.count > 1 {
            role = "mixed"
        } else {
            switch chain[0].candidate.role {
            case .canonicalFilledPause:
                role = "canonical"
            case .contextualFilledPause:
                role = "contextual"
            case .asrHesitationVariant:
                role = "asr-variant"
            case .ambiguousEnglishHomograph:
                role = "homograph"
            }
        }

        if first.candidate.shape == .trailingHanEdge {
            let endpoint = right.continuationToken?.kind == .latinWord
                ? "latin-continuation"
                : "han-continuation"
            return "filler.\(role).trailing-han-edge.\(endpoint)"
        }

        let topology: String
        if right.topology == .end {
            topology = "terminal-end"
        } else if right.topology == .fullStop && right.continuationToken == nil {
            topology = "terminal-full-stop"
        } else {
            switch left.topology {
            case .start:
                topology = "start-continuation"
            case .newClause:
                topology = "new-clause-continuation"
            case .softSeparator:
                topology = "medial-soft-continuation"
            case .horizontalGap:
                topology = "medial-gap-continuation"
            case .unsupported:
                topology = "unsupported"
            }
        }
        return "filler.\(role).whole.\(topology)"
    }

    private static func classifyLeft(
        at candidateStart: String.Index,
        source: String,
        tokens: [FillerToken]
    ) -> LeftContext {
        var cursor = candidateStart
        var gapStart = candidateStart
        var hasWhitespace = false

        while cursor > source.startIndex {
            let previous = source.index(before: cursor)
            guard isHorizontalWhitespace(source[previous]) else { break }
            hasWhitespace = true
            gapStart = previous
            cursor = previous
        }

        if cursor == source.startIndex {
            return LeftContext(
                topology: .start,
                evidence: FillerBoundaryEvidence(
                    hasHorizontalWhitespace: hasWhitespace,
                    anchor: .utteranceStart
                ),
                bridgeRange: nil,
                sameClauseContent: false,
                neighbourToken: nil
            )
        }

        let anchorIndex = source.index(before: cursor)
        let anchor = source[anchorIndex]
        let neighbour = nearestSubstantiveToken(before: cursor, tokens: tokens)

        if commaSeparators.contains(anchor) || softSeparators.contains(anchor) {
            let boundaryAnchor: FillerBoundaryAnchor = commaSeparators.contains(anchor)
                ? .commaSeparator
                : .otherSoftSeparator
            return LeftContext(
                topology: .softSeparator,
                evidence: FillerBoundaryEvidence(
                    hasHorizontalWhitespace: hasWhitespace,
                    anchor: boundaryAnchor
                ),
                bridgeRange: anchorIndex..<candidateStart,
                sameClauseContent: hasImmediateSubstantiveContent(
                    before: anchorIndex,
                    source: source,
                    tokens: tokens
                ),
                neighbourToken: nearestSubstantiveToken(before: anchorIndex, tokens: tokens)
            )
        }

        if anchor == "。" || anchor == "." {
            if anchor == ".", isPartOfLeftEllipsis(at: anchorIndex, source: source) {
                return unsupportedLeft(hasWhitespace: hasWhitespace, neighbour: neighbour)
            }
            return LeftContext(
                topology: .newClause,
                evidence: FillerBoundaryEvidence(
                    hasHorizontalWhitespace: hasWhitespace,
                    anchor: .priorClauseTerminator
                ),
                bridgeRange: nil,
                sameClauseContent: false,
                neighbourToken: neighbour
            )
        }

        if isExpressivePunctuation(anchor) {
            return LeftContext(
                topology: .newClause,
                evidence: FillerBoundaryEvidence(
                    hasHorizontalWhitespace: hasWhitespace,
                    anchor: .priorClauseTerminator
                ),
                bridgeRange: nil,
                sameClauseContent: false,
                neighbourToken: neighbour
            )
        }

        if anchor == "…" || isQuoteOrBracket(anchor) || isLineBreak(anchor) {
            return unsupportedLeft(hasWhitespace: hasWhitespace, neighbour: neighbour)
        }

        if hasWhitespace,
           hasImmediateSubstantiveContent(before: gapStart, source: source, tokens: tokens) {
            return LeftContext(
                topology: .horizontalGap,
                evidence: FillerBoundaryEvidence(
                    hasHorizontalWhitespace: true,
                    anchor: .lexicalToken
                ),
                bridgeRange: gapStart..<candidateStart,
                sameClauseContent: true,
                neighbourToken: nearestSubstantiveToken(before: gapStart, tokens: tokens)
            )
        }

        return unsupportedLeft(hasWhitespace: hasWhitespace, neighbour: neighbour)
    }

    private static func unsupportedLeft(
        hasWhitespace: Bool,
        neighbour: FillerToken?
    ) -> LeftContext {
        LeftContext(
            topology: .unsupported,
            evidence: FillerBoundaryEvidence(
                hasHorizontalWhitespace: hasWhitespace,
                anchor: .lexicalToken
            ),
            bridgeRange: nil,
            sameClauseContent: false,
            neighbourToken: neighbour
        )
    }

    private static func classifyRight(
        at candidateEnd: String.Index,
        source: String,
        tokens: [FillerToken]
    ) -> RightContext {
        var cursor = candidateEnd
        var hasWhitespace = false
        while cursor < source.endIndex, isHorizontalWhitespace(source[cursor]) {
            hasWhitespace = true
            cursor = source.index(after: cursor)
        }

        if cursor == source.endIndex {
            return RightContext(
                topology: .end,
                evidence: FillerBoundaryEvidence(
                    hasHorizontalWhitespace: hasWhitespace,
                    anchor: .utteranceEnd
                ),
                bridgeRange: candidateEnd..<source.endIndex,
                anchorRange: nil,
                continuationIndex: nil,
                continuationToken: nil
            )
        }

        let anchor = source[cursor]
        if isLineBreak(anchor) {
            return blockedRight(
                .lineBreak,
                anchor: .lineBreak,
                hasWhitespace: hasWhitespace,
                from: candidateEnd,
                at: cursor
            )
        }
        if isQuoteOrBracket(anchor) {
            return blockedRight(
                .quoteOrBracket,
                anchor: .quoteOrBracket,
                hasWhitespace: hasWhitespace,
                from: candidateEnd,
                at: cursor
            )
        }
        if isExpressivePunctuation(anchor) {
            return blockedRight(
                .expressive,
                anchor: .expressivePunctuation,
                hasWhitespace: hasWhitespace,
                from: candidateEnd,
                at: cursor
            )
        }

        let anchorRange: Range<String.Index>
        let topology: RightTopology
        let boundaryAnchor: FillerBoundaryAnchor

        if commaSeparators.contains(anchor) {
            anchorRange = cursor..<source.index(after: cursor)
            topology = .comma
            boundaryAnchor = .commaSeparator
        } else if softSeparators.contains(anchor) {
            anchorRange = cursor..<source.index(after: cursor)
            topology = .softSeparator
            boundaryAnchor = .otherSoftSeparator
        } else if anchor == "。" {
            anchorRange = cursor..<source.index(after: cursor)
            topology = .fullStop
            boundaryAnchor = .neutralFullStop
        } else if anchor == "." {
            let range = punctuationRun(from: cursor, character: ".", source: source)
            let value = String(source[range])
            guard value == "." || value == "..." else {
                return blockedRight(
                    .unsupported,
                    anchor: .expressivePunctuation,
                    hasWhitespace: hasWhitespace,
                    from: candidateEnd,
                    at: cursor
                )
            }
            anchorRange = range
            topology = value == "." ? .fullStop : .ellipsis
            boundaryAnchor = value == "." ? .neutralFullStop : .hesitationEllipsis
        } else if anchor == "…" {
            let range = punctuationRun(from: cursor, character: "…", source: source)
            let value = String(source[range])
            guard value == "…" || value == "……" else {
                return blockedRight(
                    .unsupported,
                    anchor: .expressivePunctuation,
                    hasWhitespace: hasWhitespace,
                    from: candidateEnd,
                    at: cursor
                )
            }
            anchorRange = range
            topology = .ellipsis
            boundaryAnchor = .hesitationEllipsis
        } else if hasWhitespace {
            let continuationToken = token(startingAt: cursor, tokens: tokens)
            return RightContext(
                topology: .horizontalGap,
                evidence: FillerBoundaryEvidence(
                    hasHorizontalWhitespace: true,
                    anchor: .lexicalToken
                ),
                bridgeRange: candidateEnd..<cursor,
                anchorRange: nil,
                continuationIndex: cursor,
                continuationToken: continuationToken
            )
        } else {
            return blockedRight(
                .unsupported,
                anchor: .lexicalToken,
                hasWhitespace: false,
                from: candidateEnd,
                at: cursor
            )
        }

        var continuationIndex = anchorRange.upperBound
        var trailingWhitespace = false
        while continuationIndex < source.endIndex,
              isHorizontalWhitespace(source[continuationIndex]) {
            trailingWhitespace = true
            continuationIndex = source.index(after: continuationIndex)
        }
        let continuationToken = continuationIndex < source.endIndex
            ? token(startingAt: continuationIndex, tokens: tokens)
            : nil

        return RightContext(
            topology: topology,
            evidence: FillerBoundaryEvidence(
                hasHorizontalWhitespace: hasWhitespace || trailingWhitespace,
                anchor: boundaryAnchor
            ),
            bridgeRange: candidateEnd..<continuationIndex,
            anchorRange: anchorRange,
            continuationIndex: continuationToken == nil ? nil : continuationIndex,
            continuationToken: continuationToken
        )
    }

    private static func blockedRight(
        _ topology: RightTopology,
        anchor: FillerBoundaryAnchor,
        hasWhitespace: Bool,
        from start: String.Index,
        at anchorIndex: String.Index
    ) -> RightContext {
        RightContext(
            topology: topology,
            evidence: FillerBoundaryEvidence(
                hasHorizontalWhitespace: hasWhitespace,
                anchor: anchor
            ),
            bridgeRange: start..<anchorIndex,
            anchorRange: nil,
            continuationIndex: nil,
            continuationToken: nil
        )
    }

    private static func parseInternalBridge(
        _ range: Range<String.Index>,
        source: String
    ) -> InternalBridge? {
        guard !range.isEmpty else { return nil }
        var lower = range.lowerBound
        var upper = range.upperBound

        while lower < upper, isHorizontalWhitespace(source[lower]) {
            lower = source.index(after: lower)
        }
        while upper > lower {
            let previous = source.index(before: upper)
            guard isHorizontalWhitespace(source[previous]) else { break }
            upper = previous
        }

        if lower == upper {
            return InternalBridge(range: range, kind: .horizontalGap)
        }

        let core = String(source[lower..<upper])
        if core == "," || core == "，" {
            return InternalBridge(range: range, kind: .comma)
        }
        if [";", "；", ":", "："].contains(core) {
            return InternalBridge(range: range, kind: .softSeparator)
        }
        if core == "." || core == "。" {
            return InternalBridge(range: range, kind: .fullStop)
        }
        if core == "..." || core == "…" || core == "……" {
            return InternalBridge(range: range, kind: .ellipsis)
        }
        return nil
    }

    private static func editsDoNotOverlap(_ plans: [AcceptedPlan]) -> Bool {
        for pair in zip(plans, plans.dropFirst()) {
            if pair.0.edit.sourceRange.upperBound > pair.1.edit.sourceRange.lowerBound {
                return false
            }
        }
        return true
    }

    private static func tokenInsertionIndex(_ index: String.Index, tokens: [FillerToken]) -> Int {
        var low = 0
        var high = tokens.count
        while low < high {
            let middle = (low + high) / 2
            if tokens[middle].range.lowerBound < index { low = middle + 1 } else { high = middle }
        }
        return low
    }

    private static func token(
        startingAt index: String.Index,
        tokens: [FillerToken]
    ) -> FillerToken? {
        let offset = tokenInsertionIndex(index, tokens: tokens)
        return offset < tokens.count && tokens[offset].range.lowerBound == index ? tokens[offset] : nil
    }

    private static func nearestSubstantiveToken(
        before index: String.Index,
        tokens: [FillerToken]
    ) -> FillerToken? {
        var offset = tokenInsertionIndex(index, tokens: tokens)
        while offset > 0 {
            offset -= 1
            if tokens[offset].range.upperBound <= index && isSubstantive(tokens[offset]) { return tokens[offset] }
        }
        return nil
    }

    private static func hasImmediateSubstantiveContent(
        before index: String.Index,
        source: String,
        tokens: [FillerToken]
    ) -> Bool {
        var cursor = index
        while cursor > source.startIndex {
            let previous = source.index(before: cursor)
            guard isHorizontalWhitespace(source[previous]) else { break }
            cursor = previous
        }
        let offset = tokenInsertionIndex(cursor, tokens: tokens)
        return offset > 0 && tokens[offset - 1].range.upperBound == cursor && isSubstantive(tokens[offset - 1])
    }

    /// A formula rendered by the math layer continues the sentence like the spoken words it
    /// replaced (it only exists with the math switch on).
    private static func startsMathSpan(_ token: FillerToken) -> Bool {
        token.text.first == MathStage.openSentinel
    }

    private static func isSubstantive(_ token: FillerToken) -> Bool {
        if token.isProtected { return true }
        switch token.kind {
        case .hanRun, .latinWord, .number, .identifier:
            return true
        case .whitespace, .punctuation, .other:
            return false
        }
    }

    private static func isNumericOrIdentifier(_ token: FillerToken) -> Bool {
        token.kind == .number || token.kind == .identifier
    }

    private static func punctuationRun(
        from start: String.Index,
        character: Character,
        source: String
    ) -> Range<String.Index> {
        var end = start
        while end < source.endIndex, source[end] == character {
            end = source.index(after: end)
        }
        return start..<end
    }

    private static func isPartOfLeftEllipsis(
        at dot: String.Index,
        source: String
    ) -> Bool {
        var count = 1
        var cursor = dot
        while cursor > source.startIndex {
            let previous = source.index(before: cursor)
            guard source[previous] == "." else { break }
            count += 1
            cursor = previous
        }
        return count >= 3
    }

    private static func caseStyle(of text: String) -> CaseStyle {
        guard text == text.lowercased() else {
            guard let first = text.first,
                  first.isUppercase,
                  String(text.dropFirst()) == String(text.dropFirst()).lowercased() else {
                return .unsupported
            }
            return .titlecase
        }
        return .lowercase
    }

    private static func matchesCanonicalEnglish(_ value: String) -> Bool {
        let characters = Array(value)
        guard characters.count >= 2 else { return false }

        if characters[0] == "u" {
            let remainder = Array(characters.dropFirst())
            if remainder.allSatisfy({ $0 == "h" }) || remainder.allSatisfy({ $0 == "m" }) {
                return true
            }
            var index = 0
            while index < remainder.count, remainder[index] == "h" {
                index += 1
            }
            guard index > 0, index < remainder.count else { return false }
            return remainder[index...].allSatisfy { $0 == "m" }
        }

        if characters[0] == "e" {
            let remainder = Array(characters.dropFirst())
            var index = 0
            while index < remainder.count, remainder[index] == "r" {
                index += 1
            }
            guard index > 0, index < remainder.count else { return false }
            return remainder[index...].allSatisfy { $0 == "m" }
        }

        return false
    }

    private static func matchesEm(_ value: String) -> Bool {
        let characters = Array(value)
        return characters.count >= 2 &&
            characters[0] == "e" &&
            characters.dropFirst().allSatisfy { $0 == "m" }
    }

    private static func matchesAh(_ value: String) -> Bool {
        let characters = Array(value)
        return characters.count >= 2 &&
            characters[0] == "a" &&
            characters.dropFirst().allSatisfy { $0 == "h" }
    }

    private static let commaSeparators: Set<Character> = [",", "，"]
    private static let softSeparators: Set<Character> = [";", "；", ":", "："]
    private static let semanticInterjectionCharacters: Set<Character> = [
        "哦", "噢", "啊", "呀", "哎", "诶", "欸", "唉"
    ]
    private static let allFillerAndInterjectionCharacters: Set<Character> =
        semanticInterjectionCharacters.union(["呃", "嗯", "额"])
    private static let quoteAndBracketCharacters: Set<Character> = [
        "\"", "'", "“", "”", "‘", "’", "(", ")", "（", "）",
        "[", "]", "【", "】", "{", "}", "<", ">", "《", "》"
    ]

    private static func isHorizontalWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\t"
    }

    private static func isLineBreak(_ character: Character) -> Bool {
        character == "\n" || character == "\r"
    }

    private static func isQuoteOrBracket(_ character: Character) -> Bool {
        quoteAndBracketCharacters.contains(character)
    }

    private static func isExpressivePunctuation(_ character: Character) -> Bool {
        character == "?" || character == "？" || character == "!" || character == "！"
    }

    private static func isPunctuation(_ character: Character) -> Bool {
        commaSeparators.contains(character) ||
            softSeparators.contains(character) ||
            isExpressivePunctuation(character) ||
            isQuoteOrBracket(character) ||
            ["。", "、"].contains(character)
    }

    private static func isDigit(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        isLatinLetter(character) || isDigit(character) || character == "_"
    }

    private static func isLatinLetter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            CharacterSet.letters.contains($0) && !isHanScalar($0)
        }
    }

    private static func isHan(_ character: Character) -> Bool {
        !character.unicodeScalars.isEmpty && character.unicodeScalars.allSatisfy(isHanScalar)
    }

    private static func isHanScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (0x3400...0x4DBF).contains(value) ||
            (0x4E00...0x9FFF).contains(value) ||
            (0xF900...0xFAFF).contains(value) ||
            (0x20000...0x2FA1F).contains(value)
    }
}
