import Foundation

enum SmartNumericFormatter {
    static func format(_ text: String, knownTerms: [String] = []) -> String {
        NormalizationPipeline.normalize(text, knownTerms: knownTerms)
    }
}
