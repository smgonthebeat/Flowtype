import XCTest
@testable import VoiceInputApp

final class AppleSpeechEngineTests: XCTestCase {
    func testLocaleIdentifierUsesEnglishLocaleForEnglishMode() {
        XCTAssertEqual(
            AppleSpeechEngine.localeIdentifier(
                for: .english,
                configuredLocaleIdentifier: "zh-CN"
            ),
            "en-US"
        )
    }

    func testLocaleIdentifierUsesConfiguredLocaleForChineseAndMixedModes() {
        XCTAssertEqual(
            AppleSpeechEngine.localeIdentifier(
                for: .chinese,
                configuredLocaleIdentifier: "zh-TW"
            ),
            "zh-TW"
        )
        XCTAssertEqual(
            AppleSpeechEngine.localeIdentifier(
                for: .mixedChineseEnglish,
                configuredLocaleIdentifier: "zh-TW"
            ),
            "zh-TW"
        )
    }
}
