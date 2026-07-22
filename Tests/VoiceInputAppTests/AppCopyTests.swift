import XCTest
@testable import VoiceInputApp

final class AppCopyTests: XCTestCase {
    func testChineseCopyLocalizesPrimaryNavigationAndMenu() {
        let copy = AppCopy.texts(for: .chinese)

        XCTAssertEqual(copy.homeTitle, "主页")
        XCTAssertEqual(copy.dictionaryTitle, "词典")
        XCTAssertEqual(copy.modelsTitle, "模型")
        XCTAssertEqual(copy.readinessTitle, "准备状态")
        XCTAssertEqual(copy.preferencesTitle, "转写与外观")
        XCTAssertEqual(copy.settingsTitle, "设备与存储")
        XCTAssertEqual(copy.dictationCountTitle, "听写次数")
        XCTAssertEqual(copy.dictatedUnits(198_000), "19.8万 字")
        XCTAssertEqual(copy.menuShowHome, "显示主页")
        XCTAssertEqual(copy.menuShowPreferences, "显示转写与外观")
        XCTAssertEqual(copy.menuSetupStatus, "准备状态...")
        XCTAssertEqual(copy.currentModelMenuTitle("Qwen3-ASR 1.7B"), "模型：Qwen3-ASR 1.7B")
        XCTAssertEqual(copy.rowRetrySegmented, "重新分段转写")
        XCTAssertEqual(copy.rowRetrySegmentedSucceeded, "已重新转写")
        XCTAssertEqual(copy.rowRetrySegmentedFailed, "重试失败")
        XCTAssertEqual(copy.rowTranscriptionFailed, "转写失败")
        XCTAssertEqual(copy.rowRecoverableFailureDetail, "已保留录音，可重新转写")
        XCTAssertEqual(copy.rowRetryTranscription, "重新转写")
        XCTAssertEqual(copy.rowRecordingExpired, "录音已过期")
        XCTAssertEqual(copy.capsuleRecoverableTranscriptionFailed, "转写失败，主页可重试")
        XCTAssertEqual(copy.permissionsExitWarningTitle, "Flowtype 还不能正常使用")
        XCTAssertTrue(copy.permissionsExitWarningMessage.contains("麦克风和辅助功能权限"))
        XCTAssertTrue(copy.permissionsExitWarningMessage.contains("准备状态"))
        XCTAssertEqual(copy.readinessSubtitle, "查看 Flowtype 是否可以开始听写，并处理权限、模型和本地运行问题。")
        XCTAssertEqual(copy.readinessRefreshTitle, "刷新")
        XCTAssertEqual(copy.readinessPrepareRuntimeTitle, "准备运行环境")
        XCTAssertEqual(copy.readinessRepairHelperTitle, "修复 Helper")
        XCTAssertEqual(copy.readinessWarmModelTitle, "准备模型")
        XCTAssertEqual(copy.readinessCopyDiagnosticsTitle, "复制诊断")
        XCTAssertEqual(copy.readinessCopiedDiagnosticsTitle, "已复制诊断")
        XCTAssertEqual(copy.readinessDiagnosticsTitle, "诊断")
        XCTAssertEqual(copy.readinessGenerateDiagnosticsTitle, "生成诊断文件")
        XCTAssertEqual(copy.readinessOpenDiagnosticsFolderTitle, "打开诊断文件夹")
        XCTAssertEqual(
            copy.readinessGeneratedDiagnosticsTitle("flowtype-diagnostics-20260518-231455.txt"),
            "已生成诊断文件：flowtype-diagnostics-20260518-231455.txt"
        )
        XCTAssertEqual(copy.readinessFailedTitle, "操作失败")
        XCTAssertEqual(copy.readinessStatusTitle(for: .ready), "就绪")
        XCTAssertEqual(copy.readinessStatusTitle(for: .notReady), "未就绪")
        XCTAssertEqual(copy.readinessStatusTitle(for: .preparing), "准备中")
        XCTAssertEqual(copy.readinessStatusTitle(for: .needsRepair), "需要修复")
        XCTAssertEqual(copy.readinessStatusTitle(for: .optional), "可选")
        XCTAssertEqual(copy.readinessStatusTitle(for: .failed("uv missing")), "失败")
        XCTAssertEqual(copy.readinessStatusTitle(for: .unknown), "未知")
        XCTAssertEqual(copy.readinessGroupAppBundleTitle, "应用包")
        XCTAssertEqual(copy.readinessGroupLocalRuntimeTitle, "本地运行环境")
        XCTAssertEqual(copy.readinessGroupModelsTitle, "模型")
        XCTAssertEqual(copy.readinessGroupPermissionsTitle, "权限")
        XCTAssertEqual(copy.readinessGroupPerformanceTitle, "性能")
        XCTAssertEqual(copy.readinessRequestMicrophoneTitle, "麦克风")
        XCTAssertEqual(copy.readinessOpenAccessibilitySettingsTitle, "辅助功能")
        XCTAssertEqual(copy.readinessRequestSpeechRecognitionTitle, "语音识别")
        XCTAssertEqual(copy.readinessReinstallAppTitle, "重新安装")
        XCTAssertEqual(copy.readinessRestartHelperTitle, "重启 Helper")
        XCTAssertTrue(copy.helpMessageBody.contains("可能不完整"))
        XCTAssertTrue(copy.helpMessageBody.contains("主题"))
        XCTAssertTrue(copy.helpMessageBody.contains("Qwen3-ASR 0.6B / 1.7B"))
        XCTAssertTrue(copy.helpMessageBody.contains("在“准备状态”页面"))
        XCTAssertFalse(copy.helpMessageBody.contains("设置权限"))
        XCTAssertEqual(copy.hotwordAlreadyExists, "这个词条已经存在，已为你显示对应结果。")
        XCTAssertEqual(MainWindowSection.models.title(for: .chinese), "模型")
        XCTAssertEqual(MainWindowSection.readiness.title(for: .chinese), "准备状态")
        XCTAssertEqual(MainWindowSection.readiness.systemImage, "checklist.checked")
        XCTAssertEqual(MainWindowSection.home.title(for: .chinese), "主页")
        XCTAssertEqual(MainWindowSection.allCases.map(\.rawValue), [
            "home",
            "dictionary",
            "models",
            "readiness",
            "preferences"
        ])
    }

