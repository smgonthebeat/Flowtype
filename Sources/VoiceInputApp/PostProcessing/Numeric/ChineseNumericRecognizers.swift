import Foundation

/// Shared state for one numeric-stage pass.
struct NumericContext {
    let text: NumericText
    let protected: [Range<Int>]
    let segmenter: ChineseWordSegmenting
    let lexicon = ChineseWordLexiconSegmenter()

    func isProtected(_ range: Range<Int>) -> Bool {
        protected.contains { $0.overlaps(range) }
    }

    /// Word-boundary veto: a word crosses the construct edge.
    func crossesWord(_ range: Range<Int>) -> Bool {
        segmenter.crossesWordBoundary(range, in: text)
    }

    /// Maximal run of Chinese numerals and ASCII digits starting at `start`.
    func numeralRun(from start: Int) -> Range<Int> {
        var end = start
        while end < text.count, CharClass.isChineseNumeral(text[end]) || CharClass.isASCIIDigit(text[end]) { end += 1 }
        return start..<end
    }

    /// Maximal run of Chinese numerals and ASCII digits ending at `end`.
    func numeralRun(endingAt end: Int) -> Range<Int> {
        var start = end
        while start > 0, CharClass.isChineseNumeral(text[start - 1]) || CharClass.isASCIIDigit(text[start - 1]) { start -= 1 }
        return start..<end
    }

    func isDecimalPoint(_ offset: Int) -> Bool {
        guard let c = text.at(offset) else { return false }
        return c == "点" || c == "點"
    }

    /// Length of the measure word or unit starting at `offset`, if any.
    func measureWordLength(at offset: Int) -> Int? {
        for length in stride(from: 3, through: 1, by: -1) where offset + length <= text.count {
            if ChineseLexicon.measureWords.contains(text.slice(offset..<(offset + length))) { return length }
        }
        return nil
    }

    /// Length of the measurement unit (not a clock word) starting at `offset`, if any.
    func measurementUnitLength(at offset: Int) -> Int? {
        for length in stride(from: 4, through: 1, by: -1) where offset + length <= text.count {
            if ChineseLexicon.measurementUnits.contains(text.slice(offset..<(offset + length))) { return length }
        }
        if let c = text.at(offset), CharClass.isASCIILetter(c) || c == "%" || c == "％" { return 1 }
        return nil
    }
}

enum ChineseLexicon {
    static let measureWords: Set<String> = [
        "次", "个", "位", "年", "月", "天", "日", "号", "层", "楼", "岁", "分", "秒", "元", "块", "米", "克",
        "斤", "页", "行", "条", "张", "本", "件", "只", "台", "辆", "架", "部", "套", "种", "点", "度", "倍",
        "级", "名", "份", "期", "届", "章", "节", "题", "道", "人", "遍", "回", "声", "句", "段", "字", "笔",
        "角", "寸", "尺", "吨", "升", "周", "首", "颗", "根", "支", "把", "双", "排", "组", "批", "类", "项",
        "门", "间", "家", "座", "栋", "户", "场", "局", "轮", "步", "版", "代", "集", "小时", "分钟", "公里",
        "公斤", "千米", "厘米", "毫米", "星期", "礼拜"
    ]
    static let measurementUnits: Set<String> = [
        "米", "公里", "千米", "厘米", "毫米", "英里", "英尺", "英寸", "度", "克", "千克", "公斤", "斤", "吨",
        "升", "毫升", "元", "块", "倍", "秒", "分钟", "小时", "个小时", "个月", "个百分点", "百分点", "天",
        "年", "岁", "寸", "尺", "平方", "立方", "万", "亿", "公顷", "亩"
    ]
    static let timeCues: [String] = [
        "上午", "下午", "凌晨", "早上", "早晨", "晚上", "中午", "傍晚", "夜里", "半夜", "今晚", "今早",
        "明早", "明晚", "昨晚", "今天", "明天", "昨天", "后天", "前天", "现在", "每天", "星期", "礼拜",
        "周一", "周二", "周三", "周四", "周五", "周六", "周日", "周天", "闹钟", "几点",
        // Scheduling words: the value that follows is a time of day.
        "会议", "开会", "见面", "集合", "出发", "改到", "定在", "约在", "推到", "推迟到", "提前到", "延后到"
    ]
    static let degreeCharacters: Set<Character> = [
        "快", "慢", "早", "晚", "多", "少", "大", "小", "远", "近", "轻", "重", "好", "贵"
    ]
    static let strongLabels: [String] = [
        "身份证号码", "身份证号", "快递单号", "银行卡号", "电话号码", "手机号码", "验证码", "订单号", "手机号",
        "房间号", "航班号", "门牌号", "分机号", "车牌号", "座位号", "序列号", "会员号", "准考证号", "护照号",
        "代号", "号码", "学号", "账号", "编号", "邮编", "单号", "卡号", "工号", "尾号", "电话",
        // Traditional-script variants.
        "身份證號碼", "身份證號", "電話號碼", "手機號碼", "驗證碼", "訂單號", "手機號", "房間號", "號碼", "學號",
        "帳號", "賬號", "編號", "郵編", "電話"
    ]
    static let weakLabels: [String] = ["代码", "密码", "账户", "口令", "代碼", "密碼", "帳戶"]
    static let ordinalUnits: [String] = ["道题", "小题", "大题", "小问", "大问", "题", "问", "道題", "小題", "大題", "小問", "大問", "題", "問"]
    /// Sentence-final particles: the value before them ends cleanly (三零二吧, 三零三来着).
    static let finalParticles: [String] = ["来着", "吧", "吗", "呢", "啊", "呀", "哦", "嘛", "啦"]
    /// Scheduling words right after a value mark a time of day (八点零五开始).
    static let clockFollowers: [String] = ["开始", "出发", "集合", "开会", "见面", "结束", "截止", "起床", "上班", "下班", "见"]
    static let listConnectors: [String] = ["到", "至", "、", "和", "或", "与", "跟", "-", "～", "~", "—"]
    static let scoreNouns = #"(?:评分|得分|打分|满分|平均分)[ \t]*(?:(?:是|为|[:：])[ \t]*)?$"#
}

