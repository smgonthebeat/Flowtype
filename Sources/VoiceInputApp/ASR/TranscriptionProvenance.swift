import Foundation

struct CapsuleEvent: Codable, Equatable {
    let at: Date
    let text: String
}

struct QwenModelStatusSnapshot: Codable, Equatable {
    let installed: Bool
    let loaded: Bool
    let loading: Bool?
    let downloading: Bool?
    let progress: Double?
    let modelID: String

    init(
        installed: Bool,
        loaded: Bool,
        loading: Bool?,
        downloading: Bool?,
        progress: Double?,
        modelID: String
    ) {
        self.installed = installed
        self.loaded = loaded
        self.loading = loading
        self.downloading = downloading
        self.progress = progress
        self.modelID = modelID
    }

    init(status: QwenModelStatus) {
        self.init(
            installed: status.installed,
            loaded: status.loaded,
            loading: status.loading,
            downloading: status.downloading,
            progress: status.progress,
            modelID: status.modelId
        )
    }
}

struct TranscriptionProvenanceTiming: Codable, Equatable {
    let helperStartMilliseconds: Int?
    let modelPreparationMilliseconds: Int?
    let qwenDecodeMilliseconds: Int?
    let postProcessingMilliseconds: Int?
    let totalMilliseconds: Int?

    init(
        helperStartMilliseconds: Int? = nil,
        modelPreparationMilliseconds: Int? = nil,
        qwenDecodeMilliseconds: Int? = nil,
        postProcessingMilliseconds: Int? = nil,
        totalMilliseconds: Int? = nil
    ) {
        self.helperStartMilliseconds = helperStartMilliseconds
        self.modelPreparationMilliseconds = modelPreparationMilliseconds
        self.qwenDecodeMilliseconds = qwenDecodeMilliseconds
        self.postProcessingMilliseconds = postProcessingMilliseconds
        self.totalMilliseconds = totalMilliseconds
    }

    init(sample: TranscriptionTimingSample) {
        self.init(
            helperStartMilliseconds: sample.helperStartMilliseconds,
            modelPreparationMilliseconds: sample.modelPreparationMilliseconds,
            qwenDecodeMilliseconds: sample.decodeMilliseconds,
            postProcessingMilliseconds: sample.postProcessingMilliseconds,
            totalMilliseconds: sample.totalMilliseconds
        )
    }
}

struct TranscriptionProvenance: Codable, Equatable, Identifiable {
    var id: UUID { recordingID }

    let recordingID: UUID
    let createdAt: Date
    let selectedEngine: TranscriptionEngineKind
    let winnerEngine: TranscriptionEngineKind?
    let selectedModelID: String?
    let modelStatusBefore: QwenModelStatusSnapshot?
    let requestedModelID: String?
    let activeLoadedModelIDBefore: String?
    let activeLoadedModelIDAfter: String?
    let helperWasRunningBefore: Bool?
    let helperPID: Int32?
    let helperPortKnown: Bool?
    let requestedStrategy: String?
    let effectiveStrategy: String?
    let recordingDurationSeconds: TimeInterval?
    let qwenStartedAt: Date?
    let qwenFinishedAt: Date?
    let qwenErrorKind: String?
    let appleFallbackStartedAt: Date?
    let appleFallbackReason: String?
    let fallbackReason: String?
    let sessionStateAtCompletion: String?
    let commitOutcome: String?
    let ignoredInputReason: String?
    let timing: TranscriptionProvenanceTiming?
    let capsuleEvents: [CapsuleEvent]

    init(
        recordingID: UUID,
        createdAt: Date,
        selectedEngine: TranscriptionEngineKind,
        winnerEngine: TranscriptionEngineKind? = nil,
        selectedModelID: String? = nil,
        modelStatusBefore: QwenModelStatusSnapshot? = nil,
        requestedModelID: String? = nil,
        activeLoadedModelIDBefore: String? = nil,
        activeLoadedModelIDAfter: String? = nil,
        helperWasRunningBefore: Bool? = nil,
        helperPID: Int32? = nil,
        helperPortKnown: Bool? = nil,
        requestedStrategy: String? = nil,
        effectiveStrategy: String? = nil,
        recordingDurationSeconds: TimeInterval? = nil,
        qwenStartedAt: Date? = nil,
        qwenFinishedAt: Date? = nil,
        qwenErrorKind: String? = nil,
        appleFallbackStartedAt: Date? = nil,
        appleFallbackReason: String? = nil,
        fallbackReason: String? = nil,
        sessionStateAtCompletion: String? = nil,
        commitOutcome: String? = nil,
        ignoredInputReason: String? = nil,
        timing: TranscriptionProvenanceTiming? = nil,
        capsuleEvents: [CapsuleEvent] = []
    ) {
        self.recordingID = recordingID
        self.createdAt = createdAt
        self.selectedEngine = selectedEngine
        self.winnerEngine = winnerEngine
        self.selectedModelID = selectedModelID
        self.modelStatusBefore = modelStatusBefore
        self.requestedModelID = requestedModelID
        self.activeLoadedModelIDBefore = activeLoadedModelIDBefore
        self.activeLoadedModelIDAfter = activeLoadedModelIDAfter
        self.helperWasRunningBefore = helperWasRunningBefore
        self.helperPID = helperPID
        self.helperPortKnown = helperPortKnown
        self.requestedStrategy = requestedStrategy
        self.effectiveStrategy = effectiveStrategy
        self.recordingDurationSeconds = recordingDurationSeconds
        self.qwenStartedAt = qwenStartedAt
        self.qwenFinishedAt = qwenFinishedAt
        self.qwenErrorKind = qwenErrorKind
        self.appleFallbackStartedAt = appleFallbackStartedAt
        self.appleFallbackReason = appleFallbackReason
        self.fallbackReason = fallbackReason
        self.sessionStateAtCompletion = sessionStateAtCompletion
        self.commitOutcome = commitOutcome
        self.ignoredInputReason = ignoredInputReason
        self.timing = timing
        self.capsuleEvents = capsuleEvents
    }
}
