import Foundation

struct DebugRecordingMetadata: Codable, Equatable {
    let createdAt: Date
    let recordingDuration: TimeInterval
    let audioFileSize: UInt64
    let engine: TranscriptionEngineKind
    let selectedEngine: TranscriptionEngineKind?
    let languageMode: LanguageMode
    let modelID: String?
    let processedTranscript: String?
    let errorDescription: String?

    init(
        createdAt: Date,
        recordingDuration: TimeInterval,
        audioFileSize: UInt64,
        engine: TranscriptionEngineKind,
        selectedEngine: TranscriptionEngineKind? = nil,
        languageMode: LanguageMode,
        modelID: String?,
        processedTranscript: String?,
        errorDescription: String?
    ) {
        self.createdAt = createdAt
        self.recordingDuration = recordingDuration
        self.audioFileSize = audioFileSize
        self.engine = engine
        self.selectedEngine = selectedEngine
        self.languageMode = languageMode
        self.modelID = modelID
        self.processedTranscript = processedTranscript
        self.errorDescription = errorDescription
    }

    enum CodingKeys: String, CodingKey {
        case createdAt
        case recordingDuration
        case audioFileSize
        case engine
        case selectedEngine
        case languageMode
        case modelID
        case processedTranscript
        case errorDescription
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        recordingDuration = try container.decode(TimeInterval.self, forKey: .recordingDuration)
        audioFileSize = try container.decode(UInt64.self, forKey: .audioFileSize)
        engine = try container.decode(TranscriptionEngineKind.self, forKey: .engine)
        selectedEngine = try container.decodeIfPresent(TranscriptionEngineKind.self, forKey: .selectedEngine)
        languageMode = try container.decode(LanguageMode.self, forKey: .languageMode)
        modelID = try container.decodeIfPresent(String.self, forKey: .modelID)
        processedTranscript = try container.decodeIfPresent(String.self, forKey: .processedTranscript)
        errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
    }
}

final class DebugRecordingStore {
    let directoryURL: URL
    let lastRecordingURL: URL
    let lastMetadataURL: URL

    static func defaultStore(fileManager: FileManager = .default) throws -> DebugRecordingStore {
        let directory = try ApplicationSupport.directory(fileManager: fileManager)
            .appendingPathComponent("Debug", isDirectory: true)
        return DebugRecordingStore(directoryURL: directory)
    }

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.lastRecordingURL = directoryURL.appendingPathComponent("last-recording.wav")
        self.lastMetadataURL = directoryURL.appendingPathComponent("last-transcription.json")
    }

    func saveLastRecording(sourceURL: URL, metadata: DebugRecordingMetadata) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: lastRecordingURL.path) {
            try FileManager.default.removeItem(at: lastRecordingURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: lastRecordingURL)

        let data = try JSONEncoder.debugRecording.encode(metadata)
        try data.write(to: lastMetadataURL, options: .atomic)
    }
}

extension JSONEncoder {
    static var debugRecording: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var debugRecording: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