    func testChineseCopyLocalizesReadinessChecks() {
        let copy = AppCopy.texts(for: .chinese)
        let bundledUV = ReadinessCheck(
            id: "bundled-uv",
            group: .appBundle,
            title: "Bundled uv",
            detail: "This Flowtype app bundle is incomplete. Reinstall Flowtype from the DMG.",
            status: .failed("Bundled uv is missing or not executable."),
            primaryAction: .reinstallApp
        )
        let helperCopy = ReadinessCheck(
            id: "local-helper-copy",
            group: .localRuntime,
            title: "Local Qwen helper copy",
            detail: "Prepare or repair the local helper copy before Qwen dictation.",
            status: .needsRepair,
            primaryAction: .repairHelper
        )
        let timing = ReadinessCheck(
            id: "last-transcription-timing",
            group: .performance,
            title: "Last transcription timing",
            detail: "Last run: helper 12 ms, status probe 34 ms, decode 567 ms, post 8 ms.",
            status: .ready
        )

        XCTAssertEqual(copy.readinessCheckTitle(for: bundledUV), "内置 uv")
        XCTAssertEqual(copy.readinessCheckDetail(for: bundledUV), "这个 Flowtype 应用包不完整。请从 DMG 重新安装 Flowtype。")
        XCTAssertEqual(copy.readinessCheckStatusMessage(for: bundledUV), "内置 uv 缺失或不可执行。")
        XCTAssertEqual(copy.readinessCheckTitle(for: helperCopy), "本地 Qwen helper 副本")
        XCTAssertEqual(copy.readinessCheckDetail(for: helperCopy), "使用 Qwen 听写前，需要准备或修复本地 helper 副本。")
        XCTAssertEqual(copy.readinessCheckTitle(for: timing), "上次转写耗时")
        XCTAssertEqual(copy.readinessCheckDetail(for: timing), "上次运行：helper 12 ms，状态探测 34 ms，解码 567 ms，后处理 8 ms。")
    }

