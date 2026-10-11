import XCTest
@testable import VoiceInputApp

final class DictationFormattingTests: XCTestCase {
    private func process(_ text: String, math: Bool = false, numeric: Bool = true, filler: Bool = false) -> String {
        TranscriptPostProcessor.process(text, options: TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: numeric,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: filler,
            isMathNotationEnabled: math,
            mathNotationOutputFormat: .unicode
        ))
    }

    func testWholeDecimalsAcrossLanguagesAndSettings() {
        let cases = [
            ("七点一、七点二。五点三，五点四。", "7.1、7.2。5.3，5.4。"),
            ("7 point 8. 5 point 6. 6 point 8.", "7.8. 5.6. 6.8."),
            ("seven point one", "7.1"), ("7 point one", "7.1"),
            ("seven point 1", "7.1"), ("7点一", "7.1"), ("七点1", "7.1"),
            ("五点零六", "5.06"), ("five point zero six", "5.06"),
            ("五点六零", "5.60"), ("five point six zero", "5.60"),
            ("负五点三", "负5.3"), ("minus five point six", "minus 5.6"),
            ("一百二十三点四五", "123.45"), ("twenty five point six", "25.6"),
            ("one hundred and twenty five point zero six", "125.06"),
            ("one thousand two hundred point five", "1200.5"),
            ("one thousand and five point six", "1005.6"),
            ("and five point six", "and 5.6"),
            // fix-design 4.2: a lone "one" without numeric evidence stays a word.
            ("one and five point six", "one and 5.6"),
            ("五点三米", "5.3米"), ("百分之三点五", "3.5%"),
            ("零点六B模型", "0.6B模型"), ("这是一点七B模型", "这是1.7B模型"),
            ("模型版本五点六", "模型版本5.6"),
            ("0.06，5.60，v1.2.3", "0.06，5.60，v1.2.3")
        ]
        for math in [false, true] {
            for filler in [false, true] {
                for (input, expected) in cases {
                    let result = process(input, math: math, filler: filler)
                    XCTAssertEqual(result, expected, input)
                    XCTAssertEqual(process(result, math: math, filler: filler), result, "idempotence: \(input)")
                }
            }
        }
    }

    func testNonDecimalsAreNotPartiallyConsumed() {
        let cases = [
            "一点点", "再多一点点。", "一点一滴", "一点一点地来", "一点也不难",
            "七点一刻", "七点十分", "七点十五分", "七点半", "三点五十分",
            "a point of view", "point of sale", "point six", "checkpoint six",
            "one point two point three", "1点2点3", "v1.2.3",
            "one point six hundred", "one point twenty five",
            "https://example.com/7point8", "`seven point one`", "```\n七点一\n```"
        ]
        // Through the numeric entry point; two rows changed with the contract (fix-design 4.2).
        let contractChanges = [
            "checkpoint six": "checkpoint 6",          // 4.2 cardinal: six is a standalone number word
            "one point twenty five": "1.25"           // 4.2 decimal: tens-units after point concatenate
        ]
        for input in cases {
            XCTAssertEqual(NormalizationPipeline.normalize(input), contractChanges[input] ?? input, input)
        }
        for input in ["一点点", "一点一滴", "一点一点地来", "七点一刻", "七点十分", "七点十五分"] {
            XCTAssertEqual(process(input), input)
        }
        XCTAssertEqual(process("七点一，5 point 6", numeric: false), "七点一，5 point 6")
    }

    func testLetterSpellingIsDefaultWithoutAnyFeatureSwitch() {
        let cases = [
            ("S O L", "SOL"), ("s o l", "SOL"), ("C E O", "CEO"),
            ("C O S", "COS"), ("A S T R A", "ASTRA"), ("Z R K", "ZRK"),
            ("A I", "AI"), ("U I", "UI"), ("x y z", "XYZ"),
            ("我现在念S O L，然后用C E O。", "我现在念SOL，然后用CEO。"),
            ("I use S O L and A S T R A.", "I use SOL and A S T R A."),
            ("a C E O role", "a C E O role"),
            ("SOL CEO ASTRA", "SOL CEO ASTRA"),
            ("S、O、L", "S、O、L"), ("S\nO\nL", "S\nO\nL"),
            ("I am a student.", "I am a student."),
            ("`S O L`", "`S O L`"), ("```\nC E O\n```", "```\nC E O\n```")
        ]
        for numeric in [false, true] {
            for filler in [false, true] {
                for (input, expected) in cases {
                    XCTAssertEqual(process(input, numeric: numeric, filler: filler), expected, input)
                }
            }
        }
    }

    func testNamesSurviveMathAndRepeatedProcessing() {
        for input in ["S O L", "C E O", "C O S", "P I", "S I G M A", "A I", "Z R K"] {
            let expected = input.replacingOccurrences(of: " ", with: "")
            let result = process(input, math: true)
            XCTAssertEqual(result, expected, input)
            XCTAssertEqual(process(result, math: true), result, input)
        }
        let mixed = process("我用 S O L 模型，计算 x squared。", math: true)
        XCTAssertEqual(mixed, "我用 SOL 模型，计算 x²。")
        XCTAssertEqual(process(mixed, math: true), mixed)
        XCTAssertEqual(process("C E O 和 five point six", math: true), "CEO 和 5.6")
    }

    func testExplicitMathArgumentsRemainAvailableToMath() {
        // Math rebuild: SpelledLetterNormalizer has no math branch any more. Letters the math layer
        // does not claim are spelled exactly as with math off (design.md 8.4); a span followed by
        // existing "=" is code-like and not claimed (design.md 6.2). Formerly: unchanged letter runs.
        XCTAssertEqual(process("变量 S O L 分别表示三个量", math: true), "变量 SOL 分别表示三个量")
        XCTAssertEqual(process("变量 S O L 分别表示三个量", math: false), "变量 SOL 分别表示三个量")
        XCTAssertEqual(process("x y = z", math: true), "XY = z")
        XCTAssertEqual(process("x y - z", math: true), "XY - z")
        XCTAssertEqual(process("P X", math: true), "PX")
        // Spoken operators keep the letters as math.
        XCTAssertEqual(process("x y equals z", math: true), "xy = z")
        XCTAssertEqual(process("E X", math: true), "E[X]")
        XCTAssertEqual(process("E X", math: false), "EX")
        XCTAssertEqual(process("x squared", math: true), "x²")
    }

    func testRevisionDecimalOperatorBoundaries() {
        let cases = [
            ("5 point 6 - 7", "5.6 - 7"), ("5 point 6-7", "5.6-7"),
            ("五点六-七", "5.6-七"), ("six - five point seven", "6 - 5.7"),
            ("5 point 6 - 7 point 8", "5.6 - 7.8"),
            ("twenty-five point six", "25.6"),
            ("5 point 6–7", "5.6–7"), ("5 point 6−7", "5.6−7"),
            ("5 point 6+7", "5.6+7"), ("5 point 6/7", "5.6/7"),
            // fix-design 4.2 boundaries: a number word inside a hyphen compound is not standalone.
            ("six-five point seven", "six-five point seven"),
            ("five point six seven", "5.67")
        ]
        for (input, expected) in cases {
            XCTAssertEqual(process(input), expected, input)
        }
        for input in ["一千五点六", "一万五点六", "one hundred hundred point six",
                      "one point two point three", "one point six hundred",
                      "five\npoint six", "five point\nsix", "five checkpoint six"] {
            // Never a decimal (repeated point, unsupported magnitude, newline, compound word).
            let output = NormalizationPipeline.normalize(input)
            XCTAssertNil(output.range(of: #"[0-9]\.[0-9]"#, options: .regularExpression), "\(input) -> \(output)")
        }
        for separator in ["-", "−", "–", "+", "/", ",", "\n"] {
            XCTAssertEqual(NormalizationPipeline.normalize("5 point 6" + separator + "7 point 8"),
                           "5.6" + separator + "7.8", separator)
        }
    }

    func testRevisionDecimalQuantityAndClockContexts() {
        let cases = [
            ("评分是五点三分。", "评分是5.3分。"),
            ("用了五点三分钟。", "用了5.3分钟。"),
            ("耗时五点三秒。", "耗时5.3秒。"),
            ("每天工作五点三小时。", "每天工作5.3小时。"),
            // fix-design 4.1 decimal: conversion does not depend on the following word.
            ("数值达到五点三时继续。", "数值达到5.3时继续。"),
            ("五点三分", "五点三分"), ("七点十五分见。", "七点十五分见。"),
            ("七点三分二十秒出发。", "七点三分二十秒出发。"),
            ("下午七点三分见。", "下午七点三分见。"),
            ("下午五点三见。", "下午五点三见。"),
            ("下午耗时五点三秒。", "下午耗时5.3秒。"),
            ("七点十五分出发，耗时五点三分钟。", "七点十五分出发，耗时5.3分钟。"),
            ("评分结束。五点三分见。", "评分结束。五点三分见。"),
            ("五点三米／五点三倍／零点五元", "5.3米／5.3倍／0.5元")
        ]
        for (input, expected) in cases {
            XCTAssertEqual(process(input), expected, input)
        }
    }

    // The audit revision preserves ambiguous embedded runs instead of guessing articles.
    func testRevisionArticleAndSpellingBoundaries() {
        let cases = [
            ("I got a B in maths.", "I got a B in maths."),
            ("That is a C grade.", "That is a C grade."),
            ("I ordered a T shirt.", "I ordered a T shirt."),
            ("I need a U shaped bracket.", "I need a U shaped bracket."),
            ("A B grade is fine.", "A B grade is fine."),
            ("I am a C E O.", "I am a C E O."),
            ("I am a c e o.", "I am a c e o."),
            ("a Z R K role", "a Z R K role"), ("a z r k role", "a z r k role"),
            ("a i", "AI"), ("a s t r a", "ASTRA"),
            ("I use A I and A S T R A.", "I use A I and A S T R A."),
            ("我用 a i 和 a s t r a。", "我用 a i 和 a s t r a。"),
            ("I am a student.", "I am a student."),
            ("S O L. A I", "SOL. A I"), ("S O\nL", "SO\nL")
        ]
        for math in [false, true] {
            for (input, expected) in cases {
                XCTAssertEqual(process(input, math: math), expected, input)
            }
        }
    }

    func testRevisionStatisticsNamesAcrossOutputFormats() {
        // Math rebuild: a Greek character already written by the recogniser is existing notation and
        // inert (design.md 3 rule 3), so a spoken function name is not applied to it. Formerly:
        // SD(β), \mathrm{SD}(\beta) and so on. The spoken forms convert (SD beta -> SD(β), below).
        let cases: [(String, String, String)] = [
            ("SD β", "SD β", "SD β"),
            ("SE β", "SE β", "SE β"),
            ("VAR β", "VAR β", "VAR β"),
            ("COV β γ", "COV β γ", "COV β γ"),
            ("SD beta", "SD(β)", #"$\operatorname{SD}(\beta)$"#),
            ("covariance of beta and gamma", "Cov(β, γ)", #"$\operatorname{Cov}(\beta, \gamma)$"#)
        ]
        for format in [MathNotationOutputFormat.unicode, .latex] {
            for (input, unicode, latex) in cases {
                let options = TranscriptProcessingOptions(isSmartNumericFormattingEnabled: true,
                    isAcademicReferenceFormattingEnabled: false, isFillerCleanupEnabled: false,
                    isMathNotationEnabled: true, mathNotationOutputFormat: format)
                XCTAssertEqual(TranscriptPostProcessor.process(input, options: options),
                               format == .unicode ? unicode : latex, input)
            }
        }
        for input in ["C E O", "C O S", "S O L"] {
            XCTAssertEqual(process(input, math: true), input.replacingOccurrences(of: " ", with: ""))
        }
    }


    func testRevisionProductionConfigurationMatrix() {
        for numeric in [false, true] { for filler in [false, true] { for math in [false, true] {
            for academic in [false, true] { for format in [MathNotationOutputFormat.unicode, .latex] {
                let options = TranscriptProcessingOptions(isSmartNumericFormattingEnabled: numeric,
                    isAcademicReferenceFormattingEnabled: academic, isFillerCleanupEnabled: filler,
                    isMathNotationEnabled: math, mathNotationOutputFormat: format)
                let cases = [
                    ("5 point 6 - 7", numeric ? "5.6 - 7" : "5 point 6 - 7"),
                    ("耗时五点三秒。", numeric ? "耗时5.3秒。" : "耗时五点三秒。"),
                    ("评分五点三分。", numeric ? "评分5.3分。" : "评分五点三分。"),
                    ("七点三分二十秒见。", "七点三分二十秒见。"),
                    ("I got a B in maths.", "I got a B in maths."),
                    ("I am a c e o.", "I am a c e o."),
                    ("S O L", "SOL"),
                    // Math rebuild: LaTeX is wrapped in $...$ with \mathbb{E} (D1, D4).
                    ("E X", math ? (format == .unicode ? "E[X]" : #"$\mathbb{E}[X]$"#) : "EX"),
                    // Math rebuild: existing Greek characters are inert (design.md 3 rule 3).
                    ("SD β", "SD β"),
                    ("我呃想看，那嗯，继续。", filler ? "我想看，那，继续。" : "我呃想看，那嗯，继续。"),
                    // Raw spelling reservation also prevents academic rewrites inside this code run.
                    ("`S O L 5 point 6 SD β`", "`S O L 5 point 6 SD β`")
                ]
                for (input, expected) in cases {
                    let result = TranscriptPostProcessor.process(input, options: options)
                    XCTAssertEqual(result, expected, "\(input) numeric=\(numeric) filler=\(filler) math=\(math) academic=\(academic) format=\(format)")
                    XCTAssertEqual(TranscriptPostProcessor.process(result, options: options), result, "idempotence: \(input)")
                }
            } }
        } } }
    }

    func testRevisionMathCandidatesAndStrongProtection() {
        // Math rebuild: arguments already rendered by the recogniser (β, X̄, Yᵢ) are inert
        // (design.md 3 rule 3); formerly SD(β), SD(X̄), SD(Yᵢ).
        for (input, expected) in [("SD beta", "SD(β)"), ("sd β", "sd β"), ("SD x", "SD(X)"),
                                  ("SD X bar", "SD(X̄)"), ("SD Y sub i", "SD(Yᵢ)"),
                                  ("SD X̄", "SD X̄"), ("SD Yᵢ", "SD Yᵢ"),
                                  ("SE beta hat", "SE(β̂)"), ("S D beta", "SD(β)"),
                                  ("S O L 和 x squared", "SOL 和 x²")] {
            XCTAssertEqual(process(input, math: true), expected, input)
        }
        for terms in [["SD"], ["SD β"]] {
            let options = TranscriptProcessingOptions(isSmartNumericFormattingEnabled: true,
                isAcademicReferenceFormattingEnabled: false, isFillerCleanupEnabled: true,
                isMathNotationEnabled: true, mathNotationOutputFormat: .unicode, knownTerms: terms)
            XCTAssertEqual(TranscriptPostProcessor.process("SD β", options: options), "SD β")
        }
        for input in ["U M", "U H", "E M"] {
            XCTAssertEqual(process(input, math: true, filler: true), input.replacingOccurrences(of: " ", with: ""))
        }
        for term in ["A", "UM", "U M", "SOL"] {
            let options = TranscriptProcessingOptions(isSmartNumericFormattingEnabled: true,
                isAcademicReferenceFormattingEnabled: true, isFillerCleanupEnabled: true,
                isMathNotationEnabled: true, mathNotationOutputFormat: .unicode, knownTerms: [term])
            XCTAssertEqual(TranscriptPostProcessor.process("A2, um, thick.", options: options), "A2, um, thick.")
            // fix-design 4.3: a hotword is byte-identical in every stage, including spelling joins.
            XCTAssertEqual(TranscriptPostProcessor.process("U M", options: options), term == "U M" ? "U M" : "UM")
            XCTAssertEqual(TranscriptPostProcessor.process("S O L", options: options), "SOL")
        }
    }


    func testRevisionUnsupportedMagnitudesRemainWhole() {
        for input in ["一千五点六B", "一万五点六B", "百分之一千五点六", "一亿五点六B"] {
            XCTAssertEqual(process(input), input, input)
        }
    }

}
