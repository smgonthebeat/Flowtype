import Foundation

struct NormalizationContext {
    let knownTerms: [String]
    let protectedSpans: [ProtectedSpan]

    init(knownTerms: [String] = [], protectedSpans: [ProtectedSpan] = []) {
        self.knownTerms = knownTerms
        self.protectedSpans = protectedSpans
    }
}

struct ProtectedSpan: Equatable {
    let range: Range<String.Index>
    let kind: ProtectedSpanKind
    let text: String
}

enum ProtectedSpanKind: String, Equatable {
    case url
    case email
    case filePath
    case command
    case modelID
    case version
    case courseCode
    case academicReference
}

struct NormalizationChange: Equatable {
    let ruleID: String
    let source: String
    let output: String
}

protocol TranscriptNormalizer {
    static var id: String { get }
    static func normalize(_ text: String, context: NormalizationContext) -> String
}
