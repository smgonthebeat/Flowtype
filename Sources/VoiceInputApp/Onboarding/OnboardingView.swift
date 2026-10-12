import AppKit
import SwiftUI

enum OnboardingLayout {
    /// The window at the small text size. Only `large` lengthens it a little, so the
    /// fixed-height pages keep their footer clear; the width and layout stay the same.
    static let baseWindowSize = NSSize(width: 680, height: 660)

    static func windowSize(for textSize: AppTextSize) -> NSSize {
        let extraHeight: CGFloat = textSize == .large ? 40 : 0
        return NSSize(width: baseWindowSize.width, height: baseWindowSize.height + extraHeight)
    }
}

struct OnboardingView: View {
    @Environment(\.appTheme) private var theme

    let model: VoiceInputModel
    let actions: OnboardingActions
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject private var textSizeModel = AppTextSizeModel.shared
    /// Fixed animation time for the offscreen snapshot harness; nil animates.
    var illustrationStillTime: Double? = nil

    @State private var step: OnboardingStep = .welcome
    @State private var permissions: PermissionSnapshot?
    @State private var prepareState: OnboardingPrepareState = .idle
    @State private var completedReadinessSnapshot: ReadinessSnapshot?
    @State private var downloadEstimator = DownloadTransferEstimator()
    @State private var downloadFeedback: DownloadTransferFeedback?
    @State private var downloadRoute: OnboardingDownloadRoute?
    @State private var practiceState: OnboardingPracticeState = .waiting
    @State private var practiceHoldStart: Date?

    /// Both tables follow the stored language, so the language switch redraws every page.
    private var copy: AppCopy.Texts {
        AppCopy.texts(for: settingsStore.uiLanguage)
    }

    private var guide: OnboardingCopy.Texts {
        OnboardingCopy.texts(for: settingsStore.uiLanguage)
    }

    var body: some View {
        VStack(spacing: 0) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 40)
                .padding(.top, 34)

