import XCTest
@testable import VoiceInputApp

final class SmartNumericFormatterTests: XCTestCase {
    func testFormatsChineseDate() {
        XCTAssertEqual(
            SmartNumericFormatter.format("二零二四年十一月五号"),
            "2024年11月5号"
        )
    }

    func testFormatsMixedArabicAndChineseDate() {
        XCTAssertEqual(
            SmartNumericFormatter.format("现在是2025年的十二月五号"),
            "现在是2025年12月5号"
        )
    }

    func testFormatsPercentage() {
        XCTAssertEqual(
            SmartNumericFormatter.format("百分之三点五"),
            "3.5%"
        )
    }

    func testFormatsArabicPercentageAfterPercentPrefix() {
        XCTAssertEqual(
            SmartNumericFormatter.format("百分之6.5"),
            "6.5%"
        )
    }

    func testFormatsContinuousDigits() {
        XCTAssertEqual(
            SmartNumericFormatter.format("验证码是一二三四五"),
            "验证码是12345"
        )
    }

    func testFormatsExplicitAcademicSubpartReferences() {
        XCTAssertEqual(
            SmartNumericFormatter.format("OK，A部分我会了，A一B，下一步给我A一B。"),
            "OK，A部分我会了，A1(b)，下一步给我A1(b)。"
        )
    }

    func testRepairsOmittedSectionAInAcademicSubpartContext() {
        XCTAssertEqual(
            SmartNumericFormatter.format("OK，部分我会了，一B，下一步给我讲一B。"),
            "OK，A部分我会了，A1(b)，下一步给我A1(b)。"
        )
    }

    func testFormatsAcademicSectionNumbers() {
        XCTAssertEqual(
            SmartNumericFormatter.format("A one，A一，A two，A二。"),
            "A1，A1，A2，A2。"
        )
        XCTAssertEqual(
            SmartNumericFormatter.format("A one，一, A two，二。"),
            "A1，1, A2，2。"
        )
        XCTAssertEqual(
            SmartNumericFormatter.format("B one, B two, B three.B二、B三、B四。"),
            "B1, B2, B3.B2、B3、B4。"
        )
        XCTAssertEqual(
            SmartNumericFormatter.format("Q one，Q一，Q two，Q二。"),
            "Q1，Q1，Q2，Q2。"
        )
        XCTAssertEqual(
            SmartNumericFormatter.format("x五的cheat sheet。c十二要背，b一的题，a one的题，a two的题。"),
            "X5的cheat sheet。C12要背，B1的题，A1的题，A2的题。"
        )
        XCTAssertEqual(
            SmartNumericFormatter.format("我是A11、A12、X5、A3、A4、B1、B2、B12、bit六、bit一的cheat sheet。"),
            "我是A11、A12、X5、A3、A4、B1、B2、B12、B6、B1的cheat sheet。"
        )
    }

    func testDoesNotRepairStandaloneSubpartWithoutAcademicContext() {
        XCTAssertEqual(
            SmartNumericFormatter.format("我想讲一B这个说法"),
            "我想讲一B这个说法"
        )
    }

    func testDoesNotApplyBuiltInCourseCodeNormalization() {
        XCTAssertEqual(
            SmartNumericFormatter.format("course零零一"),
            "course零零一"
        )
        XCTAssertEqual(
            SmartNumericFormatter.format("我在说 DEMO零零一 和 TEST零四四"),
            "我在说 DEMO零零一 和 TEST零四四"
        )
    }

    func testDoesNotFormatApproximateProblemCounts() {
        XCTAssertEqual(
            SmartNumericFormatter.format("我还有一两题和两三题要做"),
            "我还有一两题和两三题要做"
        )
    }

    func testFormatsExplicitProblemNumbers() {
        XCTAssertEqual(
            SmartNumericFormatter.format("第十二题和二十三道题"),
            "第12题和23道题"
        )
        XCTAssertEqual(
            SmartNumericFormatter.format("第九八题和第一二题"),
            "第98题和第12题"
        )
    }

    func testFormatsModelSizeDecimals() {
        XCTAssertEqual(
            SmartNumericFormatter.format("我现在用零点六B模型，也可以用一点七B"),
            "我现在用0.6B模型，也可以用1.7B"
        )
    }

    func testLeavesTimeExpressionAlone() {
        XCTAssertEqual(
            SmartNumericFormatter.format("我们三点半见"),
            "我们三点半见"
        )
    }
}
