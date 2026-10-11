import Foundation
import XCTest
@testable import VoiceInputApp

final class FillerCleanupFormatterTests: XCTestCase {
    private struct EditExpectation: Decodable {
        let before: String
        let after: String
    }

    private struct GoldenCase: Decodable {
        let id: String
        let input: String
        let onExpected: String
        let offExpected: String
        let eventCount: Int
        let ruleIDs: [String]
        let editBeforeAfter: [EditExpectation]
        let classification: String
    }

    func testRemovesShortChineseFillers() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("嗯，我现在说呃，theta hat"),
            "我现在说 theta hat"
        )
    }

    func testRetiresUnsafeSemanticInterjectionDeletion() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("哦，就是我现在啊发现哎这个问题"),
            "哦，就是我现在啊发现哎这个问题"
        )
    }

    func testPreservesLatinAInChineseContext() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("这个 a 我们继续，a，这样就可以"),
            "这个 a 我们继续，a，这样就可以"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("就是 a 四要背的内容"),
            "就是 a 四要背的内容"
        )
    }

    func testRemovesEnglishFillers() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("I think, em, theta hat and um alpha"),
            "I think, theta hat and alpha"
        )
    }

    func testRemovesEnglishFillerBeforeChineseText() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("Uh.他自己写了 draft"),
            "他自己写了 draft"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("uh，然后我们继续"),
            "然后我们继续"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("um。然后我们继续"),
            "然后我们继续"
        )
    }

    func testKeepsEnglishArticleA() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("This is a test and a model"),
            "This is a test and a model"
        )
    }

    func testPreservesWordsContainingEnglishFillerLetters() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("huh?"),
            "huh?"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("UHF radio"),
            "UHF radio"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("Suharto and Ahmad"),
            "Suharto and Ahmad"
        )
    }

    func testPreservesDiscoursePhrases() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("怎么说呢，就是说，然后呢，我们继续"),
            "怎么说呢，就是说，然后呢，我们继续"
        )
    }

    func testFrozenSafetyAndRecallCorpus() throws {
        for testCase in try loadCases() {
            XCTAssertEqual(
                testCase.offExpected,
                testCase.input,
                "Off fixture must be identity: \(testCase.id)"
            )
            XCTAssertEqual(
                FillerCleanupFormatter.format(testCase.input),
                testCase.onExpected,
                "Failed \(testCase.id) [\(testCase.classification)]"
            )
            XCTAssertEqual(
                testCase.eventCount,
                testCase.ruleIDs.count,
                "Event/rule fixture mismatch: \(testCase.id)"
            )
            XCTAssertEqual(
                testCase.eventCount,
                testCase.editBeforeAfter.count,
                "Event/edit fixture mismatch: \(testCase.id)"
            )
        }
    }

    func testEveryLegacyCaseHasAnExplicitClassification() throws {
        let cases = try loadCases()
        let classifications = Set(cases.map(\.classification))

        XCTAssertEqual(
            classifications,
            Set(["still-supported", "intentionally-retired", "negative-preserved"])
        )
        XCTAssertTrue(cases.contains { $0.id == "legacy-short-chinese-start" })
        XCTAssertTrue(cases.contains { $0.id == "legacy-short-chinese-trailing-edge" })
        XCTAssertTrue(cases.contains { $0.id == "legacy-semantic-interjections-retired" })
        XCTAssertTrue(cases.contains { $0.id == "legacy-english-core" })
        XCTAssertTrue(cases.contains { $0.id == "legacy-english-before-han-titlecase" })
        XCTAssertTrue(cases.contains { $0.id == "legacy-preserve-latin-a" })
        XCTAssertTrue(cases.contains { $0.id == "legacy-preserve-filler-substrings" })
        XCTAssertTrue(cases.contains { $0.id == "legacy-preserve-discourse-phrases" })
    }

    private func loadCases() throws -> [GoldenCase] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("filler-cleanup-cases.jsonl")

        let contents = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        return try contents
            .split(whereSeparator: \.isNewline)
            .map { try decoder.decode(GoldenCase.self, from: Data($0.utf8)) }
    }
}
