import XCTest
@testable import VoiceInputApp

final class DebugRecordingStoreTests: XCTestCase {
    func testSaveLastRecordingCopiesAudioAndWritesMetadata() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceURL = directory.appendingPathComponent("source.wav")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("wav-data".utf8).write(to: sourceURL)

        let store = DebugRecordingStore(directoryURL: directory.appendingPathComponent("Debug", isDirectory: true))
        let metadata = DebugRecordingMetadata(
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            recordingDuration: 12.5,
            audioFileSize: 8,
            engine: .qwenLocal,
            languageMode: .mixedChineseEnglish,
            modelID: "qwen3-asr-0.6b",
            processedTranscript: "我今天讲DEMO1001",
            errorDescription: nil
        )

        try store.saveLastRecording(sourceURL: sourceURL, metadata: metadata)

        XCTAssertEqual(try Data(contentsOf: store.lastRecordingURL), Data("wav-data".utf8))
        let savedMetadata = try JSONDecoder.debugRecording.decode(
            DebugRecordingMetadata.self,
            from: Data(contentsOf: store.lastMetadataURL)
        )
        XCTAssertEqual(savedMetadata, metadata)
    }
}
