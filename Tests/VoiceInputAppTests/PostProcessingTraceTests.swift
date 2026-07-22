import XCTest
@testable import VoiceInputApp

final class PostProcessingTraceTests: XCTestCase {
    func testResolvesGeneralProfileWhenMathNotationIsDisabled() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )

        XCTAssertEqual(TranscriptProcessingProfile.resolve(from: options), .general)
    }

    func testResolvesMathStatisticsProfileWhenMathNotationIsEnabled() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
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
}
