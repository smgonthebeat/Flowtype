import Foundation

struct TranscriptionFallbackFailure: LocalizedError {
    let primaryError: Error
    let fallbackError: Error

    var errorDescription: String? {
        (fallbackError as? LocalizedError)?.errorDescription ?? fallbackError.localizedDescription
    }
}

enum TranscriptionFailureClassifier {
    static func category(for error: Error) -> TranscriptFailureCategory {
        if let fallbackFailure = error as? TranscriptionFallbackFailure {
            return category(for: fallbackFailure.fallbackError)
        }

        if let transcriptionError = error as? TranscriptionError,
           transcriptionError == .emptyResult {
            return .noSpeechDetected
        }

        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let normalized = message.lowercased()
        if normalized.contains("no usable speech") || normalized.contains("empty audio") {
            return .noSpeechDetected
        }
        if normalized.contains("audio resampling") || normalized.contains("ffmpeg") {
            return .audioSetupError
        }
        return .transcriptionFailed
    }

    static func canCreateRecoverableHomeRow(
        category: TranscriptFailureCategory,
        selectedEngine: TranscriptionEngineKind
    ) -> Bool {
        selectedEngine == .qwenLocal && category == .transcriptionFailed
    }

    static func recoverableHomeRowCategory(
        for error: Error,
        selectedEngine: TranscriptionEngineKind
    ) -> TranscriptFailureCategory? {
        let candidateError = (error as? TranscriptionFallbackFailure)?.primaryError ?? error
        let category = category(for: candidateError)
        guard canCreateRecoverableHomeRow(category: category, selectedEngine: selectedEngine) else {
            return nil
        }
        return category
    }

    static func capsuleText(for category: TranscriptFailureCategory) -> String {
        switch category {
        case .noSpeechDetected:
            "No speech detected"
        case .audioSetupError:
            "Audio setup error"
        case .recordingUnavailable:
            "Recording unavailable"
        case .expiredRecording:
            "Recording expired"
        case .transcriptionFailed:
            "Transcription failed"
        }
    }
}
