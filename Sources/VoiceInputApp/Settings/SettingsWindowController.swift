import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let usageStatsStore: UsageStatsStore?
    private let onUsageStatsReset: () -> Void
    private let onUILanguageChange: (UILanguage) -> Void
    private var appThemeObserver: NSObjectProtocol?
    /// Bumped whenever the view must start again from the stored settings. SwiftUI keeps a
    /// view's `@State` across `rootView` swaps, so without a new identity the window kept
    /// showing the language it was first built with after onboarding switched it.
    private var contentGeneration = 0

    init(
        settingsStore: SettingsStore,
        usageStatsStore: UsageStatsStore?,
        onUsageStatsReset: @escaping () -> Void = {},
        onUILanguageChange: @escaping (UILanguage) -> Void = { _ in }
    ) {
        self.settingsStore = settingsStore
        self.usageStatsStore = usageStatsStore
        self.onUsageStatsReset = onUsageStatsReset
        self.onUILanguageChange = onUILanguageChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = SettingsCopy.texts(for: settingsStore.uiLanguage).windowTitle
        window.center()
        window.contentView = NSHostingView(rootView: AnyView(EmptyView()))
        super.init(window: window)
        applyWindowTheme()
        rebuildContent()
        appThemeObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.appThemeDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyWindowTheme()
                self?.rebuildContent()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let appThemeObserver {
            NotificationCenter.default.removeObserver(appThemeObserver)
        }
    }

    func show() {
        contentGeneration += 1
        applyWindowTheme()
        rebuildContent()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Re-reads every setting after something outside this window changed one, such as the
    /// interface language on the onboarding welcome page.
    func reloadFromStore() {
        contentGeneration += 1
        rebuildContent()
    }

    private func applyWindowTheme() {
        guard let window else { return }

        let theme = AppTheme.theme(for: settingsStore.appThemeID)
        if theme.usesSystemMaterials {
            window.titlebarAppearsTransparent = false
            window.backgroundColor = .windowBackgroundColor
            window.appearance = nil
        } else {
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(theme.surface)
            window.appearance = NSAppearance(named: .darkAqua)
        }
        window.contentView?.needsDisplay = true
        window.displayIfNeeded()
    }

    private func rebuildContent() {
        window?.title = SettingsCopy.texts(for: settingsStore.uiLanguage).windowTitle
        let rootView = SettingsView(
            settingsStore: settingsStore,
            usageStatsStore: usageStatsStore,
            onUsageStatsReset: onUsageStatsReset,
            onUILanguageChange: onUILanguageChange,
            onTitleChange: { [weak self] title in
                self?.window?.title = title
            }
        )
        .flowtypeTheme(AppTheme.theme(for: settingsStore.appThemeID))
        .id(contentGeneration)

        if let hostingView = window?.contentView as? NSHostingView<AnyView> {
            hostingView.rootView = AnyView(rootView)
        } else {
            window?.contentView = NSHostingView(rootView: AnyView(rootView))
        }
    }
}

private enum SettingsCopy {
    struct Texts {
        let windowTitle: String
        let subtitle: String
        let interfaceTitle: String
        let interfaceLanguageTitle: String
        let interfaceLanguageDetail: String
        let textSizeTitle: String
        let textSizeDetail: String
        let dictationTitle: String
        let microphoneTitle: String
        let microphoneDetail: String
        let automaticMicrophonePrefix: String
        let currentDefaultSuffix: String
        let refreshMicrophonesHelp: String
        let primaryEngineTitle: String
        let primaryEngineDetail: String
        let fallbackTitle: String
        let fallbackDetail: String
        let recordingLimitTitle: String
        let recordingLimitDetail: String
        let privacyTitle: String
        let saveTranscriptHistoryTitle: String
        let historyEnabledDetail: String
        let historyDisabledDetail: String
        let historyLimitTitle: String
        let historyLimitDetail: String
        let resetLocalStatsTitle: String
        let resetLocalStatsHelp: String
        let resetConfirmationTitle: String
        let resetConfirmationAction: String
        let resetConfirmationMessage: String
        let resetErrorTitle: String
        let storageTitle: String
        let storageLocationsDisclosureTitle: String
        let usageStatsTitle: String
        let usageStatsDetail: String
        let transcriptHistoryTitle: String
        let transcriptHistoryDetail: String
        let temporaryRecordingsTitle: String
        let temporaryRecordingsDetail: String
        let retainedRecordingsTitle: String
        let retainedRecordingsDetail: String
        let modelCacheTitle: String
        let modelCacheDetail: String
        let helperRuntimeTitle: String
        let helperRuntimeDetail: String
        let openLocationTitle: String
        let openLocationHelp: String
        let copyTitle: String
        let copyPathHelp: String
        let cancel: String
        let ok: String

    }

