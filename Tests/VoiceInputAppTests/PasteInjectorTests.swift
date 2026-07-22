import XCTest
@testable import VoiceInputApp

final class PasteInjectorTests: XCTestCase {
    func testRejectsEmptyOrPunctuationOnlyText() {
        XCTAssertFalse(PasteInjector.isPasteable(""))
        XCTAssertFalse(PasteInjector.isPasteable("   "))
        XCTAssertFalse(PasteInjector.isPasteable("。！？"))
        XCTAssertTrue(PasteInjector.isPasteable("你好 Cursor"))
    }

    @MainActor
    func testDispatchWritesOnceAndPostsOnePairToRequestedProcess() {
        let pasteboard = TestPasteboardWriter(value: "previous")
        let poster = TestPasteShortcutPoster()
        let inputSource = TestPasteInputSourceController()
        let injector = PasteInjector(
            pasteboardWriter: pasteboard,
            shortcutPoster: poster,
            inputSourceController: inputSource
        )

        let result = injector.dispatch("hello Flowtype", to: 42) { true }

        XCTAssertEqual(result.outcome, .eventDispatched)
        XCTAssertEqual(result.eventPairCount, 1)
        XCTAssertEqual(pasteboard.replaceCallCount, 1)
        XCTAssertEqual(pasteboard.value, "hello Flowtype")
        XCTAssertEqual(poster.processIdentifiers, [42])
        XCTAssertEqual(inputSource.prepareCallCount, 1)
    }

    @MainActor
    func testCopyOnlyWritesOnceWithoutPostingShortcut() {
        let pasteboard = TestPasteboardWriter()
        let poster = TestPasteShortcutPoster()
        let injector = PasteInjector(
            pasteboardWriter: pasteboard,
            shortcutPoster: poster,
            inputSourceController: TestPasteInputSourceController()
        )

        let result = injector.copyOnly("manual fallback", reason: .missingTarget)

        XCTAssertEqual(result.outcome, .copiedOnly(reason: .missingTarget))
        XCTAssertEqual(pasteboard.replaceCallCount, 1)
        XCTAssertEqual(pasteboard.value, "manual fallback")
        XCTAssertTrue(poster.processIdentifiers.isEmpty)
    }

    @MainActor
    func testEventConstructionFailureLeavesTranscriptForManualPaste() {
        let pasteboard = TestPasteboardWriter()
        let poster = TestPasteShortcutPoster()
        poster.shouldSucceed = false
        let injector = PasteInjector(
            pasteboardWriter: pasteboard,
            shortcutPoster: poster,
            inputSourceController: TestPasteInputSourceController()
        )

        let result = injector.dispatch("manual fallback", to: 99) { true }

        XCTAssertEqual(result.outcome, .copiedOnly(reason: .eventCreationFailed))
        XCTAssertEqual(result.eventPairCount, 0)
        XCTAssertEqual(pasteboard.value, "manual fallback")
        XCTAssertEqual(poster.processIdentifiers, [99])
    }

    @MainActor
    func testClipboardFailurePostsNoShortcut() {
        let pasteboard = TestPasteboardWriter(value: "previous")
        pasteboard.shouldSucceed = false
        let poster = TestPasteShortcutPoster()
        let injector = PasteInjector(
            pasteboardWriter: pasteboard,
            shortcutPoster: poster,
            inputSourceController: TestPasteInputSourceController()
        )

        let result = injector.dispatch("new transcript", to: 42) { true }

        XCTAssertEqual(result.outcome, .clipboardWriteFailed)
        XCTAssertEqual(pasteboard.value, "previous")
        XCTAssertTrue(poster.processIdentifiers.isEmpty)
    }

    @MainActor
    func testInputSourceTransitionInFlightCopiesButDoesNotPostAgain() async throws {
        let pasteboard = TestPasteboardWriter()
        let poster = TestPasteShortcutPoster()
        let inputSource = TestPasteInputSourceController()
        inputSource.returnsRestoreToken = true
        let injector = PasteInjector(
            pasteboardWriter: pasteboard,
            shortcutPoster: poster,
            inputSourceController: inputSource,
            inputSourceRestoreDelay: 0.01
        )

        XCTAssertEqual(injector.dispatch("first", to: 42) { true }.outcome, .eventDispatched)
        XCTAssertEqual(
            injector.dispatch("second", to: 42) { true }.outcome,
            .copiedOnly(reason: .inputSourceBusy)
        )
        XCTAssertEqual(poster.processIdentifiers, [42])
        XCTAssertEqual(pasteboard.value, "second")

        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(inputSource.restoreCallCount, 1)
        XCTAssertEqual(injector.dispatch("third", to: 42) { true }.outcome, .eventDispatched)
        XCTAssertEqual(poster.processIdentifiers, [42, 42])
    }

    @MainActor
    func testPermanentCopyDoesNotScheduleDelayedRewrite() async throws {
        let pasteboard = TestPasteboardWriter()
        let injector = PasteInjector(
            pasteboardWriter: pasteboard,
            shortcutPoster: TestPasteShortcutPoster(),
            inputSourceController: TestPasteInputSourceController()
        )

        XCTAssertTrue(injector.copyPermanent("diagnostics result"))
        pasteboard.value = "user clipboard change"
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertEqual(pasteboard.value, "user clipboard change")
        XCTAssertEqual(pasteboard.replaceCallCount, 1)
    }

    @MainActor
    func testSuccessfulAutoPasteLeavesOneStableClipboardPublicationAfterRestoreQueueDrains() async throws {
        let pasteboard = TestPasteboardWriter()
        let inputSource = TestPasteInputSourceController()
        inputSource.returnsRestoreToken = true
        let injector = PasteInjector(
            pasteboardWriter: pasteboard,
            shortcutPoster: TestPasteShortcutPoster(),
            inputSourceController: inputSource,
            inputSourceRestoreDelay: 0.01
        )

        let result = injector.dispatch("stable transcript", to: 42) { true }
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertEqual(result.outcome, .eventDispatched)
        XCTAssertEqual(pasteboard.value, "stable transcript")
        XCTAssertEqual(pasteboard.changeCount, 1)
        XCTAssertEqual(pasteboard.replaceCallCount, 1)
        XCTAssertEqual(inputSource.restoreCallCount, 1)
    }
}
