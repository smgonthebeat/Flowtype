import Foundation
import XCTest
@testable import VoiceInputApp

/// Drives every row of the numeric behaviour contract through the real post-processor.
/// Contract: docs/maintenance/artifacts/2026-10-02-numeric-normalization-rca/fix-design.md
final class NumericContractTests: XCTestCase {
    struct ContractRow: Decodable {
        struct Options: Decodable {
            let numeric: Bool?
            let academic: Bool?
            let filler: Bool?
            let math: Bool?
            let mathFormat: String?
            let knownTerms: [String]?
        }

        let text: String
        let options: Options
        let expected: String
        let kind: String
        let clause: String
        let note: String
        var line = 0

        private enum CodingKeys: String, CodingKey {
            case text, options, expected, kind, clause, note
        }

        var processingOptions: TranscriptProcessingOptions {
            TranscriptProcessingOptions(
                isSmartNumericFormattingEnabled: options.numeric ?? true,
                isAcademicReferenceFormattingEnabled: options.academic ?? false,
                isFillerCleanupEnabled: options.filler ?? false,
                isMathNotationEnabled: options.math ?? false,
                mathNotationOutputFormat: options.mathFormat == "latex" ? .latex : .unicode,
                knownTerms: options.knownTerms ?? []
            )
        }

        func label(_ actual: String) -> String {
            "line \(line) [\(kind) \(clause)] input: \(text.debugDescription) expected: \(expected.debugDescription) actual: \(actual.debugDescription)"
        }
    }

