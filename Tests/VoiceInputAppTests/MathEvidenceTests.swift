import XCTest
@testable import VoiceInputApp

/// design.md 6.2 (each rule positive and negative), 6.3 (alias rule) and 6.4 (accepted trade-offs).
final class MathEvidenceTests: XCTestCase {
    private func unicode(_ text: String) -> String { MathStage.run(text, outputFormat: .unicode).text }

    private func assertKeeps(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(unicode(text), text, file: file, line: line)
    }

    private func reasons(_ text: String) -> [String] {
        MathStage.run(text, outputFormat: .unicode).spans.map(\.decision.reason)
    }

    func testRule1BareLetterOrNumber() {
        assertKeeps("x")
        assertKeeps("five")
        XCTAssertEqual(reasons("x"), ["bare letter"])
        XCTAssertEqual(unicode("x plus y"), "x + y")
    }

    func testRule2SingleGreekName() {
        XCTAssertEqual(unicode("theta"), "θ")
        XCTAssertEqual(reasons("theta"), ["standalone symbol"])
        // A capitalised name followed by a capitalised word, or after an article, is a name or a noun.
        assertKeeps("Mu Online is a game")
        assertKeeps("Sigma Chi fraternity")
        assertKeeps("I saw a beta there")
        // Math-dominant names convert in a sentence.
        XCTAssertEqual(unicode("where sigma is the standard deviation"), "where σ is the standard deviation")
        // Prose-common names need a cue word or another formula in the sentence.
        assertKeeps("call omega later")
        XCTAssertEqual(unicode("the parameter alpha is small"), "the parameter α is small")
        XCTAssertEqual(unicode("x squared and alpha"), "x² and α")
        // Collocations block the name in the lexer-level tables.
        assertKeeps("We released the beta version")
        assertKeeps("six sigma training")
    }

    func testRule3PronounI() {
        assertKeeps("I choose B")
        XCTAssertEqual(unicode("I plus one"), "i + 1")
    }

    func testRule4GreekWithAConnector() {
        XCTAssertEqual(unicode("two pi r"), "2πr")
        assertKeeps("Alpha Rho Chi")
    }

    func testRule5NumbersOnlyRelation() {
        assertKeeps("five is less than ten")
        XCTAssertEqual(reasons("five is less than ten"), ["numbers only without arithmetic"])
        XCTAssertEqual(unicode("two plus two equals four"), "2 + 2 = 4")
    }

    func testRule6EvidenceScore() {
        XCTAssertEqual(unicode("we know that x is greater than zero"), "we know that x > 0")
        assertKeeps("the grade went from A plus B")
    }

    func testLetterRunsGetNoSentenceBonus() {
        // A spelled letter run next to a formula stays spelling (design.md 5.2 negative examples).
        XCTAssertEqual(unicode("S O L 和 x squared"), "S O L 和 x²")
        XCTAssertEqual(unicode("two x plus y, and x y"), "2x + y, and x y")
    }

    func testRule7StandaloneFormula() {
        XCTAssertEqual(unicode("a over b"), "a/b")
        XCTAssertEqual(reasons("a over b"), ["standalone formula"])
        assertKeeps("I chose A over B")
    }

    func testRule8AndCodeContext() {
        assertKeeps("var x = 1")
        assertKeeps("the p value is small")
        assertKeeps("x one")
    }

    func testAliasRule() {
        // 6.3: an alias contributes no evidence; the rest of the span must carry it.
        XCTAssertEqual(unicode("standard error better hat"), "SE(β̂)")
        XCTAssertEqual(unicode("Y equals better zero plus better one x plus epsilon."), "y = β₀ + β₁x + ε.")
        assertKeeps("I need a better head start")
        assertKeeps("this is a better one")
    }

    func testAcceptedTradeOffs() {
        // 6.4
        XCTAssertEqual(unicode("Sigma is the standard deviation."), "σ is the standard deviation.")
        XCTAssertEqual(unicode("one plus r over n"), "(1 + r)/n")
        assertKeeps("two times three")
        assertKeeps("minus five")
    }

    func testHypothesisSymbols() {
        // Default T9: h zero converts directly; h one needs another formula or a standalone utterance.
        XCTAssertEqual(unicode("we reject h zero"), "we reject H₀")
        XCTAssertEqual(unicode("h one"), "H₁")
    }

    func testSplitEnglishWordsCountAsAliases() {
        // The recogniser writes "What" as "W hat": the accent is an alias (design.md 6.3), so the
        // letter needs other evidence or a whole-utterance formula.
        assertKeeps("W hat does ETN stand for in financial products?")
        assertKeeps("how does W hat affect the sentence?")
        XCTAssertEqual(unicode("W hat is x squared"), "W hat is x²")
        XCTAssertEqual(unicode("W hat equals zero"), "ŵ = 0")
        XCTAssertEqual(unicode("W hat"), "ŵ")
        // p hat is not an English word: ordinary accent evidence.
        XCTAssertEqual(unicode("the sample proportion p hat is unbiased"), "the sample proportion p̂ is unbiased")
    }

    func testBareExpectationNeedsAWholeUtterance() {
        XCTAssertEqual(unicode("E T"), "E[T]")
        XCTAssertEqual(unicode("E X."), "E[X].")
        assertKeeps("what is E T in finance?")
        assertKeeps("E U")
    }

    /// The 11 scenarios of the retired MathIntentGateTests (whole-transcript gate), now decided per
    /// span (design.md 10.2). Each comment gives the old outcome.
    func testFormerWholeTranscriptGateScenarios() {
        // Kept original (plain-English blocker): W hat is a split English word (design.md 6.3).
        assertKeeps("W hat does E T N stand for in financial products?")
        // Kept original (code-like blocker). Changed: the code rule covers short names only (6.2);
        // owner to confirm (record section 5).
        XCTAssertEqual(unicode("write standard error beta hat in Swift"), "write SE(β̂) in Swift")
        // Accepted (short formula).
        XCTAssertEqual(unicode("E T"), "E[T]")
        // Accepted (formula anchor). Now with = (5.2) and a lower-case sentence-initial letter (D5).
        XCTAssertEqual(unicode("C hat equals beta"), "ĉ = β")
        // Owner decision 2026-10-10 (T11): mid-sentence letters are lower case too; was "what is Ĉ = β?".
        XCTAssertEqual(unicode("what is C hat equals beta?"), "what is ĉ = β?")
        // Kept original: compounds and paths are not spoken math (design.md 3 rule 3).
        assertKeeps("search for alpha-beta")
        assertKeeps("open docs/alpha")
        // Accepted (longer formula-like sequence).
        XCTAssertEqual(unicode("alpha hat and x sub i"), "α̂ and xᵢ")
        // Kept original (no supporting signal / prose predicate): alpha is prose-common (6.2 rule 2).
        assertKeeps("alpha remains significant in this model")
        assertKeeps("alpha is significant")
        assertKeeps("plain text")
    }

    func testDecisionsAreTracedPerSpan() {
        let result = MathStage.run("x squared. Call omega later.", outputFormat: .unicode)
        XCTAssertEqual(result.events.map(\.ruleID), ["math.span.accepted", "math.span.rejected"])
    }
}
