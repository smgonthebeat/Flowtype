import Foundation

/// A set of multi-word phrases matched longest-first on word tokens.
struct MathPhraseTable {
    private let byFirstWord: [String: [[String]]]

    init<S: Sequence>(_ phrases: S) where S.Element == String {
        var table: [String: [[String]]] = [:]
        for phrase in phrases {
            let words = phrase.split(separator: " ").map(String.init)
            guard let first = words.first else { continue }
            table[first, default: []].append(words)
        }
        byFirstWord = table.mapValues { $0.sorted { $0.count > $1.count } }
    }

    /// The longest phrase starting at `index` and its word count; `word` reads one token.
    func match(at index: Int, word: (Int) -> String?) -> (phrase: String, length: Int)? {
        guard let first = word(index), let candidates = byFirstWord[first] else { return nil }
        for words in candidates {
            var matches = true
            for offset in 1..<max(words.count, 1) where word(index + offset) != words[offset] {
                matches = false
                break
            }
            if matches { return (words.joined(separator: " "), words.count) }
        }
        return nil
    }
}