    static func loadRows(file: StaticString = #filePath) throws -> [ContractRow] {
        let url = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("numeric-contract-cases.jsonl")
        let contents = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        var rows: [ContractRow] = []
        for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            var row = try decoder.decode(ContractRow.self, from: Data(line.utf8))
            row.line = index + 1
            rows.append(row)
        }
        return rows
    }

    override func setUp() {
        super.setUp()
        NumericNormalizer.segmenterOverride = ChineseWordLexiconSegmenter()
    }

    override func tearDown() {
        NumericNormalizer.segmenterOverride = nil
        super.tearDown()
    }

    func testFixtureIsWellFormed() throws {
        let rows = try Self.loadRows()
        XCTAssertGreaterThan(rows.count, 700)
        for row in rows {
            XCTAssertTrue(["must-change", "must-keep", "deferred"].contains(row.kind), "line \(row.line)")
        }
        let prose = rows.filter { $0.clause.hasPrefix("C4-") }
        for language in ["C4-zh", "C4-en", "C4-mixed"] {
            XCTAssertGreaterThanOrEqual(prose.filter { $0.clause == language }.count, 60, language)
        }
    }

    func testEveryRowMatchesTheContract() throws {
        for row in try Self.loadRows() {
            let actual = TranscriptPostProcessor.process(row.text, options: row.processingOptions)
            XCTAssertEqual(actual, row.expected, row.label(actual))
        }
    }

    func testEveryRowIsIdempotent() throws {
        for row in try Self.loadRows() {
            let first = TranscriptPostProcessor.process(row.text, options: row.processingOptions)
            let second = TranscriptPostProcessor.process(first, options: row.processingOptions)
            XCTAssertEqual(second, first, "idempotence " + row.label(first))
        }
    }

    /// Inserting a filler between two words away from any numeral must not change a numeric decision.
    func testNumericDecisionsAreIndependentOfFillers() throws {
        for row in try Self.loadRows() where row.kind != "deferred" {
            let options = row.processingOptions
            guard options.isFillerCleanupEnabled, options.isSmartNumericFormattingEnabled,
                  let variant = Self.fillerVariant(of: row.text) else { continue }
            let base = Self.numericEdits(row.text, options: options)
            let withFiller = Self.numericEdits(variant, options: options)
            XCTAssertEqual(withFiller, base, "filler independence line \(row.line): \(variant.debugDescription)")
        }
    }

    func testHotwordsAreByteIdentical() throws {
        for row in try Self.loadRows() where row.kind != "deferred" {
            let options = row.processingOptions
            guard !options.knownTerms.isEmpty else { continue }
            let output = TranscriptPostProcessor.process(row.text, options: options)
            for term in options.knownTerms where row.text.range(of: term, options: .caseInsensitive) != nil {
                let original = String(row.text[row.text.range(of: term, options: .caseInsensitive)!])
                XCTAssertTrue(output.contains(original), "hotword \(original) line \(row.line): \(output)")
            }
        }
    }

    /// The system segmenter may add vetoes, never conversions.
    func testSystemSegmenterOnlyAddsAbstentions() throws {
        for row in try Self.loadRows() where row.kind != "deferred" {
            let options = row.processingOptions
            guard options.isSmartNumericFormattingEnabled else { continue }
            NumericNormalizer.segmenterOverride = ChineseWordLexiconSegmenter()
            let lexicon = Set(Self.numericEdits(row.text, options: options))
            NumericNormalizer.segmenterOverride = nil
            let system = Set(Self.numericEdits(row.text, options: options))
            XCTAssertTrue(system.isSubset(of: lexicon), "line \(row.line): extra edits \(system.subtracting(lexicon))")
        }
    }

    /// The examples shown under 智能数字格式 must be what the formatter actually does.
    func testPreferencesExamplesMatchTheFormatter() {
        let zh = PreferencesCopy.texts(for: .chinese).numericFormattingExamples
        let en = PreferencesCopy.texts(for: .english).numericFormattingExamples
        let examples: [(String, String, String)] = [
            (zh, "百分之三点五", "3.5%"), (zh, "验证码是一二三四五六", "验证码是123456"),
            (zh, "第三题", "第3题"), (zh, "twenty one", "21"),
            (en, "百分之三点五", "3.5%"), (en, "twenty one", "21"), (en, "three point five", "3.5")
        ]
        for (copy, input, output) in examples {
            XCTAssertTrue(copy.contains("\(input) → \(output)"), "copy lists \(input) → \(output)")
            XCTAssertEqual(NormalizationPipeline.normalize(input), output, input)
        }
        XCTAssertTrue(zh.contains("这段代码两三行"))
        XCTAssertEqual(NormalizationPipeline.normalize("这段代码两三行"), "这段代码两三行")
        XCTAssertTrue(en.contains("No one knows"))
        XCTAssertEqual(NormalizationPipeline.normalize("No one knows"), "No one knows")
    }

    // MARK: - Helpers

    static func numericEdits(_ text: String, options: TranscriptProcessingOptions) -> [String] {
        TranscriptPostProcessor.processWithTrace(text, options: options).trace.stages
            .filter { $0.stage == .normalization }
            .flatMap(\.events)
            .filter { $0.ruleID.hasPrefix("numeric.") && $0.before != $0.after }
            .map { "\($0.ruleID): \($0.before) -> \($0.after)" }
    }

    /// Inserts 呃 between two Han characters, or "um" between two English words, at least two
    /// characters away from any numeral, digit, Latin letter (for Han) or number word (for English).
    static func fillerVariant(of text: String) -> String? {
        let chars = Array(text)
        func isNumeralLike(_ c: Character) -> Bool {
            c.isNumber || "零〇一二两三四五六七八九十百千万亿幺点第%％".contains(c)
        }
        func isHan(_ c: Character) -> Bool {
            c.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
        }
        let candidates = (2..<max(2, chars.count - 1)).filter { index in
            guard index - 2 >= 0, index + 1 < chars.count else { return false }
            let window = chars[(index - 2)...(index + 1)]
            return isHan(chars[index - 1]) && isHan(chars[index])
                && window.allSatisfy { isHan($0) && !isNumeralLike($0) }
        }
        if let index = candidates.dropFirst(candidates.count / 2).first {
            return String(chars[..<index]) + "呃" + String(chars[index...])
        }
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        let numberWords: Set<String> = [
            "zero", "oh", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
            "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
            "nineteen", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
            "hundred", "thousand", "million", "billion", "point", "percent", "and", "a", "at", "first",
            "second", "third", "half", "thirds", "per", "cent"
        ]
        func plainWord(_ word: Substring) -> Bool {
            !word.isEmpty && word.allSatisfy { $0.isASCII && $0.isLetter }
                && !numberWords.contains(word.lowercased())
        }
        guard words.count >= 4 else { return nil }
        for index in 1..<(words.count - 1) where plainWord(words[index - 1]) && plainWord(words[index])
            && (index < 2 || plainWord(words[index - 2]) || words[index - 2].last?.isLetter == true) {
            return (words[..<index] + ["um"] + words[index...]).joined(separator: " ")
        }
        return nil
    }
}

