import Foundation

/// One lexical unit of a transcript as the math layer sees it (design.md 3).
struct MathToken {
    enum Kind: Equatable {
        /// An ASCII word that may be spoken math.
        case word
        /// Ordinary text: compounds (x-ray), glued alphanumerics (STAT0002), existing notation (f(x), 5%).
        case prose
        /// ASCII digits ("12", "0.05").
        case number
        /// A Chinese numeral ("三十二", "零点五").
        case zhNumber
        /// A Chinese math word from the lexicon (longest match).
        case zh
        /// Other Han text.
        case hanProse
        case punctuation
        /// A notation character: = + / ( ) and every non-ASCII math character.
        case symbol
        /// A protected span (code, URL, e-mail, path, hotword, $...$): copied verbatim.
        case barrier
    }

    var kind: Kind
    let text: String
    let lower: String
    /// Character offsets into the lexed text.
    let start: Int
    let end: Int
    /// Numeric value of number and Chinese numeral tokens.
    var value: String?
    var sentence = 0
    /// First word of its sentence (D5: a sentence-initial single letter is lower case).
    var isSentenceInitial = false
    /// Belongs to a label such as "part B" or "Q three" (design.md 3 rule 6).
    var isClaimedByLabel = false

    init(_ kind: Kind, _ text: String, start: Int, end: Int, value: String? = nil) {
        self.kind = kind
        self.text = text
        self.lower = text.lowercased()
        self.start = start
        self.end = end
        self.value = value
    }

    var isWord: Bool { kind == .word }
    var isSingleLetter: Bool { kind == .word && text.count == 1 }
}

/// The lexed transcript: characters, their String indices, and the tokens.
struct MathTokenStream {
    let characters: [Character]
    /// `indices[k]` is the String.Index of character k; the last element is endIndex.
    let indices: [String.Index]
    var tokens: [MathToken]

    func range(from start: Int, to end: Int) -> Range<String.Index> { indices[start]..<indices[end] }

    func text(from start: Int, to end: Int) -> String { String(characters[start..<end]) }
}