    static func texts(for language: UILanguage) -> Texts {
        switch language {
        case .chinese:
            return Texts(
                windowTitle: "设置与存储",
                subtitle: "管理界面语言、麦克风、本地历史、数据存储位置和隐私选项。",
                interfaceTitle: "界面",
                interfaceLanguageTitle: "界面语言",
                interfaceLanguageDetail: "选择界面显示中文或英文。第一次打开时跟随 Mac 的系统语言。",
                textSizeTitle: "文字大小",
                textSizeDetail: "调整 Flowtype 所有窗口的字号。也可以按 ⌘+ 放大、⌘− 缩小。",
                dictationTitle: "听写",
                microphoneTitle: "麦克风",
                microphoneDetail: "选择按住 Fn 听写时使用的输入设备。",
                automaticMicrophonePrefix: "自动检测",
                currentDefaultSuffix: "（当前默认）",
                refreshMicrophonesHelp: "刷新麦克风列表",
                primaryEngineTitle: "主要引擎",
                primaryEngineDetail: "按 Fn 听写时优先使用。",
                fallbackTitle: "备用方案",
                fallbackDetail: "仅在本地 Qwen 不可用时使用。",
                recordingLimitTitle: "录音时长上限",
                recordingLimitDetail: "接近上限时会提醒；超时后会直接转写已有录音，而不是丢弃音频。",
                privacyTitle: "隐私",
                saveTranscriptHistoryTitle: "保存转写历史",
                historyEnabledDetail: "成功转写的文本会保存在这台 Mac 本地。",
                historyDisabledDetail: "新的转写只会粘贴或复制，不会加入本地历史。",
                historyLimitTitle: "历史数量上限",
                historyLimitDetail: "这台 Mac 本地最多保留的历史条目数。",
                resetLocalStatsTitle: "重置本地统计",
                resetLocalStatsHelp: "清除本地累计使用统计",
                resetConfirmationTitle: "确定要重置本地统计吗？",
                resetConfirmationAction: "重置统计",
                resetConfirmationMessage: "这会清除听写次数、听写时长、字数和预计节省时间等本地累计统计。此操作不会删除转写历史。",
                resetErrorTitle: "无法重置统计",
                storageTitle: "存储",
                storageLocationsDisclosureTitle: "查看本地文件与模型位置",
                usageStatsTitle: "使用统计",
                usageStatsDetail: "Home 卡片上显示的本地累计计数。",
                transcriptHistoryTitle: "转写历史",
                transcriptHistoryDetail: "开启历史时，这里只保存文本历史。",
                temporaryRecordingsTitle: "临时录音",
                temporaryRecordingsDetail: "听写过程中会在这里写入短 WAV 文件，转写完成后删除。",
                retainedRecordingsTitle: "可重试录音",
                retainedRecordingsDetail: "最近最多保留 3 条本地录音，只用于 History 中的手动重试。",
                modelCacheTitle: "模型缓存",
                modelCacheDetail: "Flowtype 管理的本地 Qwen 模型文件。",
                helperRuntimeTitle: "Helper 运行环境",
                helperRuntimeDetail: "本地 Qwen ASR 使用的 Python helper 服务文件。",
                openLocationTitle: "打开位置",
                openLocationHelp: "在 Finder 中打开这个位置",
                copyTitle: "复制",
                copyPathHelp: "复制路径",
                cancel: "取消",
                ok: "好"
            )
        case .english:
            return Texts(
                windowTitle: "Settings & Storage",
                subtitle: "Manage the interface language, microphone, local history, storage locations, and privacy options.",
                interfaceTitle: "Interface",
                interfaceLanguageTitle: "Interface language",
                interfaceLanguageDetail: "Choose whether the interface appears in Chinese or English. The first launch follows the Mac's system language.",
                textSizeTitle: "Text size",
                textSizeDetail: "Changes the text size in every Flowtype window. You can also press ⌘+ to enlarge and ⌘− to shrink.",
                dictationTitle: "Dictation",
                microphoneTitle: "Microphone",
                microphoneDetail: "Choose the input device used for Fn dictation.",
                automaticMicrophonePrefix: "Auto-detect",
                currentDefaultSuffix: "(current default)",
                refreshMicrophonesHelp: "Refresh microphones",
                primaryEngineTitle: "Primary engine",
                primaryEngineDetail: "Used first for Fn dictation.",
                fallbackTitle: "Fallback",
                fallbackDetail: "Used only if local Qwen is unavailable.",
                recordingLimitTitle: "Recording limit",
                recordingLimitDetail: "Warnings appear near the limit; timeout now transcribes instead of discarding audio.",
                privacyTitle: "Privacy",
                saveTranscriptHistoryTitle: "Save transcript history",
                historyEnabledDetail: "Successful transcripts are saved locally on this Mac.",
                historyDisabledDetail: "New transcripts are pasted or copied, but not added to local history.",
                historyLimitTitle: "History limit",
                historyLimitDetail: "Maximum local entries kept on this Mac.",
                resetLocalStatsTitle: "Reset Local Stats",
                resetLocalStatsHelp: "Clear local aggregate usage stats",
                resetConfirmationTitle: "Reset local usage stats?",
                resetConfirmationAction: "Reset Stats",
                resetConfirmationMessage: "This clears local aggregate counts such as dictations, dictated time, words, and estimated saved time. It does not delete transcript history.",
                resetErrorTitle: "Could not reset stats",
                storageTitle: "Storage",
                storageLocationsDisclosureTitle: "View local file and model locations",
                usageStatsTitle: "Usage stats",
                usageStatsDetail: "Aggregate local counters shown on the Home cards.",
                transcriptHistoryTitle: "Transcript history",
                transcriptHistoryDetail: "Only text history is kept here when history is enabled.",
                temporaryRecordingsTitle: "Temporary recordings",
                temporaryRecordingsDetail: "Short WAV files are written here during dictation and deleted after transcription finishes.",
                retainedRecordingsTitle: "Retry recordings",
                retainedRecordingsDetail: "Up to three recent recordings are kept locally only for manual retries in History.",
                modelCacheTitle: "Model cache",
                modelCacheDetail: "Local Qwen model files managed by Flowtype.",
                helperRuntimeTitle: "Helper runtime",
                helperRuntimeDetail: "Python helper service files used by local Qwen ASR.",
                openLocationTitle: "Open Location",
                openLocationHelp: "Open this location in Finder",
                copyTitle: "Copy",
                copyPathHelp: "Copy path",
                cancel: "Cancel",
                ok: "OK"
            )
        }
    }

