import Foundation

enum HotwordContextBuilder {
    static func context(for hotwords: [Hotword], maxCharacters: Int = 700) -> String {
        terms(for: hotwords, maxCharacters: maxCharacters).joined(separator: " ")
    }

    static func terms(for hotwords: [Hotword], maxCharacters: Int = 700) -> [String] {
        let terms = hotwords
            .filter(\.isEnabled)
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var accepted: [String] = []
        for term in terms {
            let candidateTerms = accepted + [term]
            let candidate = candidateTerms.joined(separator: " ")
            if candidate.count <= maxCharacters {
                accepted.append(term)
            }
        }
        return accepted
    }
}