/// A parsed Chinese (or ASCII-digit) value: integer part, optional 点 + digit fraction.
struct ChineseValue {
    let range: Range<Int>
    let integer: Range<Int>
    let fraction: Range<Int>?
    let value: String?
    let reason: String
    let hasRepeatedPoint: Bool
}

enum ChineseNumericRecognizers {
    static func recognize(_ context: NumericContext) -> NumericDecisions {
        var decisions = NumericDecisions()
        percentages(context, &decisions)
        chinesePercentWords(context, &decisions)
        chinesePercentSigns(context, &decisions)
        decimals(context, &decisions)
        ordinals(context, &decisions)
        identifiers(context, &decisions)
        dates(context, &decisions)
        return decisions
    }

    // MARK: - Values

    static func integerValue(_ range: Range<Int>, _ context: NumericContext) -> (String?, String) {
        let chars = Array(context.text.chars[range])
        guard !chars.isEmpty else { return (nil, "missing integer") }
        if chars.allSatisfy(CharClass.isASCIIDigit) { return (String(chars), "") }
        guard chars.allSatisfy(CharClass.isChineseNumeral) else { return (nil, "mixed Arabic and Chinese digits") }
        let reading = ChineseNumberGrammar.read(chars)
        if reading.isApproximate { return (nil, "approximation") }
        if reading.isElided { return (nil, "colloquial elision is ambiguous before a decimal") }
        guard let cardinal = reading.cardinal else { return (nil, "not a cardinal") }
        return (String(cardinal), "")
    }

    static func fractionValue(_ range: Range<Int>, _ context: NumericContext) -> String? {
        let chars = Array(context.text.chars[range])
        guard !chars.isEmpty else { return nil }
        if chars.allSatisfy(CharClass.isASCIIDigit) { return String(chars) }
        return ChineseNumberGrammar.digitString(chars)
    }

    /// Parses `integer [点 digits]` starting at `start`; spaces around 点 are allowed.
    static func value(from start: Int, _ context: NumericContext) -> ChineseValue? {
        let text = context.text
        var integer = context.numeralRun(from: start)
        guard !integer.isEmpty else { return nil }
        // An Arabic decimal such as 6.5 (and malformed 1.2.3) is one scalar.
        if text.slice(integer).allSatisfy(CharClass.isASCIIDigit), text.at(integer.upperBound) == ".",
           let next = text.at(integer.upperBound + 1), CharClass.isASCIIDigit(next) {
            var end = integer.upperBound + 1
            while end < text.count, CharClass.isASCIIDigit(text[end]) { end += 1 }
            let malformed = text.at(end) == "." && text.at(end + 1).map(CharClass.isASCIIDigit) == true
            if malformed {
                while end < text.count, CharClass.isASCIIDigit(text[end]) || text[end] == "." { end += 1 }
            }
            return ChineseValue(range: start..<end, integer: integer, fraction: (integer.upperBound + 1)..<end,
                                value: malformed ? nil : text.slice(start..<end), reason: "repeated decimal point",
                                hasRepeatedPoint: malformed)
        }
        let afterInteger = text.skipSpaces(from: integer.upperBound)
        var fraction: Range<Int>?
        if context.isDecimalPoint(afterInteger) {
            let fractionStart = text.skipSpaces(from: afterInteger + 1)
            let run = context.numeralRun(from: fractionStart)
            if !run.isEmpty { fraction = run }
        }
        let end = fraction?.upperBound ?? integer.upperBound
        let afterEnd = text.skipSpaces(from: end)
        let repeated = fraction != nil && context.isDecimalPoint(afterEnd)
            && context.numeralRun(from: text.skipSpaces(from: afterEnd + 1)).isEmpty == false
        let (integerText, integerReason) = integerValue(integer, context)
        var value: String? = integerText
        var reason = integerReason
        if let fraction {
            if let digits = fractionValue(fraction, context) {
                value = integerText.map { $0 + "." + digits }
            } else {
                value = nil
                reason = "fraction is not a digit run"
            }
        }
        if repeated { value = nil; reason = "repeated decimal point" }
        integer = integer.lowerBound..<integer.upperBound
        return ChineseValue(range: start..<end, integer: integer, fraction: fraction, value: value,
                            reason: reason, hasRepeatedPoint: repeated)
    }

