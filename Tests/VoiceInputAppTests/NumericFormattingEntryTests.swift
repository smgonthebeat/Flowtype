import XCTest
@testable import VoiceInputApp

final class NumericFormattingEntryTests: XCTestCase {
    func testFormatsChineseDate() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("二零二四年十一月五号"),
            "2024年11月5号"
        )
    }

    func testFormatsMixedArabicAndChineseDate() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("现在是2025年的十二月五号"),
            "现在是2025年12月5号"
        )
    }

    func testFormatsPercentage() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("百分之三点五"),
            "3.5%"
        )
    }

    func testFormatsArabicPercentageAfterPercentPrefix() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("百分之6.5"),
            "6.5%"
        )
    }

    func testFormatsContinuousDigits() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("验证码是一二三四五"),
            "验证码是12345"
        )
    }

    func testDoesNotRepairStandaloneSubpartWithoutAcademicContext() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("我想讲一B这个说法"),
            "我想讲一B这个说法"
        )
    }

    func testDoesNotApplyBuiltInCourseCodeNormalization() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("course零零一"),
            "course零零一"
        )
        XCTAssertEqual(
            NormalizationPipeline.normalize("我在说 DEMO零零一 和 TEST零四四"),
            // 2026-10-25 (D86): no course-code list, but capitals + 零-led Chinese digits are a code.
            "我在说 DEMO001 和 TEST044"
        )
    }

    func testDoesNotFormatApproximateProblemCounts() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("我还有一两题和两三题要做"),
            "我还有一两题和两三题要做"
        )
    }

    func testFormatsExplicitProblemNumbers() {
        // fix-design 4.1 ordinal reference: a bare count without 第 stays Chinese.
        XCTAssertEqual(
            NormalizationPipeline.normalize("第十二题和二十三道题"),
            "第12题和二十三道题"
        )
        // fix-design 4.1: digit-by-digit (第九八题) and approximate (第一二题) members stay Chinese.
        XCTAssertEqual(
            NormalizationPipeline.normalize("第九八题和第一二题"),
            "第九八题和第一二题"
        )
    }

    func testFormatsModelSizeDecimals() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("我现在用零点六B模型，也可以用一点七B"),
            "我现在用0.6B模型，也可以用1.7B"
        )
    }

    func testLeavesTimeExpressionAlone() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("我们三点半见"),
            "我们三点半见"
        )
    }
}
