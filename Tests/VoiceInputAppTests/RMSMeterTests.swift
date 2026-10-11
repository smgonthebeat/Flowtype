import XCTest
@testable import VoiceInputApp

final class RMSMeterTests: XCTestCase {
    func testAttackRisesFasterThanReleaseFalls() {
        var meter = RMSMeter()
        let quiet = meter.smoothedLevel(forRMS: 0.0)
        let loud = meter.smoothedLevel(forRMS: 1.0)
        let release = meter.smoothedLevel(forRMS: 0.0)

        XCTAssertGreaterThan(loud, quiet)
        XCTAssertGreaterThan(release, quiet)
        XCTAssertLessThan(release, loud)
    }

    func testBarHeightsKeepMiddleTallest() {
        var meter = RMSMeter()
        let heights = meter.barHeights(forRMS: 0.8, maxHeight: 30)

        XCTAssertEqual(heights.count, 5)
        XCTAssertGreaterThan(heights[2], heights[0])
        XCTAssertGreaterThan(heights[2], heights[4])
        XCTAssertTrue(heights.allSatisfy { $0 >= 4 && $0 <= 30 })
    }

    func testPerceptualNormalizationPreservesNoiseFloorAndCeiling() {
        // Owner feedback 2026-10-03 (waveform not sensitive enough): floor -50 -> -55 dB, ceiling -10 -> -12 dB.
        XCTAssertEqual(RMSMeter.normalizedInputLevel(forRMS: rms(atDecibels: -55)), 0, accuracy: 0.0001)
        XCTAssertEqual(RMSMeter.normalizedInputLevel(forRMS: rms(atDecibels: -12)), 1, accuracy: 0.0001)

        let quiet = RMSMeter.normalizedInputLevel(forRMS: rms(atDecibels: -40))
        let normal = RMSMeter.normalizedInputLevel(forRMS: rms(atDecibels: -30))
        let loud = RMSMeter.normalizedInputLevel(forRMS: rms(atDecibels: -20))

        XCTAssertLessThan(quiet, normal)
        XCTAssertLessThan(normal, loud)
        XCTAssertLessThan(loud, 0.85)
    }

    func testNormalizedLevelRespondsOnFirstSpeechBuffer() {
        var meter = RMSMeter()

        let firstSpeechLevel = meter.normalizedLevel(forRMS: rms(atDecibels: -30))

        // Owner feedback 2026-10-03: recalibrated range (-55..-12 dB) with attack 0.5 makes the
        // first -30 dB buffer reach about 0.32 (was about 0.32 with the old range and attack 0.55).
        XCTAssertGreaterThan(firstSpeechLevel, 0.30)
        XCTAssertLessThan(firstSpeechLevel, 0.35)
        XCTAssertLessThan(firstSpeechLevel, 1.0)
    }

    private func rms(atDecibels decibels: Double) -> Double {
        pow(10, decibels / 20)
    }
}
