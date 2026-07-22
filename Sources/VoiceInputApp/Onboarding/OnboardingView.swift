import AppKit
import SwiftUI

struct OnboardingView: View {
    @Environment(\.appTheme) private var theme

    let copy: AppCopy.Texts
    let actions: OnboardingActions

    @State private var step: OnboardingStep = .welcome
    @State private var permissions: PermissionSnapshot?
    @State private var prepareState: OnboardingPrepareState = .idle

    var body: some View {
        VStack(spacing: 0) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 40)
                .padding(.top, 36)

            footer
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
        }
        .frame(width: 620, height: 560)
        .background(theme.surface)
        .onAppear(perform: refreshPermissions)
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
        case .howTo:
            howToStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)

            if let mark = FlowtypeLogoAsset.templateMark {
                Image(nsImage: mark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 56)
                    .foregroundStyle(theme.ink)
            }

            Text(copy.onboardingWelcomeTitle)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(theme.ink)
                .padding(.top, 26)

            Text("Flowtype")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(theme.secondaryInk)
                .padding(.top, 4)

            Text(copy.onboardingWelcomeBody)
                .font(.system(size: 15))
                .foregroundStyle(theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

            Label(copy.onboardingPrivacyNote, systemImage: "lock.shield")
                .font(.callout)
                .foregroundStyle(theme.secondaryInk)
                .padding(.top, 14)

            Spacer(minLength: 12)
        }
    }

    private var prepareStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(
                title: copy.onboardingPrepareTitle,
                body: copy.onboardingPrepareBody
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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case let .running(stage, progress):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(stageTitle(stage))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(theme.ink)
                }
                if let progress {
                    ProgressView(value: min(max(progress, 0), 1))
                }
            }

        case .ready:
            Label(copy.onboardingPrepareReadyTitle, systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(theme.success)

        case .waitingForPermissions:
            VStack(alignment: .leading, spacing: 12) {
                Label(copy.onboardingPreparePermissionsHint, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button(copy.onboardingOpenSettingsTitle) {
                    openSettingsForMissingPermission()
                }
                .buttonStyle(.bordered)
            }

        case let .failed(message):
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(message)
                        .lineLimit(3)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.callout)
                .foregroundStyle(theme.danger)
                Button {
                    startPreparation()
                } label: {
                    Label(copy.readinessRefreshTitle, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var howToStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(title: copy.onboardingHowToTitle, body: nil)

            howToRow(
                symbol: "keyboard",
                keycap: "fn",
                title: copy.onboardingHowToHoldTitle,
                detail: copy.onboardingHowToHoldDetail
            )
            howToRow(
                symbol: "text.cursor",
                keycap: nil,
                title: copy.onboardingHowToReleaseTitle,
                detail: copy.onboardingHowToReleaseDetail
            )
            howToRow(
                symbol: "text.book.closed",
                keycap: nil,
                title: copy.onboardingHowToDictionaryTitle,
                detail: copy.onboardingHowToDictionaryDetail
            )
        }
    }

    // MARK: - Shared pieces

    private func stepHeader(title: String, body: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(theme.ink)
            if let body {
                Text(body)
                    .font(.callout)
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 30, height: 30)
                .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text(state == .denied ? copy.onboardingDeniedTitle : detail)
                    .font(.callout)
                    .foregroundStyle(state == .denied ? theme.danger : theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if state == .granted {
                Label(copy.onboardingGrantedTitle, systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.success)
            } else {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.tertiaryInk)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func howToRow(
        symbol: String,
        keycap: String?,
        title: String,
        detail: String
    ) -> some View {
        HStack(spacing: 14) {
            if let keycap {
                Text(keycap)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.ink)
                    .frame(width: 34, height: 34)
                    .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    }
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 34, height: 34)
                    .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(theme, cornerRadius: 12)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if !step.isLast {
                Button(copy.onboardingSkipTitle) {
                    actions.requestClose()
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
                .buttonStyle(.bordered)
            }

            Button {
                if let next = step.next {
                    step = next
                } else {
                    actions.requestClose()
                }
            } label: {
                Text(step.isLast ? copy.onboardingFinishTitle : copy.onboardingContinueTitle)
                    .frame(minWidth: 96)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var stepDots: some View {
        HStack(spacing: 7) {
            ForEach(OnboardingStep.allCases) { candidate in
                Circle()
                    .fill(candidate == step ? theme.accent : theme.controlSurface)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Behavior

    private func refreshPermissions() {
        permissions = actions.permissionSnapshot()
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

        Task { @MainActor in
            let result = await actions.prepareFlowtype(intent) { snapshot in
                prepareState = .running(snapshot.stage, snapshot.progress)
                refreshPermissions()
            }
            prepareState = OnboardingPrepareState.state(for: result.outcome)
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
        let usesChinese = copy.timesUnit == "次"
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
}
