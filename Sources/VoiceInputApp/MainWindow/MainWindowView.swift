import AppKit
import SwiftUI

enum SegmentedRetryResult: Equatable {
    case succeeded
    case failed
    case expiredRecording
}

struct MainWindowActions {
    var openSettings: () -> Void
    var showHelp: () -> Void
    var copyTranscript: (String) -> Void
    var pasteTranscript: (String) -> Void
    var retrySegmentedTranscription: (TranscriptHistoryItem) async -> SegmentedRetryResult
    var clearHistory: () throws -> Void
    var refreshModelStatus: (String) async throws -> QwenModelStatus
    var downloadModel: (String, Bool) async throws -> QwenModelStatus
    var refreshReadiness: () async -> ReadinessReport
    var refreshReadinessLive: () async -> ReadinessReport
    var prepareFlowtype: (
        PreparationIntent,
        @escaping (PreparationSnapshot) -> Void
    ) async throws -> ReadinessSetupResult
    var prepareRuntime: () async throws -> ReadinessReport
    var repairHelper: () async throws -> ReadinessReport
    var downloadDefaultModel: () async throws -> QwenModelStatus
    var warmSelectedModel: () async throws -> QwenModelStatus
    var retrySelectedModelPreload: () async throws -> QwenModelStatus
    var openReadinessLocation: (ReadinessLocationTarget) -> Void
    var generateDiagnosticsFile: (ReadinessReport) async throws -> DiagnosticsFileResult
    var revealDiagnosticsFile: (URL) -> Void
    var copyDiagnostics: (ReadinessReport) async throws -> String
    var saveDiagnosticsSnapshot: (ReadinessReport) async -> Void
    var requestMicrophone: () -> Void
    var openAccessibilitySettings: () -> Void
    var requestSpeechRecognition: () -> Void

    init(
        openSettings: @escaping () -> Void = {},
        showHelp: @escaping () -> Void = {},
        copyTranscript: @escaping (String) -> Void = { _ in },
        pasteTranscript: @escaping (String) -> Void = { _ in },
        retrySegmentedTranscription: @escaping (TranscriptHistoryItem) async -> SegmentedRetryResult = { _ in .failed },
        clearHistory: @escaping () throws -> Void = {},
        refreshModelStatus: @escaping (String) async throws -> QwenModelStatus = { modelID in
            QwenModelStatus(
                installed: false,
                loaded: false,
                loading: nil,
                downloading: nil,
                progress: nil,
                modelId: modelID,
                modelPath: nil
            )
        },
        downloadModel: @escaping (String, Bool) async throws -> QwenModelStatus = { modelID, _ in
            QwenModelStatus(
                installed: false,
                loaded: false,
                loading: nil,
                downloading: nil,
                progress: nil,
                modelId: modelID,
                modelPath: nil
            )
        },
        refreshReadiness: @escaping () async -> ReadinessReport = {
            ReadinessReport(generatedAt: Date(), checks: [])
        },
        refreshReadinessLive: @escaping () async -> ReadinessReport = {
            ReadinessReport(generatedAt: Date(), checks: [])
        },
        prepareFlowtype: @escaping (
            PreparationIntent,
            @escaping (PreparationSnapshot) -> Void
        ) async throws -> ReadinessSetupResult = { _, _ in
            ReadinessSetupResult(
                outcome: .failed("Setup is unavailable."),
                report: ReadinessReport(generatedAt: Date(), checks: [])
            )
        },
        prepareRuntime: @escaping () async throws -> ReadinessReport = {
            ReadinessReport(generatedAt: Date(), checks: [])
        },
        repairHelper: @escaping () async throws -> ReadinessReport = {
            ReadinessReport(generatedAt: Date(), checks: [])
        },
        downloadDefaultModel: @escaping () async throws -> QwenModelStatus = {
            QwenModelStatus(
                installed: false,
                loaded: false,
                loading: nil,
                downloading: nil,
                progress: nil,
                modelId: VoiceInputModel.qwen3ASR06B.modelID,
                modelPath: nil
            )
        },
        warmSelectedModel: @escaping () async throws -> QwenModelStatus = {
            QwenModelStatus(
                installed: false,
                loaded: false,
                loading: nil,
                downloading: nil,
                progress: nil,
                modelId: "",
                modelPath: nil
            )
        },
        retrySelectedModelPreload: @escaping () async throws -> QwenModelStatus = {
            QwenModelStatus(
                installed: false,
                loaded: false,
                loading: nil,
                downloading: nil,
                progress: nil,
                modelId: "",
                modelPath: nil
            )
        },
        openReadinessLocation: @escaping (ReadinessLocationTarget) -> Void = { _ in },
        generateDiagnosticsFile: @escaping (ReadinessReport) async throws -> DiagnosticsFileResult = { report in
            let writer = DiagnosticsFileWriter()
            return try await writer.generate(report: report)
        },
        revealDiagnosticsFile: @escaping (URL) -> Void = { _ in },
        copyDiagnostics: @escaping (ReadinessReport) async throws -> String = { _ in "" },
        saveDiagnosticsSnapshot: @escaping (ReadinessReport) async -> Void = { _ in },
        requestMicrophone: @escaping () -> Void = {},
        openAccessibilitySettings: @escaping () -> Void = {},
        requestSpeechRecognition: @escaping () -> Void = {}
    ) {
        self.openSettings = openSettings
        self.showHelp = showHelp
        self.copyTranscript = copyTranscript
        self.pasteTranscript = pasteTranscript
        self.retrySegmentedTranscription = retrySegmentedTranscription
        self.clearHistory = clearHistory
        self.refreshModelStatus = refreshModelStatus
        self.downloadModel = downloadModel
        self.refreshReadiness = refreshReadiness
        self.refreshReadinessLive = refreshReadinessLive
        self.prepareFlowtype = prepareFlowtype
        self.prepareRuntime = prepareRuntime
        self.repairHelper = repairHelper
        self.downloadDefaultModel = downloadDefaultModel
        self.warmSelectedModel = warmSelectedModel
        self.retrySelectedModelPreload = retrySelectedModelPreload
        self.openReadinessLocation = openReadinessLocation
        self.generateDiagnosticsFile = generateDiagnosticsFile
        self.revealDiagnosticsFile = revealDiagnosticsFile
        self.copyDiagnostics = copyDiagnostics
        self.saveDiagnosticsSnapshot = saveDiagnosticsSnapshot
        self.requestMicrophone = requestMicrophone
        self.openAccessibilitySettings = openAccessibilitySettings
        self.requestSpeechRecognition = requestSpeechRecognition
    }
}

