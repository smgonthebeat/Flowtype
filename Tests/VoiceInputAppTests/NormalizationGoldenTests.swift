import Foundation
import XCTest
@testable import VoiceInputApp

final class NormalizationGoldenTests: XCTestCase {
    private struct GoldenCase: Decodable {
        let id: String
        let input: String
        let expected: String
        let tags: [String]
    }

    func testGoldenCases() throws {
        for testCase in try loadCases() {
            let actual = NormalizationPipeline.normalize(testCase.input)
            XCTAssertEqual(
                actual,
                testCase.expected,
                "Failed \(testCase.id): \(testCase.tags.joined(separator: ","))"
            )
        }
    }

    private func loadCases() throws -> [GoldenCase] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("normalization-cases.jsonl")

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
