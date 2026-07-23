import XCTest
@testable import VoiceInputApp

final class FlowtypePreparationTests: XCTestCase {
    func testAbsentModelPreparationNeverClaimsDownloadHasCompleted() {
        let preparingDownload = QwenModelStatus(
            installed: false,
            loaded: false,
            loading: true,
            downloading: false,
            progress: nil,
            modelId: VoiceInputModel.qwen3ASR06B.modelID,
            modelPath: nil,
            phase: .loading
        )
        let loadingInstalledModel = QwenModelStatus(
            installed: true,
            loaded: false,
            loading: true,
            downloading: false,
            progress: 1,
            modelId: VoiceInputModel.qwen3ASR06B.modelID,
            modelPath: nil,
            phase: .loading
        )

        XCTAssertEqual(
            ModelPreparationStageResolver.stage(for: preparingDownload),
            .downloadingModel
        )
        XCTAssertEqual(
            ModelPreparationStageResolver.stage(for: loadingInstalledModel),
            .loadingModel
        )
    }

    func testConcurrentSessionsForSameConfigurationShareOneMachineJob() async {
        let driver = PreparationDriverFake(
            evidences: [.qwenReadyForMachineWork, .qwenFullyReady, .qwenFullyReady]
        )
        driver.suspendMachinePreparation = true
        let module = FlowtypePreparation(driver: driver)
        let request = PreparationRequest(intent: .backgroundWarmup, configuration: .qwen06B)

        let first = await module.begin(request)
        await driver.waitUntilMachinePreparationStarts()
        let second = await module.begin(request)
        driver.resumeMachinePreparation()

        let firstResult = await first.result.value
        let secondResult = await second.result.value

        XCTAssertTrue(firstResult.isReady)
        XCTAssertTrue(secondResult.isReady)
        XCTAssertEqual(driver.prepareSelectedModelCount, 1)
        XCTAssertNotEqual(first.runID, second.runID)
    }

    func testAccessibilityCheckpointTerminatesSessionWithoutWaitingForever() async {
        let driver = PreparationDriverFake(
            evidences: [.qwenMissingAccessibility, .qwenMissingAccessibility]
        )
        let module = FlowtypePreparation(driver: driver)

        let session = await module.begin(
            PreparationRequest(intent: .interactiveSetup, configuration: .qwen06B)
        )
        let result = await session.result.value

        XCTAssertEqual(result.outcome, .awaitingUserAction(.accessibility))
        XCTAssertEqual(driver.requestedPermissions, [.accessibility])
        XCTAssertEqual(driver.recordConsentCount, 0)
        XCTAssertEqual(driver.prepareSelectedModelCount, 0)
    }

    func testInteractiveSetupFinishesPermissionsBeforeConsentRuntimeAndModelWork() async {
        let driver = PreparationDriverFake(
            evidences: [
                .qwenMissingPermissionsAndModel,
                .qwenMissingAccessibilityAndModel,
                .qwenModelAbsentNeedsRuntimeRepair,
                .qwenFullyReady,
            ]
        )
        driver.hasConsent = false
        let module = FlowtypePreparation(driver: driver)

        let session = await module.begin(
            PreparationRequest(intent: .interactiveSetup, configuration: .qwen06B)
        )
        let result = await session.result.value

        XCTAssertTrue(result.isReady)
        XCTAssertEqual(
            driver.lifecycleEvents,
            [
                "permission.microphone",
                "permission.accessibility",
                "consent.record",
                "runtime",
                "model",
            ]
        )
    }

    func testApplePreparationNeverTouchesQwenRuntime() async {
        let driver = PreparationDriverFake(evidences: [.appleFullyReady])
        let module = FlowtypePreparation(driver: driver)

        let session = await module.begin(
            PreparationRequest(intent: .backgroundWarmup, configuration: .apple)
        )
        let result = await session.result.value

        XCTAssertTrue(result.isReady)
        XCTAssertEqual(driver.prepareSelectedModelCount, 0)
        XCTAssertEqual(driver.prepareRuntimeCount, 0)
    }

    func testInvalidAppBundleStopsBeforeRuntimeOrModelMutation() async {
        let driver = PreparationDriverFake(evidences: [.invalidAppBundle])
        let module = FlowtypePreparation(driver: driver)

        let session = await module.begin(
            PreparationRequest(intent: .interactiveSetup, configuration: .qwen06B)
        )
        let result = await session.result.value

        XCTAssertEqual(result.outcome, .blocked)
        XCTAssertEqual(driver.prepareRuntimeCount, 0)
        XCTAssertEqual(driver.prepareSelectedModelCount, 0)
    }

