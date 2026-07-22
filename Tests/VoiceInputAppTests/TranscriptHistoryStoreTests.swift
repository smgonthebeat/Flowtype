import XCTest
@testable import VoiceInputApp

final class TranscriptHistoryStoreTests: XCTestCase {
    func testDefaultFileURLUsesHistoryJSONFilename() throws {
        let url = try TranscriptHistoryStore.defaultFileURL()

        XCTAssertEqual(url.lastPathComponent, "history.json")
    }

    func testAddPersistsAndLimitsEntries() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 2)

        try store.add(text: "first", engine: .qwenLocal, languageMode: .mixedChineseEnglish, targetAppName: "Notes")
        try store.add(text: "second", engine: .qwenLocal, languageMode: .mixedChineseEnglish, targetAppName: "Notes")
        try store.add(text: "third", engine: .appleSpeech, languageMode: .chinese, targetAppName: nil)

        let items = try store.load()

        XCTAssertEqual(items.map(\.text), ["third", "second"])
        XCTAssertEqual(items.first?.engine, .appleSpeech)
        XCTAssertEqual(items.first?.wordCount, 1)
    }

    func testAddPersistsRetryMetadata() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()

        try store.add(
            id: id,
            text: "short transcript",
            engine: .qwenLocal,
            languageMode: .mixedChineseEnglish,
            targetAppName: "Notes",
            recordingFileName: "\(id.uuidString).wav",
            recordingDuration: 40,
            transcriptionIssue: .possibleTruncation
        )

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.recordingFileName, "\(id.uuidString).wav")
        XCTAssertEqual(item.recordingDuration, 40)
        XCTAssertEqual(item.transcriptionIssue, .possibleTruncation)
    }

    func testAddPersistsSelectedEngineForFallbackSuccessRetry() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()

        try store.add(
            id: id,
            text: "fallback transcript",
            engine: .appleSpeech,
            selectedEngine: .qwenLocal,
            languageMode: .mixedChineseEnglish,
            targetAppName: nil,
            recordingFileName: "\(id.uuidString).wav",
            recordingDuration: 40,
            transcriptionIssue: .possibleTruncation
        )

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.engine, .appleSpeech)
        XCTAssertEqual(item.selectedEngine, .qwenLocal)
        XCTAssertEqual(item.retryEngine, .qwenLocal)
    }

    func testUpdateTranscriptClearsIssueAndRecountsWords() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()
        try store.add(
            id: id,
            text: "short",
            engine: .qwenLocal,
            languageMode: .mixedChineseEnglish,
            targetAppName: nil,
            recordingFileName: "\(id.uuidString).wav",
            recordingDuration: 40,
            transcriptionIssue: .possibleTruncation
        )

        try store.updateTranscript(id: id, text: "hello 世界", transcriptionIssue: nil)

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.text, "hello 世界")
        XCTAssertEqual(item.wordCount, 3)
        XCTAssertNil(item.transcriptionIssue)
        XCTAssertEqual(item.recordingFileName, "\(id.uuidString).wav")
    }

    func testLoadsLegacyItemsWithoutRetryMetadata() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            #"""
            [
              {
                "createdAt" : "2026-05-10T05:00:00Z",
                "engine" : "qwenLocal",
                "id" : "11111111-1111-1111-1111-111111111111",
                "languageMode" : "mixedChineseEnglish",
                "targetAppName" : null,
                "text" : "legacy transcript",
                "wordCount" : 2
              }
            ]
            """#.utf8
        ).write(to: url)
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)

        let item = try XCTUnwrap(store.load().first)

        XCTAssertEqual(item.text, "legacy transcript")
        XCTAssertNil(item.recordingFileName)
        XCTAssertNil(item.recordingDuration)
        XCTAssertNil(item.transcriptionIssue)
    }

    func testLegacyItemsDefaultToSucceededStatus() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            #"""
            [
              {
                "createdAt" : "2026-05-10T05:00:00Z",
                "engine" : "qwenLocal",
                "id" : "11111111-1111-1111-1111-111111111111",
                "languageMode" : "mixedChineseEnglish",
                "targetAppName" : null,
                "text" : "legacy transcript",
                "wordCount" : 2
              }
            ]
            """#.utf8
        ).write(to: url)
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)

        let item = try XCTUnwrap(store.load().first)

        XCTAssertEqual(item.status, .succeeded)
        XCTAssertNil(item.failureCategory)
    }

    func testAddFailedAttemptPersistsEmptyTextWithRecordingMetadata() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()

        try store.addFailedAttempt(
            id: id,
            engine: .qwenLocal,
            languageMode: .mixedChineseEnglish,
            targetAppName: "Notes",
            recordingFileName: "\(id.uuidString).wav",
            recordingDuration: 12,
            failureCategory: .transcriptionFailed
        )

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.text, "")
        XCTAssertEqual(item.wordCount, 0)
        XCTAssertEqual(item.status, .failed)
        XCTAssertEqual(item.failureCategory, .transcriptionFailed)
        XCTAssertEqual(item.recordingFileName, "\(id.uuidString).wav")
        XCTAssertEqual(item.recordingDuration, 12)
    }

    func testUpdateTranscriptTurnsFailedAttemptIntoRecoveredRow() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()
        try store.addFailedAttempt(
            id: id,
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "\(id.uuidString).wav",
            recordingDuration: 30,
            failureCategory: .transcriptionFailed
        )

        try store.updateTranscript(id: id, text: "recovered text", transcriptionIssue: .possibleTruncation)

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.text, "recovered text")
        XCTAssertEqual(item.status, .recovered)
        XCTAssertNil(item.failureCategory)
        XCTAssertEqual(item.transcriptionIssue, .possibleTruncation)
        XCTAssertEqual(item.recordingFileName, "\(id.uuidString).wav")
        XCTAssertEqual(item.recordingDuration, 30)
    }

    func testMarkRetryFailureKeepsFailedAttemptRow() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()
        try store.addFailedAttempt(
            id: id,
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "\(id.uuidString).wav",
            recordingDuration: 30,
            failureCategory: .transcriptionFailed
        )

        try store.markRetryFailed(id: id, failureCategory: .transcriptionFailed)

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.status, .failed)
        XCTAssertEqual(item.failureCategory, .transcriptionFailed)
        XCTAssertEqual(item.text, "")
    }

    func testMarkRetryFailedDoesNotDowngradeSucceededRow() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()
        try store.add(
            id: id,
            text: "successful transcript",
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil
        )

        try store.markRetryFailed(id: id, failureCategory: .transcriptionFailed)

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.text, "successful transcript")
        XCTAssertEqual(item.status, .succeeded)
        XCTAssertNil(item.failureCategory)
        XCTAssertEqual(item.wordCount, 2)
    }

    func testMarkRecordingExpiredDisablesRecoveryWithoutDeletingRow() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()
        try store.addFailedAttempt(
            id: id,
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "\(id.uuidString).wav",
            recordingDuration: 30,
            failureCategory: .transcriptionFailed
        )

        try store.markRecordingExpired(id: id)

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.status, .failed)
        XCTAssertEqual(item.failureCategory, .expiredRecording)
        XCTAssertEqual(item.recordingFileName, "\(id.uuidString).wav")
    }

    func testMarkRecordingExpiredDoesNotDowngradeSucceededRow() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()
        try store.add(
            id: id,
            text: "successful transcript",
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil
        )

        try store.markRecordingExpired(id: id)

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.text, "successful transcript")
        XCTAssertEqual(item.status, .succeeded)
        XCTAssertNil(item.failureCategory)
        XCTAssertEqual(item.wordCount, 2)
    }

    func testMarkRecordingExpiredDisablesRetryMetadataForSucceededPossibleTruncationRow() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()
        try store.add(
            id: id,
            text: "short transcript",
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "\(id.uuidString).wav",
            recordingDuration: 45,
            transcriptionIssue: .possibleTruncation
        )

        try store.markRecordingExpired(id: id)

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.text, "short transcript")
        XCTAssertEqual(item.status, .succeeded)
        XCTAssertNil(item.failureCategory)
        XCTAssertNil(item.recordingFileName)
        XCTAssertEqual(item.recordingDuration, 45)
        XCTAssertNil(item.transcriptionIssue)
    }

    func testMarkRecordingExpiredDisablesRetryMetadataForRecoveredPossibleTruncationRow() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let id = UUID()
        try store.addFailedAttempt(
            id: id,
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "\(id.uuidString).wav",
            recordingDuration: 45,
            failureCategory: .transcriptionFailed
        )
        try store.updateTranscript(id: id, text: "still short", transcriptionIssue: .possibleTruncation)

        try store.markRecordingExpired(id: id)

        let item = try XCTUnwrap(store.load().first)
        XCTAssertEqual(item.text, "still short")
        XCTAssertEqual(item.status, .recovered)
        XCTAssertNil(item.failureCategory)
        XCTAssertNil(item.recordingFileName)
        XCTAssertEqual(item.recordingDuration, 45)
        XCTAssertNil(item.transcriptionIssue)
    }

    func testFailureTransitionsDoNotDowngradeRecoveredRows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let retryFailedID = UUID()
        let expiredID = UUID()
        try store.addFailedAttempt(
            id: retryFailedID,
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "\(retryFailedID.uuidString).wav",
            recordingDuration: 20,
            failureCategory: .transcriptionFailed
        )
        try store.addFailedAttempt(
            id: expiredID,
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "\(expiredID.uuidString).wav",
            recordingDuration: 20,
            failureCategory: .transcriptionFailed
        )
        try store.updateTranscript(id: retryFailedID, text: "retry recovered", transcriptionIssue: nil)
        try store.updateTranscript(id: expiredID, text: "expired recovered", transcriptionIssue: nil)

        try store.markRetryFailed(id: retryFailedID, failureCategory: .transcriptionFailed)
        try store.markRecordingExpired(id: expiredID)

        let items = try store.load()
        let retryFailedItem = try XCTUnwrap(items.first { $0.id == retryFailedID })
        let expiredItem = try XCTUnwrap(items.first { $0.id == expiredID })
        XCTAssertEqual(retryFailedItem.text, "retry recovered")
        XCTAssertEqual(retryFailedItem.status, .recovered)
        XCTAssertNil(retryFailedItem.failureCategory)
        XCTAssertEqual(expiredItem.text, "expired recovered")
        XCTAssertEqual(expiredItem.status, .recovered)
        XCTAssertNil(expiredItem.failureCategory)
        XCTAssertNil(expiredItem.transcriptionIssue)
    }

    func testClearRemovesAllEntries() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)

        try store.add(text: "hello world", engine: .qwenLocal, languageMode: .english, targetAppName: nil)
        try store.clear()

        XCTAssertEqual(try store.load(), [])
    }

    func testClearRemovesFailedAndRecoveredEntries() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)
        let failedID = UUID()
        let recoveredID = UUID()

        try store.addFailedAttempt(
            id: failedID,
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "\(failedID.uuidString).wav",
            recordingDuration: 18,
            failureCategory: .transcriptionFailed
        )
        try store.addFailedAttempt(
            id: recoveredID,
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "\(recoveredID.uuidString).wav",
            recordingDuration: 18,
            failureCategory: .transcriptionFailed
        )
        try store.updateTranscript(id: recoveredID, text: "recovered transcript", transcriptionIssue: nil)

        try store.clear()

        XCTAssertEqual(try store.load(), [])
    }

    func testDoesNotStoreEmptyText() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = TranscriptHistoryStore(fileURL: url, limit: 100)

        try store.add(text: "   ", engine: .qwenLocal, languageMode: .english, targetAppName: nil)

        XCTAssertEqual(try store.load(), [])
    }

    func testWordCountHandlesCJKAndMixedText() {
        XCTAssertEqual(makeItem(text: "hello world").wordCount, 2)
        XCTAssertEqual(makeItem(text: "third").wordCount, 1)
        XCTAssertEqual(makeItem(text: "你好世界").wordCount, 4)
        XCTAssertEqual(makeItem(text: "hello世界").wordCount, 3)
        XCTAssertEqual(makeItem(text: "Claude Code 你好").wordCount, 4)
    }

    private func makeItem(text: String) -> TranscriptHistoryItem {
        TranscriptHistoryItem(
            text: text,
            engine: .qwenLocal,
            languageMode: .mixedChineseEnglish,
            targetAppName: nil
        )
    }
}
