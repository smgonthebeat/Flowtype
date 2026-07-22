import XCTest
@testable import VoiceInputApp

final class ReadinessServiceTests: XCTestCase {
    func testLightweightReportDoesNotCallModelStatusFetcherAndIncludesAllGroups() async throws {
        let fixture = try ReadinessServiceFixture.make()
        var fetchedModelIDs: [String] = []
        var processProviderCallCount = 0
        var timingProviderCallCount = 0
        let service = fixture.service(
            modelStatusFetcher: { modelID in
                fetchedModelIDs.append(modelID)
                return Self.status(model: .qwen3ASR06B, installed: true, loaded: true)
            },
            timingProvider: {
                timingProviderCallCount += 1
                XCTFail("lightweightReport must not load timing samples")
                return nil
            },
            processProvider: {
                processProviderCallCount += 1
                XCTFail("lightweightReport must not sample processes")
                return []
            }
        )

        let report = service.lightweightReport(
            permissionSnapshot: .granted,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            includeSpeechRecognition: true,
            bundleURL: fixture.package.appURL,
            resourceURL: fixture.package.resourcesURL
        )

        XCTAssertTrue(fetchedModelIDs.isEmpty)
        XCTAssertEqual(processProviderCallCount, 0)
        XCTAssertEqual(timingProviderCallCount, 0)
        for group in ReadinessGroup.allCases {
            XCTAssertFalse(report.checks(in: group).isEmpty, "\(group.rawValue) group was missing")
        }
        XCTAssertEqual(report.check("model-qwen3-asr-0.6b-warm")?.status, .optional)
        XCTAssertNil(report.check("model-qwen3-asr-0.6b-warm")?.primaryAction)
        XCTAssertNil(report.check("helper-memory"))
        XCTAssertNil(report.check("last-transcription-timing"))
    }

    func testPrepareRuntimeDelegatesToRuntimeManager() throws {
        let fixture = try ReadinessServiceFixture.make()
        let service = fixture.service()

        let preparedURL = try service.prepareRuntime()

        XCTAssertEqual(preparedURL, fixture.runtime.preparedURL)
        XCTAssertEqual(fixture.runtime.prepareCallCount, 1)
    }

    func testRepairHelperCopyDelegatesToRuntimeManager() throws {
        let fixture = try ReadinessServiceFixture.make()
        let service = fixture.service()

        let repairedURL = try service.repairHelperCopy()

        XCTAssertEqual(repairedURL, fixture.runtime.repairedURL)
        XCTAssertEqual(fixture.runtime.repairCallCount, 1)
    }

    func testReportWithHelperModelStatusFetchesAllModelsAndMapsStatusesIntoModelChecks() async throws {
        let fixture = try ReadinessServiceFixture.make()
        var fetchedModelIDs: [String] = []
        var processProviderCallCount = 0
        var timingProviderCallCount = 0
        let service = fixture.service(
            modelStatusFetcher: { modelID in
                fetchedModelIDs.append(modelID)
                if modelID == VoiceInputModel.qwen3ASR06B.modelID {
                    return Self.status(model: .qwen3ASR06B, installed: true, loaded: true)
                }
                throw NSError(domain: "ReadinessServiceTests", code: 42)
            },
            timingProvider: {
                timingProviderCallCount += 1
                return nil
            },
            processProvider: {
                processProviderCallCount += 1
                return []
            }
        )

        let report = await service.reportWithHelperModelStatus(
            permissionSnapshot: .granted,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            includeSpeechRecognition: false,
            bundleURL: fixture.package.appURL,
            resourceURL: fixture.package.resourcesURL
        )

        XCTAssertEqual(fetchedModelIDs.sorted(), VoiceInputModel.all.map(\.modelID).sorted())
        XCTAssertEqual(report.check("model-qwen3-asr-0.6b")?.status, .ready)
        XCTAssertEqual(report.check("model-qwen3-asr-0.6b-warm")?.status, .ready)
        XCTAssertEqual(report.check("model-qwen3-asr-1.7b")?.status, .optional)
        XCTAssertEqual(report.check("helper-model-status-qwen3-asr-1.7b")?.status, .optional)
        XCTAssertEqual(processProviderCallCount, 1)
        XCTAssertEqual(timingProviderCallCount, 1)
        XCTAssertNotNil(report.check("helper-memory"))
        XCTAssertNotNil(report.check("last-transcription-timing"))
        XCTAssertEqual(report.setupSummary.requiredIssueCount, 0)
        XCTAssertNil(report.setupSummary.recommendedPrimaryAction)
    }

