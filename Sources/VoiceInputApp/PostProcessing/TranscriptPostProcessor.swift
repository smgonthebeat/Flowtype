import Foundation

struct TranscriptProcessingOptions {
    let isSmartNumericFormattingEnabled: Bool
    let isAcademicReferenceFormattingEnabled: Bool
    let isFillerCleanupEnabled: Bool
    let isMathNotationEnabled: Bool
    let mathNotationOutputFormat: MathNotationOutputFormat
    let knownTerms: [String]

    init(
        isSmartNumericFormattingEnabled: Bool,
        isAcademicReferenceFormattingEnabled: Bool,
        isFillerCleanupEnabled: Bool,
        isMathNotationEnabled: Bool = false,
        mathNotationOutputFormat: MathNotationOutputFormat = .latex,
        knownTerms: [String] = []
    ) {
        self.isSmartNumericFormattingEnabled = isSmartNumericFormattingEnabled
        self.isAcademicReferenceFormattingEnabled = isAcademicReferenceFormattingEnabled
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
        var processed = CodeSpanDetector.trimOutsideCode(text)
        if options.isMathNotationEnabled {
            // The sentinels mark rendered formulas; any already in the input carry no meaning.
            processed = MathStage.stripSentinels(processed)
        }
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
        let technicalTermResult = TechnicalTermNormalizer.normalize(processed, knownTerms: options.knownTerms)
        processed = technicalTermResult.text
        if processed != technicalTermInput || !technicalTermResult.events.isEmpty {
            trace.append(
                stage: .technicalTerms,
                input: technicalTermInput,
                output: processed,
                events: technicalTermResult.events
            )
        }

        // The math layer sees the spoken words before study references, numbers and letter
        // spelling rewrite them (design.md 2). Each rendered formula is wrapped in sentinels, so
        // every later stage treats it as a protected span (design.md 8.1).
        if options.isMathNotationEnabled {
            let mathInput = processed
            let math = MathStage.run(
                processed,
                outputFormat: options.mathNotationOutputFormat,
                knownTerms: options.knownTerms,
                wrapInSentinels: true
            )
            processed = math.text
            trace.append(stage: .mathNotation, input: mathInput, output: processed, events: math.events)
        }

        if options.isAcademicReferenceFormattingEnabled {
            let academicInput = processed
            processed = applyAcademicReferenceFormatting(to: processed, options: options)
            trace.append(stage: .normalization, input: academicInput, output: processed)
        }

        let fillerInput = processed
        if options.isFillerCleanupEnabled {
            let context = NormalizationContext(
                knownTerms: options.knownTerms,
                protectedSpans: ProtectedSpanDetector.detect(in: fillerInput)
            )
            let fillerResult = FillerCleanupFormatter.formatWithEvents(
                fillerInput,
                context: context
            )
            processed = fillerResult.text
            trace.append(
                stage: .fillerCleanup,
                input: fillerInput,
                output: processed,
                events: fillerResult.events
            )
        } else {
            trace.append(
                stage: .fillerCleanup,
                input: fillerInput,
                output: fillerInput
            )
        }

        // Numeric decisions are made on filler-settled text, so a filler can neither create
        // nor hide numeric evidence (M19).
        if options.isSmartNumericFormattingEnabled {
            let numericInput = processed
            let numeric = NormalizationPipeline.normalizeWithEvents(processed, knownTerms: options.knownTerms)
            processed = numeric.text
            trace.append(stage: .normalization, input: numericInput, output: processed, events: numeric.events)
        }

        // Spelling joins the complete letter runs that remain after filler deletion.
        let spellingInput = processed
        let spelling = SpelledLetterNormalizer.normalize(
            processed,
            protectedRanges: SharedProtection.ranges(in: processed, knownTerms: options.knownTerms)
        )
        processed = spelling.text
        if processed != spellingInput {
            trace.append(stage: .technicalTerms, input: spellingInput, output: processed, events: spelling.events)
        }

        // Single-letter designators join their number once spelling and numbers are settled.
        if options.isSmartNumericFormattingEnabled {
            let designatorInput = processed
            let designators = DesignatorJoiner.join(processed, knownTerms: options.knownTerms)
            processed = designators.text
            if processed != designatorInput {
                trace.append(stage: .normalization, input: designatorInput, output: processed, events: designators.events)
            }
        }

        let cleanupInput = processed
        processed = cleanupWhitespace(in: processed, knownTerms: options.knownTerms)
        trace.append(stage: .finalCleanup, input: cleanupInput, output: processed)

        if options.isMathNotationEnabled {
            // No sentinel survives into the output or the diagnostics trace (I10).
            processed = MathStage.stripSentinels(processed)
            trace.stages = trace.stages.map {
                PostProcessingStageTrace(
                    stage: $0.stage,
                    input: MathStage.stripSentinels($0.input),
                    output: MathStage.stripSentinels($0.output),
                    events: $0.events
                )
            }
        }

        return TranscriptProcessingResult(text: processed, trace: trace)
    }

    private static func applyAcademicReferenceFormatting(
        to text: String,
        options: TranscriptProcessingOptions
    ) -> String {
        // Mark complete raw letter runs as opaque to academic rewrites without
        // splitting the sentence and losing its section/reference context.
        let spellingSpans = SpelledLetterNormalizer.rawLetterRanges(in: text).map {
            ProtectedSpan(range: $0, kind: .spelledLetters, text: String(text[$0]))
        }
        let context = NormalizationContext(
            knownTerms: options.knownTerms,
            protectedSpans: ProtectedSpanDetector.detect(in: text) + spellingSpans
        )
        return AcademicReferenceNormalizer.normalize(text, context: context)
    }

    private static func cleanupWhitespace(in text: String, knownTerms: [String]) -> String {
        // Final cleanup honours the same protected spans as every other stage.
        SharedProtection.transformUnprotected(in: text, knownTerms: knownTerms, using: cleanupUnprotectedWhitespace)
    }

    private static func cleanupUnprotectedWhitespace(in text: String) -> String {
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
            } else if character == "!", !isNotEqualOperator(at: index, in: text),
                      !isPrefixOperator(at: index, in: text) {
                result.append(".")
            } else {
                result.append(character)
            }
            index = text.index(after: index)
        }

        return result
    }

    /// `!important`, `!isReady`: a prefix operator before an identifier is not punctuation.
    private static func isPrefixOperator(at index: String.Index, in text: String) -> Bool {
        let nextIndex = text.index(after: index)
        guard nextIndex < text.endIndex, isASCIIAlphanumeric(text[nextIndex]) || text[nextIndex] == "_" else {
            return false
        }
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        return previous.isWhitespace || "([{,=:;".contains(previous)
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
        // A period needs sentence evidence: ASP.NET, Node.JS, Program.Main stay joined.
        if text[punctuationIndex] == "." {
            var rightEnd = nextIndex
            while rightEnd < text.endIndex, isASCIILetter(text[rightEnd]) { rightEnd = text.index(after: rightEnd) }
            // The left token is the whole dotted compound (Foundation.framework), not just its last part.
            var leftStart = precedingSegment.start
            while leftStart > text.startIndex {
                let previous = text.index(before: leftStart)
                guard isASCIIAlphanumeric(text[previous]) || text[previous] == "." else { break }
                leftStart = previous
            }
            let leftToken = text[leftStart..<punctuationIndex]
            return SentenceBoundary.isBoundary(left: leftToken, right: text[nextIndex..<rightEnd])
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

    private static func isASCIILetter(_ character: Character) -> Bool {
        guard let scalar = asciiScalar(for: character) else { return false }
        return (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
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
