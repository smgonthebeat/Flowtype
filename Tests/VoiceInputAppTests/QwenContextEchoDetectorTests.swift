import XCTest
@testable import VoiceInputApp

final class QwenContextEchoDetectorTests: XCTestCase {
    private let hotwordList = "DEMO1001, TEST2045, Qwen, alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota, kappa, lambda, markdown, parser, renderer, sample phrase, test fixture, workflow, Example University."
    private let context = "Important terms to preserve exactly: DEMO1001, TEST2045, Qwen, alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota, kappa, lambda, markdown, parser, renderer, sample phrase, test fixture, workflow, Example University."

    func testFlagsPromptPrefixEvenWhenTranscriptIsShort() {
        let shortContext = "Important terms to preserve exactly:"

        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                shortContext,
                context: shortContext,
                recordingDuration: 30
            )
        )
    }

    func testDetectsShortHotwordListEcho() {
        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                hotwordList,
                context: context,
                recordingDuration: 1.4
            )
        )
    }

    func testDoesNotFlagShortTranscriptWithOneHotword() {
        XCTAssertFalse(
            QwenContextEchoDetector.isLikelyEcho(
                "Open the Qwen cheat sheet.",
                context: context,
                recordingDuration: 1.4
            )
        )
    }

    func testFlagsLongRecordingWhenItIsOnlyHotwordList() {
        XCTAssertTrue(
            QwenContextEchoDetector.isLikelyEcho(
                hotwordList,
                context: context,
                recordingDuration: 30
            )
        )
    }
}
