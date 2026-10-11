import XCTest
@testable import VoiceInputApp

final class PreferencesExampleFormattingTests: XCTestCase {
    func testChineseExamplesSplitIntoPairsAndTrailingNote() {
        let lines = PreferencesExampleFormatting.lines("示例：百分之三点五 → 3.5%；第三题 → 第3题。“这段代码两三行”保持不变")

        XCTAssertEqual(lines, [
            .pair("百分之三点五", "3.5%"),
            .pair("第三题", "第3题"),
            .note("“这段代码两三行”保持不变")
        ])
    }

    func testEnglishExamplesKeepDecimalsInsideOutputs() {
        let lines = PreferencesExampleFormatting.lines("Examples: twenty one → 21; three point five → 3.5. \"No one knows\" stays as spoken")

        XCTAssertEqual(lines, [
            .pair("twenty one", "21"),
            .pair("three point five", "3.5"),
            .note("\"No one knows\" stays as spoken")
        ])
    }

    /// The math examples under 数学与统计符号 must be what the formatter does (math rebuild, D1:
    /// LaTeX is wrapped in $...$).
    func testMathExamplesMatchTheFormatter() {
        for language in [UILanguage.chinese, .english] {
            let examples = PreferencesCopy.texts(for: language).mathNotationExamples
            for (spoken, unicode) in [("variance x", "Var(X)"), ("standard error beta hat", "SE(β̂)"), ("theta hat", "θ̂"),
                                      ("x sub i", "xᵢ"), ("x bar", "x̄")] {
                XCTAssertTrue(examples.contains("\(spoken) → \(unicode)") || examples.contains("\(spoken) → $"), spoken)
                XCTAssertEqual(MathNotationFormatter.format(spoken, outputFormat: .unicode), unicode, spoken)
            }
            XCTAssertTrue(examples.contains(MathNotationFormatter.format("theta hat", outputFormat: .latex)), examples)
        }
    }

    func testEveryShippedExampleStringYieldsAtLeastOnePair() {
        for language in [UILanguage.chinese, .english] {
            let copy = PreferencesCopy.texts(for: language)
            for examples in [
                copy.numericFormattingExamples,
                copy.academicReferenceFormattingExamples,
                copy.mathNotationExamples,
                copy.fillerCleanupExamples
            ] {
                let pairs = PreferencesExampleFormatting.lines(examples).filter {
                    if case .pair = $0 { return true }
                    return false
                }
                XCTAssertFalse(pairs.isEmpty, examples)
            }
        }
    }
}
