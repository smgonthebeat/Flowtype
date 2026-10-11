import XCTest
@testable import VoiceInputApp

final class SettingsLimitOptionsTests: XCTestCase {
    func testPresetsCoverTheDefaultsAndTheStoredRange() {
        XCTAssertTrue(SettingsLimitOptions.recordingDurationPresets.contains(SettingsLimitOptions.defaultRecordingDuration))
        XCTAssertTrue(SettingsLimitOptions.historyLimitPresets.contains(SettingsLimitOptions.defaultHistoryLimit))
        // SettingsStore clamps the recording limit to 30...600, so both ends must be choosable.
        XCTAssertEqual(SettingsLimitOptions.recordingDurationPresets.first, 30)
        XCTAssertEqual(SettingsLimitOptions.recordingDurationPresets.last, 600)
    }

    func testValueFromTheOldStepperStaysSelectable() {
        // The retired stepper moved in 30-second steps, so 150 may already be stored.
        XCTAssertEqual(
            SettingsLimitOptions.recordingDurations(including: 150),
            [30, 60, 90, 120, 150, 180, 240, 300, 420, 600]
        )
        XCTAssertEqual(SettingsLimitOptions.recordingDurations(including: 180), SettingsLimitOptions.recordingDurationPresets)
        XCTAssertEqual(SettingsLimitOptions.historyLimits(including: 41), [10, 25, 41, 50, 100, 200, 300, 500])
    }

    func testLabelsFollowTheInterfaceLanguageAndMarkTheDefault() {
        XCTAssertEqual(SettingsLimitOptions.durationLabel(seconds: 30, language: .chinese), "30 秒")
        XCTAssertEqual(SettingsLimitOptions.durationLabel(seconds: 90, language: .chinese), "1 分 30 秒")
        XCTAssertEqual(SettingsLimitOptions.durationLabel(seconds: 180, language: .chinese), "3 分钟（默认）")
        XCTAssertEqual(SettingsLimitOptions.durationLabel(seconds: 90, language: .english), "1 min 30 sec")
        XCTAssertEqual(SettingsLimitOptions.durationLabel(seconds: 600, language: .english), "10 min")
        XCTAssertEqual(SettingsLimitOptions.historyLabel(entries: 100, language: .english), "100 entries (default)")
        XCTAssertEqual(SettingsLimitOptions.historyLabel(entries: 50, language: .chinese), "50 条")
    }
}
