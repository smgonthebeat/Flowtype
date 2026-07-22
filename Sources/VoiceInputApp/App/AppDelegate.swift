import AppKit
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private let permissionManager = PermissionManager()
    private let fnKeyMonitor = FnKeyMonitor()
    private let recorder = AudioRecorder()
    private let settingsStore = SettingsStore()
    private let hotwordStore = try? HotwordStore.defaultStore()
    @MainActor
    private lazy var pasteInjector = PasteInjector(
        pasteboardWriter: NSPasteboardStringWriter(pasteboard: .general),
        shortcutPoster: PasteShortcutPoster { processIdentifier, event in
            event.postToPid(processIdentifier)
        },
        inputSourceController: InputSourceManager()
    )
    @MainActor
    private lazy var pasteCoordinator = PasteCoordinator(
        injector: pasteInjector,
        telemetry: PasteLoggerTelemetry()
    )
    private let modelManager = ModelManager()
    private lazy var helperProcessManager = HelperProcessManager(settingsStore: settingsStore)
    private lazy var flowtypePreparation = FlowtypePreparation(driver: self)
    private lazy var historyStore = try? TranscriptHistoryStore.defaultStore(limit: settingsStore.historyLimit)
    private lazy var usageStatsStore = try? UsageStatsStore.defaultStore()
    private lazy var retainedRecordingStore = try? RetainedRecordingStore.defaultStore()
    private lazy var timingStore = TranscriptionTimingStore(applicationSupportRoot: modelManager.applicationSupportRoot)
    private lazy var provenanceStore = TranscriptionProvenanceStore(applicationSupportRoot: modelManager.applicationSupportRoot)
    private lazy var readinessService = ReadinessService(
        helperRuntimeManager: HelperRuntimeManager(applicationSupportRoot: modelManager.applicationSupportRoot),
        performanceInspector: PerformanceInspector(
            processProvider: ProcessRSSSnapshot.flowtypeRelatedProcesses,
            timingProvider: { [weak self] in
                try? self?.timingStore.loadLastSample()
            }
        ),
        modelStatusFetcher: { [weak self] modelID in
            guard let self else {
                return QwenModelStatus(
                    installed: false,
                    loaded: false,
                    loading: nil,
                    downloading: nil,
                    progress: nil,
                    modelId: modelID,
                    modelPath: nil
                )
            }
            return try await self.refreshQwenModelStatus(modelID: modelID)
        },
        timingProvider: { [weak self] in
            try? self?.timingStore.loadLastSample()
        },
        processProvider: ProcessRSSSnapshot.flowtypeRelatedProcesses
    )
    @MainActor
    private lazy var capsule = FloatingCapsulePanel()
    private var meter = RMSMeter()
    private var dictationSession = DictationSessionController()
    private var recordingPreviewID = UUID()
    private var isRecordingPreviewActive = false
    private var currentRecordingURL: URL?
    private var recordingStartedAt: Date?
    private var recordingTimeoutWorkItem: DispatchWorkItem?
    private var recordingWarningWorkItems: [DispatchWorkItem] = []
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var helpWindowController: HelpWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var mainWindowController: MainWindowController?
    private var lastExternalApplication: NSRunningApplication?
    private var recordingTargetApplication: NSRunningApplication?
    private var lastTranscript: String?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var selectedModelObserver: NSObjectProtocol?
    private var engineObserver: NSObjectProtocol?
    private var preparationConfigurationGeneration = 0
    private var lastPreparationConfigurationKey: String?
    private var didRunInitialSetupRoute = false
    private var helperStopRequestedAfterTranscription = false

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = AppMainMenu.make(copy: AppCopy.texts(for: settingsStore.uiLanguage))
        let initialReadinessSnapshot = makeLightweightReadinessSnapshot()

        settingsWindowController = SettingsWindowController(
            settingsStore: settingsStore,
            usageStatsStore: usageStatsStore,
            onUsageStatsReset: { [weak self] in
                self?.mainWindowController?.reload()
            },
            onUILanguageChange: { [weak self] language in
                self?.mainWindowController?.reload()
                self?.menuBarController?.refreshMenu()
                NSApp.mainMenu = AppMainMenu.make(copy: AppCopy.texts(for: language))
            }
        )
        if let hotwordStore, let historyStore {
            mainWindowController = MainWindowController(
                hotwordStore: hotwordStore,
                historyStore: historyStore,
                usageStatsStore: usageStatsStore,
                settingsStore: settingsStore,
                modelManager: modelManager,
                initialReadinessSnapshot: initialReadinessSnapshot,
                actions: MainWindowActions(
                    openSettings: { [weak self] in
                        self?.settingsWindowController?.show()
                    },
                    showHelp: { [weak self] in
                        self?.showHelpWindow()
                    },
                    copyTranscript: { [weak self] text in
                        Task { @MainActor in
                            self?.copyTranscript(text)
                        }
                    },
                    pasteTranscript: { [weak self] text in
                        Task { @MainActor in
                            await self?.pasteTranscript(text)
                        }
                    },
                    retrySegmentedTranscription: { [weak self] item in
                        await self?.retrySegmentedTranscription(for: item) ?? .failed
                    },
                    clearHistory: { [weak self] in
                        if let retainedRecordingStore = self?.retainedRecordingStore {
                            try retainedRecordingStore.prune(keeping: [])
                        }
                        if let historyStore = self?.historyStore {
                            try historyStore.clear()
                        }
                    },
                    refreshModelStatus: { [weak self] modelID in
                        guard let self else {
                            return QwenModelStatus(
                                installed: false,
                                loaded: false,
                                loading: nil,
                                downloading: nil,
                                progress: nil,
                                modelId: modelID,
                                modelPath: nil
                            )
                        }
                        return try await self.refreshQwenModelStatus(modelID: modelID)
                    },
                    downloadModel: { [weak self] modelID, forceRepair in
                        guard let self else {
                            return QwenModelStatus(
                                installed: false,
                                loaded: false,
                                loading: nil,
                                downloading: nil,
                                progress: nil,
                                modelId: modelID,
                                modelPath: nil
                            )
                        }
                        return try await self.prepareModelThroughLifecycle(
                            modelID: modelID,
                            forceRepair: forceRepair
                        )
                    },
                    refreshReadiness: { [weak self] in
                        guard let self else {
                            return ReadinessReport(generatedAt: Date(), checks: [])
                        }
                        return await MainActor.run {
                            self.lightweightReadinessReport()
                        }
                    },
                    refreshReadinessLive: { [weak self] in
                        guard let self else {
                            return ReadinessReport(generatedAt: Date(), checks: [])
                        }
                        return await self.readinessReportWithHelperStatus()
                    },
                    prepareFlowtype: { [weak self] intent, onUpdate in
                        guard let self else {
                            return ReadinessSetupResult(
                                outcome: .failed("Flowtype setup is unavailable."),
                                report: ReadinessReport(generatedAt: Date(), checks: [])
                            )
                        }
                        return await self.prepareFlowtypeThroughLifecycle(
                            intent: intent,
                            onUpdate: onUpdate
                        )
                    },
                    prepareRuntime: { [weak self] in
                        guard let self else {
                            return ReadinessReport(generatedAt: Date(), checks: [])
                        }
                        try await self.flowtypePreparation.withExclusiveRuntimeMutation {
                            await self.stopHelperAfterQwenFailure()
                            try await Task.detached { [readinessService = self.readinessService] in
                                _ = try readinessService.prepareRuntime()
                            }.value
                        }
                        return await MainActor.run {
                            self.lightweightReadinessReport()
                        }
                    },
                    repairHelper: { [weak self] in
                        guard let self else {
                            return ReadinessReport(generatedAt: Date(), checks: [])
                        }
                        try await self.flowtypePreparation.withExclusiveRuntimeMutation {
                            await self.stopHelperAfterQwenFailure()
                            try await Task.detached { [readinessService = self.readinessService] in
                                _ = try readinessService.repairHelperCopy()
                            }.value
                        }
                        return await MainActor.run {
                            self.lightweightReadinessReport()
                        }
                    },
                    downloadDefaultModel: { [weak self] in
                        guard let self else {
                            return QwenModelStatus(
                                installed: false,
                                loaded: false,
                                loading: nil,
                                downloading: nil,
                                progress: nil,
                                modelId: VoiceInputModel.qwen3ASR06B.modelID,
                                modelPath: nil
                            )
                        }
                        await MainActor.run {
                            self.settingsStore.selectedModelID = VoiceInputModel.qwen3ASR06B.id
                            self.settingsStore.recordModelDownloadConsent(
                                modelID: VoiceInputModel.qwen3ASR06B.modelID,
                                disclosureVersion: ModelDownloadConsent.currentDisclosureVersion
                            )
                        }
                        return try await self.prepareModelThroughLifecycle(
                            modelID: VoiceInputModel.qwen3ASR06B.modelID
                        )
                    },
                    warmSelectedModel: { [weak self] in
                        guard let self else {
                            return QwenModelStatus(
                                installed: false,
                                loaded: false,
                                loading: nil,
                                downloading: nil,
                                progress: nil,
                                modelId: "",
                                modelPath: nil
                            )
                        }
                        return try await self.prepareSelectedModelThroughLifecycle()
                    },
                    retrySelectedModelPreload: { [weak self] in
                        guard let self else {
                            return QwenModelStatus(
                                installed: false,
                                loaded: false,
                                loading: nil,
                                downloading: nil,
                                progress: nil,
                                modelId: "",
                                modelPath: nil
                            )
                        }
                        return try await self.prepareSelectedModelThroughLifecycle()
                    },
                    openReadinessLocation: { [weak self] target in
                        Task { @MainActor in
                            self?.openReadinessLocation(target)
                        }
                    },
                    generateDiagnosticsFile: { [weak self] report in
                        guard let self else {
                            let writer = DiagnosticsFileWriter()
                            return try await writer.generate(report: report)
                        }
                        AppLogger.diagnostics.info("diagnostics_generate_started")
                        let writer = DiagnosticsFileWriter(
                            applicationSupportRoot: self.modelManager.applicationSupportRoot
                        )
                        do {
                            let result = try await writer.generate(report: report)
                            AppLogger.diagnostics.info("diagnostics_latest_written file=\(result.latestURL.lastPathComponent, privacy: .public)")
                            AppLogger.diagnostics.info("diagnostics_timestamped_written file=\(result.timestampedFileName, privacy: .public)")
                            return result
                        } catch {
                            AppLogger.diagnostics.error("diagnostics_generate_failed error=\(error.localizedDescription, privacy: .private)")
                            throw error
                        }
                    },
                    revealDiagnosticsFile: { url in
                        Task { @MainActor in
                            AppLogger.diagnostics.info("diagnostics_reveal_requested file=\(url.lastPathComponent, privacy: .public)")
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    },
                    copyDiagnostics: { [weak self] report in
                        guard let self else { return "" }
                        AppLogger.diagnostics.info("diagnostics_generate_started")
                        let writer = DiagnosticsFileWriter(
                            applicationSupportRoot: self.modelManager.applicationSupportRoot
                        )
                        let result: DiagnosticsFileResult
                        do {
                            result = try await writer.generate(report: report)
                            AppLogger.diagnostics.info("diagnostics_latest_written file=\(result.latestURL.lastPathComponent, privacy: .public)")
                            AppLogger.diagnostics.info("diagnostics_timestamped_written file=\(result.timestampedFileName, privacy: .public)")
                        } catch {
                            AppLogger.diagnostics.error("diagnostics_generate_failed error=\(error.localizedDescription, privacy: .private)")
                            throw error
                        }
                        let copied = await MainActor.run {
                            self.pasteInjector.copyPermanent(result.text)
                        }
                        guard copied else {
                            AppLogger.diagnostics.error("diagnostics_copy_failed file=\(result.timestampedFileName, privacy: .public)")
                            throw DiagnosticsCopyError.pasteboardWriteFailed(result.latestURL)
                        }
                        return result.text
                    },
                    saveDiagnosticsSnapshot: { [weak self] report in
                        guard let self else { return }
                        AppLogger.diagnostics.info("diagnostics_snapshot_started")
                        let writer = DiagnosticsFileWriter(
                            applicationSupportRoot: self.modelManager.applicationSupportRoot
                        )
                        do {
                            let result = try await writer.generate(report: report)
                            AppLogger.diagnostics.info("diagnostics_snapshot_written file=\(result.timestampedFileName, privacy: .public)")
                        } catch {
                            AppLogger.diagnostics.error("diagnostics_snapshot_save_failed error=\(error.localizedDescription, privacy: .private)")
                        }
                    },
                    requestMicrophone: { [weak self] in
                        Task { @MainActor in
                            self?.permissionManager.requestMicrophone { _ in }
                        }
                    },
                    openAccessibilitySettings: { [weak self] in
                        Task { @MainActor in
                            self?.permissionManager.openAccessibilitySettings()
                        }
                    },
                    requestSpeechRecognition: { [weak self] in
                        Task { @MainActor in
                            self?.permissionManager.requestSpeechRecognition { _ in }
                        }
                    }
                )
            )
        }
        menuBarController = MenuBarController(
            settingsStore: settingsStore,
            onOpenHome: { [weak self] in
                self?.showMainWindow(section: .home)
            },
            onOpenDictionary: { [weak self] in
                self?.showMainWindow(section: .dictionary)
            },
            onOpenModels: { [weak self] in
                self?.showMainWindow(section: .models)
            },
            onOpenPreferences: { [weak self] in
                self?.showMainWindow(section: .preferences)
            },
            onOpenSettings: { [weak self] in
                self?.settingsWindowController?.show()
            },
            onShowHelp: { [weak self] in
                self?.showHelpWindow()
            },
            onOpenSetupStatus: { [weak self] in
                self?.showMainWindow(section: .readiness)
            },
            onShowOnboarding: { [weak self] in
                self?.showOnboardingWindow()
            },
            onPasteLastTranscript: { [weak self] in
                Task { @MainActor in
                    await self?.pasteLastTranscript()
                }
            }
        )
        menuBarController?.install()
        selectedModelObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.selectedModelDidChangeNotification,
            object: settingsStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.publishCurrentReadinessSnapshot()
                self?.menuBarController?.refreshMenu()
                self?.startBackgroundPreparation(reason: "selected-model-change")
            }
        }
        engineObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.engineDidChangeNotification,
            object: settingsStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleEngineChange()
            }
        }
        observeFrontmostApplicationChanges()

        fnKeyMonitor.onPress = { [weak self] in
            Task { @MainActor in
                self?.startRecordingPreview()
            }
        }
        fnKeyMonitor.onRelease = { [weak self] in
            Task { @MainActor in
                self?.stopRecordingPreview()
            }
        }
        fnKeyMonitor.start()

        if settingsStore.hasCompletedOnboarding {
            routeInitialWindowAfterReadinessCheck(snapshot: initialReadinessSnapshot)
        } else {
            showOnboardingWindow()
        }
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        recordingTimeoutWorkItem?.cancel()
        cancelRecordingWarningWorkItems()
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
        if let selectedModelObserver {
            NotificationCenter.default.removeObserver(selectedModelObserver)
        }
        if let engineObserver {
            NotificationCenter.default.removeObserver(engineObserver)
        }
        fnKeyMonitor.stop()
        recorder.stop()
        helperProcessManager.stop()
        menuBarController?.uninstall()
    }

    @MainActor
    func applicationDidBecomeActive(_ notification: Notification) {
        guard permissionManager.snapshot().accessibility == .granted else { return }
        fnKeyMonitor.start()
    }

    @MainActor
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        // While onboarding is on screen it owns the launch experience; a
        // reopen event must not raise the main window over it.
        if let onboardingWindow = onboardingWindowController?.window, onboardingWindow.isVisible {
            onboardingWindow.makeKeyAndOrderFront(nil)
            return true
        }

        // AppKit's flag can include transient panels. Only these two windows represent
        // a user task whose existing front-to-back order should be preserved.
        let action = ApplicationReopenPolicy.action(
            mainWindow: ApplicationWindowVisibility(
                isVisible: mainWindowController?.window?.isVisible == true,
                isMiniaturized: mainWindowController?.window?.isMiniaturized == true
            ),
            settingsWindow: ApplicationWindowVisibility(
                isVisible: settingsWindowController?.window?.isVisible == true,
                isMiniaturized: settingsWindowController?.window?.isMiniaturized == true
            )
        )

        if action == .showMainWindow {
            showMainWindow(section: .home)
        }
        return true
    }

    @MainActor
    private func startRecordingPreview() {
        let startResult = dictationSession.handleStartRequest()
        let sessionID: UUID
        switch startResult {
        case let .started(startedSessionID):
            sessionID = startedSessionID
        case let .ignored(reason, activeSessionID):
            logIgnoredDictationStart(reason: reason, activeSessionID: activeSessionID)
            if reason == .transcriptionInFlight {
                capsule.show(.status("Still transcribing..."))
            }
            return
        }

        recordingPreviewID = sessionID
        isRecordingPreviewActive = false
        recordingTargetApplication = pasteTargetApplication()
        cancelRecordingTimers()

        guard permissionManager.snapshot().microphone == .granted else {
            if dictationSession.abortRecordingStart(session: sessionID) {
                clearRecordingTargetIfCurrent(session: sessionID)
            }
            currentRecordingURL = nil
            capsule.show(.failure("Microphone permission required"))
            scheduleCapsuleHide(after: 1.0, previewID: recordingPreviewID)
            return
        }

        do {
            recorder.onRMS = { [weak self] rms in
                Task { @MainActor in
                    guard let self else { return }
                    self.capsule.updateAudioLevel(self.meter.normalizedLevel(forRMS: rms))
                }
            }
            currentRecordingURL = try startRecorderWithSelectedMicrophone()
            recordingStartedAt = Date()
            isRecordingPreviewActive = true
            capsule.show(.listening())
            scheduleRecordingTimeout(previewID: recordingPreviewID)
        } catch AudioRecorderError.alreadyRecording {
            currentRecordingURL = currentRecordingURL ?? recorder.outputURL
            recordingStartedAt = recordingStartedAt ?? Date()
            isRecordingPreviewActive = true
            capsule.show(.listening())
        } catch {
            if dictationSession.abortRecordingStart(session: sessionID) {
                clearRecordingTargetIfCurrent(session: sessionID)
            }
            currentRecordingURL = nil
            recordingStartedAt = nil
            if permissionManager.snapshot().microphone == .granted {
                capsule.show(.failure("Recording unavailable"))
            } else {
                capsule.show(.failure("Microphone permission required"))
            }
        }
    }

    @MainActor
    private func stopRecordingPreview() {
        let stopResult = dictationSession.handleStopRequest()
        let previewID: UUID
        switch stopResult {
        case let .startedTranscribing(sessionID):
            previewID = sessionID
        case let .ignored(reason, activeSessionID):
            logIgnoredDictationRelease(reason: reason, activeSessionID: activeSessionID)
            return
        }

        cancelRecordingTimers()
        guard isRecordingPreviewActive else {
            recordingStartedAt = nil
            _ = dictationSession.handleFailure(session: previewID)
            capsule.update(.failure("Transcription failed"))
            scheduleCapsuleHide(after: 1.0, previewID: previewID) { [weak self] in
                self?.finishDictationPresentation(session: previewID)
            }
            return
        }

        isRecordingPreviewActive = false
        let recordingDuration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartedAt = nil
        recorder.stop()
        capsule.update(.transcribing("Transcribing..."))

        guard let recordingURL = currentRecordingURL else {
            _ = dictationSession.handleFailure(session: previewID)
            capsule.update(.failure("Transcription failed"))
            scheduleCapsuleHide(after: 1.0, previewID: previewID) { [weak self] in
                self?.finishDictationPresentation(session: previewID)
            }
            return
        }
        currentRecordingURL = nil

        let selectedEngine = settingsStore.engine
        Task { @MainActor in
            defer { self.deleteTemporaryRecording(at: recordingURL) }
            do {
                let result = try await transcribe(
                    url: recordingURL,
                    previewID: previewID,
                    selectedEngine: selectedEngine
                )
                self.captureDebugRecordingIfNeeded(
                    at: recordingURL,
                    recordingDuration: recordingDuration,
                    result: result,
                    error: nil
                )
                switch self.dictationSession.handleSuccess(session: previewID) {
                case let .presentResult(session, shouldCommit):
                    guard shouldCommit else { return }
                    AppLogger.asr.info("dictation_commit_success session=\(session.uuidString, privacy: .public) engine=\(result.engine.rawValue, privacy: .public)")
                case let .ignored(reason, session):
                    AppLogger.asr.error("dictation_stale_result session=\(session.uuidString, privacy: .public) reason=\(reason.diagnosticName, privacy: .public) state=\(self.dictationSession.state.diagnosticName, privacy: .public)")
                    return
                case .presentFailure:
                    return
                }
                self.lastTranscript = result.text
                if let usageStatsStore = self.usageStatsStore {
                    do {
                        _ = try usageStatsStore.recordSuccessfulDictation(
                            text: result.text,
                            recordingDuration: recordingDuration
                        )
                        self.mainWindowController?.reload()
                    } catch {
                        // Keep dictation flow uninterrupted if local usage stats cannot be written.
                    }
                }
                if self.settingsStore.isHistoryEnabled,
                   let historyStore = self.historyStore {
                    do {
                        let historyID = UUID()
                        let recordingFileName = self.saveRetainedRecordingIfPossible(
                            at: recordingURL,
                            historyID: historyID
                        )
                        let forcedIssue = self.settingsStore.forceNextTranscriptionIssue
                        if forcedIssue {
                            self.settingsStore.forceNextTranscriptionIssue = false
                        }
                        let detectedIssue = forcedIssue
                            ? TranscriptHistoryIssue.possibleTruncation
                            : TranscriptionIssueDetector.issue(
                                for: result.text,
                                recordingDuration: recordingDuration
                            )
                        _ = try historyStore.add(
                            id: historyID,
                            text: result.text,
                            engine: result.engine,
                            selectedEngine: result.selectedEngine == result.engine ? nil : result.selectedEngine,
                            languageMode: self.settingsStore.languageMode,
                            targetAppName: self.recordingTargetApplication?.localizedName,
                            recordingFileName: recordingFileName,
                            recordingDuration: recordingDuration,
                            transcriptionIssue: recordingFileName == nil ? nil : detectedIssue
                        )
                        self.pruneRetainedRecordings()
                        self.mainWindowController?.reload()
                    } catch {
                        // Keep dictation flow uninterrupted if local history cannot be written.
                    }
                }
                self.capsule.update(.result(result.text))
                self.capsule.hide()
                self.pasteAfterOverlayDismiss(result.text, previewID: previewID) { [weak self] in
                    self?.finishDictationPresentation(session: previewID)
                }
            } catch TranscriptionFlowError.speechPermissionRequired {
                self.captureDebugRecordingIfNeeded(
                    at: recordingURL,
                    recordingDuration: recordingDuration,
                    result: nil,
                    error: TranscriptionFlowError.speechPermissionRequired
                )
                guard self.markDictationFailureForPresentation(previewID: previewID) else { return }
                self.requestSpeechPermissionIfNeeded(previewID: previewID)
            } catch {
                self.captureDebugRecordingIfNeeded(
                    at: recordingURL,
                    recordingDuration: recordingDuration,
                    result: nil,
                    error: error
                )
                guard self.markDictationFailureForPresentation(previewID: previewID) else { return }
                let savedRecoverableAttempt = self.saveRecoverableFailedAttemptIfPossible(
                    recordingURL: recordingURL,
                    recordingDuration: recordingDuration,
                    selectedEngine: selectedEngine,
                    error: error
                )
                let copy = AppCopy.texts(for: self.settingsStore.uiLanguage)
                self.capsule.update(.failure(
                    savedRecoverableAttempt
                        ? copy.capsuleRecoverableTranscriptionFailed
                        : Self.transcriptionFailureText(for: error)
                ))
                self.scheduleCapsuleHide(after: 1.0, previewID: previewID) { [weak self] in
                    self?.finishDictationPresentation(session: previewID)
                }
            }
        }
    }

    @MainActor
    private func logIgnoredDictationStart(
        reason: DictationSessionController.IgnoreReason,
        activeSessionID: UUID?
    ) {
        AppLogger.asr.info("dictation_start_ignored state=\(self.dictationSession.state.diagnosticName, privacy: .public) reason=\(reason.diagnosticName, privacy: .public) active_session=\(activeSessionID?.uuidString ?? "none", privacy: .public)")
    }

    @MainActor
    private func logIgnoredDictationRelease(
        reason: DictationSessionController.IgnoreReason,
        activeSessionID: UUID?
    ) {
        AppLogger.asr.info("dictation_release_ignored state=\(self.dictationSession.state.diagnosticName, privacy: .public) reason=\(reason.diagnosticName, privacy: .public) active_session=\(activeSessionID?.uuidString ?? "none", privacy: .public)")
    }

    @MainActor
    private func markDictationFailureForPresentation(previewID: UUID) -> Bool {
        switch dictationSession.handleFailure(session: previewID) {
        case let .presentFailure(session):
            AppLogger.asr.error("dictation_commit_failure session=\(session.uuidString, privacy: .public) state=\(self.dictationSession.state.diagnosticName, privacy: .public)")
            return true
        case let .ignored(reason, session):
            AppLogger.asr.error("dictation_stale_failure session=\(session.uuidString, privacy: .public) reason=\(reason.diagnosticName, privacy: .public) state=\(self.dictationSession.state.diagnosticName, privacy: .public)")
            return false
        case .presentResult:
            return false
        }
    }

    private func startRecorderWithSelectedMicrophone() throws -> URL {
        do {
            return try recorder.start(inputDeviceUID: settingsStore.selectedMicrophoneUID)
        } catch AudioRecorderError.inputDeviceUnavailable where settingsStore.selectedMicrophoneUID != nil {
            return try recorder.start()
        }
    }

    private func deleteTemporaryRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        } catch {
            return
        }
    }

    private func captureDebugRecordingIfNeeded(
        at url: URL,
        recordingDuration: TimeInterval,
        result: TranscriptionResult?,
        error: Error?
    ) {
        guard settingsStore.isDebugRecordingCaptureEnabled else { return }

        let audioFileSize = UInt64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let metadata = DebugRecordingMetadata(
            createdAt: Date(),
            recordingDuration: recordingDuration,
            audioFileSize: audioFileSize,
            engine: result?.engine ?? settingsStore.engine,
            selectedEngine: result?.selectedEngine ?? settingsStore.engine,
            languageMode: settingsStore.languageMode,
            modelID: settingsStore.engine == .qwenLocal ? selectedModel.id : nil,
            processedTranscript: result?.text,
            errorDescription: error.map(Self.debugDescription)
        )

        do {
            try DebugRecordingStore.defaultStore().saveLastRecording(sourceURL: url, metadata: metadata)
        } catch {
            AppLogger.app.error("Unable to save debug recording: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    @discardableResult
    private func saveRecoverableFailedAttemptIfPossible(
        recordingURL: URL,
        recordingDuration: TimeInterval,
        selectedEngine: TranscriptionEngineKind,
        error: Error
    ) -> Bool {
        guard
            let category = TranscriptionFailureClassifier.recoverableHomeRowCategory(
                for: error,
                selectedEngine: selectedEngine
            ),
            settingsStore.isHistoryEnabled,
            historyStore != nil,
            retainedRecordingStore != nil
        else {
            return false
        }

        let historyID = UUID()
        guard let recordingFileName = saveRetainedRecordingIfPossible(at: recordingURL, historyID: historyID) else {
            return false
        }

        do {
            try historyStore?.addFailedAttempt(
                id: historyID,
                engine: selectedEngine,
                languageMode: settingsStore.languageMode,
                targetAppName: recordingTargetApplication?.localizedName,
                recordingFileName: recordingFileName,
                recordingDuration: recordingDuration,
                failureCategory: category
            )
            pruneRetainedRecordings()
            mainWindowController?.reload()
            return true
        } catch {
            deleteRetainedRecordingIfPossible(fileName: recordingFileName)
            AppLogger.app.error("Unable to save failed attempt: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func deleteRetainedRecordingIfPossible(fileName: String) {
        guard let retainedRecordingStore else { return }
        do {
            try FileManager.default.removeItem(at: retainedRecordingStore.recordingURL(fileName: fileName))
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        } catch {
            AppLogger.app.error("Unable to delete retained recording after failed attempt save failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func saveRetainedRecordingIfPossible(at url: URL, historyID: UUID) -> String? {
        guard let retainedRecordingStore else { return nil }
        do {
            return try retainedRecordingStore.saveRecording(sourceURL: url, id: historyID)
        } catch {
            AppLogger.app.error("Unable to retain recording for retry: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func pruneRetainedRecordings() {
        guard
            let retainedRecordingStore,
            let historyStore,
            let items = try? historyStore.load()
        else {
            return
        }

        let retainedFileNames = Array(items.compactMap { item -> String? in
            guard
                item.failureCategory != .expiredRecording,
                let fileName = item.recordingFileName
            else {
                return nil
            }
            return FileManager.default.fileExists(
                atPath: retainedRecordingStore.recordingURL(fileName: fileName).path
            ) ? fileName : nil
        }.prefix(RetainedRecordingStore.retainedRecordingLimit))
        do {
            try retainedRecordingStore.prune(keeping: retainedFileNames)
            expireHistoryItemsWithoutRetainedAudio()
        } catch {
            AppLogger.app.error("Unable to prune retained recordings: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func expireHistoryItemsWithoutRetainedAudio() {
        guard
            let retainedRecordingStore,
            let historyStore,
            let items = try? historyStore.load()
        else {
            return
        }

        for item in items {
            guard
                item.failureCategory != .expiredRecording,
                let fileName = item.recordingFileName
            else {
                continue
            }
            let url = retainedRecordingStore.recordingURL(fileName: fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? historyStore.markRecordingExpired(id: item.id)
            }
        }
    }

    @MainActor
    private func transcribe(
        url: URL,
        previewID: UUID,
        strategy: QwenTranscriptionStrategy = .full,
        selectedEngine: TranscriptionEngineKind? = nil,
        preparedConfiguration: PreparationConfiguration? = nil
    ) async throws -> TranscriptionResult {
        switch selectedEngine ?? settingsStore.engine {
        case .qwenLocal:
            if preparedConfiguration == nil {
                if recordingPreviewID == previewID {
                    capsule.update(.transcribing("Preparing Qwen..."))
                }
                let configuration = currentPreparationConfiguration()
                helperStopRequestedAfterTranscription = false
                do {
                    let result = try await flowtypePreparation.withPreparedRuntime(for: configuration) { [weak self] runtime in
                        guard let self else { throw PreparationFailure.superseded }
                        return try await self.transcribe(
                            url: url,
                            previewID: previewID,
                            strategy: strategy,
                            selectedEngine: .qwenLocal,
                            preparedConfiguration: runtime.configuration
                        )
                    }
                    await performDeferredHelperStopIfNeeded()
                    return result
                } catch {
                    await performDeferredHelperStopIfNeeded()
                    throw error
                }
            }
            guard let preparedConfiguration,
                  let preparedModelID = preparedConfiguration.modelID,
                  let runModel = VoiceInputModel.all.first(where: { $0.modelID == preparedModelID })
            else {
                throw PreparationFailure.finalVerificationFailed
            }
            let runSelectedModelID = runModel.id
            var modelStatusBefore: QwenModelStatus?
            var qwenStartedAt: Date?
            var qwenFinishedAt: Date?
            let totalStartedAt = Date()
            var helperStartMilliseconds = 0
            var statusProbeMilliseconds = 0
            var decodeMilliseconds = 0
            do {
                let helperStartedAt = Date()
                let endpoint = try await startHelperIfNeeded()
                helperStartMilliseconds = milliseconds(since: helperStartedAt)
                let client = QwenHelperClient(baseURL: endpoint.baseURL, authToken: endpoint.authToken)

                if recordingPreviewID == previewID {
                    capsule.update(.transcribing("Preparing Qwen..."))
                }
                modelStatusBefore = try? await client.modelStatus(modelID: runModel.modelID)
                if let status = modelStatusBefore,
                   status.installed,
                   !status.loaded,
                   status.loading != true,
                   status.downloading != true {
                    _ = try? await client.downloadModel(modelID: runModel.modelID)
                }
                let readinessGate = QwenModelReadinessGate(statusProvider: client)
                let gateResult = try await readinessGate.waitForReady(
                    model: runModel,
                    budget: qwenModelLoadBudget(for: runModel)
                )
                statusProbeMilliseconds = gateResult.waitedMilliseconds
                if let failureKind = gateResult.failureKind {
                    throw QwenReadinessError(kind: failureKind)
                }
                if recordingPreviewID == previewID {
                    capsule.update(.transcribing("Transcribing with Qwen..."))
                }

                let hotwords = (try? hotwordStore?.enabledHotwords()) ?? []
                let context = TranscriptionContextBuilder.context(for: hotwords)
                qwenStartedAt = Date()
                let result = try await QwenTranscriptionEngine(
                    client: client,
                    modelID: runModel.modelID,
                    context: context,
                    strategy: strategy,
                    onDecodeTiming: { milliseconds in
                        decodeMilliseconds = milliseconds
                    }
                ).transcribe(
                    fileURL: url,
                    languageMode: settingsStore.languageMode
                )
                qwenFinishedAt = Date()
                try? ModelManager(model: runModel, applicationSupportRoot: modelManager.applicationSupportRoot).markInstalled()
                let postStartedAt = Date()
                let processed = await postProcessedOffMainActor(result)
                let postProcessingMilliseconds = milliseconds(since: postStartedAt)
                let totalMilliseconds = milliseconds(since: totalStartedAt)
                let timingSample = TranscriptionTimingSample(
                    createdAt: Date(),
                    modelID: runModel.modelID,
                    requestedStrategy: processed.requestedStrategy ?? strategy.rawValue,
                    effectiveStrategy: processed.effectiveStrategy ?? processed.requestedStrategy ?? strategy.rawValue,
                    recordingDurationSeconds: QwenContextEchoDetector.recordingDuration(fileURL: url),
                    helperStartMilliseconds: helperStartMilliseconds,
                    modelPreparationMilliseconds: statusProbeMilliseconds,
                    decodeMilliseconds: decodeMilliseconds,
                    postProcessingMilliseconds: postProcessingMilliseconds,
                    totalMilliseconds: totalMilliseconds
                )
                await saveTranscriptionTiming(timingSample, previewID: previewID)
                await appendTranscriptionProvenance(
                    TranscriptionProvenance(
                        recordingID: previewID,
                        createdAt: Date(),
                        selectedEngine: processed.selectedEngine,
                        winnerEngine: processed.engine,
                        selectedModelID: runSelectedModelID,
                        modelStatusBefore: modelStatusBefore.map(QwenModelStatusSnapshot.init(status:)),
                        requestedModelID: processed.requestedModelID,
                        activeLoadedModelIDBefore: modelStatusBefore?.loaded == true ? modelStatusBefore?.modelId : nil,
                        activeLoadedModelIDAfter: processed.requestedModelID,
                        helperPortKnown: true,
                        requestedStrategy: processed.requestedStrategy,
                        effectiveStrategy: processed.effectiveStrategy,
                        recordingDurationSeconds: timingSample.recordingDurationSeconds,
                        qwenStartedAt: qwenStartedAt,
                        qwenFinishedAt: qwenFinishedAt,
                        sessionStateAtCompletion: currentSessionStateForDiagnostics(),
                        commitOutcome: commitOutcomeForDiagnostics(previewID: previewID, currentOutcome: "committed"),
                        ignoredInputReason: ignoredInputReasonForDiagnostics(previewID: previewID),
                        timing: TranscriptionProvenanceTiming(sample: timingSample),
                        capsuleEvents: [
                            CapsuleEvent(at: Date(), text: "Preparing Qwen..."),
                            CapsuleEvent(at: Date(), text: "Transcribing with Qwen...")
                        ]
                    ),
                    previewID: previewID
                )
                AppLogger.performance.info("Qwen timing helper_ms=\(helperStartMilliseconds, privacy: .public) status_probe_ms=\(statusProbeMilliseconds, privacy: .public) decode_ms=\(decodeMilliseconds, privacy: .public) post_ms=\(postProcessingMilliseconds, privacy: .public) total_ms=\(totalMilliseconds, privacy: .public)")
                return processed
            } catch let qwenError {
                let failureKind = QwenFallbackPolicy().classify(qwenError)
                AppLogger.asr.error("Qwen failed with kind=\(failureKind.rawValue, privacy: .public)")
                if shouldStopHelperAfterQwenFailure(failureKind) {
                    helperStopRequestedAfterTranscription = true
                }
                guard QwenFallbackPolicy().shouldFallback(for: failureKind) else {
                    await appendTranscriptionProvenance(
                        TranscriptionProvenance(
                            recordingID: previewID,
                            createdAt: Date(),
                            selectedEngine: .qwenLocal,
                            winnerEngine: nil,
                            selectedModelID: runSelectedModelID,
                            modelStatusBefore: modelStatusBefore.map(QwenModelStatusSnapshot.init(status:)),
                            requestedModelID: runModel.modelID,
                            requestedStrategy: strategy.rawValue,
                            recordingDurationSeconds: QwenContextEchoDetector.recordingDuration(fileURL: url),
                            qwenStartedAt: qwenStartedAt,
                            qwenFinishedAt: qwenFinishedAt,
                            qwenErrorKind: failureKind.rawValue,
                            fallbackReason: failureKind.rawValue,
                            sessionStateAtCompletion: currentSessionStateForDiagnostics(),
                            commitOutcome: commitOutcomeForDiagnostics(previewID: previewID, currentOutcome: "failed"),
                            ignoredInputReason: ignoredInputReasonForDiagnostics(previewID: previewID),
                            capsuleEvents: [CapsuleEvent(at: Date(), text: "Preparing Qwen...")]
                        ),
                        previewID: previewID
                    )
                    throw qwenError
                }

                do {
                    try ensureSpeechPermission()
                } catch {
                    let timingSample = TranscriptionTimingSample(
                        createdAt: Date(),
                        modelID: runModel.modelID,
                        requestedStrategy: strategy.rawValue,
                        effectiveStrategy: "fallbackBlockedBySpeechPermission",
                        recordingDurationSeconds: QwenContextEchoDetector.recordingDuration(fileURL: url),
                        helperStartMilliseconds: helperStartMilliseconds,
                        modelPreparationMilliseconds: statusProbeMilliseconds,
                        decodeMilliseconds: decodeMilliseconds,
                        postProcessingMilliseconds: 0,
                        totalMilliseconds: milliseconds(since: totalStartedAt)
                    )
                    await saveTranscriptionTiming(timingSample, previewID: previewID)
                    await appendTranscriptionProvenance(
                        TranscriptionProvenance(
                            recordingID: previewID,
                            createdAt: Date(),
                            selectedEngine: .qwenLocal,
                            winnerEngine: nil,
                            selectedModelID: runSelectedModelID,
                            modelStatusBefore: modelStatusBefore.map(QwenModelStatusSnapshot.init(status:)),
                            requestedModelID: runModel.modelID,
                            requestedStrategy: strategy.rawValue,
                            effectiveStrategy: "fallbackBlockedBySpeechPermission",
                            recordingDurationSeconds: timingSample.recordingDurationSeconds,
                            qwenStartedAt: qwenStartedAt,
                            qwenFinishedAt: qwenFinishedAt,
                            qwenErrorKind: failureKind.rawValue,
                            appleFallbackReason: "fallbackBlockedBySpeechPermission",
                            fallbackReason: "fallbackBlockedBySpeechPermission",
                            sessionStateAtCompletion: currentSessionStateForDiagnostics(),
                            commitOutcome: commitOutcomeForDiagnostics(previewID: previewID, currentOutcome: "fallbackBlocked"),
                            ignoredInputReason: ignoredInputReasonForDiagnostics(previewID: previewID),
                            timing: TranscriptionProvenanceTiming(sample: timingSample),
                            capsuleEvents: [CapsuleEvent(at: Date(), text: "Preparing Qwen...")]
                        ),
                        previewID: previewID
                    )
                    throw error
                }

                let appleFallbackStartedAt = Date()
                if recordingPreviewID == previewID {
                    capsule.update(.transcribing("Using Apple Speech"))
                }
                let result: TranscriptionResult
                do {
                    result = try await AppleSpeechEngine(localeIdentifier: settingsStore.appleSpeechLocaleIdentifier)
                        .transcribe(fileURL: url, languageMode: settingsStore.languageMode)
                } catch let fallbackError {
                    throw TranscriptionFallbackFailure(primaryError: qwenError, fallbackError: fallbackError)
                }
                let fallbackPostStartedAt = Date()
                let processed = postProcessed(
                    TranscriptionResult(
                        text: result.text,
                        engine: .appleSpeech,
                        selectedEngine: .qwenLocal,
                        requestedModelID: runModel.modelID,
                        requestedStrategy: strategy.rawValue,
                        effectiveStrategy: nil,
                        fallbackReason: failureKind.rawValue
                    )
                )
                let timingSample = TranscriptionTimingSample(
                    createdAt: Date(),
                    modelID: runModel.modelID,
                    requestedStrategy: strategy.rawValue,
                    effectiveStrategy: "appleSpeechFallback",
                    recordingDurationSeconds: QwenContextEchoDetector.recordingDuration(fileURL: url),
                    helperStartMilliseconds: helperStartMilliseconds,
                    modelPreparationMilliseconds: statusProbeMilliseconds,
                    decodeMilliseconds: decodeMilliseconds,
                    postProcessingMilliseconds: milliseconds(since: fallbackPostStartedAt),
                    totalMilliseconds: milliseconds(since: totalStartedAt)
                )
                await saveTranscriptionTiming(timingSample, previewID: previewID)
                await appendTranscriptionProvenance(
                    TranscriptionProvenance(
                        recordingID: previewID,
                        createdAt: Date(),
                        selectedEngine: .qwenLocal,
                        winnerEngine: .appleSpeech,
                        selectedModelID: runSelectedModelID,
                        modelStatusBefore: modelStatusBefore.map(QwenModelStatusSnapshot.init(status:)),
                        requestedModelID: runModel.modelID,
                        requestedStrategy: strategy.rawValue,
                        effectiveStrategy: "appleSpeechFallback",
                        recordingDurationSeconds: QwenContextEchoDetector.recordingDuration(fileURL: url),
                        qwenStartedAt: qwenStartedAt,
                        qwenFinishedAt: qwenFinishedAt,
                        qwenErrorKind: failureKind.rawValue,
                        appleFallbackStartedAt: appleFallbackStartedAt,
                        appleFallbackReason: failureKind.rawValue,
                        fallbackReason: failureKind.rawValue,
                        sessionStateAtCompletion: currentSessionStateForDiagnostics(),
                        commitOutcome: commitOutcomeForDiagnostics(previewID: previewID, currentOutcome: "committed"),
                        ignoredInputReason: ignoredInputReasonForDiagnostics(previewID: previewID),
                        timing: TranscriptionProvenanceTiming(sample: timingSample),
                        capsuleEvents: [
                            CapsuleEvent(at: Date(), text: "Preparing Qwen..."),
                            CapsuleEvent(at: Date(), text: "Using Apple Speech")
                        ]
                    ),
                    previewID: previewID
                )
                return processed
            }
        case .appleSpeech:
            try ensureSpeechPermission()
            let result = try await AppleSpeechEngine(localeIdentifier: settingsStore.appleSpeechLocaleIdentifier)
                .transcribe(fileURL: url, languageMode: settingsStore.languageMode)
            let processed = postProcessed(result)
            await appendTranscriptionProvenance(
                TranscriptionProvenance(
                    recordingID: previewID,
                    createdAt: Date(),
                    selectedEngine: .appleSpeech,
                    winnerEngine: .appleSpeech,
                    selectedModelID: nil,
                    recordingDurationSeconds: QwenContextEchoDetector.recordingDuration(fileURL: url),
                    sessionStateAtCompletion: currentSessionStateForDiagnostics(),
                    commitOutcome: commitOutcomeForDiagnostics(previewID: previewID, currentOutcome: "committed"),
                    ignoredInputReason: ignoredInputReasonForDiagnostics(previewID: previewID),
                    capsuleEvents: [CapsuleEvent(at: Date(), text: "Using Apple Speech")]
                ),
                previewID: previewID
            )
            return processed
        }
    }

    @MainActor
    private func retrySegmentedTranscription(for item: TranscriptHistoryItem) async -> SegmentedRetryResult {
        guard
            let recordingFileName = item.recordingFileName,
            let retainedRecordingStore
        else {
            return .failed
        }
        let retryURL = retainedRecordingStore.recordingURL(fileName: recordingFileName)
        guard FileManager.default.fileExists(atPath: retryURL.path) else {
            try? historyStore?.markRecordingExpired(id: item.id)
            mainWindowController?.reload()
            return .expiredRecording
        }

        do {
            let result = try await transcribe(
                url: retryURL,
                previewID: recordingPreviewID,
                strategy: .chunked,
                selectedEngine: item.retryEngine
            )
            let duration = item.recordingDuration
                ?? QwenContextEchoDetector.recordingDuration(fileURL: retryURL)
                ?? 0
            let issue = TranscriptionIssueDetector.issue(
                for: result.text,
                recordingDuration: duration
            )
            try historyStore?.updateTranscript(
                id: item.id,
                text: result.text,
                transcriptionIssue: issue
            )
            lastTranscript = result.text
            copyTranscript(result.text)
            mainWindowController?.reload()
            return .succeeded
        } catch {
            try? historyStore?.markRetryFailed(id: item.id, failureCategory: .transcriptionFailed)
            mainWindowController?.reload()
            AppLogger.app.error("Segmented retry failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    private func startHelperIfNeeded() async throws -> HelperEndpoint {
        try await Task.detached { [helperProcessManager] in
            try helperProcessManager.startIfNeeded()
        }.value
    }

    private func stopHelperAfterQwenFailure() async {
        await Task.detached { [helperProcessManager] in
            helperProcessManager.stop()
        }.value
    }

    @MainActor
    private func performDeferredHelperStopIfNeeded() async {
        guard helperStopRequestedAfterTranscription else { return }
        helperStopRequestedAfterTranscription = false
        try? await flowtypePreparation.withExclusiveRuntimeMutation { [weak self] in
            await self?.stopHelperAfterQwenFailure()
        }
    }

    private func qwenModelLoadBudget(for model: VoiceInputModel) -> TimeInterval {
        model.id == VoiceInputModel.qwen3ASR17B.id ? 60 : 30
    }

    @MainActor
    private func saveTranscriptionTiming(_ sample: TranscriptionTimingSample, previewID: UUID) async {
        let applicationSupportRoot = modelManager.applicationSupportRoot
        await Task.detached {
            try? TranscriptionTimingStore(applicationSupportRoot: applicationSupportRoot).save(sample)
        }.value
    }

    @MainActor
    private func appendTranscriptionProvenance(_ record: TranscriptionProvenance, previewID: UUID) async {
        let applicationSupportRoot = modelManager.applicationSupportRoot
        await Task.detached {
            try? TranscriptionProvenanceStore(applicationSupportRoot: applicationSupportRoot).append(record)
        }.value
    }

    @MainActor
    private func currentSessionStateForDiagnostics() -> String {
        dictationSession.state.diagnosticName
    }

    @MainActor
    private func commitOutcomeForDiagnostics(previewID: UUID, currentOutcome: String) -> String {
        dictationSession.canCommit(session: previewID) ? currentOutcome : "stale"
    }

    @MainActor
    private func ignoredInputReasonForDiagnostics(previewID: UUID) -> String? {
        dictationSession.canCommit(session: previewID) ? nil : DictationSessionController.IgnoreReason.staleSession.diagnosticName
    }

    private func shouldStopHelperAfterQwenFailure(_ kind: QwenFailureKind) -> Bool {
        switch kind {
        case .helperRuntimeMissing, .helperRuntimeDamaged, .helperStartFailed:
            return true
        case .modelNotInstalled,
             .modelLoading,
             .helperBusy,
             .modelLoadTimedOut,
             .helperBusyTimedOut,
             .transcriptionTimedOut,
             .transcriptionFailed,
             .emptyAudio,
             .permissionMissing,
             .cancelled:
            return false
        }
    }

    @MainActor
    private func lightweightReadinessReport(includeSpeechRecognition: Bool? = nil) -> ReadinessReport {
        readinessService.lightweightReport(
            permissionSnapshot: permissionManager.snapshot(),
            selectedModelID: settingsStore.selectedModelID,
            includeSpeechRecognition: includeSpeechRecognition ?? (settingsStore.engine == .appleSpeech)
        )
    }

    @MainActor
    private func routeInitialWindowAfterReadinessCheck(snapshot: ReadinessSnapshot) {
        guard !didRunInitialSetupRoute else { return }
        didRunInitialSetupRoute = true

        let presentation = ReadinessPresentationPolicy.presentation(for: snapshot)
        if !presentation.tasks.isEmpty {
            showMainWindow(section: .readiness)
        } else {
            showMainWindow(section: .home)
            startBackgroundPreparation(reason: "launch")
        }
    }

    @MainActor
    private func currentPreparationConfiguration(
        modelID: String? = nil,
        engineOverride: TranscriptionEngineKind? = nil
    ) -> PreparationConfiguration {
        let engine = engineOverride ?? settingsStore.engine
        let resolvedModelID = engine == .qwenLocal
            ? (modelID ?? selectedModel.modelID)
            : nil
        let runtimeRevision = preparationRuntimeRevision
        let key = "\(engine.rawValue)|\(resolvedModelID ?? "none")|\(runtimeRevision)"
        if key != lastPreparationConfigurationKey {
            preparationConfigurationGeneration += 1
            lastPreparationConfigurationKey = key
        }
        return PreparationConfiguration(
            engine: engine,
            modelID: resolvedModelID,
            runtimeRevision: runtimeRevision,
            generation: preparationConfigurationGeneration
        )
    }

    private var preparationRuntimeRevision: String {
        if let resourceURL = Bundle.main.resourceURL,
           let manifest = try? AppBundleManifest.read(from: resourceURL) {
            return manifest.authoringContractSHA256
        }
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "development"
    }

    @MainActor
    private func startBackgroundPreparation(reason: String) {
        guard settingsStore.engine == .qwenLocal else { return }
        let configuration = currentPreparationConfiguration()
        let manager = ModelManager(
            model: VoiceInputModel.model(for: settingsStore.selectedModelID),
            applicationSupportRoot: modelManager.applicationSupportRoot
        )
        guard manager.isModelInstalled || settingsStore.modelDownloadConsent(for: configuration.modelID ?? "") != nil else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let session = await self.flowtypePreparation.begin(
                PreparationRequest(intent: .backgroundWarmup, configuration: configuration)
            )
            let result = await session.result.value
            if result.isReady {
                AppLogger.readiness.info("Flowtype preparation completed after \(reason, privacy: .public)")
            } else {
                AppLogger.readiness.error("Flowtype preparation did not reach Ready after \(reason, privacy: .public)")
            }
        }
    }

    @MainActor
    private func handleEngineChange() {
        publishCurrentReadinessSnapshot()
        if settingsStore.engine == .qwenLocal {
            startBackgroundPreparation(reason: "engine-change")
            return
        }

        let configuration = currentPreparationConfiguration()
        Task { [weak self] in
            guard let self else { return }
            let session = await self.flowtypePreparation.begin(
                PreparationRequest(intent: .backgroundWarmup, configuration: configuration)
            )
            _ = await session.result.value
            try? await self.flowtypePreparation.withExclusiveRuntimeMutation {
                await self.stopHelperAfterQwenFailure()
            }
        }
    }

    private func prepareFlowtypeThroughLifecycle(
        intent: PreparationIntent,
        onUpdate: @escaping (PreparationSnapshot) -> Void
    ) async -> ReadinessSetupResult {
        let configuration = await MainActor.run { currentPreparationConfiguration() }
        let session = await flowtypePreparation.begin(
            PreparationRequest(intent: intent, configuration: configuration)
        )
        let updateTask = Task {
            for await update in session.updates {
                await MainActor.run { onUpdate(update) }
            }
        }
        let result = await session.result.value
        _ = await updateTask.result
        let outcome: ReadinessSetupResult.Outcome
        switch result.outcome {
        case .ready:
            outcome = .prepared
        case let .awaitingUserAction(action):
            switch action {
            case .modelDownloadConsent:
                outcome = .waitingForModelDownloadConsent
            case .microphone, .accessibility, .speechRecognition:
                outcome = .waitingForPermissions
            }
        case .blocked:
            outcome = .blockedByAppBundle
        case let .failed(failure):
            outcome = .failed(failure.localizedDescription)
        }
        return ReadinessSetupResult(outcome: outcome, report: result.report)
    }

    private func prepareSelectedModelThroughLifecycle() async throws -> QwenModelStatus {
        let configuration = await MainActor.run { currentPreparationConfiguration() }
        let session = await flowtypePreparation.begin(
            PreparationRequest(intent: .backgroundWarmup, configuration: configuration)
        )
        let result = await session.result.value
        guard result.isReady, let modelID = configuration.modelID else {
            throw PreparationFailure.finalVerificationFailed
        }
        return try await refreshQwenModelStatus(modelID: modelID)
    }

    private func prepareModelThroughLifecycle(
        modelID: String,
        forceRepair: Bool = false
    ) async throws -> QwenModelStatus {
        await MainActor.run {
            settingsStore.recordModelDownloadConsent(
                modelID: modelID,
                disclosureVersion: ModelDownloadConsent.currentDisclosureVersion
            )
        }
        let configuration = await MainActor.run {
            currentPreparationConfiguration(modelID: modelID, engineOverride: .qwenLocal)
        }
        let session = await flowtypePreparation.begin(
            PreparationRequest(
                intent: .backgroundWarmup,
                configuration: configuration,
                forceModelRepair: forceRepair
            )
        )
        let result = await session.result.value
        guard result.isReady else {
            throw PreparationFailure.finalVerificationFailed
        }
        return try await refreshQwenModelStatus(modelID: modelID)
    }

    private func readinessReportWithHelperStatus() async -> ReadinessReport {
        let context = await MainActor.run {
            (
                permissionSnapshot: permissionManager.snapshot(),
                selectedModelID: settingsStore.selectedModelID,
                includeSpeechRecognition: settingsStore.engine == .appleSpeech
            )
        }
        if context.includeSpeechRecognition {
            return readinessService.lightweightReport(
                permissionSnapshot: context.permissionSnapshot,
                selectedModelID: context.selectedModelID,
                includeSpeechRecognition: true
            )
        }
        return await readinessService.reportWithHelperModelStatus(
            permissionSnapshot: context.permissionSnapshot,
            selectedModelID: context.selectedModelID,
            includeSpeechRecognition: context.includeSpeechRecognition
        )
    }

    @MainActor
    private func currentReadinessContext() -> ReadinessContext {
        ReadinessContext(
            engine: settingsStore.engine,
            selectedModelID: settingsStore.selectedModelID
        )
    }

    @MainActor
    private func makeLightweightReadinessSnapshot() -> ReadinessSnapshot {
        ReadinessSnapshot(
            report: lightweightReadinessReport(),
            context: currentReadinessContext(),
            coverage: .lightweight
        )
    }

    @MainActor
    private func publishCurrentReadinessSnapshot() {
        mainWindowController?.replaceReadinessSnapshot(makeLightweightReadinessSnapshot())
    }

    private func refreshQwenModelStatus(modelID: String) async throws -> QwenModelStatus {
        if let endpoint = await Task.detached(operation: { [helperProcessManager] in
            helperProcessManager.runningEndpoint()
        }).value {
            let client = QwenHelperClient(baseURL: endpoint.baseURL, authToken: endpoint.authToken)
            return try await client.modelStatus(modelID: modelID)
        }
        let model = VoiceInputModel.all.first(where: { $0.modelID == modelID }) ?? .qwen3ASR06B
        let installed = ModelManager(
            model: model,
            applicationSupportRoot: modelManager.applicationSupportRoot
        ).isModelInstalled
        return QwenModelStatus(
            installed: installed,
            loaded: false,
            loading: false,
            downloading: false,
            progress: installed ? 1 : nil,
            modelId: modelID,
            modelPath: nil,
            phase: installed ? .installed : .absent
        )
    }

    private static func notInstalledQwenStatus(for model: VoiceInputModel) -> QwenModelStatus {
        QwenModelStatus(
            installed: false,
            loaded: false,
            loading: nil,
            downloading: nil,
            progress: nil,
            modelId: model.modelID,
            modelPath: nil
        )
    }

    @MainActor
    private func confirmModelDownloadOnMainActor(modelID: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)
        let model = VoiceInputModel.all.first(where: { $0.modelID == modelID }) ?? .qwen3ASR06B
        let alert = NSAlert()
        alert.messageText = copy.readinessDefaultModelConsentTitle
        if model == .qwen3ASR06B {
            alert.informativeText = copy.readinessDefaultModelConsentMessage
        } else if settingsStore.uiLanguage == .chinese {
            alert.informativeText = "Flowtype 需要下载并准备 \(model.displayName)，才能使用本地离线听写。是否现在继续？"
        } else {
            alert.informativeText = "Flowtype needs to download and prepare \(model.displayName) for local offline dictation. Continue now?"
        }
        alert.alertStyle = .informational
        alert.addButton(
            withTitle: model == .qwen3ASR06B
                ? copy.readinessDownloadDefaultModelTitle
                : copy.modelDownloadTitle
        )
        alert.addButton(withTitle: copy.cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }

    @MainActor
    private func openReadinessLocation(_ target: ReadinessLocationTarget) {
        if target == .diagnostics {
            AppLogger.diagnostics.info("diagnostics_folder_open_requested")
        }
        let resolver = ReadinessLocationResolver(
            bundleURL: Bundle.main.bundleURL,
            resourceURL: Bundle.main.resourceURL,
            applicationSupportRoot: modelManager.applicationSupportRoot,
            selectedModel: selectedModel
        )
        let targetURL = resolver.url(for: target)
        let openURL = resolver.nearestExistingURL(for: targetURL)
        NSWorkspace.shared.open(openURL)
    }

    @MainActor
    private func observeFrontmostApplicationChanges() {
        if let currentApplication = pasteTargetApplication() {
            lastExternalApplication = currentApplication
        }

        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let ownProcessIdentifier = NSRunningApplication.current.processIdentifier
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  PasteTargetPolicy.isUsableExternalTarget(
                    application,
                    ownBundleIdentifier: ownBundleIdentifier,
                    ownProcessIdentifier: ownProcessIdentifier
                  ) else {
                return
            }
            Task { @MainActor [weak self] in
                self?.lastExternalApplication = application
            }
        }
    }

    @MainActor
    private func currentExternalApplication() -> NSRunningApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              !isVoiceInput(application) else {
            return nil
        }
        return application
    }

    private func isVoiceInput(_ application: NSRunningApplication) -> Bool {
        application.bundleIdentifier == Bundle.main.bundleIdentifier ||
            application.processIdentifier == NSRunningApplication.current.processIdentifier
    }

    @MainActor
    private func pasteTargetApplication() -> NSRunningApplication? {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let ownProcessIdentifier = NSRunningApplication.current.processIdentifier
        return [currentExternalApplication(), lastExternalApplication].compactMap { $0 }.first {
            PasteTargetPolicy.isUsableExternalTarget(
                $0,
                ownBundleIdentifier: ownBundleIdentifier,
                ownProcessIdentifier: ownProcessIdentifier
            )
        }
    }

    @MainActor
    private func pasteLastTranscript() async {
        let previewID = UUID()
        recordingPreviewID = previewID

        guard let text = lastTranscript, PasteInjector.isPasteable(text) else {
            capsule.show(.status(AppCopy.texts(for: settingsStore.uiLanguage).noTranscriptYet))
            scheduleCapsuleHide(after: 0.9, previewID: previewID)
            return
        }

        let attempt = PasteAttempt(
            id: previewID,
            source: .menuLastTranscript,
            text: text,
            target: pasteTargetApplication().map(pasteTargetIdentity)
        )
        let outcome = await pasteCoordinator.perform(attempt) { [weak self] target in
            guard let self else { return nil }
            return await self.activateAndValidatePasteTarget(target)
        } validateTarget: { [weak self] target in
            self?.isPasteTargetReadyForDispatch(target) == true
        }
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)
        capsule.show(.status(
            outcome == .eventDispatched
                ? copy.pastedLastTranscript
                : copy.copiedLastTranscript
        ))
        scheduleCapsuleHide(after: 0.9, previewID: previewID)
    }

    @MainActor
    private func showMainWindow(section: MainWindowSection) {
        guard let mainWindowController else {
            showMainWindowUnavailableAlert()
            return
        }
        mainWindowController.show(section: section)
    }

    @MainActor
    private func showMainWindowUnavailableAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)
        let alert = NSAlert()
        alert.messageText = copy.mainWindowUnavailableTitle
        alert.informativeText = copy.mainWindowUnavailableMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: copy.ok)
        alert.runModal()
    }

    @MainActor
    private func showHelpWindow() {
        if helpWindowController == nil {
            helpWindowController = HelpWindowController(settingsStore: settingsStore)
        }
        helpWindowController?.show()
    }

    @MainActor
    @objc func showOnboardingMenuItem(_ sender: Any?) {
        showOnboardingWindow()
    }

    @MainActor
    private func showOnboardingWindow() {
        if onboardingWindowController == nil {
            let controller = OnboardingWindowController(
                settingsStore: settingsStore,
                actions: makeOnboardingActions()
            )
            controller.onClose = { [weak self] in
                Task { @MainActor in
                    self?.handleOnboardingClosed()
                }
            }
            onboardingWindowController = controller
        }
        NSApp.setActivationPolicy(.regular)
        onboardingWindowController?.show()
    }

    /// Closing the onboarding window — finished or skipped — marks onboarding
    /// complete and lands the user in the main window.
    @MainActor
    private func handleOnboardingClosed() {
        settingsStore.hasCompletedOnboarding = true
        if didRunInitialSetupRoute {
            // Reopened from the menu after a normal launch: the initial route
            // already ran, so route explicitly (this also restores a sane
            // activation policy instead of leaving a window-less Dock icon).
            if mainWindowController?.window?.isVisible != true {
                showMainWindow(section: .home)
            }
        } else {
            routeInitialWindowAfterReadinessCheck(snapshot: makeLightweightReadinessSnapshot())
        }
    }

    @MainActor
    private func makeOnboardingActions() -> OnboardingActions {
        OnboardingActions(
            permissionSnapshot: { [weak self] in
                self?.permissionManager.snapshot()
                    ?? PermissionSnapshot(microphone: .unknown, accessibility: .unknown, speechRecognition: .unknown)
            },
            openMicrophoneSettings: {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                NSWorkspace.shared.open(url)
            },
            openAccessibilitySettings: { [weak self] in
                self?.permissionManager.openAccessibilitySettings()
            },
            prepareFlowtype: { [weak self] intent, onUpdate in
                guard let self else {
                    return ReadinessSetupResult(
                        outcome: .failed("Flowtype setup is unavailable."),
                        report: ReadinessReport(generatedAt: Date(), checks: [])
                    )
                }
                // The prepare button copy discloses the model download, so
                // tapping it is the user's consent — record it like the
                // readiness page's default-model action does.
                await MainActor.run {
                    self.settingsStore.recordModelDownloadConsent(
                        modelID: self.selectedModel.modelID,
                        disclosureVersion: ModelDownloadConsent.currentDisclosureVersion
                    )
                }
                return await self.prepareFlowtypeThroughLifecycle(intent: intent, onUpdate: onUpdate)
            }
        )
    }

    @MainActor
    private func copyTranscript(_ text: String) {
        _ = pasteInjector.copyPermanent(text)
    }

    @MainActor
    private func pasteTranscript(_ text: String) async {
        guard PasteInjector.isPasteable(text) else { return }
        let attempt = PasteAttempt(
            id: UUID(),
            source: .history,
            text: text,
            target: pasteTargetApplication().map(pasteTargetIdentity)
        )
        _ = await pasteCoordinator.perform(attempt) { [weak self] target in
            guard let self else { return nil }
            return await self.activateAndValidatePasteTarget(target)
        } validateTarget: { [weak self] target in
            self?.isPasteTargetReadyForDispatch(target) == true
        }
    }

    @MainActor
    private func pasteAfterOverlayDismiss(
        _ text: String,
        previewID: UUID,
        onComplete: (@MainActor () -> Void)? = nil
    ) {
        let target = recordingTargetApplication.map(pasteTargetIdentity)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task { @MainActor in
                guard self.dictationSession.isPresentingResult(session: previewID) else { return }
                let attempt = PasteAttempt(
                    id: previewID,
                    source: .dictation,
                    text: text,
                    target: target
                )
                let outcome = await self.pasteCoordinator.perform(attempt) { [weak self] capturedTarget in
                    guard let self else { return nil }
                    return await self.activateAndValidatePasteTarget(capturedTarget)
                } validateTarget: { [weak self] capturedTarget in
                    self?.isPasteTargetReadyForDispatch(capturedTarget) == true
                }
                guard outcome.ownsPresentationCompletion else { return }
                onComplete?()
            }
        }
    }

    @MainActor
    private func pasteTargetIdentity(_ application: NSRunningApplication) -> PasteTargetIdentity {
        PasteTargetIdentity(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier
        )
    }

    @MainActor
    private func activateAndValidatePasteTarget(
        _ expectedTarget: PasteTargetIdentity
    ) async -> PasteTargetIdentity? {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let ownProcessIdentifier = NSRunningApplication.current.processIdentifier
        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == expectedTarget.processIdentifier
        }),
        PasteTargetPolicy.matchesExpectedIdentity(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            expected: expectedTarget
        ),
        PasteTargetPolicy.isUsableExternalTarget(
            application,
            ownBundleIdentifier: ownBundleIdentifier,
            ownProcessIdentifier: ownProcessIdentifier
        ) else {
            return nil
        }

        if NSWorkspace.shared.frontmostApplication?.processIdentifier != application.processIdentifier {
            guard application.activate() else {
                return nil
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
        }

        guard let resolvedApplication = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == expectedTarget.processIdentifier
        }),
        PasteTargetPolicy.matchesExpectedIdentity(
            processIdentifier: resolvedApplication.processIdentifier,
            bundleIdentifier: resolvedApplication.bundleIdentifier,
            expected: expectedTarget
        ),
        PasteTargetPolicy.isUsableExternalTarget(
            resolvedApplication,
            ownBundleIdentifier: ownBundleIdentifier,
            ownProcessIdentifier: ownProcessIdentifier
        ),
        NSWorkspace.shared.frontmostApplication?.processIdentifier == expectedTarget.processIdentifier else {
            return nil
        }

        return pasteTargetIdentity(resolvedApplication)
    }

    @MainActor
    private func isPasteTargetReadyForDispatch(
        _ expectedTarget: PasteTargetIdentity
    ) -> Bool {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let ownProcessIdentifier = NSRunningApplication.current.processIdentifier
        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == expectedTarget.processIdentifier
        }),
        PasteTargetPolicy.matchesExpectedIdentity(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            expected: expectedTarget
        ),
        PasteTargetPolicy.isUsableExternalTarget(
            application,
            ownBundleIdentifier: ownBundleIdentifier,
            ownProcessIdentifier: ownProcessIdentifier
        ) else {
            return false
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == expectedTarget.processIdentifier
    }

    @MainActor
    private func finishDictationPresentation(session: UUID) {
        guard case .finished = dictationSession.finishPresentation(session: session) else {
            return
        }
        clearRecordingTargetIfCurrent(session: session)
    }

    @MainActor
    private func clearRecordingTargetIfCurrent(session: UUID) {
        guard recordingPreviewID == session else { return }
        recordingTargetApplication = nil
    }

    private var selectedModel: VoiceInputModel {
        VoiceInputModel.model(for: settingsStore.selectedModelID)
    }

    private var selectedModelManager: ModelManager {
        ModelManager(model: selectedModel, applicationSupportRoot: modelManager.applicationSupportRoot)
    }

    private func milliseconds(since date: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(date) * 1_000))
    }

    private func postProcessed(_ result: TranscriptionResult) -> TranscriptionResult {
        let options = transcriptProcessingOptions()
        return TranscriptionResult(
            text: TranscriptPostProcessor.process(result.text, options: options),
            engine: result.engine,
            selectedEngine: result.selectedEngine,
            requestedModelID: result.requestedModelID,
            requestedStrategy: result.requestedStrategy,
            effectiveStrategy: result.effectiveStrategy,
            fallbackReason: result.fallbackReason
        )
    }

    private func postProcessedOffMainActor(_ result: TranscriptionResult) async -> TranscriptionResult {
        let options = transcriptProcessingOptions()
        let text = result.text
        return await Task.detached(priority: .userInitiated) {
            TranscriptionResult(
                text: TranscriptPostProcessor.process(text, options: options),
                engine: result.engine,
                selectedEngine: result.selectedEngine,
                requestedModelID: result.requestedModelID,
                requestedStrategy: result.requestedStrategy,
                effectiveStrategy: result.effectiveStrategy,
                fallbackReason: result.fallbackReason
            )
        }.value
    }

    private func transcriptProcessingOptions() -> TranscriptProcessingOptions {
        let knownTerms = ((try? hotwordStore?.enabledHotwords()) ?? []).map(\.text)
        return TranscriptProcessingOptions(
            isSmartNumericFormattingEnabled: settingsStore.isSmartNumericFormattingEnabled,
            isFillerCleanupEnabled: settingsStore.isFillerCleanupEnabled,
            isMathNotationEnabled: settingsStore.isMathNotationEnabled,
            mathNotationOutputFormat: settingsStore.mathNotationOutputFormat,
            knownTerms: knownTerms
        )
    }

    private static func transcriptionFailureText(for error: Error) -> String {
        TranscriptionFailureClassifier.capsuleText(
            for: transcriptionFailureCategory(for: error)
        )
    }

    private static func transcriptionFailureCategory(for error: Error) -> TranscriptFailureCategory {
        return TranscriptionFailureClassifier.category(for: error)
    }

    private static func debugDescription(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func ensureSpeechPermission() throws {
        guard permissionManager.snapshot().speechRecognition == .granted else {
            throw TranscriptionFlowError.speechPermissionRequired
        }
    }

    @MainActor
    private func requestSpeechPermissionIfNeeded(previewID: UUID) {
        capsule.update(.failure("Speech permission required"))
        let snapshot = permissionManager.snapshot()
        if snapshot.speechRecognition == .notDetermined {
            permissionManager.requestSpeechRecognition { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showMainWindow(section: .readiness)
                }
            }
        } else {
            showMainWindow(section: .readiness)
        }
        scheduleCapsuleHide(after: 1.0, previewID: previewID) { [weak self] in
            self?.finishDictationPresentation(session: previewID)
        }
    }

    @MainActor
    private func scheduleRecordingTimeout(previewID: UUID) {
        let maxRecordingDuration = TimeInterval(settingsStore.maxRecordingDuration)
        scheduleRecordingWarnings(previewID: previewID, maxRecordingDuration: maxRecordingDuration)

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard self.recordingPreviewID == previewID else { return }
                guard self.isRecordingPreviewActive else { return }
                self.capsule.update(.transcribing("Time limit reached, transcribing..."))
                self.stopRecordingPreview()
            }
        }
        recordingTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + maxRecordingDuration, execute: workItem)
    }

    @MainActor
    private func scheduleRecordingWarnings(previewID: UUID, maxRecordingDuration: TimeInterval) {
        cancelRecordingWarningWorkItems()
        for secondsRemaining in [15, 5] {
            let fireAfter = maxRecordingDuration - TimeInterval(secondsRemaining)
            guard fireAfter > 0 else { continue }
            let workItem = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.recordingPreviewID == previewID else { return }
                    guard self.isRecordingPreviewActive else { return }
                    self.capsule.update(.status("\(secondsRemaining) seconds left"))
                }
            }
            recordingWarningWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + fireAfter, execute: workItem)
        }
    }

    @MainActor
    private func cancelRecordingTimers() {
        recordingTimeoutWorkItem?.cancel()
        recordingTimeoutWorkItem = nil
        cancelRecordingWarningWorkItems()
    }

    @MainActor
    private func cancelRecordingWarningWorkItems() {
        recordingWarningWorkItems.forEach { $0.cancel() }
        recordingWarningWorkItems.removeAll()
    }

    @MainActor
    private func scheduleCapsuleHide(
        after delay: TimeInterval,
        previewID: UUID,
        onHide: (@MainActor () -> Void)? = nil
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task { @MainActor in
                if self.recordingPreviewID == previewID {
                    self.capsule.hide()
                }
                onHide?()
            }
        }
    }
}

