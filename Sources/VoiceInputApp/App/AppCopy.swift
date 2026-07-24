import Foundation

enum AppCopy {
    /// One piece of a usage-metric value, so views can typeset numbers and
    /// units at different sizes (e.g. a large "13" next to a small "时").
    struct MetricValueSegment: Equatable {
        let text: String
        let isUnit: Bool

        static func number(_ text: String) -> MetricValueSegment {
            MetricValueSegment(text: text, isUnit: false)
        }

        static func unit(_ text: String) -> MetricValueSegment {
            MetricValueSegment(text: text, isUnit: true)
        }
    }

    struct Texts {
        let homeTitle: String
        let dictionaryTitle: String
        let modelsTitle: String
        let readinessTitle: String
        let preferencesTitle: String
        let settingsTitle: String
        let helpTitle: String
        let mainHeadline: String
        let mainSubtitle: String
        let todayTitle: String
        let yesterdayTitle: String
        let olderTitle: String
        let saveTranscriptHistory: String
        let historyEnabledDetail: String
        let historyDisabledDetail: String
        let historyOffNotice: String
        let emptyHistoryEnabled: String
        let emptyHistoryDisabled: String
        let openDictionaryHelp: String
        let clearHistoryTitle: String
        let clearHistoryHelp: String
        let moreActionsTitle: String
        let clearHistoryConfirmationTitle: String
        let clearHistoryConfirmationMessage: String
        let clearHistoryErrorTitle: String
        let cancel: String
        let ok: String
        let dictionarySubtitle: String
        let modelsSubtitle: String
        let permissionsReadyDetail: String
        let permissionsExitWarningTitle: String
        let permissionsExitWarningMessage: String
        let readinessSubtitle: String
        let readinessRefreshTitle: String
        let readinessPrepareFlowtypeTitle: String
        let readinessSetupCompleteTitle: String
        let readinessSetupNeedsStepsTitle: String
        let readinessSetupBlockedTitle: String
        let readinessPrepareRuntimeTitle: String
        let readinessRepairHelperTitle: String
        let readinessReinstallFlowtypeTitle: String
        let readinessRepairLocalRuntimeTitle: String
        let readinessOpenLocationTitle: String
        let readinessDownloadDefaultModelTitle: String
        let readinessRetryPreloadTitle: String
        let readinessDefaultModelConsentTitle: String
        let readinessDefaultModelConsentMessage: String
        let readinessFirstRunPromptTitle: String
        let readinessFirstRunPromptMessage: String
        let readinessFirstRunPromptPrimaryTitle: String
        let readinessFirstRunPromptLaterTitle: String
        let readinessWarmModelTitle: String
        let readinessCopyDiagnosticsTitle: String
        let readinessCopiedDiagnosticsTitle: String
        let readinessDiagnosticsTitle: String
        let readinessGenerateDiagnosticsTitle: String
        let readinessOpenDiagnosticsFolderTitle: String
        let readinessGeneratedDiagnosticsTitle: (String) -> String
        let readinessFailedTitle: String
        let readinessStatusReadyTitle: String
        let readinessStatusNotReadyTitle: String
        let readinessStatusPreparingTitle: String
        let readinessStatusNeedsRepairTitle: String
        let readinessStatusOptionalTitle: String
        let readinessStatusFailedTitle: String
        let readinessStatusUnknownTitle: String
        let readinessGroupAppBundleTitle: String
        let readinessGroupLocalRuntimeTitle: String
        let readinessGroupModelsTitle: String
        let readinessGroupPermissionsTitle: String
        let readinessGroupPerformanceTitle: String
        let readinessAdvancedDiagnosticsTitle: String
        let readinessRequestMicrophoneTitle: String
        let readinessOpenAccessibilitySettingsTitle: String
        let readinessRequestSpeechRecognitionTitle: String
        let readinessReinstallAppTitle: String
        let readinessRestartHelperTitle: String
        let modelLocalBadge: String
        let modelSelectedBadge: String
        let modelNotInstalled: String
        let modelReady: String
        let modelDownloading: String
        let modelFailed: String
        let modelNeedsRepair: String
        let modelPathTitle: String
        let modelPathDetail: String
        let modelDownloadTitle: String
        let modelRepairTitle: String
        let modelUseTitle: String
        let modelDownloadedTitle: String
        let modelInUseTitle: String
        let modelOpenFolderTitle: String
        let modelCopyPathTitle: String
        let modelOpenDictionaryTitle: String
        let modelRefreshTitle: String
        let modelHotwordsNote: String
        let modelSuitabilityWarningTitle: String
        let modelSuitabilityUseSmallModelTitle: String
        let modelSuitabilityContinueTitle: String
        let modelDownloadHelp: String
        let modelRepairHelp: String
        let modelUseHelp: String
        let modelOpenFolderHelp: String
        let modelCopyPathHelp: String
        let modelErrorTitle: String
        let modelPreparingMessage: String
        let modelRepairMessage: String
        let termsSuffix: String
        let addHotwordPlaceholder: String
        let addWordTitle: String
        let searchHotwordsPlaceholder: String
        let manageHotwordsTitle: String
        let matchesSuffix: String
        let deleteHotwordHelp: String
        let deleteHotwordTitle: String
        let dictionaryErrorTitle: String
        let hotwordAlreadyExists: String
        let rowExpand: String
        let rowCollapse: String
        let rowCopied: String
        let rowCopy: String
        let rowCopyTranscript: String
        let rowPaste: String
        let rowPasteAgain: String
        let rowPossibleTruncation: String
        let rowRetrySegmented: String
        let rowRetryingSegmented: String
        let rowRetrySegmentedSucceeded: String
        let rowRetrySegmentedFailed: String
        let rowTranscriptionFailed: String
        let rowRecoverableFailureDetail: String
        let rowRetryTranscription: String
        let rowRecordingExpired: String
        let capsuleRecoverableTranscriptionFailed: String
        let dictationCountTitle: String
        let recordingDurationTitle: String
        let dictatedUnitsTitle: String
        let savedTimeTitle: String
        let localEstimateNote: String
        let timesUnit: String
        let dictatedUnitSuffix: String
        let menuStatusStarting: String
        let menuEngine: String
        let menuFallback: String
        let menuShowHome: String
        let menuShowDictionary: String
        let menuShowPreferences: String
        let menuCurrentModelPrefix: String
        let menuSettings: String
        let menuHelp: String
        let menuSetupStatus: String
        let menuPasteLastTranscript: String
        let menuQuit: String
        let noTranscriptYet: String
        let copiedLastTranscript: String
        let pastedLastTranscript: String
        let mainWindowUnavailableTitle: String
        let mainWindowUnavailableMessage: String
        let helpMessageTitle: String
        let helpMessageBody: String
        let historySectionTitle: String
        let modelEverydayRoleTitle: String
        let modelPrecisionRoleTitle: String
        let modelDeleteTitle: String
        let modelDeleteConfirmTitle: String
        let onboardingMenuTitle: String
        let onboardingWelcomeTitle: String
        let onboardingWelcomeBody: String
        let onboardingPrivacyNote: String
        let onboardingMicrophoneTitle: String
        let onboardingMicrophoneDetail: String
        let onboardingAccessibilityTitle: String
        let onboardingAccessibilityDetail: String
        let onboardingOpenSettingsTitle: String
        let onboardingGrantedTitle: String
        let onboardingDeniedTitle: String
        let onboardingPrepareTitle: String
        let onboardingPrepareBody: String
        let onboardingPrepareReadyTitle: String
        let onboardingPreparePermissionsHint: String
        let onboardingHowToTitle: String
        let onboardingHowToHoldTitle: String
        let onboardingHowToHoldDetail: String
        let onboardingHowToReleaseTitle: String
        let onboardingHowToReleaseDetail: String
        let onboardingHowToDictionaryTitle: String
        let onboardingHowToDictionaryDetail: String
        let onboardingContinueTitle: String
        let onboardingBackTitle: String
        let onboardingSkipTitle: String
        let onboardingFinishTitle: String

