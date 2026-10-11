import XCTest
@testable import VoiceInputApp

final class CodeSpanProtectionTests: XCTestCase {
    func testCodeContract01() {
        ResidualRepairAssertions.check("`five point six`", when: { _ in true }, expected: { _ in "`five point six`" })
    }
    func testCodeContract02() {
        ResidualRepairAssertions.check("`L 5`", when: { _ in true }, expected: { _ in "`L 5`" })
    }
    func testCodeContract03() {
        ResidualRepairAssertions.check("```\nfive point six L 5\n```", when: { _ in true }, expected: { _ in "```\nfive point six L 5\n```" })
    }
    func testCodeContract04() {
        ResidualRepairAssertions.check("``five point six ` L 5``", when: { _ in true }, expected: { _ in "``five point six ` L 5``" })
    }
    func testCodeContract05() {
        ResidualRepairAssertions.check("`five point six", when: { _ in true }, expected: { _ in "`five point six" })
    }
    func testCodeContract06() {
        ResidualRepairAssertions.check("`five point six\n  ", when: { _ in true }, expected: { _ in "`five point six\n  " })
    }
    func testCodeContract07() {
        ResidualRepairAssertions.check("`chat g p t`", when: { _ in true }, expected: { _ in "`chat g p t`" })
    }
    func testCodeContract08() {
        ResidualRepairAssertions.check("`x!  y\n\n\nz`", when: { _ in true }, expected: { _ in "`x!  y\n\n\nz`" })
    }
    func testCodeContract09() {
        ResidualRepairAssertions.check("`um five point six L 5 SD β`", when: { _ in true }, expected: { _ in "`um five point six L 5 SD β`" })
    }
    func testCodeContract10() {
        ResidualRepairAssertions.check("`https://example.com/five`", when: { _ in true }, expected: { _ in "`https://example.com/five`" })
    }
    func testCodeContract11() {
        ResidualRepairAssertions.check("https://example.com/`five`seven", when: { _ in true }, expected: { _ in "https://example.com/`five`seven" })
    }
    func testCodeContract12() {
        ResidualRepairAssertions.check("🙂 `five point six` café", when: { _ in true }, expected: { _ in "🙂 `five point six` café" })
    }
    func testCodeContract13() {
        ResidualRepairAssertions.check("`five` `six`", when: { _ in true }, expected: { _ in "`five` `six`" })
    }
    func testCodeContract14() {
        ResidualRepairAssertions.check("five. `six`. seven.", when: { $0.isSmartNumericFormattingEnabled == true }, expected: { _ in "5. `six`. 7." })
        ResidualRepairAssertions.check("five. `six`. seven.", when: { $0.isSmartNumericFormattingEnabled == false }, expected: { _ in "five. `six`. seven." })
    }
    func testCodeContract15() {
        ResidualRepairAssertions.check("\"five point six\"", when: { $0.isSmartNumericFormattingEnabled == true }, expected: { _ in "\"5.6\"" })
        ResidualRepairAssertions.check("\"five point six\"", when: { $0.isSmartNumericFormattingEnabled == false }, expected: { _ in "\"five point six\"" })
    }
    func testCodeContract16() {
        ResidualRepairAssertions.check("A部分我会了，参考 `L 5`，再讲一B。", when: { $0.isAcademicReferenceFormattingEnabled == true }, expected: { _ in "A部分我会了，参考 `L 5`，再讲A1(b)。" })
        ResidualRepairAssertions.check("A部分我会了，参考 `L 5`，再讲一B。", when: { $0.isAcademicReferenceFormattingEnabled == false }, expected: { _ in "A部分我会了，参考 `L 5`，再讲一B。" })
    }
    func testCodeContract17() {
        ResidualRepairAssertions.check("chat g p t and `chat g p t`", when: { _ in true }, expected: { _ in "ChatGPT and `chat g p t`" })
    }
    func testCodeContract18() {
        ResidualRepairAssertions.check("a!  B `a!  B`", when: { _ in true }, expected: { _ in "a. B `a!  B`" })
    }
}
