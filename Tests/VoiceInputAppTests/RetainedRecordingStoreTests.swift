import XCTest
@testable import VoiceInputApp

final class RetainedRecordingStoreTests: XCTestCase {
    func testSaveRecordingCopiesFileUsingHistoryID() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceURL = directory.appendingPathComponent("source.wav")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("wav-data".utf8).write(to: sourceURL)
        let store = RetainedRecordingStore(directoryURL: directory.appendingPathComponent("Recordings", isDirectory: true))
        let id = UUID()

        let fileName = try store.saveRecording(sourceURL: sourceURL, id: id)

        XCTAssertEqual(fileName, "\(id.uuidString).wav")
        XCTAssertEqual(try Data(contentsOf: store.recordingURL(fileName: fileName)), Data("wav-data".utf8))
    }

    func testPruneKeepsOnlyRecentRecordingNames() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = RetainedRecordingStore(directoryURL: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let keep = ["keep-1.wav", "keep-2.wav", "keep-3.wav"]
        for name in keep + ["drop.wav"] {
            try Data(name.utf8).write(to: directory.appendingPathComponent(name))
        }

        try store.prune(keeping: keep)

        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("keep-1.wav").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("drop.wav").path))
    }

    func testPruneWithEmptyKeepListRemovesAllRecordings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = RetainedRecordingStore(directoryURL: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["one.wav", "two.wav"] {
            try Data(name.utf8).write(to: directory.appendingPathComponent(name))
        }

        try store.prune(keeping: [])

        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ),
            []
        )
    }
}

final class TranscriptionIssueDetectorTests: XCTestCase {
    func testFlagsLongRecordingWithVeryShortTranscript() {
        XCTAssertEqual(
            TranscriptionIssueDetector.issue(for: "我今天讲DEMO1001。", recordingDuration: 45),
            .possibleTruncation
        )
    }

    func testDoesNotFlagShortRecordingOrDenseTranscript() {
        XCTAssertNil(TranscriptionIssueDetector.issue(for: "请看 Q4(b) and (c)。", recordingDuration: 3))
        XCTAssertNil(TranscriptionIssueDetector.issue(for: String(repeating: "今天我们讨论模型和测试。", count: 20), recordingDuration: 45))
    }
}
