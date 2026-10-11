import Foundation
import XCTest
@testable import VoiceInputApp

final class FillerCleanupEngineTests: XCTestCase {
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

    func testFrozenCorpusMatchesTextAndExactEvents() throws {
        for testCase in try loadCases() {
            let result = FillerCleanupEngine.clean(testCase.input)

            XCTAssertEqual(
                result.text,
                testCase.onExpected,
                "Text failed: \(testCase.id) [\(testCase.classification)]"
            )
            XCTAssertEqual(result.events.count, testCase.eventCount, "Event count: \(testCase.id)")
            XCTAssertEqual(result.events.map(\.ruleID), testCase.ruleIDs, "Rule IDs: \(testCase.id)")
            XCTAssertEqual(
                result.events.map(\.before),
                testCase.editBeforeAfter.map(\.before),
                "Event before slices: \(testCase.id)"
            )
            XCTAssertEqual(
                result.events.map(\.after),
                testCase.editBeforeAfter.map(\.after),
                "Event replacements: \(testCase.id)"
            )

            let secondPass = FillerCleanupEngine.clean(result.text)
            XCTAssertEqual(secondPass.text, result.text, "Second-pass text: \(testCase.id)")
            XCTAssertTrue(secondPass.events.isEmpty, "Second-pass events: \(testCase.id)")
        }
    }

    func testKnownTermIsOpaqueButMayBeContinuationEndpoint() {
        let protectedCandidate = FillerCleanupEngine.clean(
            "um, theta",
            context: NormalizationContext(knownTerms: ["um"])
        )
        XCTAssertEqual(protectedCandidate.text, "um, theta")
        XCTAssertTrue(protectedCandidate.events.isEmpty)

        let endpoint = FillerCleanupEngine.clean(
            "I think, em, STAT100",
            context: NormalizationContext(knownTerms: ["STAT100"])
        )
        // A fully protected identifier still has numeric/identifier evidence.
        XCTAssertEqual(endpoint.text, "I think, em, STAT100")
        XCTAssertTrue(endpoint.events.isEmpty)

        let edgeEndpoint = FillerCleanupEngine.clean(
            "我说呃，theta",
            context: NormalizationContext(knownTerms: ["theta"])
        )
        XCTAssertEqual(edgeEndpoint.text, "我说呃，theta")
        XCTAssertTrue(edgeEndpoint.events.isEmpty)
    }

    func testEveryProtectedSpanKindIsOpaque() {
        let kinds: [ProtectedSpanKind] = [
            .url, .email, .filePath, .command, .modelID, .version, .courseCode,
            .academicReference
        ]

        for kind in kinds {
            let input = "um"
            let span = ProtectedSpan(range: input.startIndex..<input.endIndex, kind: kind, text: input)
            let result = FillerCleanupEngine.clean(
                input,
                context: NormalizationContext(protectedSpans: [span])
            )
            XCTAssertEqual(result.text, input, "Protected kind: \(kind)")
            XCTAssertTrue(result.events.isEmpty, "Protected kind events: \(kind)")
        }
    }

    func testDetectedProtectedSpanIsOpaqueAndMayFollowAcceptedCandidate() {
        let protectedURL = "https://um.example.com"
        let protectedOnly = FillerCleanupEngine.clean(
            protectedURL,
            context: NormalizationContext(
                protectedSpans: ProtectedSpanDetector.detect(in: protectedURL)
            )
        )
        XCTAssertEqual(protectedOnly.text, protectedURL)
        XCTAssertTrue(protectedOnly.events.isEmpty)

        let input = "I think, um, https://example.com"
        let result = FillerCleanupEngine.clean(
            input,
            context: NormalizationContext(
                protectedSpans: ProtectedSpanDetector.detect(in: input)
            )
        )
        XCTAssertEqual(result.text, "I think, https://example.com")
        XCTAssertEqual(result.events.count, 1)
    }

