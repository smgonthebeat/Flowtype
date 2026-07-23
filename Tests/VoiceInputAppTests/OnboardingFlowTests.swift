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
}
