import XCTest
@testable import VoiceInputApp

final class ModelReadinessInspectorTests: XCTestCase {
    func testSelectedInstalledAndLoadedModelIsReady() throws {
        let root = temporaryDirectory()
        let manager = ModelManager(model: .qwen3ASR06B, applicationSupportRoot: root)
        try makeValidSnapshot(for: manager)
        let status = QwenModelStatus(
            installed: true,
            loaded: true,
            loading: false,
            downloading: false,
            progress: nil,
            modelId: VoiceInputModel.qwen3ASR06B.modelID,
            modelPath: manager.modelDirectory.path
        )

        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: root,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [VoiceInputModel.qwen3ASR06B.modelID: status]
        )

        XCTAssertEqual(checks.check("selected-model")?.status, .ready)
        XCTAssertEqual(checks.check("model-qwen3-asr-0.6b")?.status, .ready)
        XCTAssertNil(checks.check("model-qwen3-asr-0.6b")?.primaryAction)
        XCTAssertEqual(checks.check("model-qwen3-asr-0.6b-warm")?.status, .ready)
    }

    func testPartialModelCacheNeedsRepair() throws {
        let root = temporaryDirectory()
        let manager = ModelManager(model: .qwen3ASR17B, applicationSupportRoot: root)
        try manager.ensureDirectories()
        try "partial".write(to: manager.modelDirectory.appendingPathComponent("partial.bin"), atomically: true, encoding: .utf8)

        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: root,
            selectedModelID: VoiceInputModel.qwen3ASR17B.id,
            helperStatuses: [:]
        )

        XCTAssertEqual(checks.check("model-qwen3-asr-1.7b")?.status, .needsRepair)
        XCTAssertNil(checks.check("model-qwen3-asr-1.7b")?.primaryAction)
    }

    func testInspectIncludesAllModelsInstallChecksAndWarmChecks() {
        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [:]
        )

        for model in VoiceInputModel.all {
            XCTAssertNotNil(checks.check("model-\(model.id)"))
            XCTAssertNotNil(checks.check("model-\(model.id)-warm"))
        }
        XCTAssertEqual(checks.filter { $0.group == .models }.count, 1 + (VoiceInputModel.all.count * 2))
    }

    func testDownloadingStateIsPreparingWithProgressDetail() {
        let status = QwenModelStatus(
            installed: false,
            loaded: false,
            loading: false,
            downloading: true,
            progress: 0.427,
            modelId: VoiceInputModel.qwen3ASR17B.modelID,
            modelPath: nil
        )

        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR17B.id,
            helperStatuses: [VoiceInputModel.qwen3ASR17B.modelID: status]
        )

        XCTAssertEqual(checks.check("model-qwen3-asr-1.7b")?.status, .preparing)
        XCTAssertEqual(checks.check("model-qwen3-asr-1.7b")?.detail, "Flowtype is preparing the local Qwen model: 43%.")
    }

    func testProgressDetailIsClampedBeforeFormatting() {
        let negativeStatus = QwenModelStatus(
            installed: false,
            loaded: false,
            loading: false,
            downloading: true,
            progress: -0.25,
            modelId: VoiceInputModel.qwen3ASR06B.modelID,
            modelPath: nil
        )
        let overOneStatus = QwenModelStatus(
            installed: false,
            loaded: false,
            loading: false,
            downloading: true,
            progress: 1.35,
            modelId: VoiceInputModel.qwen3ASR17B.modelID,
            modelPath: nil
        )

        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [
                VoiceInputModel.qwen3ASR06B.modelID: negativeStatus,
                VoiceInputModel.qwen3ASR17B.modelID: overOneStatus
            ]
        )

        XCTAssertEqual(checks.check("model-qwen3-asr-0.6b")?.detail, "Flowtype is preparing the local Qwen model: 0%.")
        XCTAssertEqual(checks.check("model-qwen3-asr-1.7b")?.detail, "Flowtype is preparing the local Qwen model: 100%.")
    }

    func testMissingModelDownloadingStateWithoutProgressIsPreparing() {
        let status = QwenModelStatus(
            installed: false,
            loaded: false,
            loading: false,
            downloading: true,
            progress: nil,
            modelId: VoiceInputModel.qwen3ASR06B.modelID,
            modelPath: nil
        )

        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [VoiceInputModel.qwen3ASR06B.modelID: status]
        )

        XCTAssertEqual(checks.check("model-qwen3-asr-0.6b")?.status, .preparing)
        XCTAssertEqual(checks.check("model-qwen3-asr-0.6b")?.detail, "Flowtype is preparing the local Qwen model.")
    }

    func testSelectedInstalledModelLoadingKeepsInstallReadyButDefersReadyPromise() throws {
        let root = temporaryDirectory()
        let manager = ModelManager(model: .qwen3ASR06B, applicationSupportRoot: root)
        try makeValidSnapshot(for: manager)
        let status = QwenModelStatus(
            installed: true,
            loaded: false,
            loading: true,
            downloading: false,
            progress: nil,
            modelId: VoiceInputModel.qwen3ASR06B.modelID,
            modelPath: manager.modelDirectory.path
        )

        let modelChecks = ModelReadinessInspector().inspect(
            applicationSupportRoot: root,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [VoiceInputModel.qwen3ASR06B.modelID: status]
        )
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 0),
            checks: [
                readyCheck(id: "app-bundle", group: .appBundle),
                readyCheck(id: "local-runtime", group: .localRuntime),
                readyCheck(id: "microphone-permission", group: .permissions),
                readyCheck(id: "accessibility-permission", group: .permissions),
                readyCheck(id: "apple-silicon", group: .performance)
            ] + modelChecks
        )

        XCTAssertEqual(modelChecks.check("model-qwen3-asr-0.6b")?.status, .ready)
        XCTAssertEqual(modelChecks.check("model-qwen3-asr-0.6b")?.locationTarget, .selectedModel)
        XCTAssertEqual(modelChecks.check("model-qwen3-asr-0.6b-warm")?.status, .optional)
        XCTAssertNil(modelChecks.check("model-qwen3-asr-0.6b-warm")?.primaryAction)
        XCTAssertFalse(report.isReadyForQwenDictation)
        XCTAssertTrue(report.requiresSelectedModelWarmup)
    }

    func testInspectorMapsMatchingHelperInstalledStatusToReadyWithoutLocalSnapshot() {
        let status = QwenModelStatus(
            installed: true,
            loaded: false,
            loading: false,
            downloading: false,
            progress: nil,
            modelId: VoiceInputModel.qwen3ASR06B.modelID,
            modelPath: "/tmp/model"
        )

        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [VoiceInputModel.qwen3ASR06B.modelID: status]
        )

        XCTAssertEqual(checks.check("model-qwen3-asr-0.6b")?.status, .ready)
        XCTAssertNil(checks.check("model-qwen3-asr-0.6b")?.primaryAction)
    }

    func testMismatchedHelperStatusDoesNotMakeModelReady() {
        let status = QwenModelStatus(
            installed: true,
            loaded: true,
            loading: false,
            downloading: false,
            progress: nil,
            modelId: VoiceInputModel.qwen3ASR17B.modelID,
            modelPath: "/tmp/model"
        )

        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [VoiceInputModel.qwen3ASR06B.modelID: status]
        )

        XCTAssertEqual(checks.check("model-qwen3-asr-0.6b")?.status, .notReady)
        XCTAssertEqual(checks.check("model-qwen3-asr-0.6b")?.primaryAction, .downloadDefaultModel)
    }

    func testSelectedInstalledButColdModelHasNoManualWarmAction() throws {
        let root = temporaryDirectory()
        let manager = ModelManager(model: .qwen3ASR06B, applicationSupportRoot: root)
        try makeValidSnapshot(for: manager)
        let status = QwenModelStatus(
            installed: true,
            loaded: false,
            loading: false,
            downloading: false,
            progress: nil,
            modelId: VoiceInputModel.qwen3ASR06B.modelID,
            modelPath: manager.modelDirectory.path
        )

        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: root,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [VoiceInputModel.qwen3ASR06B.modelID: status]
        )
        let warm = checks.check("model-qwen3-asr-0.6b-warm")

        XCTAssertEqual(warm?.status, .optional)
        XCTAssertNil(warm?.primaryAction)
        XCTAssertEqual(warm?.secondaryAction, .copyDiagnostics)
        XCTAssertEqual(warm?.locationTarget, .selectedModel)
    }

    func testSelectedModelDownloadUsesDefaultModelActionWhenMissing() {
        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [:]
        )
        let install = checks.check("model-qwen3-asr-0.6b")

        XCTAssertEqual(install?.status, .notReady)
        XCTAssertEqual(install?.primaryAction, .downloadDefaultModel)
        XCTAssertEqual(install?.locationTarget, .selectedModel)
    }

    func testMissingModelIsNotReadyWithoutReadinessAction() {
        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR17B.id,
            helperStatuses: [:]
        )

        XCTAssertEqual(checks.check("model-qwen3-asr-1.7b")?.status, .notReady)
        XCTAssertNil(checks.check("model-qwen3-asr-1.7b")?.primaryAction)
    }

    func testNonSelectedWarmChecksAreOptional() {
        let checks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [:]
        )

        XCTAssertEqual(checks.check("model-qwen3-asr-1.7b-warm")?.status, .optional)
        XCTAssertNil(checks.check("model-qwen3-asr-1.7b-warm")?.primaryAction)
        XCTAssertEqual(checks.check("model-qwen3-asr-1.7b-warm")?.locationTarget, .modelsRoot)
    }

    func testNonSelectedMissingAndPartialInstallChecksAreOptional() throws {
        let missingChecks = ModelReadinessInspector().inspect(
            applicationSupportRoot: temporaryDirectory(),
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [:]
        )

        XCTAssertEqual(missingChecks.check("model-qwen3-asr-1.7b")?.status, .optional)
        XCTAssertNil(missingChecks.check("model-qwen3-asr-1.7b")?.primaryAction)

        let root = temporaryDirectory()
        let manager = ModelManager(model: .qwen3ASR17B, applicationSupportRoot: root)
        try manager.ensureDirectories()
        try "partial".write(to: manager.modelDirectory.appendingPathComponent("partial.bin"), atomically: true, encoding: .utf8)

        let partialChecks = ModelReadinessInspector().inspect(
            applicationSupportRoot: root,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [:]
        )

        XCTAssertEqual(partialChecks.check("model-qwen3-asr-1.7b")?.status, .optional)
        XCTAssertNil(partialChecks.check("model-qwen3-asr-1.7b")?.primaryAction)
    }

    func testNonSelectedMissingModelDoesNotBlockQwenDictationReadiness() throws {
        let root = temporaryDirectory()
        let selectedManager = ModelManager(model: .qwen3ASR06B, applicationSupportRoot: root)
        try makeValidSnapshot(for: selectedManager)
        let selectedStatus = QwenModelStatus(
            installed: true,
            loaded: true,
            loading: false,
            downloading: false,
            progress: nil,
            modelId: VoiceInputModel.qwen3ASR06B.modelID,
            modelPath: selectedManager.modelDirectory.path
        )
        let modelChecks = ModelReadinessInspector().inspect(
            applicationSupportRoot: root,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            helperStatuses: [VoiceInputModel.qwen3ASR06B.modelID: selectedStatus]
        )
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 0),
            checks: [
                readyCheck(id: "app-bundle", group: .appBundle),
                readyCheck(id: "local-runtime", group: .localRuntime),
                readyCheck(id: "microphone-permission", group: .permissions),
                readyCheck(id: "accessibility-permission", group: .permissions),
                readyCheck(id: "apple-silicon", group: .performance)
            ] + modelChecks
        )

        XCTAssertEqual(modelChecks.check("model-qwen3-asr-1.7b")?.status, .optional)
        XCTAssertTrue(report.isReadyForQwenDictation)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-model-readiness-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeValidSnapshot(for manager: ModelManager) throws {
        let snapshotDirectory = manager.huggingFaceHubModelDirectory
            .appendingPathComponent("snapshots", isDirectory: true)
            .appendingPathComponent("test-snapshot", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        try "{}".write(to: snapshotDirectory.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try Data("weights".utf8).write(to: snapshotDirectory.appendingPathComponent("model.safetensors"))
    }

    private func readyCheck(id: String, group: ReadinessGroup) -> ReadinessCheck {
        ReadinessCheck(
            id: id,
            group: group,
            title: id,
            detail: "Ready.",
            status: .ready
        )
    }
}

private extension Array where Element == ReadinessCheck {
    func check(_ id: String) -> ReadinessCheck? {
        first { $0.id == id }
    }
}