final class NumericLongDictationGoldenTests: XCTestCase {
    private static let sentences: [(String, String)] = [
        ("今天上午我们开了三个会，讨论了十几个问题。", "今天上午我们开了三个会，讨论了十几个问题。"),
        ("这个项目的转化率是百分之三点五，比上个月高了百分之零点八。", "这个项目的转化率是3.5%，比上个月高了0.8%。"),
        ("验证码是一二三四五六，五分钟内有效。", "验证码是123456，五分钟内有效。"),
        ("第三题和第五题我还没做完。", "第3题和第5题我还没做完。"),
        ("我输错密码三四次了，账号被锁了。", "我输错密码三四次了，账号被锁了。"),
        ("这段代码两三行就够了。", "这段代码两三行就够了。"),
        ("会议改到明天下午三点半。", "会议改到明天下午三点半。"),
        ("我们一共跑了五点三公里，平均配速六分钟。", "我们一共跑了5.3公里，平均配速六分钟。"),
        ("体温三十七点五度，有点发烧。", "体温37.5度，有点发烧。"),
        ("他的房间号是三零二。", "他的房间号是302。"),
        ("我二零二五年毕业，二零二六年十月二号入职。", "我二零二五年毕业，2026年10月2号入职。"),
        ("这一问题很重要，我们下周一再讨论。", "这一问题很重要，我们下周一再讨论。"),
        ("百分之八十以上的用户都选了这个方案。", "80%以上的用户都选了这个方案。"),
        ("No one knows the answer yet.", "No one knows the answer yet."),
        ("I have twenty one questions about the API.", "I have 21 questions about the API."),
        ("The meeting is at five thirty tomorrow.", "The meeting is at five thirty tomorrow."),
        ("We raised three point five million dollars last year.", "We raised 3.5 million dollars last year."),
        ("Please open version one point two of the app.", "Please open version 1.2 of the app."),
        ("I use ASP.NET and Node.js every day.", "I use ASP.NET and Node.js every day."),
        ("This one is fine, but the other one is not.", "This one is fine, but the other one is not."),
        ("Step one is to install it, step two is to run it.", "Step 1 is to install it, step 2 is to run it."),
        ("My code is one two three four.", "My code is 1234."),
        ("It grew one hundred and twenty five percent.", "It grew 125%."),
        ("I was born in nineteen ninety nine.", "I was born in 1999."),
        ("我用 Python three 写了一个脚本。", "我用 Python 3 写了一个脚本。"),
        ("这个版本叫 V five。", "这个版本叫 V5。"),
        ("我有twenty one个问题想问你。", "我有21个问题想问你。"),
        ("大概五六个人会来。", "大概五六个人会来。"),
        ("这个函数的代码三四十行。", "这个函数的代码三四十行。"),
        ("三点一起走吧。", "三点一起走吧。"),
        ("他身高一点八米。", "他身高1.8米。"),
        ("Take a five-minute break.", "Take a five-minute break."),
        ("We stayed at the Four Seasons hotel.", "We stayed at the Four Seasons hotel."),
        ("Call nine one one if anything happens.", "Call 911 if anything happens."),
        ("It is the twenty first century.", "It is the 21st century."),
        ("About two thirds of the class agreed.", "About two thirds of the class agreed."),
        ("这个月电话两三个都没接到。", "这个月电话两三个都没接到。"),
        ("订单号：九八七六五四三。", "订单号：9876543。"),
        ("从百分之二十涨到百分之三十。", "从20%涨到30%。"),
        ("It works.Then we ship it.", "It works. Then we ship it.")
    ]

    static var dictation: String { sentences.map(\.0).joined(separator: " ") }

    override func setUp() {
        super.setUp()
        NumericNormalizer.segmenterOverride = ChineseWordLexiconSegmenter()
    }

    override func tearDown() {
        NumericNormalizer.segmenterOverride = nil
        super.tearDown()
    }

    func testLongDictationUnderDefaultSettings() {
        let options = TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: true,
            isAcademicReferenceFormattingEnabled: false,
            isFillerCleanupEnabled: false
        )
        let expected = Self.sentences.map(\.1).joined(separator: " ")
        let actual = TranscriptPostProcessor.process(Self.dictation, options: options)
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(TranscriptPostProcessor.process(actual, options: options), actual)
    }

    /// Every capability on: academic, filler and math must not disturb the numeric decisions
    /// (reviewed on 2026-10-02: identical to the default-settings golden in both math formats).
    func testLongDictationWithEveryCapabilityEnabled() {
        let expected = Self.sentences.map(\.1).joined(separator: " ")
        for format in [MathNotationOutputFormat.unicode, .latex] {
            let options = TranscriptProcessingOptions(
                isSmartNumericFormattingEnabled: true,
                isAcademicReferenceFormattingEnabled: true,
                isFillerCleanupEnabled: true,
                isMathNotationEnabled: true,
                mathNotationOutputFormat: format
            )
            let actual = TranscriptPostProcessor.process(Self.dictation, options: options)
            XCTAssertEqual(actual, expected, "\(format)")
            XCTAssertEqual(TranscriptPostProcessor.process(actual, options: options), actual, "\(format)")
        }
    }

    func testNumericPathPerformanceOnAFiveThousandCharacterDictation() {
        var text = ""
        while text.count < 5_000 { text += Self.dictation + " " }
        _ = NormalizationPipeline.normalize(text)
        let start = Date()
        let rounds = 3
        for _ in 0..<rounds { _ = NormalizationPipeline.normalize(text) }
        let average = Date().timeIntervalSince(start) / Double(rounds)
        XCTAssertLessThan(average, 0.1, "numeric path took \(average)s for \(text.count) characters")
    }
}
