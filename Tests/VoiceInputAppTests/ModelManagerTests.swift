import XCTest
@testable import VoiceInputApp

final class ModelManagerTests: XCTestCase {
    func testModelDirectoryUsesApplicationSupport() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let manager = ModelManager(applicationSupportRoot: root)

        XCTAssertEqual(manager.model.id, "qwen3-asr-0.6b")
        XCTAssertEqual(manager.model.modelID, "Qwen/Qwen3-ASR-0.6B")
        XCTAssertEqual(manager.model.displayName, "Qwen3-ASR 0.6B")
        XCTAssertTrue(manager.modelDirectory.path.contains("qwen3-asr-0.6b"))
        XCTAssertTrue(manager.huggingFaceHome.path.hasPrefix(manager.modelDirectory.path))
        XCTAssertTrue(manager.transformersCache.path.hasPrefix(manager.modelDirectory.path))
        XCTAssertFalse(manager.isModelInstalled)
    }

    func testReadyMarkerRequiresReadyContents() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let manager = ModelManager(applicationSupportRoot: root)

        try manager.ensureDirectories()
        try "partial".write(to: manager.markerFile, atomically: true, encoding: .utf8)

        XCTAssertFalse(manager.isModelInstalled)
    }

    func testValidHuggingFaceSnapshotCountsAsInstalled() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let manager = ModelManager(applicationSupportRoot: root)
        let snapshotDirectory = manager.huggingFaceHubModelDirectory
            .appendingPathComponent("snapshots", isDirectory: true)
            .appendingPathComponent("test-snapshot", isDirectory: true)

        try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        try "{}".write(to: snapshotDirectory.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try Data("weights".utf8).write(to: snapshotDirectory.appendingPathComponent("model.safetensors"))

        XCTAssertTrue(manager.isModelInstalled)
    }

    func testPartialHuggingFaceSnapshotNeedsRepair() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let manager = ModelManager(applicationSupportRoot: root)
        let snapshotDirectory = manager.huggingFaceHubModelDirectory
            .appendingPathComponent("snapshots", isDirectory: true)
            .appendingPathComponent("partial-snapshot", isDirectory: true)

        try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        try "{}".write(to: snapshotDirectory.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        XCTAssertFalse(manager.isModelInstalled)
        XCTAssertTrue(manager.needsRepair)
    }

    func testEmptyHuggingFaceSnapshotDirectoryDoesNotCountAsInstalled() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let manager = ModelManager(applicationSupportRoot: root)
        let snapshotsDirectory = manager.huggingFaceHubModelDirectory
            .appendingPathComponent("snapshots", isDirectory: true)

        try FileManager.default.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)

        XCTAssertFalse(manager.isModelInstalled)
        XCTAssertFalse(manager.needsRepair)
    }

    func testMarkerAloneDoesNotCountAsInstalled() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let manager = ModelManager(applicationSupportRoot: root)

        XCTAssertFalse(manager.isModelInstalled)

        try manager.markInstalled()

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.modelDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.markerFile.path, isDirectory: &isDirectory))
        XCTAssertFalse(isDirectory.boolValue)
        XCTAssertFalse(manager.isModelInstalled)
        XCTAssertTrue(manager.needsRepair)
    }

    func testResetModelStorageRemovesPartialCache() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let manager = ModelManager(applicationSupportRoot: root)
        try manager.ensureDirectories()
        try "partial".write(to: manager.modelDirectory.appendingPathComponent("partial.bin"), atomically: true, encoding: .utf8)

        XCTAssertTrue(manager.needsRepair)

        try manager.resetModelStorage()

        XCTAssertFalse(manager.isModelInstalled)
        XCTAssertFalse(manager.needsRepair)
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.modelDirectory.path))
    }

    func testHelperLaunchEnvironmentPointsToManagedModelDirectory() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let manager = ModelManager(applicationSupportRoot: root)
        let helperProcessManager = HelperProcessManager(modelManager: manager)

        let environment = helperProcessManager.launchEnvironment(port: 49152, authToken: "test-token")

        XCTAssertEqual(environment["VOICEINPUT_HELPER_PORT"], "49152")
        XCTAssertEqual(environment["VOICEINPUT_HELPER_TOKEN"], "test-token")
        XCTAssertEqual(environment["VOICEINPUT_MODEL_ROOT"], manager.modelDirectory.path)
        XCTAssertEqual(environment["HF_HOME"], manager.huggingFaceHome.path)
        XCTAssertEqual(environment["TRANSFORMERS_CACHE"], manager.transformersCache.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.modelDirectory.path))
    }

    func testStorageSizeReflectsOnDiskFilesAndReset() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let manager = ModelManager(applicationSupportRoot: root)

        XCTAssertNil(manager.storageSizeBytes())

        try manager.ensureDirectories()
        XCTAssertNil(manager.storageSizeBytes())

        try Data(repeating: 0, count: 2_048)
            .write(to: manager.modelDirectory.appendingPathComponent("weights.bin"))
        try Data(repeating: 0, count: 512)
            .write(to: manager.modelDirectory.appendingPathComponent("config.json"))
        XCTAssertEqual(manager.storageSizeBytes(), 2_560)

        try manager.resetModelStorage()
        XCTAssertNil(manager.storageSizeBytes())
    }
}