        func termCount(_ count: Int) -> String {
            "\(count) \(termsSuffix)"
        }

        func matchCount(_ count: Int) -> String {
            "\(count) \(matchesSuffix)"
        }

        func dictationCount(_ count: Int) -> String {
            "\(count) \(timesUnit)"
        }

        func dictatedUnits(_ count: Int) -> String {
            "\(formatCount(count)) \(dictatedUnitSuffix)"
        }

        func dictationCountSegments(_ count: Int) -> [MetricValueSegment] {
            [.number("\(count)"), .unit(timesUnit)]
        }

        func durationSegments(_ seconds: TimeInterval) -> [MetricValueSegment] {
            let totalMinutes = max(0, Int((seconds / 60).rounded()))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            let hourUnit = usesChineseReadinessCopy ? "时" : "hr"
            let minuteUnit = usesChineseReadinessCopy ? "分" : "min"

            if hours > 0 {
                return [
                    .number("\(hours)"), .unit(hourUnit),
                    .number("\(minutes)"), .unit(minuteUnit)
                ]
            }
            return [.number("\(minutes)"), .unit(minuteUnit)]
        }

        func dictatedUnitsSegments(_ count: Int) -> [MetricValueSegment] {
            guard count >= 10_000 else {
                return [.number("\(count)"), .unit(dictatedUnitSuffix)]
            }
            if usesChineseReadinessCopy {
                return [
                    .number(String(format: "%.1f", Double(count) / 10_000)),
                    .unit("万" + dictatedUnitSuffix)
                ]
            }
            return [
                .number(String(format: "%.1fk", Double(count) / 1_000)),
                .unit(dictatedUnitSuffix)
            ]
        }

        func modelRoleTitle(for model: VoiceInputModel) -> String {
            model.id == VoiceInputModel.qwen3ASR17B.id
                ? modelPrecisionRoleTitle
                : modelEverydayRoleTitle
        }

        func modelRoleDescription(for model: VoiceInputModel) -> String {
            if usesChineseReadinessCopy {
                return model.id == VoiceInputModel.qwen3ASR17B.id
                    ? "识别更准，适合复杂内容——但转写更慢、更占内存。"
                    : "默认推荐，速度快、占用小，适合日常本地听写。"
            }
            return model.id == VoiceInputModel.qwen3ASR17B.id
                ? "Higher accuracy for complex content — with slower transcription and higher memory use."
                : "Default recommendation: fast, lightweight, ideal for everyday local dictation."
        }

        func modelProvenance(for model: VoiceInputModel) -> String {
            usesChineseReadinessCopy
                ? "基于 \(model.displayName) 开源模型"
                : "Based on the open-source \(model.displayName) model"
        }

        func modelStorageUsage(_ formattedSize: String) -> String {
            usesChineseReadinessCopy
                ? "已占用 \(formattedSize)"
                : "Uses \(formattedSize) on disk"
        }

        func modelDownloadUsage(_ downloaded: String, total: String, source: String?) -> String {
            let sourceSuffix = source.map { " · \($0)" } ?? ""
            return usesChineseReadinessCopy
                ? "已下载 \(downloaded) / \(total)\(sourceSuffix)"
                : "Downloaded \(downloaded) / \(total)\(sourceSuffix)"
        }

        func modelDeleteConfirmMessage(for model: VoiceInputModel, formattedSize: String?) -> String {
            if usesChineseReadinessCopy {
                let sizeNote = formattedSize.map { "（\($0)）" } ?? ""
                return "将从磁盘删除 \(model.displayName)\(sizeNote) 的本地文件。之后可以随时重新下载。"
            }
            let sizeNote = formattedSize.map { " (\($0))" } ?? ""
            return "This removes the local files for \(model.displayName)\(sizeNote) from disk. You can download it again at any time."
        }

        func currentModelMenuTitle(_ modelName: String) -> String {
            "\(menuCurrentModelPrefix)\(modelName)"
        }

        func readinessStatusTitle(for status: ReadinessStatus) -> String {
            switch status {
            case .ready: return readinessStatusReadyTitle
            case .notReady: return readinessStatusNotReadyTitle
            case .preparing: return readinessStatusPreparingTitle
            case .needsRepair: return readinessStatusNeedsRepairTitle
            case .optional: return readinessStatusOptionalTitle
            case .failed: return readinessStatusFailedTitle
            case .unknown: return readinessStatusUnknownTitle
            }
        }

        func readinessStatusTitle(for check: ReadinessCheck) -> String {
            if check.status == .optional {
                if check.group == .performance {
                    return timesUnit == "次" ? "建议" : "Advisory"
                }
                if check.group == .models {
                    if check.id.hasSuffix("-warm") {
                        return check.locationTarget == .selectedModel
                            ? (timesUnit == "次" ? "未准备" : "Not Prepared")
                            : (timesUnit == "次" ? "未选择" : "Not Selected")
                    }
                    return modelNotInstalled
                }
            }
            return readinessStatusTitle(for: check.status)
        }

        func modelSuitabilityDetail(for recommendation: ModelSuitabilityRecommendation) -> String {
            guard usesChineseReadinessCopy else {
                return recommendation.detail
            }

            let memory = recommendation.physicalMemoryGB.map { "\($0) GB" } ?? "当前"
            switch recommendation.level {
            case .stronglyDiscouraged:
                return "这台 Mac 检测到 \(memory) 统一内存。Flowtype 建议日常听写使用 Qwen3-ASR 0.6B。Qwen3-ASR 1.7B 可能明显变慢，尤其是第一次听写、切换模型后和较长录音。"
            case .allowedWithWarning:
                return "这台 Mac 检测到 \(memory) 统一内存。Qwen3-ASR 1.7B 可以改善复杂音频，但可能会明显慢于 0.6B。"
            case .reasonableOptIn:
                return "Qwen3-ASR 1.7B 可以作为更高准确率的可选模式，适合愿意用速度换准确率的场景。"
            case .suitable:
                return "这台 Mac 适合在更看重准确率时使用 Qwen3-ASR 1.7B。"
            case .recommended:
                return "Qwen3-ASR 0.6B 是日常本地听写的推荐模型。"
            }
        }

        func readinessSetupSummaryTitle(for summary: ReadinessSetupSummary) -> String {
            if timesUnit == "次" {
                return summary.isComplete
                    ? readinessSetupCompleteTitle
                    : "Flowtype 还需要完成 \(summary.requiredIssueCount) 项设置"
            }
            return summary.isComplete
                ? readinessSetupCompleteTitle
                : "Flowtype needs \(summary.requiredIssueCount) setup steps"
        }

        var readinessCheckingTitle: String {
            timesUnit == "次" ? "正在检查 Flowtype…" : "Checking Flowtype…"
        }

        var readinessCheckingDetail: String {
            timesUnit == "次"
                ? "正在确认权限、当前引擎和本地运行环境。"
                : "Confirming permissions, the selected engine, and the local runtime."
        }

        var readinessPreparingDetail: String {
            timesUnit == "次"
                ? "Flowtype 正在完成本地准备；当前页面会保持稳定并自动更新。"
                : "Flowtype is finishing local preparation. This page will stay in place and update automatically."
        }

        var readinessRepairRequiredTitle: String {
            timesUnit == "次" ? "Flowtype 需要修复" : "Flowtype needs repair"
        }

        var readinessRepairRequiredDetail: String {
            timesUnit == "次"
                ? "至少一项必要组件无法通过检查。先使用下面的恢复操作，具体证据仍保留在技术诊断中。"
                : "At least one required component did not pass its checks. Use the recovery action below; the evidence remains in Technical Diagnostics."
        }

