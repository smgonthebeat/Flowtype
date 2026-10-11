import Foundation
import XCTest
@testable import VoiceInputApp

final class AcademicReferenceGrammarTests: XCTestCase {
    private struct GoldenCase: Decodable {
        let id: String
        let family: String
        let input: String
        let expected: String
    }

    func testMatchesEveryApprovedLegacyCaseSideBySide() throws {
        for testCase in try loadCases() {
            let actual = AcademicReferenceGrammar.normalize(testCase.input)
            XCTAssertEqual(
                actual,
                testCase.expected,
                "Failed \(testCase.id) [\(testCase.family)]"
            )
        }
    }

    func testScannerKeepsWordsAndCompactIdentifiersAtomic() {
        let tokens = AcademicReferenceGrammar.scan("done B2B D one")
            .filter { $0.kind != .whitespace }

        XCTAssertEqual(tokens.map(\.text), ["done", "B2B", "D", "one"])
        XCTAssertEqual(
            tokens.map(\.kind),
            [.latinWord, .asciiIdentifier, .latinWord, .latinWord]
        )
    }

    func testPreservesOrdinaryWordsWithoutWordSpecificRules() {
        let words = ["done", "gone", "hone", "none", "tone", "bone", "cone", "lone", "zone", "weight", "height"]
        let input = words.joined(separator: ", ") + "."

        XCTAssertEqual(AcademicReferenceGrammar.normalize(input), input)
    }

    func testPreservesCompactIdentifiersDeterministically() {
        let explicit = "B2B B2C C2C A1B H2O R2D2 P2P M3 Pro A4 paper"
        XCTAssertEqual(AcademicReferenceGrammar.normalize(explicit), explicit)

        for first in ["A", "B", "C", "D", "Q", "R", "X"] {
            for digit in 0...9 {
                for last in ["A", "B", "C", "D", "Q", "X"] {
                    let identifier = "\(first)\(digit)\(last)"
                    XCTAssertEqual(
                        AcademicReferenceGrammar.normalize(identifier),
                        identifier
                    )
                }
            }
        }
    }

    func testPreservesSpokenLetterNumberLetterIdentifierFamily() {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)
        let identifierPrefixes = letters.filter { $0 != "Q" }
        let numberWords = [
            "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
            "twelve", "nineteen", "twenty one", "thirty five", "ninety nine"
        ]

        for first in identifierPrefixes {
            for numberWord in numberWords {
                for last in letters {
                    let identifier = "\(first) \(numberWord) \(last)"
                    XCTAssertEqual(
                        AcademicReferenceGrammar.normalize(identifier),
                        identifier,
                        identifier
                    )
                }
            }
        }

