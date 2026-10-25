import Foundation

struct NumericNormalizationResult {
    let text: String
    let events: [PostProcessingEvent]
    /// Caller-supplied protected spans moved through the applied edits.
    let protectedSpans: [ProtectedSpan]
}

/// Entry point of the evidence-based numeric layer:
/// shared protection -> construct recognisers (proposals / abstentions) -> one arbiter pass.
enum NumericNormalizer {
    /// Test seam: a deterministic segmenter replaces the system one when set.
    static var segmenterOverride: ChineseWordSegmenting?

    static func normalize(
        _ text: String,
        knownTerms: [String] = [],
        protectedSpans: [ProtectedSpan] = []
    ) -> NumericNormalizationResult {
        guard !text.isEmpty else { return NumericNormalizationResult(text: text, events: [], protectedSpans: protectedSpans) }
        let numericText = NumericText(text)
        let protectedRanges = (SharedProtection.ranges(in: text, knownTerms: knownTerms)
            + MathProtectedSegmenter.syntaxProtectedRanges(in: text)
            + protectedSpans.filter { $0.kind != .numericCandidate }.map(\.range))
            .map { numericText.range(of: $0) }
        let segmenter = segmenterOverride
            ?? CompositeChineseWordSegmenter(system: SystemChineseWordSegmenter())
        let context = NumericContext(text: numericText, protected: protectedRanges, segmenter: segmenter)

        var decisions = ChineseNumericRecognizers.recognize(context)
        decisions.merge(EnglishNumericRecognizer.recognize(context))
        // An identifier's number is decided once, by the designator rule (S one -> S 1).
        let designators = DesignatorRecognizer.recognize(context)
        decisions.removeOverlapping(designators.proposals.map(\.range))
        decisions.merge(designators)
        let result = NumericArbiter.resolve(numericText, decisions: decisions, protected: protectedRanges)

        let output = NumericText(result.text)
        let remapped = protectedSpans.compactMap { span -> ProtectedSpan? in
            let original = numericText.range(of: span.range)
            let lower = result.mappedOffset(original.lowerBound)
            let upper = result.mappedOffset(original.upperBound)
            guard lower <= upper, upper <= output.count else { return nil }
            let range = output.index(lower)..<output.index(upper)
            return ProtectedSpan(range: range, kind: span.kind, text: String(result.text[range]))
        }
        return NumericNormalizationResult(text: result.text, events: result.events, protectedSpans: remapped)
    }
}
