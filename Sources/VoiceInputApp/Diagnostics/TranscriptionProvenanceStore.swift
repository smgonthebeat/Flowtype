import Foundation

final class TranscriptionProvenanceStore {
    private static let appendQueue = DispatchQueue(label: "com.smg.flowtype.transcription-provenance-store.append")

    private let url: URL
    private let limit: Int
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(applicationSupportRoot: URL? = nil, limit: Int = 50, fileManager: FileManager = .default) {
        self.limit = max(1, limit)
        self.fileManager = fileManager

        let root = applicationSupportRoot ?? ((try? ApplicationSupport.directory(fileManager: fileManager)) ??
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(ApplicationSupport.appDirectoryName, isDirectory: true))
        self.url = root
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("Transcriptions", isDirectory: true)
            .appendingPathComponent("transcription-provenance.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func append(_ record: TranscriptionProvenance) throws {
        try Self.appendQueue.sync {
            var records = try loadRecent()
            records.append(record)
            records.sort { $0.createdAt > $1.createdAt }
            try save(Array(records.prefix(limit)))
        }
    }

    func loadRecent() throws -> [TranscriptionProvenance] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let records = try decoder.decode([TranscriptionProvenance].self, from: Data(contentsOf: url))
            .sorted { $0.createdAt > $1.createdAt }
        return Array(records.prefix(limit))
    }

    private func save(_ records: [TranscriptionProvenance]) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(records).write(to: url, options: .atomic)
    }
}
