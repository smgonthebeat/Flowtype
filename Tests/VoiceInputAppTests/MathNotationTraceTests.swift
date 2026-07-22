import XCTest
@testable import VoiceInputApp

final class MathNotationTraceTests: XCTestCase {
    func testMathNotationStageEmitsEventWhenFormatterChangesText() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        let result = TranscriptPostProcessor.processWithTrace("variance x", options: options)

        XCTAssertEqual(result.text, "Var(X)")

        guard let mathStage = result.trace.stages.first(where: { $0.stage == .mathNotation }) else {
            XCTFail("Expected math notation stage in trace")
            return
        }

        XCTAssertEqual(mathStage.input, "variance x")
        XCTAssertEqual(mathStage.output, "Var(X)")
        XCTAssertFalse(mathStage.events.isEmpty)
        XCTAssertTrue(mathStage.events.contains { $0.ruleID == "math.formatter.statistics-functions" })
    }

    func testFormatWithEventsMatchesPlainFormatText() {
        let cases = [
            "variance x",
            "Use `variance x` then variance y",
            "theta hat equals x bar and sigma squared",
            "standard error beta hat",
        ]

        for input in cases {
            let plainUnicode = MathNotationFormatter.format(input, outputFormat: .unicode)
            let traceUnicode = MathNotationFormatter.formatWithEvents(input, outputFormat: .unicode)
            XCTAssertEqual(plainUnicode, traceUnicode.text, "Unicode mismatch for input: \(input)")

            let plainLatex = MathNotationFormatter.format(input, outputFormat: .latex)
            let traceLatex = MathNotationFormatter.formatWithEvents(input, outputFormat: .latex)
            XCTAssertEqual(plainLatex, traceLatex.text, "LaTeX mismatch for input: \(input)")
        }
    }

    func testFormatWithEventsDoesNotEmitEventsForUnchangedText() {
        let input = "This is plain text."

        let unicodeResult = MathNotationFormatter.formatWithEvents(input, outputFormat: .unicode)
        XCTAssertEqual(unicodeResult.text, input)
        XCTAssertTrue(unicodeResult.events.isEmpty)

        let latexResult = MathNotationFormatter.formatWithEvents(input, outputFormat: .latex)
        XCTAssertEqual(latexResult.text, input)
        XCTAssertTrue(latexResult.events.isEmpty)
    }

    func testFormatWithEventsEmitsCompactASRNormalizationEvent() {
        let result = MathNotationFormatter.formatWithEvents("Nsubj", outputFormat: .unicode)

        XCTAssertEqual(result.text, "Nⱼ")
        XCTAssertTrue(
            result.events.contains { $0.ruleID == "math.formatter.compact-asr-normalization" }
        )
    }

    func testProtectedSpanEventsOnlyReflectUnprotectedChanges() {
        let input = "Use `variance x` then variance y"

        let unicodeResult = MathNotationFormatter.formatWithEvents(input, outputFormat: .unicode)

        XCTAssertEqual(unicodeResult.text, "Use `variance x` then Var(Y)")
        XCTAssertFalse(unicodeResult.events.isEmpty)
        XCTAssertTrue(unicodeResult.events.allSatisfy { $0.before != $0.after })
        XCTAssertTrue(
            unicodeResult.events.contains {
                $0.before.localizedCaseInsensitiveContains("variance y")
                || $0.after.localizedCaseInsensitiveContains("variance y")
                || $0.before.localizedCaseInsensitiveContains("Var(Y)")
                || $0.after.localizedCaseInsensitiveContains("Var(Y)")
            }
        )
    }
}
