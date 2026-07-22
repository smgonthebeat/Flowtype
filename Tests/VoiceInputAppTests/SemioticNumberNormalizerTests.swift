import XCTest
@testable import VoiceInputApp

final class SemioticNumberNormalizerTests: XCTestCase {
    func testFormatsDates() {
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("二零二四年十一月五号", context: NormalizationContext()),
            "2024年11月5号"
        )
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("现在是2025年的十二月五号", context: NormalizationContext()),
            "现在是2025年12月5号"
        )
    }

    func testFormatsPercentages() {
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("百分之三点五", context: NormalizationContext()),
            "3.5%"
        )
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("百分之6.5", context: NormalizationContext()),
            "6.5%"
        )
    }

    func testFormatsDecimalsWithUnits() {
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("我现在用零点六B模型，也可以用一点七B", context: NormalizationContext()),
            "我现在用0.6B模型，也可以用1.7B"
        )
    }

    func testFormatsIdentifierDigits() {
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("验证码是一二三四五", context: NormalizationContext()),
            "验证码是12345"
        )
    }

    func testFormatsProblemNumbers() {
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("第十二题和二十三道题", context: NormalizationContext()),
            "第12题和23道题"
        )
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("第九八题", context: NormalizationContext()),
            "第98题"
        )
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("第一二题", context: NormalizationContext()),
            "第12题"
        )
    }

    func testDoesNotConvertApproximateCountsOrTimeExpressions() {
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("我还有一两题和两三题要做", context: NormalizationContext()),
            "我还有一两题和两三题要做"
        )
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("我还有两三题要做", context: NormalizationContext()),
            "我还有两三题要做"
        )
        XCTAssertEqual(
            SemioticNumberNormalizer.normalize("我们三点半见", context: NormalizationContext()),
            "我们三点半见"
        )
    }
}
