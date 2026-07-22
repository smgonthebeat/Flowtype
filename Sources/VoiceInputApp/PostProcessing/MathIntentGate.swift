import Foundation

struct MathRenderingDecision: Equatable {
    let text: String
    let selectedCandidate: CandidateSource
    let outcome: MathRenderingDecisionOutcome
    let decisionEvent: PostProcessingEvent
}

enum MathRenderingDecisionOutcome: String, Codable, Equatable {
    case acceptedMath
    case keptOriginal
}

enum MathIntentGate {
    static func evaluate(
        original: String,
        rendered: String,
        events: [PostProcessingEvent],
        profile: TranscriptProcessingProfile
    ) -> MathRenderingDecision {
        guard original != rendered, !events.isEmpty else {
            return MathRenderingDecision(
                text: original,
                selectedCandidate: .original,
                outcome: .keptOriginal,
                decisionEvent: decisionEvent(
                    before: original,
                    after: original,
                    reason: "kept original: no math notation change",
                    confidence: .low
                )
            )
        }

        let hasFormulaAnchor = containsFormulaAnchor(original)
        let shortFormula = isShortFormulaDense(original, events: events)
        let formulaLikeSequence = isFormulaLikeSequence(original, events: events)
        let strongMath = containsStrongMathSignal(original, rendered: rendered, events: events)
        let plainBlocker = containsPlainEnglishBlocker(original)
        let codeBlocker = containsCodeLikeBlocker(original)

        guard hasFormulaAnchor || shortFormula || formulaLikeSequence || strongMath else {
            return MathRenderingDecision(
                text: original,
                selectedCandidate: .original,
                outcome: .keptOriginal,
                decisionEvent: decisionEvent(
                    before: original,
                    after: original,
                    reason: "kept original: no supporting signal",
                    confidence: .high
                )
            )
        }

        let context = CandidateScoringContext(
            profile: profile,
            sourceText: original,
            hasMathSignal: hasFormulaAnchor || shortFormula || formulaLikeSequence || strongMath,
            hasPlainEnglishBlocker: plainBlocker && !hasFormulaAnchor && !shortFormula && !formulaLikeSequence,
            hasCodeLikeBlocker: codeBlocker && !hasFormulaAnchor && !shortFormula && !formulaLikeSequence
        )
        let candidates = [
            TranscriptCandidate(text: original, source: .original, transformations: []),
            TranscriptCandidate(text: rendered, source: .mathRendered, transformations: events)
        ]
        let selected = CandidateScorer.choose(candidates, context: context) ?? candidates[0]
        let outcome: MathRenderingDecisionOutcome = selected.source == .mathRendered
            ? .acceptedMath
            : .keptOriginal
        let reason = decisionReason(
            outcome: outcome,
            hasFormulaAnchor: hasFormulaAnchor,
            shortFormula: shortFormula,
            formulaLikeSequence: formulaLikeSequence,
            strongMath: strongMath,
            plainBlocker: plainBlocker,
            codeBlocker: codeBlocker
        )

        return MathRenderingDecision(
            text: selected.text,
            selectedCandidate: selected.source,
            outcome: outcome,
            decisionEvent: decisionEvent(
                before: original,
                after: selected.text,
                reason: reason,
                confidence: outcome == .acceptedMath ? .medium : .high
            )
        )
    }

    private static func decisionEvent(
        before: String,
        after: String,
        reason: String,
        confidence: CandidateConfidence
    ) -> PostProcessingEvent {
        PostProcessingEvent(
            ruleID: "math.intent-gate",
            rangeDescription: "whole-transcript",
            before: before,
            after: after,
            reason: reason,
            confidence: confidence
        )
    }

    private static func decisionReason(
        outcome: MathRenderingDecisionOutcome,
        hasFormulaAnchor: Bool,
        shortFormula: Bool,
        formulaLikeSequence: Bool,
        strongMath: Bool,
        plainBlocker: Bool,
        codeBlocker: Bool
    ) -> String {
        var reasons: [String] = []

        if hasFormulaAnchor {
            reasons.append("formula anchor")
        }
        if shortFormula {
            reasons.append("short formula")
        }
        if formulaLikeSequence {
            reasons.append("formula-like sequence")
        }
        if strongMath {
            reasons.append("strong math signal")
        }
        if plainBlocker {
            reasons.append("plain-English blocker")
        }
        if codeBlocker {
            reasons.append("code-like blocker")
        }

        let suffix = reasons.isEmpty ? "no supporting signal" : reasons.joined(separator: ", ")
        switch outcome {
        case .acceptedMath:
            return "accepted math: \(suffix)"
        case .keptOriginal:
            return "kept original: \(suffix)"
        }
    }

    private static func containsStrongMathSignal(
        _ original: String,
        rendered: String,
        events: [PostProcessingEvent]
    ) -> Bool {
        let lower = original.lowercased()
        if containsAny(
            lower,
            patterns: [
                #"\bvariance\b"#,
                #"\bvar\b"#,
                #"\bstandard\s+error\b"#,
                #"\bstandard\s+deviation\b"#,
                #"\bcovariance\b"#,
                #"\bcorrelation\b"#,
                #"\bexpected\s+value\b"#,
                #"\bexpectation\b"#
            ]
        ) {
            return true
        }

        if rendered.contains("SE(")
            || rendered.contains("Var(")
            || rendered.contains("Cov(")
            || rendered.contains("Corr(") {
            return true
        }

        return events.contains { event in
            let rule = event.ruleID.lowercased()
            return rule.contains("variance")
                || rule.contains("standard-error")
                || rule.contains("statistics")
                || rule.contains("expectation")
        }
    }

