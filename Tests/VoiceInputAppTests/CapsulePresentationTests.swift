import XCTest
@testable import VoiceInputApp

final class CapsulePresentationTests: XCTestCase {
    func testListeningPresentationAnimatesWaveform() {
        let presentation = CapsulePresentation.listening()

        XCTAssertEqual(presentation.text, "Listening...")
        XCTAssertEqual(presentation.waveformMode, .liveAudio)
        XCTAssertTrue(presentation.animatesWaveform)
    }

    func testNonListeningPresentationsDoNotAnimateWaveform() {
        let presentations: [CapsulePresentation] = [
            .transcribing("Transcribing..."),
            .status("Still transcribing..."),
            .result("hello world"),
            .failure("Transcription failed")
        ]

        XCTAssertTrue(presentations.allSatisfy { !$0.animatesWaveform })
        XCTAssertEqual(presentations.map(\.text), [
            "Transcribing...",
            "Still transcribing...",
            "hello world",
            "Transcription failed"
        ])
    }

    func testCapsuleMotionStaysWithinFrequentInteractionBudget() {
        XCTAssertEqual(CapsuleMotion.showDuration, 0.18)
        XCTAssertEqual(CapsuleMotion.hideDuration, 0.14)
        XCTAssertEqual(CapsuleMotion.updateDuration, 0.18)
        XCTAssertLessThan(CapsuleMotion.showDuration, 0.30)
        XCTAssertLessThan(CapsuleMotion.hideDuration, CapsuleMotion.showDuration)
    }

    func testCapsuleFrameMotionRespectsReduceMotion() {
        XCTAssertTrue(CapsuleMotion.animatesFrame(reduceMotion: false))
        XCTAssertFalse(CapsuleMotion.animatesFrame(reduceMotion: true))
        XCTAssertEqual(CapsuleMotion.reducedMotionFadeDuration, 0.12)
    }

    func testWaveformUsesMeteredLevelWithoutSecondSmoothing() {
        XCTAssertEqual(WaveformResponse.displayedLevel(for: -0.2), 0)
        XCTAssertEqual(WaveformResponse.displayedLevel(for: 0.62), 0.62)
        XCTAssertEqual(WaveformResponse.displayedLevel(for: 1.4), 1)
        XCTAssertEqual(WaveformResponse.frameAnimationDuration, 0.04)
    }

    func testWaveformUsesFiveStableSymmetricBarsWithIntermediateLevels() {
        let quiet = WaveformResponse.barFractions(for: 0.20)
        let normal = WaveformResponse.barFractions(for: 0.50)
        let loud = WaveformResponse.barFractions(for: 0.80)

        XCTAssertEqual(WaveformResponse.barCount, 5)
        XCTAssertEqual(quiet.count, 5)
        XCTAssertEqual(normal, Array(normal.reversed()))
        XCTAssertGreaterThan(normal[2], normal[0])
        XCTAssertLessThan(quiet[2], normal[2])
        XCTAssertLessThan(normal[2], loud[2])
        XCTAssertLessThan(loud[0], loud[2])
        XCTAssertLessThan(WaveformResponse.totalBarWidth, 44)
    }
}
