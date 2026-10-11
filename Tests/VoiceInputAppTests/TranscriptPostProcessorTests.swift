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
            isAcademicReferenceFormattingEnabled: false,
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
            isAcademicReferenceFormattingEnabled: false,
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
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .latex
        )

        let processed = TranscriptPostProcessor.process(
            "theta hat equals x bar and sigma squared, beta one and theta zero",
            options: options
        )

        // Math rebuild: each formula is wrapped in $...$ (D1) and "equals" is a relation (design.md 5.2).
        XCTAssertEqual(
            processed,
            #"$\hat{\theta} = \bar{x}$ and $\sigma^2$, $\beta_1$ and $\theta_0$"#
        )
    }

    func testMathNotationTemplatesRespectExistingEnableSwitch() {
        let disabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .latex
        )
        let enabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
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
            // Math rebuild: each formula is wrapped in $...$ (D1).
            #"$\hat{\alpha}$ and $x_i$"#
        )
    }

    func testChatGPTNearMissIsProtectedFromMathHatRendering() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
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
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        XCTAssertEqual(
            TranscriptPostProcessor.process("C hat equals beta", options: options),
            // Math rebuild: a sentence-initial letter is lower case (D5); "equals" is a relation (design.md 5.2).
            "ĉ = β"
        )
    }

    func testMathNotationParserRunsWhenEnabledAfterNormalization() {
        let input = "嗯，Variance X. correlation xy. var x = 1."
        let disabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )
        let enabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: false,
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
            // Math rebuild: a space after the comma between arguments (D4).
            "Var(X). Corr(X, Y). var x = 1."
        )
    }

    func testPhaseTwoMathNotationRunsAfterFillerCleanup() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: false,
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
            isAcademicReferenceFormattingEnabled: false,
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
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false
        )

        let processed = TranscriptPostProcessor.process(
            "sheet 一 exercise 四",
            options: options
        )

        XCTAssertEqual(processed, "sheet 一 exercise 四")
    }

    func testAcademicReferenceAndSmartNumericCapabilitiesAreIndependent() {
        for smartNumericEnabled in [false, true] {
            for academicReferenceEnabled in [false, true] {
                let options = TranscriptProcessingOptions(
                    isSmartNumericFormattingEnabled: smartNumericEnabled,
                    isAcademicReferenceFormattingEnabled: academicReferenceEnabled,
                    isFillerCleanupEnabled: false
                )

                let academicExpected: String
                if academicReferenceEnabled {
                    academicExpected = "Exercise 3 Q2(h)."
                } else if smartNumericEnabled {
                    academicExpected = "Exercise 3 Q 2 H."
                } else {
                    academicExpected = "Exercise three Q two H."
                }

                XCTAssertEqual(
                    TranscriptPostProcessor.process(
                        "Exercise three Q two H.",
                        options: options
                    ),
                    academicExpected,
                    "smart=\(smartNumericEnabled), academic=\(academicReferenceEnabled)"
                )
                XCTAssertEqual(
                    TranscriptPostProcessor.process(
                        "二零二四年十一月五号",
                        options: options
                    ),
                    smartNumericEnabled ? "2024年11月5号" : "二零二四年十一月五号",
                    "smart=\(smartNumericEnabled), academic=\(academicReferenceEnabled)"
                )
                XCTAssertEqual(
                    TranscriptPostProcessor.process("B2B.", options: options),
                    "B2B.",
                    "smart=\(smartNumericEnabled), academic=\(academicReferenceEnabled)"
                )
                XCTAssertEqual(
                    TranscriptPostProcessor.process("C2C.", options: options),
                    "C2C.",
                    "smart=\(smartNumericEnabled), academic=\(academicReferenceEnabled)"
                )
                XCTAssertEqual(
                    TranscriptPostProcessor.process("B3(b).", options: options),
                    "B3(b).",
                    "smart=\(smartNumericEnabled), academic=\(academicReferenceEnabled)"
                )
                XCTAssertEqual(
                    TranscriptPostProcessor.process("I have done.", options: options),
                    "I have done.",
                    "smart=\(smartNumericEnabled), academic=\(academicReferenceEnabled)"
                )
            }
        }
    }

    func testSpokenIdentifierFamilyIsIndependentOfAcademicReferenceCapability() {
        let inputs = [
            "B to B.",
            "C to C.",
            "B two B.",
            "B three B.",
            "C three C.",
            "A one H.",
            "X ninety nine Z."
        ]

        for smartNumericEnabled in [false, true] {
            let generalOptions = TranscriptProcessingOptions(
                isSmartNumericFormattingEnabled: smartNumericEnabled,
                isAcademicReferenceFormattingEnabled: false,
                isFillerCleanupEnabled: false
            )
            let studyOptions = TranscriptProcessingOptions(
                isSmartNumericFormattingEnabled: smartNumericEnabled,
                isAcademicReferenceFormattingEnabled: true,
                isFillerCleanupEnabled: false
            )

            for input in inputs {
                XCTAssertEqual(
                    TranscriptPostProcessor.process(input, options: studyOptions),
                    TranscriptPostProcessor.process(input, options: generalOptions),
                    "Academic Reference changed spoken identifier: \(input)"
                )
            }
        }
    }

    func testPreservesTextAfterAcademicNormalization() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: true,
            isFillerCleanupEnabled: true
        )

        let processed = TranscriptPostProcessor.process(
            "我测试第一段。我今天讲DEMO1001。我今天讲一空 zero zero zero one。请打开 sheet e exercise four。请打开 Sheet 1 的 exercise。四B和C。请看 Q4 BNC。请看 A1 BNC。",
            options: options
        )

        // fix-design 4.2 digit sequence: three or more spoken digits join (was "0 0 0 1").
        XCTAssertEqual(
            processed,
            "我测试第一段。我今天讲DEMO1001。我今天讲一空 0001。请打开 Sheet 1 Exercise 4。请打开 Sheet 1 Exercise 4(b) and (c)。请看 Q4(b) and (c)。请看 A1(b) and (c)。"
        )
    }

    func testNormalizesSegmentedQwenTranscript() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: true,
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
            isAcademicReferenceFormattingEnabled: true,
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
            isAcademicReferenceFormattingEnabled: true,
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
            isAcademicReferenceFormattingEnabled: false,
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
            isAcademicReferenceFormattingEnabled: false,
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
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false
        )

        let processed = TranscriptPostProcessor.process("x != y!Then continue.", options: options)

        XCTAssertEqual(processed, "x != y. Then continue.")
    }

    func testMathProfileCorrectsVariantOfXToRenderedVariance() {
        let disabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )
        let enabledOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: false,
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
            isAcademicReferenceFormattingEnabled: false,
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
                "what does ETN stand for in financial products?"
            ),
            (
                "W hat does E T N stand for in financial products?",
                "W hat does ETN stand for in financial products?"
            ),
            (
                "what is E T in finance?",
                "what is ET in finance?"
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
            // Math rebuild: the code-context rule covers short function names only (design.md 6.2,
            // "var x = 1", "let cos"); a long statistics name with an argument is a formula (design.md 5.3).
            // Listed for the owner in the rebuild record as a behaviour change.
            "write SE(β̂) in Swift"
        )
        XCTAssertEqual(
            TranscriptPostProcessor.process("write var x in Swift", options: options),
            "write var x in Swift"
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
            // Math rebuild: a sentence-initial letter is lower case (D5); "equals" is a relation (design.md 5.2).
            ("C hat equals beta", "ĉ = β"),
            ("W hat equals zero", "ŵ = 0")
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

        XCTAssertEqual(result.text, "W hat does ETN stand for in financial products?")

        // Math rebuild: the whole-transcript gate and its .candidateScoring stage are gone; each
        // candidate span records its own decision in the math stage (design.md 8.7). "W hat" is a
        // split English word, an alias without evidence of its own (design.md 6.3).
        XCTAssertFalse(result.trace.stages.contains { $0.stage == .candidateScoring })
        let mathStage = result.trace.stages.first { $0.stage == .mathNotation }
        XCTAssertEqual(mathStage?.input, "W hat does E T N stand for in financial products?")
        XCTAssertEqual(mathStage?.output, "W hat does E T N stand for in financial products?")
        XCTAssertTrue(
            mathStage?.events.contains {
                $0.ruleID == "math.span.rejected" && $0.before == "W hat"
            } == true
        )
    }

    func testProcessingTraceRecordsConfusionAndMathStages() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
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
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )

        let result = TranscriptPostProcessor.processWithTrace("  variant of X  ", options: options)

        XCTAssertEqual(result.text, "variant of X")
        XCTAssertEqual(result.trace.originalText, "  variant of X  ")
    }

    func testFillerCleanupReceivesKnownTermsAndDetectedProtectedSpans() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: true,
            knownTerms: ["Um"]
        )

        let result = TranscriptPostProcessor.processWithTrace(
            "Um, continue with https://example.com/um",
            options: options
        )
        let stage = result.trace.stages.first { $0.stage == .fillerCleanup }

        XCTAssertEqual(stage?.input, "Um, continue with https://example.com/um")
        XCTAssertEqual(stage?.output, "Um, continue with https://example.com/um")
        XCTAssertEqual(stage?.events, [])
    }

    func testFillerStageInputMatchesDisabledPassThroughForSameUpstreamOptions() {
        let enabled = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: true,
            isFillerCleanupEnabled: true
        )
        let disabled = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: true,
            isFillerCleanupEnabled: false
        )

        let enabledResult = TranscriptPostProcessor.processWithTrace(
            "嗯，二零二四年十一月五号 Exercise three Q two H.",
            options: enabled
        )
        let disabledResult = TranscriptPostProcessor.processWithTrace(
            "嗯，二零二四年十一月五号 Exercise three Q two H.",
            options: disabled
        )
        let enabledStage = enabledResult.trace.stages.first { $0.stage == .fillerCleanup }
        let disabledStage = disabledResult.trace.stages.first { $0.stage == .fillerCleanup }

        XCTAssertEqual(enabledStage?.input, disabledStage?.input)
        XCTAssertEqual(disabledStage?.input, disabledStage?.output)
        XCTAssertEqual(disabledStage?.events, [])
        // fix-design section 3 ordering: numeric runs after filler cleanup, so the filler stage
        // sees the date before numeric formatting; the final text is unchanged.
        XCTAssertEqual(enabledStage?.output, "二零二四年十一月五号 Exercise 3 Q2(h).")
        XCTAssertEqual(enabledStage?.events.count, 1)
        XCTAssertEqual(enabledResult.text, "2024年11月5号 Exercise 3 Q2(h).")
    }

    func testAllSixteenCapabilityCombinationsKeepFillerOwnershipIndependent() {
        struct CapabilityCase {
            let name: String
            let input: String
            let knownTerms: [String]
            let fillerOnStageOutput: String?
            var fillerOnStageOutputWithMath: String?
            let expectedFinal: (
                _ smartNumeric: Bool,
                _ academicReference: Bool,
                _ fillerCleanup: Bool,
                _ mathNotation: Bool
            ) -> String
        }

        let cases = [
            CapabilityCase(
                name: "normal Han lexical content",
                input: "余额。",
                knownTerms: [],
                fillerOnStageOutput: nil,
                expectedFinal: { _, _, _, _ in "余额。" }
            ),
            CapabilityCase(
                name: "English technical homograph",
                input: "Access and UHF radio.",
                knownTerms: [],
                fillerOnStageOutput: nil,
                expectedFinal: { _, _, _, _ in "Access and UHF radio." }
            ),
            CapabilityCase(
                name: "accepted Chinese filler",
                input: "嗯，我继续。",
                knownTerms: [],
                fillerOnStageOutput: "我继续。",
                expectedFinal: { _, _, filler, _ in filler ? "我继续。" : "嗯，我继续。" }
            ),
            CapabilityCase(
                name: "accepted English filler",
                input: "Um, continue.",
                knownTerms: [],
                fillerOnStageOutput: "continue.",
                expectedFinal: { _, _, filler, _ in filler ? "continue." : "Um, continue." }
            ),
            CapabilityCase(
                name: "adjacent mixed-language sequence",
                input: "嗯，um, continue.",
                knownTerms: [],
                fillerOnStageOutput: "continue.",
                expectedFinal: { _, _, filler, _ in filler ? "continue." : "嗯，um, continue." }
            ),
            CapabilityCase(
                name: "trailing Han edge",
                input: "我说呃，theta.",
                knownTerms: [],
                fillerOnStageOutput: "我说 theta.",
                // Math rebuild: the math stage now runs before filler cleanup (design.md 2, 8.7),
                // so with math on the filler stage sees the rendered formula.
                fillerOnStageOutputWithMath: "我说 θ.",
                expectedFinal: { _, _, filler, math in
                    let suffix = math ? "θ." : "theta."
                    return filler ? "我说 \(suffix)" : "我说呃，\(suffix)"
                }
            ),
            CapabilityCase(
                name: "academic reference",
                input: "Exercise three Q two H.",
                knownTerms: [],
                fillerOnStageOutput: nil,
                expectedFinal: { smart, academic, _, _ in
                    if academic { return "Exercise 3 Q2(h)." }
                    return smart ? "Exercise 3 Q 2 H." : "Exercise three Q two H."
                }
            ),
            CapabilityCase(
                name: "date",
                input: "二零二四年十一月五号",
                knownTerms: [],
                fillerOnStageOutput: nil,
                expectedFinal: { smart, _, _, _ in
                    smart ? "2024年11月5号" : "二零二四年十一月五号"
                }
            ),
            CapabilityCase(
                name: "percentage",
                input: "百分之三点五",
                knownTerms: [],
                fillerOnStageOutput: nil,
                expectedFinal: { smart, _, _, _ in smart ? "3.5%" : "百分之三点五" }
            ),
            CapabilityCase(
                name: "math and unit expression",
                input: "theta hat equals x bar and 5 kg",
                knownTerms: [],
                fillerOnStageOutput: nil,
                expectedFinal: { _, _, _, math in
                    // Math rebuild: "equals" is a relation (design.md 5.2).
                    math ? "θ̂ = x̄ and 5 kg" : "theta hat equals x bar and 5 kg"
                }
            ),
            CapabilityCase(
                name: "protected known term",
                input: "Um, https://example.com/um",
                knownTerms: ["Um"],
                fillerOnStageOutput: nil,
                expectedFinal: { _, _, _, _ in "Um, https://example.com/um" }
            ),
            CapabilityCase(
                name: "punctuation only",
                input: "?!",
                knownTerms: [],
                fillerOnStageOutput: nil,
                expectedFinal: { _, _, _, _ in "?." }
            )
        ]

        for smart in [false, true] {
            for academic in [false, true] {
                for math in [false, true] {
                    for testCase in cases {
                        var results: [Bool: TranscriptProcessingResult] = [:]
                        for filler in [false, true] {
                            let options = TranscriptProcessingOptions(
                                isSmartNumericFormattingEnabled: smart,
                                isAcademicReferenceFormattingEnabled: academic,
                                isFillerCleanupEnabled: filler,
                                isMathNotationEnabled: math,
                                mathNotationOutputFormat: .unicode,
                                knownTerms: testCase.knownTerms
                            )
                            let result = TranscriptPostProcessor.processWithTrace(
                                testCase.input,
                                options: options
                            )
                            results[filler] = result
                            XCTAssertEqual(
                                result.text,
                                testCase.expectedFinal(smart, academic, filler, math),
                                "\(testCase.name): smart=\(smart), academic=\(academic), filler=\(filler), math=\(math)"
                            )
                        }

                        let offStage = results[false]?.trace.stages.first { $0.stage == .fillerCleanup }
                        let onStage = results[true]?.trace.stages.first { $0.stage == .fillerCleanup }
                        XCTAssertEqual(onStage?.input, offStage?.input, testCase.name)
                        XCTAssertEqual(offStage?.input, offStage?.output, testCase.name)
                        XCTAssertEqual(offStage?.events, [], testCase.name)

                        let stageOutput = math
                            ? testCase.fillerOnStageOutputWithMath ?? testCase.fillerOnStageOutput
                            : testCase.fillerOnStageOutput
                        if let expected = stageOutput {
                            XCTAssertEqual(onStage?.output, expected, testCase.name)
                            XCTAssertEqual(onStage?.events.count, 1, testCase.name)
                        } else {
                            XCTAssertEqual(onStage?.output, onStage?.input, testCase.name)
                            XCTAssertEqual(onStage?.events, [], testCase.name)
                        }
                    }
                }
            }
        }
    }

    private func mathUnicodeOptions() -> TranscriptProcessingOptions {
        TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )
    }
}