    static func textSizeName(_ size: AppTextSize, in uiLanguage: UILanguage) -> String {
        let isDefault = size == AppTextSize.defaultSize
        switch (size, uiLanguage) {
        case (.small, .chinese): return "小"
        case (.standard, .chinese): return isDefault ? "标准（默认）" : "标准"
        case (.large, .chinese): return "大"
        case (.small, .english): return "Small"
        case (.standard, .english): return isDefault ? "Standard (default)" : "Standard"
        case (.large, .english): return "Large"
        }
    }

    static func languageName(_ language: UILanguage, in uiLanguage: UILanguage) -> String {
        switch (language, uiLanguage) {
        case (.chinese, .chinese):
            return "中文"
        case (.english, .chinese):
            return "英文"
        case (.chinese, .english):
            return "Chinese"
        case (.english, .english):
            return "English"
        }
    }
}

private struct SettingsView: View {
    @Environment(\.appTheme) private var theme

    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject private var textSizeModel = AppTextSizeModel.shared
    let usageStatsStore: UsageStatsStore?
    let onUsageStatsReset: () -> Void
    let onUILanguageChange: (UILanguage) -> Void
    let onTitleChange: (String) -> Void

    @State private var uiLanguage: UILanguage
    @State private var isHistoryEnabled: Bool
    @State private var historyLimit: Int
    @State private var maxRecordingDuration: Int
    @State private var selectedMicrophoneUID: String
    @State private var inputDevices: [AudioInputDevice]
    @State private var isConfirmingResetStats = false
    @State private var isShowingResetStatsError = false
    @State private var resetStatsErrorMessage = ""
    @State private var isShowingStorageLocations = false

