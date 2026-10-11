import Foundation

enum AcademicReferenceNormalizer: TranscriptNormalizer {
    static let id = "academic_reference"

    static func normalize(_ text: String, context: NormalizationContext) -> String {
        AcademicReferenceGrammar.normalize(text, context: context)
    }
}
