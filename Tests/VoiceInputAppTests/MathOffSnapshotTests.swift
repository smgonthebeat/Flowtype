import XCTest
@testable import VoiceInputApp

/// Invariant I4 (design.md 10.1): with the math switch off, the output is byte-identical to the code
/// at main @ ee0d573. The snapshot was frozen before the rebuild by
/// docs/maintenance/artifacts/2026-10-03-math-notation-rebuild/corpus-src/gen_math_off_snapshot.py.
final class MathOffSnapshotTests: XCTestCase {
    func testMathOffOutputIsByteIdenticalToTheSnapshot() throws {
        let rows = try MathCorpusSupport.snapshot()
        XCTAssertGreaterThan(rows.count, 2600)
        var failures = 0
        for row in rows {
            for (filler, expected) in [(false, row.numericAcademic), (true, row.all)] {
                let options = MathCorpusSupport.options(.unicode, knownTerms: row.knownTerms, math: false, filler: filler)
                let actual = TranscriptPostProcessor.process(row.input, options: options)
                // Byte comparison, not canonical equivalence: nothing may change with the switch off.
                if Array(actual.utf8) != Array(expected.utf8) {
                    failures += 1
                    if failures <= 20 {
                        XCTFail("filler \(filler) input: \(row.input.debugDescription) expected: \(expected.debugDescription) actual: \(actual.debugDescription)")
                    }
                }
            }
        }
        XCTAssertEqual(failures, 0, "math-off outputs that differ from the snapshot")
    }

    func testMathOffOutputDoesNotDependOnTheOutputFormat() throws {
        let rows = try MathCorpusSupport.snapshot().prefix(400)
        for row in rows {
            let unicode = TranscriptPostProcessor.process(row.input, options: MathCorpusSupport.options(.unicode, knownTerms: row.knownTerms, math: false))
            let latex = TranscriptPostProcessor.process(row.input, options: MathCorpusSupport.options(.latex, knownTerms: row.knownTerms, math: false))
            XCTAssertEqual(Array(unicode.utf8), Array(latex.utf8), row.input)
        }
    }
}
