import Foundation

enum HotwordContextBuilder {
    private static let prefix = "Important terms to preserve exactly: "

    static func context(for hotwords: [Hotword], maxCharacters: Int = 700) -> String {
        let terms = hotwords
            .filter(\.isEnabled)
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !terms.isEmpty else { return "" }

        var accepted: [String] = []
        for term in terms {
            let candidateTerms = accepted + [term]
            let candidate = prefix + candidateTerms.joined(separator: ", ") + "."
            if candidate.count <= maxCharacters {
                accepted.append(term)
            } else {
                continue
            }
        }

        guard !accepted.isEmpty else { return "" }
        return prefix + accepted.joined(separator: ", ") + "."
    }
}