extension AppDelegate: FlowtypePreparationDriving {
    func inspect(
        configuration: PreparationConfiguration,
        live: Bool
    ) async -> PreparationEvidence {
        let context = await MainActor.run {
            (
                permissions: permissionManager.snapshot(),
                selectedModelID: settingsStore.selectedModelID
            )
        }
        let includeSpeechRecognition = configuration.engine == .appleSpeech
        var report = readinessService.lightweightReport(
            permissionSnapshot: context.permissions,
            selectedModelID: context.selectedModelID,
            includeSpeechRecognition: includeSpeechRecognition
        )
        let model = configuration.modelID.flatMap { modelID in
            VoiceInputModel.all.first(where: { $0.modelID == modelID })
        }
        let selectedManager = model.map {
            ModelManager(model: $0, applicationSupportRoot: modelManager.applicationSupportRoot)
        }

        var helperHealthy = false
        var selectedStatus: QwenModelStatus?
        if live, configuration.engine == .qwenLocal, let modelID = configuration.modelID {
            do {
                let endpoint = try await startHelperIfNeeded()
                let client = QwenHelperClient(baseURL: endpoint.baseURL, authToken: endpoint.authToken)
                helperHealthy = try await client.health().ok
                selectedStatus = try await client.modelStatus(modelID: modelID)
                report = await readinessService.reportWithHelperModelStatus(
                    permissionSnapshot: context.permissions,
                    selectedModelID: context.selectedModelID,
                    includeSpeechRecognition: false,
                    includePerformanceDetails: false
                )
            } catch {
                helperHealthy = false
            }
        }

        let appChecks = report.checks(in: .appBundle)
        let appBundleReady = !appChecks.isEmpty && appChecks.allSatisfy {
            $0.status == .ready || $0.status == .optional
        }
        let runtimeActions = report.checks(in: .localRuntime).compactMap { check -> ReadinessActionKind? in
            guard check.status != .ready else { return nil }
            return check.primaryAction
        }
        let runtimeAction: ReadinessActionKind?
        if runtimeActions.contains(.repairHelper) {
            runtimeAction = .repairHelper
        } else if runtimeActions.contains(.repairLocalRuntime) {
            runtimeAction = .repairLocalRuntime
        } else if runtimeActions.contains(.prepareRuntime) {
            runtimeAction = .prepareRuntime
        } else {
            runtimeAction = nil
        }

        var missingPermissions: [PreparationPermission] = []
        if report.checks.contains(where: { $0.id == "microphone-permission" && $0.status != .ready }) {
            missingPermissions.append(.microphone)
        }
        if report.checks.contains(where: { $0.id == "accessibility-permission" && $0.status != .ready }) {
            missingPermissions.append(.accessibility)
        }
        if includeSpeechRecognition,
           report.checks.contains(where: { $0.id == "speech-recognition-permission" && $0.status != .ready }) {
            missingPermissions.append(.speechRecognition)
        }

        return PreparationEvidence(
            report: report,
            appBundleReady: appBundleReady,
            runtimeAction: runtimeAction,
            missingPermissions: missingPermissions,
            selectedModelInstalled: selectedManager?.isModelInstalled ?? false,
            selectedModelLoaded: selectedStatus?.loaded == true && selectedStatus?.modelId == configuration.modelID,
            helperHealthy: helperHealthy
        )
    }

