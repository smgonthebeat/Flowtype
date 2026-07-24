import AppKit
import SwiftUI

struct ModelsView: View {
    @Environment(\.appTheme) private var theme

    @ObservedObject var state: MainWindowState
    @ObservedObject var settingsStore: SettingsStore
    let modelManager: ModelManager
    let actions: MainWindowActions

    @State private var downloadStates: [String: ModelDownloadState] = [:]
    @State private var liveStatuses: [String: QwenModelStatus] = [:]
    @State private var refreshingModelIDs: Set<String> = []
    @State private var statusRequestsInFlight: Set<String> = []
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var suitabilityAlert: ModelSuitabilityAlert?
    @State private var hardwareSummary: HardwareSummary?
    @State private var storageSizes: [String: Int64] = [:]
    @State private var storageSizeGeneration = 0
    @State private var modelPendingDeletion: VoiceInputModel?

    private var models: [VoiceInputModel] {
        VoiceInputModel.all
    }

    var body: some View {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)

        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(copy: copy)
                    dictionaryGuidance(copy: copy)
                    ForEach(models) { model in
                        modelCard(model: model, copy: copy)
                    }
                }
                .padding(.horizontal, MainWindowDetailLayout.horizontalPadding(forWidth: geometry.size.width))
                .padding(.top, MainWindowDetailLayout.topPadding)
                .padding(.bottom, MainWindowDetailLayout.bottomPadding)
                .frame(maxWidth: MainWindowDetailLayout.modelsContentMaxWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.surface)
        }
        .onAppear {
            loadHardwareSummaryIfNeeded()
            reloadLocalState()
            reloadStorageSizes()
        }
        .task { await monitorModelStatuses() }
        .onChange(of: state.refreshID) {
            reloadLocalState()
            reloadStorageSizes()
            Task { await refreshAllStatuses(indicateActivity: false) }
        }
        .confirmationDialog(
            copy.modelDeleteConfirmTitle,
            isPresented: isDeleteConfirmationPresented,
            titleVisibility: .visible,
            presenting: modelPendingDeletion
        ) { model in
            Button(copy.modelDeleteTitle, role: .destructive) {
                deleteModelStorage(model)
            }
            Button(copy.cancel, role: .cancel) {}
        } message: { model in
            Text(copy.modelDeleteConfirmMessage(
                for: model,
                formattedSize: storageSizes[model.id].map(formattedSize)
            ))
        }
        .alert(copy.modelErrorTitle, isPresented: $isShowingError) {
            Button(copy.ok, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(copy.modelSuitabilityWarningTitle, isPresented: isSuitabilityAlertPresented) {
            Button(copy.modelSuitabilityUseSmallModelTitle, role: .cancel) {
                settingsStore.selectedModelID = VoiceInputModel.qwen3ASR06B.id
                state.refresh()
            }
            Button(copy.modelSuitabilityContinueTitle) {
                if let suitabilityAlert {
                    continueAfterSuitabilityWarning(suitabilityAlert)
                }
            }
        } message: {
            if let recommendation = suitabilityAlert?.recommendation {
                Text(copy.modelSuitabilityDetail(for: recommendation))
            }
        }
    }

    private func dictionaryGuidance(copy: AppCopy.Texts) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "text.book.closed")
                .foregroundStyle(theme.secondaryInk)
            Text(copy.modelHotwordsNote)
                .foregroundStyle(theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                state.show(.dictionary)
            } label: {
                Label(copy.modelOpenDictionaryTitle, systemImage: "arrow.right")
            }
            .buttonStyle(.borderless)
        }
        .font(.callout)
        .padding(14)
        .themedInset(theme, cornerRadius: 10)
    }

    private func header(copy: AppCopy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.modelsTitle)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text(copy.modelsSubtitle)
                .font(.callout)
                .foregroundStyle(theme.secondaryInk)
        }
    }

    private func modelCard(model: VoiceInputModel, copy: AppCopy.Texts) -> some View {
        let manager = manager(for: model)
        let state = downloadStates[model.id] ?? localState(for: manager, copy: copy)
        let isSelected = settingsStore.selectedModelID == model.id && isReady(state)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                QwenLogoIcon()
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(copy.modelRoleTitle(for: model))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.ink)
                        statusBadge(model: model, state: state, copy: copy)
                    }

                    Text(copy.modelRoleDescription(for: model))
                        .font(.callout)
                        .foregroundStyle(theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(copy.modelProvenance(for: model))
                        .font(.caption)
                        .foregroundStyle(theme.tertiaryInk)
                        .help(model.modelID)

                    if let advisory = inlineSuitabilityAdvisory(for: model) {
                        Label(copy.modelSuitabilityDetail(for: advisory), systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Button {
                    Task { await refreshStatus(for: model) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing(model))
                .help(copy.modelRefreshTitle)
            }

            progressArea(for: state, status: liveStatuses[model.id], copy: copy)
            modelFooter(
                model: model,
                manager: manager,
                state: state,
                isSelected: isSelected,
                copy: copy
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? theme.accent.opacity(0.05) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .themedCard(theme)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.accent.opacity(0.7), lineWidth: 1.5)
            }
        }
        .contextMenu {
            Button {
                openModelFolder(manager: manager)
            } label: {
                Label(copy.modelOpenFolderTitle, systemImage: "folder")
            }
            Button {
                copyModelPath(manager: manager)
            } label: {
                Label(copy.modelCopyPathTitle, systemImage: "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private func progressArea(
        for state: ModelDownloadState,
        status: QwenModelStatus?,
        copy: AppCopy.Texts
    ) -> some View {
        switch state {
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 8) {
                if let progress {
                    ProgressView(value: progress)
                } else {
                    ProgressView()
                }
                Text(progressText(progress, copy: copy))
                    .font(.caption)
                    .foregroundStyle(theme.secondaryInk)
                if let status,
                   let downloadedBytes = status.downloadedBytes,
                   let totalBytes = status.totalBytes,
                   totalBytes > 0 {
                    Text(copy.modelDownloadUsage(
                        formattedSize(downloadedBytes),
                        total: formattedSize(totalBytes),
                        source: downloadSourceTitle(status.downloadSource)
                    ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.secondaryInk)
                }
            }
        case .repairNeeded:
            Text(copy.modelRepairMessage)
                .font(.callout)
                .foregroundStyle(.orange)
        case .failed(let message):
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
        case .notInstalled, .ready:
            EmptyView()
        }
    }

    @ViewBuilder
    private func modelFooter(
        model: VoiceInputModel,
        manager: ModelManager,
        state: ModelDownloadState,
        isSelected: Bool,
        copy: AppCopy.Texts
    ) -> some View {
        let isDownloaded = isReady(state)
        let needsRepair: Bool = {
            if case .repairNeeded = state { return true }
            return false
        }()

        HStack(spacing: 14) {
            if isDownloaded && !isSelected {
                Button {
                    useModel(model, bypassSuitabilityWarning: false)
                } label: {
                    Label(copy.modelUseTitle, systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .help(copy.modelUseHelp)
            } else if !isDownloaded {
                Button {
                    Task { await downloadModel(model: model, bypassSuitabilityWarning: false) }
                } label: {
                    Label(
                        needsRepair ? copy.modelRepairTitle : copy.modelDownloadTitle,
                        systemImage: needsRepair ? "gearshape.2" : "arrow.down.circle"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy(model, state: state))
                .help(needsRepair ? copy.modelRepairHelp : copy.modelDownloadHelp)
            }

            if !isDownloading(state), let bytes = storageSizes[model.id] {
                Text(copy.modelStorageUsage(formattedSize(bytes)))
                    .font(.caption)
                    .foregroundStyle(theme.secondaryInk)
            }

            Spacer()

            Button {
                openModelFolder(manager: manager)
            } label: {
                Label(copy.modelOpenFolderTitle, systemImage: "folder")
            }
            .buttonStyle(.borderless)
            .help(manager.modelDirectory.path)

            if (isDownloaded || needsRepair) && !isSelected {
                Button(role: .destructive) {
                    modelPendingDeletion = model
                } label: {
                    Label(copy.modelDeleteTitle, systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.danger)
                .disabled(isBusy(model, state: state))
                .help(copy.modelDeleteConfirmTitle)
            }
        }
    }

    private func loadHardwareSummaryIfNeeded() {
        if hardwareSummary == nil {
            hardwareSummary = HardwareSummary.current()
        }
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { modelPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    modelPendingDeletion = nil
                }
            }
        )
    }

    private func deleteModelStorage(_ model: VoiceInputModel) {
        // Re-check at confirm time: selection or download state may have
        // changed while the confirmation dialog was open.
        guard settingsStore.selectedModelID != model.id else { return }
        if case .downloading = downloadStates[model.id] { return }
        guard !isRefreshing(model) else { return }

        do {
            try manager(for: model).resetModelStorage()
            downloadStates[model.id] = .notInstalled
            storageSizes[model.id] = nil
            reloadStorageSizes()
            state.refresh()
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }

    private func reloadStorageSizes() {
        storageSizeGeneration += 1
        let generation = storageSizeGeneration
        let managers = models.map { (id: $0.id, manager: manager(for: $0)) }
        Task.detached(priority: .utility) {
            var sizes: [String: Int64] = [:]
            for entry in managers {
                if let size = entry.manager.storageSizeBytes() {
                    sizes[entry.id] = size
                }
            }
            let result = sizes
            await MainActor.run {
                // Drop stale results (e.g. a scan that started before a delete).
                guard generation == storageSizeGeneration else { return }
                storageSizes = result
            }
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var isSuitabilityAlertPresented: Binding<Bool> {
        Binding(
            get: { suitabilityAlert != nil },
            set: { isPresented in
                if !isPresented {
                    suitabilityAlert = nil
                }
            }
        )
    }

    private func shouldWarnBeforeActing(on model: VoiceInputModel) -> ModelSuitabilityRecommendation? {
        let hardware = hardwareSummary ?? HardwareSummary.current()
        if hardwareSummary == nil {
            hardwareSummary = hardware
        }
        let policy = ModelSuitabilityPolicy()
        guard policy.requiresConfirmation(hardware: hardware, model: model) else {
            return nil
        }
        return policy.recommendation(hardware: hardware, model: model)
    }

    private func inlineSuitabilityAdvisory(for model: VoiceInputModel) -> ModelSuitabilityRecommendation? {
        guard model.id == VoiceInputModel.qwen3ASR17B.id else {
            return nil
        }
        guard let hardwareSummary else {
            return nil
        }
        let recommendation = ModelSuitabilityPolicy().recommendation(hardware: hardwareSummary, model: model)
        if recommendation.level == .stronglyDiscouraged || recommendation.level == .allowedWithWarning {
            return recommendation
        }
        return nil
    }

    private func continueAfterSuitabilityWarning(_ alert: ModelSuitabilityAlert) {
        switch alert.action {
        case .download:
            Task { await downloadModel(model: alert.model, bypassSuitabilityWarning: true) }
        case .use:
            useModel(alert.model, bypassSuitabilityWarning: true)
        }
    }

    @ViewBuilder
    private func statusBadge(model: VoiceInputModel, state: ModelDownloadState, copy: AppCopy.Texts) -> some View {
        switch state {
        case .notInstalled:
            EmptyView()
        case .downloading:
            badge(copy.modelDownloading, tint: theme.accent)
        case .ready:
            if settingsStore.selectedModelID == model.id {
                inUseBadge(copy.modelInUseTitle)
            } else {
                badge(copy.modelDownloadedTitle, tint: theme.secondaryInk)
            }
        case .repairNeeded:
            badge(copy.modelNeedsRepair, tint: .orange)
        case .failed:
            badge(copy.modelFailed, tint: theme.danger)
        }
    }

    private func badge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }

    /// The one accent-filled badge on the page: the model Fn dictation uses now.
    private func inUseBadge(_ title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(theme.onAccent)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(theme.accent, in: Capsule())
    }

    private func manager(for model: VoiceInputModel) -> ModelManager {
        ModelManager(model: model, applicationSupportRoot: modelManager.applicationSupportRoot)
    }

    private func isRefreshing(_ model: VoiceInputModel) -> Bool {
        refreshingModelIDs.contains(model.id)
    }

    private func isBusy(_ model: VoiceInputModel, state: ModelDownloadState) -> Bool {
        isRefreshing(model) || isDownloading(state)
    }

    private func isReady(_ state: ModelDownloadState) -> Bool {
        if case .ready = state { return true }
        return false
    }

    private func isDownloading(_ state: ModelDownloadState) -> Bool {
        if case .downloading = state { return true }
        return false
    }

    private func localState(for manager: ModelManager, copy: AppCopy.Texts) -> ModelDownloadState {
        if manager.isModelInstalled {
            return .ready
        }
        if manager.needsRepair {
            return .repairNeeded
        }
        return .notInstalled
    }

    private func reloadLocalState() {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)
        for model in models {
            // Keep an in-flight download's state: a disk probe mid-download
            // would misreport partial files as repair-needed and expose
            // destructive actions for a directory that is being written.
            if case .downloading = downloadStates[model.id] {
                continue
            }
            let manager = manager(for: model)
            downloadStates[model.id] = localState(for: manager, copy: copy)
        }
    }

    private func monitorModelStatuses() async {
        while !Task.isCancelled {
            await refreshAllStatuses(indicateActivity: false)
            let hasActivePreparation = downloadStates.values.contains(where: isDownloading)
            do {
                try await Task.sleep(
                    nanoseconds: ModelStatusRefreshPolicy.intervalNanoseconds(
                        hasActivePreparation: hasActivePreparation
                    )
                )
            } catch {
                return
            }
        }
    }

    private func refreshAllStatuses(indicateActivity: Bool = true) async {
        for model in models {
            await refreshStatus(for: model, indicateActivity: indicateActivity)
        }
    }

    private func refreshStatus(for model: VoiceInputModel, indicateActivity: Bool = true) async {
        guard !statusRequestsInFlight.contains(model.id) else { return }
        statusRequestsInFlight.insert(model.id)
        if indicateActivity {
            refreshingModelIDs.insert(model.id)
        }
        defer {
            statusRequestsInFlight.remove(model.id)
            if indicateActivity {
                refreshingModelIDs.remove(model.id)
            }
        }

        do {
            let status = try await actions.refreshModelStatus(model.modelID)
            apply(status: status, to: model)
        } catch {
            let copy = AppCopy.texts(for: settingsStore.uiLanguage)
            downloadStates[model.id] = ModelStatusRefreshPolicy.stateAfterRefreshFailure(
                current: downloadStates[model.id],
                fallback: localState(for: manager(for: model), copy: copy)
            )
        }
    }

    private func downloadModel(model: VoiceInputModel, bypassSuitabilityWarning: Bool) async {
        if !bypassSuitabilityWarning, let recommendation = shouldWarnBeforeActing(on: model) {
            suitabilityAlert = ModelSuitabilityAlert(model: model, recommendation: recommendation, action: .download)
            return
        }

        let currentState = downloadStates[model.id] ?? .notInstalled
        guard !isBusy(model, state: currentState) else { return }
        downloadStates[model.id] = .downloading(nil)

        do {
            let forceRepair: Bool
            if case .repairNeeded = currentState {
                forceRepair = true
            } else {
                forceRepair = false
            }
            let status = try await actions.downloadModel(model.modelID, forceRepair)
            apply(status: status, to: model)
        } catch {
            fail(error, for: model)
        }
    }

    private func apply(status: QwenModelStatus, to model: VoiceInputModel) {
        liveStatuses[model.id] = status
        let manager = manager(for: model)
        // Trust disk over the helper's in-memory session: after a delete the
        // helper can still report a recently-loaded model as installed, which
        // would silently resurrect the card the user just deleted.
        if (status.loaded || status.installed) && manager.isModelInstalled {
            try? manager.markInstalled()
            downloadStates[model.id] = .ready
            reloadStorageSizes()
        } else if status.downloading == true || status.loading == true {
            downloadStates[model.id] = .downloading(status.progress)
        } else {
            let copy = AppCopy.texts(for: settingsStore.uiLanguage)
            downloadStates[model.id] = localState(for: manager, copy: copy)
        }
    }

    private func fail(_ error: Error, for model: VoiceInputModel) {
        let message = error.localizedDescription
        downloadStates[model.id] = .failed(message)
        errorMessage = message
        isShowingError = true
    }

    private func useModel(_ model: VoiceInputModel, bypassSuitabilityWarning: Bool) {
        if !bypassSuitabilityWarning, let recommendation = shouldWarnBeforeActing(on: model) {
            suitabilityAlert = ModelSuitabilityAlert(model: model, recommendation: recommendation, action: .use)
            return
        }

        settingsStore.selectedModelID = model.id
        state.refresh()
    }

    private func openModelFolder(manager: ModelManager) {
        try? manager.ensureDirectories()
        NSWorkspace.shared.open(manager.modelDirectory)
    }

    private func copyModelPath(manager: ModelManager) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(manager.modelDirectory.path, forType: .string)
    }

    private func progressText(_ progress: Double?, copy: AppCopy.Texts) -> String {
        guard let progress else {
            return copy.modelPreparingMessage
        }
        let percentage = Int((min(max(progress, 0), 1) * 100).rounded())
        return "\(copy.modelPreparingMessage) \(percentage)%"
    }

    private func downloadSourceTitle(_ source: String?) -> String? {
        switch source {
        case "modelscope": return "ModelScope"
        case "huggingface": return "Hugging Face"
        default: return nil
        }
    }

}

enum ModelStatusRefreshPolicy {
    static func intervalNanoseconds(hasActivePreparation: Bool) -> UInt64 {
        hasActivePreparation ? 500_000_000 : 2_000_000_000
    }

    static func stateAfterRefreshFailure(
        current: ModelDownloadState?,
        fallback: ModelDownloadState
    ) -> ModelDownloadState {
        if case .downloading = current {
            return current ?? fallback
        }
        return fallback
    }
}

private struct ModelSuitabilityAlert: Identifiable {
    enum Action {
        case download
        case use
    }

    let id = UUID()
    let model: VoiceInputModel
    let recommendation: ModelSuitabilityRecommendation
    let action: Action
}

private struct QwenLogoIcon: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        if let image = Self.image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.skill)
        }
    }

    private static let image: NSImage? = {
        if let url = Bundle.main.url(forResource: "Qwen-logo", withExtension: "svg") {
            return NSImage(contentsOf: url)
        }
        return NSImage(contentsOfFile: "Resources/Qwen-logo.svg")
    }()
}
