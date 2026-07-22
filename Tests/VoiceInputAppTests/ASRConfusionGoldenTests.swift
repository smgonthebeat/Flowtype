import Foundation
import XCTest
@testable import VoiceInputApp

final class ASRConfusionGoldenTests: XCTestCase {
    private struct GoldenCase: Decodable {
        let id: String
        let input: String
        let general: String
        let unicode: String
        let latex: String
        let tags: [String]
    }

    func testGeneralProfileGoldenCases() throws {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        )

        for testCase in try loadCases() {
            let actual = TranscriptPostProcessor.process(testCase.input, options: options)
            XCTAssertEqual(actual, testCase.general, failureMessage(for: testCase, format: "general"))
        }
    }

    func testUnicodeMathProfileGoldenCases() throws {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .unicode
        )

        for testCase in try loadCases() {
            let actual = TranscriptPostProcessor.process(testCase.input, options: options)
            XCTAssertEqual(actual, testCase.unicode, failureMessage(for: testCase, format: "unicode"))
        }
    }

    func testLatexMathProfileGoldenCases() throws {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: true,
            mathNotationOutputFormat: .latex
        )

        for testCase in try loadCases() {
            let actual = TranscriptPostProcessor.process(testCase.input, options: options)
            XCTAssertEqual(actual, testCase.latex, failureMessage(for: testCase, format: "latex"))
        }
    }

    private func failureMessage(for testCase: GoldenCase, format: String) -> String {
        "Failed \(testCase.id) [\(format)]: \(testCase.tags.joined(separator: ","))"
    }

    private func loadCases() throws -> [GoldenCase] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("asr-confusion-cases.jsonl")

        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let decoder = JSONDecoder()
        return try lines.map { line in
            try decoder.decode(GoldenCase.self, from: Data(line.utf8))
        }
    }
}
