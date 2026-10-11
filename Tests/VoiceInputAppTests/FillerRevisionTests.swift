import Foundation
import XCTest
@testable import VoiceInputApp

final class FillerRevisionTests: XCTestCase {
    private struct Fixture: Decodable {
        let id: String
        let input: String
        let expected: String
        let knownTerms: [String]
    }

    func testAll55CurrentDiagnosticExpectations() throws {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/filler-revision2-cases.jsonl")
        let lines = try String(contentsOf: path, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines.count, 55)
        for line in lines {
            let row = try JSONDecoder().decode(Fixture.self, from: Data(line.utf8))
            check(row.input, row.expected, terms: row.knownTerms)
        }
    }

    func testAuthorizedShapesAndConservativeBoundaries() {
        for (input, expected) in [
            ("那嗯，我们继续。", "那，我们继续。"),
            ("那，嗯，我们继续。", "那，我们继续。"),
            ("我想呃先看呃呃这些文件。", "我想先看这些文件。"),
            ("这些文件的名字呃写错了。", "这些文件的名字写错了。"),
            ("这个嗯 \t， now.", "这个 \t， now."),
            ("我呃想说：“我，嗯，继续。”", "我想说：“我，嗯，继续。”"),
            ("🙂我呃想看e\u{301}，那嗯，继续。", "🙂我想看e\u{301}，那，继续。")
        ] { check(input, expected) }
        for input in [
            "那嗯我们继续。", "嗯嗯，我知道。", "那嗯嗯，继续。", "嗯我们继续。",
            "呃我们继续。", "额度不足。", "余额呃逆。", "我um现在继续。", "五um厚。",
            "那嗯。继续。", "那嗯！继续。", "那嗯，\n继续。", "那嗯，2号。",
            "那嗯，\"继续\"", "那嗯，`continue`", "我呃嗯继续。", "我嗯呃继续。",
            "他说了嗯，然后离开。", "我们讨论呃这个字。", "我发出了呃，一声。",
            "我呃，了一声。", "我呃，呃继续。", "我呃，嗯，呃继续。", "他出现呃逆症状。", "嗯哼，我知道。"
        ] { check(input, input) }
    }

    func testProtectionGrammarWithoutMarkerMasking() {
        let pairs = [("“", "”"), ("‘", "’"), ("「", "」"), ("『", "』"), ("《", "》"),
                     ("\"", "\""), ("'", "'"), ("`", "`"), ("``", "``"), ("```\n", "\n```")]
        for (open, close) in pairs {
            for body in ["我，嗯，继续。", "I um continue.", "我想呃先继续。", "那嗯，继续。", "我说呃，um，继续。"] {
                check(open + body + close, open + body + close)
                check(open + body, open + body)
                check("我呃想说：" + open + body + close, "我想说：" + open + body + close)
            }
        }
        for input in [
            "“外层「我，嗯，继续。」结束”", "“外层『我，嗯，继续。」仍未闭合",
            "`don't \" um, continue.`", "\"code `I um continue.` more um text\"",
            "读作\t嗯，继续。", "嗯 \t， 这个读音。", "写成 呃，继续。"
        ] { check(input, input) }
        check("请保留原文：我，嗯，继续。\n我呃继续。", "请保留原文：我，继续。\n我继续。")
        check("don't um continue.", "don't continue.")
        check("prefix \\\" note um continue.", "prefix \\\" note continue.")
        check("“I \\\" um continue.”, um, next", "“I \\\" um continue.”, next")
        check("写字的人呃继续。", "写字的人继续。")
        check("读作\n我呃继续。", "读作\n我继续。")
    }

