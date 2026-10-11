import XCTest
@testable import VoiceInputApp

/// I8 (typical long dictation) and I9 (worst cases), design.md 10.1. The debug-build bounds here are
/// loose guards; the release-build numbers are measured separately and written to the record.
final class MathPerformanceTests: XCTestCase {
    /// About 5,000 characters of mixed Chinese / English dictation with more than 30 formulas,
    /// built from corpus inputs so the mix of formulas and prose is realistic.
    static func longDictation() throws -> String {
        let rows = try MathCorpusSupport.corpus()
        let formulas = rows.filter { $0.isMustChange && !$0.isPipelineScope }
        let prose = rows.filter { !$0.isMustChange }
        var parts: [String] = []
        var k = 0
        while parts.joined(separator: " ").count < 5_000 {
            parts.append(formulas[(k * 7) % formulas.count].input + "。")
            parts.append(prose[(k * 5) % prose.count].input)
            k += 1
        }
        return parts.joined(separator: " ")
    }

    private func median(_ samples: [Double]) -> Double { samples.sorted()[samples.count / 2] }

    private func milliseconds(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    func testLongMixedDictation() throws {
        let text = try Self.longDictation()
        XCTAssertGreaterThanOrEqual(text.count, 5_000)
        let accepted = MathStage.run(text, outputFormat: .unicode).acceptedSpans.count
        XCTAssertGreaterThan(accepted, 30)
        let samples = (0..<7).map { _ in milliseconds { _ = MathStage.run(text, outputFormat: .unicode) } }
        let pipeline = (0..<5).map { _ in
            milliseconds { _ = TranscriptPostProcessor.process(text, options: MathCorpusSupport.options(.unicode, knownTerms: [])) }
        }
        print("MathPerformanceTests: \(text.count) chars, \(accepted) formulas, MathStage median \(median(samples)) ms (debug), whole pipeline median \(median(pipeline)) ms (debug)")
        XCTAssertLessThan(median(samples), 100)
    }

    func testWorstCasesTerminateQuickly() {
        let cases = [
            ("2,000 x plus", String(repeating: "x plus ", count: 2_000) + "x"),
            ("5,000 letters without spaces", String(repeating: "abcde", count: 1_000)),
            ("nested quantity", String(repeating: "the quantity ", count: 500) + "x"),
            ("5,000 single letters", String(repeating: "x ", count: 5_000)),
            ("long Chinese run", String(repeating: "x 的平方加", count: 1_000) + "y")
        ]
        for (name, text) in cases {
            var output = ""
            let elapsed = milliseconds { output = MathStage.run(text, outputFormat: .latex).text }
            print("MathPerformanceTests worst case \(name): \(text.count) chars, \(elapsed) ms (debug)")
            XCTAssertLessThan(elapsed, 1_000, name)
            XCTAssertFalse(output.isEmpty, name)
        }
    }
}
