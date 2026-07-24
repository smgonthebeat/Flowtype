import Foundation

enum QwenContextEchoRecovery: String, Codable, Equatable {
    case retriedWithoutContext
}

struct TranscriptionResult: Equatable {
    let text: String
    let engine: TranscriptionEngineKind
    let selectedEngine: TranscriptionEngineKind
    let requestedModelID: String?
    let requestedStrategy: String?
    let effectiveStrategy: String?
    let fallbackReason: String?
    let contextEchoRecovery: QwenContextEchoRecovery?

    init(
        text: String,
        engine: TranscriptionEngineKind,
        selectedEngine: TranscriptionEngineKind? = nil,
        requestedModelID: String? = nil,
        requestedStrategy: String? = nil,
        effectiveStrategy: String? = nil,
        fallbackReason: String? = nil,
        contextEchoRecovery: QwenContextEchoRecovery? = nil
    ) {
        self.text = text
        self.engine = engine
        self.selectedEngine = selectedEngine ?? engine
        self.requestedModelID = requestedModelID
        self.requestedStrategy = requestedStrategy
        self.effectiveStrategy = effectiveStrategy
        self.fallbackReason = fallbackReason
        self.contextEchoRecovery = contextEchoRecovery
    }
}

protocol TranscriptionEngine {
    func transcribe(fileURL: URL, languageMode: LanguageMode) async throws -> TranscriptionResult
}

enum TranscriptionError: Error, Equatable {
    case unavailable
    case emptyResult
    case timedOut
    case contextLeakDetected
}
