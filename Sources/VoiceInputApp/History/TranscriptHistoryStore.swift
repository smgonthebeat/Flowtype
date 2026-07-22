import Foundation

final class TranscriptHistoryStore {
    private let fileURL: URL
    private let limit: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    static func defaultFileURL(fileManager: FileManager = .default) throws -> URL {
        try ApplicationSupport.directory(fileManager: fileManager)
            .appendingPathComponent("history.json")
    }

    static func defaultStore(limit: Int = 100, fileManager: FileManager = .default) throws -> TranscriptHistoryStore {
        TranscriptHistoryStore(fileURL: try defaultFileURL(fileManager: fileManager), limit: limit)
    }

    convenience init(limit: Int = 100) {
        do {
            self.init(fileURL: try Self.defaultFileURL(), limit: limit)
        } catch {
            preconditionFailure("Unable to resolve TranscriptHistoryStore persistence URL: \(error)")
        }
    }

    init(fileURL: URL, limit: Int) {
        self.fileURL = fileURL
        self.limit = max(1, limit)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> [TranscriptHistoryItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let items = try decoder.decode([TranscriptHistoryItem].self, from: data)
        return Array(items.prefix(limit))
    }

    @discardableResult
    func add(
        id: UUID = UUID(),
        text: String,
        engine: TranscriptionEngineKind,
        selectedEngine: TranscriptionEngineKind? = nil,
        languageMode: LanguageMode,
        targetAppName: String?,
        recordingFileName: String? = nil,
        recordingDuration: TimeInterval? = nil,
        transcriptionIssue: TranscriptHistoryIssue? = nil
    ) throws -> TranscriptHistoryItem? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        let item = TranscriptHistoryItem(
            id: id,
            text: normalized,
            engine: engine,
            selectedEngine: selectedEngine,
            languageMode: languageMode,
            targetAppName: targetAppName,
            recordingFileName: recordingFileName,
            recordingDuration: recordingDuration,
            transcriptionIssue: transcriptionIssue
        )
        var items = try load()
        items.insert(item, at: 0)
        try save(items)
        return item
    }

    @discardableResult
    func addFailedAttempt(
        id: UUID = UUID(),
        engine: TranscriptionEngineKind,
        languageMode: LanguageMode,
        targetAppName: String?,
        recordingFileName: String,
        recordingDuration: TimeInterval?,
        failureCategory: TranscriptFailureCategory
    ) throws -> TranscriptHistoryItem {
        let item = TranscriptHistoryItem(
            id: id,
            text: "",
            engine: engine,
            languageMode: languageMode,
            targetAppName: targetAppName,
            wordCount: 0,
            recordingFileName: recordingFileName,
            recordingDuration: recordingDuration,
            status: .failed,
            failureCategory: failureCategory
        )
        var items = try load()
        items.insert(item, at: 0)
        try save(items)
        return item
    }

    func updateTranscript(
        id: UUID,
        text: String,
        transcriptionIssue: TranscriptHistoryIssue?
    ) throws {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        let items = try load().map { item in
            item.id == id ? item.updatingTranscript(normalized, transcriptionIssue: transcriptionIssue) : item
        }
        try save(items)
    }

    func markRetryFailed(id: UUID, failureCategory: TranscriptFailureCategory) throws {
        let items = try load().map { item in
            item.id == id ? item.markingRetryFailed(failureCategory) : item
        }
        try save(items)
    }

    func markRecordingExpired(id: UUID) throws {
        let items = try load().map { item in
            item.id == id ? item.markingRecordingExpired() : item
        }
        try save(items)
    }

    func clear() throws {
        try save([])
    }

    func save(_ items: [TranscriptHistoryItem]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(Array(items.prefix(limit)))
        try data.write(to: fileURL, options: .atomic)
    }
}
