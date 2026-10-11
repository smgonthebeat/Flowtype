import XCTest
@testable import VoiceInputApp

/// Whole-pipeline corpus run (design.md 10.1): numeric, academic and math on, filler off, with each
/// row's known terms. Strict mode since execution stage 6; the report-mode baseline it replaced
/// (must-change 201 / 0, must-keep 612 / 609 on main @ ee0d573) is kept in corpus-report.txt.
final class MathCorpusTests: XCTestCase {
    private static let formats: [MathNotationOutputFormat] = [.unicode, .latex]

    private func process(_ row: MathCorpusSupport.CorpusRow, _ format: MathNotationOutputFormat, filler: Bool = false) -> String {
        TranscriptPostProcessor.process(row.input, options: MathCorpusSupport.options(format, knownTerms: row.terms, filler: filler))
    }

    func testFixtureIsAByteIdenticalCopyOfTheArtifactCorpus() throws {
        let artifactURL = MathCorpusSupport.corpusArtifactURL
        // The artifact lives in private maintenance records, which public source checkouts do not include.
        try XCTSkipUnless(FileManager.default.fileExists(atPath: artifactURL.path), "Artifact corpus is not part of this checkout.")
        let fixture = try Data(contentsOf: MathCorpusSupport.corpusFixtureURL)
        let artifact = try Data(contentsOf: artifactURL)
        XCTAssertEqual(fixture, artifact, "Tests/VoiceInputAppTests/Fixtures/math-corpus.jsonl must equal the artifact corpus.jsonl")
    }

    func testCorpusShape() throws {
        let rows = try MathCorpusSupport.corpus()
        // 2026-10-09: 16 must-change and 7 must-keep rows appended from the owner's in-app test
        // (source "owner-test"); 2026-10-10: 4 more for the owner's T11 case decision, which also
        // changed the expectations of MC-0038 and MC-0303 (see their notes); 2026-10-10 retest: 5
        // must-change and 7 must-keep rows. Formerly 1325 / 674 / 651.
        XCTAssertEqual(rows.count, 1364)
        XCTAssertEqual(rows.filter(\.isMustChange).count, 699)
        XCTAssertEqual(rows.filter { $0.kind == "must-keep" }.count, 665)
        XCTAssertEqual(rows.filter(\.isPipelineScope).count, 4)
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
    }

    /// I1: every row, both formats, through the whole pipeline.
    func testEveryRowMatchesThroughTheWholePipeline() throws {
        let rows = try MathCorpusSupport.corpus()
        var passed: [String: Int] = [:]
        for row in rows {
            for format in Self.formats {
                let actual = process(row, format)
                if actual == row.expected(format) {
                    passed["\(row.kind) \(format)", default: 0] += 1
                } else {
                    XCTFail("\(row.id) [\(format)] \(row.input.debugDescription) expected: \(row.expected(format).debugDescription) actual: \(actual.debugDescription)")
                }
            }
        }
        print("MathCorpusTests:", passed.sorted { $0.key < $1.key })
        // Counts follow the 2026-10-09 rows above. Formerly 674 / 651.
        XCTAssertEqual(passed["must-change unicode", default: 0], 699)
        XCTAssertEqual(passed["must-change latex", default: 0], 699)
        XCTAssertEqual(passed["must-keep unicode", default: 0], 665)
        XCTAssertEqual(passed["must-keep latex", default: 0], 665)
    }

    /// I2: processing the output again changes nothing.
    func testIdempotent() throws {
        for row in try MathCorpusSupport.corpus() {
            for format in Self.formats {
                let once = process(row, format)
                let options = MathCorpusSupport.options(format, knownTerms: row.terms)
                XCTAssertEqual(TranscriptPostProcessor.process(once, options: options), once, "\(row.id) [\(format)]")
            }
        }
    }

    /// I5: protected substrings (code, URL, e-mail, path, hotword, $...$) appear verbatim in the output.
    func testProtectedSpansAreKeptByteForByte() throws {
        let rows = try MathCorpusSupport.corpus().filter { ["code-url", "hotword", "rendered"].contains($0.category) || !$0.terms.isEmpty }
        XCTAssertGreaterThan(rows.count, 50)
        for row in rows {
            let barriers = MathLexer.lex(row.input, knownTerms: row.terms).tokens.filter { $0.kind == .barrier }.map(\.text)
            for format in Self.formats {
                let output = process(row, format)
                for barrier in barriers {
                    XCTAssertTrue(output.contains(barrier),
                                  "\(row.id) [\(format)] lost protected text \(barrier.debugDescription) in \(output.debugDescription)")
                }
            }
        }
    }

    /// I6: the filler switch does not change any math decision.
    func testFillerIndependence() throws {
        let hesitation = try NSRegularExpression(pattern: #"\b(?:um|uh|uhm|er|erm|hmm|umm)\b|[嗯呃额]"#, options: [.caseInsensitive])
        for row in try MathCorpusSupport.corpus() {
            let range = NSRange(row.input.startIndex..., in: row.input)
            let hasHesitation = hesitation.firstMatch(in: row.input, range: range) != nil
            for format in Self.formats {
                let accepted = { (text: String) in
                    MathStage.run(text, outputFormat: format, knownTerms: row.terms).acceptedSpans.map(\.rendered)
                }
                let off = process(row, format, filler: false)
                let on = process(row, format, filler: true)
                if hasHesitation {
                    // The formulas are the same; only the hesitations outside them may go.
                    for formula in accepted(row.input) {
                        XCTAssertTrue(off.contains(formula) && on.contains(formula), "\(row.id) [\(format)] \(formula)")
                    }
                } else if row.isMustChange {
                    XCTAssertEqual(on, off, "\(row.id) [\(format)]")
                }
            }
        }
    }

    /// I7: only the accepted spans change. Everything else is processed exactly as with the math
    /// switch off: replacing each accepted span by its protected rendering and running the math-off
    /// pipeline gives the math-on output.
    func testOnlyAcceptedSpansChange() throws {
        let rows = try MathCorpusSupport.corpus().filter { ["prose-en", "prose-zh"].contains($0.category) }
        XCTAssertGreaterThan(rows.count, 100)
        for row in rows {
            for format in Self.formats {
                let stage = MathStage.run(row.input, outputFormat: format, knownTerms: row.terms, wrapInSentinels: true)
                let off = TranscriptPostProcessor.process(
                    stage.text,
                    options: MathCorpusSupport.options(format, knownTerms: row.terms, math: false)
                )
                XCTAssertEqual(MathStage.stripSentinels(off), process(row, format), "\(row.id) [\(format)]")
            }
        }
    }

    /// I10: no sentinel character survives.
    func testNoSentinelLeaks() throws {
        for row in try MathCorpusSupport.corpus() {
            for format in Self.formats {
                let output = process(row, format)
                XCTAssertFalse(output.contains(MathStage.openSentinel) || output.contains(MathStage.closeSentinel), row.id)
            }
        }
    }
}
