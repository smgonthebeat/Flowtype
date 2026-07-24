import XCTest
@testable import VoiceInputApp

final class HotwordContextBuilderTests: XCTestCase {
    func testBuildsContextFromEnabledHotwords() {
        let words = [
            Hotword(text: "Cursor", isEnabled: true),
            Hotword(text: "Claude Code", isEnabled: true),
            Hotword(text: "disabled", isEnabled: false)
        ]

        let context = HotwordContextBuilder.context(for: words)

        XCTAssertEqual(context, "Cursor Claude Code")
    }

    func testLimitsContextLength() {
        let words = (0..<100).map { Hotword(text: "term\($0)") }

        let context = HotwordContextBuilder.context(for: words, maxCharacters: 80)

        XCTAssertLessThanOrEqual(context.count, 80)
        XCTAssertFalse(context.contains("Important terms to preserve exactly:"))
    }

    func testSkipsOversizedHotwordAndKeepsLaterFittingHotwords() {
        let words = [
            Hotword(text: String(repeating: "x", count: 100)),
            Hotword(text: "Cursor")
        ]

        let context = HotwordContextBuilder.context(for: words, maxCharacters: 60)

        XCTAssertEqual(context, "Cursor")
    }

    func testTrimsHotwordsAndIgnoresWhitespaceOnlyTerms() {
        let words = [
            Hotword(text: "  Cursor\n"),
            Hotword(text: "   "),
            Hotword(text: "\tClaude Code  ")
        ]

        let context = HotwordContextBuilder.context(for: words)

        XCTAssertEqual(context, "Cursor Claude Code")
    }

    func testReturnsEmptyStringWhenNoEnabledWords() {
        let context = HotwordContextBuilder.context(for: [Hotword(text: "Cursor", isEnabled: false)])

        XCTAssertEqual(context, "")
    }
}
