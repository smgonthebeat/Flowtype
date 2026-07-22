import Foundation

struct ASRConfusionCorrectionResult: Equatable {
    let text: String
    let events: [PostProcessingEvent]
}

enum ASRConfusionCorrector {
    private static let mathModifierPattern = #"(?:double\s+prime|double\s+dot|transpose|inverse|squared|square|cubed|cube|overbar|head|hat|bar|tilde|dot|prime|star|asterisk)"#

    private static let mathSymbolArgumentPattern =
        MathSymbolCatalog.asrArgumentSymbolPattern
        + #"(?:\s+"# + mathModifierPattern + #"|\s+sub\s+(?:"# + MathScriptCatalog.subscriptPattern + #"))?"#

    private static let variantOfSymbolRegex = try! NSRegularExpression(
        pattern: #"\bvariants?\s+of\s+("# + mathSymbolArgumentPattern + #")\b"#,
        options: [.caseInsensitive]
    )

    private static let spacedStandardDeviationRegex = try! NSRegularExpression(
        pattern: #"\bs\s+d\s+("# + mathSymbolArgumentPattern + #")\b"#,
        options: [.caseInsensitive]
    )

    private static let standardErrorNearMissRegex = try! NSRegularExpression(
        pattern: #"\b(standard\s+(?:error|arrow)|s\s*e|se)\s+(better|bad|beta)\s+(?:head|hat)\b"#,
        options: [.caseInsensitive]
    )

    private static let coreCorrelationRegex = try! NSRegularExpression(
        pattern: #"\bcore\s+("# + mathSymbolArgumentPattern + #")\s+("# + mathSymbolArgumentPattern + #")\b"#,
        options: [.caseInsensitive]
    )

    private static let chiSquaredPrefixPattern = #"(?:\b(?:k|kite|key|kia|chi|kai|cai|coy|car\s+is)|(?:开|凯|卡伊))"#
    private static let chiSquaredPowerWordPattern = #"(?:squared?|square|squad|squid|spread)"#
    private static let chiSquaredSpokenHeadPattern = chiSquaredPrefixPattern + #"\s*"# + chiSquaredPowerWordPattern
    private static let chiSquaredRenderedHeadPattern = #"\b(?:k|χ|chi)\s*(?:²|\^2)"#
    private static let chiSquaredHeadPattern = #"(?:"# + chiSquaredSpokenHeadPattern + #"|"# + chiSquaredRenderedHeadPattern + #")"#
    private static let degreeCountPattern = #"(?:[0-9]+|zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|(?:twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)(?:\s+(?:one|two|three|four|five|six|seven|eight|nine))?|[零〇一二两三四五六七八九十百]+)"#

    private static let chiSquaredDegreesOfFreedomRegex = try! NSRegularExpression(
        pattern: chiSquaredHeadPattern + #"\s+(?:with|of)\s+("# + degreeCountPattern + #")\s+degrees?\s+of\s+freedom\b"#,
        options: [.caseInsensitive]
    )

    private static let chiSquaredDistributionRegex = try! NSRegularExpression(
        pattern: chiSquaredHeadPattern + #"\s+distribution\b"#,
        options: [.caseInsensitive]
    )

    private static let standaloneChiSquaredNearMissRegex = try! NSRegularExpression(
        pattern: #"(?:开|凯|卡伊)\s*(?:squared?|square|squad|squid)\b"#,
        options: [.caseInsensitive]
    )

    static func correct(
        _ text: String,
        profile: TranscriptProcessingProfile,
        knownTerms: [String] = []
    ) -> ASRConfusionCorrectionResult {
        guard profile == .mathStatistics else {
            return ASRConfusionCorrectionResult(text: text, events: [])
        }

        var collectedEvents: [PostProcessingEvent] = []
        let corrected = MathProtectedSegmenter.formatUnprotectedSegments(
            in: text,
            knownTerms: knownTerms
        ) { segment in
            let result = correctUnprotectedSegment(segment)
            collectedEvents.append(contentsOf: result.events)
            return result.text
        }

        return ASRConfusionCorrectionResult(text: corrected, events: collectedEvents)
    }

