import Foundation
import XCTest
@testable import VoiceInputApp

final class AcademicReferenceGoldenTests: XCTestCase {
    private struct GoldenCase: Decodable {
        let id: String
        let family: String
        let input: String
        let expected: String
    }

    func testApprovedAcademicReferenceCorpus() throws {
        for testCase in try loadCases() {
            let actual = AcademicReferenceNormalizer.normalize(
                testCase.input,
                context: NormalizationContext()
            )
            XCTAssertEqual(
                actual,
                testCase.expected,
                "Failed \(testCase.id) [\(testCase.family)]"
            )
        }
    }

    private func loadCases() throws -> [GoldenCase] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("academic-reference-cases.jsonl")

        let contents = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        return try contents
            .split(whereSeparator: \.isNewline)
            .map { line in
                try decoder.decode(GoldenCase.self, from: Data(line.utf8))
            }
    }
}
