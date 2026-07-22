import XCTest
@testable import VoiceInputApp

final class UsageStatsStoreTests: XCTestCase {
    func testDefaultFileURLUsesUsageStatsJSONFilename() throws {
        let url = try UsageStatsStore.defaultFileURL()

        XCTAssertEqual(url.lastPathComponent, "usage-stats.json")
    }

    func testRecordSuccessfulDictationPersistsAggregateStats() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("usage-stats.json")
        let store = UsageStatsStore(fileURL: url)
        let now = Date(timeIntervalSince1970: 100)

        let stats = try store.recordSuccessfulDictation(
            text: "Claude Code 你好",
            recordingDuration: 5,
            now: now
        )

        XCTAssertEqual(stats.firstUsedAt, now)
        XCTAssertEqual(stats.updatedAt, now)
        XCTAssertEqual(stats.successfulDictations, 1)
        XCTAssertEqual(stats.cumulativeRecordingSeconds, 5)
        XCTAssertEqual(stats.dictatedUnitCount, 4)
        XCTAssertGreaterThan(stats.estimatedSavedSeconds, 0)
        XCTAssertEqual(try UsageStatsStore(fileURL: url).load(), stats)
    }

    func testRecordSuccessfulDictationAccumulatesAndKeepsFirstUseDate() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("usage-stats.json")
        let store = UsageStatsStore(fileURL: url)
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)

        try store.recordSuccessfulDictation(text: "hello", recordingDuration: 1, now: first)
        let stats = try store.recordSuccessfulDictation(text: "世界", recordingDuration: 2, now: second)

        XCTAssertEqual(stats.firstUsedAt, first)
        XCTAssertEqual(stats.updatedAt, second)
        XCTAssertEqual(stats.successfulDictations, 2)
        XCTAssertEqual(stats.cumulativeRecordingSeconds, 3)
        XCTAssertEqual(stats.dictatedUnitCount, 3)
    }

    func testDoesNotRecordEmptyText() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("usage-stats.json")
        let store = UsageStatsStore(fileURL: url)

        let stats = try store.recordSuccessfulDictation(text: "   ", recordingDuration: 10)

        XCTAssertEqual(stats, .empty)
    }

    func testResetClearsStats() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("usage-stats.json")
        let store = UsageStatsStore(fileURL: url)

        try store.recordSuccessfulDictation(text: "hello world", recordingDuration: 3)
        try store.reset()

        XCTAssertEqual(try store.load(), .empty)
    }

    func testReconcileWithHistorySeedsEmptyStats() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("usage-stats.json")
        let store = UsageStatsStore(fileURL: url)
        let olderDate = Date(timeIntervalSince1970: 50)
        let newerDate = Date(timeIntervalSince1970: 100)
        let history = [
            TranscriptHistoryItem(
                text: "hello world",
                createdAt: newerDate,
                engine: .qwenLocal,
                languageMode: .english,
                targetAppName: nil
            ),
            TranscriptHistoryItem(
                text: "你好",
                createdAt: olderDate,
                engine: .qwenLocal,
                languageMode: .mixedChineseEnglish,
                targetAppName: nil
            )
        ]

        let stats = try store.reconcileWithHistory(history, now: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(stats.firstUsedAt, olderDate)
        XCTAssertEqual(stats.successfulDictations, 2)
        XCTAssertEqual(stats.dictatedUnitCount, 4)
        XCTAssertEqual(stats.cumulativeRecordingSeconds, 0)
        XCTAssertEqual(stats.estimatedSavedSeconds, 0)
    }

    func testReconcileWithHistoryIgnoresFailedEmptyRows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("usage-stats.json")
        let store = UsageStatsStore(fileURL: url)
        let failedDate = Date(timeIntervalSince1970: 50)
        let successfulDate = Date(timeIntervalSince1970: 100)
        let history = [
            TranscriptHistoryItem(
                text: "",
                createdAt: failedDate,
                engine: .qwenLocal,
                languageMode: .english,
                targetAppName: nil,
                wordCount: 0,
                status: .failed,
                failureCategory: .transcriptionFailed
            ),
            TranscriptHistoryItem(
                text: "hello world",
                createdAt: successfulDate,
                engine: .qwenLocal,
                languageMode: .english,
                targetAppName: nil
            )
        ]

        let stats = try store.reconcileWithHistory(history, now: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(stats.firstUsedAt, successfulDate)
        XCTAssertEqual(stats.successfulDictations, 1)
        XCTAssertEqual(stats.dictatedUnitCount, 2)
    }

    func testReconcileWithHistoryBackfillsUndercountedExistingStats() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("usage-stats.json")
        let store = UsageStatsStore(fileURL: url)
        let olderDate = Date(timeIntervalSince1970: 50)
        let newerDate = Date(timeIntervalSince1970: 100)
        let history = [
            TranscriptHistoryItem(
                text: "hello world",
                createdAt: newerDate,
                engine: .qwenLocal,
                languageMode: .english,
                targetAppName: nil
            ),
            TranscriptHistoryItem(
                text: "你好",
                createdAt: olderDate,
                engine: .qwenLocal,
                languageMode: .mixedChineseEnglish,
                targetAppName: nil
            )
        ]

        try store.recordSuccessfulDictation(text: "next", recordingDuration: 1)
        let reconciled = try store.reconcileWithHistory(history)

        XCTAssertEqual(reconciled.firstUsedAt, olderDate)
        XCTAssertEqual(reconciled.successfulDictations, 2)
        XCTAssertEqual(reconciled.dictatedUnitCount, 4)
        XCTAssertEqual(reconciled.cumulativeRecordingSeconds, 1)

        let loaded = try store.load()
        XCTAssertEqual(loaded.firstUsedAt, reconciled.firstUsedAt)
        XCTAssertEqual(loaded.successfulDictations, reconciled.successfulDictations)
        XCTAssertEqual(loaded.dictatedUnitCount, reconciled.dictatedUnitCount)
        XCTAssertEqual(loaded.cumulativeRecordingSeconds, reconciled.cumulativeRecordingSeconds)
    }

    func testReconcileWithHistoryDoesNotReduceLargerStats() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("usage-stats.json")
        let store = UsageStatsStore(fileURL: url)
        let history = [
            TranscriptHistoryItem(
                text: "hello",
                engine: .qwenLocal,
                languageMode: .english,
                targetAppName: nil
            )
        ]

        try store.recordSuccessfulDictation(text: "one two three", recordingDuration: 1)
        try store.recordSuccessfulDictation(text: "four five six", recordingDuration: 1)
        let existingStats = try store.load()
        let reconciled = try store.reconcileWithHistory(history)

        XCTAssertEqual(reconciled, existingStats)
    }

    func testDictatedUnitCountHandlesMixedText() {
        XCTAssertEqual(UsageStatsStore.dictatedUnitCount(in: "hello world"), 2)
        XCTAssertEqual(UsageStatsStore.dictatedUnitCount(in: "你好世界"), 4)
        XCTAssertEqual(UsageStatsStore.dictatedUnitCount(in: "Claude Code 你好"), 4)
    }
}