        for input in ["B to B", "C to C", "B two B", "B three B", "C three C"] {
            XCTAssertEqual(AcademicReferenceGrammar.normalize(input), input, input)
        }
    }

    func testPreservesFormattedAcademicReferenceAndRequiresExplicitSubpartEvidence() {
        XCTAssertEqual(AcademicReferenceGrammar.normalize("B3(b)"), "B3(b)")
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("B three B and C"),
            "B3(b) and (c)"
        )
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("Exercise three B and C"),
            "Exercise 3(b) and (c)"
        )
        XCTAssertEqual(AcademicReferenceGrammar.normalize("Q three B"), "Q3(b)")
    }

    func testPreservesContextualSectionARepairsWithinOneSentence() {
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("OK，A部分我会了，A一B，下一步给我A一B。"),
            "OK，A部分我会了，A1(b)，下一步给我A1(b)。"
        )
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("OK，部分我会了，一B，下一步给我讲一B。"),
            "OK，A部分我会了，A1(b)，下一步给我A1(b)。"
        )
    }

    func testDoesNotLeakSectionAContextAcrossSentenceBoundary() {
        let input = "A部分我会了。一B这个说法保持原样。"
        XCTAssertEqual(AcademicReferenceGrammar.normalize(input), input)
    }

    func testStrongSentenceBoundariesCannotBecomeReferenceSeparators() {
        let inputs = [
            "I have a question. One thing remains.",
            "I have a question: one thing remains.",
            "I have a question, one thing remains.",
            "Please open sheet. One note remains.",
            "Please open sheet: one note remains.",
            "Exercise. Four items remain.",
            "Exercise, four people remain.",
            "Question! Nine people answered.",
            "Please open sheet\nOne note remains."
        ]

        for input in inputs {
            XCTAssertEqual(AcademicReferenceGrammar.normalize(input), input, input)
        }

        for head in ["question", "sheet", "exercise"] {
            for separator in [",", ":", ";", "—", "、"] {
                for number in ["one", "three", "nine"] {
                    let input = "I mention \(head)\(separator) \(number) things."
                    XCTAssertEqual(AcademicReferenceGrammar.normalize(input), input, input)
                }
            }
        }
    }

    func testHanContextRequiresACompleteBoundedEvidenceToken() {
        for input in ["大部分我会了。", "这部分我会了。", "DATA部分我会了，一B。"] {
            XCTAssertEqual(AcademicReferenceGrammar.normalize(input), input, input)
        }

        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("部分我会了，一B。"),
            "A部分我会了，A1(b)。"
        )
    }

    func testConsumesArbitraryLengthSubpartLists() {
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("Exercise four B and C and D"),
            "Exercise 4(b) and (c) and (d)"
        )
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("A one B和C和D"),
            "A1(b) and (c) and (d)"
        )
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("Q three B and C 和 D and H"),
            "Q3(b) and (c) and (d) and (h)"
        )

        for input in [
            "Exercise four B and C and Z",
            "Exercise 4B and C and Z",
            "Exercise Sheet four B and C and Z",
            "Exercise four Q three B and C and X",
            "Q three B and C and X"
        ] {
            XCTAssertEqual(AcademicReferenceGrammar.normalize(input), input, input)
        }

        for invalidLetter in Array("IJKLMNOPQRSTUVWXYZ") {
            let input = "Exercise four B and C and \(invalidLetter)"
            XCTAssertEqual(AcademicReferenceGrammar.normalize(input), input, input)
        }
    }

    func testPreservesExerciseSheetSubpartLists() {
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("Exercise sheet four B and C and D"),
            "Exercise Sheet 4(b) and (c) and (d)"
        )
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("Exercise sheet 4B and C"),
            "Exercise Sheet 4(b) and (c)"
        )
    }

    func testPreservesProtectedSpansAsOpaqueTokens() {
        let input = "保留 Exercise four B and C，然后转换 Q four B and C。"
        let protectedText = "Exercise four B and C"
        let protectedRange = input.range(of: protectedText)!
        let context = NormalizationContext(
            protectedSpans: [ProtectedSpan(
                range: protectedRange,
                kind: .command,
                text: protectedText
            )]
        )

        XCTAssertEqual(
            AcademicReferenceGrammar.normalize(input, context: context),
            "保留 Exercise four B and C，然后转换 Q4(b) and (c)。"
        )
    }

    func testProtectedSpanCanStartInsideAnOtherwiseAtomicToken() {
        let input = "fooA部分我会了，一B。"
        let protectedText = "A部分我会了"
        let protectedRange = input.range(of: protectedText)!
        let context = NormalizationContext(
            protectedSpans: [ProtectedSpan(
                range: protectedRange,
                kind: .command,
                text: protectedText
            )]
        )

        let tokens = AcademicReferenceGrammar.scan(input, protectedSpans: context.protectedSpans)
        XCTAssertEqual(tokens.first?.text, "foo")
        XCTAssertEqual(tokens.dropFirst().first?.kind, .protected)
        XCTAssertEqual(AcademicReferenceGrammar.normalize(input, context: context), input)
    }

    func testSupportsSegmentedAndNearMissLegacyInputs() {
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("请打开 q 四。BNC，请看A one BNC。"),
            "请打开 Q4(b) and (c)，请看A1(b) and (c)。"
        )
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("请看 Q。是，BNC。"),
            "请看 Q4(b) and (c)。"
        )
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("Q four. BNC"),
            "Q4(b) and (c)"
        )
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("Question four. BNC"),
            "Question 4. BNC"
        )
        XCTAssertEqual(
            AcademicReferenceGrammar.normalize("Sheet one Exercise, four B and C"),
            "Sheet 1 Exercise 4(b) and (c)"
        )
    }

    func testEveryRenderedSubpartHasAReferenceParent() {
        let nodes = AcademicReferenceGrammar.recognize(
            in: "Exercise 4B and C, Q4 BNC, A 一 B and C"
        )

        XCTAssertFalse(nodes.isEmpty)
        for node in nodes where !node.subparts.isEmpty {
            switch node.kind {
            case .exercise, .exerciseQuestion, .question, .section, .sectionWithPrefix,
                 .sheetExercise, .exerciseSheet:
                break
            case .sheet, .questionSheet, .academicListNumber, .omittedSectionAMarker:
                XCTFail("Subparts rendered without a valid parent: \(node)")
            }
        }
    }

    func testMatchesNeverOverlapAndNormalizationIsIdempotent() throws {
        for testCase in try loadCases() {
            let nodes = AcademicReferenceGrammar.recognize(in: testCase.input)
            for (index, lhs) in nodes.enumerated() {
                for rhs in nodes.dropFirst(index + 1) {
                    XCTAssertFalse(rangesOverlap(lhs.sourceRange, rhs.sourceRange), testCase.id)
                }
            }

            let once = AcademicReferenceGrammar.normalize(testCase.input)
            XCTAssertEqual(AcademicReferenceGrammar.normalize(once), once, testCase.id)
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
            .map { try decoder.decode(GoldenCase.self, from: Data($0.utf8)) }
    }

    private func rangesOverlap(_ lhs: Range<String.Index>, _ rhs: Range<String.Index>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }
}