    func testFormerVerbatimMarkersAreOrdinaryText() {
        for marker in ["请保留原文", "请逐字保留", "逐字记录", "原文", "原句"] {
            for separator in [":", "：", " \t："] {
                let prefix = marker + separator
                for (body, cleaned) in [("我，嗯，继续。", "我，继续。"),
                                        ("我呃继续。", "我继续。"),
                                        ("那嗯，继续。", "那，继续。"),
                                        ("I um continue.", "I continue.")] {
                    check(prefix + body, prefix + cleaned)
                    for (open, close) in [("“", "”"), ("`", "`")] {
                        // The delimiter, not the wording before it, protects the body.
                        check(prefix + open + body + close, prefix + open + body + close)
                        let quotedExample = open + "原文：示例" + close + " "
                        check(quotedExample + prefix + body, quotedExample + prefix + cleaned)
                    }
                }
            }
        }
        check("请保留原文：我，嗯，继续。", "请保留原文：我，嗯，继续。", terms: ["我，嗯，继续。"])
    }

    func testKnownTermOverlapAndBridgesUseOriginalBoundaries() {
        for terms in [["呃"], ["想呃"], ["呃继续"], ["想呃继续"]] {
            check("我想呃继续。", "我想呃继续。", terms: terms)
        }
        check("我想呃继续。", "我想继续。", terms: ["我想"])
        check("我呃继续。", "我继续。", terms: ["继续"])
        check("那嗯，继续。", "那，继续。", terms: ["那"])
        check("我嗯继续。", "我嗯继续。", terms: ["我", "继续"])
        check("um, next", "um, next", terms: [","])
        check("um, uh, next", "um, uh, next", terms: [", uh,"])
    }

    func testDictionaryProtectionCannotEraseNumericOrIdentifierEvidence() {
        for value in ["A2", "B3", "12", "X_2", "STAT100"] {
            let termSets: [[String]] = [[], [String(value.prefix(1))], [String(value.suffix(1))], [value], ["unrelated"]]
            for filler in ["um", "uh", "em", "erm", "额"] {
                for input in ["\(value), \(filler), next.", "next, \(filler), \(value)."] {
                    for terms in termSets { check(input, input, terms: terms) }
                }
            }
        }
    }

    func testExplicitProtectedSpanKeepsOriginalIdentifierKind() {
        let kinds: [ProtectedSpanKind] = [.url, .email, .filePath, .command, .modelID,
                                         .version, .courseCode, .academicReference]
        for input in ["A2, um, next.", "next, um, A2."] {
            for protectedText in ["A", "2", "A2"] {
                for kind in kinds {
                    let range = input.range(of: protectedText)!
                    let result = FillerCleanupEngine.clean(input, context: NormalizationContext(
                        protectedSpans: [ProtectedSpan(range: range, kind: kind, text: protectedText)]))
                    XCTAssertEqual(result.text, input)
                    XCTAssertTrue(result.events.isEmpty)
                }
            }
        }
    }

    func testNonNumericProtectedContinuationAndContentStayCompatible() {
        check("I think, em, theta", "I think, theta", terms: ["theta"])
        check("I think, um, https://example.com", "I think, https://example.com")
        check("我说呃，theta", "我说呃，theta", terms: ["theta"])
        check("我呃想看，那嗯，继续。", "我想看，那，继续。", terms: ["想看"])
        check("um, next", "um, next", terms: ["um"])
        check("A2, um, next.", "A2, um, next.", terms: ["A", "2"])
    }

    func testDenseMixedCandidateTraceAndIdempotence() {
        for count in [1, 10, 100] {
            let unit = "🙂我呃想看，那嗯，继续；um, next。"
            let expected = "🙂我想看，那，继续；next。"
            check(String(repeating: unit, count: count), String(repeating: expected, count: count))
        }
    }

