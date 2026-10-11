import XCTest
@testable import VoiceInputApp

final class ConservativeSpellingRevisionTests: XCTestCase {
    func testAmbiguousEmbeddedRunsRemainWholeAcrossCapabilities() {
        let inputs = [
            "The code is A M A Z O N.", "The A B C title changed.",
            "I saw a C E O yesterday.", "I got a B in biology.",
            "I teach a C programming course.", "I am A S T R A.",
            "I use A I and A S T R A.", "I work at I B M.",
            "I use S I G M A.", "我用 a i 和 a s t r a。",
            "Il y a un problème.", "Il y a trois jours."
        ]
        for numeric in [false, true] { for academic in [false, true] {
            for filler in [false, true] { for math in [false, true] {
                for format in [MathNotationOutputFormat.unicode, .latex] {
                    let options = TranscriptProcessingOptions(
                        isSmartNumericFormattingEnabled: numeric,
                        isAcademicReferenceFormattingEnabled: academic,
                        isFillerCleanupEnabled: filler,
                        isMathNotationEnabled: math,
                        mathNotationOutputFormat: format
                    )
                    for input in inputs {
                        let output = TranscriptPostProcessor.process(input, options: options)
                        XCTAssertEqual(output, input, "\(input), math=\(math), academic=\(academic), format=\(format)")
                        XCTAssertEqual(TranscriptPostProcessor.process(output, options: options), output, input)
                    }
                }
            } }
        } }
    }

    func testStandaloneConventionUsesTheWholeInput() {
        for (input, expected) in [
            ("A I", "AI"), ("a i.", "AI."), ("A S T R A。", "ASTRA。"),
            ("I B M?", "IBM?"), ("S I G M A!", "SIGMA!"),
            ("I use S O L.", "I use SOL."),
            ("S O L. A I", "SOL. A I"), ("S O L\nA I", "SOL\nA I"),
            ("`keep` A I", "`keep` A I"), ("A I `keep`", "A I `keep`"),
            ("https://example.com/ A I", "https://example.com/ A I"),
            ("A I...", "A I...")
        ] {
            XCTAssertEqual(SpelledLetterNormalizer.normalize(input).text, expected, input)
        }
    }

    func testFillerAndMathCannotOverrideAnAbstainedRun() {
        for format in [MathNotationOutputFormat.unicode, .latex] {
            let options = TranscriptProcessingOptions(
                isSmartNumericFormattingEnabled: true,
                isAcademicReferenceFormattingEnabled: true,
                isFillerCleanupEnabled: true,
                isMathNotationEnabled: true,
                mathNotationOutputFormat: format,
                knownTerms: ["I use", "tail"]
            )
            for (input, expected) in [
                ("I saw a um C E O yesterday.", "I saw a C E O yesterday."),
                ("I use A I", "I use A I"), ("A I tail", "A I tail"),
                ("A uh I", "AI"), ("C um E O", "CEO"),
                ("`A uh I`", "`A uh I`")
            ] {
                XCTAssertEqual(TranscriptPostProcessor.process(input, options: options), expected, input)
            }
        }
    }
}
