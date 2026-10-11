import Foundation

/// Evidence that `left.Right` (no space) is two sentences rather than one dotted name.
/// A missed space is cosmetic; a split name (ASP.NET, Node.JS, Program.Main) is corruption.
enum SentenceBoundary {
    /// `left` is the ASCII alphanumeric run before the period, `right` the letter run after it.
    static func isBoundary(left: Substring, right: Substring) -> Bool {
        guard let rightFirst = right.first, CharClass.isASCIIUppercase(rightFirst), !left.isEmpty else {
            return false
        }
        // Right token all-caps (two or more letters) or with an internal capital: identifier-like.
        let rightLetters = right.filter(CharClass.isASCIILetter)
        if rightLetters.count >= 2, rightLetters.allSatisfy(CharClass.isASCIIUppercase) { return false }
        if right.dropFirst().contains(where: CharClass.isASCIIUppercase) { return false }
        // Left token starting with or containing a capital: name-like (Program.Main, README.MD).
        if left.contains(where: CharClass.isASCIIUppercase) { return false }
        return true
    }

    /// Checks the period at `offset` in `text` (character offsets).
    static func isBoundary(at offset: Int, in text: NumericText) -> Bool {
        guard text.at(offset) == "." else { return false }
        // The left token is the whole dotted compound (Foundation.framework), not just its last part.
        var start = offset
        while start > 0, CharClass.isASCIILetter(text[start - 1]) || CharClass.isASCIIDigit(text[start - 1])
                || text[start - 1] == "." && start - 1 > 0 && CharClass.isASCIILetter(text[start - 2]) { start -= 1 }
        var end = offset + 1
        while end < text.count, CharClass.isASCIILetter(text[end]) { end += 1 }
        guard start < offset, end > offset + 1 else { return false }
        let chars = text.chars
        return isBoundary(left: Substring(String(chars[start..<offset])), right: Substring(String(chars[(offset + 1)..<end])))
    }
}