    func testCapabilityMatrixInBothMathFormats() {
        let samples = [
            "我呃想看，那嗯，继续。",
            "我呃想说：“我，嗯，继续。”",
            "Exercise three Q two H. theta hat equals x bar and 5 kg. 我呃继续。",
            "二零二四年十一月五号。余额。Access SS. 我um继续。",
            "我呃继续。"
        ]
        for format in [MathNotationOutputFormat.unicode, .latex] {
            for smart in [false, true] {
                for academic in [false, true] {
                    for math in [false, true] {
                        for input in samples {
                            func options(_ filler: Bool) -> TranscriptProcessingOptions {
                                TranscriptProcessingOptions(isSmartNumericFormattingEnabled: smart,
                                    isAcademicReferenceFormattingEnabled: academic,
                                    isFillerCleanupEnabled: filler, isMathNotationEnabled: math,
                                    mathNotationOutputFormat: format, knownTerms: ["Access", "SS"])
                            }
                            let off = TranscriptPostProcessor.processWithTrace(input, options: options(false))
                            let on = TranscriptPostProcessor.processWithTrace(input, options: options(true))
                            let offStage = off.trace.stages.first { $0.stage == .fillerCleanup }!
                            let onStage = on.trace.stages.first { $0.stage == .fillerCleanup }!
                            XCTAssertEqual(offStage.input, onStage.input)
                            XCTAssertEqual(offStage.input, offStage.output)
                            XCTAssertTrue(offStage.events.isEmpty)
                            let expected = onStage.input.replacingOccurrences(of: "我呃", with: "我")
                                .replacingOccurrences(of: "那嗯，", with: "那，")
                            XCTAssertEqual(onStage.output, expected)
                            // Feeding the approved input delta through the same other formatters
                            // must produce the exact final output, including numeric/math stages.
                            let editedInput = input.replacingOccurrences(of: "我呃", with: "我")
                                .replacingOccurrences(of: "那嗯，", with: "那，")
                            XCTAssertEqual(on.text, TranscriptPostProcessor.processWithTrace(editedInput, options: options(false)).text)
                        }
                    }
                }
            }
        }
    }

    func testObservationStressHasStableRangesAndNoCascades() {
        for left in ["我", "我说了", "我呃", "🙂。", "“", "原文：", "e\u{301} ", ""] {
            for middle in ["呃", "嗯", "呃呃", "呃嗯", "嗯呃", "um", "呃，嗯", "嗯，呃", "呃我呃", "嗯，um"] {
                for right in ["继续。", "，继续。", "，嗯，继续。", "，呃继续。", "，um, next", "。", "”，继续。", "\n继续。"] {
                    let input = left + middle + right
                    // Observation-only corpus: correctness is asserted by golden tests above.
                    check(input, FillerCleanupEngine.clean(input, context: NormalizationContext(
                        protectedSpans: ProtectedSpanDetector.detect(in: input))).text)
                }
            }
        }
    }

    private func check(_ input: String, _ expected: String, terms: [String] = [],
                       file: StaticString = #filePath, line: UInt = #line) {
        func context(_ source: String) -> NormalizationContext {
            NormalizationContext(knownTerms: terms, protectedSpans: ProtectedSpanDetector.detect(in: source))
        }
        let first = FillerCleanupEngine.clean(input, context: context(input))
        XCTAssertEqual(first.text, expected, input, file: file, line: line)
        let second = FillerCleanupEngine.clean(first.text, context: context(first.text))
        XCTAssertEqual(second.text, first.text, "Idempotence: \(input)", file: file, line: line)
        XCTAssertTrue(second.events.isEmpty, file: file, line: line)
        let source = input as NSString
        let rebuilt = NSMutableString(string: input)
        var edits: [(NSRange, String)] = []
        var end = 0
        for event in first.events {
            let parts = event.rangeDescription.dropFirst("segment:".count).components(separatedBy: "..<")
            guard parts.count == 2, let lower = Int(parts[0]), let upper = Int(parts[1]),
                  lower >= end, upper <= source.length else {
                XCTFail("Invalid event range", file: file, line: line); return
            }
            let range = NSRange(location: lower, length: upper - lower)
            XCTAssertNotNil(Range(range, in: input), file: file, line: line)
            XCTAssertEqual(source.substring(with: range), event.before, file: file, line: line)
            edits.append((range, event.after)); end = upper
        }
        for (range, replacement) in edits.reversed() { rebuilt.replaceCharacters(in: range, with: replacement) }
        XCTAssertEqual(rebuilt as String, first.text, file: file, line: line)
    }
}
