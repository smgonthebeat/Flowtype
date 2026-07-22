import XCTest
@testable import VoiceInputApp

final class MathNotationIdempotencyTests: XCTestCase {
    func testUnicodeMathOutputIsStableWhenFormattedAgain() {
        let inputs = [
            "variance x",
            "variance beta hat",
            "variance x sub i squared",
            "standard error beta hat",
            "corr beta hat gamma bar",
            "chi squared with 4 degrees of freedom"
        ]

        for input in inputs {
            let once = MathNotationFormatter.format(input, outputFormat: .unicode)
            let twice = MathNotationFormatter.format(once, outputFormat: .unicode)
            XCTAssertEqual(twice, once, input)
        }
    }

    func testLatexMathOutputIsStableWhenFormattedAgain() {
        let inputs = [
            "variance x",
            "variance beta hat",
            "variance x sub i squared",
            "standard error beta hat",
            "corr beta hat gamma bar"
        ]

        for input in inputs {
            let once = MathNotationFormatter.format(input, outputFormat: .latex)
            let twice = MathNotationFormatter.format(once, outputFormat: .latex)
            XCTAssertEqual(twice, once, input)
        }
    }
}
