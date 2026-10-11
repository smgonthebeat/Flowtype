import Foundation
import XCTest
@testable import VoiceInputApp

/// The 31 legacy golden cases (formerly Fixtures/math-notation-cases.jsonl), migrated by the math
/// rebuild (design.md 10.2). 27 of them live in the corpus with their old id in `note` or as the same
/// input; their expectations follow the contract (D1 $...$, D4 \operatorname and comma spacing,
/// 5.2 relations). The four inputs the corpus does not contain verbatim are asserted below.
final class MathNotationGoldenTests: XCTestCase {
    private static let legacyIDs = [
        "MATH001", "MATH002", "MATH003", "MATH004", "MATH005", "MATH006", "MATH007", "MATH008", "MATH009", "MATH010",
        "MATH011", "MATH012", "MATH020", "MATH021", "MATH022", "MATH023", "MATH024", "MATH025", "MATH026", "MATH027",
        "MATH028", "MATH029", "MATH030", "MATH031"
    ]
    /// Legacy negative cases and MATH028, which the corpus holds under the same input.
    private static let legacyInputsInCorpus = [
        "var x = 1", "variants of products", "open https://example.com/var/x-bar today", "Use `var x` in Swift",
        "standard error beta hat", "standard error message", "expectation is that x will rise",
        "Use `expectation x` in notes"
    ]

    private func format(_ input: String, _ format: MathNotationOutputFormat) -> String {
        MathNotationFormatter.format(input, outputFormat: format)
    }

    func testLegacyCasesInTheCorpus() throws {
        let rows = try MathCorpusSupport.corpus()
        let byNote = rows.filter { row in Self.legacyIDs.contains { row.note?.contains($0) == true } }
        let byInput = rows.filter { Self.legacyInputsInCorpus.contains($0.input) }
        XCTAssertEqual(byNote.count, 20)
        XCTAssertEqual(byInput.count, Self.legacyInputsInCorpus.count)
        for row in byNote + byInput {
            for outputFormat in [MathNotationOutputFormat.unicode, .latex] {
                let expected = row.isMustChange ? row.expected(outputFormat) : row.input
                XCTAssertEqual(format(row.input, outputFormat), expected, "\(row.id) \(row.note ?? "")")
            }
        }
    }

    func testLegacyCasesOutsideTheCorpus() {
        // MATH001: "equals" is a relation (design.md 5.2); LaTeX is $...$ per formula (D1).
        // Formerly θ̂ equals x̄ and σ² / \hat{\theta} equals \bar{x} and \sigma^2.
        XCTAssertEqual(format("theta hat equals x bar and sigma squared", .unicode), "θ̂ = x̄ and σ²")
        XCTAssertEqual(format("theta hat equals x bar and sigma squared", .latex), #"$\hat{\theta} = \bar{x}$ and $\sigma^2$"#)
        // MATH006: unchanged in Unicode; LaTeX $\operatorname{Var}$ (D1, D4). Formerly \mathrm{Var}(Y).
        XCTAssertEqual(format("Variants of Y.", .unicode), "Var(Y).")
        XCTAssertEqual(format("Variants of Y.", .latex), #"$\operatorname{Var}(Y)$."#)
        // MATH008: rendered notation is inert and is not re-parsed (design.md 3 rule 3, 10.2).
        // Formerly Var(X̄) / \mathrm{Var}(\bar{X}).
        XCTAssertEqual(format("Var(X) bar", .unicode), "Var(X) bar")
        XCTAssertEqual(format("Var(X) bar", .latex), "Var(X) bar")
        // MATH011: covariance needs two arguments, so only the second formula converts.
        // Unicode unchanged; LaTeX formerly covariance of y, \mathrm{Var}(E).
        XCTAssertEqual(format("covariance of y, variance of e", .unicode), "covariance of y, Var(E)")
        XCTAssertEqual(format("covariance of y, variance of e", .latex), #"covariance of y, $\operatorname{Var}(E)$"#)
    }
}