    func testChinesePreloadCopyDescribesAutomaticPreparation() {
        let copy = AppCopy.texts(for: .chinese)
        let check = ReadinessCheck(
            id: "model-qwen3-asr-0.6b-warm",
            group: .models,
            title: "Qwen3-ASR 0.6B preload status",
            detail: "Flowtype prepares this model automatically.",
            status: .optional,
            secondaryAction: .copyDiagnostics
        )

        XCTAssertEqual(copy.readinessCheckTitle(for: check), "Qwen3-ASR 0.6B 准备状态")
        XCTAssertTrue(copy.readinessCheckDetail(for: check).contains("自动"))
        XCTAssertFalse(copy.readinessCheckDetail(for: check).contains("手动"))
        XCTAssertFalse(copy.readinessCheckDetail(for: check).contains("预热"))
    }

    func testChineseReadinessStatusBadgesUseRowContext() {
        let copy = AppCopy.texts(for: .chinese)
        let missingOptionalModel = ReadinessCheck(
            id: "model-qwen3-asr-1.7b",
            group: .models,
            title: "Qwen3-ASR 1.7B",
            detail: "Download this model before using local Qwen dictation.",
            status: .optional,
            locationTarget: .modelsRoot
        )
        let selectedColdModel = ReadinessCheck(
            id: "model-qwen3-asr-0.6b-warm",
            group: .models,
            title: "Qwen3-ASR 0.6B preload status",
            detail: "Flowtype prepares this model automatically.",
            status: .optional,
            locationTarget: .selectedModel
        )
        let nonSelectedPreload = ReadinessCheck(
            id: "model-qwen3-asr-1.7b-warm",
            group: .models,
            title: "Qwen3-ASR 1.7B preload status",
            detail: "Only the selected model is prepared.",
            status: .optional,
            locationTarget: .modelsRoot
        )
        let performanceAdvisory = ReadinessCheck(
            id: "memory-tier",
            group: .performance,
            title: "Memory tier",
            detail: "16 GB unified memory detected.",
            status: .optional
        )

        XCTAssertEqual(copy.readinessStatusTitle(for: missingOptionalModel), "未下载")
        XCTAssertEqual(copy.readinessStatusTitle(for: selectedColdModel), "未准备")
        XCTAssertEqual(copy.readinessStatusTitle(for: nonSelectedPreload), "未选择")
        XCTAssertEqual(copy.readinessStatusTitle(for: performanceAdvisory), "建议")
    }

    func testChineseSetupActionCopyIsSpecific() {
        let copy = AppCopy.texts(for: .chinese)

        XCTAssertEqual(copy.readinessPrepareFlowtypeTitle, "一键准备 Flowtype")
        XCTAssertEqual(copy.readinessReinstallFlowtypeTitle, "打开应用位置")
        XCTAssertEqual(copy.readinessRepairLocalRuntimeTitle, "修复本地运行环境")
        XCTAssertEqual(copy.readinessOpenLocationTitle, "打开位置")
        XCTAssertEqual(copy.readinessDownloadDefaultModelTitle, "下载 0.6B 模型")
    }

    func testChineseModelSuitabilityWarningCopyDoesNotFallBackToEnglish() {
        let copy = AppCopy.texts(for: .chinese)
        let recommendation = ModelSuitabilityRecommendation(
            level: .stronglyDiscouraged,
            summary: "Not recommended on this Mac",
            detail: "Qwen3-ASR 1.7B may be much slower, especially after launch, after model switching, and for longer recordings.",
            physicalMemoryGB: 16
        )

        XCTAssertEqual(copy.modelSuitabilityWarningTitle, "1.7B 在这台 Mac 上可能较慢")
        XCTAssertEqual(copy.modelSuitabilityUseSmallModelTitle, "使用 0.6B")
        XCTAssertEqual(copy.modelSuitabilityContinueTitle, "仍然继续")
        XCTAssertEqual(
            copy.modelSuitabilityDetail(for: recommendation),
            "这台 Mac 检测到 16 GB 统一内存。Flowtype 建议日常听写使用 Qwen3-ASR 0.6B。Qwen3-ASR 1.7B 可能明显变慢，尤其是第一次听写、切换模型后和较长录音。"
        )
        XCTAssertFalse(copy.modelSuitabilityWarningTitle.contains("slow"))
        XCTAssertFalse(copy.modelSuitabilityContinueTitle.contains("Continue"))
        XCTAssertFalse(copy.modelSuitabilityDetail(for: recommendation).contains("unified memory"))
    }