        var readinessNeedsActionTitle: String {
            timesUnit == "次" ? "需要处理" : "Needs Action"
        }

        var readinessEverydayRequirementsTitle: String {
            timesUnit == "次" ? "日常使用条件" : "Everyday Requirements"
        }

        var readinessRefreshFailedDetail: String {
            timesUnit == "次"
                ? "暂时无法刷新；仍显示上一次已确认的状态。"
                : "Refresh is temporarily unavailable. The last confirmed state is still shown."
        }

        func readinessTaskSummaryTitle(count: Int) -> String {
            timesUnit == "次"
                ? "Flowtype 还需要完成 \(count) 项设置"
                : "Flowtype needs \(count) setup \(count == 1 ? "step" : "steps")"
        }

        func readinessTaskSummaryDetail(for tasks: [ReadinessTask]) -> String {
            guard let first = tasks.first else { return readinessCheckingDetail }
            if timesUnit == "次" {
                switch first.kind {
                case .grantMicrophone, .grantAccessibility, .grantSpeechRecognition:
                    return "先完成必要的 macOS 授权，然后即可继续准备。"
                case .installSelectedModel:
                    return "当前 Qwen 模型尚未安装；点击一键准备后会自动开始下载。"
                case .prepareSelectedModel:
                    return "当前 Qwen 模型需要重新准备。"
                case .repairLocalRuntime:
                    return "本地运行环境需要修复后才能使用 Qwen 听写。"
                case .reinstallApplication:
                    return "当前应用包不完整，需要从完整安装包重新安装。"
                }
            }
            switch first.kind {
            case .grantMicrophone, .grantAccessibility, .grantSpeechRecognition:
                return "Grant the required macOS permissions, then continue setup."
            case .installSelectedModel:
                return "The selected Qwen model is not installed. One-click setup will download it automatically."
            case .prepareSelectedModel:
                return "The selected Qwen model needs to be prepared again."
            case .repairLocalRuntime:
                return "The local runtime needs repair before Qwen dictation can work."
            case .reinstallApplication:
                return "This app bundle is incomplete and must be reinstalled from a complete package."
            }
        }

        func readinessReadyDetail(for context: ReadinessContext) -> String {
            if context.engine == .appleSpeech {
                return timesUnit == "次"
                    ? "Apple Speech 已准备好，可以按住 Fn 开始听写。"
                    : "Apple Speech is ready. Hold Fn to start dictating."
            }
            let model = VoiceInputModel.model(for: context.selectedModelID)
            let role = modelRoleTitle(for: model)
            return timesUnit == "次"
                ? "本地模型「\(role)」已准备好，按住 Fn 开始听写。"
                : "Local model \"\(role)\" is ready. Hold Fn to start dictating."
        }

        func readinessPresentationTitle(_ phase: ReadinessPresentationPhase, count: Int) -> String {
            switch phase {
            case .checking: return readinessCheckingTitle
            case .ready: return readinessSetupCompleteTitle
            case .needsSetup: return readinessTaskSummaryTitle(count: count)
            case .preparing: return readinessStatusPreparingTitle
            case .repairRequired: return readinessRepairRequiredTitle
            }
        }

        func readinessPresentationDetail(
            _ presentation: ReadinessPresentation,
            context: ReadinessContext
        ) -> String {
            switch presentation.phase {
            case .checking: return readinessCheckingDetail
            case .ready: return readinessReadyDetail(for: context)
            case .needsSetup: return readinessTaskSummaryDetail(for: presentation.tasks)
            case .preparing: return readinessPreparingDetail
            case .repairRequired: return readinessRepairRequiredDetail
            }
        }

        func readinessCheckDetailsTitle(count: Int) -> String {
            timesUnit == "次" ? "检查详情（\(count)）" : "Check Details (\(count))"
        }

        func readinessPermissionsReadyDetail(for context: ReadinessContext) -> String {
            if context.engine == .appleSpeech {
                return timesUnit == "次"
                    ? "权限：麦克风、辅助功能和语音识别已授权"
                    : "Permissions: Microphone, Accessibility, and Speech Recognition are ready"
            }
            return timesUnit == "次"
                ? "权限：麦克风和辅助功能已授权"
                : "Permissions: Microphone and Accessibility are ready"
        }

        func readinessEngineReadyDetail(for context: ReadinessContext) -> String {
            if context.engine == .appleSpeech {
                return timesUnit == "次" ? "当前引擎：Apple Speech 已准备好" : "Current engine: Apple Speech is ready"
            }
            let model = VoiceInputModel.model(for: context.selectedModelID)
            let role = modelRoleTitle(for: model)
            return timesUnit == "次"
                ? "当前引擎：本地「\(role)」模型已准备好"
                : "Current engine: local \"\(role)\" model is ready"
        }

        func readinessEngineCheckingDetail(for context: ReadinessContext) -> String {
            if context.engine == .appleSpeech {
                return timesUnit == "次" ? "当前引擎：正在确认 Apple Speech" : "Current engine: Checking Apple Speech"
            }
            let model = VoiceInputModel.model(for: context.selectedModelID)
            let role = modelRoleTitle(for: model)
            return timesUnit == "次"
                ? "当前引擎：正在确认本地「\(role)」模型"
                : "Current engine: checking the local \"\(role)\" model"
        }

        func readinessEnginePreparingDetail(for context: ReadinessContext) -> String {
            if context.engine == .appleSpeech {
                return timesUnit == "次" ? "当前引擎：正在准备 Apple Speech" : "Current engine: Preparing Apple Speech"
            }
            let model = VoiceInputModel.model(for: context.selectedModelID)
            let role = modelRoleTitle(for: model)
            return timesUnit == "次"
                ? "当前引擎：正在准备本地「\(role)」模型"
                : "Current engine: preparing the local \"\(role)\" model"
        }

        func readinessTaskTitle(_ kind: ReadinessTaskKind, context: ReadinessContext) -> String {
            let chinese = timesUnit == "次"
            switch kind {
            case .grantMicrophone: return chinese ? "允许使用麦克风" : "Allow Microphone Access"
            case .grantAccessibility: return chinese ? "允许使用辅助功能" : "Allow Accessibility Access"
            case .grantSpeechRecognition: return chinese ? "允许使用语音识别" : "Allow Speech Recognition"
            case .installSelectedModel:
                let model = VoiceInputModel.model(for: context.selectedModelID)
                let role = modelRoleTitle(for: model)
                return chinese
                    ? "下载「\(role)」模型（\(model.displayName)）"
                    : "Download the \(role) model (\(model.displayName))"
            case .prepareSelectedModel: return chinese ? "重新准备当前模型" : "Prepare the Selected Model"
            case .repairLocalRuntime: return chinese ? "修复本地运行环境" : "Repair the Local Runtime"
            case .reinstallApplication: return chinese ? "重新安装 Flowtype" : "Reinstall Flowtype"
            }
        }

        func readinessTaskDetail(_ kind: ReadinessTaskKind, context: ReadinessContext) -> String {
            let chinese = timesUnit == "次"
            switch kind {
            case .grantMicrophone:
                return chinese ? "用于录制听写音频。" : "Required to record dictation audio."
            case .grantAccessibility:
                return chinese ? "用于监听 Fn 并把转写结果粘贴到当前应用。" : "Required to listen for Fn and paste into the current app."
            case .grantSpeechRecognition:
                return chinese ? "只在使用 Apple Speech 时需要。" : "Required only when using Apple Speech."
            case .installSelectedModel:
                let model = VoiceInputModel.model(for: context.selectedModelID)
                return chinese
                    ? "点击“一键准备 Flowtype”即确认下载当前所选的 \(model.displayName) 本地模型。"
                    : "Clicking Prepare Flowtype confirms the download of the selected \(model.displayName) local model."
            case .prepareSelectedModel:
                return chinese ? "模型已安装，但当前 Helper 无法确认它已就绪。" : "The model is installed, but the helper cannot confirm it is ready."
            case .repairLocalRuntime:
                return chinese ? "修复 Flowtype 在本机使用的 Helper 和运行文件。" : "Repair the helper and runtime files Flowtype uses on this Mac."
            case .reinstallApplication:
                return chinese
                    ? "应用包缺少必要文件。打开应用位置后，请用完整安装包重新安装；技术诊断中保留了具体证据。"
                    : "Required app files are missing. Open the app location, then reinstall from a complete package; Technical Diagnostics retains the evidence."
            }
        }

