import XCTest
@testable import VoiceInputApp

final class RenderedMathArgumentReaderTests: XCTestCase {
    func testEmittedAtomsModifiersAndScriptsRoundTrip() throws {
        let modifiers: [MathModifier] = [.hat, .bar, .tilde, .dot, .doubleDot, .prime,
                                        .doublePrime, .star, .transpose, .inverse, .squared, .cubed]
        for definition in MathSymbolCatalog.allGreek {
            let atom = MathExpression.symbol(MathSymbolAtom(spoken: definition.spoken,
                latex: definition.latex, unicode: definition.unicode))
            let index = MathExpression.symbol(MathSymbolAtom(spoken: "i", latex: "i", unicode: "i"))
            let expressions = [atom] + modifiers.map { .modified(base: atom, modifier: $0) }
                + [.subscripted(base: atom, index: index)]
            for expression in expressions {
                for format in [MathNotationOutputFormat.unicode, .latex] {
                    let rendered = MathRenderer.render(expression, outputFormat: format)
                    let parsed = try XCTUnwrap(RenderedMathArgumentReader.read(rendered), rendered)
                    XCTAssertEqual(MathRenderer.render(parsed, outputFormat: format), rendered)
                }
            }
        }
    }

    func testFiniteCommandGrammarRejectsPartialAndMalformedTokens() {
        for token in [#"\Beta"#, #"\betamax"#, #"\beta{evil}"#, #"\hat{\beta"#,
                      #"\hat{\unknown}"#, #"\unknown{\beta}"#, #"\beta_i_extra"#,
                      String(repeating: #"\hat{"#, count: 20) + "X" + String(repeating: "}", count: 20)] {
            XCTAssertNil(RenderedMathArgumentReader.read(token), token)
            XCTAssertNil(MathSpeechParser.parseArgumentExpression(token), token)
        }
        for token in [#"\betaᵢ"#, "β^2", "β'", #"β̂_i"#, #"\hat{\beta}_i"#, "β*"] {
            XCTAssertNotNil(RenderedMathArgumentReader.read(token), token)
        }
    }
}
