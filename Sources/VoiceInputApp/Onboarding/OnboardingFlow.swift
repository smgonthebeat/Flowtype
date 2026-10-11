import Foundation

/// Ordered steps of the first-run onboarding flow. Permissions and model
/// download share one step because `prepareFlowtype(.interactiveSetup)`
/// already drives both from a single action. `holdFn` and `practice` exist
/// because users kept treating Fn as tap-to-start / tap-to-stop (owner
/// report, 2026-10-10); `features` surfaces the formatting switches that are
/// off by default.
enum OnboardingStep: Int, CaseIterable, Identifiable, Equatable {
    case welcome
    case prepare
    case holdFn
    case practice
    case features

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
    var requestClose: (ReadinessSnapshot?) -> Void
    /// Routes dictation results into the practice page instead of pasting
    /// them. Passing nil returns dictation to normal paste behaviour.
    var setPracticeListener: (((OnboardingPracticeEvent) -> Void)?) -> Void
    /// Called after the welcome page switches the interface language, so the rest of
    /// the app (menus, main window) can redraw.
    var uiLanguageDidChange: (UILanguage) -> Void

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
        requestClose: @escaping (ReadinessSnapshot?) -> Void = { _ in },
        setPracticeListener: @escaping (((OnboardingPracticeEvent) -> Void)?) -> Void = { _ in },
        uiLanguageDidChange: @escaping (UILanguage) -> Void = { _ in }
    ) {
        self.permissionSnapshot = permissionSnapshot
        self.openMicrophoneSettings = openMicrophoneSettings
        self.openAccessibilitySettings = openAccessibilitySettings
        self.prepareFlowtype = prepareFlowtype
        self.requestClose = requestClose
        self.setPracticeListener = setPracticeListener
        self.uiLanguageDidChange = uiLanguageDidChange
    }
}

enum OnboardingReadinessHandoff {
    static func resolvedSnapshot(
        completed: ReadinessSnapshot?,
        current: ReadinessSnapshot
    ) -> ReadinessSnapshot {
        guard let completed, completed.context == current.context else {
            return current
        }
        return completed
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

    /// Continue unlocks only when permissions and the model are ready. The
    /// next page invites the user to press Fn, and a press before setup has
    /// finished would fail and look like a bug (owner decision, 2026-10-11).
    var allowsContinue: Bool {
        isReady
    }

    static func state(for outcome: ReadinessSetupResult.Outcome, language: UILanguage) -> OnboardingPrepareState {
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
            return .failed(UserFacingErrorMessage.message(for: PreparationFailure.appBundleInvalid, language: language))
        case let .failed(message):
            return .failed(message)
        }
    }
}

/// Where the model is being downloaded from. The helper always tries
/// ModelScope first and falls back to Hugging Face (`download_source_order`).
enum OnboardingDownloadRoute: Equatable {
    case modelScope
    case huggingFace

    init?(source: String?) {
        switch source {
        case "modelscope": self = .modelScope
        case "huggingface": self = .huggingFace
        default: return nil
        }
    }
}

/// Dictation lifecycle events the app forwards to the practice page.
enum OnboardingPracticeEvent: Equatable {
    case listening
    case transcribing
    case tooShort
    case result(String)
    case failed(String)
}

/// What the practice page shows. `apply` is the whole reducer so the page
/// and its tests agree on every transition.
enum OnboardingPracticeState: Equatable {
    case waiting
    case listening
    case transcribing
    case succeeded(String)
    case tooShort
    case failed(String)

    var isHoldingKey: Bool { self == .listening }

    func applying(_ event: OnboardingPracticeEvent) -> OnboardingPracticeState {
        switch event {
        case .listening: return .listening
        case .transcribing: return .transcribing
        case .tooShort: return .tooShort
        case let .result(text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? .failed("") : .succeeded(trimmed)
        case let .failed(message): return .failed(message)
        }
    }
}
