import Foundation

enum TranscriptionContextBuilder {
    private enum Budget {
        static let hotwords = 700
        static let total = 900
    }

    /// Fixed guidance matching the former default "natural" style preset.
    /// The user-facing style controls were removed (they were weak soft
    /// hints), but this baseline is kept so default transcription context —
    /// and therefore output behavior — stays identical.
    private static let baselineStyleGuidance =
        "Keep the text natural, clear, and conversational. Stay close to the spoken wording. Use conservative punctuation. Do not use exclamation marks. Remove obvious filler words only when they do not change meaning."

    static func context(for hotwords: [Hotword]) -> String {
        let hotwordContext = HotwordContextBuilder.context(for: hotwords, maxCharacters: Budget.hotwords)
        let separatorCost = hotwordContext.isEmpty ? 0 : 1
        let styleContext = truncated(
            baselineStyleGuidance,
            maxCharacters: Budget.total - hotwordContext.count - separatorCost
        )

        return [hotwordContext, styleContext]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func truncated(_ line: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0 else { return "" }
        guard line.count > maxCharacters else { return line }
        let endIndex = line.index(line.startIndex, offsetBy: maxCharacters)
        return String(line[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
