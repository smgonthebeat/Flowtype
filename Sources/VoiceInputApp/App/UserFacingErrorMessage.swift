import Foundation

/// Turns internal errors into a sentence in the interface language that says what happened
/// and what to do next. Technical detail stays in English and is appended only when there is
/// no specific sentence, so a user can still paste it into a diagnostics report (owner
/// decision, 2026-10-11: user-facing text follows the interface language, technical detail
/// may stay English). Each error type keeps its English `errorDescription` for logs.
enum UserFacingErrorMessage {
    static func message(for error: Error, language: UILanguage) -> String {
        let chinese = language == .chinese
        switch error {
        case let failure as PreparationFailure:
            return message(for: failure, language: language)
        case let helperError as QwenHelperClientError:
            switch helperError {
            case .invalidResponse:
                return chinese
                    ? "本地转写组件返回了无法识别的结果。请重试；如果一直这样，可以在「准备状态」里重启组件。"
                    : "The local transcription helper sent an unexpected reply. Try again, or restart it from Setup & Status."
            case let .httpStatus(status, detail):
                return withDetail(
                    chinese
                        ? "本地转写组件没能完成这次操作。请重试；如果一直这样，可以在「准备状态」里重启组件。"
                        : "The local transcription helper couldn't finish this. Try again, or restart it from Setup & Status.",
                    detail: "HTTP \(status)" + (detail.map { ": \($0)" } ?? ""),
                    language: language
                )
            }
        case let processError as HelperProcessError:
            return withDetail(
                chinese
                    ? "本地转写组件没能启动。请在「准备状态」里点「一键准备」重试；如果一直失败，可以复制诊断信息发给我们。"
                    : "The local transcription helper didn't start. Run setup again from Setup & Status, or copy the diagnostics and send them to us.",
                detail: "\(processError)",
                language: language
            )
        case HotwordStoreError.emptyText:
            return chinese ? "词条不能为空。" : "The entry can't be empty."
        case let copyError as DiagnosticsCopyError:
            if case let .pasteboardWriteFailed(url?) = copyError {
                return chinese
                    ? "没能复制到剪贴板。诊断信息已经保存在：\(url.path)"
                    : "Couldn't copy to the clipboard. The diagnostics were saved to \(url.path)."
            }
            return chinese ? "没能复制到剪贴板，请再试一次。" : "Couldn't copy to the clipboard. Try again."
        default:
            return withDetail(
                chinese ? "操作没有完成，请再试一次。" : "That didn't work. Try again.",
                detail: error.localizedDescription,
                language: language
            )
        }
    }

    static func message(for failure: PreparationFailure, language: UILanguage) -> String {
        let chinese = language == .chinese
        switch failure {
        case .appBundleInvalid:
            return chinese
                ? "Flowtype 的安装文件不完整，请重新安装。"
                : "Flowtype's app files are incomplete. Please reinstall it."
        case .consentRequired:
            return chinese
                ? "需要先同意下载本地模型。"
                : "The local model needs your OK before it downloads."
        case .finalVerificationFailed:
            return chinese
                ? "最后一步检查没有通过，请再试一次。"
                : "The final check didn't pass. Try again."
        case .superseded:
            return chinese
                ? "你切换了模型，之前的准备已经取消。"
                : "You switched models, so the earlier setup was cancelled."
        case let .modelPreparationFailed(code):
            switch code {
            case "network_unavailable":
                return chinese
                    ? "模型下载连不上网络。请检查网络后重试；开着 VPN 时可以先关掉。"
                    : "The model download couldn't connect. Check your network and try again; if a VPN is on, try turning it off."
            case "insufficient_disk_space":
                return chinese
                    ? "磁盘空间不够，放不下本地模型。清理一些空间后再试。"
                    : "There isn't enough disk space for the local model. Free up some space and try again."
            case "model_preparation_timed_out":
                return chinese
                    ? "模型准备超时了。请再试一次；如果一直这样，可以在「准备状态」里复制诊断信息发给我们。"
                    : "Preparing the model timed out. Try again, or copy the diagnostics from Setup & Status and send them to us."
            default:
                return withDetail(
                    chinese
                        ? "本地模型没有准备好。请再试一次；如果一直失败，可以在「准备状态」里复制诊断信息发给我们。"
                        : "The local model isn't ready. Try again, or copy the diagnostics from Setup & Status and send them to us.",
                    detail: code,
                    language: language
                )
            }
        }
    }

    /// The default sentence with technical detail, for failures that only arrive as text.
    static func genericFailure(detail: String, language: UILanguage) -> String {
        withDetail(
            language == .chinese ? "操作没有完成，请再试一次。" : "That didn't work. Try again.",
            detail: detail,
            language: language
        )
    }

    private static func withDetail(_ sentence: String, detail: String, language: UILanguage) -> String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sentence }
        return language == .chinese ? "\(sentence)（技术信息：\(trimmed)）" : "\(sentence) (Technical detail: \(trimmed))"
    }
}