    func testEventsUseUTF16StageInputRangesAndSourceOrder() {
        let input = "😀。嗯，我继续；I think, em, theta and um alpha"
        let result = FillerCleanupEngine.clean(input)

        XCTAssertEqual(result.events.count, 3)
        var previousUpperBound = -1
        for event in result.events {
            let range = try! parseRange(event.rangeDescription)
            XCTAssertGreaterThanOrEqual(range.lowerBound, previousUpperBound)
            let source = input as NSString
            XCTAssertEqual(source.substring(with: NSRange(range)), event.before)
            previousUpperBound = range.upperBound
        }
    }

    func testLongGrammarAndSequenceHaveNoProductionCap() {
        let longUm = "u" + String(repeating: "m", count: 64)
        let longSingle = FillerCleanupEngine.clean("\(longUm), next")
        XCTAssertEqual(longSingle.text, "next")
        XCTAssertEqual(longSingle.events.count, 1)

        let chain = Array(repeating: "um", count: 32).joined(separator: ", ")
        let longSequence = FillerCleanupEngine.clean("\(chain), next")
        XCTAssertEqual(longSequence.text, "next")
        XCTAssertEqual(longSequence.events.count, 1)
    }

    func testGeneratedFiniteGrammarBoundaryAndPairedNegativeOracle() {
        let repetitions = [1, 2, 3, 8]
        let gaps = [" ", "\t", "  ", " \t"]
        let punctuationGaps = ["", " ", "\t", "  ", " \t"]
        let broadRightAnchors = [",", "，", ";", "；", ":", "：", ".", "。", "...", "…", "……"]
        let commaAnchors = [",", "，"]

        var broadCandidates = ["嗯"]
        var englishCanonicalCandidates: [String] = []
        var commaOnlyCandidates = ["额"]
        for count in repetitions {
            broadCandidates.append(String(repeating: "呃", count: count))
            englishCanonicalCandidates.append("u" + String(repeating: "h", count: count))
            englishCanonicalCandidates.append("u" + String(repeating: "m", count: count))
            commaOnlyCandidates.append("e" + String(repeating: "m", count: count))
        }
        for firstCount in repetitions {
            for secondCount in repetitions {
                englishCanonicalCandidates.append(
                    "u" + String(repeating: "h", count: firstCount) +
                        String(repeating: "m", count: secondCount)
                )
                englishCanonicalCandidates.append(
                    "e" + String(repeating: "r", count: firstCount) +
                        String(repeating: "m", count: secondCount)
                )
            }
        }
        broadCandidates.append(contentsOf: englishCanonicalCandidates)
        broadCandidates.append(contentsOf: englishCanonicalCandidates.map(titlecased))

        for candidate in broadCandidates {
            for anchor in broadRightAnchors {
                for leadingGap in punctuationGaps {
                    for trailingGap in punctuationGaps {
                        let input = "\(candidate)\(leadingGap)\(anchor)\(trailingGap)next"
                        assertAccepted(input, expected: "next")

                        let pairedNegative = "\(candidate)\(leadingGap)?!\(trailingGap)next"
                        assertPreserved(pairedNegative)
                    }
                }
            }
            for gap in gaps {
                assertAccepted("\(candidate)\(gap)next", expected: "next")
                assertPreserved("prefix\(candidate)\(gap)next")
            }
        }

        for candidate in commaOnlyCandidates {
            for anchor in commaAnchors {
                for leadingGap in punctuationGaps {
                    for trailingGap in punctuationGaps {
                        assertAccepted(
                            "\(candidate)\(leadingGap)\(anchor)\(trailingGap)next",
                            expected: "next"
                        )
                    }
                }
            }
            assertPreserved("\(candidate); next")
            assertPreserved("\(candidate) next")
        }
        for candidate in englishCanonicalCandidates {
            assertPreserved("\(candidate.uppercased()), next")
            assertPreserved("\(candidate.dropFirst().isEmpty ? "U" : "u" + String(candidate.dropFirst()).uppercased()), next")
        }
        for candidate in commaOnlyCandidates.dropFirst() {
            assertPreserved("\(titlecased(candidate)), next")
            assertPreserved("\(candidate.uppercased()), next")
        }
    }

