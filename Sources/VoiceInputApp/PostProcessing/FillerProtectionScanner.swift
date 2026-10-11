import Foundation

/// Filler-local guards. All ranges refer to the unchanged stage input.
struct FillerProtectionMask {
    let ranges: [Range<String.Index>]

    init(_ ranges: [Range<String.Index>]) {
        var merged: [Range<String.Index>] = []
        for range in ranges.filter({ !$0.isEmpty }).sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        self.ranges = merged
    }

    func overlaps(_ range: Range<String.Index>) -> Bool {
        guard !range.isEmpty else { return false }
        var low = 0
        var high = ranges.count
        while low < high {
            let mid = (low + high) / 2
            if ranges[mid].upperBound <= range.lowerBound { low = mid + 1 } else { high = mid }
        }
        return low < ranges.count && ranges[low].lowerBound < range.upperBound
    }
}

enum FillerProtectionScanner {
    private static let delimiter = try! NSRegularExpression(pattern: "[`\"'“‘「『《]")
    private static let lexical = try! NSRegularExpression(pattern: "呃逆|嗯哼|嗯嗯")
    private static let anyCue = try! NSRegularExpression(pattern: "读作|写作|念作|读成|写成|字是|词是|说了|发出|回答了|答了|这个字|这个词|这两个字|这个读音|的读音|的写法|字怎么写|怎么读|怎么写|了一声")
    private static let leftCues = ["读作", "写作", "念作", "读成", "写成", "字是", "词是", "说了", "发出", "发出了", "回答了", "答了"]
    private static let rightCues = ["这个字", "这个词", "这两个字", "这个读音", "的读音", "的写法", "字怎么写", "怎么读", "怎么写", "了一声"]

    static func staticRanges(in source: String) -> FillerProtectionMask {
        let full = NSRange(source.startIndex..<source.endIndex, in: source)
        var ranges = delimiter.firstMatch(in: source, range: full) == nil ? [] : quoteAndCodeRanges(in: source)
        for match in lexical.matches(in: source, range: full) {
            if let range = Range(match.range, in: source) { ranges.append(range) }
        }
        return FillerProtectionMask(ranges)
    }

    private static func quoteAndCodeRanges(in source: String) -> [Range<String.Index>] {
        let indices = Array(source.indices) + [source.endIndex]
        let chars = Array(source)
        var ranges = CodeSpanDetector.ranges(in: source)
        var code = [Bool](repeating: false, count: chars.count)
        var rangeIndex = 0
        for offset in chars.indices {
            while rangeIndex < ranges.count, ranges[rangeIndex].upperBound <= indices[offset] { rangeIndex += 1 }
            code[offset] = rangeIndex < ranges.count && ranges[rangeIndex].contains(indices[offset])
        }

        let pairs: [Character: Character] = ["“": "”", "‘": "’", "「": "」", "『": "』", "《": "》", "\"": "\"", "'": "'"]
        var stack: [(start: Int, close: Character)] = []
        var backslashes = 0
        for offset in chars.indices {
            let char = chars[offset]
            let escaped = backslashes % 2 == 1
            backslashes = char == "\\" ? backslashes + 1 : 0
            guard !code[offset] else { continue }
            if char == "\"" || char == "'" {
                if escaped { continue }
                if char == "'", offset > 0, offset + 1 < chars.count,
                   asciiAlphanumeric(chars[offset - 1]), asciiAlphanumeric(chars[offset + 1]) { continue }
            }
            if stack.last?.close == char {
                let open = stack.removeLast()
                // Only outer ranges are needed; this also keeps nested scans linear.
                if stack.isEmpty { ranges.append(indices[open.start]..<indices[offset + 1]) }
            } else if let close = pairs[char] {
                stack.append((offset, close))
            }
        }
        if let open = stack.first { ranges.append(indices[open.start]..<source.endIndex) }
        return ranges
    }

    static func cueRanges(in source: String, candidates: [FillerCandidate]) -> [Range<String.Index>] {
        guard anyCue.firstMatch(in: source, range: NSRange(source.startIndex..<source.endIndex, in: source)) != nil else { return [] }
        return candidates.compactMap { candidate in
            let range = candidate.sourceRange
            var leftEnd = range.lowerBound
            while leftEnd > source.startIndex {
                let previous = source.index(before: leftEnd)
                guard horizontal(source[previous]) else { break }
                leftEnd = previous
            }
            let leftStart = source.index(leftEnd, offsetBy: -3, limitedBy: source.startIndex) ?? source.startIndex
            let left = source[leftStart..<leftEnd]
            if leftCues.contains(where: { left.hasSuffix($0) }) { return range }
            var rightStart = range.upperBound
            func skipGap() {
                while rightStart < source.endIndex, horizontal(source[rightStart]) {
                    rightStart = source.index(after: rightStart)
                }
            }
            skipGap()
            if rightStart < source.endIndex, source[rightStart] == "," || source[rightStart] == "，" {
                rightStart = source.index(after: rightStart)
                skipGap()
            }
            let rightEnd = source.index(rightStart, offsetBy: 4, limitedBy: source.endIndex) ?? source.endIndex
            let right = source[rightStart..<rightEnd]
            return rightCues.contains(where: { right.hasPrefix($0) }) ? range : nil
        }
    }

    private static func horizontal(_ char: Character) -> Bool { char == " " || char == "\t" }
    private static func asciiAlphanumeric(_ char: Character) -> Bool {
        char.isASCII && (char.isLetter || char.isNumber)
    }
}