    // MARK: - Percent (百分之 X)

    static func percentages(_ context: NumericContext, _ decisions: inout NumericDecisions) {
        let text = context.text
        var offset = 0
        while offset + 3 <= text.count {
            guard text.hasPrefix("百分之", at: offset) else { offset += 1; continue }
            let marker = offset
            offset += 3
            let start = text.skipSpaces(from: marker + 3)
            let rule = "numeric.zh.percent"
            // 百分之百
            if text.at(start) == "百", !(text.at(start + 1).map(CharClass.isChineseNumeral) ?? false) {
                let range = marker..<(start + 1)
                if !context.isProtected(range) {
                    decisions.propose(range, "100%", rule: rule, evidence: "百分之 + complete numeral")
                }
                continue
            }
            var scalarEnd: Int
            var scalarValue: String?
            var reason = ""
            var repeated = false
            if let first = text.at(start), CharClass.isASCIILetter(first) {
                guard let english = EnglishNumericRecognizer.scalar(from: start, context) else { continue }
                scalarEnd = english.range.upperBound
                scalarValue = english.value
                reason = english.value == nil ? "incomplete English number" : ""
            } else if let parsed = value(from: start, context) {
                scalarEnd = parsed.range.upperBound
                scalarValue = parsed.value
                reason = parsed.reason
                repeated = parsed.hasRepeatedPoint
            } else {
                continue
            }
            var abstainEnd = scalarEnd
            let pointAfter = text.skipSpaces(from: scalarEnd)
            if repeated, context.isDecimalPoint(pointAfter) {
                abstainEnd = context.numeralRun(from: text.skipSpaces(from: pointAfter + 1)).upperBound
            }
            if let next = text.at(scalarEnd), CharClass.isASCIIWordChar(next) {
                // A numeral glued to a Latin token belongs to that token (5.6B, 5.6kg, 5.6_id).
                scalarValue = nil
                reason = "numeral glued to a Latin token"
                var end = scalarEnd
                while end < text.count, CharClass.isASCIIWordChar(text[end]) { end += 1 }
                abstainEnd = end
            } else if let next = text.at(scalarEnd), "几多来余".contains(next) {
                scalarValue = nil
                reason = "approximation"
                abstainEnd = scalarEnd + 1
            } else if text.skipSpaces(from: scalarEnd) > scalarEnd,
                      let resumed = text.at(text.skipSpaces(from: scalarEnd)),
                      CharClass.isChineseNumeral(resumed) || CharClass.isASCIIDigit(resumed) {
                scalarValue = nil
                reason = "numeral continues after a space"
                abstainEnd = context.numeralRun(from: text.skipSpaces(from: scalarEnd)).upperBound
            } else if let duplicate = duplicateMarkerEnd(after: scalarEnd, context) {
                scalarValue = nil
                reason = "duplicate percent marker"
                abstainEnd = duplicate
            }
            let range = marker..<scalarEnd
            offset = max(offset, scalarEnd)
            if context.isProtected(marker..<abstainEnd) { continue }
            if let scalarValue, !context.crossesWord(marker..<scalarEnd) {
                decisions.propose(range, scalarValue + "%", rule: rule, evidence: "百分之 + complete numeral")
                rangeContinuation(after: scalarEnd, context, &decisions)
            } else {
                decisions.abstain(marker..<abstainEnd, rule: rule + ".abstain",
                                  reason: scalarValue == nil ? reason : "numeral continues into a word")
            }
        }
    }

    /// 百分之八十到九十: the second end of a range converts with the first.
    private static func rangeContinuation(after end: Int, _ context: NumericContext, _ decisions: inout NumericDecisions) {
        let text = context.text
        guard let connector = text.at(end), "到至~～-－—".contains(connector) else { return }
        let start = end + 1
        guard !text.hasPrefix("百分之", at: start), let parsed = value(from: start, context),
              let value = parsed.value else { return }
        let after = parsed.range.upperBound
        if let next = text.at(after) {
            if CharClass.isASCIIWordChar(next) || CharClass.isChineseNumeral(next) || "几多来余%％".contains(next) { return }
            if context.measureWordLength(at: after) != nil { return }
        }
        guard !context.isProtected(parsed.range), !context.crossesWord(parsed.range) else { return }
        decisions.propose(parsed.range, value + "%", rule: "numeric.zh.percent.range",
                          evidence: "second end of a percent range")
    }

    private static func duplicateMarkerEnd(after end: Int, _ context: NumericContext) -> Int? {
        let text = context.text
        let next = text.skipSpaces(from: end)
        if let c = text.at(next), c == "%" || c == "％" { return next + 1 }
        if let word = EnglishNumericRecognizer.percentMarkerEnd(at: next, context) { return word }
        return nil
    }

