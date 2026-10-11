import XCTest
@testable import VoiceInputApp

enum ResidualRepairAssertions {
    static func check(_ input: String, terms: [String] = [],
                      when: (TranscriptProcessingOptions) -> Bool = { _ in true },
                      expected: (TranscriptProcessingOptions) -> String,
                      file: StaticString = #filePath, line: UInt = #line) {
        for numeric in [false, true] { for academic in [false, true] {
            for filler in [false, true] { for math in [false, true] {
                for format in [MathNotationOutputFormat.unicode, .latex] {
                    let options = TranscriptProcessingOptions(
                        isSmartNumericFormattingEnabled: numeric,
                        isAcademicReferenceFormattingEnabled: academic,
                        isFillerCleanupEnabled: filler, isMathNotationEnabled: math,
                        mathNotationOutputFormat: format, knownTerms: terms)
                    guard when(options) else { continue }
                    let output = TranscriptPostProcessor.process(input, options: options)
                    let label = "\(input) [numeric=\(numeric), academic=\(academic), filler=\(filler), math=\(math), \(format)]"
                    XCTAssertEqual(output, expected(options), label, file: file, line: line)
                    XCTAssertEqual(TranscriptPostProcessor.process(output, options: options), output,
                                   "Repeated processing: " + label, file: file, line: line)
                }
            } }
        } }
    }
}
