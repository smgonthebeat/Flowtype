import XCTest
@testable import VoiceInputApp

final class CapsulePresentationTests: XCTestCase {
    func testListeningPresentationAnimatesWaveform() {
        // design-spec 5.10: the default argument is gone; the text comes from AppCopy with a real ellipsis.
        let presentation = CapsulePresentation.listening(AppCopy.texts(for: .english).capsuleListening)

        XCTAssertEqual(presentation.text, "Listening…")
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

    func testKindsSeparateListeningTranscribingAndFailure() {
        XCTAssertEqual(CapsulePresentation.listening("a").kind, .listening)
        XCTAssertEqual(CapsulePresentation.transcribing("a").kind, .transcribing)
        XCTAssertEqual(CapsulePresentation.status("a").kind, .info)
        XCTAssertEqual(CapsulePresentation.result("a").kind, .confirmation)
        XCTAssertEqual(CapsulePresentation.failure("a").kind, .failure)

        XCTAssertTrue(CapsulePresentation.transcribing("a").pulsesWaveform)
        XCTAssertFalse(CapsulePresentation.listening("a").pulsesWaveform)
        XCTAssertFalse(CapsulePresentation.status("a").showsWaveform)
        XCTAssertFalse(CapsulePresentation.failure("a").showsWaveform)
    }

    func testCountdownKeepsTheLiveWaveform() {
        let countdown = CapsulePresentation.listeningCountdown(AppCopy.texts(for: .chinese).capsuleSecondsLeft(15))

        XCTAssertEqual(countdown.text, "还剩 15 秒")
        XCTAssertEqual(countdown.kind, .warning)
        XCTAssertTrue(countdown.animatesWaveform)
        XCTAssertTrue(countdown.showsWaveform)
    }

    func testCapsuleCopyIsLocalisedWithRealEllipses() {
        let chinese = AppCopy.texts(for: .chinese)

        XCTAssertEqual(chinese.capsuleListening, "正在聆听…")
        XCTAssertEqual(chinese.capsuleTranscribing, "正在转写…")
        XCTAssertEqual(chinese.capsulePreparingModel, "正在准备模型…")
        XCTAssertEqual(chinese.capsuleFailureText(for: .noSpeechDetected), "没有检测到语音")
        XCTAssertEqual(AppCopy.texts(for: .english).capsuleFailureText(for: .transcriptionFailed), "Transcription failed")
        XCTAssertFalse(chinese.capsuleTimeLimitReached.contains("..."))
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

    // Owner choice "V2" (2026-10-03) replaces the five thick bars with nine thin ones: overall
    // height follows the level, each bar moves at its own pace, and the edges are never starved.
    func testWaveformUsesNineThinBarsThatFollowTheLevelAndMoveIndependently() {
        XCTAssertEqual(WaveformResponse.barCount, 9)
        XCTAssertLessThan(WaveformResponse.totalBarWidth, 44)
        XCTAssertEqual(WaveformResponse.barWeights, Array(WaveformResponse.barWeights.reversed()))
        XCTAssertGreaterThanOrEqual(WaveformResponse.barWeights.min() ?? 0, 0.6)

        let silent = WaveformResponse.barFractions(for: 0, at: 1.3)
        XCTAssertTrue(silent.allSatisfy { $0 == WaveformResponse.minimumBarFraction })

        func average(_ level: CGFloat) -> CGFloat {
            let samples = stride(from: 0.0, to: 2.0, by: 0.05).flatMap { WaveformResponse.barFractions(for: level, at: $0) }
            return samples.reduce(0, +) / CGFloat(samples.count)
        }
        XCTAssertLessThan(average(0.2), average(0.5))
        XCTAssertLessThan(average(0.5), average(0.8))

        let frame = WaveformResponse.barFractions(for: 0.6, at: 0.7)
        XCTAssertTrue(frame.allSatisfy { $0 >= WaveformResponse.minimumBarFraction && $0 <= 1 })
        XCTAssertNotEqual(frame, WaveformResponse.barFractions(for: 0.6, at: 0.9))
    }

    func testNoSpeechIsItsOwnKindWithoutAWaveform() {
        let presentation = CapsulePresentation.noSpeech(AppCopy.texts(for: .chinese).capsuleNoSpeechDetected)

        XCTAssertEqual(presentation.kind, .noSpeech)
        XCTAssertEqual(presentation.text, "没有检测到语音")
        XCTAssertFalse(presentation.showsWaveform)
        XCTAssertFalse(presentation.animatesWaveform)
    }

    func testGradientPaletteRunsFromFirstToLastStopAcrossTheBars() {
        // Owner choice "3" (2026-10-12): bars take the Flowtype blend leading to trailing.
        let stops = FlowtypeAccent.fillStops
        let bars = WaveformPalette.colors(stops: stops, count: WaveformResponse.barCount)

        XCTAssertEqual(bars.count, 9)
        XCTAssertEqual(bars.first, HexColor.components(stops[0]))
        XCTAssertEqual(bars[4], HexColor.components(stops[1]))
        XCTAssertEqual(bars.last, HexColor.components(stops[2]))
        // Between stops the blend moves steadily: bar 2 sits halfway from peach to lilac.
        let peach = HexColor.components(stops[0])
        let lilac = HexColor.components(stops[1])
        XCTAssertEqual(bars[2].red, (peach.red + lilac.red) / 2, accuracy: 1e-9)
        XCTAssertEqual(bars[2].blue, (peach.blue + lilac.blue) / 2, accuracy: 1e-9)
    }

    func testGradientPaletteGivesEachTranscribingDotOneStop() {
        let stops = FlowtypeAccent.fillStops
        let dots = WaveformPalette.colors(stops: stops, count: WaveformResponse.dotCount)

        XCTAssertEqual(dots, stops.map(HexColor.components))
    }

    func testGradientPaletteHandlesDegenerateInput() {
        XCTAssertEqual(WaveformPalette.colors(stops: ["#FBD8C3"], count: 3), Array(repeating: HexColor.components("#FBD8C3"), count: 3))
        XCTAssertEqual(WaveformPalette.colors(stops: FlowtypeAccent.fillStops, count: 1), [HexColor.components("#FBD8C3")])
        XCTAssertTrue(WaveformPalette.colors(stops: [], count: 9).isEmpty)
        XCTAssertTrue(WaveformPalette.colors(stops: FlowtypeAccent.fillStops, count: 0).isEmpty)
    }
}
