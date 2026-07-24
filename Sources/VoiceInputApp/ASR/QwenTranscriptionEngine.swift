import Foundation

final class QwenTranscriptionEngine: TranscriptionEngine {
    // Keep ordinary long dictation in full mode through this duration; only longer recordings are chunked.
    private static let longDictationFullThreshold: TimeInterval = 60

    private let client: QwenTranscriptionClient
    private let modelID: String
    private let context: QwenPromptContext
    private let strategy: QwenTranscriptionStrategy
    private let recordingDuration: (URL) -> TimeInterval?
    private let onDecodeTiming: ((Int) -> Void)?

    init(
        client: QwenTranscriptionClient = QwenHelperClient(),
        modelID: String,
        context: QwenPromptContext = .empty,
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
            context: context.payload,
            strategy: effectiveStrategy
        )

        let echoDetectionDuration = duration ?? 0
        if containsContextLeak(
            text,
            context: context,
            recordingDuration: echoDetectionDuration,
            knownTermPolicy: .all
        ) {
            let retriedText = try await client.transcribe(
                wavURL: fileURL,
                modelID: modelID,
                context: "",
                strategy: effectiveStrategy
            )
            guard !containsContextLeak(
                retriedText,
                context: context,
                recordingDuration: echoDetectionDuration,
                knownTermPolicy: .listOnly
            ) else {
                throw TranscriptionError.contextLeakDetected
            }
            guard PasteInjector.isPasteable(retriedText) else {
                throw TranscriptionError.emptyResult
            }
            onDecodeTiming?(Self.milliseconds(since: decodeStartedAt))
            return result(
                text: retriedText,
                effectiveStrategy: effectiveStrategy,
                contextEchoRecovery: .retriedWithoutContext
            )
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

    private func containsContextLeak(
        _ text: String,
        context: QwenPromptContext,
        recordingDuration: TimeInterval,
        knownTermPolicy: QwenKnownTermEchoPolicy
    ) -> Bool {
        QwenContextEchoDetector.containsInternalContextEchoTail(text, context: context)
            || QwenContextEchoDetector.isLikelyEcho(
                text,
                context: context,
                recordingDuration: recordingDuration,
                knownTermPolicy: knownTermPolicy
            )
    }

    private func result(
        text: String,
        effectiveStrategy: QwenTranscriptionStrategy,
        contextEchoRecovery: QwenContextEchoRecovery? = nil
    ) -> TranscriptionResult {
        TranscriptionResult(
            text: text,
            engine: .qwenLocal,
            requestedModelID: modelID,
            requestedStrategy: strategy.rawValue,
            effectiveStrategy: effectiveStrategy.rawValue,
            contextEchoRecovery: contextEchoRecovery
        )
    }

    private static func milliseconds(since date: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(date) * 1_000))
    }
}
