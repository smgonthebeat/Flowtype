import Foundation

struct TranscriptProcessingOptions {
    let isSmartNumericFormattingEnabled: Bool
    let isFillerCleanupEnabled: Bool
    let isMathNotationEnabled: Bool
    let mathNotationOutputFormat: MathNotationOutputFormat
    let knownTerms: [String]

    init(
        isSmartNumericFormattingEnabled: Bool,
        isFillerCleanupEnabled: Bool,
        isMathNotationEnabled: Bool = false,
        mathNotationOutputFormat: MathNotationOutputFormat = .latex,
        knownTerms: [String] = []
    ) {
        self.isSmartNumericFormattingEnabled = isSmartNumericFormattingEnabled
        self.isFillerCleanupEnabled = isFillerCleanupEnabled
        self.isMathNotationEnabled = isMathNotationEnabled
        self.mathNotationOutputFormat = mathNotationOutputFormat
        self.knownTerms = knownTerms
    }
}

enum TranscriptPostProcessor {
    static func process(_ text: String, options: TranscriptProcessingOptions) -> String {
        processWithTrace(text, options: options).text
    }

    static func processWithTrace(_ text: String, options: TranscriptProcessingOptions) -> TranscriptProcessingResult {
        let profile = TranscriptProcessingProfile.resolve(from: options)
        var processed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var trace = PostProcessingTrace(originalText: text, profile: profile, stages: [])

        let confusionInput = processed
        let confusionResult = ASRConfusionCorrector.correct(
            processed,
            profile: profile,
            knownTerms: options.knownTerms
        )
        processed = confusionResult.text
        trace.append(
            stage: .confusionCorrection,
            input: confusionInput,
            output: processed,
            events: confusionResult.events
        )

        let technicalTermInput = processed
        let technicalTermResult = TechnicalTermNormalizer.normalize(processed)
        processed = technicalTermResult.text
        if processed != technicalTermInput || !technicalTermResult.events.isEmpty {
            trace.append(
                stage: .technicalTerms,
                input: technicalTermInput,
                output: processed,
                events: technicalTermResult.events
            )
        }

        let normalizationInput = processed
        processed = applySmartNumericFormattingIfEnabled(to: processed, options: options)
        if options.isSmartNumericFormattingEnabled || processed != normalizationInput {
            trace.append(stage: .normalization, input: normalizationInput, output: processed)
        }

        if options.isFillerCleanupEnabled {
            let fillerInput = processed
            processed = FillerCleanupFormatter.format(processed)
            trace.append(stage: .fillerCleanup, input: fillerInput, output: processed)
        }

        if options.isMathNotationEnabled {
            let mathInput = processed
            let mathResult = MathNotationFormatter.formatWithEvents(
                processed,
                outputFormat: options.mathNotationOutputFormat,
                knownTerms: options.knownTerms
            )
            trace.append(
                stage: .mathNotation,
                input: mathInput,
                output: mathResult.text,
                events: mathResult.events
            )

            let decision = MathIntentGate.evaluate(
                original: mathInput,
                rendered: mathResult.text,
                events: mathResult.events,
                profile: profile
            )
            processed = decision.text
            trace.append(
                stage: .candidateScoring,
                input: mathInput,
                output: processed,
                events: [decision.decisionEvent]
            )
        }

        let cleanupInput = processed
        processed = cleanupWhitespace(in: processed)
        trace.append(stage: .finalCleanup, input: cleanupInput, output: processed)

        return TranscriptProcessingResult(text: processed, trace: trace)
    }

    private static func applySmartNumericFormattingIfEnabled(
        to text: String,
        options: TranscriptProcessingOptions
    ) -> String {
        guard options.isSmartNumericFormattingEnabled else {
            return text
        }

        return NormalizationPipeline.normalize(text, knownTerms: options.knownTerms)
    }

    private static func cleanupWhitespace(in text: String) -> String {
        var cleaned = normalizeExclamationMarks(in: text)
        cleaned = insertEnglishSentenceSpacing(in: cleaned)
        let collapsed = cleaned.replacingOccurrences(
            of: #"[ \t]{2,}"#,
            with: " ",
            options: .regularExpression
        )
        return collapsed.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
    }

    private static func normalizeExclamationMarks(in text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "！" {
                result.append("。")
            } else if character == "!", !isNotEqualOperator(at: index, in: text) {
                result.append(".")
            } else {
                result.append(character)
            }
            index = text.index(after: index)
        }

        return result
    }

    private static func isNotEqualOperator(at index: String.Index, in text: String) -> Bool {
        let nextIndex = text.index(after: index)
        return nextIndex < text.endIndex && text[nextIndex] == "="
    }

    private static func insertEnglishSentenceSpacing(in text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            result.append(character)

            let nextIndex = text.index(after: index)
            if shouldInsertEnglishSpace(afterPunctuationAt: index, nextIndex: nextIndex, in: text) {
                result.append(" ")
            }

            index = nextIndex
        }

        return result
    }

    private static func shouldInsertEnglishSpace(
        afterPunctuationAt punctuationIndex: String.Index,
        nextIndex: String.Index,
        in text: String
    ) -> Bool {
        guard nextIndex < text.endIndex else { return false }
        guard isEnglishSentenceBoundary(text[punctuationIndex]) else { return false }
        guard isASCIIUppercaseLetter(text[nextIndex]) else { return false }

        let precedingSegment = asciiAlphanumericSegment(before: punctuationIndex, in: text)
        guard !precedingSegment.text.isEmpty else { return false }
        if isDottedInitialismBoundary(
            precedingSegment: precedingSegment,
            nextIndex: nextIndex,
            in: text
        ) {
            return false
        }

        return true
    }

    private static func isEnglishSentenceBoundary(_ character: Character) -> Bool {
        character == "." || character == "?"
    }

    private static func asciiAlphanumericSegment(
        before index: String.Index,
        in text: String
    ) -> (text: String, start: String.Index) {
        var cursor = index
        var characters: [Character] = []

        while cursor > text.startIndex {
            let previousIndex = text.index(before: cursor)
            let character = text[previousIndex]
            guard isASCIIAlphanumeric(character) else { break }
            characters.insert(character, at: 0)
            cursor = previousIndex
        }

        return (String(characters), cursor)
    }

    private static func isDottedInitialismBoundary(
        precedingSegment: (text: String, start: String.Index),
        nextIndex: String.Index,
        in text: String
    ) -> Bool {
        guard precedingSegment.text.count == 1,
              let character = precedingSegment.text.first,
              isASCIIUppercaseLetter(character) else {
            return false
        }

        if precedingSegment.start > text.startIndex {
            let beforeSegmentIndex = text.index(before: precedingSegment.start)
            if text[beforeSegmentIndex] == "." {
                return true
            }
        }

        let afterNextIndex = text.index(after: nextIndex)
        return afterNextIndex < text.endIndex && text[afterNextIndex] == "."
    }

    private static func isASCIIAlphanumeric(_ character: Character) -> Bool {
        guard let scalar = asciiScalar(for: character) else { return false }
        return (65...90).contains(scalar.value)
            || (97...122).contains(scalar.value)
            || (48...57).contains(scalar.value)
    }

    private static func isASCIIUppercaseLetter(_ character: Character) -> Bool {
        guard let scalar = asciiScalar(for: character) else { return false }
        return (65...90).contains(scalar.value)
    }

    private static func asciiScalar(for character: Character) -> UnicodeScalar? {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first,
              scalar.isASCII else {
            return nil
        }
        return scalar
    }
}
