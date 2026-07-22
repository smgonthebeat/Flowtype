import Foundation

enum ReadinessGroup: String, CaseIterable, Identifiable, Codable {
    case appBundle
    case localRuntime
    case models
    case permissions
    case performance

    var id: String { rawValue }
}

enum ReadinessSeverity: String, Codable {
    case success
    case warning
    case error
    case neutral
    case inProgress
}

enum ReadinessStatus: Equatable {
    case ready
    case notReady
    case preparing
    case needsRepair
    case optional
    case failed(String)
    case unknown

    var badgeText: String {
        switch self {
        case .ready: return "Ready"
        case .notReady: return "Not Ready"
        case .preparing: return "Preparing"
        case .needsRepair: return "Needs Repair"
        case .optional: return "Optional"
        case .failed: return "Failed"
        case .unknown: return "Unknown"
        }
    }

    var severity: ReadinessSeverity {
        switch self {
        case .ready: return .success
        case .notReady, .needsRepair: return .warning
        case .preparing: return .inProgress
        case .failed: return .error
        case .optional, .unknown: return .neutral
        }
    }

    var message: String? {
        if case let .failed(message) = self {
            return message
        }
        return nil
    }
}

enum ReadinessActionKind: String, Equatable, Codable {
    case prepareFlowtype
    case reinstallApp
    case reinstallFlowtypeApp
    case prepareRuntime
    case repairHelper
    case repairLocalRuntime
    case restartHelper
    case downloadModel
    case downloadDefaultModel
    case repairModelCache
    case useModel
    case warmModel
    case retryPreload
    case requestMicrophone
    case openAccessibilitySettings
    case requestSpeechRecognition
    case copyDiagnostics
}

enum ReadinessLocationTarget: String, Equatable, Codable {
    case appBundle
    case appResources
    case applicationSupportRoot
    case localHelper
    case modelsRoot
    case selectedModel
    case diagnostics
}

enum ReadinessIssueKind: Equatable {
    case blocking
    case repairable
    case manual
    case optional
    case ready
    case informational
}

struct ReadinessSetupSummary: Equatable {
    let blockingCount: Int
    let repairableCount: Int
    let manualCount: Int
    let optionalCount: Int
    let requiredIssueCount: Int
    let recommendedPrimaryAction: ReadinessActionKind?

    var isComplete: Bool {
        requiredIssueCount == 0
    }
}

struct ReadinessCheck: Identifiable, Equatable {
    let id: String
    let group: ReadinessGroup
    let title: String
    let detail: String
    let status: ReadinessStatus
    let primaryAction: ReadinessActionKind?
    let secondaryAction: ReadinessActionKind?
    let locationTarget: ReadinessLocationTarget?
    let modelSuitabilityRecommendation: ModelSuitabilityRecommendation?

    init(
        id: String,
        group: ReadinessGroup,
        title: String,
        detail: String,
        status: ReadinessStatus,
        primaryAction: ReadinessActionKind? = nil,
        secondaryAction: ReadinessActionKind? = nil,
        locationTarget: ReadinessLocationTarget? = nil,
        modelSuitabilityRecommendation: ModelSuitabilityRecommendation? = nil
    ) {
        self.id = id
        self.group = group
        self.title = title
        self.detail = detail
        self.status = status
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.locationTarget = locationTarget
        self.modelSuitabilityRecommendation = modelSuitabilityRecommendation
    }

    var statusMessage: String? {
        status.message
    }
}

struct ReadinessReport: Equatable {
    let generatedAt: Date
    let checks: [ReadinessCheck]

    func checks(in group: ReadinessGroup) -> [ReadinessCheck] {
        checks.filter { $0.group == group }
    }

    var setupSummary: ReadinessSetupSummary {
        let issueKinds = checks.map(\.issueKind)
        let blockingCount = issueKinds.filter { $0 == .blocking }.count
        let repairableCount = issueKinds.filter { $0 == .repairable }.count + (requiresSelectedModelWarmup ? 1 : 0)
        let manualCount = issueKinds.filter { $0 == .manual }.count
        let optionalCount = issueKinds.filter { $0 == .optional }.count
        let requiredIssueCount = blockingCount + repairableCount + manualCount

        return ReadinessSetupSummary(
            blockingCount: blockingCount,
            repairableCount: repairableCount,
            manualCount: manualCount,
            optionalCount: optionalCount,
            requiredIssueCount: requiredIssueCount,
            recommendedPrimaryAction: blockingCount == 0 && requiredIssueCount > 0 ? .prepareFlowtype : nil
        )
    }

