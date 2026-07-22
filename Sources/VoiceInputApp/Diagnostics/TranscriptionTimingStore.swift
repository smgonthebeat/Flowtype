import Foundation

struct TranscriptionTimingSample: Codable, Equatable {
    let createdAt: Date
    let modelID: String
    let requestedStrategy: String
    let effectiveStrategy: String
    let recordingDurationSeconds: TimeInterval?
    let helperStartMilliseconds: Int
    let modelPreparationMilliseconds: Int
    let decodeMilliseconds: Int
    let postProcessingMilliseconds: Int
    let totalMilliseconds: Int

    var strategy: String {
        requestedStrategy
    }

    init(
        createdAt: Date,
        modelID: String,
        requestedStrategy: String,
        effectiveStrategy: String,
        recordingDurationSeconds: TimeInterval?,
        helperStartMilliseconds: Int,
        modelPreparationMilliseconds: Int,
        decodeMilliseconds: Int,
        postProcessingMilliseconds: Int,
        totalMilliseconds: Int
    ) {
        self.createdAt = createdAt
        self.modelID = modelID
        self.requestedStrategy = requestedStrategy
        self.effectiveStrategy = effectiveStrategy
        self.recordingDurationSeconds = recordingDurationSeconds
        self.helperStartMilliseconds = helperStartMilliseconds
        self.modelPreparationMilliseconds = modelPreparationMilliseconds
        self.decodeMilliseconds = decodeMilliseconds
        self.postProcessingMilliseconds = postProcessingMilliseconds
        self.totalMilliseconds = totalMilliseconds
    }

    init(
        createdAt: Date,
        modelID: String,
        strategy: String,
        recordingDurationSeconds: TimeInterval?,
        helperStartMilliseconds: Int,
        modelPreparationMilliseconds: Int,
        decodeMilliseconds: Int,
        postProcessingMilliseconds: Int,
        totalMilliseconds: Int
    ) {
        self.init(
            createdAt: createdAt,
            modelID: modelID,
            requestedStrategy: strategy,
            effectiveStrategy: strategy,
            recordingDurationSeconds: recordingDurationSeconds,
            helperStartMilliseconds: helperStartMilliseconds,
            modelPreparationMilliseconds: modelPreparationMilliseconds,
            decodeMilliseconds: decodeMilliseconds,
            postProcessingMilliseconds: postProcessingMilliseconds,
            totalMilliseconds: totalMilliseconds
        )
    }

    enum CodingKeys: String, CodingKey {
        case createdAt
        case modelID
        case strategy
        case requestedStrategy
        case effectiveStrategy
        case recordingDurationSeconds
        case helperStartMilliseconds
        case modelPreparationMilliseconds
        case decodeMilliseconds
        case postProcessingMilliseconds
        case totalMilliseconds
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modelID = try container.decode(String.self, forKey: .modelID)
        requestedStrategy = try container.decodeIfPresent(String.self, forKey: .requestedStrategy)
            ?? container.decodeIfPresent(String.self, forKey: .strategy)
            ?? "full"
        effectiveStrategy = try container.decodeIfPresent(String.self, forKey: .effectiveStrategy)
            ?? requestedStrategy
        recordingDurationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .recordingDurationSeconds)
        helperStartMilliseconds = try container.decode(Int.self, forKey: .helperStartMilliseconds)
        modelPreparationMilliseconds = try container.decode(Int.self, forKey: .modelPreparationMilliseconds)
        decodeMilliseconds = try container.decode(Int.self, forKey: .decodeMilliseconds)
        postProcessingMilliseconds = try container.decode(Int.self, forKey: .postProcessingMilliseconds)
        totalMilliseconds = try container.decode(Int.self, forKey: .totalMilliseconds)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modelID, forKey: .modelID)
        try container.encode(requestedStrategy, forKey: .strategy)
        try container.encode(requestedStrategy, forKey: .requestedStrategy)
        try container.encode(effectiveStrategy, forKey: .effectiveStrategy)
        try container.encodeIfPresent(recordingDurationSeconds, forKey: .recordingDurationSeconds)
        try container.encode(helperStartMilliseconds, forKey: .helperStartMilliseconds)
        try container.encode(modelPreparationMilliseconds, forKey: .modelPreparationMilliseconds)
        try container.encode(decodeMilliseconds, forKey: .decodeMilliseconds)
        try container.encode(postProcessingMilliseconds, forKey: .postProcessingMilliseconds)
        try container.encode(totalMilliseconds, forKey: .totalMilliseconds)
    }
}

final class TranscriptionTimingStore {
    private let url: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(applicationSupportRoot: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let root = applicationSupportRoot ?? ((try? ApplicationSupport.directory(fileManager: fileManager)) ??
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(ApplicationSupport.appDirectoryName, isDirectory: true))
        self.url = root
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("last-transcription-timing.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func save(_ sample: TranscriptionTimingSample) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(sample).write(to: url, options: .atomic)
    }

    func loadLastSample() throws -> TranscriptionTimingSample? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return try decoder.decode(TranscriptionTimingSample.self, from: Data(contentsOf: url))
    }
}
