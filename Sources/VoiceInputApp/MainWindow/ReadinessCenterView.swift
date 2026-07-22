import AppKit
import SwiftUI

struct ReadinessCenterView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var readinessStore: MainWindowReadinessStore
    let actions: MainWindowActions

    @State private var activeAction: ReadinessActionKind?
    @State private var actionError: String?
    @StateObject private var diagnosticsGeneration = ReadinessDiagnosticsActionRunner()
    @State private var generatedDiagnosticsToken: UUID?
    @State private var copiedDiagnosticsToken: UUID?
    @State private var generateDiagnosticsTask: Task<Void, Never>?
    @State private var copyDiagnosticsTask: Task<Void, Never>?
    @State private var generatedDiagnosticsFeedbackTask: Task<Void, Never>?
    @State private var copiedDiagnosticsFeedbackTask: Task<Void, Never>?
    @State private var preparationSnapshot: PreparationSnapshot?
    @State private var isAwaitingExternalPermission = false
    @State private var isShowingCompletedDetails = false
    @State private var isShowingAdvancedDiagnostics = false

    private var report: ReadinessReport {
        readinessStore.snapshot.report
    }

    private var presentation: ReadinessPresentation {
        readinessStore.presentation
    }

    private var availability: ReadinessActionAvailability {
        ReadinessActionAvailability(
            isRefreshing: readinessStore.isRefreshing,
            activeAction: activeAction,
            report: report,
            hasActionableSetupOverride: !presentation.tasks.isEmpty
        )
    }

    var body: some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)

        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(copy: copy)

                    Group {
                        if generatedDiagnosticsToken != nil,
                           let generatedDiagnosticsResult = diagnosticsGeneration.generatedResult {
                            Label(
                                copy.readinessGeneratedDiagnosticsTitle(generatedDiagnosticsResult.timestampedFileName),
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.callout.weight(.medium))
                            .foregroundStyle(theme.success)
                            .transition(.opacity)
                        }

                        if copiedDiagnosticsToken != nil {
                            Label(copy.readinessCopiedDiagnosticsTitle, systemImage: "checkmark.circle.fill")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(theme.success)
                                .transition(.opacity)
                        }
                    }
                    .animation(
                        InlineFeedbackMotion.animation(reduceMotion: reduceMotion),
                        value: generatedDiagnosticsToken
                    )
                    .animation(
                        InlineFeedbackMotion.animation(reduceMotion: reduceMotion),
                        value: copiedDiagnosticsToken
                    )

                    SetupSummaryView(
                        presentation: presentation,
                        context: readinessStore.snapshot.context,
                        isRefreshing: readinessStore.isRefreshing,
                        refreshFailed: readinessStore.didLastRefreshFail,
                        copy: copy,
                        availability: availability,
                        actionHandler: handleAction
                    )

                    if let preparationSnapshot, activeAction == .prepareFlowtype {
                        preparationProgressCard(preparationSnapshot, copy: copy)
                    }

                    if !presentation.tasks.isEmpty {
                        needsActionView(copy: copy)
                    }

                    if presentation.phase == .checking ||
                        presentation.phase == .preparing ||
                        presentation.phase == .ready {
                        everydayRequirementsView(copy: copy)
                    }

                    if !presentation.checkDetails.isEmpty {
                        DisclosureGroup(isExpanded: $isShowingCompletedDetails) {
                            readinessGroups(
                                checks: presentation.checkDetails,
                                copy: copy
                            )
                            .padding(.top, 14)
                        } label: {
                            Label(
                                copy.readinessCheckDetailsTitle(
                                    count: presentation.checkDetails.count
                                ),
                                systemImage: "checkmark.circle"
                            )
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                        }
                        .padding(14)
                        .themedCard(theme, cornerRadius: 10)
                    }

                    DisclosureGroup(isExpanded: $isShowingAdvancedDiagnostics) {
                        readinessGroups(checks: presentation.technicalChecks, copy: copy)
                        .padding(.top, 14)
                    } label: {
                        Label(copy.readinessAdvancedDiagnosticsTitle, systemImage: "stethoscope")
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                    }
                    .padding(14)
                    .themedCard(theme, cornerRadius: 10)

                    if let actionError {
                        Label {
                            Text(actionError)
                                .lineLimit(3)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.callout)
                        .foregroundStyle(theme.danger)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .themedInset(theme, cornerRadius: 8)
                    }
                }
                .padding(.horizontal, MainWindowDetailLayout.horizontalPadding(forWidth: geometry.size.width))
                .padding(.top, MainWindowDetailLayout.topPadding)
                .padding(.bottom, MainWindowDetailLayout.bottomPadding)
                .frame(maxWidth: MainWindowDetailLayout.readinessContentMaxWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.surface)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if isAwaitingExternalPermission, activeAction == nil {
                activeAction = .prepareFlowtype
                Task {
                    await runPreparation(intent: .resumeAfterUserAction)
                    activeAction = nil
                }
            }
        }
        .onDisappear {
            cancelViewTasks()
        }
    }

    private func header(copy: AppCopy.Texts) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.readinessTitle)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(copy.readinessSubtitle)
                    .font(.callout)
                    .foregroundStyle(theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Menu {
                Button {
                    startGenerateDiagnosticsFile()
                } label: {
                    Label(copy.readinessGenerateDiagnosticsTitle, systemImage: "doc.badge.plus")
                }
                .disabled(diagnosticsGeneration.isGeneratingFile)

                Button {
                    actions.openReadinessLocation(.diagnostics)
                } label: {
                    Label(copy.readinessOpenDiagnosticsFolderTitle, systemImage: "folder")
                }
            } label: {
                Label(copy.readinessDiagnosticsTitle, systemImage: "stethoscope")
            }
            .controlSize(.regular)

            Button {
                Task {
                    await refresh(live: true)
                }
            } label: {
                Label(copy.readinessRefreshTitle, systemImage: "arrow.clockwise")
            }
            .disabled(availability.isRefreshDisabled)
            .controlSize(.regular)
        }
    }

    @MainActor
    private func refresh(live: Bool) async {
        guard !readinessStore.isRefreshing else { return }
        actionError = nil
        if live {
            await readinessStore.refreshLive()
        } else {
            await readinessStore.refreshLightweight()
        }
        saveDiagnosticsSnapshot(report)
        if live,
           activeAction == nil,
           presentation.phase == .preparing {
            readinessStore.scheduleFollowUpRefreshes()
        }
    }

    @MainActor
    private func handleAction(_ action: ReadinessActionKind) {
        guard !availability.isActionDisabled(action) else { return }
        diagnosticsGeneration.resetFeedback()
        generatedDiagnosticsToken = nil
        copiedDiagnosticsToken = nil
        generatedDiagnosticsFeedbackTask?.cancel()
        copiedDiagnosticsFeedbackTask?.cancel()
        actionError = nil

        if action == .copyDiagnostics {
            startCopyDiagnostics()
            return
        }

        activeAction = action

        Task {
            await runAction(action)
        }
    }

    @MainActor
    private func runAction(_ action: ReadinessActionKind) async {
        defer { activeAction = nil }

        do {
            switch action {
            case .prepareFlowtype:
                await runPreparation(intent: .interactiveSetup)
            case .prepareRuntime:
                updateReport(try await actions.prepareRuntime(), coverage: .lightweight)
            case .repairHelper, .repairLocalRuntime:
                updateReport(try await actions.repairHelper(), coverage: .lightweight)
            case .warmModel:
                _ = try await actions.warmSelectedModel()
                updateReport(await actions.refreshReadinessLive(), coverage: .live)
            case .retryPreload:
                _ = try await actions.retrySelectedModelPreload()
                updateReport(await actions.refreshReadinessLive(), coverage: .live)
            case .requestMicrophone:
                actions.requestMicrophone()
                updateReport(await actions.refreshReadiness(), coverage: .lightweight)
                readinessStore.scheduleFollowUpRefreshes()
            case .openAccessibilitySettings:
                actions.openAccessibilitySettings()
                updateReport(await actions.refreshReadiness(), coverage: .lightweight)
                readinessStore.scheduleFollowUpRefreshes()
            case .requestSpeechRecognition:
                actions.requestSpeechRecognition()
                updateReport(await actions.refreshReadiness(), coverage: .lightweight)
                readinessStore.scheduleFollowUpRefreshes()
            case .copyDiagnostics:
                break
            case .reinstallFlowtypeApp:
                actions.openReadinessLocation(.appBundle)
                updateReport(await actions.refreshReadiness(), coverage: .lightweight)
            case .downloadDefaultModel:
                _ = try await actions.downloadDefaultModel()
                updateReport(await actions.refreshReadinessLive(), coverage: .live)
            case .reinstallApp, .restartHelper, .downloadModel, .repairModelCache, .useModel:
                updateReport(await actions.refreshReadiness(), coverage: .lightweight)
            }
            saveDiagnosticsSnapshot(report)
        } catch {
            actionError = error.localizedDescription
        }
    }

    @MainActor
    private func runPreparation(intent: PreparationIntent) async {
        do {
            let result = try await actions.prepareFlowtype(intent) { snapshot in
                preparationSnapshot = snapshot
            }
            updateReport(
                result.report,
                coverage: result.outcome == .prepared ? .live : .lightweight
            )
            isAwaitingExternalPermission = result.outcome == .waitingForPermissions
            if case let .failed(message) = result.outcome {
                actionError = message
            }
            saveDiagnosticsSnapshot(report)
        } catch {
            actionError = error.localizedDescription
        }
    }

    @MainActor
    private func updateReport(_ nextReport: ReadinessReport, coverage: ReadinessCoverage) {
        readinessStore.accept(nextReport, coverage: coverage)
    }

    private func needsActionView(copy: AppCopy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.readinessNeedsActionTitle)
                .font(.headline)
                .foregroundStyle(theme.ink)

            VStack(spacing: 0) {
                ForEach(Array(presentation.tasks.enumerated()), id: \.element.id) { index, task in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: copy.readinessTaskSymbol(task.kind))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(task.kind == .reinstallApplication ? theme.danger : .orange)
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(copy.readinessTaskTitle(task.kind, context: readinessStore.snapshot.context))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.ink)
                            Text(copy.readinessTaskDetail(task.kind, context: readinessStore.snapshot.context))
                                .font(.caption)
                                .foregroundStyle(theme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < presentation.tasks.count - 1 {
                        Divider()
                    }
                }
            }
            .themedCard(theme, cornerRadius: 8)
        }
    }

    private func everydayRequirementsView(copy: AppCopy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.readinessEverydayRequirementsTitle)
                .font(.headline)
                .foregroundStyle(theme.ink)

            VStack(spacing: 0) {
                compactRequirementRow(
                    title: copy.readinessPermissionsReadyDetail(for: readinessStore.snapshot.context),
                    symbol: "hand.raised.fill",
                    isComplete: true
                )
                Divider()
                compactRequirementRow(
                    title: engineRequirementTitle(copy: copy),
                    symbol: readinessStore.snapshot.context.engine == .qwenLocal ? "cube.fill" : "waveform",
                    isComplete: presentation.phase == .ready
                )
            }
            .themedCard(theme, cornerRadius: 8)
        }
    }

    private func compactRequirementRow(
        title: String,
        symbol: String,
        isComplete: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Group {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.success)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 20, height: 20)
            Image(systemName: symbol)
                .foregroundStyle(theme.secondaryInk)
                .frame(width: 20)
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(theme.ink)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private func engineRequirementTitle(copy: AppCopy.Texts) -> String {
        switch presentation.phase {
        case .checking:
            return copy.readinessEngineCheckingDetail(for: readinessStore.snapshot.context)
        case .preparing:
            return copy.readinessEnginePreparingDetail(for: readinessStore.snapshot.context)
        case .ready:
            return copy.readinessEngineReadyDetail(for: readinessStore.snapshot.context)
        case .needsSetup, .repairRequired:
            return copy.readinessEngineCheckingDetail(for: readinessStore.snapshot.context)
        }
    }

    @ViewBuilder
    private func readinessGroups(checks: [ReadinessCheck], copy: AppCopy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(ReadinessGroup.allCases) { group in
                let groupChecks = checks.filter { $0.group == group }
                if !groupChecks.isEmpty {
                    ReadinessGroupView(
                        group: group,
                        checks: groupChecks,
                        copy: copy,
                        availability: availability,
                        actionHandler: handleAction,
                        locationHandler: { target in
                            actions.openReadinessLocation(target)
                        }
                    )
                }
            }
        }
    }

    private func preparationProgressCard(
        _ snapshot: PreparationSnapshot,
        copy: AppCopy.Texts
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(preparationStageTitle(snapshot.stage, copy: copy))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(theme.ink)
            }
            if let progress = snapshot.progress {
                ProgressView(value: min(max(progress, 0), 1))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedInset(theme, cornerRadius: 8)
    }

    private func preparationStageTitle(
        _ stage: PreparationStage,
        copy: AppCopy.Texts
    ) -> String {
        switch stage {
        case .inspecting: return settingsStore.uiLanguage == .chinese ? "正在检查 Flowtype…" : "Checking Flowtype…"
        case .preparingRuntime: return settingsStore.uiLanguage == .chinese ? "正在准备本地运行环境…" : "Preparing local runtime…"
        case .startingHelper: return settingsStore.uiLanguage == .chinese ? "正在启动本地 Helper…" : "Starting local Helper…"
        case .downloadingModel: return settingsStore.uiLanguage == .chinese ? "正在下载 Qwen 模型…" : "Downloading Qwen model…"
        case .loadingModel: return settingsStore.uiLanguage == .chinese ? "正在加载 Qwen 模型…" : "Loading Qwen model…"
        case .verifying: return settingsStore.uiLanguage == .chinese ? "正在进行最终检查…" : "Running final checks…"
        case .awaitingUserAction: return settingsStore.uiLanguage == .chinese ? "等待你完成 macOS 操作…" : "Waiting for macOS action…"
        case .ready: return copy.readinessSetupCompleteTitle
        case .failed: return copy.readinessFailedTitle
        }
    }

    @MainActor
    private func runCopyDiagnostics() async {
        defer { copyDiagnosticsTask = nil }

        do {
            _ = try await actions.copyDiagnostics(report)
            guard !Task.isCancelled else { return }
            showCopiedDiagnosticsFeedback()
        } catch {
            guard !Task.isCancelled else { return }
            actionError = error.localizedDescription
        }
    }

    @MainActor
    private func runGenerateDiagnosticsFile() async {
        diagnosticsGeneration.resetFeedback()
        generatedDiagnosticsToken = nil
        copiedDiagnosticsToken = nil
        generatedDiagnosticsFeedbackTask?.cancel()
        copiedDiagnosticsFeedbackTask?.cancel()
        actionError = nil

        let outcome = await diagnosticsGeneration.generateFile(
            report: report,
            action: actions.generateDiagnosticsFile
        )
        guard !Task.isCancelled else { return }

        switch outcome {
        case let .generated(result):
            showGeneratedDiagnosticsFeedback(result)
            actions.revealDiagnosticsFile(result.timestampedURL)
        case let .failed(message):
            actionError = message
        case .alreadyRunning, .cancelled:
            break
        }
    }

    @MainActor
    private func startGenerateDiagnosticsFile() {
        guard generateDiagnosticsTask == nil else { return }

        generateDiagnosticsTask = Task {
            await runGenerateDiagnosticsFile()
            await MainActor.run {
                generateDiagnosticsTask = nil
            }
        }
    }

    @MainActor
    private func startCopyDiagnostics() {
        guard copyDiagnosticsTask == nil else { return }
        copyDiagnosticsTask = Task {
            await runCopyDiagnostics()
        }
    }

    @MainActor
    private func saveDiagnosticsSnapshot(_ report: ReadinessReport) {
        Task {
            await actions.saveDiagnosticsSnapshot(report)
        }
    }

    @MainActor
    private func showGeneratedDiagnosticsFeedback(_ result: DiagnosticsFileResult) {
        let token = UUID()
        generatedDiagnosticsToken = token

        generatedDiagnosticsFeedbackTask?.cancel()
        generatedDiagnosticsFeedbackTask = Task {
            do {
                try await Task.sleep(nanoseconds: 1_800_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if generatedDiagnosticsToken == token {
                    diagnosticsGeneration.resetFeedback()
                    generatedDiagnosticsToken = nil
                }
                generatedDiagnosticsFeedbackTask = nil
            }
        }
    }

    @MainActor
    private func showCopiedDiagnosticsFeedback() {
        let token = UUID()
        copiedDiagnosticsToken = token

        copiedDiagnosticsFeedbackTask?.cancel()
        copiedDiagnosticsFeedbackTask = Task {
            do {
                try await Task.sleep(nanoseconds: 1_800_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if copiedDiagnosticsToken == token {
                    copiedDiagnosticsToken = nil
                }
                copiedDiagnosticsFeedbackTask = nil
            }
        }
    }

    @MainActor
    private func cancelViewTasks() {
        generateDiagnosticsTask?.cancel()
        copyDiagnosticsTask?.cancel()
        generatedDiagnosticsFeedbackTask?.cancel()
        copiedDiagnosticsFeedbackTask?.cancel()
        generateDiagnosticsTask = nil
        copyDiagnosticsTask = nil
        generatedDiagnosticsFeedbackTask = nil
        copiedDiagnosticsFeedbackTask = nil
    }
}

private struct SetupSummaryView: View {
    @Environment(\.appTheme) private var theme

    let presentation: ReadinessPresentation
    let context: ReadinessContext
    let isRefreshing: Bool
    let refreshFailed: Bool
    let copy: AppCopy.Texts
    let availability: ReadinessActionAvailability
    let actionHandler: (ReadinessActionKind) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Group {
                if presentation.phase == .checking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: symbolName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(symbolColor)
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(copy.readinessPresentationTitle(presentation.phase, count: presentation.requiredTaskCount))
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text(copy.readinessPresentationDetail(presentation, context: context))
                    .font(.callout)
                    .foregroundStyle(theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                if refreshFailed {
                    Text(copy.readinessRefreshFailedDetail)
                        .font(.caption)
                        .foregroundStyle(theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            if isRefreshing && presentation.phase != .checking {
                ProgressView()
                    .controlSize(.small)
                    .help(copy.readinessCheckingTitle)
            }

            if let action = presentation.primaryAction {
                Button {
                    actionHandler(action)
                } label: {
                    Label(
                        copy.readinessPrimaryActionTitle(action),
                        systemImage: action == .reinstallFlowtypeApp ? "arrow.down.circle" : "wand.and.stars"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(availability.isActionDisabled(action))
            }
        }
        .padding(14)
        .themedCard(theme, cornerRadius: 8)
    }

    private var symbolName: String {
        switch presentation.phase {
        case .checking, .preparing: return "clock.fill"
        case .ready: return "checkmark.circle.fill"
        case .needsSetup: return "exclamationmark.triangle.fill"
        case .repairRequired: return "exclamationmark.triangle.fill"
        }
    }

    private var symbolColor: Color {
        switch presentation.phase {
        case .checking, .preparing: return theme.accent
        case .ready: return theme.success
        case .needsSetup: return .orange
        case .repairRequired: return theme.danger
        }
    }
}

struct ReadinessGroupView: View {
    @Environment(\.appTheme) private var theme

    let group: ReadinessGroup
    let checks: [ReadinessCheck]
    let copy: AppCopy.Texts
    let availability: ReadinessActionAvailability
    let actionHandler: (ReadinessActionKind) -> Void
    let locationHandler: (ReadinessLocationTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.ink)

            VStack(spacing: 0) {
                ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                    ReadinessCheckRow(
                        check: check,
                        copy: copy,
                        availability: availability,
                        actionHandler: actionHandler,
                        locationHandler: locationHandler
                    )
                    if index < checks.count - 1 {
                        Divider()
                    }
                }
            }
            .themedCard(theme, cornerRadius: 8)
        }
    }

    private var title: String {
        switch group {
        case .appBundle: return copy.readinessGroupAppBundleTitle
        case .localRuntime: return copy.readinessGroupLocalRuntimeTitle
        case .models: return copy.readinessGroupModelsTitle
        case .permissions: return copy.readinessGroupPermissionsTitle
        case .performance: return copy.readinessGroupPerformanceTitle
        }
    }
}

private struct ReadinessCheckRow: View {
    @Environment(\.appTheme) private var theme

    let check: ReadinessCheck
    let copy: AppCopy.Texts
    let availability: ReadinessActionAvailability
    let actionHandler: (ReadinessActionKind) -> Void
    let locationHandler: (ReadinessLocationTarget) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(symbolColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(copy.readinessCheckTitle(for: check))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(copy.readinessCheckDetail(for: check))
                    .font(.caption)
                    .foregroundStyle(theme.secondaryInk)
                    .lineLimit(2)
                if let message = copy.readinessCheckStatusMessage(for: check) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(theme.danger)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            Text(copy.readinessStatusTitle(for: check))
                .font(.caption.weight(.semibold))
                .foregroundStyle(symbolColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(symbolColor.opacity(0.14), in: Capsule())

            if let action = check.primaryAction {
                Button {
                    actionHandler(action)
                } label: {
                    Label(actionTitle(for: action), systemImage: actionSystemImage(for: action))
                }
                .controlSize(.small)
                .disabled(availability.isActionDisabled(action))
            }

            if let target = check.locationTarget {
                Button {
                    locationHandler(target)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help(copy.readinessOpenLocationTitle)
                .disabled(false)
            }

            if let action = check.secondaryAction {
                Button {
                    actionHandler(action)
                } label: {
                    Image(systemName: actionSystemImage(for: action))
                }
                .buttonStyle(.borderless)
                .help(actionTitle(for: action))
                .disabled(availability.isActionDisabled(action))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var symbolName: String {
        if check.status == .optional && check.group == .performance {
            return "exclamationmark.triangle.fill"
        }
        switch check.status.severity {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .neutral: return "circle"
        case .inProgress: return "clock.fill"
        }
    }

    private var symbolColor: Color {
        if check.status == .optional {
            return check.group == .performance ? .orange : theme.secondaryInk
        }
        switch check.status.severity {
        case .success: return theme.success
        case .warning: return .orange
        case .error: return theme.danger
        case .neutral: return theme.secondaryInk
        case .inProgress: return theme.accent
        }
    }

    private func actionTitle(for action: ReadinessActionKind) -> String {
        switch action {
        case .prepareFlowtype: return copy.readinessPrepareFlowtypeTitle
        case .prepareRuntime: return copy.readinessPrepareRuntimeTitle
        case .repairHelper: return copy.readinessRepairHelperTitle
        case .repairLocalRuntime: return copy.readinessRepairLocalRuntimeTitle
        case .warmModel: return copy.readinessWarmModelTitle
        case .retryPreload: return copy.readinessRetryPreloadTitle
        case .copyDiagnostics: return copy.readinessCopyDiagnosticsTitle
        case .requestMicrophone: return copy.readinessRequestMicrophoneTitle
        case .openAccessibilitySettings: return copy.readinessOpenAccessibilitySettingsTitle
        case .requestSpeechRecognition: return copy.readinessRequestSpeechRecognitionTitle
        case .reinstallApp: return copy.readinessReinstallAppTitle
        case .reinstallFlowtypeApp: return copy.readinessReinstallFlowtypeTitle
        case .restartHelper: return copy.readinessRestartHelperTitle
        case .downloadModel: return copy.modelDownloadTitle
        case .downloadDefaultModel: return copy.readinessDownloadDefaultModelTitle
        case .repairModelCache: return copy.modelRepairTitle
        case .useModel: return copy.modelUseTitle
        }
    }

    private func actionSystemImage(for action: ReadinessActionKind) -> String {
        switch action {
        case .prepareFlowtype: return "wand.and.stars"
        case .prepareRuntime: return "arrow.down.doc"
        case .repairHelper, .repairLocalRuntime, .repairModelCache: return "gearshape.2"
        case .warmModel: return "flame"
        case .retryPreload: return "arrow.clockwise"
        case .copyDiagnostics: return "doc.on.doc"
        case .requestMicrophone: return "mic"
        case .openAccessibilitySettings: return "figure.wave"
        case .requestSpeechRecognition: return "waveform"
        case .reinstallApp, .reinstallFlowtypeApp, .downloadModel, .downloadDefaultModel: return "arrow.down.circle"
        case .restartHelper: return "arrow.clockwise"
        case .useModel: return "checkmark.circle"
        }
    }
}