    private static func correctUnprotectedSegment(_ segment: String) -> ASRConfusionCorrectionResult {
        var current = segment
        var events: [PostProcessingEvent] = []

        let varianceResult = replaceVariantOfMathSymbol(in: current)
        current = varianceResult.text
        events.append(contentsOf: varianceResult.events)

        let standardDeviationResult = replaceSpacedStandardDeviation(in: current)
        current = standardDeviationResult.text
        events.append(contentsOf: standardDeviationResult.events)

        let betaHatResult = replaceStandardErrorBetaHatNearMisses(in: current)
        current = betaHatResult.text
        events.append(contentsOf: betaHatResult.events)

        let correlationResult = replaceCoreCorrelation(in: current)
        current = correlationResult.text
        events.append(contentsOf: correlationResult.events)

        let chiSquaredResult = replaceChiSquaredDegreesOfFreedom(in: current)
        current = chiSquaredResult.text
        events.append(contentsOf: chiSquaredResult.events)

        let chiSquaredDistributionResult = replaceChiSquaredDistribution(in: current)
        current = chiSquaredDistributionResult.text
        events.append(contentsOf: chiSquaredDistributionResult.events)

        let standaloneChiSquaredResult = replaceStandaloneChiSquaredNearMiss(in: current)
        current = standaloneChiSquaredResult.text
        events.append(contentsOf: standaloneChiSquaredResult.events)

        return ASRConfusionCorrectionResult(text: current, events: events)
    }

    private static func replaceVariantOfMathSymbol(in text: String) -> ASRConfusionCorrectionResult {
        replaceMatches(
            in: text,
            regex: variantOfSymbolRegex,
            ruleID: "variance.variant-of-symbol",
            confidence: .high
        ) { matchText, match in
            guard let argumentPhrase = group(1, in: match, text: matchText),
                  MathSpeechParser.parseArgumentExpression(argumentPhrase) != nil,
                  let matchRange = Range(match.range, in: matchText) else {
                return nil
            }

            let original = String(matchText[matchRange])
            let corrected = "variance of \(argumentPhrase)"
            let hasPlainEnglishBlocker = hasVariantOfPlainEnglishContinuation(in: matchText, from: matchRange.upperBound)
            return acceptedCorrection(
                original: original,
                corrected: corrected,
                hasMathSignal: true,
                hasPlainEnglishBlocker: hasPlainEnglishBlocker,
                hasCodeLikeBlocker: false
            )
        }
    }

    private static func hasVariantOfPlainEnglishContinuation(in text: String, from start: String.Index) -> Bool {
        let nextWord = nextWord(in: text, from: start)
        return [
            "release",
            "releases",
            "version",
            "versions",
            "product",
            "products",
            "feature",
            "features"
        ].contains(nextWord)
    }

    private static func nextWord(in text: String, from start: String.Index) -> String {
        var cursor = start
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }

        let wordStart = cursor
        while cursor < text.endIndex, text[cursor].isLetter {
            cursor = text.index(after: cursor)
        }

        guard wordStart < cursor else {
            return ""
        }