    private static func containsPlainEnglishBlocker(_ text: String) -> Bool {
        containsAny(
            text.lowercased(),
            patterns: [
                #"\b(?:what|w\s+hat)\s+(?:does|is|are)\b.*\b(?:stand\s+for|mean|means|in\s+finance|in\s+financial)\b"#,
                #"\bhow\s+does\b"#,
                #"\bwhy\s+does\b"#,
                #"\b(?:what|w\s+hat)\s+does\b.*\?"#,
                #"\b(?:what|w\s+hat)\s+is\b.*\?"#,
                #"\bask\b.*\b(?:chatgpt|qwen|codex)\b"#,
                #"\bopen\b.*\b(?:chatgpt|qwen|codex|flowtype)\b"#,
                #"\bsearch\b.*\bfor\b"#
            ]
        )
    }

    private static func containsCodeLikeBlocker(_ text: String) -> Bool {
        let lower = text.lowercased()

        return containsAny(
            lower,
            patterns: [
                #"\bwrite\b.*\bin\s+(?:swift|python|javascript|typescript|r|stata|matlab|sql)\b"#,
                #"\b(?:swift|python|javascript|typescript|stata|matlab|sql)\s+code\b"#,
                #"[/~][\w\-/\.]+"#,
                #"\.\w{1,6}\b"#
            ]
        )
    }

    private static func containsFormulaAnchor(_ text: String) -> Bool {
        containsAny(
            text.lowercased(),
            patterns: [
                #"\b(?:equals|equal\s+to|is\s+equal\s+to)\b"#,
                #"\b(?:plus|minus|times|over|divided\s+by|squared|cubed)\b"#,
                #"\b(?:sub|subscript|bar|hat)\b.*\b(?:equals|equal\s+to)\b"#,
                #"(^|\s)(?:=|\+|-|\*|/|≤|≥|<|>)(\s|$)"#
            ]
        )
    }

    private static func isShortFormulaDense(_ text: String, events: [PostProcessingEvent]) -> Bool {
        let words = text
            .split { character in
                character.isWhitespace || character.isPunctuation
            }
        guard words.count <= 4 else {
            return false
        }
        guard !containsPlainEnglishBlocker(text), !containsCodeLikeBlocker(text) else {
            return false
        }
        guard !containsShortProsePredicate(text) else {
            return false
        }

        return events.contains { event in
            event.before != event.after
        }
    }

    private static func isFormulaLikeSequence(_ text: String, events: [PostProcessingEvent]) -> Bool {
        let words = normalizedWords(in: text)
        guard words.count > 4 else {
            return false
        }
        guard !containsPlainEnglishBlocker(text), !containsCodeLikeBlocker(text) else {
            return false
        }
        guard !containsShortProsePredicate(text) else {
            return false
        }
        guard events.contains(where: { $0.before != $0.after }) else {
            return false
        }

        var mathVocabularyCount = 0
        var hasStructuralMathToken = false

        for word in words {
            if isFormulaConnector(word) {
                continue
            }

            guard isFormulaVocabularyToken(word) else {
                return false
            }

            mathVocabularyCount += 1
            if isStructuralFormulaToken(word) {
                hasStructuralMathToken = true
            }
        }

        return hasStructuralMathToken && mathVocabularyCount >= 3
    }

    private static func containsShortProsePredicate(_ text: String) -> Bool {
        containsAny(
            text.lowercased(),
            patterns: [
                #"\b(?:is|are|means|mean|refers|significant|important)\b"#
            ]
        )
    }

    private static func normalizedWords(in text: String) -> [String] {
        text
            .lowercased()
            .split { character in
                !character.isLetter && !character.isNumber
            }
            .map(String.init)
    }

    private static func isFormulaConnector(_ word: String) -> Bool {
        ["and", "comma"].contains(word)
    }

    private static func isFormulaVocabularyToken(_ word: String) -> Bool {
        if MathLexicon.symbol(from: word, uppercaseLatinForStatistics: false) != nil {
            return true
        }
        if MathScriptCatalog.subscriptIndex(from: word) != nil {
            return true
        }
        return isStructuralFormulaToken(word)
            || [
                "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
                "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
                "seventeen", "eighteen", "nineteen", "twenty", "capital", "big"
            ].contains(word)
            || word.allSatisfy(\.isNumber)
    }

    private static func isStructuralFormulaToken(_ word: String) -> Bool {
        if MathLexicon.modifier(from: word) != nil {
            return true
        }
        return [
            "sub", "subscript", "super", "superscript", "plus", "minus", "times", "over",
            "divided", "by", "equal", "equals", "squared", "cubed"
        ].contains(word)
    }

    private static func containsAny(_ text: String, patterns: [String]) -> Bool {
        patterns.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }
}
