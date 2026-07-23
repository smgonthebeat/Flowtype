import Foundation

/// Ordered steps of the first-run onboarding flow. Permissions and model
/// download share one step because `prepareFlowtype(.interactiveSetup)`
/// already drives both from a single action.
enum OnboardingStep: Int, CaseIterable, Identifiable, Equatable {
    case welcome
    case prepare
    case howTo

    var id: Int { rawValue }

    var isFirst: Bool { self == OnboardingStep.allCases.first }
    var isLast: Bool { self == OnboardingStep.allCases.last }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}

/// Host-provided capabilities for the onboarding flow. The window controller
/// injects `requestClose`; everything else is wired by the app delegate so the
/// flow reuses the same permission and preparation paths as the main window.
struct OnboardingActions {
    var permissionSnapshot: () -> PermissionSnapshot
    var openMicrophoneSettings: () -> Void
    var openAccessibilitySettings: () -> Void
    var prepareFlowtype: (
        PreparationIntent,
        String,
        @escaping (PreparationSnapshot) -> Void
    ) async -> ReadinessSetupResult
    var requestClose: () -> Void

    init(
        permissionSnapshot: @escaping () -> PermissionSnapshot = {
            PermissionSnapshot(microphone: .unknown, accessibility: .unknown, speechRecognition: .unknown)
        },
        openMicrophoneSettings: @escaping () -> Void = {},
        openAccessibilitySettings: @escaping () -> Void = {},
        prepareFlowtype: @escaping (
            PreparationIntent,
            String,
            @escaping (PreparationSnapshot) -> Void
        ) async -> ReadinessSetupResult = { _, _, _ in
            ReadinessSetupResult(
                outcome: .failed("Setup is unavailable."),
                report: ReadinessReport(generatedAt: Date(), checks: [])
            )
        },
        requestClose: @escaping () -> Void = {}
    ) {
        self.permissionSnapshot = permissionSnapshot
        self.openMicrophoneSettings = openMicrophoneSettings
        self.openAccessibilitySettings = openAccessibilitySettings
        self.prepareFlowtype = prepareFlowtype
        self.requestClose = requestClose
    }
}

/// Presentation state of the embedded prepare step.
enum OnboardingPrepareState: Equatable {
    case idle
    case running(PreparationStage, Double?)
    case ready
    case waitingForPermissions
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isReady: Bool {
        self == .ready
    }

    static func state(for outcome: ReadinessSetupResult.Outcome) -> OnboardingPrepareState {
        switch outcome {
        case .prepared:
            return .ready
        case .waitingForPermissions:
            return .waitingForPermissions
        case .waitingForModelDownloadConsent, .waitingForModelDownload:
            // Consent is recorded when the user taps the prepare button, so
            // these outcomes only appear if that recording failed or the
            // download is still pending; treat them as retryable idle rather
            // than an error.
            return .idle
        case .blockedByAppBundle:
            return .failed("Flowtype's app bundle is incomplete.")
        case let .failed(message):
            return .failed(message)
        }
    }
}
