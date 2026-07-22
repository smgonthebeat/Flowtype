import XCTest
@testable import VoiceInputApp

final class MathCompositionMatrixTests: XCTestCase {
    func testSharedSubscriptCatalogMatrixForUnaryFunctions() {
        let cases: [(input: String, unicode: String, latex: String)] = [
            ("variance x sub four", "Var(X₄)", #"\mathrm{Var}(X_4)"#),
            ("variance x sub 4", "Var(X₄)", #"\mathrm{Var}(X_4)"#),
            ("variance x sub nine", "Var(X₉)", #"\mathrm{Var}(X_9)"#),
            ("variance x sub 10", "Var(X₁₀)", #"\mathrm{Var}(X_{10})"#),
            ("variance x sub twenty", "Var(X₂₀)", #"\mathrm{Var}(X_{20})"#),
            ("variance x sub m", "Var(Xₘ)", #"\mathrm{Var}(X_m)"#),
            ("variance x sub p", "Var(Xₚ)", #"\mathrm{Var}(X_p)"#),
            ("variance x sub q", "Var(X_q)", #"\mathrm{Var}(X_q)"#),
            ("variance x sub t minus one", "Var(Xₜ₋₁)", #"\mathrm{Var}(X_{t-1})"#),
            ("variance x sub i comma t", "Var(Xᵢ,ₜ)", #"\mathrm{Var}(X_{i,t})"#)
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

    func testSharedSubscriptCatalogMatrixForBinaryFunctions() {
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "corr x sub four y sub five", outputFormat: .unicode),
            "Corr(X₄,Y₅)"
        )
        XCTAssertEqual(
            MathSpeechParser.replaceStatisticsFunctions(in: "covariance n sub p n sub q", outputFormat: .latex),
            #"\mathrm{Cov}(N_p,N_q)"#
        )
    }
}