    func testReportWithHelperModelStatusCanSkipPerformanceDetailsForDictationPreparation() async throws {
        let fixture = try ReadinessServiceFixture.make()
        var processProviderCallCount = 0
        var timingProviderCallCount = 0
        let service = fixture.service(
            modelStatusFetcher: { modelID in
                if modelID == VoiceInputModel.qwen3ASR06B.modelID {
                    return Self.status(model: .qwen3ASR06B, installed: true, loaded: true)
                }
                return Self.status(model: .qwen3ASR17B, installed: false, loaded: false)
            },
            timingProvider: {
                timingProviderCallCount += 1
                XCTFail("dictation preparation must not load historical timing")
                return nil
            },
            processProvider: {
                processProviderCallCount += 1
                XCTFail("dictation preparation must not sample processes")
                return []
            }
        )

        let report = await service.reportWithHelperModelStatus(
            permissionSnapshot: .granted,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            includeSpeechRecognition: false,
            includePerformanceDetails: false,
            bundleURL: fixture.package.appURL,
            resourceURL: fixture.package.resourcesURL
        )

        XCTAssertEqual(report.check("model-qwen3-asr-0.6b-warm")?.status, .ready)
        XCTAssertEqual(processProviderCallCount, 0)
        XCTAssertEqual(timingProviderCallCount, 0)
        XCTAssertNil(report.check("helper-memory"))
        XCTAssertNil(report.check("last-transcription-timing"))
    }

    func testReportWithHelperModelStatusSelectedFetchFailureAddsBlockingModelCheck() async throws {
        let fixture = try ReadinessServiceFixture.make()
        try makeValidSnapshot(
            for: ModelManager(
                model: .qwen3ASR06B,
                applicationSupportRoot: fixture.runtime.applicationSupportRoot
            )
        )
        let service = fixture.service(
            modelStatusFetcher: { modelID in
                if modelID == VoiceInputModel.qwen3ASR06B.modelID {
                    throw NSError(domain: "ReadinessServiceTests", code: 7)
                }
                return Self.status(model: .qwen3ASR17B, installed: false, loaded: false)
            }
        )

        let report = await service.reportWithHelperModelStatus(
            permissionSnapshot: .granted,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            includeSpeechRecognition: false,
            bundleURL: fixture.package.appURL,
            resourceURL: fixture.package.resourcesURL
        )

        let failedCheck = report.check("helper-model-status-qwen3-asr-0.6b")
        XCTAssertEqual(failedCheck?.group, .models)
        XCTAssertEqual(failedCheck?.status, .failed("Could not refresh selected Qwen model status."))
        XCTAssertEqual(failedCheck?.primaryAction, .copyDiagnostics)
        XCTAssertFalse(report.isReadyForQwenDictation)
        XCTAssertGreaterThan(report.setupSummary.requiredIssueCount, 0)
        XCTAssertFalse(report.setupSummary.isComplete)
    }

    func testReportWithHelperModelStatusSelectedInstalledButNotLoadedDefersReadyPromise() async throws {
        let fixture = try ReadinessServiceFixture.make()
        let service = fixture.service(
            modelStatusFetcher: { modelID in
                if modelID == VoiceInputModel.qwen3ASR06B.modelID {
                    return Self.status(model: .qwen3ASR06B, installed: true, loaded: false)
                }
                return Self.status(model: .qwen3ASR17B, installed: false, loaded: false)
            }
        )

        let report = await service.reportWithHelperModelStatus(
            permissionSnapshot: .granted,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            includeSpeechRecognition: false,
            bundleURL: fixture.package.appURL,
            resourceURL: fixture.package.resourcesURL
        )

        XCTAssertEqual(report.check("model-qwen3-asr-0.6b")?.status, .ready)
        XCTAssertEqual(report.check("model-qwen3-asr-0.6b-warm")?.status, .optional)
        XCTAssertNil(report.check("model-qwen3-asr-0.6b-warm")?.primaryAction)
        XCTAssertEqual(report.check("model-qwen3-asr-0.6b-warm")?.secondaryAction, .copyDiagnostics)
        XCTAssertFalse(report.isReadyForQwenDictation)
        XCTAssertFalse(report.setupSummary.isComplete)
    }