    func testChineseSelectedModelRecommendationPreservesLargeModelAdvisory() {
        let copy = AppCopy.texts(for: .chinese)
        let recommendation = ModelSuitabilityPolicy()
            .recommendation(
                hardware: HardwareSummary(machine: "MacBookPro18,3", processor: "Apple M1 Pro", physicalMemoryGB: 16, isAppleSilicon: true),
                model: .qwen3ASR17B
            )
        let check = ReadinessCheck(
            id: "selected-model-recommendation",
            group: .performance,
            title: "Model recommendation",
            detail: recommendation.detail,
            status: .optional,
            modelSuitabilityRecommendation: recommendation
        )

        let localizedDetail = copy.readinessCheckDetail(for: check)

        XCTAssertTrue(localizedDetail.contains("1.7B 可能明显变慢"))
        XCTAssertTrue(localizedDetail.contains("建议日常听写使用 Qwen3-ASR 0.6B"))
        XCTAssertFalse(localizedDetail.contains("符合这台 Mac 的内存档位"))
    }

    func testEnglishModelSuitabilityWarningCopyUsesPolicyDetail() {
        let copy = AppCopy.texts(for: .english)
        let recommendation = ModelSuitabilityRecommendation(
            level: .allowedWithWarning,
            summary: "Use with warning",
            detail: "Qwen3-ASR 1.7B can improve difficult audio but may feel noticeably slower on 24 GB unified memory.",
            physicalMemoryGB: 24
        )

        XCTAssertEqual(copy.modelSuitabilityWarningTitle, "1.7B may be slow on this Mac")
        XCTAssertEqual(copy.modelSuitabilityUseSmallModelTitle, "Use 0.6B")
        XCTAssertEqual(copy.modelSuitabilityContinueTitle, "Continue Anyway")
        XCTAssertEqual(copy.modelSuitabilityDetail(for: recommendation), recommendation.detail)
    }

    func testChineseFirstRunSetupPromptCopyIsActionable() {
        let copy = AppCopy.texts(for: .chinese)

        XCTAssertEqual(copy.readinessFirstRunPromptTitle, "先把 Flowtype 准备好")
        XCTAssertTrue(copy.readinessFirstRunPromptMessage.contains("麦克风"))
        XCTAssertTrue(copy.readinessFirstRunPromptMessage.contains("辅助功能"))
        XCTAssertTrue(copy.readinessFirstRunPromptMessage.contains("0.6B"))
        XCTAssertEqual(copy.readinessFirstRunPromptPrimaryTitle, "开始准备并下载")
        XCTAssertEqual(copy.readinessFirstRunPromptLaterTitle, "稍后")
    }

    func testChineseSetupSummaryCopyUsesCounts() {
        let copy = AppCopy.texts(for: .chinese)
        let summary = ReadinessSetupSummary(
            blockingCount: 1,
            repairableCount: 2,
            manualCount: 1,
            optionalCount: 3,
            requiredIssueCount: 4,
            recommendedPrimaryAction: .prepareFlowtype
        )

        XCTAssertEqual(copy.readinessSetupSummaryTitle(for: summary), "Flowtype 还需要完成 4 项设置")
        XCTAssertTrue(copy.readinessSetupSummaryDetail(for: summary).contains("重新安装"))
        XCTAssertTrue(copy.readinessSetupSummaryDetail(for: summary).contains("修复"))
        XCTAssertTrue(copy.readinessSetupSummaryDetail(for: summary).contains("授权"))
    }