    init(
        settingsStore: SettingsStore,
        usageStatsStore: UsageStatsStore?,
        onUsageStatsReset: @escaping () -> Void,
        onUILanguageChange: @escaping (UILanguage) -> Void,
        onTitleChange: @escaping (String) -> Void
    ) {
        self.settingsStore = settingsStore
        self.usageStatsStore = usageStatsStore
        self.onUsageStatsReset = onUsageStatsReset
        self.onUILanguageChange = onUILanguageChange
        self.onTitleChange = onTitleChange
        _uiLanguage = State(initialValue: settingsStore.uiLanguage)
        _isHistoryEnabled = State(initialValue: settingsStore.isHistoryEnabled)
        _historyLimit = State(initialValue: settingsStore.historyLimit)
        _maxRecordingDuration = State(initialValue: settingsStore.maxRecordingDuration)
        _selectedMicrophoneUID = State(initialValue: settingsStore.selectedMicrophoneUID ?? "")
        _inputDevices = State(initialValue: AudioInputDeviceManager.inputDevices())
    }

    var body: some View {
        let copy = SettingsCopy.texts(for: uiLanguage)

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                languageSection
                dictationSection
                privacySection
                storageSection
            }
            .padding(34)
            .frame(maxWidth: 680, alignment: .topLeading)
        }
        .background(theme.surface)
        .onAppear {
            onTitleChange(copy.windowTitle)
        }
        .confirmationDialog(
            copy.resetConfirmationTitle,
            isPresented: $isConfirmingResetStats
        ) {
            Button(copy.resetConfirmationAction, role: .destructive) {
                resetUsageStats()
            }
            Button(copy.cancel, role: .cancel) {}
        } message: {
            Text(copy.resetConfirmationMessage)
        }
        .alert(copy.resetErrorTitle, isPresented: $isShowingResetStatsError) {
            Button(copy.ok, role: .cancel) {}
        } message: {
            Text(resetStatsErrorMessage)
        }
    }

    private var header: some View {
        let copy = SettingsCopy.texts(for: uiLanguage)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .scaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(theme.accent)
                    .frame(width: 34, height: 34)
                    .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(copy.windowTitle)
                    .scaledFont(size: 32, weight: .semibold)
            }

            Text(copy.subtitle)
                .scaledFont(.callout)
                .foregroundStyle(theme.secondaryInk)
        }
    }

    private var languageSection: some View {
        let copy = SettingsCopy.texts(for: uiLanguage)

        return SettingsCard(title: copy.interfaceTitle, systemImage: "globe") {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(copy.interfaceLanguageTitle)
                        .fontWeight(.medium)
                    Text(copy.interfaceLanguageDetail)
                        .scaledFont(.caption)
                        .foregroundStyle(theme.secondaryInk)
                }

                Spacer(minLength: 16)

                Picker("", selection: uiLanguageBinding) {
                    ForEach(UILanguage.allCases, id: \.self) { language in
                        Text(SettingsCopy.languageName(language, in: uiLanguage))
                            .tag(language)
                    }
                }
                .labelsHidden()
                .frame(width: 180, alignment: .trailing)
                // A tinted pop-up arrow box renders the accent as muddy gold; keep it neutral.
                .tint(Color(nsColor: .systemGray))
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(copy.textSizeTitle)
                        .fontWeight(.medium)
                    Text(copy.textSizeDetail)
                        .scaledFont(.caption)
                        .foregroundStyle(theme.secondaryInk)
                }

                Spacer(minLength: 16)

                Picker("", selection: textSizeBinding) {
                    ForEach(AppTextSize.allCases, id: \.self) { size in
                        Text(SettingsCopy.textSizeName(size, in: uiLanguage))
                            .tag(size)
                    }
                }
                .labelsHidden()
                .frame(width: 180, alignment: .trailing)
                .tint(Color(nsColor: .systemGray))
            }
        }
    }

    private var dictationSection: some View {
        let copy = SettingsCopy.texts(for: uiLanguage)

        return SettingsCard(title: copy.dictationTitle, systemImage: "mic") {
            MicrophonePickerRow(
                selectedMicrophoneUID: microphoneBinding,
                devices: inputDevices,
                automaticTitle: automaticMicrophoneTitle,
                title: copy.microphoneTitle,
                detail: copy.microphoneDetail,
                currentDefaultSuffix: copy.currentDefaultSuffix,
                refreshHelp: copy.refreshMicrophonesHelp,
                refresh: refreshInputDevices
            )
            SettingsValueRow(
                title: copy.primaryEngineTitle,
                value: SettingsPresentation.primaryEngineName(selectedModelID: settingsStore.selectedModelID),
                detail: copy.primaryEngineDetail
            )
            SettingsValueRow(title: copy.fallbackTitle, value: "Apple Speech", detail: copy.fallbackDetail)
            SettingsMenuRow(
                title: copy.recordingLimitTitle,
                detail: copy.recordingLimitDetail,
                selection: maxRecordingDurationBinding,
                options: SettingsLimitOptions.recordingDurations(including: maxRecordingDuration).map {
                    ($0, SettingsLimitOptions.durationLabel(seconds: $0, language: uiLanguage))
                }
            )
        }
    }

    private var privacySection: some View {
        let copy = SettingsCopy.texts(for: uiLanguage)

        return SettingsCard(title: copy.privacyTitle, systemImage: "lock") {
            Toggle(copy.saveTranscriptHistoryTitle, isOn: historyEnabledBinding)
                .flowtypeSwitch(theme)

            Text(isHistoryEnabled ? copy.historyEnabledDetail : copy.historyDisabledDetail)
                .scaledFont(.caption)
                .foregroundStyle(theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            SettingsMenuRow(
                title: copy.historyLimitTitle,
                detail: copy.historyLimitDetail,
                selection: historyLimitBinding,
                options: SettingsLimitOptions.historyLimits(including: historyLimit).map {
                    ($0, SettingsLimitOptions.historyLabel(entries: $0, language: uiLanguage))
                }
            )

            Divider()

            Button(role: .destructive) {
                isConfirmingResetStats = true
            } label: {
                Label(copy.resetLocalStatsTitle, systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(FlowtypeNeutralButtonStyle(theme: theme))
            .disabled(usageStatsStore == nil)
            .help(copy.resetLocalStatsHelp)
        }
    }

    private var storageSection: some View {
        let copy = SettingsCopy.texts(for: uiLanguage)

        return SettingsCard(title: copy.storageTitle, systemImage: "internaldrive") {
            DisclosureGroup(isExpanded: $isShowingStorageLocations) {
                VStack(alignment: .leading, spacing: 13) {
                    PathRow(
                        title: copy.usageStatsTitle,
                        detail: copy.usageStatsDetail,
                        path: Self.usageStatsPath(),
                        isDirectory: false,
                        copy: copy
                    )
                    PathRow(
                        title: copy.transcriptHistoryTitle,
                        detail: copy.transcriptHistoryDetail,
                        path: Self.transcriptHistoryPath(),
                        isDirectory: false,
                        copy: copy
                    )
                    PathRow(
                        title: copy.temporaryRecordingsTitle,
                        detail: copy.temporaryRecordingsDetail,
                        path: FileManager.default.temporaryDirectory.path,
                        isDirectory: true,
                        copy: copy
                    )
                    PathRow(
                        title: copy.retainedRecordingsTitle,
                        detail: copy.retainedRecordingsDetail,
                        path: SettingsPresentation.retainedRecordingsPath(),
                        isDirectory: true,
                        copy: copy
                    )
                    PathRow(
                        title: copy.modelCacheTitle,
                        detail: copy.modelCacheDetail,
                        path: SettingsPresentation.modelsRootPath(),
                        isDirectory: true,
                        copy: copy
                    )
                    PathRow(
                        title: copy.helperRuntimeTitle,
                        detail: copy.helperRuntimeDetail,
                        path: Self.helperRuntimePath(),
                        isDirectory: true,
                        copy: copy
                    )
                }
                .padding(.top, 12)
            } label: {
                Text(copy.storageLocationsDisclosureTitle)
                    .fontWeight(.medium)
            }
        }
    }

    private var historyEnabledBinding: Binding<Bool> {
        Binding(
            get: { isHistoryEnabled },
            set: { newValue in
                isHistoryEnabled = newValue
                settingsStore.isHistoryEnabled = newValue
            }
        )
    }

    /// Reads the shared model so a ⌘+ / ⌘− change shows here while the window is open.
    private var textSizeBinding: Binding<AppTextSize> {
        Binding(
            get: { textSizeModel.size },
            set: { settingsStore.textSize = $0 }
        )
    }

    private var uiLanguageBinding: Binding<UILanguage> {
        Binding(
            get: { uiLanguage },
            set: { newValue in
                uiLanguage = newValue
                settingsStore.uiLanguage = newValue
                onTitleChange(SettingsCopy.texts(for: newValue).windowTitle)
                onUILanguageChange(newValue)
            }
        )
    }

    private var historyLimitBinding: Binding<Int> {
        Binding(
            get: { historyLimit },
            set: { newValue in
                historyLimit = newValue
                settingsStore.historyLimit = newValue
            }
        )
    }

    private var maxRecordingDurationBinding: Binding<Int> {
        Binding(
            get: { maxRecordingDuration },
            set: { newValue in
                maxRecordingDuration = newValue
                settingsStore.maxRecordingDuration = newValue
            }
        )
    }

    private var microphoneBinding: Binding<String> {
        Binding(
            get: { selectedMicrophoneUID },
            set: { newValue in
                selectedMicrophoneUID = newValue
                settingsStore.selectedMicrophoneUID = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private var automaticMicrophoneTitle: String {
        let copy = SettingsCopy.texts(for: uiLanguage)
        if let name = AudioInputDeviceManager.defaultInputDeviceName(), !name.isEmpty {
            return "\(copy.automaticMicrophonePrefix) (\(name))"
        }
        return copy.automaticMicrophonePrefix
    }

    private func refreshInputDevices() {
        inputDevices = AudioInputDeviceManager.inputDevices()
        if !selectedMicrophoneUID.isEmpty,
           !inputDevices.contains(where: { $0.uid == selectedMicrophoneUID }) {
            selectedMicrophoneUID = ""
            settingsStore.selectedMicrophoneUID = nil
        }
    }

    private func resetUsageStats() {
        do {
            try usageStatsStore?.reset()
            onUsageStatsReset()
        } catch {
            resetStatsErrorMessage = UserFacingErrorMessage.message(for: error, language: uiLanguage)
            isShowingResetStatsError = true
        }
    }

    private static func transcriptHistoryPath() -> String {
        (try? TranscriptHistoryStore.defaultFileURL().path) ??
            "Application Support/\(ApplicationSupport.appDirectoryName)/history.json"
    }

    private static func usageStatsPath() -> String {
        (try? UsageStatsStore.defaultFileURL().path) ??
            "Application Support/\(ApplicationSupport.appDirectoryName)/usage-stats.json"
    }

    private static func helperRuntimePath() -> String {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.homeDirectoryForCurrentUser
        return baseURL
            .appendingPathComponent(ApplicationSupport.appDirectoryName, isDirectory: true)
            .appendingPathComponent("qwen-asr-helper", isDirectory: true)
            .path
    }
}

private struct SettingsCard<Content: View>: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .scaledFont(.headline)
                .foregroundStyle(theme.ink)

            VStack(alignment: .leading, spacing: 13) {
                content
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(theme.ink)
        .themedCard(theme)
    }
}

private struct SettingsValueRow: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .scaledFont(.caption)
                    .foregroundStyle(theme.secondaryInk)
            }

            Spacer(minLength: 16)

            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// A setting chosen from a pop-up menu, laid out like the language and microphone rows.
/// Replaced the steppers, whose tiny arrows did not line up with the value (owner feedback,
/// 2026-10-11).
private struct SettingsMenuRow: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let detail: String
    let selection: Binding<Int>
    let options: [(value: Int, label: String)]

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .scaledFont(.caption)
                    .foregroundStyle(theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Picker("", selection: selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .labelsHidden()
            .frame(width: 180, alignment: .trailing)
            // A tinted pop-up arrow box renders the accent as muddy gold; keep it neutral.
            .tint(Color(nsColor: .systemGray))
        }
    }
}

private struct MicrophonePickerRow: View {
    @Environment(\.appTheme) private var theme

    let selectedMicrophoneUID: Binding<String>
    let devices: [AudioInputDevice]
    let automaticTitle: String
    let title: String
    let detail: String
    let currentDefaultSuffix: String
    let refreshHelp: String
    let refresh: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .scaledFont(.caption)
                    .foregroundStyle(theme.secondaryInk)
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                Picker("", selection: selectedMicrophoneUID) {
                    Text(automaticTitle).tag("")
                    ForEach(devices) { device in
                        Text(device.isDefault ? "\(device.name) \(currentDefaultSuffix)" : device.name)
                            .tag(device.uid)
                    }
                }
                .labelsHidden()
                .frame(width: 260)
                // A tinted pop-up arrow box renders the accent as muddy gold; keep it neutral.
                .tint(Color(nsColor: .systemGray))

                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(refreshHelp)
            }
        }
    }
}

