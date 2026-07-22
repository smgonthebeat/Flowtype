import XCTest
@testable import VoiceInputApp

final class SpokenNumberParserTests: XCTestCase {
    func testParsesChineseSequentialDigits() {
        XCTAssertEqual(SpokenNumberParser.sequentialDigits("零零四五"), "0045")
    }

    func testParsesChineseCardinalNumbers() {
        XCTAssertEqual(SpokenNumberParser.number("四"), 4)
        XCTAssertEqual(SpokenNumberParser.number("十二"), 12)
        XCTAssertEqual(SpokenNumberParser.number("二十"), 20)
        XCTAssertEqual(SpokenNumberParser.number("一百零五"), 105)
        XCTAssertEqual(SpokenNumberParser.number("三百二十"), 320)
        XCTAssertEqual(SpokenNumberParser.number("一百二"), 120)
        XCTAssertEqual(SpokenNumberParser.number("两百三"), 230)
    }

    func testRejectsMalformedChineseNumbers() {
        XCTAssertNil(SpokenNumberParser.number("二十三四"))
        XCTAssertNil(SpokenNumberParser.number("十百"))
        XCTAssertNil(SpokenNumberParser.number("一百零十"))
        XCTAssertNil(SpokenNumberParser.number("一百零二十"))
    }

    func testParsesEnglishNumbers() {
        XCTAssertEqual(SpokenNumberParser.numberOrEnglishNumber("one"), 1)
        XCTAssertEqual(SpokenNumberParser.numberOrEnglishNumber("four"), 4)
        XCTAssertEqual(SpokenNumberParser.numberOrEnglishNumber("twenty"), 20)
        XCTAssertEqual(SpokenNumberParser.numberOrEnglishNumber("fifty"), 50)
        XCTAssertEqual(SpokenNumberParser.numberOrEnglishNumber("twenty one"), 21)
        XCTAssertEqual(SpokenNumberParser.numberOrEnglishNumber("ninety-nine"), 99)
    }

    func testParsesLeadingAndExplicitZeroDecimals() {
        XCTAssertEqual(SpokenNumberParser.decimal("点五"), "0.5")
        XCTAssertEqual(SpokenNumberParser.decimal("零点五"), "0.5")
    }

    func testParsesMixedDecimals() {
        XCTAssertEqual(SpokenNumberParser.decimal("1点五"), "1.5")
        XCTAssertEqual(SpokenNumberParser.decimal("12点3"), "12.3")
        XCTAssertEqual(SpokenNumberParser.decimal("十二点5"), "12.5")
        XCTAssertEqual(SpokenNumberParser.decimal("一百二点五"), "120.5")
        XCTAssertEqual(SpokenNumberParser.decimal("零点零五"), "0.05")
        XCTAssertEqual(SpokenNumberParser.decimal("十二点零三"), "12.03")
    }

    func testRejectsInvalidDecimals() {
        XCTAssertNil(SpokenNumberParser.decimal("点"))
        XCTAssertNil(SpokenNumberParser.decimal("一百零十点五"))
    }
}
