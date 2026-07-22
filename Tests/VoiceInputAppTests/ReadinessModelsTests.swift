import XCTest
@testable import VoiceInputApp

final class ReadinessModelsTests: XCTestCase {
    func testStatusSeverityAndBadgeTextAreStable() {
        XCTAssertEqual(ReadinessStatus.ready.badgeText, "Ready")
        XCTAssertEqual(ReadinessStatus.notReady.badgeText, "Not Ready")
        XCTAssertEqual(ReadinessStatus.preparing.badgeText, "Preparing")
        XCTAssertEqual(ReadinessStatus.needsRepair.badgeText, "Needs Repair")
        XCTAssertEqual(ReadinessStatus.optional.badgeText, "Optional")
        XCTAssertEqual(ReadinessStatus.failed("uv missing").badgeText, "Failed")
        XCTAssertEqual(ReadinessStatus.unknown.badgeText, "Unknown")

        XCTAssertEqual(ReadinessStatus.ready.severity, .success)
        XCTAssertEqual(ReadinessStatus.notReady.severity, .warning)
        XCTAssertEqual(ReadinessStatus.needsRepair.severity, .warning)
        XCTAssertEqual(ReadinessStatus.failed("uv missing").severity, .error)
        XCTAssertEqual(ReadinessStatus.optional.severity, .neutral)
    }

    func testCheckStoresActionAndGroup() {
        let check = ReadinessCheck(
            id: "bundled-uv",
            group: .appBundle,
            title: "Bundled uv",
            detail: "Found executable uv inside the app bundle.",
            status: .ready,
            primaryAction: .prepareRuntime
        )

        XCTAssertEqual(check.id, "bundled-uv")
        XCTAssertEqual(check.group, .appBundle)
        XCTAssertEqual(check.primaryAction, .prepareRuntime)
        XCTAssertEqual(check.statusMessage, nil)
    }

    func testFailedStatusMessageIsExposed() {
        let check = ReadinessCheck(
            id: "helper",
            group: .localRuntime,
            title: "Helper",
            detail: "Helper launch failed.",
            status: .failed("Timed out waiting for /health")
        )

        XCTAssertEqual(check.statusMessage, "Timed out waiting for /health")
    }

    func testEmptyReportIsNotReadyForQwenDictation() {
        let report = ReadinessReport(generatedAt: Date(), checks: [])

        XCTAssertFalse(report.isReadyForQwenDictation)
    }

    func testReadyAndOptionalChecksInRequiredGroupsAreReadyForQwenDictation() {
        let report = ReadinessReport(
            generatedAt: Date(),
            checks: [
                readinessCheck(id: "bundle", group: .appBundle, status: .ready),
                readinessCheck(id: "runtime", group: .localRuntime, status: .optional),
                readinessCheck(id: "model", group: .models, status: .ready),
                readinessCheck(id: "permissions", group: .permissions, status: .ready),
                readinessCheck(id: "apple-silicon", group: .performance, status: .ready)
            ]
        )

        XCTAssertTrue(report.isReadyForQwenDictation)
    }

    func testMissingAppleSiliconCheckBlocksQwenDictationReadiness() {
        let report = ReadinessReport(
            generatedAt: Date(),
            checks: [
                readinessCheck(id: "bundle", group: .appBundle, status: .ready),
                readinessCheck(id: "runtime", group: .localRuntime, status: .ready),
                readinessCheck(id: "model", group: .models, status: .ready),
                readinessCheck(id: "permissions", group: .permissions, status: .ready)
            ]
        )

        XCTAssertFalse(report.isReadyForQwenDictation)
    }

    func testNotReadyInRequiredGroupBlocksQwenDictationReadiness() {
        let report = ReadinessReport(
            generatedAt: Date(),
            checks: [
                readinessCheck(id: "bundle", group: .appBundle, status: .ready),
                readinessCheck(id: "runtime", group: .localRuntime, status: .ready),
                readinessCheck(id: "model", group: .models, status: .notReady),
                readinessCheck(id: "permissions", group: .permissions, status: .ready)
            ]
        )

        XCTAssertFalse(report.isReadyForQwenDictation)
    }

    func testSelectedInstalledButNotLoadedWarmCheckBlocksReadyPromise() {
        let report = ReadinessReport(
            generatedAt: Date(),
            checks: [
                readinessCheck(id: "bundle", group: .appBundle, status: .ready),
                readinessCheck(id: "runtime", group: .localRuntime, status: .ready),
                readinessCheck(id: "model-qwen3-asr-0.6b", group: .models, status: .ready),
                readinessCheck(
                    id: "model-qwen3-asr-0.6b-warm",
                    group: .models,
                    status: .optional,
                    locationTarget: .selectedModel
                ),
                readinessCheck(id: "permissions", group: .permissions, status: .ready),
                readinessCheck(id: "apple-silicon", group: .performance, status: .ready)
            ]
        )

        XCTAssertFalse(report.isReadyForQwenDictation)
        XCTAssertTrue(report.requiresSelectedModelWarmup)
        XCTAssertEqual(report.setupSummary.requiredIssueCount, 1)
    }