private struct PathRow: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let detail: String
    let path: String
    let isDirectory: Bool
    let copy: SettingsCopy.Texts

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .fontWeight(.medium)
                    Text(detail)
                        .scaledFont(.caption)
                        .foregroundStyle(theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        openLocation()
                    } label: {
                        Label(copy.openLocationTitle, systemImage: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help(copy.openLocationHelp)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                    } label: {
                        Label(copy.copyTitle, systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help(copy.copyPathHelp)
                }
            }

            Text(path)
                .scaledFont(.caption, design: .monospaced)
                .foregroundStyle(theme.secondaryInk)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .themedInset(theme, cornerRadius: 8)
        }
    }

    private func openLocation() {
        let url = URL(fileURLWithPath: path, isDirectory: isDirectory)
        let folderURL = isDirectory ? url : url.deletingLastPathComponent()

        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folderURL)
    }
}

/// Menu choices for the recording and history limits. A stored value that is not one of the
/// presets (for example from the old 30-second stepper) is added so the menu still shows it.
enum SettingsLimitOptions {
    static let defaultRecordingDuration = 180
    static let defaultHistoryLimit = 100
    static let recordingDurationPresets = [30, 60, 90, 120, 180, 240, 300, 420, 600]
    static let historyLimitPresets = [10, 25, 50, 100, 200, 300, 500]

