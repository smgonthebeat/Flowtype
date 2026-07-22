import XCTest
@testable import VoiceInputApp

final class MathArgumentParserMatrixTests: XCTestCase {
    func testVarianceAcceptsCommonSymbolsAndModifiers() {
        let cases: [(input: String, unicode: String, latex: String)] = [
            ("variance a", "Var(A)", #"\mathrm{Var}(A)"#),
            ("variance z", "Var(Z)", #"\mathrm{Var}(Z)"#),
            ("variance rho", "Var(ρ)", #"\mathrm{Var}(\rho)"#),
            ("variance omega bar", "Var(ω̄)", #"\mathrm{Var}(\bar{\omega})"#),
            ("variance beta hat", "Var(β̂)", #"\mathrm{Var}(\hat{\beta})"#),
            ("variance x prime", "Var(X′)", #"\mathrm{Var}(X')"#)
        ]

        for testCase in cases {
            XCTAssertEqual(
                MathSpeechParser.replaceStatisticsFunctions(in: testCase.input, outputFormat: .unicode),
                testCase.unicode,
                testCase.input
            )
            XCTAssertEqual(
                MathSpeechParser.replaceStatisticsFunctions(in: testCase.input, outputFormat: .latex),
                testCase.latex,
                testCase.input
            )
        }
    }

    func testBinaryFunctionsAcceptComposedArguments() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "corr x sub i y sub i", outputFormat: .unicode),
            "Corr(Xᵢ,Yᵢ)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "covariance beta hat theta bar", outputFormat: .latex),
            #"\mathrm{Cov}(\hat{\beta},\bar{\theta})"#
        )
    }
}
