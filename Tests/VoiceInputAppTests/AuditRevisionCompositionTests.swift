import XCTest
@testable import VoiceInputApp

final class AuditRevisionCompositionTests: XCTestCase {
    func testFillerCreatesCompleteSpellingRunsInOnePass() {
        let cases = [
            ("A uh I", "AI", "A uh I"),
            ("U um M", "UM", "U um M"),
            ("C um E O", "CEO", "C um EO"),
            ("S O um L", "SOL", "SO um L"),
            ("我用 S O um L 模型。", "我用 SOL 模型。", "我用 SO um L 模型。")
        ]
        for numeric in [false, true] { for academic in [false, true] {
            for math in [false, true] { for filler in [false, true] {
                for format in [MathNotationOutputFormat.unicode, .latex] {
                    let options = TranscriptProcessingOptions(
                        isSmartNumericFormattingEnabled: numeric,
                        isAcademicReferenceFormattingEnabled: academic,
                        isFillerCleanupEnabled: filler,
                        isMathNotationEnabled: math,
                        mathNotationOutputFormat: format
                    )
                    for (input, cleaned, retained) in cases {
                        let output = TranscriptPostProcessor.process(input, options: options)
                        XCTAssertEqual(output, filler ? cleaned : retained,
                                       "\(input), numeric=\(numeric), academic=\(academic), math=\(math), filler=\(filler), format=\(format)")
                        XCTAssertEqual(TranscriptPostProcessor.process(output, options: options), output,
                                       "The production pipeline must be stable after one call: \(input)")
                    }
                }
            } }
        } }
    }

    func testDeferredSpellingRetainsExistingFillerAndIdentifierGuards() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )
        for (input, expected) in [
            ("`C um E O`", "`C um E O`"),
            ("```\nA uh I\n```", "```\nA uh I\n```"),
            ("U M", "UM"), ("U H", "UH"),
            ("A2, um, thick.", "A2, um, thick."),
            ("S O L 5", "SOL 5")
        ] {
            XCTAssertEqual(TranscriptPostProcessor.process(input, options: options), expected, input)
        }

        let knownFiller = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: true,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode,
            knownTerms: ["um"]
        )
        XCTAssertEqual(TranscriptPostProcessor.process("C um E O", options: knownFiller), "C um EO")
    }

    func testAcademicScopeAndNumericFillerEvidenceSurviveDeferredSpelling() {
        for numeric in [false, true] {
            let options = TranscriptProcessingOptions(
                isSmartNumericFormattingEnabled: numeric,
                isAcademicReferenceFormattingEnabled: true,
                isFillerCleanupEnabled: true,
                isMathNotationEnabled: false,
                mathNotationOutputFormat: .unicode
            )
            XCTAssertEqual(
                TranscriptPostProcessor.process("A部分我会了，参考 S O L，再讲一B。", options: options),
                "A部分我会了，参考 SOL，再讲A1(b)。"
            )
            XCTAssertEqual(TranscriptPostProcessor.process("S O L 5", options: options), "SOL 5")
            XCTAssertEqual(TranscriptPostProcessor.process("A two, um, thick.", options: options),
                           "A2, um, thick.")
        }
    }

    func testAcademicReservationIncludesSpellingRunsOverlappingStrongSyntax() {
        for numeric in [false, true] { for academic in [false, true] {
            for filler in [false, true] { for math in [false, true] {
                let options = TranscriptProcessingOptions(
                    isSmartNumericFormattingEnabled: numeric,
                    isAcademicReferenceFormattingEnabled: academic,
                    isFillerCleanupEnabled: filler,
                    isMathNotationEnabled: math,
                    mathNotationOutputFormat: .unicode
                )
                for input in ["https://example.com/S O L 5", "https://example.com/A I 5",
                              "S O L@example.com 5"] {
                    let output = TranscriptPostProcessor.process(input, options: options)
                    XCTAssertEqual(output, input, input)
                    XCTAssertEqual(TranscriptPostProcessor.process(output, options: options), output, input)
                }
            } }
        } }
    }
}
