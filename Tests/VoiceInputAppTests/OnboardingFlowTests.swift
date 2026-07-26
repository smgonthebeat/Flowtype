import XCTest
@testable import VoiceInputApp

final class OnboardingFlowTests: XCTestCase {
    func testStepsRunWelcomePrepareHowTo() {
        XCTAssertEqual(OnboardingStep.allCases, [.welcome, .prepare, .howTo])

        XCTAssertTrue(OnboardingStep.welcome.isFirst)
        XCTAssertFalse(OnboardingStep.welcome.isLast)
        XCTAssertTrue(OnboardingStep.howTo.isLast)
        XCTAssertFalse(OnboardingStep.howTo.isFirst)

        XCTAssertEqual(OnboardingStep.welcome.next, .prepare)
        XCTAssertEqual(OnboardingStep.prepare.next, .howTo)
        XCTAssertNil(OnboardingStep.howTo.next)

        XCTAssertNil(OnboardingStep.welcome.previous)
        XCTAssertEqual(OnboardingStep.prepare.previous, .welcome)
        XCTAssertEqual(OnboardingStep.howTo.previous, .prepare)
    }

    func testPrepareStateMapsSetupOutcomes() {
        XCTAssertEqual(OnboardingPrepareState.state(for: .prepared), .ready)
        XCTAssertEqual(OnboardingPrepareState.state(for: .waitingForPermissions), .waitingForPermissions)
        XCTAssertEqual(OnboardingPrepareState.state(for: .waitingForModelDownloadConsent), .idle)
        XCTAssertEqual(OnboardingPrepareState.state(for: .waitingForModelDownload), .idle)
        XCTAssertEqual(
            OnboardingPrepareState.state(for: .failed("boom")),
            .failed("boom")
        )
        if case .failed = OnboardingPrepareState.state(for: .blockedByAppBundle) {
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
