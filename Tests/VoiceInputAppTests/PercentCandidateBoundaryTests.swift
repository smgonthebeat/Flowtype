import XCTest
@testable import VoiceInputApp

final class PercentCandidateBoundaryTests: XCTestCase {
    func testFrozenMainAndSpacedCandidates() {
        let cases: [(String, String)] = [
            ("百分之1千五点六", "百分之1千五点六"),
            ("百分之五点六foo", "百分之五点六foo"),
            ("百分之三点一线", "百分之三点一线"),
            ("百分之一千五点六", "百分之一千五点六"),
            ("百分之1万五点六", "百分之1万五点六"),
            ("百分之1亿五点六", "百分之1亿五点六"),
            ("百分之五点六B", "百分之五点六B"),
            ("百分之五点六kg", "百分之五点六kg"),
            ("百分之五点六_id", "百分之五点六_id"),
            ("百分之五点六th", "百分之五点六th"),
            ("百分之1.2.3", "百分之1.2.3"),
            ("百分之五点六点七", "百分之五点六点七"),
            ("百分之五点六%", "百分之五点六%"),
            ("百分之五", "5%"),
            ("百分之五点六", "5.6%"),
            ("百分之5.6", "5.6%"),
            ("百分之5点六", "5.6%"),
            ("百分之一百零五点六", "105.6%"),
            ("百分之零点零六", "0.06%"),
            ("百分之 五点六", "5.6%"),
            ("百分之五点六。", "5.6%。"),
            ("百分之五-百分之三", "5%-3%"),
            ("百分之五加百分之三", "5%加3%"),
            ("增长百分之三点五的概率", "增长3.5%的概率"),
            ("增长百分之三点五左右", "增长3.5%左右"),
            ("五点六B", "5.6B"),
            ("五点六kg", "5.6kg"),
            ("五点六%", "5.6%"),
            ("五点六米。", "5.6米。"),
            ("评分是五点三分。", "评分是5.3分。"),
            ("下午五点三分。", "下午五点三分。"),
            // fix-design 4.2 boundaries: "six-six" is a hyphen compound, so the decimal is incomplete.
            ("five point six-six", "five point six-six"),
            ("下午 百分之1千五点六 五点三分。", "下午 百分之1千五点六 五点三分。"),
            ("评分将在百分之1千五点六后的五点三分开始", "评分将在百分之1千五点六后的五点三分开始"),
            ("百分之1千五点六，five point six", "百分之1千五点六，5.6"),
            ("百分之1千五点六，评分是五点三分。", "百分之1千五点六，评分是5.3分。"),
            ("百分之1千五点六，下午五点三分。", "百分之1千五点六，下午五点三分。"),
            // fix-design 4.3 designator join: a single letter + number at the end of text joins.
            ("百分之五点六 B twenty one", "5.6% B21"),
            // fix-design 4.1 percent: the following word no longer decides; each construct stands alone.
            ("百分之五点六第十二题", "5.6%第12题"),
            ("百分之五点六编号一二三", "5.6%编号123"),
            ("百分之5.6.", "5.6%."),
            ("百分之one point six", "1.6%"),
            ("百分之1 千五点六", "百分之1 千五点六"),
            ("百分之五 点 六", "5.6%"),
            ("百分之五点 六", "5.6%"),
            // fix-design 4.1 percent: 百分之 + complete numeral (English words included) converts.
            ("百分之twenty one", "21%"),
            ("百分之one point sixfoo", "百分之one point sixfoo"),
            ("百分之1千五点六 twenty one", "百分之1千五点六 21"),
            ("百分之五点六 twenty one", "5.6% 21")
        ]
        for (input, expected) in cases {
            ResidualRepairAssertions.check(input, when: {
                $0.isSmartNumericFormattingEnabled && !$0.isAcademicReferenceFormattingEnabled
                    && !$0.isFillerCleanupEnabled && !$0.isMathNotationEnabled
            }, expected: { _ in expected })
        }
    }
    func testUnsupportedCandidatesCannotBeConsumedByDirectSemioticCall() {
        for input in ["百分之1千五点六", "百分之1 千五点六", "百分之五点六B"] {
            let spans = ProtectedSpanDetector.detect(in: input)
            XCTAssertEqual(NumericNormalizer.normalize(input, protectedSpans: spans).text, input)
        }
        // fix-design 4.1 percent: a complete percentage converts whatever follows it.
        for (input, expected) in [("百分之五点六第十二题", "5.6%第12题"), ("百分之五点六编号一二三", "5.6%编号123")] {
            XCTAssertEqual(NumericNormalizer.normalize(input, protectedSpans: []).text, expected)
        }
        for (input, expected) in [("百分之五 点 六", "5.6%"), ("百分之one point six", "1.6%"), ("百分之五点 六", "5.6%"), ("百分之5.6", "5.6%") ] {
            XCTAssertEqual(NumericNormalizer.normalize(input, protectedSpans: []).text, expected)
        }
    }
    func testCandidateIntegrityAcrossAllSettings() {
        for (input, expected) in [("百分之1千五点六", "百分之1千五点六"), ("百分之1 千五点六", "百分之1 千五点六"), ("百分之五 点 六", "5.6%"), ("百分之one point six", "1.6%"), ("增长百分之三点五左右", "增长3.5%左右")] {
            ResidualRepairAssertions.check(input, expected: { $0.isSmartNumericFormattingEnabled ? expected : input })
        }
    }
}