        func readinessTaskSymbol(_ kind: ReadinessTaskKind) -> String {
            switch kind {
            case .grantMicrophone: return "mic.fill"
            case .grantAccessibility: return "figure.wave"
            case .grantSpeechRecognition: return "waveform"
            case .installSelectedModel: return "arrow.down.circle.fill"
            case .prepareSelectedModel: return "flame.fill"
            case .repairLocalRuntime: return "gearshape.2.fill"
            case .reinstallApplication: return "shippingbox.fill"
            }
        }

        func readinessPrimaryActionTitle(_ action: ReadinessActionKind) -> String {
            action == .reinstallFlowtypeApp ? readinessReinstallFlowtypeTitle : readinessPrepareFlowtypeTitle
        }

        func readinessSetupSummaryDetail(for summary: ReadinessSetupSummary) -> String {
            if summary.isComplete {
                return timesUnit == "次"
                    ? "你可以直接使用 Fn 开始本地 Qwen 听写。"
                    : "You can use Fn for local Qwen dictation."
            }

            if timesUnit == "次" {
                var parts: [String] = []
                if summary.blockingCount > 0 { parts.append("需要重新安装完整的 Flowtype") }
                if summary.repairableCount > 0 { parts.append("可以修复本地运行环境") }
                if summary.manualCount > 0 { parts.append("需要完成 macOS 授权") }
                return parts.joined(separator: "，") + "。"
            }

            var parts: [String] = []
            if summary.blockingCount > 0 { parts.append("reinstall the complete Flowtype app") }
            if summary.repairableCount > 0 { parts.append("repair the local runtime") }
            if summary.manualCount > 0 { parts.append("grant macOS permissions") }
            return parts.joined(separator: ", ") + "."
        }

        func readinessCheckTitle(for check: ReadinessCheck) -> String {
            guard usesChineseReadinessCopy else {
                return check.title
            }

            switch check.id {
            case "app-resources": return "应用资源"
            case "app-binary": return "Flowtype 应用程序"
            case "bundled-uv": return "内置 uv"
            case "bundled-qwen-helper": return "内置 Qwen helper"
            case "helper-manifest": return "Helper 版本清单"
            case "flowtype-icon": return "Flowtype 图标"
            case "qwen-logo": return "Qwen 标志"
            case "application-support-root": return "Application Support 文件夹"
            case "local-helper-copy": return "本地 Qwen helper 副本"
            case "local-bundled-uv": return "内置 uv 运行时"
            case "selected-model": return "已选择模型"
            case "apple-silicon": return "Apple Silicon"
            case "memory-tier": return "内存档位"
            case "selected-model-recommendation": return "模型建议"
            case "helper-memory": return "Helper 内存"
            case "last-transcription-timing": return "上次转写耗时"
            case "microphone-permission": return "麦克风"
            case "accessibility-permission": return "辅助功能"
            case "speech-recognition-permission": return "语音识别"
            default:
                if check.id.hasPrefix("model-"), check.id.hasSuffix("-warm") {
                    return "\(check.title.replacingOccurrences(of: " preload status", with: "")) 准备状态"
                }
                if check.id.hasPrefix("helper-model-status-") {
                    return "\(check.title.replacingOccurrences(of: " helper status", with: "")) helper 状态"
                }
                return check.title
            }
        }

        func readinessCheckDetail(for check: ReadinessCheck) -> String {
            guard usesChineseReadinessCopy else {
                return check.detail
            }

            switch check.id {
            case "app-resources":
                return "Flowtype 找不到应用包内资源。"
            case "app-binary":
                return check.status == .ready
                    ? "Flowtype 可执行文件已包含在应用包内。"
                    : "这个 Flowtype 应用包不完整。请从 DMG 重新安装 Flowtype。"
            case "bundled-uv":
                return check.status == .ready
                    ? "内置 uv 已包含在应用包内，并且可以执行。"
                    : "这个 Flowtype 应用包不完整。请从 DMG 重新安装 Flowtype。"
            case "bundled-qwen-helper":
                return check.status == .ready
                    ? "内置 helper 源码已包含在应用包内。"
                    : "内置 helper 文件不完整。请从 DMG 重新安装 Flowtype。"
            case "helper-manifest":
                return readinessManifestDetail(for: check)
            case "flowtype-icon":
                return check.status == .ready
                    ? "应用图标资源已包含在应用包内。"
                    : "这个 Flowtype 应用包不完整。请从 DMG 重新安装 Flowtype。"
            case "qwen-logo":
                return check.status == .ready
                    ? "Qwen 标志资源已包含在应用包内。"
                    : "这个 Flowtype 应用包不完整。请从 DMG 重新安装 Flowtype。"
            case "application-support-root":
                return check.status == .ready
                    ? "Flowtype 可以使用自己的 Application Support 文件夹。"
                    : "需要先准备 Flowtype 在 Application Support 里的本地运行目录。"
            case "local-helper-copy":
                return check.status == .ready
                    ? "本地 helper 副本已准备好。"
                    : "使用 Qwen 听写前，需要准备或修复本地 helper 副本。"
            case "local-bundled-uv":
                return check.status == .ready
                    ? "Flowtype 可以用内置 uv 启动 helper。"
                    : "独立安装的 Flowtype 需要应用包内置 uv。"
            case "selected-model":
                return selectedModelName(from: check.detail).map { "\($0) 已被选为本地听写模型。" }
                    ?? "当前模型已被选为本地听写模型。"
            case let id where id.hasPrefix("model-") && id.hasSuffix("-warm"):
                return readinessModelWarmDetail(for: check)
            case let id where id.hasPrefix("model-"):
                return readinessModelInstallDetail(for: check)
            case let id where id.hasPrefix("helper-model-status-"):
                return check.status == .optional
                    ? "Flowtype 无法从本地 helper 刷新这个可选模型的状态。"
                    : "Flowtype 无法从本地 helper 刷新已选择模型的状态。"
            case "apple-silicon":
                return check.status == .ready
                    ? "\(processorName(from: check.detail) ?? "这台 Mac") 受支持。"
                    : "Flowtype 本地 Qwen 听写专为 Apple Silicon 设计。"
            case "memory-tier":
                return "\(leadingNumber(from: check.detail) ?? "当前") GB 统一内存已检测到。"
            case "selected-model-recommendation":
                if let recommendation = check.modelSuitabilityRecommendation {
                    return modelSuitabilityDetail(for: recommendation)
                }
                if check.detail.contains("0.6B is recommended") {
                    return "建议在这台 Mac 上使用 Qwen3-ASR 0.6B，以获得更快听写速度。"
                }
                return "\(selectedModelName(from: check.detail) ?? "当前模型") 符合这台 Mac 的内存档位。"
            case "helper-memory":
                if let mb = helperMemoryMB(from: check.detail) {
                    return "Flowtype helper 进程正在使用 \(mb) MB RSS。"
                }
                return "暂时还没有 helper 内存采样。"
            case "last-transcription-timing":
                return readinessTimingDetail(from: check.detail)
            case "microphone-permission":
                return check.status == .ready
                    ? "Flowtype 可以录制音频。"
                    : "Flowtype 需要麦克风权限来录制听写音频。"
            case "accessibility-permission":
                return check.status == .ready
                    ? "Flowtype 可以监听 Fn 并粘贴转写结果。"
                    : "Flowtype 需要辅助功能权限来监听 Fn 并粘贴文本。"
            case "speech-recognition-permission":
                return check.status == .ready
                    ? "需要时可以使用 Apple Speech 备用转写。"
                    : "语音识别权限只在使用 Apple Speech 备用转写时需要。"
            default:
                return check.detail
            }
        }