    func testEnglishCopyKeepsExistingPrimaryNavigationAndMenu() {
        let copy = AppCopy.texts(for: .english)

        XCTAssertEqual(copy.homeTitle, "Home")
        XCTAssertEqual(copy.dictionaryTitle, "Dictionary")
        XCTAssertEqual(copy.modelsTitle, "Models")
        XCTAssertEqual(copy.readinessTitle, "Setup & Status")
        XCTAssertEqual(copy.preferencesTitle, "Transcription & Appearance")
        XCTAssertEqual(copy.settingsTitle, "Device & Storage")
        XCTAssertEqual(copy.menuShowHome, "Show Home")
        XCTAssertEqual(copy.menuShowPreferences, "Show Transcription & Appearance")
        XCTAssertEqual(copy.menuSetupStatus, "Setup & Status...")
        XCTAssertEqual(copy.currentModelMenuTitle("Qwen3-ASR 1.7B"), "Model: Qwen3-ASR 1.7B")
        XCTAssertEqual(copy.rowRetrySegmented, "Retry with segments")
        XCTAssertEqual(copy.rowRetrySegmentedSucceeded, "Retried")
        XCTAssertEqual(copy.rowRetrySegmentedFailed, "Retry failed")
        XCTAssertEqual(copy.rowTranscriptionFailed, "Transcription failed")
        XCTAssertEqual(copy.rowRecoverableFailureDetail, "Recording saved for retry")
        XCTAssertEqual(copy.rowRetryTranscription, "Retry transcription")
        XCTAssertEqual(copy.rowRecordingExpired, "Recording expired")
        XCTAssertEqual(copy.capsuleRecoverableTranscriptionFailed, "Failed, retry in Home")
        XCTAssertEqual(copy.permissionsExitWarningTitle, "Flowtype is not ready yet")
        XCTAssertTrue(copy.permissionsExitWarningMessage.contains("Microphone and Accessibility"))
        XCTAssertTrue(copy.permissionsExitWarningMessage.contains("Setup & Status"))
        XCTAssertEqual(copy.readinessSubtitle, "See whether Flowtype is ready to dictate, then resolve permissions, models, and local runtime issues.")
        XCTAssertEqual(copy.readinessRefreshTitle, "Refresh")
        XCTAssertEqual(copy.readinessPrepareRuntimeTitle, "Prepare Runtime")
        XCTAssertEqual(copy.readinessRepairHelperTitle, "Repair Helper")
        XCTAssertEqual(copy.readinessWarmModelTitle, "Warm Model")
        XCTAssertEqual(copy.readinessCopyDiagnosticsTitle, "Copy Diagnostics")
        XCTAssertEqual(copy.readinessCopiedDiagnosticsTitle, "Diagnostics Copied")
        XCTAssertEqual(copy.readinessDiagnosticsTitle, "Diagnostics")
        XCTAssertEqual(copy.readinessGenerateDiagnosticsTitle, "Generate Diagnostics File")
        XCTAssertEqual(copy.readinessOpenDiagnosticsFolderTitle, "Open Diagnostics Folder")
        XCTAssertEqual(
            copy.readinessGeneratedDiagnosticsTitle("flowtype-diagnostics-20260518-231455.txt"),
            "Diagnostics file generated: flowtype-diagnostics-20260518-231455.txt"
        )
        XCTAssertEqual(copy.readinessFailedTitle, "Action Failed")
        XCTAssertEqual(copy.readinessStatusTitle(for: .ready), "Ready")
        XCTAssertEqual(copy.readinessStatusTitle(for: .notReady), "Not Ready")
        XCTAssertEqual(copy.readinessStatusTitle(for: .preparing), "Preparing")
        XCTAssertEqual(copy.readinessStatusTitle(for: .needsRepair), "Needs Repair")
        XCTAssertEqual(copy.readinessStatusTitle(for: .optional), "Optional")
        XCTAssertEqual(copy.readinessStatusTitle(for: .failed("uv missing")), "Failed")
        XCTAssertEqual(copy.readinessStatusTitle(for: .unknown), "Unknown")
        XCTAssertEqual(copy.readinessGroupAppBundleTitle, "App Bundle")
        XCTAssertEqual(copy.readinessGroupLocalRuntimeTitle, "Local Runtime")
        XCTAssertEqual(copy.readinessGroupModelsTitle, "Models")
        XCTAssertEqual(copy.readinessGroupPermissionsTitle, "Permissions")
        XCTAssertEqual(copy.readinessGroupPerformanceTitle, "Performance")
        XCTAssertEqual(copy.readinessRequestMicrophoneTitle, "Microphone")
        XCTAssertEqual(copy.readinessOpenAccessibilitySettingsTitle, "Accessibility")
        XCTAssertEqual(copy.readinessRequestSpeechRecognitionTitle, "Speech Recognition")
        XCTAssertEqual(copy.readinessReinstallAppTitle, "Reinstall")
        XCTAssertEqual(copy.readinessRestartHelperTitle, "Restart Helper")
        XCTAssertTrue(copy.helpMessageBody.contains("possibly incomplete"))
        XCTAssertTrue(copy.helpMessageBody.contains("themes"))
        XCTAssertTrue(copy.helpMessageBody.contains("Qwen3-ASR 0.6B and 1.7B"))
        XCTAssertTrue(copy.helpMessageBody.contains("Use Setup & Status"))
        XCTAssertTrue(copy.helpMessageBody.contains("only needed for Apple Speech fallback"))
        XCTAssertEqual(copy.hotwordAlreadyExists, "This term already exists. The matching result is now shown.")
        XCTAssertEqual(MainWindowSection.models.title(for: .english), "Models")
        XCTAssertEqual(MainWindowSection.readiness.title(for: .english), "Setup & Status")
        XCTAssertEqual(MainWindowSection.readiness.systemImage, "checklist.checked")
        XCTAssertEqual(MainWindowSection.dictionary.title(for: .english), "Dictionary")
    }