    func testSetupSummaryCountsBlockingRepairableManualAndOptionalChecks() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1),
            checks: [
                ReadinessCheck(
                    id: "bundled-uv",
                    group: .appBundle,
                    title: "Bundled uv",
                    detail: "Missing.",
                    status: .failed("Bundled uv is missing."),
                    primaryAction: .reinstallFlowtypeApp,
                    secondaryAction: .copyDiagnostics,
                    locationTarget: .appBundle
                ),
                ReadinessCheck(
                    id: "local-helper-copy",
                    group: .localRuntime,
                    title: "Local helper",
                    detail: "Missing.",
                    status: .needsRepair,
                    primaryAction: .repairLocalRuntime,
                    secondaryAction: .copyDiagnostics,
                    locationTarget: .localHelper
                ),
                ReadinessCheck(
                    id: "microphone-permission",
                    group: .permissions,
                    title: "Microphone",
                    detail: "Required.",
                    status: .notReady,
                    primaryAction: .requestMicrophone
                ),
                ReadinessCheck(
                    id: "model-qwen3-asr-1.7b",
                    group: .models,
                    title: "Qwen3-ASR 1.7B",
                    detail: "Optional.",
                    status: .optional,
                    locationTarget: .modelsRoot
                )
            ]
        )

        let summary = report.setupSummary

        XCTAssertEqual(summary.blockingCount, 1)
        XCTAssertEqual(summary.repairableCount, 1)
        XCTAssertEqual(summary.manualCount, 1)
        XCTAssertEqual(summary.optionalCount, 1)
        XCTAssertEqual(summary.requiredIssueCount, 3)
        XCTAssertNil(summary.recommendedPrimaryAction)
    }

    func testSetupSummaryRecommendsPrepareWhenNoBlockingIssueExists() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1),
            checks: [
                ReadinessCheck(
                    id: "local-helper-copy",
                    group: .localRuntime,
                    title: "Local helper",
                    detail: "Missing.",
                    status: .needsRepair,
                    primaryAction: .repairLocalRuntime
                ),
                ReadinessCheck(
                    id: "microphone-permission",
                    group: .permissions,
                    title: "Microphone",
                    detail: "Required.",
                    status: .notReady,
                    primaryAction: .requestMicrophone
                )
            ]
        )

        let summary = report.setupSummary

        XCTAssertEqual(summary.blockingCount, 0)
        XCTAssertEqual(summary.requiredIssueCount, 2)
        XCTAssertEqual(summary.recommendedPrimaryAction, .prepareFlowtype)
    }

    func testSetupSummaryTreatsDefaultModelDownloadAsRequiredManualSetup() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1),
            checks: [
                ReadinessCheck(
                    id: "model-qwen3-asr-0.6b",
                    group: .models,
                    title: "Qwen3-ASR 0.6B",
                    detail: "Download this model before using local Qwen dictation.",
                    status: .notReady,
                    primaryAction: .downloadDefaultModel,
                    locationTarget: .selectedModel
                )
            ]
        )

        let summary = report.setupSummary

        XCTAssertEqual(summary.blockingCount, 0)
        XCTAssertEqual(summary.manualCount, 1)
        XCTAssertEqual(summary.requiredIssueCount, 1)
        XCTAssertEqual(summary.recommendedPrimaryAction, .prepareFlowtype)
    }

    func testSetupSummaryDoesNotCountPerformanceAdvisoriesAsSetupWork() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1),
            checks: [
                ReadinessCheck(
                    id: "memory-tier",
                    group: .performance,
                    title: "Memory tier",
                    detail: "16 GB unified memory detected.",
                    status: .needsRepair
                ),
                ReadinessCheck(
                    id: "selected-model-recommendation",
                    group: .performance,
                    title: "Model recommendation",
                    detail: "Qwen3-ASR 0.6B is recommended for faster dictation on this Mac.",
                    status: .optional
                )
            ]
        )

        let summary = report.setupSummary

        XCTAssertEqual(summary.blockingCount, 0)
        XCTAssertEqual(summary.repairableCount, 0)
        XCTAssertEqual(summary.manualCount, 0)
        XCTAssertEqual(summary.requiredIssueCount, 0)
        XCTAssertNil(summary.recommendedPrimaryAction)
    }

    func testWarmModelActionIsNotRequiredForQwenReadiness() {
        let report = ReadinessReport(
            generatedAt: Date(timeIntervalSince1970: 1),
            checks: [
                ReadinessCheck(id: "app-binary", group: .appBundle, title: "App", detail: "Ready.", status: .ready),
                ReadinessCheck(id: "local-helper-copy", group: .localRuntime, title: "Helper", detail: "Ready.", status: .ready),
                ReadinessCheck(id: "selected-model", group: .models, title: "Selected", detail: "Selected.", status: .ready),
                ReadinessCheck(id: "model-qwen3-asr-0.6b", group: .models, title: "0.6B", detail: "Ready.", status: .ready),
                ReadinessCheck(id: "model-qwen3-asr-0.6b-warm", group: .models, title: "Preload", detail: "Cold.", status: .optional),
                ReadinessCheck(id: "microphone-permission", group: .permissions, title: "Microphone", detail: "Ready.", status: .ready),
                ReadinessCheck(id: "accessibility-permission", group: .permissions, title: "Accessibility", detail: "Ready.", status: .ready),
                ReadinessCheck(id: "apple-silicon", group: .performance, title: "Apple Silicon", detail: "M2 is supported.", status: .ready)
            ]
        )

        XCTAssertTrue(report.isReadyForQwenDictation)
    }

    func testNonAppleSiliconPerformanceWarningDoesNotBlockQwenDictationReadiness() {
        let report = ReadinessReport(
            generatedAt: Date(),
            checks: [
                readinessCheck(id: "bundle", group: .appBundle, status: .ready),
                readinessCheck(id: "runtime", group: .localRuntime, status: .ready),
                readinessCheck(id: "model", group: .models, status: .ready),
                readinessCheck(id: "permissions", group: .permissions, status: .ready),
                readinessCheck(id: "apple-silicon", group: .performance, status: .ready),
                readinessCheck(id: "memory", group: .performance, status: .needsRepair)
            ]
        )

        XCTAssertTrue(report.isReadyForQwenDictation)
    }

    func testAppleSiliconFailedBlocksQwenDictationReadiness() {
        let report = ReadinessReport(
            generatedAt: Date(),
            checks: [
                readinessCheck(id: "bundle", group: .appBundle, status: .ready),
                readinessCheck(id: "runtime", group: .localRuntime, status: .ready),
                readinessCheck(id: "model", group: .models, status: .ready),
                readinessCheck(id: "permissions", group: .permissions, status: .ready),
                readinessCheck(id: "apple-silicon", group: .performance, status: .failed("Intel Mac"))
            ]
        )

        XCTAssertFalse(report.isReadyForQwenDictation)
    }

    func testActionAvailabilityKeepsRecoveryActionsAvailableDuringRefresh() {
        let availability = ReadinessActionAvailability(
            isRefreshing: true,
            activeAction: nil,
            report: ReadinessReport(
                generatedAt: Date(timeIntervalSince1970: 0),
                checks: [
                    readinessCheck(
                        id: "microphone",
                        group: .permissions,
                        status: .notReady,
                        primaryAction: .requestMicrophone
                    )
                ]
            )
        )

        XCTAssertFalse(availability.isCopyDiagnosticsDisabled)
        XCTAssertTrue(availability.isRefreshDisabled)
        XCTAssertFalse(availability.isActionDisabled(.prepareFlowtype))
        XCTAssertFalse(availability.isActionDisabled(.requestMicrophone))
        XCTAssertFalse(availability.isActionDisabled(.openAccessibilitySettings))
        XCTAssertFalse(availability.isActionDisabled(.requestSpeechRecognition))
    }

    func testActionAvailabilityOnlyDisablesSameActiveAction() {
        let availability = ReadinessActionAvailability(
            isRefreshing: false,
            activeAction: .prepareFlowtype,
            report: ReadinessReport(
                generatedAt: Date(timeIntervalSince1970: 0),
                checks: [
                    readinessCheck(
                        id: "model",
                        group: .models,
                        status: .notReady,
                        primaryAction: .downloadDefaultModel
                    )
                ]
            )
        )

        XCTAssertTrue(availability.isActionDisabled(.prepareFlowtype))
        XCTAssertFalse(availability.isCopyDiagnosticsDisabled)
        XCTAssertFalse(availability.isRefreshDisabled)
        XCTAssertFalse(availability.isActionDisabled(.downloadDefaultModel))
    }

    func testActionAvailabilityDisablesPrepareWhenNothingActionable() {
        let availability = ReadinessActionAvailability(
            isRefreshing: false,
            activeAction: nil,
            report: ReadinessReport(
                generatedAt: Date(timeIntervalSince1970: 0),
                checks: [
                    readinessCheck(id: "app", group: .appBundle, status: .ready),
                    readinessCheck(id: "runtime", group: .localRuntime, status: .ready),
                    readinessCheck(id: "model", group: .models, status: .ready),
                    readinessCheck(id: "permissions", group: .permissions, status: .ready)
                ]
            )
        )

        XCTAssertTrue(availability.isActionDisabled(.prepareFlowtype))
    }

    private func readinessCheck(
        id: String,
        group: ReadinessGroup,
        status: ReadinessStatus,
        primaryAction: ReadinessActionKind? = nil,
        locationTarget: ReadinessLocationTarget? = nil
    ) -> ReadinessCheck {
        ReadinessCheck(
            id: id,
            group: group,
            title: id,
            detail: id,
            status: status,
            primaryAction: primaryAction,
            locationTarget: locationTarget
        )
    }
}
