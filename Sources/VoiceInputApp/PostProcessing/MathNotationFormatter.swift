import Foundation

struct MathNotationFormattingResult: Equatable {
    let text: String
    let events: [PostProcessingEvent]
}

/// Thin entry point kept for existing call sites: the math layer is MathStage
/// (lexer -> span parser -> evidence -> dual renderer, design.md 2). No sentinels are added here.
enum MathNotationFormatter {
    static func format(_ text: String, outputFormat: MathNotationOutputFormat) -> String {
        formatWithEvents(text, outputFormat: outputFormat).text
    }

    /// `protectSpelledNames` is accepted for source compatibility; letter runs are now decided per
    /// span by the evidence rules (design.md 6), so it has no effect.
    static func formatWithEvents(
        _ text: String,
        outputFormat: MathNotationOutputFormat,
        knownTerms: [String] = [],
        protectSpelledNames: Bool = false
    ) -> MathNotationFormattingResult {
        let result = MathStage.run(text, outputFormat: outputFormat, knownTerms: knownTerms)
        return MathNotationFormattingResult(text: result.text, events: result.events)
    }
}
