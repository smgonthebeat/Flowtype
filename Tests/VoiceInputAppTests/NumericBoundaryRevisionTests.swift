import XCTest
@testable import VoiceInputApp

final class NumericBoundaryRevisionTests: XCTestCase {
    private func process(_ text: String, numeric: Bool = true) -> String {
        TranscriptPostProcessor.process(text, options: TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: numeric,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false,
            isMathNotationEnabled: false,
            mathNotationOutputFormat: .unicode
        ))
    }

    func testExplicitClockWinsOverEarlierScoreWords() {
        for input in [
            "评分将在下午五点三分开始",
            "得分公布安排在上午七点三分",
            "打分在晚上八点五分结束"
        ] {
            XCTAssertEqual(process(input), input, input)
        }
        XCTAssertEqual(process("下午耗时五点三秒"), "下午耗时5.3秒")
        XCTAssertEqual(process("评分耗时五点三分钟"), "评分耗时5.3分钟")
    }

    func testScoreRequiresAnAdjacentCompleteValueConstruction() {
        for input in [
            "评分将在五点三分开始",
            "评分结束后五点三分集合",
            "评分五点三分开始",
            "评分五点三分 开始"
        ] {
            XCTAssertEqual(process(input), input, input)
        }
        for (input, expected) in [
            ("评分是五点三分。", "评分是5.3分。"),
            ("评分五点三分。", "评分5.3分。"),
            ("得分为五点三分", "得分为5.3分"),
            ("评分：五点三分。", "评分：5.3分。"),
            ("平均分: 五点三分，稍后公布。", "平均分: 5.3分，稍后公布。")
        ] {
            XCTAssertEqual(process(input), expected, input)
        }
    }

    func testChineseContinuationRequiresACompleteQuantity() {
        for input in [
            "两点一线", "三点一线的生活", "这是三点一线图",
        ] {
            XCTAssertEqual(process(input), input, input)
        }
        // fix-design 4.1 decimal: a complete decimal converts regardless of the following word;
        // only positive clock/enumeration/word evidence keeps it Chinese.
        for (input, expected) in [
            ("五点三米线", "5.3米线"), ("三点一倍数", "3.1倍数"),
            ("数值达到五点三时继续", "数值达到5.3时继续")
        ] {
            XCTAssertEqual(process(input), expected, input)
        }
        // 元宵 is a word: the system segmenter may veto (stay), the lexicon alone converts.
        XCTAssertTrue(["五点三元宵", "5.3元宵"].contains(process("五点三元宵")))
        for (input, expected) in [
            ("五点三米／五点三倍／零点五元", "5.3米／5.3倍／0.5元"),
            ("用了五点三分钟，然后走了五点三米。", "用了5.3分钟，然后走了5.3米。"),
            ("耗时五点三秒。", "耗时5.3秒。"),
            ("每天工作五点三小时。", "每天工作5.3小时。"),
            ("七点一，五点三", "7.1，5.3"),
            ("七点一、七点二。五点三，五点四。", "7.1、7.2。5.3，5.4。"),
            ("five point six 和五点三米", "5.6 和5.3米"),
            ("五点三 以及后续说明", "5.3 以及后续说明"),
            ("零点六B模型", "0.6B模型")
        ] {
            XCTAssertEqual(process(input), expected, input)
        }
    }

    func testFractionDoesNotConsumeIdentifierOrOrdinalPrefixes() {
        for input in [
            "5 point 6_beta", "5point6_beta", "5 point 6th",
            "5 point 6foo", "5 point 6kg_beta", "5 point 6kg2",
            "五点六foo", "五点六th", "五点六kg_beta", "五点六kg2",
            "五点六B_beta", "五点六B2"
        ] {
            XCTAssertEqual(NormalizationPipeline.normalize(input), input, input)
            XCTAssertEqual(process(input), input, input)
            XCTAssertEqual(process(input, numeric: false), input, input)
        }
    }

    func testCompleteUnitSuffixesAndOperatorsRemainAvailable() {
        let cases = [
            ("零点六B模型", "0.6B模型"),
            ("5点6B", "5.6B"), ("五点六K", "5.6K"), ("五点六M", "5.6M"),
            ("五点六kg", "5.6kg"), ("5 point 6kg", "5.6kg"),
            ("五点六kg重", "5.6kg重"), ("5 point 6 foo", "5.6 foo"),
            ("5 point 6%", "5.6%"), ("五点六%", "5.6%"),
            ("5 point 6 - 7", "5.6 - 7"),
            ("twenty-five point six", "25.6"),
            ("5 point 6/7", "5.6/7")
        ]
        for (input, expected) in cases {
            XCTAssertEqual(process(input), expected, input)
            XCTAssertEqual(process(expected), expected, "Repeated processing: \(input)")
        }
    }
}
