import XCTest
@testable import VoiceInputApp

final class OnboardingFlowTests: XCTestCase {
    // Was welcome → prepare → howTo. The 2026-10-10 redesign split the how-to card into an
    // illustrated hold-Fn page and a practice page, and added the feature switches page.
    func testStepsRunWelcomePrepareHoldFnPracticeFeatures() {
        XCTAssertEqual(OnboardingStep.allCases, [.welcome, .prepare, .holdFn, .practice, .features])

        XCTAssertTrue(OnboardingStep.welcome.isFirst)
        XCTAssertFalse(OnboardingStep.welcome.isLast)
        XCTAssertTrue(OnboardingStep.features.isLast)
        XCTAssertFalse(OnboardingStep.features.isFirst)

        XCTAssertEqual(OnboardingStep.welcome.next, .prepare)
        XCTAssertEqual(OnboardingStep.prepare.next, .holdFn)
        XCTAssertEqual(OnboardingStep.holdFn.next, .practice)
        XCTAssertEqual(OnboardingStep.practice.next, .features)
        XCTAssertNil(OnboardingStep.features.next)

        XCTAssertNil(OnboardingStep.welcome.previous)
        XCTAssertEqual(OnboardingStep.prepare.previous, .welcome)
        XCTAssertEqual(OnboardingStep.features.previous, .practice)
    }

    // First version unlocked Continue during the download. Owner decision (2026-10-11): the
    // next page invites pressing Fn, so Continue waits until setup has fully finished.
    func testContinueUnlocksOnlyWhenSetupIsReady() {
        XCTAssertTrue(OnboardingPrepareState.ready.allowsContinue)
        for stage in [PreparationStage.preparingRuntime, .startingHelper, .downloadingModel, .loadingModel, .verifying] {
            XCTAssertFalse(OnboardingPrepareState.running(stage, 0.4).allowsContinue, "\(stage)")
        }
        XCTAssertFalse(OnboardingPrepareState.idle.allowsContinue)
        XCTAssertFalse(OnboardingPrepareState.running(.inspecting, nil).allowsContinue)
        XCTAssertFalse(OnboardingPrepareState.waitingForPermissions.allowsContinue)
        XCTAssertFalse(OnboardingPrepareState.failed("boom").allowsContinue)
    }

    func testDownloadRouteMapsHelperSources() {
        XCTAssertEqual(OnboardingDownloadRoute(source: "modelscope"), .modelScope)
        XCTAssertEqual(OnboardingDownloadRoute(source: "huggingface"), .huggingFace)
        XCTAssertNil(OnboardingDownloadRoute(source: nil))
        XCTAssertNil(OnboardingDownloadRoute(source: "unknown"))

        let chinese = OnboardingCopy.texts(for: .chinese)
        XCTAssertTrue(chinese.downloadRouteText(.modelScope).contains("国内"))
        XCTAssertTrue(chinese.downloadRouteText(.huggingFace).contains("国际"))
        XCTAssertTrue(chinese.prepareVPNHint.contains("VPN"))
        XCTAssertTrue(OnboardingCopy.texts(for: .english).prepareVPNHint.contains("VPN"))
    }

    func testPracticeStateFollowsDictationEvents() {
        var state = OnboardingPracticeState.waiting
        XCTAssertFalse(state.isHoldingKey)

        state = state.applying(.listening)
        XCTAssertEqual(state, .listening)
        XCTAssertTrue(state.isHoldingKey)

        state = state.applying(.transcribing)
        XCTAssertEqual(state, .transcribing)

        state = state.applying(.result("  今天天气不错。 \n"))
        XCTAssertEqual(state, .succeeded("今天天气不错。"))

        XCTAssertEqual(state.applying(.tooShort), .tooShort)
        XCTAssertEqual(state.applying(.failed("没有检测到语音")), .failed("没有检测到语音"))
        // An empty transcript is not a success.
        XCTAssertEqual(OnboardingPracticeState.transcribing.applying(.result("   ")), .failed(""))
    }

    // Loop lengthened to 8 s with a calm opening (owner feedback 2026-10-11: the press came
    // too abruptly), so the sample moments moved: 4.5 s is still holding now.
    func testHoldFnAnimationPhasesCoverOneLoop() {
        XCTAssertEqual(HoldFnAnimation.phase(at: 0.2), .idle)
        XCTAssertEqual(HoldFnAnimation.phase(at: 1.2), .idle)
        XCTAssertEqual(HoldFnAnimation.phase(at: 2.0), .holding)
        XCTAssertEqual(HoldFnAnimation.phase(at: 5.0), .transcribing)
        XCTAssertEqual(HoldFnAnimation.phase(at: 6.5), .pasted)
        XCTAssertLessThan(6.5, HoldFnAnimation.cycle)
    }

