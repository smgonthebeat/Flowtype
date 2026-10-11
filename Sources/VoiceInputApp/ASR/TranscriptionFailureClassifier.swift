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

    /// A recording at least this long almost certainly holds speech worth keeping.
    static let minimumRetainedFailureDuration: TimeInterval = 2

    static func recoverableHomeRowCategory(
        for error: Error,
        selectedEngine: TranscriptionEngineKind,
        recordingDuration: TimeInterval? = nil
    ) -> TranscriptFailureCategory? {
        let candidateError = (error as? TranscriptionFallbackFailure)?.primaryError ?? error
        let category = category(for: candidateError)
        if canCreateRecoverableHomeRow(category: category, selectedEngine: selectedEngine) {
            return category
        }
        // 2026-10-08: the helper answered a two-minute dictation with HTTP 400 "No usable speech"
        // because its own splitter produced an empty piece, and the recording was discarded as
        // silence. An error raised by the helper is a model failure, not a heard-nothing result
        // (that arrives as TranscriptionError.emptyResult), so a recording long enough to hold
        // speech is kept for retry.
        if selectedEngine == .qwenLocal,
           category == .noSpeechDetected,
           candidateError is QwenHelperClientError,
           let recordingDuration,
           recordingDuration >= minimumRetainedFailureDuration {
            return .transcriptionFailed
        }
        return nil
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