    func testReportWithHelperModelStatusSelectedDownloadingStillBlocksReadiness() async throws {
        let fixture = try ReadinessServiceFixture.make()
        let service = fixture.service(
            modelStatusFetcher: { modelID in
                if modelID == VoiceInputModel.qwen3ASR06B.modelID {
                    return QwenModelStatus(
                        installed: false,
                        loaded: false,
                        loading: false,
                        downloading: true,
                        progress: 0.25,
                        modelId: VoiceInputModel.qwen3ASR06B.modelID,
                        modelPath: nil
                    )
                }
                return Self.status(model: .qwen3ASR17B, installed: false, loaded: false)
            }
        )

        let report = await service.reportWithHelperModelStatus(
            permissionSnapshot: .granted,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            includeSpeechRecognition: false,
            bundleURL: fixture.package.appURL,
            resourceURL: fixture.package.resourcesURL
        )

        XCTAssertEqual(report.check("model-qwen3-asr-0.6b")?.status, .preparing)
        XCTAssertFalse(report.isReadyForQwenDictation)
    }

    func testDiagnosticsTextIncludesReportDataAndRedactionThroughExporter() throws {
        let fixture = try ReadinessServiceFixture.make()
        let service = fixture.service(
            timingProvider: {
                TranscriptionTimingSample(
                    createdAt: Date(timeIntervalSince1970: 1_800_000_001),
                    modelID: VoiceInputModel.qwen3ASR06B.modelID,
                    strategy: "full",
                    recordingDurationSeconds: 1.0,
                    helperStartMilliseconds: 10,
                    modelPreparationMilliseconds: 20,
                    decodeMilliseconds: 30,
                    postProcessingMilliseconds: 40,
                    totalMilliseconds: 100
                )
            },
            processProvider: {
                [
                    ProcessRSSSnapshot(
                        command: "uv run qwen-asr-helper VOICEINPUT_HELPER_TOKEN=secret",
                        residentMemoryKB: 2_048
                    )
                ]
            }
        )
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            checks: [
                ReadinessCheck(
                    id: "runtime",
                    group: .localRuntime,
                    title: "Runtime",
                    detail: "--token=detailSecret",
                    status: .failed("access-token statusSecret")
                )
            ]
        )

        let text = service.diagnosticsText(report: report)

