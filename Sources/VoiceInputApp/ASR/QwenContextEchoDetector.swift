import AVFoundation
import Foundation

enum QwenKnownTermEchoPolicy {
    case all
    case listOnly
    case none
}

enum QwenContextEchoDetector {
    private static let minimumPartialInternalFragmentCharacters = 18
    private static let minimumPartialInternalFragmentTokens = 4

    /// Prompts previously shipped by Flowtype must remain blocked even after
    /// they stop being sent. This is a versioned deny catalog consumed by the
    /// generic matcher, not phrase-specific output rewriting.
    static let retiredInternalSegments = [
        "Important terms to preserve exactly:",
        "Transcribe faithfully. Preserve the user's wording and mixed Chinese-English content.",
        "Keep the text natural, clear, and conversational. Stay close to the spoken wording. Use conservative punctuation. Do not use exclamation marks. Remove obvious filler words only when they do not change meaning.",
        "Use clear written punctuation and a calm formal tone. Avoid excessive exclamation marks. Do not add new content.",
        "Use clear written punctuation and a calm formal tone. Use conservative punctuation. Do not use exclamation marks. Do not add new content.",
        "Follow the user's style guidance while preserving meaning and mixed Chinese-English terms.",
        "User style guidance:"
    ]

    static func isLikelyEcho(
        _ text: String,
        context: QwenPromptContext,
        recordingDuration _: TimeInterval,
        knownTermPolicy: QwenKnownTermEchoPolicy = .all
    ) -> Bool {
        if containsInternalContextEcho(text, context: context) {
            return true
        }

        guard knownTermPolicy != .none else { return false }

        let normalizedText = normalized(text)
        let normalizedPayload = normalized(context.payload)
        let terms = normalizedKnownTerms(context.knownTerms)
        let minimumPolicyTermCount = knownTermPolicy == .listOnly ? 3 : 1
        guard terms.count >= minimumPolicyTermCount else { return false }

        if !normalizedPayload.isEmpty, normalizedText == normalizedPayload {
            return true
        }

        guard terms.count >= 2 else { return false }

        let minimumOrderedRun = knownTermPolicy == .listOnly ? 3 : 2
        if terms.count >= minimumOrderedRun,
           containsOrderedKnownTermRun(
               terms,
               minimumRunLength: minimumOrderedRun,
               in: normalizedText
           ) {
            return true
        }

        let matchedTerms = terms.filter { term in
            containsNormalizedPhrase(term, in: normalizedText)
        }

        if matchedTerms.count == terms.count {
            return true
        }

        guard terms.count >= 3 else { return false }
        let minimumMatches = terms.count <= 4
            ? Int(ceil(Double(terms.count) * 2.0 / 3.0))
            : 3
        return matchedTerms.count >= minimumMatches
            && knownTermCoverage(matchedTerms, in: normalizedText) >= 0.45
    }

    static func containsInternalContextEchoTail(
        _ text: String,
        context: QwenPromptContext
    ) -> Bool {
        containsInternalContextEcho(text, context: context, requireNonInitialMatch: true)
    }

    static func containsInternalContextEcho(
        _ text: String,
        context: QwenPromptContext
    ) -> Bool {
        containsInternalContextEcho(text, context: context, requireNonInitialMatch: false)
    }

