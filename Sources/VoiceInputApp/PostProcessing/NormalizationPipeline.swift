import Foundation

/// Stable entry point of smart numeric formatting. See `NumericNormalizer`.
enum NormalizationPipeline {
    static func normalize(_ text: String, knownTerms: [String] = []) -> String {
        NumericNormalizer.normalize(text, knownTerms: knownTerms).text
    }

    static func normalizeWithEvents(_ text: String, knownTerms: [String] = []) -> NumericNormalizationResult {
        NumericNormalizer.normalize(text, knownTerms: knownTerms)
    }
}