    func testEnglishCopyKeepsReadinessCheckDiagnosticsUnchanged() {
        let copy = AppCopy.texts(for: .english)
        let check = ReadinessCheck(
            id: "bundled-uv",
            group: .appBundle,
            title: "Bundled uv",
            detail: "This Flowtype app bundle is incomplete. Reinstall Flowtype from the DMG.",
            status: .failed("Bundled uv is missing or not executable."),
            primaryAction: .reinstallApp
        )

        XCTAssertEqual(copy.readinessCheckTitle(for: check), "Bundled uv")
        XCTAssertEqual(copy.readinessCheckDetail(for: check), "This Flowtype app bundle is incomplete. Reinstall Flowtype from the DMG.")
        XCTAssertEqual(copy.readinessCheckStatusMessage(for: check), "Bundled uv is missing or not executable.")
    }

    func testSemanticReadinessCopyFollowsEngineAndTaskKind() {
        let chinese = AppCopy.texts(for: .chinese)
        let english = AppCopy.texts(for: .english)
        let qwen = ReadinessContext(
            engine: .qwenLocal,
            selectedModelID: VoiceInputModel.qwen3ASR17B.id
        )
        let apple = ReadinessContext(
            engine: .appleSpeech,
            selectedModelID: VoiceInputModel.qwen3ASR06B.id
        )

        XCTAssertEqual(chinese.readinessCheckingTitle, "正在检查 Flowtype…")
        XCTAssertTrue(chinese.readinessReadyDetail(for: qwen).contains("精准听写"))
        XCTAssertTrue(chinese.readinessPermissionsReadyDetail(for: apple).contains("语音识别"))
        XCTAssertEqual(chinese.readinessTaskTitle(.grantAccessibility, context: qwen), "允许使用辅助功能")
        XCTAssertEqual(english.readinessTaskSummaryTitle(count: 1), "Flowtype needs 1 setup step")
        XCTAssertEqual(english.readinessTaskSummaryTitle(count: 2), "Flowtype needs 2 setup steps")
        XCTAssertEqual(english.readinessTaskSymbol(.repairLocalRuntime), "gearshape.2.fill")
        XCTAssertTrue(english.readinessEngineReadyDetail(for: apple).contains("Apple Speech"))
    }

    func testMetricValueSegmentsSplitNumbersAndUnits() {
        let chinese = AppCopy.texts(for: .chinese)
        let english = AppCopy.texts(for: .english)

        XCTAssertEqual(chinese.dictationCountSegments(4114), [
            .number("4114"), .unit("次")
        ])
        XCTAssertEqual(chinese.durationSegments(13 * 3600 + 4 * 60), [
            .number("13"), .unit("时"), .number("4"), .unit("分")
        ])
        XCTAssertEqual(chinese.durationSegments(240), [
            .number("4"), .unit("分")
        ])
        XCTAssertEqual(chinese.durationSegments(0), [
            .number("0"), .unit("分")
        ])
        XCTAssertEqual(chinese.dictatedUnitsSegments(209_000), [
            .number("20.9"), .unit("万字")
        ])
        XCTAssertEqual(chinese.dictatedUnitsSegments(950), [
            .number("950"), .unit("字")
        ])

        XCTAssertEqual(english.dictationCountSegments(12), [
            .number("12"), .unit("times")
        ])
        XCTAssertEqual(english.durationSegments(13 * 3600 + 4 * 60), [
            .number("13"), .unit("hr"), .number("4"), .unit("min")
        ])
        XCTAssertEqual(english.dictatedUnitsSegments(209_000), [
            .number("209.0k"), .unit("words")
        ])
    }