    static func recordingDurations(including current: Int) -> [Int] {
        merged(recordingDurationPresets, current)
    }

    static func historyLimits(including current: Int) -> [Int] {
        merged(historyLimitPresets, current)
    }

    static func durationLabel(seconds: Int, language: UILanguage) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        let chinese = language == .chinese
        let text: String
        switch (minutes, rest) {
        case (0, _):
            text = chinese ? "\(rest) 秒" : "\(rest) sec"
        case (_, 0):
            text = chinese ? "\(minutes) 分钟" : "\(minutes) min"
        default:
            text = chinese ? "\(minutes) 分 \(rest) 秒" : "\(minutes) min \(rest) sec"
        }
        return seconds == defaultRecordingDuration ? withDefaultMark(text, language: language) : text
    }

    static func historyLabel(entries: Int, language: UILanguage) -> String {
        let text = language == .chinese ? "\(entries) 条" : "\(entries) entries"
        return entries == defaultHistoryLimit ? withDefaultMark(text, language: language) : text
    }

    private static func merged(_ presets: [Int], _ current: Int) -> [Int] {
        presets.contains(current) ? presets : (presets + [current]).sorted()
    }

    private static func withDefaultMark(_ text: String, language: UILanguage) -> String {
        language == .chinese ? "\(text)（默认）" : "\(text) (default)"
    }
}
