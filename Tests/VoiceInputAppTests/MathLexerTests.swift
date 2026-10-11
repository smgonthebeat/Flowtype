import XCTest
@testable import VoiceInputApp

/// design.md section 3: token kinds, protected spans, Han longest match, compact splitting,
/// label claiming and sentence marks.
final class MathLexerTests: XCTestCase {
    private func tokens(_ text: String, knownTerms: [String] = []) -> [MathToken] {
        MathLexer.lex(text, knownTerms: knownTerms).tokens
    }

    private func summary(_ text: String, knownTerms: [String] = []) -> [String] {
        tokens(text, knownTerms: knownTerms).map { "\($0.kind):\($0.text)" }
    }

    func testTokenKinds() {
        XCTAssertEqual(summary("x squared = 12, 0.05 x-ray"), [
            "word:x", "word:squared", "symbol:=", "number:12", "punctuation:,", "number:0.05", "prose:x-ray"
        ])
        XCTAssertEqual(summary("p-value people's"), ["word:p-value", "prose:people's"])
        XCTAssertEqual(summary("x2y 3rd"), ["prose:x2y", "prose:3rd"])
        // Course codes, versions and model IDs are protected spans from ProtectedSpanDetector.
        XCTAssertEqual(summary("STAT0002 v1.2"), ["barrier:STAT0002", "barrier:v1.2"])
    }

    func testOnlyASCIIDigitsAreNumbers() {
        // ² and ₁ are notation characters, not digits.
        XCTAssertEqual(summary("x²"), ["prose:x", "symbol:²"])
        XCTAssertEqual(summary("β₁x"), ["symbol:β", "symbol:₁", "prose:x"])
    }

    func testExistingNotationIsInert() {
        XCTAssertEqual(summary("f(x) a/b 5%"), [
            "prose:f", "symbol:(", "prose:x", "symbol:)", "prose:a", "symbol:/", "prose:b", "prose:5", "symbol:%"
        ])
    }

    func testProtectedSpansAreBarriers() {
        XCTAssertEqual(summary("run `x plus y` now"), ["word:run", "barrier:`x plus y`", "word:now"])
        XCTAssertEqual(summary("see `x plus y"), ["word:see", "barrier:`x plus y"])
        XCTAssertEqual(summary("go to https://example.com/x+y now"), [
            "word:go", "word:to", "barrier:https://example.com/x+y", "word:now"
        ])
        XCTAssertEqual(summary("mail a.b@example.com"), ["word:mail", "barrier:a.b@example.com"])
        XCTAssertEqual(summary("open /Users/me/x squared"), ["word:open", "barrier:/Users/me/x", "word:squared"])
        XCTAssertEqual(summary("we have $x^2$ here"), ["word:we", "word:have", "barrier:$x^2$", "word:here"])
        XCTAssertEqual(summary("Beta Hat Labs is great", knownTerms: ["Beta Hat Labs"]), [
            "barrier:Beta Hat Labs", "word:is", "word:great"
        ])
    }

    func testHanLongestMatch() {
        XCTAssertEqual(summary("x的平方"), ["word:x", "zh:的平方"])
        XCTAssertEqual(summary("x的期望"), ["word:x", "zh:的", "zh:期望"])
        XCTAssertEqual(summary("九十平方米"), ["zhNumber:九十", "hanProse:平方米"])
        XCTAssertEqual(summary("大于等于"), ["zh:大于等于"])
    }

    func testChineseNumerals() {
        let lexed = tokens("零点五 三十二 二三 百分之五十")
        XCTAssertEqual(lexed.map(\.kind), [.zhNumber, .zhNumber, .zhNumber, .hanProse])
        XCTAssertEqual(lexed.map(\.value), ["0.5", "32", "23", nil])
        XCTAssertEqual(lexed[3].text, "百分之五十")
    }

    func testCompactSplitting() {
        XCTAssertEqual(summary("thetahat"), ["word:theta", "word:hat"])
        XCTAssertEqual(summary("subzero"), ["word:sub", "word:zero"])
        XCTAssertEqual(summary("Xbar"), ["word:X", "word:bar"])
        XCTAssertEqual(summary("Xsub1"), ["word:X", "word:sub", "number:1"])
        XCTAssertEqual(summary("x1"), ["word:x", "number:1"])
        for word in ["What", "That", "chat", "ChatGPT", "what", "ahead"] {
            XCTAssertEqual(summary(word).count, 1, word)
        }
    }

    /// The cases of the retired CompactASRTokenNormalizerTests (design.md 10.2): splitting now happens
    /// in the lexer. Chains such as NsubiNsubj are not split any more (design.md 3 rule 4 covers one
    /// letter + sub + index); formerly "N sub i N sub j".
    func testFormerCompactTokenCases() {
        XCTAssertEqual(summary("Nsubj"), ["word:N", "word:sub", "word:j"])
        XCTAssertEqual(summary("Xsub10"), ["word:X", "word:sub", "number:10"])
        XCTAssertEqual(summary("Zsubt"), ["word:Z", "word:sub", "word:t"])
        XCTAssertEqual(summary("NsubiNsubj"), ["word:NsubiNsubj"])
        XCTAssertEqual(summary("Xbar"), ["word:X", "word:bar"])
        XCTAssertEqual(summary("Yhat"), ["word:Y", "word:hat"])
        XCTAssertEqual(summary("Nprime"), ["word:N", "word:prime"])
        for text in ["subway", "barbecue", "the X factor", "core ideas are useful"] {
            XCTAssertEqual(summary(text).map { String($0.split(separator: ":")[1]) }, text.split(separator: " ").map(String.init), text)
        }
    }

    func testLabelsClaimTheNextLetterOrNumber() {
        let claimed = { (text: String) in self.tokens(text).filter(\.isClaimedByLabel).map(\.text) }
        XCTAssertEqual(claimed("Q three part B"), ["three", "B"])
        XCTAssertEqual(claimed("vitamin C and plan B"), ["C", "B"])
        XCTAssertEqual(claimed("x plus y"), [])
    }

    func testSentenceInitialMarks() {
        let lexed = tokens("X bar. Then y")
        XCTAssertEqual(lexed.filter(\.isSentenceInitial).map(\.text), ["X", "Then"])
        XCTAssertEqual(lexed.map(\.sentence), [0, 0, 0, 1, 1])
    }
}
