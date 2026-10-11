import Foundation
import NaturalLanguage

/// Word knowledge used only to veto Chinese numeric constructs.
/// A construct is vetoed when a word crosses its edge (e.g. 一 of 三点一 inside 一起).
protocol ChineseWordSegmenting {
    /// Word ranges (character offsets) that overlap `range` in `text`.
    func words(overlapping range: Range<Int>, in text: NumericText) -> [Range<Int>]
}

extension ChineseWordSegmenting {
    /// True when a word starts inside the construct and ends outside it, or vice versa.
    func crossesWordBoundary(_ range: Range<Int>, in text: NumericText) -> Bool {
        words(overlapping: range, in: text).contains { word in
            word.count > 1 && word.overlaps(range)
                && (word.lowerBound < range.lowerBound || word.upperBound > range.upperBound)
                && !range.contains(word.lowerBound..<word.upperBound)
        }
    }

    /// True when the single character at `offset` is the tail or head of a longer word.
    func isInsideLongerWord(at offset: Int, in text: NumericText) -> Bool {
        words(overlapping: offset..<(offset + 1), in: text).contains { $0.count > 1 }
    }
}

private extension Range where Bound == Int {
    func contains(_ other: Range<Int>) -> Bool {
        lowerBound <= other.lowerBound && other.upperBound <= upperBound
    }
}

/// Deterministic veto lexicon: common words that begin with a numeral or unit character,
/// or end with a degree adjective. It is the baseline on every macOS version.
struct ChineseWordLexiconSegmenter: ChineseWordSegmenting {
    static let words: Set<String> = [
        // Words beginning with a numeral character.
        "一起", "一定", "一线", "一下", "一些", "一样", "一直", "一般", "一致", "一切", "一共", "一会",
        "一边", "一旦", "一滴", "一同", "一再", "一向", "一律", "一概", "一番", "一手", "一心", "一生",
        "一时", "一句", "一口", "一面", "一路", "一流", "一体", "一贯", "一阵", "一带", "一行", "一齐",
        "一对", "一模", "一举", "一言", "一针", "一丝", "一惊", "一开", "一见", "一趟", "一眼", "一杯",
        "一整", "一遍", "一刻", "一点点", "一点儿", "二手", "三心", "三思", "三番", "四处", "五道口",
        "七嘴", "八舌", "八字", "九泉", "十分", "十足", "十字", "百般", "千万", "千方", "万一", "万分",
        "万全", "两点一线",
        // Month names: the digit before 月 belongs to the month (三点五月份 is not 3.5).
        "一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "正月",
        // Words beginning with an ordinal unit character.
        "问题", "问责", "问世", "问候", "问好", "问答", "问卷", "问号", "问询", "问路", "问津", "问鼎",
        "问诊", "问讯", "问话", "问安", "问罪", "题目", "题型", "题材", "题库", "题干", "题量", "题海",
        "题解", "题词", "题名", "题字", "题记", "题外", "题意", "题注", "题头", "题眼",
        // Words ending with a degree adjective (so the adjective is not a standalone "a bit" cue).
        "最快", "很快", "尽快", "赶快", "加快", "飞快", "较快", "最慢", "很慢", "最早", "很早", "较早",
        "最晚", "很晚", "最多", "很多", "许多", "至多", "最少", "很少", "至少", "不少", "多少", "减少",
        "缺少", "最大", "很大", "较大", "大小", "最小", "很小", "较小", "最远", "很远", "最近", "很近",
        "附近", "接近", "最轻", "很轻", "减轻", "最重", "很重", "体重", "严重", "最好", "很好", "正好",
        "刚好", "只好", "还好", "友好", "不好", "爱好", "更好"
    ]
    static let maxLength = words.map(\.count).max() ?? 1

    func words(overlapping range: Range<Int>, in text: NumericText) -> [Range<Int>] {
        var result: [Range<Int>] = []
        let lower = max(0, range.lowerBound - Self.maxLength + 1)
        let upper = min(text.count, range.upperBound + Self.maxLength - 1)
        guard lower < upper else { return [] }
        for start in lower..<upper {
            for length in 2...Self.maxLength where start + length <= upper {
                let candidate = start..<(start + length)
                guard candidate.overlaps(range) else { continue }
                if Self.words.contains(text.slice(candidate)) { result.append(candidate) }
            }
        }
        return result
    }
}

/// System word segmentation (NaturalLanguage). Its output varies between macOS versions,
/// so it is only ever combined with the lexicon to add vetoes.
final class SystemChineseWordSegmenter: ChineseWordSegmenting {
    private var cachedText: String?
    private var cachedWords: [Range<Int>] = []

    func words(overlapping range: Range<Int>, in text: NumericText) -> [Range<Int>] {
        if cachedText != text.string {
            cachedText = text.string
            cachedWords = Self.segment(text)
        }
        return cachedWords.filter { $0.overlaps(range) }
    }

    private static func segment(_ text: NumericText) -> [Range<Int>] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text.string
        tokenizer.setLanguage(.simplifiedChinese)
        var result: [Range<Int>] = []
        tokenizer.enumerateTokens(in: text.string.startIndex..<text.string.endIndex) { range, _ in
            let lower = text.offset(of: range.lowerBound)
            let upper = text.offset(of: range.upperBound)
            if upper - lower > 1, !isQuantityToken(lower..<upper, text) { result.append(lower..<upper) }
            return true
        }
        return result
    }

    /// Numeral tokens with an optional unit (三分钟, 五点, 三时) are quantities, not lexical words,
    /// so they carry no word-boundary evidence.
    private static func isQuantityToken(_ range: Range<Int>, _ text: NumericText) -> Bool {
        var cursor = range.lowerBound
        while cursor < range.upperBound,
              CharClass.isChineseNumeral(text[cursor]) || CharClass.isASCIIDigit(text[cursor]) || text[cursor] == "点" {
            cursor += 1
        }
        guard cursor > range.lowerBound else { return false }
        if cursor == range.upperBound { return true }
        let tail = text.slice(cursor..<range.upperBound)
        return ChineseLexicon.measureWords.contains(tail) || ChineseLexicon.measurementUnits.contains(tail)
            || ["时", "分钟", "多", "几", "来", "余"].contains(tail)
    }
}

/// Lexicon words plus system words: more vetoes, never fewer.
struct CompositeChineseWordSegmenter: ChineseWordSegmenting {
    let lexicon = ChineseWordLexiconSegmenter()
    let system: SystemChineseWordSegmenter

    func words(overlapping range: Range<Int>, in text: NumericText) -> [Range<Int>] {
        lexicon.words(overlapping: range, in: text) + system.words(overlapping: range, in: text)
    }

    /// Exemptions that enable a conversion must not depend on the system segmenter.
    func lexiconIsInsideLongerWord(at offset: Int, in text: NumericText) -> Bool {
        lexicon.isInsideLongerWord(at: offset, in: text)
    }
}