        XCTAssertTrue(text.contains("Runtime"))
        XCTAssertTrue(text.contains("- helper_ms: 10"))
        XCTAssertTrue(text.contains("2048 KB RSS: qwen-asr-helper"))
        XCTAssertFalse(text.contains("VOICEINPUT_HELPER_TOKEN="))
        XCTAssertFalse(text.contains("secret"))
        XCTAssertFalse(text.contains("detailSecret"))
        XCTAssertFalse(text.contains("statusSecret"))
    }

    func testRuntimeChecksExposeActionsForMissingRepairAndMissingUVStates() throws {
        let fixture = try ReadinessServiceFixture.make(
            runtimeSnapshot: HelperRuntimeSnapshot(
                applicationSupportStatus: .notReady,
                bundledUVStatus: .failed("Bundled uv is missing or not executable."),
                helperCopyStatus: .needsRepair,
                helperDirectory: URL(fileURLWithPath: "/tmp/helper"),
                bundledHelperDirectory: nil
            )
        )
        let service = fixture.service()

        let report = service.lightweightReport(
            permissionSnapshot: .granted,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id,
            includeSpeechRecognition: false,
            bundleURL: fixture.package.appURL,
            resourceURL: fixture.package.resourcesURL
        )

        XCTAssertEqual(report.check("application-support-root")?.status, .notReady)
        XCTAssertEqual(report.check("application-support-root")?.primaryAction, .prepareRuntime)
        XCTAssertEqual(report.check("application-support-root")?.secondaryAction, .copyDiagnostics)
        XCTAssertEqual(report.check("application-support-root")?.locationTarget, .applicationSupportRoot)
        XCTAssertEqual(report.check("local-helper-copy")?.status, .needsRepair)
        XCTAssertEqual(report.check("local-helper-copy")?.primaryAction, .prepareRuntime)
        XCTAssertEqual(report.check("local-helper-copy")?.secondaryAction, .copyDiagnostics)
        XCTAssertEqual(report.check("local-helper-copy")?.locationTarget, .localHelper)
        XCTAssertEqual(report.check("local-bundled-uv")?.status, .failed("Bundled uv is missing or not executable."))
        XCTAssertEqual(report.check("local-bundled-uv")?.primaryAction, .reinstallFlowtypeApp)
        XCTAssertEqual(report.check("local-bundled-uv")?.secondaryAction, .copyDiagnostics)
        XCTAssertEqual(report.check("local-bundled-uv")?.locationTarget, .appResources)
    }

    fileprivate static func status(model: VoiceInputModel, installed: Bool, loaded: Bool) -> QwenModelStatus {
        QwenModelStatus(
            installed: installed,
            loaded: loaded,
            loading: false,
            downloading: false,
            progress: nil,
            modelId: model.modelID,
            modelPath: installed ? "/tmp/\(model.directoryName)" : nil
        )
    }

    private func makeValidSnapshot(for manager: ModelManager) throws {
        let snapshotDirectory = manager.huggingFaceHubModelDirectory
            .appendingPathComponent("snapshots", isDirectory: true)
            .appendingPathComponent("test-snapshot", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        try "{}".write(to: snapshotDirectory.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try Data("weights".utf8).write(to: snapshotDirectory.appendingPathComponent("model.safetensors"))
    }
}

private final class SpyHelperRuntimeManager: HelperRuntimeManaging {
    let applicationSupportRoot: URL
    let snapshotValue: HelperRuntimeSnapshot
    let preparedURL: URL
    let repairedURL: URL
    private(set) var prepareCallCount = 0
    private(set) var repairCallCount = 0

    init(applicationSupportRoot: URL, snapshotValue: HelperRuntimeSnapshot) {
        self.applicationSupportRoot = applicationSupportRoot
        self.snapshotValue = snapshotValue
        self.preparedURL = applicationSupportRoot.appendingPathComponent("prepared-helper", isDirectory: true)
        self.repairedURL = applicationSupportRoot.appendingPathComponent("repaired-helper", isDirectory: true)
    }

    func snapshot() -> HelperRuntimeSnapshot {
        snapshotValue
    }

    func prepareRuntime() throws -> URL {
        prepareCallCount += 1
        return preparedURL
    }

    func repairHelperCopy() throws -> URL {
        repairCallCount += 1
        return repairedURL
    }
}

private struct ReadinessServiceFixture {
    let package: ReadinessPackageFixture
    let runtime: SpyHelperRuntimeManager

    static func make(runtimeSnapshot: HelperRuntimeSnapshot? = nil) throws -> ReadinessServiceFixture {
        let package = try ReadinessPackageFixture.makeComplete()
        let supportRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("flowtype-readiness-service-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: supportRoot, withIntermediateDirectories: true)
        let snapshot = runtimeSnapshot ?? HelperRuntimeSnapshot(
            applicationSupportStatus: .ready,
            bundledUVStatus: .ready,
            helperCopyStatus: .ready,
            helperDirectory: supportRoot.appendingPathComponent("qwen-asr-helper", isDirectory: true),
            bundledHelperDirectory: package.resourcesURL.appendingPathComponent("Helpers/qwen-asr-helper", isDirectory: true)
        )
        let runtime = SpyHelperRuntimeManager(applicationSupportRoot: supportRoot, snapshotValue: snapshot)
        return ReadinessServiceFixture(package: package, runtime: runtime)
    }

    func service(
        modelStatusFetcher: @escaping (String) async throws -> QwenModelStatus = { _ in
            ReadinessServiceTests.status(model: .qwen3ASR06B, installed: false, loaded: false)
        },
        timingProvider: @escaping () -> TranscriptionTimingSample? = { nil },
        processProvider: @escaping () -> [ProcessRSSSnapshot] = { [] }
    ) -> ReadinessService {
        ReadinessService(
            packageInspector: PackageInspector(),
            helperRuntimeManager: runtime,
            permissionInspector: PermissionReadinessInspector(),
            modelReadinessInspector: ModelReadinessInspector(),
            performanceInspector: PerformanceInspector(
                hardwareProvider: {
                    HardwareSummary(machine: "Mac14,7", processor: "Apple M2", physicalMemoryGB: 16, isAppleSilicon: true)
                },
                processProvider: processProvider,
                timingProvider: timingProvider
            ),
            diagnosticsExporter: DiagnosticsExporter(
                appVersionProvider: { "1.0-test" },
                macOSVersionProvider: { "macOS 15.5" },
                hardwareProvider: {
                    HardwareSummary(machine: "Mac14,7", processor: "Apple M2", physicalMemoryGB: 16, isAppleSilicon: true)
                }
            ),
            modelStatusFetcher: modelStatusFetcher,
            timingProvider: timingProvider,
            processProvider: processProvider,
            dateProvider: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }
}

private struct ReadinessPackageFixture {
    let appURL: URL
    let resourcesURL: URL

    static func makeComplete() throws -> ReadinessPackageFixture {
        let fixture = try PackageFixture.makeComplete()
        return ReadinessPackageFixture(appURL: fixture.appURL, resourcesURL: fixture.resourcesURL)
    }
}

private extension PermissionSnapshot {
    static let granted = PermissionSnapshot(
        microphone: .granted,
        accessibility: .granted,
        speechRecognition: .granted
    )
}

private extension ReadinessReport {
    func check(_ id: String) -> ReadinessCheck? {
        checks.first { $0.id == id }
    }
}
