import Foundation

enum NormalizationPipeline {
    static func normalize(_ text: String, knownTerms: [String] = []) -> String {
        var normalized = text
        var context = NormalizationContext(
            knownTerms: knownTerms,
            protectedSpans: ProtectedSpanDetector.detect(in: normalized)
        )

        normalized = AcademicReferenceNormalizer.normalize(normalized, context: context)
        context = NormalizationContext(
            knownTerms: knownTerms,
            protectedSpans: ProtectedSpanDetector.detect(in: normalized)
        )
        normalized = SemioticNumberNormalizer.normalize(normalized, context: context)
        context = NormalizationContext(
            knownTerms: knownTerms,
            protectedSpans: ProtectedSpanDetector.detect(in: normalized)
        )
        normalized = EnglishNumberNormalizer.normalize(normalized, context: context)
        return normalized
    }
}
