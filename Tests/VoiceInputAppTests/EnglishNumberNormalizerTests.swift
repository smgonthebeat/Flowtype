import XCTest
@testable import VoiceInputApp

final class EnglishNumberNormalizerTests: XCTestCase {
    func testConvertsStandaloneEnglishNumberWordsHarshly() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("I need four, five, ten, twelve, thirteen, fourteen, fifty examples."),
            "I need 4, 5, 10, 12, 13, 14, 50 examples."
        )
    }

    func testConvertsEnglishNumbersInOrdinaryAcademicPhrases() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("Problem set one. problem set twelve. week fourteen. question ninety nine."),
            "Problem set 1. problem set 12. week 14. Question 99."
        )
    }

    func testConvertsCompoundEnglishNumbers() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("twenty one, thirty five, ninety nine"),
            "21, 35, 99"
        )
    }

    func testKeepsHyphenatedEnglishWordsReadable() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("a one-time reminder"),
            "a one-time reminder"
        )
    }
}
