import Foundation

enum FillerTokenKind {
    case hanRun
    case latinWord
    case number
    case identifier
    case whitespace
    case punctuation
    case other
}

enum FillerLanguage: Hashable {
    case chinese
    case english
}

enum FillerCandidateRole: Hashable {
    case canonicalFilledPause
    case contextualFilledPause
    case asrHesitationVariant
    case ambiguousEnglishHomograph
}

enum FillerCandidateShape: Hashable {
    case wholeToken
    case trailingHanEdge
    case leadingHanEdge
    case internalHan
}

enum FillerBoundaryAnchor: Hashable {
    case utteranceStart
    case utteranceEnd
    case commaSeparator
    case otherSoftSeparator
    case neutralFullStop
    case hesitationEllipsis
    case expressivePunctuation
    case priorClauseTerminator
    case quoteOrBracket
    case lexicalToken
    case lineBreak
}

struct FillerBoundaryEvidence: Hashable {
    let hasHorizontalWhitespace: Bool
    let anchor: FillerBoundaryAnchor
}

struct FillerToken {
    /// Lexical kind from the original input; protection must not erase this evidence.
    let kind: FillerTokenKind
    let text: Substring
    let range: Range<String.Index>
    let isProtected: Bool

    init(kind: FillerTokenKind, text: Substring, range: Range<String.Index>, isProtected: Bool = false) {
        self.kind = kind
        self.text = text
        self.range = range
        self.isProtected = isProtected
    }
}

enum FillerEvidence: Hashable {
    case exactWholeToken
    case closedTrailingHanEdge
    case leftBoundary(FillerBoundaryEvidence)
    case rightBoundary(FillerBoundaryEvidence)
    case repeatedHesitationForm
    case rightContinuation
    case sameClauseLeftContent
    case mixedBoundary
}

enum FillerVeto: Hashable {
    case protectedOverlap
    case unsupportedHanSubrange
    case embeddedInLatinToken
    case semanticInterjection
    case uppercaseOrIdentifierShape
    case numericOrMeasurementContext
    case quoteOrBracketBoundary
    case expressivePunctuation
    case noSupportedContinuation
    case insufficientBoundaryEvidence
}

struct FillerCandidate {
    let sourceRange: Range<String.Index>
    let canonicalForm: String
    let language: FillerLanguage
    let role: FillerCandidateRole
    let shape: FillerCandidateShape
    let evidence: Set<FillerEvidence>
    let vetoes: Set<FillerVeto>
}

struct FillerSequence {
    let sourceRange: Range<String.Index>
    let candidates: [FillerCandidate]
    let leftBoundary: FillerBoundaryEvidence
    let rightBoundary: FillerBoundaryEvidence
}

struct FillerEdit {
    let sourceRange: Range<String.Index>
    let replacement: String
    let sequence: FillerSequence
}

struct FillerCleanupResult {
    let text: String
    let events: [PostProcessingEvent]
}
