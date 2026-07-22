import Foundation

final class RetainedRecordingStore {
    let directoryURL: URL

    static let retainedRecordingLimit = 3

    static func defaultStore(fileManager: FileManager = .default) throws -> RetainedRecordingStore {
        let directory = try ApplicationSupport.directory(fileManager: fileManager)
            .appendingPathComponent("Recordings", isDirectory: true)
        return RetainedRecordingStore(directoryURL: directory)
    }

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    func saveRecording(sourceURL: URL, id: UUID) throws -> String {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileName = "\(id.uuidString).wav"
        let destination = recordingURL(fileName: fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return fileName
    }

    func recordingURL(fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }

    func prune(keeping fileNames: [String]) throws {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return }
        let keepSet = Set(fileNames)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for url in urls where !keepSet.contains(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

enum TranscriptionIssueDetector {
    static func issue(for text: String, recordingDuration: TimeInterval) -> TranscriptHistoryIssue? {
        guard recordingDuration >= 20 else { return nil }
        let unitCount = TranscriptHistoryItem.countWords(in: text)
        let expectedMinimum = Int(recordingDuration * 1.2)
        return unitCount < expectedMinimum ? .possibleTruncation : nil
    }
}
