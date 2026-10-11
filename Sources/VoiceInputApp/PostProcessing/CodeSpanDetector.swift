import Foundation

/// Shared backtick-run syntax. An unclosed run protects the remaining input.
enum CodeSpanDetector {
    static func ranges(in text: String) -> [Range<String.Index>] {
        guard text.contains("`") else { return [] }
        var result: [Range<String.Index>] = []
        var cursor = text.startIndex
        var opening: String.Index?
        var delimiterLength = 0
        while cursor < text.endIndex {
            guard text[cursor] == "`" else { cursor = text.index(after: cursor); continue }
            let start = cursor
            var count = 0
            while cursor < text.endIndex, text[cursor] == "`" {
                cursor = text.index(after: cursor); count += 1
            }
            if let open = opening {
                if count == delimiterLength { result.append(open..<cursor); opening = nil }
            } else { opening = start; delimiterLength = count }
        }
        if let open = opening { result.append(open..<text.endIndex) }
        return result
    }

    static func overlaps(_ candidate: Range<String.Index>, ranges: [Range<String.Index>]) -> Bool {
        var low = 0
        var high = ranges.count
        while low < high {
            let mid = (low + high) / 2
            if ranges[mid].upperBound <= candidate.lowerBound { low = mid + 1 } else { high = mid }
        }
        return low < ranges.count && ranges[low].lowerBound < candidate.upperBound
    }

    static func transformUnprotected(in text: String, using transform: (String) -> String) -> String {
        let protected = ranges(in: text)
        guard !protected.isEmpty else { return transform(text) }
        var result = ""
        var cursor = text.startIndex
        for range in protected {
            if cursor < range.lowerBound { result += transform(String(text[cursor..<range.lowerBound])) }
            result += text[range]
            cursor = range.upperBound
        }
        if cursor < text.endIndex { result += transform(String(text[cursor...])) }
        return result
    }

    static func trimOutsideCode(_ text: String) -> String {
        var lower = text.startIndex
        while lower < text.endIndex, text[lower].isWhitespace { lower = text.index(after: lower) }
        var upper = text.endIndex
        let lastCode = ranges(in: text).last
        while upper > lower {
            let previous = text.index(before: upper)
            guard text[previous].isWhitespace, lastCode?.contains(previous) != true else { break }
            upper = previous
        }
        return String(text[lower..<upper])
    }
}