    func testInteractiveSetupTreatsOneClickActionAsDownloadConsent() async {
        let driver = PreparationDriverFake(evidences: [.qwenModelAbsent, .qwenFullyReady])
        driver.hasConsent = false
        let module = FlowtypePreparation(driver: driver)

        let session = await module.begin(
            PreparationRequest(intent: .interactiveSetup, configuration: .qwen06B)
        )
        let result = await session.result.value

        XCTAssertTrue(result.isReady)
        XCTAssertEqual(driver.recordConsentCount, 1)
        XCTAssertEqual(driver.prepareSelectedModelCount, 1)
    }

    func testPermissionReturnResumesOriginalOneClickIntoAutomaticDownload() async {
        let driver = PreparationDriverFake(
            evidences: [
                .qwenMissingAccessibilityAndModel,
                .qwenMissingAccessibilityAndModel,
                .qwenModelAbsent,
                .qwenFullyReady,
            ]
        )
        driver.hasConsent = false
        let module = FlowtypePreparation(driver: driver)

        let initialSession = await module.begin(
            PreparationRequest(intent: .interactiveSetup, configuration: .qwen06B)
        )
        let initialResult = await initialSession.result.value
        XCTAssertEqual(initialResult.outcome, .awaitingUserAction(.accessibility))

        let resumedSession = await module.begin(
            PreparationRequest(intent: .resumeAfterUserAction, configuration: .qwen06B)
        )
        let resumedResult = await resumedSession.result.value

        XCTAssertTrue(resumedResult.isReady)
        XCTAssertEqual(
            driver.lifecycleEvents,
            ["permission.accessibility", "consent.record", "model"]
        )
    }

    func testRuntimeRepairPrecedesModelPreparation() async {
        let driver = PreparationDriverFake(
            evidences: [.qwenNeedsRuntimeRepair, .qwenFullyReady]
        )
        let module = FlowtypePreparation(driver: driver)

        let session = await module.begin(
            PreparationRequest(intent: .backgroundWarmup, configuration: .qwen06B)
        )
        let result = await session.result.value

        XCTAssertTrue(result.isReady)
        XCTAssertEqual(driver.machineEvents, ["runtime", "model"])
    }

    func testDoesNotPublishReadyWhenFinalProbeReportsSelectedModelCold() async {
        let driver = PreparationDriverFake(
            evidences: [.qwenReadyForMachineWork, .qwenInstalledButCold]
        )
        let module = FlowtypePreparation(driver: driver)

        let session = await module.begin(
            PreparationRequest(intent: .backgroundWarmup, configuration: .qwen06B)
        )
        let result = await session.result.value

        XCTAssertEqual(result.outcome, .failed(.finalVerificationFailed))
    }

    func testRuntimeMutationWaitsForActiveDictationReservation() async throws {
        let driver = PreparationDriverFake(
            evidences: [.qwenReadyForMachineWork, .qwenFullyReady, .qwenReadyForMachineWork, .qwenFullyReady]
        )
        let module = FlowtypePreparation(driver: driver)
        let operationStarted = expectation(description: "dictation operation started")
        let allowOperationToFinish = AsyncTestGate()

        let dictationTask = Task {
            try await module.withPreparedRuntime(for: .qwen06B) { identity in
                XCTAssertEqual(identity.configuration.modelID, VoiceInputModel.qwen3ASR06B.modelID)
                operationStarted.fulfill()
                await allowOperationToFinish.wait()
                return "done"
            }
        }
        await fulfillment(of: [operationStarted], timeout: 1)

        let switchSession = await module.begin(
            PreparationRequest(intent: .backgroundWarmup, configuration: .qwen17B)
        )
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(driver.prepareSelectedModelCount, 1)

        await allowOperationToFinish.open()
        let dictationResult = try await dictationTask.value
        let switchResult = await switchSession.result.value
        XCTAssertEqual(dictationResult, "done")
        XCTAssertTrue(switchResult.isReady)
        XCTAssertEqual(driver.prepareSelectedModelCount, 2)
    }

    func testNewGenerationDoesNotAttachToStaleJobForSameModel() async {
        let driver = PreparationDriverFake(
            evidences: [.qwenReadyForMachineWork, .qwenReadyForMachineWork, .qwenFullyReady]
        )
        driver.suspendMachinePreparation = true
        let module = FlowtypePreparation(driver: driver)

        let stale = await module.begin(
            PreparationRequest(intent: .backgroundWarmup, configuration: .qwen06B)
        )
        await driver.waitUntilMachinePreparationStarts()
        let current = await module.begin(
            PreparationRequest(intent: .backgroundWarmup, configuration: .qwen06BGeneration3)
        )
        driver.resumeMachinePreparation()

        let staleResult = await stale.result.value
        let currentResult = await current.result.value

        XCTAssertEqual(staleResult.outcome, .failed(.superseded))
        XCTAssertTrue(currentResult.isReady)
        XCTAssertEqual(currentResult.runtime?.configuration, .qwen06BGeneration3)
        XCTAssertEqual(driver.prepareSelectedModelCount, 2)
    }