    func prepareRuntime(action: ReadinessActionKind) async throws {
        await stopHelperAfterQwenFailure()
        switch action {
        case .repairHelper, .repairLocalRuntime:
            try await Task.detached { [readinessService] in
                _ = try readinessService.repairHelperCopy()
            }.value
        default:
            try await Task.detached { [readinessService] in
                _ = try readinessService.prepareRuntime()
            }.value
        }
    }

    func requestPermission(_ permission: PreparationPermission) async {
        switch permission {
        case .microphone:
            await withCheckedContinuation { continuation in
                permissionManager.requestMicrophone { _ in continuation.resume() }
            }
        case .accessibility:
            await MainActor.run {
                permissionManager.requestAccessibilityPrompt()
                permissionManager.openAccessibilitySettings()
            }
        case .speechRecognition:
            await withCheckedContinuation { continuation in
                permissionManager.requestSpeechRecognition { _ in continuation.resume() }
            }
        }
    }

    func hasDownloadConsent(modelID: String) async -> Bool {
        await MainActor.run {
            settingsStore.modelDownloadConsent(for: modelID) != nil
        }
    }

    func requestDownloadConsent(modelID: String) async -> Bool {
        await MainActor.run {
            confirmModelDownloadOnMainActor(modelID: modelID)
        }
    }

