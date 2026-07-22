import Foundation
import XCTest
@testable import VoiceInputApp

final class MathNotationGoldenTests: XCTestCase {
    private struct GoldenCase: Decodable {
        let id: String
        let input: String
        let unicode: String
        let latex: String
        let tags: [String]
        let knownFailure: Bool
    }

    func testUnicodeGoldenCases() throws {
        for testCase in try loadCases() {
            let actual = MathNotationFormatter.format(testCase.input, outputFormat: .unicode)
            assert(actual, equals: testCase.unicode, for: testCase, format: "unicode")
        }
    }

    func testLatexGoldenCases() throws {
        for testCase in try loadCases() {
            let actual = MathNotationFormatter.format(testCase.input, outputFormat: .latex)
            assert(actual, equals: testCase.latex, for: testCase, format: "latex")
        }
    }

    private func assert(
        _ actual: String,
        equals expected: String,
        for testCase: GoldenCase,
        format: String
    ) {
        let message = "Failed \(testCase.id) [\(format)]: \(testCase.tags.joined(separator: ","))"
        if testCase.knownFailure {
            XCTExpectFailure("Known math notation gap \(testCase.id) [\(format)]") {
                XCTAssertEqual(actual, expected, message)
            }
        } else {
            XCTAssertEqual(actual, expected, message)
        }
    }

    private func loadCases() throws -> [GoldenCase] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("math-notation-cases.jsonl")

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
