import XCTest
@testable import VoiceInputApp

/// Every before → after example on the onboarding pages must be what the formatter really
/// writes, with the switches a new user would have (smart numbers on by default).
final class OnboardingExamplesTests: XCTestCase {
    private func options(
        academic: Bool = false,
        filler: Bool = false,
        math: Bool = false,
        format: MathNotationOutputFormat = .latex
    ) -> TranscriptProcessingOptions {
        TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: academic,
            isFillerCleanupEnabled: filler,
            isMathNotationEnabled: math,
            mathNotationOutputFormat: format
        )
    }

    private func assertExamples(
        _ examples: [OnboardingExample],
        _ options: TranscriptProcessingOptions,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(examples.count, 2, "\(label): show at least two examples", file: file, line: line)
        for example in examples {
            XCTAssertEqual(
                TranscriptPostProcessor.process(example.spoken, options: options),
                example.written,
                "\(label): \(example.spoken)",
                file: file,
                line: line
            )
        }
    }

    func testFeatureExamplesMatchTheFormatter() {
        for language in [UILanguage.chinese, .english] {
            let copy = OnboardingCopy.texts(for: language)
            assertExamples(copy.numericExamples, options(), "\(language) numeric")
            assertExamples(copy.academicExamples, options(academic: true), "\(language) academic")
            assertExamples(copy.mathLaTeXExamples, options(math: true, format: .latex), "\(language) math LaTeX")
            assertExamples(copy.mathUnicodeExamples, options(math: true, format: .unicode), "\(language) math Unicode")
            assertExamples(copy.fillerExamples, options(filler: true), "\(language) filler")
            XCTAssertEqual(copy.mathExamples(for: .latex), copy.mathLaTeXExamples)
            XCTAssertEqual(copy.mathExamples(for: .unicode), copy.mathUnicodeExamples)
        }
    }

    func testSampleSentenceShowsDefaultFormatting() {
        for language in [UILanguage.chinese, .english] {
            let copy = OnboardingCopy.texts(for: language)
            XCTAssertEqual(
                TranscriptPostProcessor.process(copy.sampleSpokenText, options: options()),
                copy.sampleWrittenText,
                "\(language)"
            )
        }
    }
}