    func testBackgroundWarmupRequiresConsentBeforeStartingMissingModelJob() async {
        let driver = PreparationDriverFake(evidences: [.qwenModelAbsent])
        driver.hasConsent = false
        let module = FlowtypePreparation(driver: driver)

        let session = await module.begin(
            PreparationRequest(intent: .backgroundWarmup, configuration: .qwen06B)
        )
        let result = await session.result.value

        XCTAssertEqual(result.outcome, .awaitingUserAction(.modelDownloadConsent))
        XCTAssertEqual(driver.prepareSelectedModelCount, 0)
        XCTAssertEqual(driver.recordConsentCount, 0)
    }

    func testForcedModelRepairRunsInsidePreparationJob() async {
        let driver = PreparationDriverFake(
            evidences: [.qwenReadyForMachineWork, .qwenFullyReady]
        )
        let module = FlowtypePreparation(driver: driver)

        let session = await module.begin(
            PreparationRequest(
                intent: .backgroundWarmup,
                configuration: .qwen06B,
                forceModelRepair: true
            )
        )
        let result = await session.result.value

        XCTAssertTrue(result.isReady)
        XCTAssertEqual(driver.repairSelectedModelStorageCount, 1)
        XCTAssertEqual(driver.prepareSelectedModelCount, 1)
    }

    func testThrownDictationOperationReleasesReservationForQueuedMutation() async {
        enum ExpectedFailure: Error { case failed }
        let driver = PreparationDriverFake(
            evidences: [.qwenReadyForMachineWork, .qwenFullyReady]
        )
        let module = FlowtypePreparation(driver: driver)

        do {
            let _: String = try await module.withPreparedRuntime(for: .qwen06B) { _ in
                throw ExpectedFailure.failed
            }
            XCTFail("Expected dictation operation to throw")
        } catch ExpectedFailure.failed {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let mutationCompleted = expectation(description: "mutation completed")
        Task {
            try? await module.withExclusiveRuntimeMutation {
                mutationCompleted.fulfill()
            }
        }
        await fulfillment(of: [mutationCompleted], timeout: 1)
    }
}

private extension PreparationConfiguration {
    static let qwen06B = PreparationConfiguration(
        engine: .qwenLocal,
        modelID: VoiceInputModel.qwen3ASR06B.modelID,
        runtimeRevision: "runtime-1",
        generation: 1
    )

    static let qwen17B = PreparationConfiguration(
        engine: .qwenLocal,
        modelID: VoiceInputModel.qwen3ASR17B.modelID,
        runtimeRevision: "runtime-1",
        generation: 2
    )

    static let qwen06BGeneration3 = PreparationConfiguration(
        engine: .qwenLocal,
        modelID: VoiceInputModel.qwen3ASR06B.modelID,
        runtimeRevision: "runtime-1",
        generation: 3
    )

    static let apple = PreparationConfiguration(
        engine: .appleSpeech,
        modelID: nil,
        runtimeRevision: "runtime-1",
        generation: 1
    )
}

private extension PreparationEvidence {
    static let qwenReadyForMachineWork = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: nil,
        missingPermissions: [],
        selectedModelInstalled: true,
        selectedModelLoaded: false,
        helperHealthy: false
    )

    static let qwenFullyReady = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: nil,
        missingPermissions: [],
        selectedModelInstalled: true,
        selectedModelLoaded: true,
        helperHealthy: true
    )

    static let qwenInstalledButCold = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: nil,
        missingPermissions: [],
        selectedModelInstalled: true,
        selectedModelLoaded: false,
        helperHealthy: true
    )

    static let qwenMissingAccessibility = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: nil,
        missingPermissions: [.accessibility],
        selectedModelInstalled: true,
        selectedModelLoaded: false,
        helperHealthy: false
    )

    static let qwenModelAbsent = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: nil,
        missingPermissions: [],
        selectedModelInstalled: false,
        selectedModelLoaded: false,
        helperHealthy: false
    )

    static let qwenMissingPermissionsAndModel = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: .repairHelper,
        missingPermissions: [.microphone, .accessibility],
        selectedModelInstalled: false,
        selectedModelLoaded: false,
        helperHealthy: false
    )

    static let qwenMissingAccessibilityAndModel = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: .repairHelper,
        missingPermissions: [.accessibility],
        selectedModelInstalled: false,
        selectedModelLoaded: false,
        helperHealthy: false
    )

    static let qwenModelAbsentNeedsRuntimeRepair = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: .repairHelper,
        missingPermissions: [],
        selectedModelInstalled: false,
        selectedModelLoaded: false,
        helperHealthy: false
    )

    static let qwenNeedsRuntimeRepair = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: .repairHelper,
        missingPermissions: [],
        selectedModelInstalled: true,
        selectedModelLoaded: false,
        helperHealthy: false
    )

    static let invalidAppBundle = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: false,
        runtimeAction: .repairHelper,
        missingPermissions: [],
        selectedModelInstalled: false,
        selectedModelLoaded: false,
        helperHealthy: false
    )

    static let appleFullyReady = PreparationEvidence(
        report: ReadinessReport(generatedAt: Date(), checks: []),
        appBundleReady: true,
        runtimeAction: nil,
        missingPermissions: [],
        selectedModelInstalled: false,
        selectedModelLoaded: false,
        helperHealthy: false
    )
}