            footer
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
        }
        .frame(
            width: OnboardingLayout.windowSize(for: textSizeModel.size).width,
            height: OnboardingLayout.windowSize(for: textSizeModel.size).height
        )
        .background(ThemeBackdropView(theme: theme))
        .onAppear(perform: refreshPermissions)
        .onChange(of: step) { _, newStep in
            updatePracticeListener(for: newStep)
        }
        .onDisappear {
            actions.setPracticeListener(nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
            resumePreparationIfWaiting()
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .prepare:
            prepareStep
        case .holdFn:
            holdFnStep
        case .practice:
            practiceStep
        case .features:
            featuresStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed gap under the corner switch; spare height goes below the content.
            Color.clear.frame(height: 44)

            if let mark = FlowtypeLogoAsset.templateMark {
                Image(nsImage: mark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 46)
                    .foregroundStyle(theme.ink)
            }

            Text(copy.onboardingWelcomeTitle)
                .scaledFont(size: 38, weight: .semibold)
                .foregroundStyle(theme.ink)
                .padding(.top, 20)

            Text(copy.onboardingWelcomeBody)
                .scaledFont(size: 15)
                .foregroundStyle(theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            WelcomeFlowIllustration(copy: guide, listeningText: copy.capsuleListening)
                .padding(.vertical, 22)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .themedCard(theme, cornerRadius: 14)
                .padding(.top, 26)

            Label(copy.onboardingPrivacyNote, systemImage: "lock.shield")
                .scaledFont(.callout)
                .foregroundStyle(theme.secondaryInk)
                .padding(.top, 16)

            Spacer(minLength: 0)
        }
        // The switch floats in the corner so it takes no height, and the content starts just
        // below it instead of being centred, which made the page sink (owner feedback,
        // 2026-10-11).
        .overlay(alignment: .topTrailing) {
            languageSwitch
        }
    }

    /// First-launch language choice (owner decision, 2026-10-11). Each option is written in
    /// its own language so it can be found whichever language is showing.
    private var languageSwitch: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .scaledFont(size: 13, weight: .medium)
                .foregroundStyle(theme.secondaryInk)
            FlowtypeSegmentedPicker(
                theme: theme,
                selection: Binding(
                    get: { settingsStore.uiLanguage },
                    set: { language in
                        guard language != settingsStore.uiLanguage else { return }
                        settingsStore.uiLanguage = language
                        settingsStore.objectWillChange.send()
                        actions.uiLanguageDidChange(language)
                    }
                ),
                options: [(.chinese, "中文"), (.english, "English")]
            )
            .accessibilityLabel("Language / 语言")
        }
    }

    private var prepareStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(
                title: copy.onboardingPrepareTitle,
                body: onboardingPrepareBody
            )

            VStack(alignment: .leading, spacing: 0) {
                permissionStatusRow(
                    symbol: "mic.fill",
                    title: copy.onboardingMicrophoneTitle,
                    detail: copy.onboardingMicrophoneDetail,
                    state: permissions?.microphone ?? .unknown
                )
                Divider()
                permissionStatusRow(
                    symbol: "figure.wave",
                    title: copy.onboardingAccessibilityTitle,
                    detail: copy.onboardingAccessibilityDetail,
                    state: permissions?.accessibility ?? .unknown
                )
                Divider()

                prepareControls
                    .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(theme, cornerRadius: 12)

        }
    }

    @ViewBuilder
    private var prepareControls: some View {
        switch prepareState {
        case .idle:
            Button {
                startPreparation()
            } label: {
                Label(copy.readinessPrepareFlowtypeTitle, systemImage: "wand.and.stars")
            }
            .buttonStyle(FlowtypeProminentButtonStyle(theme: theme, isLarge: true))

        case let .running(stage, progress):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(stageTitle(stage))
                        .scaledFont(.callout, weight: .medium)
                        .foregroundStyle(theme.ink)
                    Spacer(minLength: 8)
                    if let progress {
                        Text(progressPercentage(progress))
                            .scaledFont(.caption, monospacedDigit: true)
                            .foregroundStyle(theme.secondaryInk)
                    }
                }
                if let progress {
                    FlowtypeProgressBar(theme: theme, value: progress)
                }
                if let detail = stageDetail(stage) {
                    Text(detail)
                        .scaledFont(.caption)
                        .foregroundStyle(theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if stage == .downloadingModel, let downloadFeedback {
                    downloadFeedbackView(downloadFeedback)
                }
                if stage == .downloadingModel {
                    downloadRouteView
                }
            }

        case .ready:
            Label(copy.onboardingPrepareReadyTitle, systemImage: "checkmark.circle.fill")
                .scaledFont(.headline)
                .foregroundStyle(theme.success)

        case .waitingForPermissions:
            VStack(alignment: .leading, spacing: 12) {
                Label(copy.onboardingPreparePermissionsHint, systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button(copy.onboardingOpenSettingsTitle) {
                    openSettingsForMissingPermission()
                }
                .buttonStyle(FlowtypeNeutralButtonStyle(theme: theme))
            }

        case let .failed(message):
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(message)
                        .lineLimit(3)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .scaledFont(.callout)
                .foregroundStyle(theme.danger)
                Button {
                    startPreparation()
                } label: {
                    Label(copy.readinessRefreshTitle, systemImage: "arrow.clockwise")
                }
                .buttonStyle(FlowtypeNeutralButtonStyle(theme: theme))
            }
        }
    }

    private var holdFnStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(title: guide.holdTitle, body: guide.holdSubtitle)

            HoldFnAnimation(
                copy: guide,
                listeningText: copy.capsuleListening,
                transcribingText: copy.capsuleTranscribing,
                stillTime: illustrationStillTime
            )
        }
    }

    private var practiceStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(title: guide.practiceTitle, body: guide.practiceSubtitle)

            if practiceState.isHoldingKey && illustrationStillTime == nil {
                TimelineView(.animation) { context in
                    practiceScene(now: context.date)
                }
            } else {
                practiceScene(now: practiceHoldStart.map { $0.addingTimeInterval(illustrationStillTime ?? 0) } ?? Date())
            }

            practiceStatus

            Spacer(minLength: 0)

            Label(guide.holdExternalKeyboardNote, systemImage: "keyboard")
                .scaledFont(.caption)
                .foregroundStyle(theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Same scene as the hold-Fn page, driven by the real key: the drawn fn key sinks,
    /// counts the seconds held and fills its ring while Fn is down.
    private func practiceScene(now: Date) -> some View {
        let held = practiceHoldStart.map { now.timeIntervalSince($0) } ?? 0
        let capsule: MockCapsuleKind? = switch practiceState {
        case .listening: .listening
        case .transcribing: .transcribing
        default: nil
        }
        return DictationScene(
            text: practiceText,
            placeholder: guide.practicePlaceholder,
            capsule: capsule,
            listeningText: copy.capsuleListening,
            transcribingText: copy.capsuleTranscribing,
            clock: now.timeIntervalSinceReferenceDate,
            fnPressAmount: practiceState.isHoldingKey ? 1 : 0,
            fingertipOpacity: practiceState.isHoldingKey ? 1 : 0,
            holdProgress: practiceState.isHoldingKey ? held / Self.practiceRingSeconds : 0,
            holdingText: practiceState.isHoldingKey ? guide.holdingText(seconds: held) : nil,
            copy: guide
        )
        .animation(.easeInOut(duration: HoldFnAnimation.travel), value: practiceState.isHoldingKey)
    }

    /// Seconds of holding that fill the ring once; most sentences take about this long.
    private static let practiceRingSeconds: Double = 3

    private var practiceText: String {
        if case let .succeeded(text) = practiceState { return text }
        return ""
    }

    @ViewBuilder
    private var practiceStatus: some View {
        if prepareState.isRunning {
            statusPill(practiceNotReadyText, symbol: "arrow.down.circle", color: theme.secondaryInk, showsProgress: true)
        } else {
            switch practiceState {
            case .waiting:
                statusPill(guide.practiceSuggestion, symbol: "quote.bubble", color: theme.secondaryInk)
            case .listening:
                statusPill(guide.practiceListening, symbol: "waveform", color: theme.voiceInk)
            case .transcribing:
                statusPill(guide.practiceTranscribing, symbol: "ellipsis", color: theme.voiceInk, showsProgress: true)
            case .succeeded:
                statusPill(guide.practiceSucceeded, symbol: "checkmark.circle.fill", color: theme.success)
            case .tooShort:
                statusPill(guide.practiceTooShort, symbol: "hand.raised.fill", color: theme.warning)
            case let .failed(message):
                statusPill(
                    message.isEmpty ? guide.practiceFailed : guide.practiceFailedWithReason(message),
                    symbol: "exclamationmark.triangle.fill",
                    color: theme.danger
                )
            }
        }
    }

    private var practiceNotReadyText: String {
        if case let .running(_, progress?) = prepareState {
            return "\(guide.practiceNotReady) · \(progressPercentage(progress))"
        }
        return guide.practiceNotReady
    }

    private func statusPill(_ text: String, symbol: String, color: Color, showsProgress: Bool = false) -> some View {
        HStack(spacing: 9) {
            if showsProgress {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: symbol)
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(color)
            }
            Text(text)
                .scaledFont(size: 13.5, weight: .medium)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 1))
        .clipShape(Capsule())
    }

    private var featuresStep: some View {
        let preferences = PreferencesCopy.texts(for: settingsStore.uiLanguage)
        return VStack(alignment: .leading, spacing: 14) {
            stepHeader(title: guide.featuresTitle, body: guide.featuresSubtitle)

            VStack(spacing: 0) {
                featureRow(
                    symbol: "number",
                    title: preferences.numericFormattingTitle,
                    examples: guide.numericExamples,
                    isDefaultOn: true,
                    isOn: settingBinding(\.isSmartNumericFormattingEnabled),
                    accessibilityLabel: preferences.numericFormattingToggle
                )
                Divider().overlay(theme.divider)
                featureRow(
                    symbol: "scissors",
                    title: preferences.fillerCleanupTitle,
                    examples: guide.fillerExamples,
                    isDefaultOn: true,
                    isOn: settingBinding(\.isFillerCleanupEnabled),
                    accessibilityLabel: preferences.fillerCleanupToggle
                )
                Divider().overlay(theme.divider)
                featureRow(
                    symbol: "list.number",
                    title: preferences.academicReferenceFormattingTitle,
                    examples: guide.academicExamples,
                    isDefaultOn: false,
                    isOn: settingBinding(\.isAcademicReferenceFormattingEnabled),
                    accessibilityLabel: preferences.academicReferenceFormattingToggle
                )
                Divider().overlay(theme.divider)
                featureRow(
                    symbol: "function",
                    title: preferences.mathNotationTitle,
                    examples: guide.mathExamples(for: settingsStore.mathNotationOutputFormat),
                    isDefaultOn: false,
                    isOn: settingBinding(\.isMathNotationEnabled),
                    accessibilityLabel: preferences.mathNotationToggle
                ) {
                    if settingsStore.isMathNotationEnabled {
                        FlowtypeSegmentedPicker(
                            theme: theme,
                            selection: Binding(
                                get: { settingsStore.mathNotationOutputFormat },
                                set: {
                                    settingsStore.mathNotationOutputFormat = $0
                                    settingsStore.objectWillChange.send()
                                }
                            ),
                            options: [(.latex, preferences.latex), (.unicode, preferences.unicode)]
                        )
                        .accessibilityLabel(preferences.mathOutputFormatTitle)
                    }
                }
            }
            .themedCard(theme, cornerRadius: 14)
        }
    }

    private func settingBinding(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Bool>) -> Binding<Bool> {
        Binding(
            get: { settingsStore[keyPath: keyPath] },
            set: {
                settingsStore[keyPath: keyPath] = $0
                // These setters only write UserDefaults; publish so the switch redraws.
                settingsStore.objectWillChange.send()
            }
        )
    }

    private func featureRow<Extra: View>(
        symbol: String,
        title: String,
        examples: [OnboardingExample],
        isDefaultOn: Bool,
        isOn: Binding<Bool>,
        accessibilityLabel: String,
        @ViewBuilder extra: () -> Extra = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: symbol)
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(theme.accent)
                    .frame(width: 28, height: 28)
                    .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .scaledFont(.headline)
                    .foregroundStyle(theme.ink)
                if isDefaultOn {
                    Text(guide.defaultOnBadge)
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(theme.success)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.success.opacity(0.14)))
                }
                Spacer(minLength: 8)
                extra()
                Toggle(isOn: isOn) { EmptyView() }
                    .flowtypeSwitch(theme)
                    .accessibilityLabel(accessibilityLabel)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                ForEach(examples.indices, id: \.self) { index in
                    GridRow {
                        Text(examples[index].spoken)
                            .foregroundStyle(theme.tertiaryInk)
                        Image(systemName: "arrow.right")
                            .scaledFont(size: 9, weight: .bold)
                            .foregroundStyle(theme.tertiaryInk)
                        Text(examples[index].written)
                            .foregroundStyle(theme.ink)
                            .fontWeight(.medium)
                    }
                    .lineLimit(1)
                }
            }
            .scaledFont(size: 12.5)
            .padding(.leading, 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Shared pieces

    private func stepHeader(title: String, body: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .scaledFont(size: 28, weight: .semibold)
                .foregroundStyle(theme.ink)
            if let body {
                Text(body)
                    .scaledFont(.callout)
                    .foregroundStyle(theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Read-only permission status line; the single prepare button below
    /// drives the actual requests.
    private func permissionStatusRow(
        symbol: String,
        title: String,
        detail: String,
        state: PermissionState
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .scaledFont(size: 16, weight: .semibold)
                .foregroundStyle(theme.accent)
                .frame(width: 30, height: 30)
                .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(.headline)
                    .foregroundStyle(theme.ink)
                Text(state == .denied ? copy.onboardingDeniedTitle : detail)
                    .scaledFont(.callout)
                    .foregroundStyle(state == .denied ? theme.danger : theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if state == .granted {
                Label(copy.onboardingGrantedTitle, systemImage: "checkmark.circle.fill")
                    .scaledFont(.callout, weight: .semibold)
                    .foregroundStyle(theme.success)
            } else {
                Image(systemName: "circle.dashed")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(theme.tertiaryInk)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if !step.isLast {
                Button(copy.onboardingSkipTitle) {
                    actions.requestClose(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondaryInk)
            }

            Spacer()

            stepDots

            Spacer()

            if let previous = step.previous {
                Button(copy.onboardingBackTitle) {
                    step = previous
                }
                .buttonStyle(FlowtypeNeutralButtonStyle(theme: theme, isLarge: true, onPage: true))
            }

            Button {
                if let next = step.next {
                    step = next
                } else {
                    actions.requestClose(completedReadinessSnapshot)
                }
            } label: {
                Text(step.isLast ? copy.onboardingFinishTitle : copy.onboardingContinueTitle)
                    .frame(minWidth: 96)
            }
            .buttonStyle(FlowtypeProminentButtonStyle(theme: theme, isLarge: true))
            .keyboardShortcut(.defaultAction)
            .disabled(step == .prepare && !prepareState.allowsContinue)
        }
    }

    private var stepDots: some View {
        HStack(spacing: 7) {
            ForEach(OnboardingStep.allCases) { candidate in
                Circle()
                    .fill(candidate == step ? theme.accentFill : AnyShapeStyle(theme.controlSurface))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Behavior

    private func refreshPermissions() {
        permissions = actions.permissionSnapshot()
    }

    /// Only the practice page captures dictation; every other page leaves
    /// Fn working as normal, pasting into the previous app.
    private func updatePracticeListener(for step: OnboardingStep) {
        guard step == .practice else {
            actions.setPracticeListener(nil)
            return
        }
        practiceState = .waiting
        actions.setPracticeListener { event in
            if event == .listening { practiceHoldStart = Date() }
            practiceState = practiceState.applying(event)
        }
    }

    private func startPreparation() {
        runPreparation(intent: .interactiveSetup)
    }

    /// Resumes a preparation that paused for a macOS permission, regardless
    /// of which step is showing — the pause only exists after the user
    /// explicitly started preparation.
    private func resumePreparationIfWaiting() {
        guard prepareState == .waitingForPermissions else { return }
        runPreparation(intent: .resumeAfterUserAction)
    }

    private func runPreparation(intent: PreparationIntent) {
        guard !prepareState.isRunning else { return }
        prepareState = .running(.inspecting, nil)
        completedReadinessSnapshot = nil
        downloadEstimator.reset()
        downloadFeedback = nil
        downloadRoute = nil

        Task { @MainActor in
            let result = await actions.prepareFlowtype(intent, model.modelID) { snapshot in
                prepareState = .running(snapshot.stage, snapshot.progress)
                if snapshot.stage == .downloadingModel, let transfer = snapshot.transfer {
                    downloadFeedback = downloadEstimator.update(transfer)
                    downloadRoute = OnboardingDownloadRoute(source: transfer.source) ?? downloadRoute
                } else {
                    downloadEstimator.reset()
                    downloadFeedback = nil
                }
                refreshPermissions()
            }
            prepareState = OnboardingPrepareState.state(for: result.outcome, language: settingsStore.uiLanguage)
            completedReadinessSnapshot = result.verifiedSnapshot
            downloadEstimator.reset()
            downloadFeedback = nil
            refreshPermissions()
        }
    }

    private func openSettingsForMissingPermission() {
        let snapshot = actions.permissionSnapshot()
        if snapshot.accessibility != .granted {
            actions.openAccessibilitySettings()
        } else {
            actions.openMicrophoneSettings()
        }
    }

    private func stageTitle(_ stage: PreparationStage) -> String {
        let usesChinese = copy.usesChinese
        switch stage {
        case .inspecting: return usesChinese ? "正在检查 Flowtype…" : "Checking Flowtype…"
        case .preparingRuntime: return usesChinese ? "正在准备本地运行环境…" : "Preparing local runtime…"
        case .startingHelper: return usesChinese ? "正在启动本地 Helper…" : "Starting local Helper…"
        case .downloadingModel: return usesChinese ? "正在下载 Qwen 模型…" : "Downloading Qwen model…"
        case .loadingModel: return usesChinese ? "正在加载 Qwen 模型…" : "Loading Qwen model…"
        case .verifying: return usesChinese ? "正在进行最终检查…" : "Running final checks…"
        case .awaitingUserAction: return usesChinese ? "等待你完成 macOS 操作…" : "Waiting for macOS action…"
        case .ready: return copy.readinessSetupCompleteTitle
        case .failed: return copy.readinessFailedTitle
        }
    }

    private func stageDetail(_ stage: PreparationStage) -> String? {
        let usesChinese = copy.usesChinese
        switch stage {
        case .preparingRuntime, .startingHelper:
            return usesChinese
                ? "正在准备首次使用所需的本地组件。"
                : "Preparing the local components required for first use."
        case .downloadingModel:
            if model == .qwen3ASR06B {
                return usesChinese
                    ? "正在下载约 1.9 GB 的默认模型，仅首次需要。下载完成后即可使用。"
                    : "Downloading the default model (about 1.9 GB). This is only required once."
            }
            return usesChinese
                ? "正在下载当前所选的 \(model.displayName) 模型，仅首次需要。下载完成后即可使用。"
                : "Downloading the selected \(model.displayName) model. This is only required once."
        case .loadingModel:
            return usesChinese
                ? "下载已完成，正在加载并验证本地模型。"
                : "Download complete. Loading and verifying the local model."
        case .verifying:
            return usesChinese
                ? "最后确认 Helper、模型和权限均已准备好。"
                : "Confirming that the Helper, model, and permissions are ready."
        case .inspecting, .awaitingUserAction, .ready, .failed:
            return nil
        }
    }

    private func progressPercentage(_ progress: Double) -> String {
        "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
    }

    private func downloadFeedbackView(_ feedback: DownloadTransferFeedback) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(downloadedBytesText(feedback))
                .scaledFont(.caption, monospacedDigit: true)
                .foregroundStyle(theme.secondaryInk)
            Text(downloadActivityText(feedback.activity))
                .scaledFont(.caption, monospacedDigit: true)
                .foregroundStyle(theme.secondaryInk)
        }
    }

    private var downloadRouteView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let downloadRoute {
                Label(guide.downloadRouteText(downloadRoute), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .scaledFont(.caption, weight: .medium)
                    .foregroundStyle(theme.secondaryInk)
            }
            Label(guide.prepareVPNHint, systemImage: "network")
                .scaledFont(.caption)
                .foregroundStyle(theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    private func downloadedBytesText(_ feedback: DownloadTransferFeedback) -> String {
        let downloaded = ByteCountFormatter.string(
            fromByteCount: feedback.downloadedBytes,
            countStyle: .file
        )
        let total = ByteCountFormatter.string(
            fromByteCount: feedback.totalBytes,
            countStyle: .file
        )
        return copy.usesChinese
            ? "已下载 \(downloaded) / \(total)"
            : "Downloaded \(downloaded) / \(total)"
    }

    private func downloadActivityText(_ activity: DownloadTransferActivity) -> String {
        let usesChinese = copy.usesChinese
        switch activity {
        case .estimating:
            return usesChinese
                ? "正在估算下载速度与剩余时间…"
                : "Estimating download speed and time remaining…"
        case let .transferring(bytesPerSecond, remainingSeconds):
            let speed = formattedSpeed(bytesPerSecond)
            let remaining = formattedRemainingTime(remainingSeconds, usesChinese: usesChinese)
            return usesChinese
                ? "\(speed) · 预计还需 \(remaining)"
                : "\(speed) · About \(remaining) remaining"
        case .finishing:
            return usesChinese ? "下载完成，正在校验…" : "Download complete. Verifying…"
        case .waitingForNetwork:
            return usesChinese ? "等待网络响应…" : "Waiting for network response…"
        }
    }

    private func formattedSpeed(_ bytesPerSecond: Double) -> String {
        let units: [(threshold: Double, divisor: Double, suffix: String)] = [
            (1_000_000_000, 1_000_000_000, "GB/s"),
            (1_000_000, 1_000_000, "MB/s"),
            (1_000, 1_000, "KB/s"),
        ]
        for unit in units where bytesPerSecond >= unit.threshold {
            return String(format: "%.1f %@", bytesPerSecond / unit.divisor, unit.suffix)
        }
        return String(format: "%.0f B/s", max(bytesPerSecond, 0))
    }

    private func formattedRemainingTime(_ seconds: Int, usesChinese: Bool) -> String {
        let clampedSeconds = max(seconds, 0)
        let minutes = clampedSeconds / 60
        let remainder = clampedSeconds % 60
        if usesChinese {
            return minutes > 0 ? "\(minutes) 分 \(remainder) 秒" : "\(remainder) 秒"
        }
        return minutes > 0 ? "\(minutes) min \(remainder) sec" : "\(remainder) sec"
    }

    private var onboardingPrepareBody: String {
        guard model != .qwen3ASR06B else { return copy.onboardingPrepareBody }
        if copy.usesChinese {
            return "一键完成全部准备：开启麦克风与辅助功能权限，并下载当前所选的 \(model.displayName) 本地模型（仅首次需要，也可以稍后在“准备状态”页完成）。"
        }
        return "One click does everything: grants Microphone and Accessibility permissions and downloads the selected \(model.displayName) local model (first run only — you can also do this later from Setup & Status)."
    }
}
