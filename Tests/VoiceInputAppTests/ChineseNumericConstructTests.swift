import XCTest
@testable import VoiceInputApp

final class ChineseNumericConstructTests: XCTestCase {
    func testFormatsDates() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("二零二四年十一月五号"),
            "2024年11月5号"
        )
        XCTAssertEqual(
            NormalizationPipeline.normalize("现在是2025年的十二月五号"),
            "现在是2025年12月5号"
        )
    }

    func testFormatsPercentages() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("百分之三点五"),
            "3.5%"
        )
        XCTAssertEqual(
            NormalizationPipeline.normalize("百分之6.5"),
            "6.5%"
        )
    }

    func testFormatsDecimalsWithUnits() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("我现在用零点六B模型，也可以用一点七B"),
            "我现在用0.6B模型，也可以用1.7B"
        )
    }

    func testFormatsIdentifierDigits() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("验证码是一二三四五"),
            "验证码是12345"
        )
    }

    func testFormatsProblemNumbers() {
        // fix-design 4.1 ordinal reference: only 第 + complete cardinal converts; a bare count stays Chinese.
        XCTAssertEqual(
            NormalizationPipeline.normalize("第十二题和二十三道题"),
            "第12题和二十三道题"
        )
        // fix-design 4.1: a digit-by-digit reading is not licensed for ordinals (第九八题 stays).
        XCTAssertEqual(
            NormalizationPipeline.normalize("第九八题"),
            "第九八题"
        )
        // fix-design 4.1 approximation: 第一二题 stays Chinese.
        XCTAssertEqual(
            NormalizationPipeline.normalize("第一二题"),
            "第一二题"
        )
    }

    func testDoesNotConvertApproximateCountsOrTimeExpressions() {
        XCTAssertEqual(
            NormalizationPipeline.normalize("我还有一两题和两三题要做"),
            "我还有一两题和两三题要做"
        )
        XCTAssertEqual(
            NormalizationPipeline.normalize("我还有两三题要做"),
            "我还有两三题要做"
        )
        XCTAssertEqual(
            NormalizationPipeline.normalize("我们三点半见"),
            "我们三点半见"
        )
    }
}