private final class PreparationDriverFake: FlowtypePreparationDriving {
    private let queue = DispatchQueue(label: "FlowtypePreparationTests.Driver")
    private var evidences: [PreparationEvidence]
    private let machineStarted = AsyncTestGate()
    private let machineResume = AsyncTestGate()
    private var _suspendMachinePreparation = false
    private var _prepareSelectedModelCount = 0
    private var _prepareRuntimeCount = 0
    private var _requestedPermissions: [PreparationPermission] = []
    private var _hasConsent = true
    private var _recordConsentCount = 0
    private var _repairSelectedModelStorageCount = 0
    private var _machineEvents: [String] = []
    private var _lifecycleEvents: [String] = []

    var suspendMachinePreparation: Bool {
        get { queue.sync { _suspendMachinePreparation } }
        set { queue.sync { _suspendMachinePreparation = newValue } }
    }

    var prepareSelectedModelCount: Int { queue.sync { _prepareSelectedModelCount } }
    var prepareRuntimeCount: Int { queue.sync { _prepareRuntimeCount } }
    var requestedPermissions: [PreparationPermission] { queue.sync { _requestedPermissions } }
    var hasConsent: Bool {
        get { queue.sync { _hasConsent } }
        set { queue.sync { _hasConsent = newValue } }
    }
    var recordConsentCount: Int { queue.sync { _recordConsentCount } }
    var repairSelectedModelStorageCount: Int { queue.sync { _repairSelectedModelStorageCount } }
    var machineEvents: [String] { queue.sync { _machineEvents } }
    var lifecycleEvents: [String] { queue.sync { _lifecycleEvents } }

    init(evidences: [PreparationEvidence]) {
        self.evidences = evidences
    }

    func inspect(configuration: PreparationConfiguration, live: Bool) async -> PreparationEvidence {
        queue.sync {
            if evidences.count > 1 {
                return evidences.removeFirst()
            }
            return evidences[0]
        }
    }

    func prepareRuntime(action: ReadinessActionKind) async throws {
        queue.sync {
            _prepareRuntimeCount += 1
            _machineEvents.append("runtime")
            _lifecycleEvents.append("runtime")
        }
    }

    func requestPermission(_ permission: PreparationPermission) async {
        queue.sync {
            _requestedPermissions.append(permission)
            switch permission {
            case .microphone: _lifecycleEvents.append("permission.microphone")
            case .accessibility: _lifecycleEvents.append("permission.accessibility")
            case .speechRecognition: _lifecycleEvents.append("permission.speechRecognition")
            }
        }
    }

    func hasDownloadConsent(modelID: String) async -> Bool { queue.sync { _hasConsent } }
    func recordDownloadConsent(modelID: String) async {
        queue.sync {
            _recordConsentCount += 1
            _lifecycleEvents.append("consent.record")
        }
    }
    func repairSelectedModelStorage(configuration: PreparationConfiguration) async throws {
        queue.sync { _repairSelectedModelStorageCount += 1 }
    }

    func prepareSelectedModel(
        configuration: PreparationConfiguration,
        operationID: UUID,
        progress: @escaping (PreparationStage, Double?) async -> Void
    ) async throws -> PreparedRuntimeIdentity {
        queue.sync {
            _prepareSelectedModelCount += 1
            _machineEvents.append("model")
            _lifecycleEvents.append("model")
        }
        await machineStarted.open()
        if queue.sync(execute: { _suspendMachinePreparation }) {
            await machineResume.wait()
        }
        return PreparedRuntimeIdentity(
            configuration: configuration,
            bootID: UUID(),
            verifiedAt: Date()
        )
    }

    func waitUntilMachinePreparationStarts() async {
        await machineStarted.wait()
    }

    func resumeMachinePreparation() {
        Task { await machineResume.open() }
    }
}

private actor AsyncTestGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}