    var requiresSelectedModelWarmup: Bool {
        if checks.contains(where: { $0.id == "speech-recognition-permission" }) {
            return false
        }
        guard let warmCheck = checks.first(where: {
            $0.id.hasSuffix("-warm") && $0.locationTarget == .selectedModel
        }) else {
            return false
        }
        let installCheckID = String(warmCheck.id.dropLast("-warm".count))
        guard let installCheck = checks.first(where: { $0.id == installCheckID }),
              installCheck.status == .ready else {
            return false
        }
        return warmCheck.status != .ready
    }

    var isReadyForQwenDictation: Bool {
        let requiredGroups: [ReadinessGroup] = [.appBundle, .localRuntime, .models, .permissions]
        let requiredGroupsAreReady = requiredGroups.allSatisfy { group in
            let groupChecks = checks(in: group)
            return !groupChecks.isEmpty && groupChecks.allSatisfy(\.isReadyOrOptional)
        }
        let appleSiliconIsReady = checks
            .contains { $0.group == .performance && $0.id == "apple-silicon" && $0.status == .ready }

        return requiredGroupsAreReady && appleSiliconIsReady && !requiresSelectedModelWarmup
    }
}

struct ReadinessActionAvailability: Equatable {
    let isRefreshing: Bool
    let activeAction: ReadinessActionKind?
    let report: ReadinessReport
    var hasActionableSetupOverride: Bool? = nil

    var isRefreshDisabled: Bool {
        isRefreshing
    }

    var isCopyDiagnosticsDisabled: Bool {
        false
    }

    func isActionDisabled(_ action: ReadinessActionKind) -> Bool {
        if activeAction == action {
            return true
        }

        switch action {
        case .copyDiagnostics,
             .requestMicrophone,
             .openAccessibilitySettings,
             .requestSpeechRecognition:
            return false
        case .prepareFlowtype:
            return !hasActionableSetup
        case .reinstallApp,
             .reinstallFlowtypeApp,
             .prepareRuntime,
             .repairHelper,
             .repairLocalRuntime,
             .restartHelper,
             .downloadModel,
             .downloadDefaultModel,
             .repairModelCache,
             .useModel,
             .warmModel,
             .retryPreload:
            return false
        }
    }

    private var hasActionableSetup: Bool {
        hasActionableSetupOverride ?? (report.setupSummary.requiredIssueCount > 0)
    }
}

private extension ReadinessCheck {
    var isReadyOrOptional: Bool {
        status == .ready || status == .optional
    }

    var issueKind: ReadinessIssueKind {
        guard isRequiredGroup else {
            return status == .ready ? .ready : .optional
        }

        switch status {
        case .ready:
            return .ready
        case .optional, .unknown:
            return .optional
        case .preparing:
            return .informational
        case .failed where primaryAction == .copyDiagnostics && isRequiredGroup:
            return .blocking
        case .notReady, .needsRepair, .failed:
            return issueKindForAction(primaryAction)
        }
    }

    private var isRequiredGroup: Bool {
        switch group {
        case .appBundle, .localRuntime, .models, .permissions:
            return true
        case .performance:
            return false
        }
    }

    private func issueKindForAction(_ action: ReadinessActionKind?) -> ReadinessIssueKind {
        switch action {
        case .reinstallFlowtypeApp, .reinstallApp:
            return .blocking
        case .prepareRuntime, .repairHelper, .repairLocalRuntime, .restartHelper:
            return .repairable
        case .downloadDefaultModel, .requestMicrophone, .openAccessibilitySettings, .requestSpeechRecognition:
            return .manual
        case .copyDiagnostics, .downloadModel, .repairModelCache, .useModel, .warmModel, .retryPreload:
            return .optional
        case .prepareFlowtype:
            return .repairable
        case nil:
            return .blocking
        }
    }
}