    /// Chinese numeral + English "percent" (二十 percent).
    static func chinesePercentWords(_ context: NumericContext, _ decisions: inout NumericDecisions) {
        let text = context.text
        for offset in 0..<text.count {
            guard let markerEnd = EnglishNumericRecognizer.percentMarkerEnd(at: offset, context),
                  offset == 0 || !CharClass.isASCIIWordChar(text[offset - 1]) else { continue }
            let scalarEnd = text.skipSpacesBackward(from: offset)
            guard scalarEnd > 0, let last = text.at(scalarEnd - 1), CharClass.isChineseNumeral(last) else { continue }
            var start = context.numeralRun(endingAt: scalarEnd).lowerBound
            // Include an integer part before 点 (三点五 percent).
            let beforeRun = text.skipSpacesBackward(from: start)
            if context.isDecimalPoint(beforeRun - 1) {
                let integer = context.numeralRun(endingAt: text.skipSpacesBackward(from: beforeRun - 1))
                if !integer.isEmpty { start = integer.lowerBound }
            }
            let range = start..<markerEnd
            guard !context.isProtected(range) else { continue }
            let prefixStart = text.skipSpacesBackward(from: start)
            if text.hasSuffix("百分之", endingAt: prefixStart) {
                decisions.abstain(range, rule: "numeric.zh.percent.abstain", reason: "duplicate percent marker")
                continue
            }
            guard let parsed = value(from: start, context), parsed.range.upperBound == scalarEnd,
                  let value = parsed.value else {
                decisions.abstain(range, rule: "numeric.zh.percent.abstain", reason: "incomplete numeral")
                continue
            }
            decisions.propose(range, value + "%", rule: "numeric.zh.percent-word",
                              evidence: "Chinese numeral + English percent")
        }
    }

    /// Chinese numeral + percent sign (三十％ -> 30%). Decimals before % are handled by the decimal rule.
    static func chinesePercentSigns(_ context: NumericContext, _ decisions: inout NumericDecisions) {
        let text = context.text
        for sign in 0..<text.count where text[sign] == "%" || text[sign] == "％" {
            let run = context.numeralRun(endingAt: sign)
            guard !run.isEmpty, !context.isDecimalPoint(run.lowerBound - 1),
                  !text.hasSuffix("百分之", endingAt: run.lowerBound) else { continue }
            let chars = Array(text.chars[run])
            guard chars.allSatisfy(CharClass.isChineseNumeral) else { continue }
            let range = run.lowerBound..<(sign + 1)
            guard !context.isProtected(range) else { continue }
            let reading = ChineseNumberGrammar.read(chars)
            if reading.isCompleteCardinal, let value = reading.cardinal {
                decisions.propose(range, "\(value)%", rule: "numeric.zh.percent-sign", evidence: "Chinese numeral + percent sign")
            } else {
                decisions.abstain(range, rule: "numeric.zh.percent.abstain", reason: "approximate or incomplete numeral")
            }
        }
    }

    // MARK: - Decimal (X点Y)

    static func decimals(_ context: NumericContext, _ decisions: inout NumericDecisions) {
        let text = context.text
        let rule = "numeric.zh.decimal"
        for point in 0..<text.count where context.isDecimalPoint(point) {
            let integerEnd = text.skipSpacesBackward(from: point)
            let integer = context.numeralRun(endingAt: integerEnd)
            let fractionStart = text.skipSpaces(from: point + 1)
            let fractionRun = context.numeralRun(from: fractionStart)
            guard !integer.isEmpty, !fractionRun.isEmpty else { continue }
            // Keep a trailing 万/亿 as a scale word after the digits (三点五万 -> 3.5万).
            var fraction = fractionRun
            if fraction.count > 1, let last = text.at(fraction.upperBound - 1), "万亿萬億".contains(last) {
                fraction = fraction.lowerBound..<(fraction.upperBound - 1)
            }
            let range = integer.lowerBound..<fraction.upperBound
            guard !context.isProtected(range) else { continue }
            // A percentage owns its decimal.
            let beforeInteger = text.skipSpacesBackward(from: integer.lowerBound)
            if text.hasSuffix("百分之", endingAt: beforeInteger) { continue }
            if EnglishNumericRecognizer.percentMarkerEnd(at: text.skipSpaces(from: fractionRun.upperBound), context) != nil {
                continue
            }
            if let reason = decimalVeto(integer: integer, point: point, fraction: fraction,
                                        fractionRun: fractionRun, context) {
                var abstainEnd = fractionRun.upperBound
                while abstainEnd < text.count, CharClass.isASCIIWordChar(text[abstainEnd]),
                      reason.hasPrefix("glued") { abstainEnd += 1 }
                decisions.abstain(integer.lowerBound..<abstainEnd, rule: rule + ".abstain", reason: reason)
                continue
            }
            let (integerText, _) = integerValue(integer, context)
            guard let integerText, let digits = fractionValue(fraction, context) else { continue }
            decisions.propose(range, integerText + "." + digits, rule: rule,
                              evidence: "complete integer + 点 + digit-by-digit fraction")
        }
    }

