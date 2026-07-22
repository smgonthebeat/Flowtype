import AVFoundation
import Foundation

enum QwenContextEchoDetector {
    private static let hotwordPromptPrefix = "Important terms to preserve exactly:"
    private static let shortRecordingThreshold: TimeInterval = 4
    private static let minimumTranscriptCharacters = 40

    static func isLikelyEcho(
        _ text: String,
        context: String,
        recordingDuration: TimeInterval
    ) -> Bool {
        guard !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        if startsWithHotwordPrompt(text) {
            return true
        }

        guard text.count >= minimumTranscriptCharacters else { return false }

        let terms = contextTerms(from: context)
        guard terms.count >= 4 else { return false }

        let normalizedText = normalized(text)
        let matchedTerms = terms.filter { term in
            normalizedText.contains(normalized(term))
        }

        let minimumMatches = min(6, max(4, terms.count / 4))
        if recordingDuration <= shortRecordingThreshold {
            return matchedTerms.count >= minimumMatches
        }

        let longRecordingMinimumMatches = min(terms.count, max(6, Int(ceil(Double(terms.count) * 0.5))))
        return matchedTerms.count >= longRecordingMinimumMatches
            && contextTermCoverage(matchedTerms, in: normalizedText) >= 0.55
    }

    static func transcriptByRemovingContextEchoTail(_ text: String, context: String) -> String? {
        guard !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let range = text.range(
                of: hotwordPromptPrefix,
                options: [.caseInsensitive, .diacriticInsensitive]
              ),
              range.lowerBound > text.startIndex else {
            return nil
        }

        let cleaned = text[..<range.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : String(cleaned)
    }

    static func recordingDuration(fileURL: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: fileURL) else { return nil }
        let sampleRate = file.fileFormat.sampleRate
        guard sampleRate > 0 else { return nil }
        return Double(file.length) / sampleRate
    }

    private static func contextTerms(from context: String) -> [String] {
        let hotwordLine = context
            .components(separatedBy: .newlines)
            .first { $0.localizedCaseInsensitiveContains(hotwordPromptPrefix) }

        guard let hotwordLine,
              let separatorRange = hotwordLine.range(of: ":") else {
            return []
        }

        return hotwordLine[separatorRange.upperBound...]
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            }
            .filter { $0.count >= 2 }
    }

    private static func normalized(_ text: String) -> String {
        let scalars = text.lowercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func startsWithHotwordPrompt(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
            .range(of: hotwordPromptPrefix, options: [.caseInsensitive, .diacriticInsensitive])?
            .lowerBound == trimmed.startIndex
    }

    private static func contextTermCoverage(_ terms: [String], in normalizedText: String) -> Double {
        guard !normalizedText.isEmpty else { return 0 }
        let matchedLength = terms.reduce(0) { total, term in
            let normalizedTerm = normalized(term)
            guard !normalizedTerm.isEmpty else { return total }
            return total + normalizedTerm.count
        }
        return Double(min(matchedLength, normalizedText.count)) / Double(normalizedText.count)
    }
}