struct MainWindowView: View {
    @ObservedObject var state: MainWindowState
    let hotwordStore: HotwordStore
    let historyStore: TranscriptHistoryStore
    let usageStatsStore: UsageStatsStore?
    @ObservedObject var settingsStore: SettingsStore
    let modelManager: ModelManager
    @ObservedObject var readinessStore: MainWindowReadinessStore
    let actions: MainWindowActions

    var body: some View {
        let theme = AppTheme.theme(for: settingsStore.appThemeID)
        let selectedSection = Binding<MainWindowSection>(
            get: {
                state.selectedSection
            },
            set: { nextSection in
                state.show(nextSection)
            }
        )

        HSplitView {
            MainSidebarView(
                selectedSection: selectedSection,
                uiLanguage: settingsStore.uiLanguage,
                actions: actions
            )
            .frame(width: 196)

            detailView
                .frame(minWidth: 620)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.surface)
        .flowtypeTheme(theme)
        .task {
            await readinessStore.refreshLive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await readinessStore.refreshLive()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch state.selectedSection {
        case .home:
            HomeView(
                state: state,
                hotwordStore: hotwordStore,
                historyStore: historyStore,
                usageStatsStore: usageStatsStore,
                settingsStore: settingsStore,
                readinessStore: readinessStore,
                actions: actions
            )
        case .dictionary:
            DictionaryView(
                state: state,
                hotwordStore: hotwordStore,
                uiLanguage: settingsStore.uiLanguage
            )
        case .models:
            ModelsView(
                state: state,
                settingsStore: settingsStore,
                modelManager: modelManager,
                actions: actions
            )
        case .readiness:
            ReadinessCenterView(
                settingsStore: settingsStore,
                readinessStore: readinessStore,
                actions: actions
            )
        case .preferences:
            PreferencesView(
                state: state,
                settingsStore: settingsStore
            )
        }
    }

}
