import XCTest
@testable import VoiceInputApp

final class PostProcessingTraceTests: XCTestCase {
    func testResolvesGeneralProfileWhenMathNotationIsDisabled() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )

        XCTAssertEqual(TranscriptProcessingProfile.resolve(from: options), .general)
    }

    func testResolvesMathStatisticsProfileWhenMathNotationIsEnabled() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        XCTAssertEqual(TranscriptProcessingProfile.resolve(from: options), .mathStatistics)
    }

    func testStoresStageEventsForDebuggableProcessing() {
        let event = PostProcessingEvent(
            ruleID: "variance.variant-of-symbol",
            rangeDescription: "0..<12",
            before: "variant of X",
            after: "variance of X",
            reason: "math profile with variable argument",
            confidence: .high
        )
        let stage = PostProcessingStageTrace(
            stage: .confusionCorrection,
            input: "variant of X",
            output: "variance of X",
            events: [event]
        )
        let trace = PostProcessingTrace(
            originalText: "variant of X",
            profile: .mathStatistics,
            stages: [stage]
        )

        XCTAssertEqual(trace.originalText, "variant of X")
        XCTAssertEqual(trace.profile, .mathStatistics)
        XCTAssertEqual(trace.stages.first?.events.first?.ruleID, "variance.variant-of-symbol")
        XCTAssertEqual(trace.stages.first?.events.first?.confidence, .high)
    }

    func testFillerCleanupStageRecordsAcceptedEditWhenEnabled() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: true
        )

        let result = TranscriptPostProcessor.processWithTrace(
            "嗯，我现在先说结论",
            options: options
        )
        let stage = result.trace.stages.first { $0.stage == .fillerCleanup }

        XCTAssertEqual(stage?.input, "嗯，我现在先说结论")
        XCTAssertEqual(stage?.output, "我现在先说结论")
        XCTAssertEqual(stage?.events.count, 1)
        XCTAssertEqual(stage?.events.first?.ruleID, "filler.contextual.whole.start-continuation")
        XCTAssertEqual(stage?.events.first?.before, "嗯，")
        XCTAssertEqual(stage?.events.first?.after, "")
    }

    func testFillerCleanupStageIsIdentityWithNoEventsWhenDisabled() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false
        )

        let result = TranscriptPostProcessor.processWithTrace(
            "嗯，我现在先说结论",
            options: options
        )
        let stages = result.trace.stages.filter { $0.stage == .fillerCleanup }

        XCTAssertEqual(stages.count, 1)
        XCTAssertEqual(stages.first?.input, "嗯，我现在先说结论")
        XCTAssertEqual(stages.first?.output, "嗯，我现在先说结论")
        XCTAssertEqual(stages.first?.events, [])
    }
}