    func recordDownloadConsent(modelID: String) async {
        await MainActor.run {
            settingsStore.recordModelDownloadConsent(
                modelID: modelID,
                disclosureVersion: ModelDownloadConsent.currentDisclosureVersion
            )
        }
    }

    func repairSelectedModelStorage(configuration: PreparationConfiguration) async throws {
        guard let modelID = configuration.modelID,
              let model = VoiceInputModel.all.first(where: { $0.modelID == modelID })
        else {
            throw PreparationFailure.finalVerificationFailed
        }
        await stopHelperAfterQwenFailure()
        try await Task.detached { [applicationSupportRoot = modelManager.applicationSupportRoot] in
            try ModelManager(
                model: model,
                applicationSupportRoot: applicationSupportRoot
            ).resetModelStorage()
        }.value
    }

    func prepareSelectedModel(
        configuration: PreparationConfiguration,
        operationID: UUID,
        progress: @escaping (PreparationStage, Double?) async -> Void
    ) async throws -> PreparedRuntimeIdentity {
        guard let modelID = configuration.modelID,
              let model = VoiceInputModel.all.first(where: { $0.modelID == modelID })
        else {
            throw PreparationFailure.finalVerificationFailed
        }

        await progress(.startingHelper, nil)
        let endpoint = try await startHelperIfNeeded()
        let client = QwenHelperClient(baseURL: endpoint.baseURL, authToken: endpoint.authToken)
        var status = try await client.modelStatus(modelID: modelID)
        let wasInstalled = status.installed
        if !status.loaded {
            status = try await client.downloadModel(modelID: modelID)
        }

        let deadline = Date().addingTimeInterval(wasInstalled ? 120 : 1_800)
        while !status.loaded {
            if status.phase == .failed {
                throw PreparationFailure.modelPreparationFailed(
                    status.errorCode ?? "model_preparation_failed"
                )
            }
            switch status.phase {
            case .downloading:
                await progress(.downloadingModel, status.progress)
            case .loading, .installed, .absent:
                await progress(.loadingModel, status.progress)
            case .ready:
                break
            case .failed:
                break
            }
            guard Date() < deadline else {
                throw PreparationFailure.modelPreparationFailed("model_preparation_timed_out")
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            status = try await client.modelStatus(modelID: modelID)
        }

        guard status.modelId == modelID else {
            throw PreparationFailure.finalVerificationFailed
        }
        try? ModelManager(
            model: model,
            applicationSupportRoot: modelManager.applicationSupportRoot
        ).markInstalled()
        return PreparedRuntimeIdentity(
            configuration: configuration,
            bootID: endpoint.bootID,
            verifiedAt: Date()
        )
    }
}

private enum TranscriptionFlowError: LocalizedError {
    case speechPermissionRequired

    var errorDescription: String? {
        switch self {
        case .speechPermissionRequired:
            "Speech permission required"
        }
    }
}

private enum DiagnosticsCopyError: LocalizedError {
    case pasteboardWriteFailed(URL?)

    var errorDescription: String? {
        if case let .pasteboardWriteFailed(url?) = self {
            return "Unable to copy diagnostics to the clipboard. Latest diagnostics were saved to \(url.path)."
        }
        return "Unable to copy diagnostics to the clipboard."
    }
}
