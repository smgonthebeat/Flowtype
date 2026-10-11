import XCTest
@testable import VoiceInputApp

final class EnglishPercentCompositionRepairTests: XCTestCase {
    func testRenderedDecimalNeverConsumesAnotherNumericFragment() {
        for input in ["3.5 60 percent", "3.5 6 percent", "3.50 10 percent", "3.5 six percent",
                      "3.05\t6 percent", "3.5 20 per cent"] {
            ResidualRepairAssertions.check(input, expected: { _ in input })
        }
    }

    func testSpokenFractionalDigitsAndAtomicDecimalsStillConvert() {
        for (input, output) in [("3 point five six percent", "3.56%"),
                                ("three point zero five percent", "3.05%"),
                                ("3 point 5 6 percent", "3.56%"),
                                ("3.560 percent", "3.560%"),
                                ("3.5 percent, 60 percent", "3.5%, 60%") ] {
            ResidualRepairAssertions.check(input, expected: {
                $0.isSmartNumericFormattingEnabled ? output : input
            })
        }
    }

    func testFillerCreatedPercentageCompletesInOnePass() {
        for (input, withoutFiller, normalized) in [
            ("3.5 呃 percent", "3.5 percent", "3.5%"),
            ("3.05 呃 per cent", "3.05 per cent", "3.05%"),
            ("增长 3.5 呃 percent。", "增长 3.5 percent。", "增长 3.5%。")
        ] {
            ResidualRepairAssertions.check(input, expected: { options in
                guard options.isFillerCleanupEnabled else { return input }
                return options.isSmartNumericFormattingEnabled ? normalized : withoutFiller
            })
        }
    }

    func testFillerFollowupKeepsLiteralAndMalformedProtection() {
        for input in ["`3.5 呃 percent`", "```\n3.5 呃 percent\n```", "`3.5 呃 percent"] {
            ResidualRepairAssertions.check(input, expected: { _ in input })
        }
        let cases = [
            ("3.5 60 呃 percent", "3.5 60 percent"),
            ("3.5 呃 percent percent", "3.5 percent percent"),
            ("3.5 呃 percent points", "3.5 percent points"),
            ("3.5 呃 percent `3.5 percent`", "3.5% `3.5 percent`")
        ]
        for (input, expected) in cases {
            let options = TranscriptProcessingOptions(isSmartNumericFormattingEnabled: true,
                isAcademicReferenceFormattingEnabled: false, isFillerCleanupEnabled: true,
                isMathNotationEnabled: false, mathNotationOutputFormat: .unicode)
            let output = TranscriptPostProcessor.process(input, options: options)
            XCTAssertEqual(output, expected)
            XCTAssertEqual(TranscriptPostProcessor.process(output, options: options), output)
        }
    }

    func testFollowupNormalizationIsVisibleInExistingTrace() {
        let result = TranscriptPostProcessor.processWithTrace("3.5 呃 percent", options: .init(
            isSmartNumericFormattingEnabled: true, isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: true))
        let stages = result.trace.stages
        let fillerIndex = stages.firstIndex { $0.stage == .fillerCleanup }!
        XCTAssertTrue(stages.dropFirst(fillerIndex + 1).contains {
            $0.stage == .normalization && $0.input == "3.5 percent" && $0.output == "3.5%"
        })
    }
}
