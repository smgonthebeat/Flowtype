import Foundation

protocol PackageInspecting {
    func inspect(bundleURL: URL, resourceURL: URL?) -> [ReadinessCheck]
}

extension PackageInspector: PackageInspecting {}

protocol HelperRuntimeManaging: AnyObject {
    var applicationSupportRoot: URL { get }

    func snapshot() -> HelperRuntimeSnapshot
    func prepareRuntime() throws -> URL
    func repairHelperCopy() throws -> URL
}

extension HelperRuntimeManager: HelperRuntimeManaging {}

struct ReadinessService {
    private let packageInspector: PackageInspecting
    private let helperRuntimeManager: HelperRuntimeManaging
    private let permissionInspector: PermissionReadinessInspector
    private let modelReadinessInspector: ModelReadinessInspector
    private let performanceInspector: PerformanceInspector
    private let diagnosticsExporter: DiagnosticsExporter
    private let modelStatusFetcher: (String) async throws -> QwenModelStatus
    private let timingProvider: () -> TranscriptionTimingSample?
    private let processProvider: () -> [ProcessRSSSnapshot]
    private let dateProvider: () -> Date

    init(
        packageInspector: PackageInspecting = PackageInspector(),
        helperRuntimeManager: HelperRuntimeManaging = HelperRuntimeManager(),
        permissionInspector: PermissionReadinessInspector = PermissionReadinessInspector(),
        modelReadinessInspector: ModelReadinessInspector = ModelReadinessInspector(),
        performanceInspector: PerformanceInspector = PerformanceInspector(),
        diagnosticsExporter: DiagnosticsExporter = DiagnosticsExporter(),
        modelStatusFetcher: @escaping (String) async throws -> QwenModelStatus,
        timingProvider: @escaping () -> TranscriptionTimingSample? = {
            try? TranscriptionTimingStore().loadLastSample()
        },
        processProvider: @escaping () -> [ProcessRSSSnapshot] = ProcessRSSSnapshot.flowtypeRelatedProcesses,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.packageInspector = packageInspector
        self.helperRuntimeManager = helperRuntimeManager
        self.permissionInspector = permissionInspector
        self.modelReadinessInspector = modelReadinessInspector
        self.performanceInspector = performanceInspector
        self.diagnosticsExporter = diagnosticsExporter
        self.modelStatusFetcher = modelStatusFetcher
        self.timingProvider = timingProvider
        self.processProvider = processProvider
        self.dateProvider = dateProvider
    }

    func lightweightReport(
        permissionSnapshot: PermissionSnapshot,
        selectedModelID: String,
        includeSpeechRecognition: Bool,
        bundleURL: URL = Bundle.main.bundleURL,
        resourceURL: URL? = Bundle.main.resourceURL
    ) -> ReadinessReport {
        makeReport(
            permissionSnapshot: permissionSnapshot,
            selectedModelID: selectedModelID,
            includeSpeechRecognition: includeSpeechRecognition,
            helperStatuses: [:],
            helperStatusFailures: [:],
            usesFullPerformanceInspection: false,
            bundleURL: bundleURL,
            resourceURL: resourceURL
        )
    }

    func reportWithHelperModelStatus(
        permissionSnapshot: PermissionSnapshot,
        selectedModelID: String,
        includeSpeechRecognition: Bool,
        includePerformanceDetails: Bool = true,
        bundleURL: URL = Bundle.main.bundleURL,
        resourceURL: URL? = Bundle.main.resourceURL
    ) async -> ReadinessReport {
        var statuses: [String: QwenModelStatus] = [:]
        var failures: [String: Error] = [:]
        for model in VoiceInputModel.all {
            do {
                let status = try await modelStatusFetcher(model.modelID)
                statuses[model.modelID] = status
            } catch {
                failures[model.modelID] = error
            }
        }

        return makeReport(
            permissionSnapshot: permissionSnapshot,
            selectedModelID: selectedModelID,
            includeSpeechRecognition: includeSpeechRecognition,
            helperStatuses: statuses,
            helperStatusFailures: failures,
            usesFullPerformanceInspection: includePerformanceDetails,
            bundleURL: bundleURL,
            resourceURL: resourceURL
        )
    }

    func prepareRuntime() throws -> URL {
        try helperRuntimeManager.prepareRuntime()
    }

    func repairHelperCopy() throws -> URL {
        try helperRuntimeManager.repairHelperCopy()
    }

    func diagnosticsText(report: ReadinessReport, provenance: TranscriptionProvenance? = nil) -> String {
        diagnosticsExporter.makeDiagnosticsText(
            report: report,
            timing: timingProvider(),
            processes: processProvider(),
            provenance: provenance
        )
    }

