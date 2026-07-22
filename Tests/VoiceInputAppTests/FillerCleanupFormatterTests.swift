import XCTest
@testable import VoiceInputApp

final class FillerCleanupFormatterTests: XCTestCase {
    func testRemovesShortChineseFillers() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("嗯，我现在说呃，theta hat"),
            "我现在说 theta hat"
        )
    }

    func testRemovesMoreChineseFillers() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("哦，就是我现在啊发现哎这个问题"),
            "就是我现在发现这个问题"
        )
    }

    func testPreservesLatinAInChineseContext() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("这个 a 我们继续，a，这样就可以"),
            "这个 a 我们继续，a，这样就可以"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("就是 a 四要背的内容"),
            "就是 a 四要背的内容"
        )
    }

    func testRemovesEnglishFillers() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("I think, em, theta hat and um alpha"),
            "I think, theta hat and alpha"
        )
    }

    func testRemovesEnglishFillerBeforeChineseText() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("Uh.他自己写了 draft"),
            "他自己写了 draft"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("uh，然后我们继续"),
            "然后我们继续"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("um。然后我们继续"),
            "然后我们继续"
        )
    }

    func testKeepsEnglishArticleA() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("This is a test and a model"),
            "This is a test and a model"
        )
    }

    func testPreservesWordsContainingEnglishFillerLetters() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("huh?"),
            "huh?"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("UHF radio"),
            "UHF radio"
        )
        XCTAssertEqual(
            FillerCleanupFormatter.format("Suharto and Ahmad"),
            "Suharto and Ahmad"
        )
    }

    func testPreservesDiscoursePhrases() {
        XCTAssertEqual(
            FillerCleanupFormatter.format("怎么说呢，就是说，然后呢，我们继续"),
            "怎么说呢，就是说，然后呢，我们继续"
        )
    }
}
