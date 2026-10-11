import XCTest
@testable import VoiceInputApp

final class NumberGrammarTests: XCTestCase {
    func testChineseCardinalReadings() {
        let reading = ChineseNumberGrammar.read("一千二百")
        XCTAssertEqual(reading.cardinal, 1200)
        XCTAssertTrue(reading.isCompleteCardinal)
        XCTAssertNil(reading.digits)

        XCTAssertEqual(ChineseNumberGrammar.read("一千零一").cardinal, 1001)
        XCTAssertEqual(ChineseNumberGrammar.read("三十七").cardinal, 37)
        XCTAssertEqual(ChineseNumberGrammar.read("十二").cardinal, 12)
        XCTAssertEqual(ChineseNumberGrammar.read("两百").cardinal, 200)
        XCTAssertEqual(ChineseNumberGrammar.read("一万零五百").cardinal, 10_500)
        XCTAssertEqual(ChineseNumberGrammar.read("三亿五千万").cardinal, 350_000_000)
        XCTAssertEqual(ChineseNumberGrammar.read("零").cardinal, 0)
    }

    func testChineseElisionIsMarked() {
        let reading = ChineseNumberGrammar.read("一千五")
        XCTAssertEqual(reading.cardinal, 1500)
        XCTAssertTrue(reading.isElided)
        XCTAssertFalse(reading.isCompleteCardinal)
        XCTAssertEqual(ChineseNumberGrammar.read("两万三").cardinal, 23_000)
    }

    func testChineseApproximationsAreIncomplete() {
        for text in ["三四十", "三四", "两三", "一两", "十七八", "五六"] {
            let reading = ChineseNumberGrammar.read(text)
            XCTAssertTrue(reading.isApproximate, text)
            XCTAssertFalse(reading.isCompleteCardinal, text)
        }
        XCTAssertFalse(ChineseNumberGrammar.read("一二三四五六").isApproximate)
        XCTAssertFalse(ChineseNumberGrammar.read("三零五六七八九零一二").isApproximate)
    }

    func testChineseDigitByDigitReadingIsSeparate() {
        let reading = ChineseNumberGrammar.read("二零二六")
        XCTAssertEqual(reading.digits, "2026")
        XCTAssertNil(reading.cardinal)
        XCTAssertEqual(ChineseNumberGrammar.read("幺三八").digits, "138")
        XCTAssertNil(ChineseNumberGrammar.read("两三").digits)
        XCTAssertNil(ChineseNumberGrammar.read("九八").cardinal)
    }

    func testMalformedChineseCardinals() {
        for text in ["二十三四", "十百", "一百零十", "一百零二十", "百", "零五"] {
            XCTAssertNil(ChineseNumberGrammar.read(text).cardinal, text)
        }
    }

    func testEnglishCardinals() {
        XCTAssertEqual(EnglishNumberGrammar.cardinal(["one", "hundred", "and", "twenty", "five"]), 125)
        XCTAssertEqual(EnglishNumberGrammar.cardinal(EnglishNumberGrammar.splitCompound("twenty-one")!), 21)
        XCTAssertEqual(EnglishNumberGrammar.splitCompound("twentyone"), ["twenty", "one"])
        XCTAssertNil(EnglishNumberGrammar.splitCompound("twentieth"))
        XCTAssertEqual(EnglishNumberGrammar.cardinal(["three", "million"]), 3_000_000)
        XCTAssertEqual(EnglishNumberGrammar.cardinal(["two", "hundred", "thousand"]), 200_000)
        XCTAssertEqual(EnglishNumberGrammar.cardinal(["one", "thousand", "and", "five"]), 1005)
        XCTAssertNil(EnglishNumberGrammar.cardinal(["one", "thousand", "million"]))
        XCTAssertNil(EnglishNumberGrammar.cardinal(["twenty", "four", "seven"]))
        XCTAssertNil(EnglishNumberGrammar.cardinal(["five", "thirty"]))
    }

    func testEnglishYearsDigitsAndFractions() {
        XCTAssertEqual(EnglishNumberGrammar.year(["nineteen", "ninety", "nine"]), 1999)
        XCTAssertEqual(EnglishNumberGrammar.year(["twenty", "twenty", "six"]), 2026)
        XCTAssertNil(EnglishNumberGrammar.year(["eighty", "eighty"]))
        XCTAssertNil(EnglishNumberGrammar.year(["eleven", "thirty"]))
        XCTAssertEqual(EnglishNumberGrammar.digitSequence(["four", "oh", "four"]), "404")
        XCTAssertNil(EnglishNumberGrammar.digitSequence(["one", "two"]))
        XCTAssertEqual(EnglishNumberGrammar.fractionDigits(["twelve"]), "12")
        XCTAssertEqual(EnglishNumberGrammar.fractionDigits(["oh", "five"]), "05")
        XCTAssertEqual(EnglishNumberGrammar.ordinalSuffix(21), "st")
        XCTAssertEqual(EnglishNumberGrammar.ordinalSuffix(12), "th")
    }
}