    private func makeReport(
        permissionSnapshot: PermissionSnapshot,
        selectedModelID: String,
        includeSpeechRecognition: Bool,
        helperStatuses: [String: QwenModelStatus],
        helperStatusFailures: [String: Error],
        usesFullPerformanceInspection: Bool,
        bundleURL: URL,
        resourceURL: URL?
    ) -> ReadinessReport {
        let selectedModel = VoiceInputModel.model(for: selectedModelID)
        let snapshot = helperRuntimeManager.snapshot()
        let checks =
            packageInspector.inspect(bundleURL: bundleURL, resourceURL: resourceURL) +
            runtimeChecks(snapshot: snapshot) +
            permissionInspector.inspect(
                snapshot: permissionSnapshot,
                includeSpeechRecognition: includeSpeechRecognition
            ) +
            modelReadinessInspector.inspect(
                applicationSupportRoot: helperRuntimeManager.applicationSupportRoot,
                selectedModelID: selectedModel.id,
                helperStatuses: helperStatuses
            ) +
            helperStatusFailureChecks(
                failures: helperStatusFailures,
                selectedModel: selectedModel
            ) +
            performanceChecks(
                selectedModel: selectedModel,
                usesFullInspection: usesFullPerformanceInspection
            )

        return ReadinessReport(generatedAt: dateProvider(), checks: checks)
    }

    private func performanceChecks(
        selectedModel: VoiceInputModel,
        usesFullInspection: Bool
    ) -> [ReadinessCheck] {
        if usesFullInspection {
            return performanceInspector.inspect(selectedModel: selectedModel)
        }
        return performanceInspector.inspectLightweight(selectedModel: selectedModel)
    }

    private func helperStatusFailureChecks(
        failures: [String: Error],
        selectedModel: VoiceInputModel
    ) -> [ReadinessCheck] {
        VoiceInputModel.all.compactMap { model in
            guard failures[model.modelID] != nil else {
                return nil
            }

            if model.id == selectedModel.id {
                return ReadinessCheck(
                    id: "helper-model-status-\(model.id)",
                    group: .models,
                    title: "\(model.displayName) helper status",
                    detail: "Flowtype could not refresh the selected model status from the local helper.",
                    status: .failed("Could not refresh selected Qwen model status."),
                    primaryAction: .copyDiagnostics
                )
            }

            return ReadinessCheck(
                id: "helper-model-status-\(model.id)",
                group: .models,
                title: "\(model.displayName) helper status",
                detail: "Flowtype could not refresh this optional model status from the local helper.",
                status: .optional,
                primaryAction: .copyDiagnostics
            )
        }
    }

    private func runtimeChecks(snapshot: HelperRuntimeSnapshot) -> [ReadinessCheck] {
        [
            applicationSupportCheck(status: snapshot.applicationSupportStatus),
            helperCopyCheck(status: snapshot.helperCopyStatus, helperDirectory: snapshot.helperDirectory),
            bundledUVCheck(status: snapshot.bundledUVStatus)
        ]
    }

    private func applicationSupportCheck(status: ReadinessStatus) -> ReadinessCheck {
        ReadinessCheck(
            id: "application-support-root",
            group: .localRuntime,
            title: "Application Support folder",
            detail: status == .ready
                ? "Flowtype can use its Application Support folder."
                : "Prepare Flowtype's local runtime folder in Application Support.",
            status: status,
            primaryAction: status == .ready ? nil : .prepareRuntime,
            secondaryAction: status == .ready ? nil : .copyDiagnostics,
            locationTarget: .applicationSupportRoot
        )
    }

    private func helperCopyCheck(status: ReadinessStatus, helperDirectory: URL) -> ReadinessCheck {
        let action: ReadinessActionKind?
        switch status {
        case .ready:
            action = nil
        default:
            action = .prepareRuntime
        }

        return ReadinessCheck(
            id: "local-helper-copy",
            group: .localRuntime,
            title: "Local Qwen helper copy",
            detail: status == .ready
                ? "The local helper copy is ready at \(helperDirectory.path)."
                : "Prepare or repair the local helper copy before Qwen dictation.",
            status: status,
            primaryAction: action,
            secondaryAction: status == .ready ? nil : .copyDiagnostics,
            locationTarget: .localHelper
        )
    }

    private func bundledUVCheck(status: ReadinessStatus) -> ReadinessCheck {
        let action: ReadinessActionKind?
        switch status {
        case .ready:
            action = nil
        case .needsRepair:
            action = .repairLocalRuntime
        default:
            action = .reinstallFlowtypeApp
        }

        return ReadinessCheck(
            id: "local-bundled-uv",
            group: .localRuntime,
            title: "Bundled uv runtime",
            detail: status == .ready
                ? "Flowtype can launch the helper with bundled uv."
                : "Bundled uv is required for a standalone Flowtype install.",
            status: status,
            primaryAction: action,
            secondaryAction: status == .ready ? nil : .copyDiagnostics,
            locationTarget: .appResources
        )
    }
}
