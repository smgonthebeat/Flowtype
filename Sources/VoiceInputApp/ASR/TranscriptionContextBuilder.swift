import Foundation

struct QwenPromptContext: Equatable {
    let payload: String
    let knownTerms: [String]
    let internalOnlySegments: [String]

    init(
        payload: String,
        knownTerms: [String] = [],
        internalOnlySegments: [String] = []
    ) {
        self.payload = payload
        self.knownTerms = knownTerms

        var classifiedInternalSegments = internalOnlySegments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let vocabularyPayload = knownTerms.joined(separator: " ")
        if !trimmedPayload.isEmpty,
           trimmedPayload != vocabularyPayload,
           !classifiedInternalSegments.contains(trimmedPayload) {
            classifiedInternalSegments.append(trimmedPayload)
        }
        self.internalOnlySegments = classifiedInternalSegments
    }

    static let empty = QwenPromptContext(payload: "")
}

enum TranscriptionContextBuilder {
    private enum Budget {
        static let hotwords = 700
    }

    static func context(for hotwords: [Hotword]) -> QwenPromptContext {
        let terms = HotwordContextBuilder.terms(for: hotwords, maxCharacters: Budget.hotwords)
        guard !terms.isEmpty else { return .empty }
        return QwenPromptContext(
            payload: terms.joined(separator: " "),
            knownTerms: terms
        )
    }
}