        return MathLexicon.normalizeSpaces(String(text[wordStart..<cursor]))
    }

    private static func replaceSpacedStandardDeviation(in text: String) -> ASRConfusionCorrectionResult {
        replaceMatches(
            in: text,
            regex: spacedStandardDeviationRegex,
            ruleID: "standard-deviation.spaced-abbreviation",
            confidence: .high
        ) { matchText, match in
            guard let argumentPhrase = group(1, in: match, text: matchText),
                  MathSpeechParser.parseArgumentExpression(argumentPhrase) != nil,
                  let matchRange = Range(match.range, in: matchText) else {
                return nil
            }

            let original = String(matchText[matchRange])
            let hasPlainEnglishBlocker = !hasStrongSingleArgumentMathSignal(argumentPhrase)
            let corrected = "standard deviation \(argumentPhrase)"
            return acceptedCorrection(
                original: original,
                corrected: corrected,
                hasMathSignal: !hasPlainEnglishBlocker,
                hasPlainEnglishBlocker: hasPlainEnglishBlocker,
                hasCodeLikeBlocker: false
            )
        }
    }

    private static func replaceStandardErrorBetaHatNearMisses(in text: String) -> ASRConfusionCorrectionResult {
        replaceMatches(
            in: text,
            regex: standardErrorNearMissRegex,
            ruleID: "standard-error.beta-hat-near-miss",
            confidence: .high
        ) { matchText, match in
            guard let functionPhrase = group(1, in: match, text: matchText),
                  let matchRange = Range(match.range, in: matchText) else {
                return nil
            }

            let original = String(matchText[matchRange])
            let corrected = "\(canonicalStandardErrorPrefix(functionPhrase)) beta hat"
            return acceptedCorrection(
                original: original,
                corrected: corrected,
                hasMathSignal: true,
                hasPlainEnglishBlocker: false,
                hasCodeLikeBlocker: false
            )
        }
    }

    private static func replaceCoreCorrelation(in text: String) -> ASRConfusionCorrectionResult {
        replaceMatches(
            in: text,
            regex: coreCorrelationRegex,
            ruleID: "correlation.core-two-symbols",
            confidence: .high
        ) { matchText, match in
            guard let firstArgument = group(1, in: match, text: matchText),
                  let secondArgument = group(2, in: match, text: matchText),
                  MathSpeechParser.parseArgumentExpression(firstArgument) != nil,
                  MathSpeechParser.parseArgumentExpression(secondArgument) != nil,
                  let matchRange = Range(match.range, in: matchText) else {
                return nil
            }

            let original = String(matchText[matchRange])
            let corrected = "corr \(firstArgument) \(secondArgument)"
            let hasPlainEnglishBlocker = !hasStrongBinaryArgumentMathSignal(firstArgument, secondArgument)
            return acceptedCorrection(
                original: original,
                corrected: corrected,
                hasMathSignal: !hasPlainEnglishBlocker,
                hasPlainEnglishBlocker: hasPlainEnglishBlocker,
                hasCodeLikeBlocker: false
            )
        }
    }

    private static func replaceChiSquaredDegreesOfFreedom(in text: String) -> ASRConfusionCorrectionResult {
        replaceMatches(
            in: text,
            regex: chiSquaredDegreesOfFreedomRegex,
            ruleID: "chi-square.k-squared-dof",
            confidence: .high
        ) { matchText, match in
            guard let countPhrase = group(1, in: match, text: matchText),
                  let canonicalCount = canonicalDegreeCount(countPhrase),
                  let matchRange = Range(match.range, in: matchText) else {
                return nil
            }

            let original = String(matchText[matchRange])
            let degreeWord = canonicalCount == "1" ? "degree" : "degrees"
            let corrected = "chi squared with \(canonicalCount) \(degreeWord) of freedom"
            return acceptedCorrection(
                original: original,
                corrected: corrected,
                hasMathSignal: true,
                hasPlainEnglishBlocker: false,
                hasCodeLikeBlocker: false
            )
        }
    }

    private static func replaceChiSquaredDistribution(in text: String) -> ASRConfusionCorrectionResult {
        replaceMatches(
            in: text,
            regex: chiSquaredDistributionRegex,
            ruleID: "chi-square.distribution-near-miss",
            confidence: .high
        ) { matchText, match in
            guard let matchRange = Range(match.range, in: matchText) else {
                return nil
            }

            let original = String(matchText[matchRange])
            return acceptedCorrection(
                original: original,
                corrected: "chi squared distribution",
                hasMathSignal: true,
                hasPlainEnglishBlocker: false,
                hasCodeLikeBlocker: false
            )
        }
    }

    private static func replaceStandaloneChiSquaredNearMiss(in text: String) -> ASRConfusionCorrectionResult {
        replaceMatches(
            in: text,
            regex: standaloneChiSquaredNearMissRegex,
            ruleID: "chi-square.standalone-near-miss",
            confidence: .medium
        ) { matchText, match in
            guard let matchRange = Range(match.range, in: matchText) else {
                return nil
            }

            let original = String(matchText[matchRange])
            return acceptedCorrection(
                original: original,
                corrected: "chi squared",
                hasMathSignal: true,
                hasPlainEnglishBlocker: false,
                hasCodeLikeBlocker: false
            )
        }
    }

    private static func canonicalDegreeCount(_ phrase: String) -> String? {
        SpokenNumberParser.numberOrEnglishNumber(MathLexicon.normalizeSpaces(phrase)).map(String.init)
    }

    private static func acceptedCorrection(
        original: String,
        corrected: String,
        hasMathSignal: Bool,
        hasPlainEnglishBlocker: Bool,
        hasCodeLikeBlocker: Bool
    ) -> String? {
        let candidates = [
            TranscriptCandidate(text: original, source: .original, transformations: []),
            TranscriptCandidate(text: corrected, source: .confusionCorrected, transformations: [])
        ]
        let context = CandidateScoringContext(
            profile: .mathStatistics,
            sourceText: original,
            hasMathSignal: hasMathSignal,
            hasPlainEnglishBlocker: hasPlainEnglishBlocker,
            hasCodeLikeBlocker: hasCodeLikeBlocker
        )

        return CandidateScorer.choose(candidates, context: context)?.source == .confusionCorrected
            ? corrected
            : nil
    }

    private static func hasStrongSingleArgumentMathSignal(_ phrase: String) -> Bool {
        let normalized = MathLexicon.normalizeSpaces(phrase)
        if strongLatinVariableNames.contains(normalized) || strongGreekVariableNames.contains(normalized) {
            return true
        }
        return normalized.contains(" ")
            && MathSpeechParser.parseArgumentExpression(normalized) != nil
            && !shortPlainEnglishAcronymArguments.contains(normalized)
    }

    private static func hasStrongBinaryArgumentMathSignal(_ first: String, _ second: String) -> Bool {
        let normalizedFirst = MathLexicon.normalizeSpaces(first)
        let normalizedSecond = MathLexicon.normalizeSpaces(second)
        guard !shortPlainEnglishAcronymArguments.contains("\(normalizedFirst) \(normalizedSecond)") else {
            return false
        }
        return hasStrongCorrelationArgumentSignal(normalizedFirst)
            && hasStrongCorrelationArgumentSignal(normalizedSecond)
    }

    private static func hasStrongCorrelationArgumentSignal(_ phrase: String) -> Bool {
        strongLatinVariableNames.contains(phrase)
            || strongGreekVariableNames.contains(phrase)
            || phrase.contains(" ")
    }

    private static let strongLatinVariableNames: Set<String> = [
        "x", "y", "z"
    ]

    private static let strongGreekVariableNames: Set<String> = Set(
        MathSymbolCatalog.allGreek
            .flatMap(\.allParserForms)
            .map(MathLexicon.normalizeSpaces)
    )

    private static let shortPlainEnglishAcronymArguments: Set<String> = [
        "i", "d", "i d", "u s", "u k", "a i"
    ]

    private static func replaceMatches(
        in text: String,
        regex: NSRegularExpression,
        ruleID: String,
        confidence: CandidateConfidence,
        replacement: (String, NSTextCheckingResult) -> String?
    ) -> ASRConfusionCorrectionResult {
        var result = ""
        var searchStart = text.startIndex
        var events: [PostProcessingEvent] = []
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match,
                  let matchRange = Range(match.range, in: text),
                  matchRange.lowerBound >= searchStart,
                  let replacementText = replacement(text, match) else {
                return
            }

            let before = String(text[matchRange])
            result += text[searchStart..<matchRange.lowerBound]
            result += replacementText
            events.append(
                PostProcessingEvent(
                    ruleID: ruleID,
                    rangeDescription: "segment:\(match.range.location)..<\(match.range.location + match.range.length)",
                    before: before,
                    after: replacementText,
                    reason: "math profile ASR confusion correction",
                    confidence: confidence
                )
            )
            searchStart = matchRange.upperBound
        }

        result += text[searchStart..<text.endIndex]
        return ASRConfusionCorrectionResult(text: result, events: events)
    }

    private static func canonicalStandardErrorPrefix(_ phrase: String) -> String {
        switch MathLexicon.normalizeSpaces(phrase) {
        case "se":
            return "SE"
        case "standard arrow":
            return "standard error"
        case "s e":
            return "standard error"
        default:
            return "standard error"
        }
    }

    private static func group(_ index: Int, in match: NSTextCheckingResult, text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }
}
