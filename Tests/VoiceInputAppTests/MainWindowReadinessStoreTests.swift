import XCTest
@testable import VoiceInputApp

@MainActor
final class MainWindowReadinessStoreTests: XCTestCase {
    func testConcurrentLiveRefreshesAreDeduplicated() async {
        var callCount = 0
        let liveReport = report(status: .ready)
        let store = makeStore(liveRefresh: {
            callCount += 1
            try? await Task.sleep(nanoseconds: 50_000_000)
            return liveReport
        })

        let first = Task { await store.refreshLive() }
        let second = Task { await store.refreshLive() }
        await first.value
        await second.value

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(store.snapshot.coverage, .live)
    }

    func testEmptyRefreshRetainsPreviousSnapshotAndReportsFailure() async {
        let initial = snapshot(report: report(status: .notReady))
        let store = MainWindowReadinessStore(
            initialSnapshot: initial,
            refreshLightweight: { ReadinessReport(generatedAt: Date(), checks: []) },
            refreshLive: { ReadinessReport(generatedAt: Date(), checks: []) }
        )

        await store.refreshLive()

        XCTAssertEqual(store.snapshot, initial)
        XCTAssertTrue(store.didLastRefreshFail)
    }

    func testRefreshKeepsTheCurrentSnapshotVisibleWhileLiveWorkRuns() async {
        let initial = snapshot(report: report(status: .notReady))
        let store = MainWindowReadinessStore(
            initialSnapshot: initial,
            refreshLightweight: { self.report(status: .notReady) },
            refreshLive: {
                try? await Task.sleep(nanoseconds: 80_000_000)
                return self.report(status: .ready)
            }
        )

        let refresh = Task { await store.refreshLive() }
        await Task.yield()

        XCTAssertTrue(store.isRefreshing)
        XCTAssertEqual(store.snapshot, initial)

        await refresh.value
        XCTAssertFalse(store.isRefreshing)
        XCTAssertEqual(store.snapshot.coverage, .live)
    }

    func testReplacingContextImmediatelyReturnsToLightweightChecking() {
        let store = makeStore(liveRefresh: { self.report(status: .ready) })
        let appleSnapshot = ReadinessSnapshot(
            report: report(status: .ready, includeSpeech: true),
            context: ReadinessContext(engine: .appleSpeech, selectedModelID: VoiceInputModel.qwen3ASR06B.id),
            coverage: .lightweight
        )

        store.replace(with: appleSnapshot)

        XCTAssertEqual(store.snapshot.context.engine, .appleSpeech)
        XCTAssertEqual(store.presentation.phase, .checking)
    }

    private func makeStore(
        liveRefresh: @escaping () async -> ReadinessReport
    ) -> MainWindowReadinessStore {
        MainWindowReadinessStore(
            initialSnapshot: snapshot(report: report(status: .notReady)),
            refreshLightweight: { self.report(status: .notReady) },
            refreshLive: liveRefresh
        )
    }

    private func snapshot(report: ReadinessReport) -> ReadinessSnapshot {
        ReadinessSnapshot(
            report: report,
            context: ReadinessContext(engine: .qwenLocal, selectedModelID: VoiceInputModel.qwen3ASR06B.id),
            coverage: .lightweight
        )
    }

    private func report(
        status: ReadinessStatus,
        includeSpeech: Bool = false
    ) -> ReadinessReport {
        var checks = [
            ReadinessCheck(id: "app", group: .appBundle, title: "App", detail: "", status: .ready),
            ReadinessCheck(id: "runtime", group: .localRuntime, title: "Runtime", detail: "", status: .ready),
            ReadinessCheck(id: "microphone-permission", group: .permissions, title: "Mic", detail: "", status: status),
            ReadinessCheck(id: "accessibility-permission", group: .permissions, title: "Accessibility", detail: "", status: .ready),
            ReadinessCheck(id: "model-qwen3-asr-0.6b", group: .models, title: "Model", detail: "", status: .ready),
            ReadinessCheck(id: "model-qwen3-asr-0.6b-warm", group: .models, title: "Warm", detail: "", status: .ready)
        ]
        if includeSpeech {
            checks.append(ReadinessCheck(
                id: "speech-recognition-permission",
                group: .permissions,
                title: "Speech",
                detail: "",
                status: .ready
            ))
        }
        return ReadinessReport(generatedAt: Date(), checks: checks)
    }
}
