import XCTest
@testable import VoiceInputApp

final class MathKnownTermsProtectionTests: XCTestCase {
    func testKnownTermProtectsFormatterRewrite() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode,
            knownTerms: ["variance x"]
        )
        let result = TranscriptPostProcessor.process("keep variance x as a product label", options: options)
        XCTAssertEqual(result, "keep variance x as a product label")
        XCTAssertEqual(
            TranscriptPostProcessor.process(
                "keep variance x as a formula",
                options: TranscriptProcessingOptions(
                    isSmartNumericFormattingEnabled: false,
                    isFillerCleanupEnabled: false,
                    isMathNotationEnabled: true,
                    mathNotationOutputFormat: .unicode
                )
            ),
            "keep Var(X) as a formula"
        )
    }

    func testKnownTermProtectsASRConfusionRewrite() {
        let protectedOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode,
            knownTerms: ["variant of X"]
        )
        XCTAssertEqual(
            TranscriptPostProcessor.process("keep variant of X as a product label", options: protectedOptions),
            "keep variant of X as a product label"
        )

        let unprotectedOptions = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )
        XCTAssertEqual(
            TranscriptPostProcessor.process("keep variant of X as a formula", options: unprotectedOptions),
            "keep Var(X) as a formula"
        )
    }

    func testKnownTermDoesNotBlockMathOutsideProtectedSpan() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode,
            knownTerms: ["K² 课程"]
        )
        let result = TranscriptPostProcessor.process("review K² 课程 and variance x", options: options)
        XCTAssertEqual(result, "review K² 课程 and Var(X)")
    }
}