    func testGeneratedClauseTerminalSequenceAndEdgeOracle() {
        let leftTerminators = [
            ".", "。", "?", "？", "!", "！",
            "?!", "！？", "!!", "！！", "??", "？？", "?!?", "！？！"
        ]
        let unsupportedLeftEllipses = ["...", "…", "……"]
        let rightExpressive = [
            "?", "？", "!", "！",
            "?!", "！？", "!!", "！！", "??", "？？", "?!?", "！？！"
        ]
        let gaps = [" ", "\t", "  ", " \t"]

        for terminator in leftTerminators {
            for gap in [""] + gaps {
                assertAccepted(
                    "Done\(terminator)\(gap)Um, next",
                    expected: "Done\(terminator)\(gap)next"
                )
            }
        }
        assertAccepted("2. um, next", expected: "2. next")
        assertAccepted("2？Um, next", expected: "2？next")
        for ellipsis in unsupportedLeftEllipses {
            assertPreserved("Done\(ellipsis)um, next")
        }
        for punctuation in rightExpressive {
            assertPreserved("um\(punctuation)next")
        }

        for candidate in ["呃", "嗯", "uh", "um", "uhm", "erm"] {
            assertAccepted("prefix, \(candidate)", expected: "prefix")
            assertAccepted("prefix, \(candidate).", expected: "prefix.")
        }
        for candidate in ["呃", "嗯", "uh", "um", "uhm", "erm", "额", "em", "Um"] {
            assertPreserved(candidate)
            assertPreserved("\(candidate).")
        }

        let internalAnchors = [",", "，", ";", "；", ":", "：", ".", "。"]
        let internalEllipsisNegatives = ["...", "…", "……"]
        let punctuationGaps = ["", " ", "\t", "  ", " \t"]
        for length in [1, 2, 3] {
            for anchor in internalAnchors {
                for leftGap in punctuationGaps {
                    for rightGap in punctuationGaps {
                        let separator = "\(leftGap)\(anchor)\(rightGap)"
                        let homogeneous = Array(repeating: "um", count: length)
                            .joined(separator: separator)
                        let alternating = (0..<length)
                            .map { $0.isMultiple(of: 2) ? "嗯" : "um" }
                            .joined(separator: separator)
                        assertAccepted("\(homogeneous), next", expected: "next")
                        assertAccepted("\(alternating), next", expected: "next")
                    }
                }
            }
        }
        for ellipsis in internalEllipsisNegatives {
            assertPreserved("um\(ellipsis)um, next")
            assertPreserved("嗯\(ellipsis)um, next")
        }
        let longHomogeneous = Array(repeating: "um", count: 8).joined(separator: ", ")
        let longAlternating = (0..<8).map { $0.isMultiple(of: 2) ? "嗯" : "um" }
            .joined(separator: ", ")
        assertAccepted("\(longHomogeneous), next", expected: "next")
        assertAccepted("\(longAlternating), next", expected: "next")

        let edgeBridges = [",", "，", ";", "；", ":", "：", " ", "\t", "  ", " \t"]
        for repeatCount in [1, 2, 3, 8] {
            let edge = String(repeating: "呃", count: repeatCount)
            for bridge in edgeBridges {
                assertAccepted("我说\(edge)\(bridge)继续", expected: "我说继续")
                assertAccepted("我说\(edge)\(bridge)next", expected: "我说 next")
            }
            for length in [2, 3] {
                let tail = Array(repeating: "um", count: length - 1).joined(separator: ", ")
                assertAccepted("我说\(edge)，\(tail)，继续", expected: "我说继续")
                assertAccepted("我说\(edge)，\(tail)，next", expected: "我说 next")
            }
            assertPreserved("我说\(edge)。um, next")
            assertPreserved("我说\(edge)…um, next")
        }
    }

