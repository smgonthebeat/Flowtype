import XCTest
@testable import VoiceInputApp

final class TranscriptPostProcessorTests: XCTestCase {
    func testNormalizationPipelineLeavesUserSpecificTermsToHotwords() {
        let processed = NormalizationPipeline.normalize(
            "今天讲 DEMO零零一",
            knownTerms: ["DEMO1001"]
        )

        XCTAssertEqual(processed, "今天讲 DEMO零零一")
    }

    func testAppliesNumericAndFillerProcessing() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true
        )

        let processed = TranscriptPostProcessor.process(
            "嗯，二零二四年十一月五号 theta hat equals x bar",
            options: options
        )

        XCTAssertEqual(processed, "2024年11月5号 theta hat equals x bar")
    }

    func testCanApplyFillerCleanupWithoutExtraNotationFormatting() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true
        )

        let processed = TranscriptPostProcessor.process(
            "嗯，我现在说呃，theta hat",
            options: options
        )

        XCTAssertEqual(processed, "我现在说 theta hat")
    }

    func testAppliesMathNotationOnlyWhenEnabled() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .latex
        )

        let processed = TranscriptPostProcessor.process(
            "theta hat equals x bar and sigma squared, beta one and theta zero",
            options: options
        )

        XCTAssertEqual(
            processed,
            #"\hat{\theta} equals \bar{x} and \sigma^2, \beta_1 and \theta_0"#
        )
    }

    func testMathNotationTemplatesRespectExistingEnableSwitch() {
        let disabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .latex
        )
        let enabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .latex
        )

        XCTAssertEqual(
            TranscriptPostProcessor.process("alpha hat and x sub i", options: disabledOptions),
            "alpha hat and x sub i"
        )
        XCTAssertEqual(
            TranscriptPostProcessor.process("alpha hat and x sub i", options: enabledOptions),
            #"\hat{\alpha} and x_i"#
        )
    }

    func testChatGPTNearMissIsProtectedFromMathHatRendering() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        for input in [
            "C hat GPT",
            "C head GPT",
            "C hat G P T",
            "chat GPT",
            "Chat G P T"
        ] {
            XCTAssertEqual(
                TranscriptPostProcessor.process(input, options: options),
                "ChatGPT",
                input
            )
        }
    }

    func testChatGPTFixDoesNotBlockRealCHatMath() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        XCTAssertEqual(
            TranscriptPostProcessor.process("C hat equals beta", options: options),
            "Ĉ equals β"
        )
    }

    func testMathNotationParserRunsWhenEnabledAfterNormalization() {
        let input = "嗯，Variance X. correlation xy. var x = 1."
        let disabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )
        let enabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        XCTAssertEqual(
            TranscriptPostProcessor.process(input, options: disabledOptions),
            "Variance X. correlation xy. var x = 1."
        )
        XCTAssertEqual(
            TranscriptPostProcessor.process(input, options: enabledOptions),
            "Var(X). Corr(X,Y). var x = 1."
        )
    }

    func testPhaseTwoMathNotationRunsAfterFillerCleanup() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        XCTAssertEqual(
            TranscriptPostProcessor.process("嗯，expectation x. standard error beta hat.", options: options),
            "E[X]. SE(β̂)."
        )
    }

    func testHotwordsDoNotTriggerBuiltInCourseCodeNormalization() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: false,
            knownTerms: ["DEMO1001"]
        )

        let processed = TranscriptPostProcessor.process(
            "今天讲 DEMO零零一",
            options: options
        )

        XCTAssertEqual(processed, "今天讲 DEMO零零一")
    }

    func testCanDisableSmartNumericFormatting() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false
        )

        let processed = TranscriptPostProcessor.process(
            "sheet 一 exercise 四",
            options: options
        )

        XCTAssertEqual(processed, "sheet 一 exercise 四")
    }

    func testPreservesTextAfterAcademicNormalization() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true
        )

        let processed = TranscriptPostProcessor.process(
            "我测试第一段。我今天讲DEMO1001。我今天讲一空 zero zero zero one。请打开 sheet e exercise four。请打开 Sheet 1 的 exercise。四B和C。请看 Q4 BNC。请看 A1 BNC。",
            options: options
        )

        XCTAssertEqual(
            processed,
            "我测试第一段。我今天讲DEMO1001。我今天讲一空 0 0 0 1。请打开 Sheet 1 Exercise 4。请打开 Sheet 1 Exercise 4(b) and (c)。请看 Q4(b) and (c)。请看 A1(b) and (c)。"
        )
    }

    func testNormalizesSegmentedQwenTranscript() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true
        )

        let processed = TranscriptPostProcessor.process(
            "我测试第一段。我今天讲一空零零零一。我今天讲一空零零零一。请打开 sheet 一 exercise 四，请打开 sheet 一的 exercise 四 b 和 c，请打开 q 四。BNC，请看A one BNC。",
            options: options
        )

        XCTAssertEqual(
            processed,
            "我测试第一段。我今天讲一空零零零一。我今天讲一空零零零一。请打开 Sheet 1 Exercise 4，请打开 Sheet 1 Exercise 4(b) and (c)，请打开 Q4(b) and (c)，请看A1(b) and (c)。"
        )
    }

    func testRepairsQFourMisheardAsShiBeforeBNC() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true
        )

        let processed = TranscriptPostProcessor.process(
            "请看 Q。是，BNC。",
            options: options
        )

        XCTAssertEqual(processed, "请看 Q4(b) and (c)。")
    }

    func testNormalizesExerciseQuestionReferences() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true
        )

        let processed = TranscriptPostProcessor.process(
            "我们现在讲 Exercise 3 Q 1，然后看 Exercise 3 Q two H。",
            options: options
        )

        XCTAssertEqual(processed, "我们现在讲 Exercise 3 Q1，然后看 Exercise 3 Q2(h)。")
    }

    func testNormalizesNeutralPunctuationPreferences() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true
        )

        let processed = TranscriptPostProcessor.process(
            "I'm testing Flowtype punctuation right now.This is not formal.I do not want.An exclamation mark here! 我没有想加感叹号！",
            options: options
        )

        XCTAssertEqual(
            processed,
            "I'm testing Flowtype punctuation right now. This is not formal. I do not want. An exclamation mark here. 我没有想加感叹号。"
        )
    }

    func testEnglishSentenceSpacingDoesNotSplitCommonAbbreviationsOrDomains() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false
        )

        let processed = TranscriptPostProcessor.process(
            "Open flowtype.app.Then compare e.g.This case with U.S.A.Today.",
            options: options
        )

        XCTAssertEqual(
            processed,
            "Open flowtype.app. Then compare e.g. This case with U.S.A.Today."
        )
    }

    func testExclamationCleanupPreservesNotEqualOperator() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false
        )

        let processed = TranscriptPostProcessor.process("x != y!Then continue.", options: options)

        XCTAssertEqual(processed, "x != y. Then continue.")
    }

    func testMathProfileCorrectsVariantOfXToRenderedVariance() {
        let disabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )
        let enabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        XCTAssertEqual(
            TranscriptPostProcessor.process("variant of X", options: disabledOptions),
            "variant of X"
        )
        XCTAssertEqual(
            TranscriptPostProcessor.process("variant of X", options: enabledOptions),
            "Var(X)"
        )
    }

    func testMathProfileCorrectsStandardErrorBetterHeadToRenderedBetaHat() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        XCTAssertEqual(
            TranscriptPostProcessor.process("SE better head", options: options),
            "SE(β̂)"
        )
        XCTAssertEqual(
            TranscriptPostProcessor.process("standard arrow better hat", options: options),
            "SE(β̂)"
        )
        XCTAssertEqual(
            TranscriptPostProcessor.process("standard arrow beta head", options: options),
            "SE(β̂)"
        )
        XCTAssertEqual(
            TranscriptPostProcessor.process("standard arrow message", options: options),
            "standard arrow message"
        )
    }

    func testMathModeKeepsDefinitionQuestionsPlain() {
        let options = mathUnicodeOptions()

        let cases: [(String, String)] = [
            (
                "what does ETN stand for in financial products?",
                "what does ETN stand for in financial products?"
            ),
            (
                "what does E T N stand for in financial products?",
                "what does E T N stand for in financial products?"
            ),
            (
                "W hat does E T N stand for in financial products?",
                "W hat does E T N stand for in financial products?"
            ),
            (
                "what is E T in finance?",
                "what is E T in finance?"
            ),
            (
                "how does W hat affect the sentence?",
                "how does W hat affect the sentence?"
            )
        ]

        for (input, expected) in cases {
            XCTAssertEqual(
                TranscriptPostProcessor.process(input, options: options),
                expected,
                input
            )
        }
    }

    func testMathModeKeepsCodeLikeProsePlain() {
        let options = mathUnicodeOptions()

        XCTAssertEqual(
            TranscriptPostProcessor.process("write standard error beta hat in Swift", options: options),
            "write standard error beta hat in Swift"
        )
    }

    func testMathModeKeepsPathCommandPlainWhenFormatterCouldChangeTrailingGreek() {
        let options = mathUnicodeOptions()

        XCTAssertEqual(
            TranscriptPostProcessor.process("open docs/alpha and beta", options: options),
            "open docs/alpha and beta"
        )
    }

    func testMathModeStillAcceptsShortFormulaDictation() {
        let options = mathUnicodeOptions()

        let cases: [(String, String)] = [
            ("E T", "E[T]"),
            ("expectation T", "E[T]"),
            ("beta hat", "β̂"),
            ("theta hat", "θ̂"),
            ("standard error beta hat", "SE(β̂)"),
            ("standard arrow better hat", "SE(β̂)"),
            ("C hat equals beta", "Ĉ equals β"),
            ("W hat equals zero", "Ŵ equals 0")
        ]

        for (input, expected) in cases {
            XCTAssertEqual(
                TranscriptPostProcessor.process(input, options: options),
                expected,
                input
            )
        }
    }

    func testMathDecisionTraceRecordsWhenPlainEnglishWins() {
        let options = mathUnicodeOptions()

        let result = TranscriptPostProcessor.processWithTrace(
            "W hat does E T N stand for in financial products?",
            options: options
        )

        XCTAssertEqual(result.text, "W hat does E T N stand for in financial products?")

        let candidateStage = result.trace.stages.first { $0.stage == .candidateScoring }
        XCTAssertEqual(candidateStage?.input, "W hat does E T N stand for in financial products?")
        XCTAssertEqual(candidateStage?.output, "W hat does E T N stand for in financial products?")
        XCTAssertTrue(
            candidateStage?.events.contains {
                $0.ruleID == "math.intent-gate" &&
                $0.reason.contains("plain-English blocker")
            } == true
        )
    }

    func testProcessingTraceRecordsConfusionAndMathStages() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        let result = TranscriptPostProcessor.processWithTrace("variant of X", options: options)

        XCTAssertEqual(result.text, "Var(X)")
        XCTAssertEqual(result.trace.profile, .mathStatistics)
        XCTAssertTrue(result.trace.stages.contains { $0.stage == .confusionCorrection })
        XCTAssertTrue(result.trace.stages.contains { $0.stage == .mathNotation })
        XCTAssertTrue(
            result.trace.stages
                .flatMap(\.events)
                .contains { $0.ruleID == "variance.variant-of-symbol" }
        )
    }

    func testProcessingTraceKeepsRawOriginalTextBeforeTrimming() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )

        let result = TranscriptPostProcessor.processWithTrace("  variant of X  ", options: options)

        XCTAssertEqual(result.text, "variant of X")
        XCTAssertEqual(result.trace.originalText, "  variant of X  ")
    }

    private func mathUnicodeOptions() -> TranscriptProcessingOptions {
        TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )
    }
}
