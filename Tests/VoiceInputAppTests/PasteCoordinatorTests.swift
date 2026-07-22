import XCTest
@testable import VoiceInputApp

final class PasteCoordinatorTests: XCTestCase {
    @MainActor
    func testSameAttemptIDIsConsumedBeforeAwaitAndHasOneSideEffect() async {
        let pasteboard = TestPasteboardWriter()
        let poster = TestPasteShortcutPoster()
        let telemetry = TestPasteTelemetryRecorder()
        let coordinator = makeCoordinator(
            pasteboard: pasteboard,
            poster: poster,
            telemetry: telemetry
        )
        let target = PasteTargetIdentity(processIdentifier: 42, bundleIdentifier: "com.example.Editor")
        let attempt = PasteAttempt(
            id: UUID(),
            source: .dictation,
            text: "exactly once",
            target: target
        )
        var suspendedResolver: CheckedContinuation<PasteTargetIdentity?, Never>?
        let firstTask = Task { @MainActor in
            await coordinator.perform(attempt) { _ in
                await withCheckedContinuation { continuation in
                    suspendedResolver = continuation
                }
            } validateTarget: { _ in
                true
            }
        }
        while suspendedResolver == nil {
            await Task.yield()
        }
        let duplicate = await coordinator.perform(attempt) { captured in
            XCTFail("Duplicate attempt must not invoke the resolver")
            return captured
        } validateTarget: { _ in
            XCTFail("Duplicate attempt must not invoke final validation")
            return true
        }
        suspendedResolver?.resume(returning: target)
        let first = await firstTask.value

        XCTAssertEqual(first, .eventDispatched)
        XCTAssertEqual(duplicate, .duplicateIgnored)
        XCTAssertTrue(first.ownsPresentationCompletion)
        XCTAssertFalse(duplicate.ownsPresentationCompletion)
        XCTAssertEqual(pasteboard.replaceCallCount, 1)
        XCTAssertEqual(poster.processIdentifiers, [42])
        XCTAssertEqual(telemetry.events.map(\.outcome), [.duplicateIgnored, .eventDispatched])
        XCTAssertEqual(telemetry.events.map(\.eventPairCount), [0, 1])
    }

    @MainActor
    func testMissingTargetCopiesOnly() async {
        let pasteboard = TestPasteboardWriter()
        let poster = TestPasteShortcutPoster()
        let coordinator = makeCoordinator(pasteboard: pasteboard, poster: poster)
        let attempt = PasteAttempt(
            id: UUID(),
            source: .dictation,
            text: "copy fallback",
            target: nil
        )

        let outcome = await coordinator.perform(attempt) { _ in
            XCTFail("Missing target must not be resolved")
            return nil
        } validateTarget: { _ in
            XCTFail("Missing target must not be validated")
            return false
        }

        XCTAssertEqual(outcome, .copiedOnly(reason: .missingTarget))
        XCTAssertEqual(pasteboard.value, "copy fallback")
        XCTAssertTrue(poster.processIdentifiers.isEmpty)
    }

    @MainActor
    func testRejectedTargetCopiesOnlyWithoutShortcut() async {
        let pasteboard = TestPasteboardWriter()
        let poster = TestPasteShortcutPoster()
        let coordinator = makeCoordinator(pasteboard: pasteboard, poster: poster)
        let target = PasteTargetIdentity(processIdentifier: 42, bundleIdentifier: "com.example.Editor")
        let attempt = PasteAttempt(
            id: UUID(),
            source: .history,
            text: "copy after rejection",
            target: target
        )

        let outcome = await coordinator.perform(attempt) { _ in nil } validateTarget: { _ in
            XCTFail("Rejected target must not reach final validation")
            return false
        }

        XCTAssertEqual(outcome, .copiedOnly(reason: .targetRejected))
        XCTAssertEqual(pasteboard.replaceCallCount, 1)
        XCTAssertTrue(poster.processIdentifiers.isEmpty)
    }

    @MainActor
    func testDifferentExplicitAttemptIDsRemainAllowed() async {
        let pasteboard = TestPasteboardWriter()
        let poster = TestPasteShortcutPoster()
        let coordinator = makeCoordinator(pasteboard: pasteboard, poster: poster)
        let target = PasteTargetIdentity(processIdentifier: 42, bundleIdentifier: "com.example.Editor")

        for text in ["first click", "second click"] {
            let outcome = await coordinator.perform(PasteAttempt(
                id: UUID(),
                source: .history,
                text: text,
                target: target
            )) { $0 } validateTarget: { _ in true }
            XCTAssertEqual(outcome, .eventDispatched)
        }

        XCTAssertEqual(pasteboard.replaceCallCount, 2)
        XCTAssertEqual(poster.processIdentifiers, [42, 42])
    }

    @MainActor
    func testSameCopyOnlyAttemptIDWritesClipboardOnlyOnce() async {
        let pasteboard = TestPasteboardWriter()
        let poster = TestPasteShortcutPoster()
        let coordinator = makeCoordinator(pasteboard: pasteboard, poster: poster)
        let attempt = PasteAttempt(
            id: UUID(),
            source: .dictation,
            text: "manual fallback",
            target: nil
        )

        let first = await coordinator.perform(attempt) { _ in nil } validateTarget: { _ in false }
        let duplicate = await coordinator.perform(attempt) { _ in nil } validateTarget: { _ in false }

        XCTAssertEqual(first, .copiedOnly(reason: .missingTarget))
        XCTAssertEqual(duplicate, .duplicateIgnored)
        XCTAssertEqual(pasteboard.replaceCallCount, 1)
        XCTAssertEqual(pasteboard.value, "manual fallback")
        XCTAssertTrue(poster.processIdentifiers.isEmpty)
    }

    @MainActor
    func testTargetLosingFocusDuringInputSourcePreparationCopiesOnly() async throws {
        let pasteboard = TestPasteboardWriter()
        let poster = TestPasteShortcutPoster()
        let inputSource = TestPasteInputSourceController()
        let telemetry = TestPasteTelemetryRecorder()
        var targetIsStillValid = true
        inputSource.returnsRestoreToken = true
        inputSource.onPrepare = {
            targetIsStillValid = false
        }
        let coordinator = PasteCoordinator(injector: PasteInjector(
            pasteboardWriter: pasteboard,
            shortcutPoster: poster,
            inputSourceController: inputSource,
            inputSourceRestoreDelay: 0.01
        ), telemetry: telemetry)
        let target = PasteTargetIdentity(processIdentifier: 42, bundleIdentifier: "com.example.Editor")

        let outcome = await coordinator.perform(PasteAttempt(
            id: UUID(),
            source: .dictation,
            text: "focus changed",
            target: target
        )) { $0 } validateTarget: { _ in
            targetIsStillValid
        }

        XCTAssertEqual(outcome, .copiedOnly(reason: .targetRejected))
        XCTAssertEqual(pasteboard.value, "focus changed")
        XCTAssertTrue(poster.processIdentifiers.isEmpty)
        XCTAssertEqual(telemetry.events.last?.frontmostMatch, false)
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(inputSource.restoreCallCount, 1)
    }

    @MainActor
    private func makeCoordinator(
        pasteboard: TestPasteboardWriter,
        poster: TestPasteShortcutPoster,
        telemetry: TestPasteTelemetryRecorder = TestPasteTelemetryRecorder()
    ) -> PasteCoordinator {
        PasteCoordinator(injector: PasteInjector(
            pasteboardWriter: pasteboard,
            shortcutPoster: poster,
            inputSourceController: TestPasteInputSourceController()
        ), telemetry: telemetry)
    }
}