        func readinessCheckStatusMessage(for check: ReadinessCheck) -> String? {
            guard let message = check.statusMessage else {
                return nil
            }
            guard usesChineseReadinessCopy else {
                return message
            }

            switch check.id {
            case "app-resources": return "应用包资源不可用。"
            case "app-binary": return "应用程序可执行文件缺失。"
            case "bundled-uv", "local-bundled-uv": return "内置 uv 缺失或不可执行。"
            case "bundled-qwen-helper": return "内置 helper 不完整。"
            case "helper-manifest":
                if message.contains("missing") { return "Helper 清单缺失。" }
                if message.contains("uv.lock") { return "Helper 清单与 uv.lock 不匹配。" }
                return "Helper 清单无效。"
            case "microphone-permission": return "麦克风权限已被拒绝。"
            case "accessibility-permission": return "辅助功能权限已被拒绝。"
            case "speech-recognition-permission": return "语音识别权限已被拒绝。"
            case "apple-silicon": return "不支持的芯片架构。"
            case let id where id.hasPrefix("helper-model-status-"):
                return "无法刷新已选择的 Qwen 模型状态。"
            default:
                return message
            }
        }

        func duration(_ seconds: TimeInterval) -> String {
            let totalMinutes = max(0, Int((seconds / 60).rounded()))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60

            if timesUnit == "次" {
                if hours > 0 {
                    return "\(hours) 时 \(minutes) 分"
                }
                if minutes > 0 {
                    return "\(minutes) 分"
                }
                return "0 分"
            }

            if hours > 0 {
                return "\(hours) hr \(minutes) min"
            }
            if minutes > 0 {
                return "\(minutes) min"
            }
            return "0 min"
        }

        private func formatCount(_ count: Int) -> String {
            guard count >= 10_000 else {
                return "\(count)"
            }
            let value = Double(count) / 10_000
            return timesUnit == "次"
                ? String(format: "%.1f万", value)
                : String(format: "%.1fk", Double(count) / 1_000)
        }

        private var usesChineseReadinessCopy: Bool {
            timesUnit == "次"
        }

        private func readinessManifestDetail(for check: ReadinessCheck) -> String {
            guard check.status == .ready else {
                if check.detail.contains("uv.lock") {
                    return "内置 helper 清单与 uv.lock 不匹配。请从 DMG 重新安装 Flowtype。"
                }
                if check.detail.contains("could not be decoded") {
                    return "内置 helper 清单无法解析。请从 DMG 重新安装 Flowtype。"
                }
                return "这个 Flowtype 应用包不完整。请从 DMG 重新安装 Flowtype。"
            }
            return "内置 helper 清单已包含在应用包内。"
        }

        private func readinessModelInstallDetail(for check: ReadinessCheck) -> String {
            switch check.status {
            case .ready:
                return "模型缓存已保存在 Flowtype 管理的 Application Support 文件夹中。"
            case .preparing:
                if let percent = percentage(from: check.detail) {
                    return "Flowtype 正在准备本地 Qwen 模型：\(percent)。"
                }
                return "Flowtype 正在准备本地 Qwen 模型。"
            case .needsRepair:
                return "模型缓存看起来不完整，建议在模型页重新安装。"
            case .notReady, .optional:
                return "使用本地 Qwen 听写前，请先在模型页下载这个模型。"
            default:
                return check.detail
            }
        }

        private func readinessModelWarmDetail(for check: ReadinessCheck) -> String {
            switch check.status {
            case .ready:
                return "已选择的 Qwen 模型已加载，可以进行更低延迟的听写。"
            case .optional:
                return "Flowtype 会在模型下载完成和每次启动后自动准备已选择模型；如果准备还没完成，第一次 Fn 听写可能会稍慢。"
            case .failed:
                return "Qwen 模型自动准备失败。第一次 Fn 听写仍会尝试重新准备。"
            default:
                return "Flowtype 正在后台准备已选择的 Qwen 模型。"
            }
        }

        private func readinessTimingDetail(from detail: String) -> String {
            guard detail.contains("Last run:") else {
                return "还没有记录本地 Qwen 转写耗时样本。"
            }
            let values = integerValues(from: detail)
            guard values.count >= 4 else {
                return detail
            }
            return "上次运行：helper \(values[0]) ms，状态探测 \(values[1]) ms，解码 \(values[2]) ms，后处理 \(values[3]) ms。"
        }

        private func selectedModelName(from text: String) -> String? {
            if text.contains("Qwen3-ASR 0.6B") {
                return "Qwen3-ASR 0.6B"
            }
            if text.contains("Qwen3-ASR 1.7B") {
                return "Qwen3-ASR 1.7B"
            }
            return nil
        }

        private func processorName(from detail: String) -> String? {
            guard let range = detail.range(of: " is supported.") else {
                return nil
            }
            return String(detail[..<range.lowerBound])
        }

        private func leadingNumber(from text: String) -> String? {
            integerValues(from: text).first.map(String.init)
        }

        private func helperMemoryMB(from text: String) -> Int? {
            integerValues(from: text).first
        }

        private func percentage(from text: String) -> String? {
            integerValues(from: text).first.map { "\($0)%" }
        }

        private func integerValues(from text: String) -> [Int] {
            var values: [Int] = []
            var current = ""

            for character in text {
                if character.isNumber {
                    current.append(character)
                } else if !current.isEmpty {
                    if let value = Int(current) {
                        values.append(value)
                    }
                    current = ""
                }
            }

            if !current.isEmpty, let value = Int(current) {
                values.append(value)
            }

            return values
        }

    }