    /// Returns the reason the X点Y construct must stay as dictated, or nil for a decimal.
    private static func decimalVeto(
        integer: Range<Int>,
        point: Int,
        fraction: Range<Int>,
        fractionRun: Range<Int>,
        _ context: NumericContext
    ) -> String? {
        let text = context.text
        let integerChars = Array(text.chars[integer])
        // Repeated separators (三点五点二, 1点2点3) are versions or lists, not decimals.
        let before = text.skipSpacesBackward(from: integer.lowerBound)
        if context.isDecimalPoint(before - 1), !context.numeralRun(endingAt: text.skipSpacesBackward(from: before - 1)).isEmpty {
            return "repeated decimal point"
        }
        let after = text.skipSpaces(from: fractionRun.upperBound)
        if context.isDecimalPoint(after) { return "repeated decimal point" }
        if text.at(before - 1) == "第" { return "ordinal 第N点" }
        if integerChars == ["两"] || integerChars == ["兩"] { return "integer part 两 is a count of points" }
        let (integerText, integerReason) = integerValue(integer, context)
        guard let integerText else { return integerReason }
        guard fractionValue(fraction, context) != nil else { return "fraction is not a digit run (clock or count)" }
        if fraction.upperBound != fractionRun.upperBound,
           !fractionRun.isEmpty, let scale = text.at(fraction.upperBound), !"万亿萬億".contains(scale) {
            return "fraction is not a digit run"
        }
        // Left context glued to an identifier.
        if let left = text.at(integer.lowerBound - 1), left == "." || left == "_" { return "glued to an identifier" }
        // Right context glued to Latin letters: only a unit token may follow.
        let end = fractionRun.upperBound
        if let next = text.at(end), next == "_" { return "glued to an identifier" }
        if let next = text.at(end), CharClass.isASCIILetter(next) {
            var tokenEnd = end
            while tokenEnd < text.count, CharClass.isASCIILetter(text[tokenEnd]) { tokenEnd += 1 }
            let token = text.slice(end..<tokenEnd)
            if let follow = text.at(tokenEnd), CharClass.isASCIIDigit(follow) || follow == "_" {
                return "glued to an identifier"
            }
            if !(token.count == 1 || UnitLexicon.latinUnits.contains(token) || UnitLexicon.latinUnits.contains(token.lowercased())) {
                return "glued to a Latin word"
            }
        }
        let integerValue = Int(integerText) ?? Int.max
        let fractionDigits = fractionValue(fraction, context) ?? ""
        let nextOffset = text.skipSpaces(from: fractionRun.upperBound)
        let scaleFollows = fraction.upperBound != fractionRun.upperBound
        let unitFollows = scaleFollows || context.measurementUnitLength(at: nextOffset) != nil
            && !(text.hasPrefix("分", at: nextOffset) && !text.hasPrefix("分钟", at: nextOffset))
        // Clock and score readings of 分.
        if text.hasPrefix("分", at: nextOffset), !text.hasPrefix("分钟", at: nextOffset) {
            let clause = text.clausePrefix(before: integer.lowerBound)
            let afterFen = text.skipSpaces(from: nextOffset + 1)
            let scoreContext = clause.range(of: ChineseLexicon.scoreNouns, options: .regularExpression) != nil
            let completeValue = afterFen >= text.count || CharClass.isClauseBreak(text[afterFen])
                || "、/／！？".contains(text[afterFen])
            if scoreContext && completeValue && !hasTimeCue(before: integer.lowerBound, context) { return nil }
            let validClock = integerValue <= 24 && (Int(fractionDigits) ?? 99) <= 59
            let clockContinuation = text.slice(afterFen..<min(text.count, afterFen + 4))
                .range(of: #"^[零〇一二两三四五六七八九十0-9]+秒"#, options: .regularExpression) != nil
            if clockContinuation || validClock || !completeValue { return "clock reading (点…分)" }
            return nil // not a valid clock value (九十五点五分): a score
        }
        if text.hasPrefix("刻", at: nextOffset) { return "clock reading (点…刻)" }
        let tail = text.slice(nextOffset..<min(text.count, nextOffset + 4)).lowercased()
        if tail.hasPrefix("pm") || tail.hasPrefix("am") || tail.hasPrefix("p.m") || tail.hasPrefix("a.m") {
            return "clock reading (am/pm)"
        }
        let clockValue = integerValue <= 24 && fractionDigits.count <= 2
        if clockValue, !unitFollows, hasTimeCue(before: integer.lowerBound, context) {
            return "clock reading (time cue)"
        }
        if clockValue, !unitFollows, ChineseLexicon.clockFollowers.contains(where: { text.hasPrefix($0, at: nextOffset) }) {
            return "clock reading (scheduling word after the value)"
        }
        // Enumeration: 总结三点一：…, 三点一、要快…, 三点一是成本…
        if fractionDigits.count == 1, fractionDigits != "0", let marker = text.at(fractionRun.upperBound),
           "、：:是".contains(marker) {
            let afterMarker = text.at(fractionRun.upperBound + 1)
            if !(afterMarker.map { CharClass.isChineseNumeral($0) || CharClass.isASCIIDigit($0) } ?? false) {
                return "enumeration (N点 + list marker)"
            }
        }
        // 一点 meaning "a bit".
        if integerChars == ["一"], !unitFollows, let previous = text.at(integer.lowerBound - 1) {
            if previous == "有" { return "a bit (有一点)" }
            if ChineseLexicon.degreeCharacters.contains(previous),
               !context.lexicon.isInsideLongerWord(at: integer.lowerBound - 1, in: text) {
                return "a bit (degree word + 一点)"
            }
        }
        if context.crossesWord(integer.lowerBound..<fraction.upperBound) {
            return "numeral belongs to a neighbouring word"
        }
        return nil
    }

    private static func hasTimeCue(before offset: Int, _ context: NumericContext) -> Bool {
        let clause = context.text.clausePrefix(before: offset)
        return ChineseLexicon.timeCues.contains { clause.contains($0) }
    }


    // MARK: - Ordinal references (第N题)

    static func ordinals(_ context: NumericContext, _ decisions: inout NumericDecisions) {
        let text = context.text
        var offset = 0
        while offset < text.count {
            guard text[offset] == "第" else { offset += 1; continue }
            var items: [Range<Int>] = []
            var cursor = offset
            var unitEnd: Int?
            while cursor < text.count, text[cursor] == "第" {
                let number = context.numeralRun(from: cursor + 1)
                guard !number.isEmpty else { break }
                items.append(number)
                if let unit = ordinalUnit(at: number.upperBound, context) {
                    unitEnd = number.upperBound + unit
                    break
                }
                // A unit-less member continues the list only through a connector and another 第.
                var next = number.upperBound
                if let connector = ChineseLexicon.listConnectors.first(where: { text.hasPrefix($0, at: next) }) {
                    next += connector.count
                }
                guard text.at(next) == "第" else { break }
                cursor = next
            }
            guard let end = unitEnd, !items.isEmpty else { offset += 1; continue }
            let range = offset..<end
            offset = end
            guard !context.isProtected(range) else { continue }
            let values = items.map { item -> Int? in
                let digits = text.slice(item)
                if digits.allSatisfy(CharClass.isASCIIDigit) { return Int(digits) }
                let reading = ChineseNumberGrammar.read(text.chars[item])
                guard reading.isCompleteCardinal, let value = reading.cardinal else { return nil }
                return value
            }
            if values.contains(where: { $0 == nil }) {
                decisions.abstain(range, rule: "numeric.zh.ordinal.abstain",
                                  reason: "a member is not a complete cardinal (approximation or digit run)")
                continue
            }
            for (item, value) in zip(items, values) {
                decisions.propose(item, String(value!), rule: "numeric.zh.ordinal",
                                  evidence: "第 + complete cardinal + whole-word unit")
            }
        }
    }

    private static func ordinalUnit(at offset: Int, _ context: NumericContext) -> Int? {
        for unit in ChineseLexicon.ordinalUnits where context.text.hasPrefix(unit, at: offset) {
            let range = offset..<(offset + unit.count)
            // The unit must be a whole word, not the head of 问题/题材/问责.
            if context.crossesWord(range) { continue }
            return unit.count
        }
        return nil
    }

    // MARK: - Identifiers (验证码是一二三四五六)

    static func identifiers(_ context: NumericContext, _ decisions: inout NumericDecisions) {
        let text = context.text
        var offset = 0
        while offset < text.count {
            guard let label = labelMatch(at: offset, context) else { offset += 1; continue }
            offset = label.end
            var cursor = label.end
            if text.at(cursor) == " " { cursor += 1 }
            var hasConnector = false
            if let c = text.at(cursor), "是为：:".contains(c) {
                hasConnector = true
                cursor += 1
                if text.at(cursor) == " " { cursor += 1 }
            } else if cursor != label.end {
                // A space alone attaches a value only to a number label (验证码 一二三四).
                guard label.isASCII || label.isStrong else { continue }
            }
            let strongEvidence = label.isStrong || hasConnector
            var runs: [Range<Int>] = []
            guard evaluateIdentifierRun(at: cursor, strongEvidence: strongEvidence, weakLabel: !label.isStrong,
                                        hasConnector: hasConnector, context, &runs, &decisions) else { continue }
            for run in runs {
                guard let digits = ChineseNumberGrammar.digitString(Array(text.chars[run])) else { continue }
                decisions.propose(run, digits, rule: "numeric.zh.identifier",
                                  evidence: label.isStrong ? "number label + clean digit run" : "label + connector + clean digit run")
            }
            offset = max(offset, runs.last?.upperBound ?? offset)
        }
    }

    /// Validates the digit run at `start` (and any coordinated run). Returns false when nothing converts.
    private static func evaluateIdentifierRun(
        at start: Int,
        strongEvidence: Bool,
        weakLabel: Bool,
        hasConnector: Bool,
        _ context: NumericContext,
        _ runs: inout [Range<Int>],
        _ decisions: inout NumericDecisions
    ) -> Bool {
        let text = context.text
        var end = start
        while end < text.count, CharClass.isChineseRunDigit(text[end]) { end += 1 }
        let run = start..<end
        guard run.count >= 2, !context.isProtected(run) else { return false }
        let rule = "numeric.zh.identifier.abstain"
        let numeral = context.numeralRun(from: start)
        if numeral.upperBound > end {
            decisions.abstain(numeral, rule: rule, reason: "digit run continues into a larger numeral")
            return false
        }
        if ChineseNumberGrammar.isApproximate(Array(text.chars[run])) {
            decisions.abstain(run, rule: rule, reason: "approximation")
            return false
        }
        let next = text.at(end)
        // 几/多/余 mark an approximation; 来 only when a measure word follows (十来个, not 三零三来着).
        let approximationFollows = next.map { "几多余".contains($0) } ?? false
            || next == "来" && context.measureWordLength(at: end + 1) != nil
        let measureFollows = context.measureWordLength(at: end) != nil || approximationFollows
        if measureFollows {
            decisions.abstain(run, rule: rule, reason: "measure word follows")
            return false
        }
        // Label + digit runs are strong evidence; only the deterministic lexicon may veto them
        // (system tokens such as 单号三 merge the label with the value).
        if context.lexicon.crossesWordBoundary(run, in: text) {
            decisions.abstain(run, rule: rule, reason: "digit belongs to a neighbouring word")
            return false
        }
        var clean = CharClass.isCleanEnd(next) || next == "的"
            || ChineseLexicon.finalParticles.contains { text.hasPrefix($0, at: end) }
        var coordinated: [Range<Int>] = []
        if !clean, let connector = ["还是", "和", "或", "与", "跟"].first(where: { text.hasPrefix($0, at: end) }) {
            var nextStart = end + connector.count
            if text.at(nextStart) == " " { nextStart += 1 }
            var nested: [Range<Int>] = []
            var scratch = NumericDecisions()
            if evaluateIdentifierRun(at: nextStart, strongEvidence: true, weakLabel: false, hasConnector: true,
                                     context, &nested, &scratch) {
                clean = true
                coordinated = nested
            }
        }
        let accepted: Bool
        if run.count >= 4 {
            accepted = strongEvidence || clean
        } else {
            accepted = clean && strongEvidence
        }
        guard accepted, clean || run.count >= 4 && strongEvidence else {
            if run.count >= 2 && (strongEvidence || weakLabel) {
                decisions.abstain(run, rule: rule, reason: "no clean ending or label evidence")
            }
            return false
        }
        runs.append(run)
        runs += coordinated
        return true
    }

    private struct LabelMatch {
        let end: Int
        let isStrong: Bool
        let isASCII: Bool
    }

    private static func labelMatch(at offset: Int, _ context: NumericContext) -> LabelMatch? {
        let text = context.text
        var best: LabelMatch?
        func consider(_ match: LabelMatch) {
            if best == nil || match.end > best!.end { best = match }
        }
        for label in ChineseLexicon.strongLabels where text.hasPrefix(label, at: offset) {
            consider(LabelMatch(end: offset + label.count, isStrong: true, isASCII: false))
        }
        for label in ChineseLexicon.weakLabels where text.hasPrefix(label, at: offset) {
            // A weak label never outranks a strong one of the same length.
            if best == nil || offset + label.count > best!.end {
                consider(LabelMatch(end: offset + label.count, isStrong: false, isASCII: false))
            }
        }
        // Any word ending in 码 names a code (取件码, 提取码, 门牌号码). Words ending in 号 are often
        // not numbers (口号, 问号), so 号 labels stay in the explicit list.
        if let c = text.at(offset), c == "码" || c == "碼", offset > 0, CharClass.isHan(text[offset - 1]),
           !CharClass.isChineseNumeral(text[offset - 1]),
           !ChineseLexicon.weakLabels.contains(where: { text.hasSuffix($0, endingAt: offset + 1) }),
           let next = text.at(offset + 1), CharClass.isChineseRunDigit(next) || "是为：: ".contains(next) {
            consider(LabelMatch(end: offset + 1, isStrong: true, isASCII: false))
        }
        if best != nil { return best }
        // "ID" as a whole token.
        if offset + 2 <= text.count, text.slice(offset..<(offset + 2)).lowercased() == "id",
           !(text.at(offset - 1).map(CharClass.isASCIILetter) ?? false),
           !(text.at(offset + 2).map(CharClass.isASCIILetter) ?? false) {
            return LabelMatch(end: offset + 2, isStrong: true, isASCII: true)
        }
        return nil
    }

    // MARK: - Full dates (二零二六年十月二号)

    static func dates(_ context: NumericContext, _ decisions: inout NumericDecisions) {
        let text = context.text
        for yearMark in 0..<text.count where text[yearMark] == "年" {
            guard yearMark >= 4 else { continue }
            let year = (yearMark - 4)..<yearMark
            let yearChars = Array(text.chars[year])
            if let before = text.at(year.lowerBound - 1),
               CharClass.isChineseNumeral(before) || CharClass.isASCIIDigit(before) { continue }
            let yearDigits: String
            if yearChars.allSatisfy(CharClass.isASCIIDigit) {
                yearDigits = String(yearChars)
            } else if let digits = ChineseNumberGrammar.digitString(yearChars) {
                yearDigits = digits
            } else {
                continue
            }
            var cursor = yearMark + 1
            if text.at(cursor) == "的" { cursor += 1 }
            let month = context.numeralRun(from: cursor)
            guard let monthValue = dateNumber(month, context), (1...12).contains(monthValue),
                  text.at(month.upperBound) == "月" else { continue }
            let day = context.numeralRun(from: month.upperBound + 1)
            guard let dayValue = dateNumber(day, context), (1...31).contains(dayValue),
                  let suffix = text.at(day.upperBound), suffix == "号" || suffix == "日" else { continue }
            let range = year.lowerBound..<(day.upperBound + 1)
            guard !context.isProtected(range) else { continue }
            // Established contract: the full date is rewritten as one unit (an inner 的 is dropped).
            decisions.propose(range, "\(yearDigits)年\(monthValue)月\(dayValue)\(suffix)",
                              rule: "numeric.zh.date", evidence: "year + month + day")
            proposeDayRange(after: day.upperBound + 1, context, &decisions)
        }
        monthDays(context, &decisions)
    }

    /// Owner decision (2026-10-03): a month and day without a year also become digits
    /// (七月一号 → 7月1号). Both parts must be complete cardinals in range and the day must end
    /// in 号 or 日; anything after 年 is left to the full-date rule so a date never half-converts.
    private static func monthDays(_ context: NumericContext, _ decisions: inout NumericDecisions) {
        let text = context.text
        for monthMark in 0..<text.count where text[monthMark] == "月" {
            let month = context.numeralRun(endingAt: monthMark)
            guard let monthValue = dateNumber(month, context), (1...12).contains(monthValue) else { continue }
            if text.at(month.lowerBound - 1) == "年" ||
                (text.at(month.lowerBound - 1) == "的" && text.at(month.lowerBound - 2) == "年") { continue }
            let day = context.numeralRun(from: monthMark + 1)
            guard let dayValue = dateNumber(day, context), (1...31).contains(dayValue),
                  let suffix = text.at(day.upperBound), suffix == "号" || suffix == "日" else { continue }
            let range = month.lowerBound..<(day.upperBound + 1)
            guard !context.isProtected(range) else { continue }
            decisions.propose(range, "\(monthValue)月\(dayValue)\(suffix)",
                              rule: "numeric.zh.date.monthDay", evidence: "month + day")
            proposeDayRange(after: day.upperBound + 1, context, &decisions)
        }
    }

    /// A day range after a converted date converts with it (2号到5号).
    private static func proposeDayRange(after offset: Int, _ context: NumericContext, _ decisions: inout NumericDecisions) {
        guard let connector = context.text.at(offset), "到至~～-－".contains(connector) else { return }
        let second = context.numeralRun(from: offset + 1)
        if let value = dateNumber(second, context), (1...31).contains(value),
           let secondSuffix = context.text.at(second.upperBound), secondSuffix == "号" || secondSuffix == "日",
           !context.isProtected(second) {
            decisions.propose(second, String(value), rule: "numeric.zh.date.range",
                              evidence: "day range after a date")
        }
    }

    private static func dateNumber(_ range: Range<Int>, _ context: NumericContext) -> Int? {
        guard !range.isEmpty, range.count <= 3 else { return nil }
        let chars = Array(context.text.chars[range])
        if chars.allSatisfy(CharClass.isASCIIDigit) { return Int(String(chars)) }
        let reading = ChineseNumberGrammar.read(chars)
        return reading.isCompleteCardinal ? reading.cardinal : nil
    }
}

enum UnitLexicon {
    static let latinUnits: Set<String> = [
        "kg", "km", "cm", "mm", "nm", "mg", "ml", "kb", "mb", "gb", "tb", "pb", "kB", "KB", "MB", "GB", "TB",
        "Hz", "kHz", "MHz", "GHz", "hz", "khz", "mhz", "ghz", "ms", "min", "mi", "ft", "lb", "lbs", "oz", "px",
        "pt", "em", "rem", "dB", "db", "mAh", "mah", "kW", "kw", "mV", "mv", "mA", "ma", "fps", "rpm", "bps",
        "kbps", "mbps", "gbps", "Kbps", "Mbps", "Gbps", "sec", "hr", "hrs", "yr", "yrs", "cc", "ppm", "pp"
    ]
}