    func testKeyEasesDownAndUpInsteadOfSnapping() {
        XCTAssertEqual(HoldFnAnimation.pressAmount(at: 0.5), 0)
        let halfway = HoldFnAnimation.pressAmount(at: HoldFnAnimation.pressAt + HoldFnAnimation.travel / 2)
        XCTAssertGreaterThan(halfway, 0.2)
        XCTAssertLessThan(halfway, 0.8)
        XCTAssertEqual(HoldFnAnimation.pressAmount(at: 3.0), 1)
        XCTAssertEqual(HoldFnAnimation.pressAmount(at: HoldFnAnimation.releaseAt + 1), 0)
    }

    func testPrepareStateMapsSetupOutcomes() {
        XCTAssertEqual(OnboardingPrepareState.state(for: .prepared, language: .english), .ready)
        XCTAssertEqual(OnboardingPrepareState.state(for: .waitingForPermissions, language: .english), .waitingForPermissions)
        XCTAssertEqual(OnboardingPrepareState.state(for: .waitingForModelDownloadConsent, language: .english), .idle)
        XCTAssertEqual(OnboardingPrepareState.state(for: .waitingForModelDownload, language: .english), .idle)
        XCTAssertEqual(
            OnboardingPrepareState.state(for: .failed("boom"), language: .english),
            .failed("boom")
        )
        if case .failed = OnboardingPrepareState.state(for: .blockedByAppBundle, language: .english) {
        } else {
            XCTFail("blockedByAppBundle should surface as a failure message")
        }

        XCTAssertTrue(OnboardingPrepareState.running(.downloadingModel, 0.5).isRunning)
        XCTAssertFalse(OnboardingPrepareState.ready.isRunning)
        XCTAssertTrue(OnboardingPrepareState.ready.isReady)
        XCTAssertFalse(OnboardingPrepareState.running(.loadingModel, 1).isReady)
    }

    func testPreparedResultBuildsLiveSnapshotWithVerifiedContext() {
        let context = ReadinessContext(
            engine: .qwenLocal,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id
        )
        let report = ReadinessReport(generatedAt: Date(), checks: [])
        let result = ReadinessSetupResult(
            outcome: .prepared,
            report: report,
            verifiedContext: context
        )

        XCTAssertEqual(
            result.verifiedSnapshot,
            ReadinessSnapshot(report: report, context: context, coverage: .live)
        )
    }

    func testHandoffRejectsVerifiedSnapshotWhenCurrentContextChanged() {
        let verifiedSnapshot = ReadinessSnapshot(
            report: ReadinessReport(generatedAt: Date(timeIntervalSince1970: 1), checks: []),
            context: ReadinessContext(
                engine: .qwenLocal,
                selectedModelID: VoiceInputModel.qwen3ASR06B.id
            ),
            coverage: .live
        )
        let currentSnapshot = ReadinessSnapshot(
            report: ReadinessReport(generatedAt: Date(timeIntervalSince1970: 2), checks: []),
            context: ReadinessContext(
                engine: .qwenLocal,
                selectedModelID: VoiceInputModel.qwen3ASR17B.id
            ),
            coverage: .lightweight
        )

        XCTAssertEqual(
            OnboardingReadinessHandoff.resolvedSnapshot(
                completed: verifiedSnapshot,
                current: currentSnapshot
            ),
            currentSnapshot
        )
    }

    func testHandoffKeepsVerifiedSnapshotWhenContextStillMatches() {
        let context = ReadinessContext(
            engine: .qwenLocal,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id
        )
        let verifiedSnapshot = ReadinessSnapshot(
            report: ReadinessReport(generatedAt: Date(timeIntervalSince1970: 1), checks: []),
            context: context,
            coverage: .live
        )
        let currentSnapshot = ReadinessSnapshot(
            report: ReadinessReport(generatedAt: Date(timeIntervalSince1970: 2), checks: []),
            context: context,
            coverage: .lightweight
        )

        XCTAssertEqual(
            OnboardingReadinessHandoff.resolvedSnapshot(
                completed: verifiedSnapshot,
                current: currentSnapshot
            ),
            verifiedSnapshot
        )
    }
}