    static func texts(for language: UILanguage) -> Texts {
        switch language {
        case .chinese:
            return Texts(
                homeTitle: "主页",
                dictionaryTitle: "词典",
                modelsTitle: "模型",
                readinessTitle: "准备状态",
                preferencesTitle: "转写与外观",
                settingsTitle: "设备与存储",
                helpTitle: "帮助",
                mainHeadline: "回到心流 - Flowtype",
                mainSubtitle: "本地优先的听写工具，适合提示词、笔记和中英文混合开发术语。",
                todayTitle: "今天",
                yesterdayTitle: "昨天",
                olderTitle: "更早",
                saveTranscriptHistory: "保存转写历史",
                historyEnabledDetail: "成功转写会保存在本地。",
                historyDisabledDetail: "新的转写不会加入本地历史。",
                historyOffNotice: "历史已关闭。之后的转写不会保存到本地历史。",
                emptyHistoryEnabled: "使用 Fn 听写后，最近转写会显示在这里。",
                emptyHistoryDisabled: "现有本地历史为空。关闭历史时，新的转写不会被保存。",
                openDictionaryHelp: "打开词典热词",
                clearHistoryTitle: "清空历史",
                clearHistoryHelp: "删除本地转写历史",
                moreActionsTitle: "更多操作",
                clearHistoryConfirmationTitle: "确定要清空转写历史吗？",
                clearHistoryConfirmationMessage: "这会永久删除所有本地转写历史。",
                clearHistoryErrorTitle: "无法清空历史",
                cancel: "取消",
                ok: "好",
                dictionarySubtitle: "热词可以帮助本地 Qwen 听写更稳定地保留工具名、人名和中英文短语。",
                modelsSubtitle: "下载并选择本地听写模型。下载完成后，Fn 听写会自动使用它。",
                permissionsReadyDetail: "现在可以按住 Fn 本地听写，并自动粘贴到当前应用。",
                permissionsExitWarningTitle: "Flowtype 还不能正常使用",
                permissionsExitWarningMessage: "没有麦克风和辅助功能权限，Flowtype 不能录音、监听 Fn 或自动粘贴转写结果。你可以先继续浏览，之后回到“准备状态”完成授权。",
                readinessSubtitle: "查看 Flowtype 是否可以开始听写，并处理权限、模型和本地运行问题。",
                readinessRefreshTitle: "刷新",
                readinessPrepareFlowtypeTitle: "一键准备 Flowtype",
                readinessSetupCompleteTitle: "Flowtype 已准备好",
                readinessSetupNeedsStepsTitle: "Flowtype 还需要完成设置",
                readinessSetupBlockedTitle: "需要重新安装完整的 Flowtype",
                readinessPrepareRuntimeTitle: "准备运行环境",
                readinessRepairHelperTitle: "修复 Helper",
                readinessReinstallFlowtypeTitle: "打开应用位置",
                readinessRepairLocalRuntimeTitle: "修复本地运行环境",
                readinessOpenLocationTitle: "打开位置",
                readinessDownloadDefaultModelTitle: "下载 0.6B 模型",
                readinessRetryPreloadTitle: "重试准备模型",
                readinessDefaultModelConsentTitle: "下载本地 Qwen 模型",
                readinessDefaultModelConsentMessage: "Flowtype 需要一个本地 Qwen 模型才能离线听写。是否现在下载 Qwen3-ASR 0.6B？",
                readinessFirstRunPromptTitle: "先把 Flowtype 准备好",
                readinessFirstRunPromptMessage: "Flowtype 需要完成麦克风和辅助功能授权，并下载默认 Qwen3-ASR 0.6B 模型，之后就可以用 Fn 开始本地听写。",
                readinessFirstRunPromptPrimaryTitle: "开始准备并下载",
                readinessFirstRunPromptLaterTitle: "稍后",
                readinessWarmModelTitle: "准备模型",
                readinessCopyDiagnosticsTitle: "复制诊断",
                readinessCopiedDiagnosticsTitle: "已复制诊断",
                readinessDiagnosticsTitle: "诊断",
                readinessGenerateDiagnosticsTitle: "生成诊断文件",
                readinessOpenDiagnosticsFolderTitle: "打开诊断文件夹",
                readinessGeneratedDiagnosticsTitle: { fileName in "已生成诊断文件：\(fileName)" },
                readinessFailedTitle: "操作失败",
                readinessStatusReadyTitle: "就绪",
                readinessStatusNotReadyTitle: "未就绪",
                readinessStatusPreparingTitle: "准备中",
                readinessStatusNeedsRepairTitle: "需要修复",
                readinessStatusOptionalTitle: "可选",
                readinessStatusFailedTitle: "失败",
                readinessStatusUnknownTitle: "未知",
                readinessGroupAppBundleTitle: "应用包",
                readinessGroupLocalRuntimeTitle: "本地运行环境",
                readinessGroupModelsTitle: "模型",
                readinessGroupPermissionsTitle: "权限",
                readinessGroupPerformanceTitle: "性能",
                readinessAdvancedDiagnosticsTitle: "高级诊断",
                readinessRequestMicrophoneTitle: "麦克风",
                readinessOpenAccessibilitySettingsTitle: "辅助功能",
                readinessRequestSpeechRecognitionTitle: "语音识别",
                readinessReinstallAppTitle: "重新安装",
                readinessRestartHelperTitle: "重启 Helper",
                modelLocalBadge: "本地",
                modelSelectedBadge: "已选择",
                modelNotInstalled: "未下载",
                modelReady: "可使用",
                modelDownloading: "下载中",
                modelFailed: "下载失败",
                modelNeedsRepair: "需要修复",
                modelPathTitle: "模型位置",
                modelPathDetail: "模型会保存到此应用管理的本地目录。",
                modelDownloadTitle: "下载模型",
                modelRepairTitle: "重新安装",
                modelUseTitle: "使用此模型",
                modelDownloadedTitle: "已下载",
                modelInUseTitle: "正在使用",
                modelOpenFolderTitle: "打开文件夹",
                modelCopyPathTitle: "复制路径",
                modelOpenDictionaryTitle: "打开词典热词",
                modelRefreshTitle: "刷新",
                modelHotwordsNote: "词典热词会在听写时自动传给本地 Qwen，不需要额外设置。",
                modelSuitabilityWarningTitle: "1.7B 在这台 Mac 上可能较慢",
                modelSuitabilityUseSmallModelTitle: "使用 0.6B",
                modelSuitabilityContinueTitle: "仍然继续",
                modelDownloadHelp: "下载并准备本地 Qwen 模型",
                modelRepairHelp: "删除不完整的模型缓存并重新下载",
                modelUseHelp: "选择此模型作为本地听写模型",
                modelOpenFolderHelp: "在 Finder 中打开模型文件夹",
                modelCopyPathHelp: "复制模型文件夹路径",
                modelErrorTitle: "模型无法更新",
                modelPreparingMessage: "准备本地模型...",
                modelRepairMessage: "检测到不完整的模型缓存。请重新安装，Flowtype 会先清理旧缓存再重新下载。",
                termsSuffix: "个词条",
                addHotwordPlaceholder: "添加新热词",
                addWordTitle: "添加词条",
                searchHotwordsPlaceholder: "搜索热词",
                manageHotwordsTitle: "管理热词",
                matchesSuffix: "个匹配",
                deleteHotwordHelp: "删除热词",
                deleteHotwordTitle: "删除热词",
                dictionaryErrorTitle: "词典无法更新",
                hotwordAlreadyExists: "这个词条已经存在，已为你显示对应结果。",
                rowExpand: "展开",
                rowCollapse: "收起",
                rowCopied: "已复制",
                rowCopy: "复制",
                rowCopyTranscript: "复制转写文本",
                rowPaste: "粘贴",
                rowPasteAgain: "再次粘贴",
                rowPossibleTruncation: "可能不完整",
                rowRetrySegmented: "重新分段转写",
                rowRetryingSegmented: "正在重试",
                rowRetrySegmentedSucceeded: "已重新转写",
                rowRetrySegmentedFailed: "重试失败",
                rowTranscriptionFailed: "转写失败",
                rowRecoverableFailureDetail: "已保留录音，可重新转写",
                rowRetryTranscription: "重新转写",
                rowRecordingExpired: "录音已过期",
                capsuleRecoverableTranscriptionFailed: "转写失败，主页可重试",
                dictationCountTitle: "听写次数",
                recordingDurationTitle: "累计口述时间",
                dictatedUnitsTitle: "口述字数",
                savedTimeTitle: "节省时间",
                localEstimateNote: "由本地算法估算",
                timesUnit: "次",
                dictatedUnitSuffix: "字",
                menuStatusStarting: "状态：启动中",
                menuEngine: "引擎：Qwen3-ASR 本地",
                menuFallback: "备用：Apple Speech",
                menuShowHome: "显示主页",
                menuShowDictionary: "显示词典",
                menuShowPreferences: "显示转写与外观",
                menuCurrentModelPrefix: "模型：",
                menuSettings: "设备与存储...",
                menuHelp: "帮助...",
                menuSetupStatus: "准备状态...",
                menuPasteLastTranscript: "粘贴上次转写",
                menuQuit: "退出",
                noTranscriptYet: "还没有转写内容",
                copiedLastTranscript: "已复制上次转写",
                pastedLastTranscript: "已粘贴上次转写",
                mainWindowUnavailableTitle: "Flowtype 存储不可用",
                mainWindowUnavailableMessage: "主窗口无法打开，因为本地热词或历史存储还没有准备好。",
                helpMessageTitle: "Flowtype 帮助",
                helpMessageBody: """
                按住 Fn 说话，松开 Fn 后会用当前本地模型转写，并自动复制、粘贴到你刚才使用的应用里。

                主页会在开启历史时显示本地转写历史。若某条长录音疑似只转出一小段，历史里会标记“可能不完整”，你可以点重新分段转写。最近几条录音会短暂保留在本机，只用于这个手动重试。

                词典热词会帮助 Qwen 保留人名、工具名、课程代码和中英文短语。模型页可以下载、切换 Qwen3-ASR 0.6B / 1.7B；“转写与外观”可以调整主题、数字格式、数学符号和填充词清理。

                在“准备状态”页面开启麦克风和辅助功能；只有使用 Apple Speech 备用转写时才需要语音识别权限。使用“设备与存储”管理麦克风、历史和本地文件位置。转写历史与为手动重试短暂保留的录音都只保存在这台 Mac 本地。
                """,
                historySectionTitle: "转写历史",
                modelEverydayRoleTitle: "日常听写",
                modelPrecisionRoleTitle: "精准听写",
                modelDeleteTitle: "删除模型",
                modelDeleteConfirmTitle: "删除这个模型？",
                onboardingMenuTitle: "新手引导…",
                onboardingWelcomeTitle: "回到心流",
                onboardingWelcomeBody: "Flowtype 是本地优先的语音听写工具：按住 Fn 说话，松开即转写，结果会自动粘贴到你正在使用的应用。",
                onboardingPrivacyNote: "所有识别都在这台 Mac 上完成，录音和文字不会上传。",
                onboardingMicrophoneTitle: "麦克风",
                onboardingMicrophoneDetail: "用于录制你的声音。",
                onboardingAccessibilityTitle: "辅助功能",
                onboardingAccessibilityDetail: "用于把转写结果自动粘贴到当前应用。",
                onboardingOpenSettingsTitle: "打开系统设置",
                onboardingGrantedTitle: "已开启",
                onboardingDeniedTitle: "已被拒绝，请在系统设置中开启。",
                onboardingPrepareTitle: "准备 Flowtype",
                onboardingPrepareBody: "一键完成全部准备：开启麦克风与辅助功能权限，并下载默认的 Qwen3-ASR 0.6B 本地模型（约 1.9 GB，仅首次需要，也可以稍后在“准备状态”页完成）。",
                onboardingPrepareReadyTitle: "已准备就绪",
                onboardingPreparePermissionsHint: "需要你在系统设置中完成授权，返回本窗口会自动继续。",
                onboardingHowToTitle: "开始听写",
                onboardingHowToHoldTitle: "按住 Fn 说话",
                onboardingHowToHoldDetail: "在任何应用里按住 Fn 键开始录音。",
                onboardingHowToReleaseTitle: "松开 Fn 完成",
                onboardingHowToReleaseDetail: "松开后自动转写，并粘贴到你刚才使用的应用。",
                onboardingHowToDictionaryTitle: "词典让专有名词更准",
                onboardingHowToDictionaryDetail: "把人名、术语加入词典，转写时会优先保留它们。",
                onboardingContinueTitle: "继续",
                onboardingBackTitle: "上一步",
                onboardingSkipTitle: "跳过引导",
                onboardingFinishTitle: "开始使用 Flowtype"
            )
        case .english:
            return Texts(
                homeTitle: "Home",
                dictionaryTitle: "Dictionary",
                modelsTitle: "Models",
                readinessTitle: "Setup & Status",
                preferencesTitle: "Transcription & Appearance",
                settingsTitle: "Device & Storage",
                helpTitle: "Help",
                mainHeadline: "Back to Flow - Flowtype",
                mainSubtitle: "Local-first dictation for prompts, notes, and mixed Chinese-English developer terms.",
                todayTitle: "Today",
                yesterdayTitle: "Yesterday",
                olderTitle: "Older",
                saveTranscriptHistory: "Save transcript history",
                historyEnabledDetail: "Successful transcripts are saved locally.",
                historyDisabledDetail: "New transcripts are not added to local history.",
                historyOffNotice: "History is off. Future transcripts will not be saved to local history.",
                emptyHistoryEnabled: "Recent transcripts will appear here after you use Fn dictation.",
                emptyHistoryDisabled: "Existing local history is empty. New transcripts will not be saved while history is off.",
                openDictionaryHelp: "Open dictionary hotwords",
                clearHistoryTitle: "Clear History",
                clearHistoryHelp: "Delete local transcript history",
                moreActionsTitle: "More Actions",
                clearHistoryConfirmationTitle: "Clear transcript history?",
                clearHistoryConfirmationMessage: "This permanently deletes all local transcript history.",
                clearHistoryErrorTitle: "Could not clear history",
                cancel: "Cancel",
                ok: "OK",
                dictionarySubtitle: "Hotwords help local Qwen dictation keep your tools, names, and mixed-language phrases intact.",
                modelsSubtitle: "Download and select the local dictation model. Fn dictation will use it after setup.",
                permissionsReadyDetail: "You can hold Fn for local dictation and paste into the current app.",
                permissionsExitWarningTitle: "Flowtype is not ready yet",
                permissionsExitWarningMessage: "Without Microphone and Accessibility permissions, Flowtype cannot record audio, listen for Fn, or paste transcripts automatically. You can keep browsing and return to Setup & Status later.",
                readinessSubtitle: "See whether Flowtype is ready to dictate, then resolve permissions, models, and local runtime issues.",
                readinessRefreshTitle: "Refresh",
                readinessPrepareFlowtypeTitle: "Prepare Flowtype",
                readinessSetupCompleteTitle: "Flowtype is ready",
                readinessSetupNeedsStepsTitle: "Flowtype needs setup",
                readinessSetupBlockedTitle: "Reinstall the complete Flowtype app",
                readinessPrepareRuntimeTitle: "Prepare Runtime",
                readinessRepairHelperTitle: "Repair Helper",
                readinessReinstallFlowtypeTitle: "Open App Location",
                readinessRepairLocalRuntimeTitle: "Repair Local Runtime",
                readinessOpenLocationTitle: "Open Location",
                readinessDownloadDefaultModelTitle: "Download 0.6B Model",
                readinessRetryPreloadTitle: "Retry Model Preparation",
                readinessDefaultModelConsentTitle: "Download Local Qwen Model",
                readinessDefaultModelConsentMessage: "Flowtype needs a local Qwen model for offline dictation. Download Qwen3-ASR 0.6B now?",
                readinessFirstRunPromptTitle: "Prepare Flowtype first",
                readinessFirstRunPromptMessage: "Flowtype needs microphone and Accessibility permissions, plus the default Qwen3-ASR 0.6B model, before local Fn dictation is ready.",
                readinessFirstRunPromptPrimaryTitle: "Prepare and Download",
                readinessFirstRunPromptLaterTitle: "Later",
                readinessWarmModelTitle: "Warm Model",
                readinessCopyDiagnosticsTitle: "Copy Diagnostics",
                readinessCopiedDiagnosticsTitle: "Diagnostics Copied",
                readinessDiagnosticsTitle: "Diagnostics",
                readinessGenerateDiagnosticsTitle: "Generate Diagnostics File",
                readinessOpenDiagnosticsFolderTitle: "Open Diagnostics Folder",
                readinessGeneratedDiagnosticsTitle: { fileName in "Diagnostics file generated: \(fileName)" },
                readinessFailedTitle: "Action Failed",
                readinessStatusReadyTitle: "Ready",
                readinessStatusNotReadyTitle: "Not Ready",
                readinessStatusPreparingTitle: "Preparing",
                readinessStatusNeedsRepairTitle: "Needs Repair",
                readinessStatusOptionalTitle: "Optional",
                readinessStatusFailedTitle: "Failed",
                readinessStatusUnknownTitle: "Unknown",
                readinessGroupAppBundleTitle: "App Bundle",
                readinessGroupLocalRuntimeTitle: "Local Runtime",
                readinessGroupModelsTitle: "Models",
                readinessGroupPermissionsTitle: "Permissions",
                readinessGroupPerformanceTitle: "Performance",
                readinessAdvancedDiagnosticsTitle: "Advanced Diagnostics",
                readinessRequestMicrophoneTitle: "Microphone",
                readinessOpenAccessibilitySettingsTitle: "Accessibility",
                readinessRequestSpeechRecognitionTitle: "Speech Recognition",
                readinessReinstallAppTitle: "Reinstall",
                readinessRestartHelperTitle: "Restart Helper",
                modelLocalBadge: "Local",
                modelSelectedBadge: "Selected",
                modelNotInstalled: "Not downloaded",
                modelReady: "Ready",
                modelDownloading: "Downloading",
                modelFailed: "Failed",
                modelNeedsRepair: "Needs Repair",
                modelPathTitle: "Model location",
                modelPathDetail: "The model is stored in this app-managed local folder.",
                modelDownloadTitle: "Download Model",
                modelRepairTitle: "Reinstall",
                modelUseTitle: "Use This Model",
                modelDownloadedTitle: "Downloaded",
                modelInUseTitle: "In Use",
                modelOpenFolderTitle: "Open Folder",
                modelCopyPathTitle: "Copy Path",
                modelOpenDictionaryTitle: "Open Dictionary Hotwords",
                modelRefreshTitle: "Refresh",
                modelHotwordsNote: "Dictionary hotwords are passed to local Qwen automatically during dictation.",
                modelSuitabilityWarningTitle: "1.7B may be slow on this Mac",
                modelSuitabilityUseSmallModelTitle: "Use 0.6B",
                modelSuitabilityContinueTitle: "Continue Anyway",
                modelDownloadHelp: "Download and prepare the local Qwen model",
                modelRepairHelp: "Delete the incomplete model cache and download it again",
                modelUseHelp: "Select this model for local dictation",
                modelOpenFolderHelp: "Open the model folder in Finder",
                modelCopyPathHelp: "Copy the model folder path",
                modelErrorTitle: "Model could not be updated",
                modelPreparingMessage: "Preparing local model...",
                modelRepairMessage: "Flowtype found an incomplete model cache. Reinstall to remove the old cache and download a clean copy.",
                termsSuffix: "terms",
                addHotwordPlaceholder: "Add new hotword",
                addWordTitle: "Add word",
                searchHotwordsPlaceholder: "Search hotwords",
                manageHotwordsTitle: "Manage hotwords",
                matchesSuffix: "matches",
                deleteHotwordHelp: "Delete hotword",
                deleteHotwordTitle: "Delete Hotword",
                dictionaryErrorTitle: "Dictionary could not be updated",
                hotwordAlreadyExists: "This term already exists. The matching result is now shown.",
                rowExpand: "Expand",
                rowCollapse: "Collapse",
                rowCopied: "Copied",
                rowCopy: "Copy",
                rowCopyTranscript: "Copy transcript",
                rowPaste: "Paste",
                rowPasteAgain: "Paste again",
                rowPossibleTruncation: "May be incomplete",
                rowRetrySegmented: "Retry with segments",
                rowRetryingSegmented: "Retrying",
                rowRetrySegmentedSucceeded: "Retried",
                rowRetrySegmentedFailed: "Retry failed",
                rowTranscriptionFailed: "Transcription failed",
                rowRecoverableFailureDetail: "Recording saved for retry",
                rowRetryTranscription: "Retry transcription",
                rowRecordingExpired: "Recording expired",
                capsuleRecoverableTranscriptionFailed: "Failed, retry in Home",
                dictationCountTitle: "Dictations",
                recordingDurationTitle: "Dictated time",
                dictatedUnitsTitle: "Dictated words",
                savedTimeTitle: "Time saved",
                localEstimateNote: "Estimated locally",
                timesUnit: "times",
                dictatedUnitSuffix: "words",
                menuStatusStarting: "Status: Starting",
                menuEngine: "Engine: Qwen3-ASR Local",
                menuFallback: "Fallback: Apple Speech",
                menuShowHome: "Show Home",
                menuShowDictionary: "Show Dictionary",
                menuShowPreferences: "Show Transcription & Appearance",
                menuCurrentModelPrefix: "Model: ",
                menuSettings: "Device & Storage...",
                menuHelp: "Help...",
                menuSetupStatus: "Setup & Status...",
                menuPasteLastTranscript: "Paste Last Transcript",
                menuQuit: "Quit",
                noTranscriptYet: "No transcript yet",
                copiedLastTranscript: "Copied last transcript",
                pastedLastTranscript: "Pasted last transcript",
                mainWindowUnavailableTitle: "Flowtype storage is unavailable",
                mainWindowUnavailableMessage: "The main window cannot open because local hotword or history storage could not be prepared.",
                helpMessageTitle: "Flowtype Help",
                helpMessageBody: """
                Hold Fn to talk, then release Fn to transcribe with the selected local model. Flowtype copies the result and pastes it into the app you were using.

                Home shows local transcript history when history is enabled. If a longer recording looks truncated, the row is marked as possibly incomplete and you can retry it with segmented transcription. Recent recordings are kept briefly on this Mac only for that manual retry.

                Dictionary hotwords help Qwen keep names, tools, course codes, and mixed-language phrases. Models lets you download and switch between Qwen3-ASR 0.6B and 1.7B. Transcription & Appearance controls themes, number cleanup, math notation, and filler cleanup.

                Use Setup & Status for Microphone and Accessibility. Speech Recognition is only needed for Apple Speech fallback. Use Device & Storage for microphones, history, and local file locations. Transcript history and recordings retained briefly for manual retry stay local on this Mac.
                """,
                historySectionTitle: "History",
                modelEverydayRoleTitle: "Everyday Dictation",
                modelPrecisionRoleTitle: "Precision Dictation",
                modelDeleteTitle: "Delete Model",
                modelDeleteConfirmTitle: "Delete this model?",
                onboardingMenuTitle: "Getting Started…",
                onboardingWelcomeTitle: "Back to Flow",
                onboardingWelcomeBody: "Flowtype is a local-first dictation tool: hold Fn to talk, release to transcribe, and the result is pasted into the app you were using.",
                onboardingPrivacyNote: "Everything runs on this Mac — audio and text never leave it.",
                onboardingMicrophoneTitle: "Microphone",
                onboardingMicrophoneDetail: "Records your voice.",
                onboardingAccessibilityTitle: "Accessibility",
                onboardingAccessibilityDetail: "Pastes the transcript into the frontmost app.",
                onboardingOpenSettingsTitle: "Open System Settings",
                onboardingGrantedTitle: "Granted",
                onboardingDeniedTitle: "Denied — enable it in System Settings.",
                onboardingPrepareTitle: "Prepare Flowtype",
                onboardingPrepareBody: "One click does everything: grants Microphone and Accessibility permissions and downloads the default Qwen3-ASR 0.6B local model (about 1.9 GB, first run only — you can also do this later from Setup & Status).",
                onboardingPrepareReadyTitle: "Ready to go",
                onboardingPreparePermissionsHint: "Finish granting the permission in System Settings, then return to this window to continue automatically.",
                onboardingHowToTitle: "Start Dictating",
                onboardingHowToHoldTitle: "Hold Fn and talk",
                onboardingHowToHoldDetail: "Hold the Fn key in any app to start recording.",
                onboardingHowToReleaseTitle: "Release Fn to finish",
                onboardingHowToReleaseDetail: "The transcript is pasted into the app you were just using.",
                onboardingHowToDictionaryTitle: "Dictionary keeps names accurate",
                onboardingHowToDictionaryDetail: "Add names and terms to the Dictionary so transcription preserves them.",
                onboardingContinueTitle: "Continue",
                onboardingBackTitle: "Back",
                onboardingSkipTitle: "Skip",
                onboardingFinishTitle: "Start Using Flowtype"
            )
        }
    }
}
