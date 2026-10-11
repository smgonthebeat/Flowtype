import XCTest
@testable import VoiceInputApp

final class EnglishPercentCandidateTests: XCTestCase {
    func testAcceptedSuffixesAcrossSettings() {
        let cases = [
            ("3.5 percent.", "3.5%."),
            ("three point five percent", "3.5%"),
            ("three point zero five percent", "3.05%"),
            ("zero point zero six per cent", "0.06%"),
            ("twenty five percent", "25%"),
            ("twenty-five percent", "25%"),
            ("one hundred percent", "100%"),
            ("one hundred and five point six percent", "105.6%"),
            ("one thousand percent", "1000%"),
            ("3.50 PERCENT", "3.50%"),
            ("Growth is three point five percent.", "Growth is 3.5%."),
            ("3.5 percent of revenue", "3.5% of revenue"),
            ("增长 3.5 percent，接着讨论。", "增长 3.5%，接着讨论。"),
            ("3.5 percent, 5 percent", "3.5%, 5%"),
            ("-3.5 percent", "-3.5%"),
            ("+3.5 percent", "+3.5%"),
            ("🙂 3.5 percent; 25 per cent.", "🙂 3.5%; 25%."),
            ("百分之三点五", "3.5%")
        ]
        for (input, output) in cases {
            ResidualRepairAssertions.check(input, expected: {
                $0.isSmartNumericFormattingEnabled ? output : input
            })
        }
        // Math rebuild: with math on, a whole utterance with a spoken operator is a formula and the
        // math layer reads its numbers itself (design.md 2 principle 2, 5.2, 6.2 rule 7). Formerly the
        // math setting made no difference: 3.5 minus 7% / unchanged.
        let spokenMinus = "three point five minus seven percent"
        ResidualRepairAssertions.check(spokenMinus, when: { !$0.isMathNotationEnabled }, expected: {
            $0.isSmartNumericFormattingEnabled ? "3.5 minus 7%" : spokenMinus
        })
        ResidualRepairAssertions.check(spokenMinus, when: { $0.isMathNotationEnabled }, expected: {
            $0.mathNotationOutputFormat == .latex ? #"$3.5 - 7\%$"# : "3.5 − 7%"
        })
    }

    func testHorizontalSpacingAtNumericEntryPoint() {
        for input in ["3.5  percent", "3.5\tpercent", "3.5 per\tcent", "three\tpoint\tzero\tfive\tper\tcent"] {
            let expected = input.hasPrefix("three") ? "3.05%" : "3.5%"
            XCTAssertEqual(NormalizationPipeline.normalize(input), expected)
        }
    }

    func testOrdinaryProseAndExistingSymbolsRemainAvailable() {
        for input in ["Percentage of 3.5.", "what percentage", "3.5 percentile", "3.5 percentage points",
                      "3.5 percent points", "3.5 percent sign", "3.5%", "3.5percent", "3.5 percentiles"] {
            ResidualRepairAssertions.check(input, expected: { _ in input })
        }
        XCTAssertEqual(NormalizationPipeline.normalize("three point five percentage points"), "3.5 percentage points")
        XCTAssertEqual(NormalizationPipeline.normalize("three point five percent points"), "3.5 percent points")
        XCTAssertEqual(NormalizationPipeline.normalize("three point five percent sign"), "3.5 percent sign")
    }

    func testMalformedCandidatesAreNotPartiallyConsumed() {
        let inputs = [
            "three point five point six percent", "three point percent",
            "1,000 percent", "1e3 percent", "1/2 percent", ".5 percent", "1.2.3 percent",
            "rate_3.5 percent", "v3.5 percent", "3.5 percent%", "3.5 percent percent",
            "three point five percent percent", "3.5 per cent per cent",
            "百分之3.5 percent", "百分之three point five percent",
            "one thousand million percent"
        ]
        for input in inputs {
            ResidualRepairAssertions.check(input, expected: { _ in input })
        }
    }

    func testNewlinesNeverJoinCandidates() {
        for input in ["3.5\npercent", "3.5 per\ncent"] {
            XCTAssertEqual(NormalizationPipeline.normalize(input), input)
        }
    }

    func testProtectedSegmentsAndIndependentText() {
        let cases = [
            ("`three point five percent`", "`three point five percent`"),
            ("```\nthree point five percent\n```", "```\nthree point five percent\n```"),
            ("`three point five percent", "`three point five percent"),
            ("3.5 percent `three point five percent` 5 per cent", "3.5% `three point five percent` 5%"),
            ("https://example.com/3.5percent 5 percent", "https://example.com/3.5percent 5%"),
            ("/tmp/3.5percent 5 percent", "/tmp/3.5percent 5%"),
            ("three point percent, twenty one", "three point percent, 21"),
            ("three point five point six percent, 5 percent", "three point five point six percent, 5%")
        ]
        for (input, output) in cases {
            ResidualRepairAssertions.check(input, expected: {
                $0.isSmartNumericFormattingEnabled ? output : input
            })
        }
    }

    func testDirectSemioticEntryAndProtectedRangeRemapping() {
        XCTAssertEqual(NormalizationPipeline.normalize("three point five percent"), "3.5%")
        let malformed = "three point five point six percent"
        XCTAssertEqual(NormalizationPipeline.normalize(malformed), malformed)
        // fix-design 4.2 decimal: tens after "point" are digits, so this is no longer malformed.
        XCTAssertEqual(NormalizationPipeline.normalize("three point twenty percent"), "3.20%")
        let input = "🙂 three point five percent; 7 percent; five percent"
        let range = input.range(of: "7 percent")!
        let protected = ProtectedSpan(range: range, kind: .command, text: String(input[range]))
        let result = NumericNormalizer.normalize(input, protectedSpans: [protected])
        XCTAssertEqual(result.text, "🙂 3.5%; 7 percent; 5%")
        XCTAssertEqual(result.protectedSpans.count, 1)
        if let span = result.protectedSpans.first {
            XCTAssertEqual(String(result.text[span.range]), "7 percent")
        }
    }

    func testDictionaryHotwordIsProtectedFromNumericRewrites() {
        // fix-design 4.3 / section 6: a hotword that is itself numeric is protected.
        ResidualRepairAssertions.check("3.5 percent", terms: ["3.5 percent"], expected: { _ in "3.5 percent" })
    }
}