    func testModelRoleCopyLeadsWithUserFacingNames() {
        let chinese = AppCopy.texts(for: .chinese)
        let english = AppCopy.texts(for: .english)

        XCTAssertEqual(chinese.modelRoleTitle(for: .qwen3ASR06B), "日常听写")
        XCTAssertEqual(chinese.modelRoleTitle(for: .qwen3ASR17B), "精准听写")
        XCTAssertTrue(chinese.modelRoleDescription(for: .qwen3ASR06B).contains("默认推荐"))
        XCTAssertTrue(chinese.modelRoleDescription(for: .qwen3ASR17B).contains("更慢"))
        XCTAssertTrue(chinese.modelProvenance(for: .qwen3ASR06B).contains("Qwen3-ASR 0.6B"))
        XCTAssertEqual(chinese.modelStorageUsage("1.2 GB"), "已占用 1.2 GB")
        XCTAssertTrue(
            chinese.modelDeleteConfirmMessage(for: .qwen3ASR17B, formattedSize: "3.4 GB")
                .contains("Qwen3-ASR 1.7B（3.4 GB）")
        )
        XCTAssertEqual(chinese.historySectionTitle, "转写历史")
        XCTAssertEqual(chinese.modelDeleteTitle, "删除模型")
        XCTAssertEqual(chinese.modelDeleteConfirmTitle, "删除这个模型？")

        XCTAssertEqual(english.modelRoleTitle(for: .qwen3ASR06B), "Everyday Dictation")
        XCTAssertEqual(english.modelRoleTitle(for: .qwen3ASR17B), "Precision Dictation")
        XCTAssertTrue(english.modelProvenance(for: .qwen3ASR17B).contains("Qwen3-ASR 1.7B"))
        XCTAssertEqual(english.historySectionTitle, "History")
    }

    func testOnboardingCopyCoversAllStepsInBothLanguages() {
        let chinese = AppCopy.texts(for: .chinese)
        let english = AppCopy.texts(for: .english)

        XCTAssertEqual(chinese.onboardingMenuTitle, "新手引导…")
        XCTAssertEqual(chinese.onboardingWelcomeTitle, "回到心流")
        XCTAssertTrue(chinese.onboardingWelcomeBody.contains("Fn"))
        XCTAssertTrue(chinese.onboardingPrivacyNote.contains("不会上传"))
        XCTAssertEqual(chinese.onboardingMicrophoneTitle, "麦克风")
        XCTAssertEqual(chinese.onboardingAccessibilityTitle, "辅助功能")
        XCTAssertTrue(chinese.onboardingPrepareBody.contains("Qwen3-ASR 0.6B"))
        XCTAssertTrue(chinese.onboardingPrepareBody.contains("权限"))
        XCTAssertTrue(chinese.onboardingPreparePermissionsHint.contains("系统设置"))
        XCTAssertEqual(chinese.onboardingHowToHoldTitle, "按住 Fn 说话")
        XCTAssertEqual(chinese.onboardingFinishTitle, "开始使用 Flowtype")
        XCTAssertEqual(chinese.onboardingSkipTitle, "跳过引导")

        XCTAssertEqual(english.onboardingMenuTitle, "Getting Started…")
        XCTAssertEqual(english.onboardingWelcomeTitle, "Back to Flow")
        XCTAssertTrue(english.onboardingPrepareBody.contains("Qwen3-ASR 0.6B"))
        XCTAssertEqual(english.onboardingHowToHoldTitle, "Hold Fn and talk")
        XCTAssertEqual(english.onboardingFinishTitle, "Start Using Flowtype")
    }
}
