import XCTest
@testable import VoiceInputApp

/// Engine-level corpus run (execution spec stage 5): MathStage alone, compared the same way the
/// reference prototype was checked. must-change rows give the expected output; must-keep rows stay
/// untouched. Pipeline-scope rows involve other stages and are covered by MathCorpusTests.
final class MathStageCorpusTests: XCTestCase {
    func testEveryEngineScopeRowMatches() throws {
        let rows = try MathCorpusSupport.corpus().filter { !$0.isPipelineScope }
        // 2026-10-09 / 2026-10-10: 39 owner-test rows appended (all engine scope). Formerly 1321.
        XCTAssertEqual(rows.count, 1360)
        var failures: [String] = []
        var passed = ["must-change": 0, "must-keep": 0]
        for row in rows {
            var good = true
            for format in [MathNotationOutputFormat.unicode, .latex] {
                let actual = MathStage.run(row.input, outputFormat: format, knownTerms: row.terms).text
                let expected = row.isMustChange ? row.expected(format) : row.input
                if actual != expected {
                    good = false
                    failures.append("\(row.id) [\(format)] \(row.input.debugDescription)\n   expected: \(expected.debugDescription)\n   actual:   \(actual.debugDescription)")
                }
            }
            if good { passed[row.kind, default: 0] += 1 }
        }
        print("MathStageCorpusTests: must-change \(passed["must-change"]!) / 695, must-keep \(passed["must-keep"]!) / 665")
        if !failures.isEmpty { print(failures.prefix(80).joined(separator: "\n")) }
        // Formerly 670 / 651; see the row count above.
        XCTAssertEqual(passed["must-change"], 695)
        XCTAssertEqual(passed["must-keep"], 665)
    }

    /// I2 at the engine level: the stage is idempotent on its own output.
    func testStageIsIdempotentOnTheCorpus() throws {
        for row in try MathCorpusSupport.corpus() {
            for format in [MathNotationOutputFormat.unicode, .latex] {
                let once = MathStage.run(row.input, outputFormat: format, knownTerms: row.terms).text
                let twice = MathStage.run(once, outputFormat: format, knownTerms: row.terms).text
                XCTAssertEqual(once, twice, "\(row.id) [\(format)]")
            }
        }
    }

    /// I3: both formats accept exactly the same source ranges.
    func testBothFormatsAcceptTheSameSourceSpans() throws {
        for row in try MathCorpusSupport.corpus() {
            let unicode = MathStage.run(row.input, outputFormat: .unicode, knownTerms: row.terms).acceptedSpans.map(\.range)
            let latex = MathStage.run(row.input, outputFormat: .latex, knownTerms: row.terms).acceptedSpans.map(\.range)
            XCTAssertEqual(unicode, latex, row.id)
        }
    }
}