    func testGeneratedLexicalIdentifierProtectionAndConservationOracle() {
        for lexical in [
            "金额", "余额", "额度", "额定", "总额", "名额", "配额",
            "哎呀", "咿呀学语", "唉声叹气", "我现在啊发现"
        ] {
            assertPreserved(lexical)
            assertPreserved("\(lexical)。")
        }

        let formerCatalog = ["呃", "嗯", "额", "哦", "噢", "啊", "呀", "哎", "诶", "欸", "唉"]
        let hanPrefixes = ["我", "学", "金", "余", "名", "配"]
        let hanSuffixes = ["逆", "好", "度", "定", "语", "题"]
        for candidate in formerCatalog {
            for prefix in hanPrefixes {
                for suffix in hanSuffixes {
                    if candidate == "呃" && suffix != "逆" {
                        assertAccepted("\(prefix)\(candidate)\(suffix)", expected: "\(prefix)\(suffix)")
                    } else {
                        assertPreserved("\(prefix)\(candidate)\(suffix)")
                    }
                }
            }
        }

        let englishCandidates = ["uh", "um", "uhm", "erm", "em"]
        for candidate in englishCandidates {
            assertPreserved("pre\(candidate)")
            assertPreserved("\(candidate)suffix")
            assertPreserved(candidate.uppercased() + ", next")
            assertPreserved("X_\(candidate), next")
            assertPreserved("2, \(candidate), next")
            assertPreserved("\(candidate), 2")
            assertPreserved("\"\(candidate), next")
            assertPreserved("(\(candidate), next")
            assertPreserved("\(candidate)\nnext")
        }
        let quoteAndBracketBoundaries = [
            "\"", "'", "“", "”", "‘", "’", "(", ")", "（", "）",
            "[", "]", "【", "】", "{", "}", "<", ">", "《", "》"
        ]
        for boundary in quoteAndBracketBoundaries {
            assertPreserved("\(boundary)um, next")
            assertPreserved("um\(boundary)next")
        }

        for knownTerm in ["um", "嗯"] {
            let input = "\(knownTerm), next"
            let result = FillerCleanupEngine.clean(
                input,
                context: NormalizationContext(knownTerms: [knownTerm])
            )
            XCTAssertEqual(result.text, input)
            XCTAssertTrue(result.events.isEmpty)
        }

        let conserved = "LEFT; um, CENTER; 嗯，RIGHT"
        let result = FillerCleanupEngine.clean(conserved)
        XCTAssertEqual(result.text, "LEFT; CENTER; RIGHT")
        XCTAssertEqual(result.events.count, 2)
        let secondPass = FillerCleanupEngine.clean(result.text)
        XCTAssertEqual(secondPass.text, result.text)
        XCTAssertTrue(secondPass.events.isEmpty)
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

    private func parseRange(_ description: String) throws -> Range<Int> {
        let prefix = "segment:"
        guard description.hasPrefix(prefix) else { throw RangeError.invalid }
        let values = description.dropFirst(prefix.count).components(separatedBy: "..<")
        guard values.count == 2,
              let lower = Int(values[0]),
              let upper = Int(values[1]) else {
            throw RangeError.invalid
        }
        return lower..<upper
    }

    private func assertAccepted(
        _ input: String,
        expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = FillerCleanupEngine.clean(input)
        XCTAssertEqual(result.text, expected, input, file: file, line: line)
        XCTAssertEqual(result.events.count, 1, input, file: file, line: line)
        let secondPass = FillerCleanupEngine.clean(result.text)
        XCTAssertEqual(secondPass.text, result.text, input, file: file, line: line)
        XCTAssertTrue(secondPass.events.isEmpty, input, file: file, line: line)
    }

    private func titlecased(_ value: String) -> String {
        guard let first = value.first else { return value }
        return String(first).uppercased() + value.dropFirst()
    }

    private func assertPreserved(
        _ input: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = FillerCleanupEngine.clean(input)
        XCTAssertEqual(result.text, input, input, file: file, line: line)
        XCTAssertTrue(result.events.isEmpty, input, file: file, line: line)
    }

    private enum RangeError: Error {
        case invalid
    }
}
