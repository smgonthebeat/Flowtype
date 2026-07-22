import Foundation

enum TranscriptHistoryIssue: String, Codable, Equatable {
    case possibleTruncation
}

enum TranscriptHistoryStatus: String, Codable, Equatable {
    case succeeded
    case failed
    case recovered
}

enum TranscriptFailureCategory: String, Codable, Equatable {
    case transcriptionFailed
    case noSpeechDetected
    case audioSetupError
    case recordingUnavailable
    case expiredRecording
}

struct TranscriptHistoryItem: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let createdAt: Date
    let engine: TranscriptionEngineKind
    let selectedEngine: TranscriptionEngineKind?
    let languageMode: LanguageMode
    let targetAppName: String?
    let wordCount: Int
    let recordingFileName: String?
    let recordingDuration: TimeInterval?
    let transcriptionIssue: TranscriptHistoryIssue?
    let status: TranscriptHistoryStatus
    let failureCategory: TranscriptFailureCategory?

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case createdAt
        case engine
        case selectedEngine
        case languageMode
        case targetAppName
        case wordCount
        case recordingFileName
        case recordingDuration
        case transcriptionIssue
        case status
        case failureCategory
    }

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        engine: TranscriptionEngineKind,
        selectedEngine: TranscriptionEngineKind? = nil,
        languageMode: LanguageMode,
        targetAppName: String?,
        wordCount: Int? = nil,
        recordingFileName: String? = nil,
        recordingDuration: TimeInterval? = nil,
        transcriptionIssue: TranscriptHistoryIssue? = nil,
        status: TranscriptHistoryStatus = .succeeded,
        failureCategory: TranscriptFailureCategory? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.engine = engine
        self.selectedEngine = selectedEngine
        self.languageMode = languageMode
        self.targetAppName = targetAppName
        self.wordCount = wordCount ?? Self.countWords(in: text)
        self.recordingFileName = recordingFileName
        self.recordingDuration = recordingDuration
        self.transcriptionIssue = transcriptionIssue
        self.status = status
        self.failureCategory = failureCategory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        engine = try container.decode(TranscriptionEngineKind.self, forKey: .engine)
        selectedEngine = try container.decodeIfPresent(TranscriptionEngineKind.self, forKey: .selectedEngine)
        languageMode = try container.decode(LanguageMode.self, forKey: .languageMode)
        targetAppName = try container.decodeIfPresent(String.self, forKey: .targetAppName)
        wordCount = try container.decode(Int.self, forKey: .wordCount)
        recordingFileName = try container.decodeIfPresent(String.self, forKey: .recordingFileName)
        recordingDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .recordingDuration)
        transcriptionIssue = try container.decodeIfPresent(TranscriptHistoryIssue.self, forKey: .transcriptionIssue)
        status = try container.decodeIfPresent(TranscriptHistoryStatus.self, forKey: .status) ?? .succeeded
        failureCategory = try container.decodeIfPresent(TranscriptFailureCategory.self, forKey: .failureCategory)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(engine, forKey: .engine)
        try container.encodeIfPresent(selectedEngine, forKey: .selectedEngine)
        try container.encode(languageMode, forKey: .languageMode)
        try container.encodeIfPresent(targetAppName, forKey: .targetAppName)
        try container.encode(wordCount, forKey: .wordCount)
        try container.encodeIfPresent(recordingFileName, forKey: .recordingFileName)
        try container.encodeIfPresent(recordingDuration, forKey: .recordingDuration)
        try container.encodeIfPresent(transcriptionIssue, forKey: .transcriptionIssue)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(failureCategory, forKey: .failureCategory)
    }

    func updatingTranscript(_ newText: String, transcriptionIssue: TranscriptHistoryIssue?) -> TranscriptHistoryItem {
        TranscriptHistoryItem(
            id: id,
            text: newText,
            createdAt: createdAt,
            engine: engine,
            selectedEngine: selectedEngine,
            languageMode: languageMode,
            targetAppName: targetAppName,
            recordingFileName: recordingFileName,
            recordingDuration: recordingDuration,
            transcriptionIssue: transcriptionIssue,
            status: status == .failed ? .recovered : .succeeded,
            failureCategory: nil
        )
    }

    func markingRetryFailed(_ category: TranscriptFailureCategory) -> TranscriptHistoryItem {
        guard status == .failed else {
            return self
        }

        return TranscriptHistoryItem(
            id: id,
            text: text,
            createdAt: createdAt,
            engine: engine,
            selectedEngine: selectedEngine,
            languageMode: languageMode,
            targetAppName: targetAppName,
            wordCount: wordCount,
            recordingFileName: recordingFileName,
            recordingDuration: recordingDuration,
            transcriptionIssue: transcriptionIssue,
            status: .failed,
            failureCategory: category
        )
    }

    func markingRecordingExpired() -> TranscriptHistoryItem {
        if status == .failed {
            return markingRetryFailed(.expiredRecording)
        }

        return TranscriptHistoryItem(
            id: id,
            text: text,
            createdAt: createdAt,
            engine: engine,
            selectedEngine: selectedEngine,
            languageMode: languageMode,
            targetAppName: targetAppName,
            wordCount: wordCount,
            recordingDuration: recordingDuration,
            status: status,
            failureCategory: failureCategory
        )
    }

    static func countWords(in text: String) -> Int {
        var count = 0
        var isInAlphanumericWord = false

        for character in text {
            if character.isCJKHistoryUnit {
                count += 1
                isInAlphanumericWord = false
            } else if character.isNonCJKAlphanumeric {
                if !isInAlphanumericWord {
                    count += 1
                    isInAlphanumericWord = true
                }
            } else {
                isInAlphanumericWord = false
            }
        }

        return count
    }

    var retryEngine: TranscriptionEngineKind {
        selectedEngine ?? engine
    }
}

private extension Character {
    var isCJKHistoryUnit: Bool {
        unicodeScalars.contains { scalar in
            scalar.isCJKIdeograph || scalar.isKana || scalar.isHangul
        }
    }

    var isNonCJKAlphanumeric: Bool {
        !isCJKHistoryUnit && unicodeScalars.allSatisfy { scalar in
            scalar.properties.isAlphabetic || scalar.properties.numericType != nil
        }
    }
}

private extension Unicode.Scalar {
    var isCJKIdeograph: Bool {
        switch value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF,
             0x2CEB0...0x2EBEF,
             0x30000...0x3134F:
            return true
        default:
            return false
        }
    }

    var isKana: Bool {
        switch value {
        case 0x3040...0x309F,
             0x30A0...0x30FF,
             0x31F0...0x31FF:
            return true
        default:
            return false
        }
    }

    var isHangul: Bool {
        switch value {
        case 0x1100...0x11FF,
             0x3130...0x318F,
             0xAC00...0xD7AF:
            return true
        default:
            return false
        }
    }
}
