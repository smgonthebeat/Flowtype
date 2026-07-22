import XCTest
@testable import VoiceInputApp

final class SettingsPresentationTests: XCTestCase {
    func testPrimaryEngineTracksSelectedModel() {
        XCTAssertEqual(
            SettingsPresentation.primaryEngineName(selectedModelID: VoiceInputModel.qwen3ASR17B.id),
            "Qwen3-ASR 1.7B Local"
        )
    }

    func testStoragePathsUseFlowtypeApplicationSupportRoot() {
        let root = URL(fileURLWithPath: "/tmp/Flowtype-Test-Support", isDirectory: true)

        XCTAssertEqual(
            SettingsPresentation.modelsRootPath(applicationSupportRoot: root),
            root.appendingPathComponent("Models", isDirectory: true).path
        )
        XCTAssertEqual(
            SettingsPresentation.retainedRecordingsPath(applicationSupportRoot: root),
            root.appendingPathComponent("Recordings", isDirectory: true).path
        )
    }
}
