import XCTest
@testable import VoiceInputApp

final class TranscriptRowPresentationTests: XCTestCase {
    func testSuccessfulRowUsesTranscriptActions() {
        let copy = AppCopy.texts(for: .chinese)
        let item = TranscriptHistoryItem(
            text: "hello",
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil
        )

        let presentation = TranscriptRowPresentation.make(item: item, copy: copy)

        XCTAssertEqual(presentation.primaryText, "hello")
        XCTAssertNil(presentation.secondaryText)
        XCTAssertNil(presentation.recoveryMarkerText)
        XCTAssertTrue(presentation.canCopyAndPaste)
        XCTAssertFalse(presentation.showsRetryAtRest)
        XCTAssertNil(presentation.retryButtonTitle)
    }

    func testFailedRowShowsRetryAtRestAndNoCopyPaste() {
        let copy = AppCopy.texts(for: .chinese)
        let item = TranscriptHistoryItem(
            text: "",
            engine: .qwenLocal,
            languageMode: .mixedChineseEnglish,
            targetAppName: nil,
            recordingFileName: "failed.wav",
            recordingDuration: 12,
            status: .failed,
            failureCategory: .transcriptionFailed
        )

        let presentation = TranscriptRowPresentation.make(item: item, copy: copy)

        XCTAssertEqual(presentation.primaryText, "转写失败")
        XCTAssertEqual(presentation.secondaryText, "已保留录音，可重新转写")
        XCTAssertNil(presentation.recoveryMarkerText)
        XCTAssertFalse(presentation.canCopyAndPaste)
        XCTAssertTrue(presentation.canRetry)
        XCTAssertTrue(presentation.showsRetryAtRest)
        XCTAssertEqual(presentation.retryButtonTitle, "重新转写")
    }

    func testExpiredFailedRowDisablesRetry() {
        let copy = AppCopy.texts(for: .chinese)
        let item = TranscriptHistoryItem(
            text: "",
            engine: .qwenLocal,
            languageMode: .mixedChineseEnglish,
            targetAppName: nil,
            recordingFileName: "expired.wav",
            recordingDuration: 12,
            status: .failed,
            failureCategory: .expiredRecording
        )

        let presentation = TranscriptRowPresentation.make(item: item, copy: copy)

        XCTAssertEqual(presentation.primaryText, "转写失败")
        XCTAssertEqual(presentation.secondaryText, "录音已过期")
        XCTAssertFalse(presentation.canCopyAndPaste)
        XCTAssertFalse(presentation.canRetry)
        XCTAssertTrue(presentation.showsRetryAtRest)
        XCTAssertEqual(presentation.retryButtonTitle, "重新转写")
    }

    func testFailedRowWithoutRecordingDoesNotClaimRecordingWasSaved() {
        let copy = AppCopy.texts(for: .chinese)
        let item = TranscriptHistoryItem(
            text: "",
            engine: .qwenLocal,
            languageMode: .mixedChineseEnglish,
            targetAppName: nil,
            status: .failed,
            failureCategory: .transcriptionFailed
        )

        let presentation = TranscriptRowPresentation.make(item: item, copy: copy)

        XCTAssertEqual(presentation.primaryText, "转写失败")
        XCTAssertEqual(presentation.secondaryText, "录音已过期")
        XCTAssertFalse(presentation.canCopyAndPaste)
        XCTAssertFalse(presentation.canRetry)
        XCTAssertTrue(presentation.showsRetryAtRest)
    }

    func testRecoveredRowKeepsRecoveryMarkerAndTranscriptActions() {
        let copy = AppCopy.texts(for: .chinese)
        let item = TranscriptHistoryItem(
            text: "recovered text",
            engine: .qwenLocal,
            languageMode: .english,
            targetAppName: nil,
            recordingFileName: "recording.wav",
            recordingDuration: 30,
            status: .recovered,
            failureCategory: nil
        )

        let presentation = TranscriptRowPresentation.make(item: item, copy: copy)

        XCTAssertEqual(presentation.primaryText, "recovered text")
        XCTAssertNil(presentation.secondaryText)
        XCTAssertEqual(presentation.recoveryMarkerText, "已重新转写")
        XCTAssertTrue(presentation.canCopyAndPaste)
        XCTAssertFalse(presentation.showsRetryAtRest)
    }
}
