import Foundation

final class QwenTranscriptionEngine: TranscriptionEngine {
    // Keep ordinary long dictation in full mode through this duration; only longer recordings are chunked.
    private static let longDictationFullThreshold: TimeInterval = 60

    private let client: QwenTranscriptionClient
    private let modelID: String
    private let context: String
    private let strategy: QwenTranscriptionStrategy
    private let recordingDuration: (URL) -> TimeInterval?
    private let onDecodeTiming: ((Int) -> Void)?

    init(
        client: QwenTranscriptionClient = QwenHelperClient(),
        modelID: String,
        context: String = "",
        strategy: QwenTranscriptionStrategy = .full,
        recordingDuration: @escaping (URL) -> TimeInterval? = QwenContextEchoDetector.recordingDuration,
        onDecodeTiming: ((Int) -> Void)? = nil
    ) {
        self.client = client
        self.modelID = modelID
        self.context = context
        self.strategy = strategy
        self.recordingDuration = recordingDuration
        self.onDecodeTiming = onDecodeTiming
    }

    func transcribe(fileURL: URL, languageMode: LanguageMode) async throws -> TranscriptionResult {
        let duration = recordingDuration(fileURL)
        let effectiveStrategy = effectiveStrategy(forRecordingDuration: duration)
        let decodeStartedAt = Date()
        let text = try await client.transcribe(
            wavURL: fileURL,
            modelID: modelID,
            context: context,
            strategy: effectiveStrategy
        )
        if let cleanedText = QwenContextEchoDetector.transcriptByRemovingContextEchoTail(text, context: context),
           PasteInjector.isPasteable(cleanedText) {
            onDecodeTiming?(Self.milliseconds(since: decodeStartedAt))
            return result(text: cleanedText, effectiveStrategy: effectiveStrategy)
        }

        let echoDetectionDuration = duration ?? 0
        if QwenContextEchoDetector.isLikelyEcho(text, context: context, recordingDuration: echoDetectionDuration) {
            let retriedText = try await client.transcribe(
                wavURL: fileURL,
                modelID: modelID,
                context: "",
                strategy: effectiveStrategy
            )
            let acceptedRetryText = QwenContextEchoDetector.transcriptByRemovingContextEchoTail(retriedText, context: context) ?? retriedText
            guard PasteInjector.isPasteable(acceptedRetryText),
                  !QwenContextEchoDetector.isLikelyEcho(
                    acceptedRetryText,
                    context: context,
                    recordingDuration: echoDetectionDuration
                  ) else {
                throw TranscriptionError.emptyResult
            }
            onDecodeTiming?(Self.milliseconds(since: decodeStartedAt))
            return result(text: acceptedRetryText, effectiveStrategy: effectiveStrategy)
        }

        guard PasteInjector.isPasteable(text) else {
            throw TranscriptionError.emptyResult
        }
        onDecodeTiming?(Self.milliseconds(since: decodeStartedAt))
        return result(text: text, effectiveStrategy: effectiveStrategy)
    }

    private func effectiveStrategy(forRecordingDuration duration: TimeInterval?) -> QwenTranscriptionStrategy {
        guard strategy == .full,
              let duration,
              duration > Self.longDictationFullThreshold else {
            return strategy
        }
        return .chunked
    }

    private func result(text: String, effectiveStrategy: QwenTranscriptionStrategy) -> TranscriptionResult {
        TranscriptionResult(
            text: text,
            engine: .qwenLocal,
            requestedModelID: modelID,
            requestedStrategy: strategy.rawValue,
            effectiveStrategy: effectiveStrategy.rawValue
        )
    }

    private static func milliseconds(since date: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(date) * 1_000))
    }
}