    static func recordingDuration(fileURL: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: fileURL) else { return nil }
        let sampleRate = file.fileFormat.sampleRate
        guard sampleRate > 0 else { return nil }
        return Double(file.length) / sampleRate
    }

    private static func containsInternalContextEcho(
        _ text: String,
        context: QwenPromptContext,
        requireNonInitialMatch: Bool
    ) -> Bool {
        let normalizedOutput = normalized(text)
        let outputTokens = normalizedTokens(text)
        guard !outputTokens.isEmpty else { return false }

        return internalSegmentFragments(context: context).contains { fragment in
            let normalizedInternalFragment = normalized(fragment)
            let internalTokens = normalizedTokens(fragment)
            guard !internalTokens.isEmpty else { return false }

            if containsCompleteInternalFragment(
                internalTokens,
                in: outputTokens,
                requireNonInitialMatch: requireNonInitialMatch
            ) {
                return true
            }

            if containsPartialInternalFragment(
                internalTokens,
                in: outputTokens,
                requireNonInitialMatch: requireNonInitialMatch
            ) {
                return true
            }

            return containsPartialInternalCharacterFragment(
                normalizedInternalFragment,
                in: normalizedOutput,
                requireNonInitialMatch: requireNonInitialMatch
            )
        }
    }

    private static func normalized(_ text: String) -> String {
        let folded = text
            .precomposedStringWithCompatibilityMapping
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
        var characters: [Character] = []
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                characters.append(Character(scalar))
                continue
            }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                characters.append(" ")
                continue
            }
            switch scalar.properties.generalCategory {
            case .control, .format, .nonspacingMark, .spacingMark, .enclosingMark:
                continue
            case .currencySymbol, .mathSymbol, .modifierSymbol, .otherSymbol:
                characters.append(Character(scalar))
            default:
                characters.append(" ")
            }
        }
        return String(characters)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedTokens(_ text: String) -> [String] {
        normalized(text).split(separator: " ").map(String.init)
    }

    private static func normalizedKnownTerms(_ terms: [String]) -> [String] {
        var seen = Set<String>()
        return terms.compactMap { term in
            let normalizedTerm = normalized(term)
            guard !normalizedTerm.isEmpty, seen.insert(normalizedTerm).inserted else {
                return nil
            }
            return normalizedTerm
        }
    }

    private static func containsNormalizedPhrase(_ needle: String, in haystack: String) -> Bool {
        guard !needle.isEmpty, !haystack.isEmpty else { return false }
        return " \(haystack) ".contains(" \(needle) ")
    }

    private static func containsOrderedKnownTermRun(
        _ terms: [String],
        minimumRunLength: Int,
        in normalizedText: String
    ) -> Bool {
        guard minimumRunLength > 0, terms.count >= minimumRunLength else { return false }
        for start in 0...(terms.count - minimumRunLength) {
            let run = terms[start..<(start + minimumRunLength)].joined(separator: " ")
            if containsNormalizedPhrase(run, in: normalizedText) {
                return true
            }
        }
        return false
    }

    private static func knownTermCoverage(_ terms: [String], in normalizedText: String) -> Double {
        guard !normalizedText.isEmpty else { return 0 }
        let matchedLength = terms.reduce(0) { $0 + $1.count }
        return Double(matchedLength) / Double(normalizedText.count)
    }

    private static func containsCompleteInternalFragment(
        _ internalTokens: [String],
        in outputTokens: [String],
        requireNonInitialMatch: Bool
    ) -> Bool {
        guard internalTokens.count <= outputTokens.count else { return false }
        let lastStart = outputTokens.count - internalTokens.count
        for start in 0...lastStart {
            if requireNonInitialMatch, start == 0 {
                continue
            }
            let end = start + internalTokens.count
            if Array(outputTokens[start..<end]) == internalTokens {
                return true
            }
        }
        return false
    }

    private static func containsPartialInternalFragment(
        _ internalTokens: [String],
        in outputTokens: [String],
        requireNonInitialMatch: Bool
    ) -> Bool {
        for outputStart in outputTokens.indices {
            if requireNonInitialMatch, outputStart == outputTokens.startIndex {
                continue
            }
            for internalStart in internalTokens.indices {
                var matchedCount = 0
                while outputStart + matchedCount < outputTokens.count,
                      internalStart + matchedCount < internalTokens.count,
                      outputTokens[outputStart + matchedCount] == internalTokens[internalStart + matchedCount] {
                    matchedCount += 1
                }

                guard matchedCount >= minimumPartialInternalFragmentTokens else { continue }
                let touchesOutputBoundary = outputStart == outputTokens.startIndex
                    || outputStart + matchedCount == outputTokens.count
                guard touchesOutputBoundary else { continue }
                let evidence = outputTokens[outputStart..<(outputStart + matchedCount)].joined(separator: " ")
                if evidence.count >= minimumPartialInternalFragmentCharacters {
                    return true
                }
            }
        }
        return false
    }

    /// Token matching cannot see a truncated CJK instruction because an
    /// entire unspaced sentence is one token. Match sufficiently long exact
    /// character runs at an output boundary as a second, script-independent
    /// signal. Requiring an output boundary avoids rewriting ordinary prose
    /// that merely quotes a short phrase in the middle of a transcript.
    private static func containsPartialInternalCharacterFragment(
        _ internalFragment: String,
        in output: String,
        requireNonInitialMatch: Bool
    ) -> Bool {
        let internalCharacters = Array(internalFragment)
        let outputCharacters = Array(output)
        guard internalCharacters.count >= minimumPartialInternalFragmentCharacters,
              outputCharacters.count >= minimumPartialInternalFragmentCharacters else {
            return false
        }

        for outputStart in outputCharacters.indices {
            if requireNonInitialMatch, outputStart == outputCharacters.startIndex {
                continue
            }
            for internalStart in internalCharacters.indices {
                var matchedCount = 0
                while outputStart + matchedCount < outputCharacters.count,
                      internalStart + matchedCount < internalCharacters.count,
                      outputCharacters[outputStart + matchedCount] == internalCharacters[internalStart + matchedCount] {
                    matchedCount += 1
                }

                guard matchedCount >= minimumPartialInternalFragmentCharacters else { continue }
                let touchesOutputBoundary = outputStart == outputCharacters.startIndex
                    || outputStart + matchedCount == outputCharacters.count
                if touchesOutputBoundary {
                    return true
                }
            }
        }
        return false
    }

    private static func internalSegments(context: QwenPromptContext) -> [String] {
        (context.internalOnlySegments + retiredInternalSegments)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func internalSegmentFragments(context: QwenPromptContext) -> [String] {
        internalSegments(context: context).flatMap { segment in
            [segment] + sentenceFragments(in: segment)
        }
    }

    private static func sentenceFragments(in segment: String) -> [String] {
        var fragments: [String] = []
        var current = ""
        let terminators = CharacterSet(charactersIn: ".!?。！？\n")

        for scalar in segment.unicodeScalars {
            current.unicodeScalars.append(scalar)
            if terminators.contains(scalar) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    fragments.append(trimmed)
                }
                current = ""
            }
        }
        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            fragments.append(trailing)
        }
        return fragments
    }
}

enum SensitiveTranscriptCommitGuard {
    static func validate(_ text: String, context: QwenPromptContext) throws {
        if QwenContextEchoDetector.isLikelyEcho(
            text,
            context: context,
            recordingDuration: 0,
            knownTermPolicy: .listOnly
        ) {
            throw TranscriptionError.contextLeakDetected
        }
    }
}
