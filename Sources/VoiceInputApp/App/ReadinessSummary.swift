import Foundation

/// One line that says whether Flowtype can dictate right now. Shown at the top of the menu
/// bar menu and as the result of the Help page's check (owner request, 2026-10-11): the menu
/// bar icon is the only part of Flowtype that is always visible, so it should answer
/// "can I use it?" without opening Setup & Status.
struct ReadinessSummary: Equatable {
    enum Tone: Equatable {
        case ready
        case working
        case attention
    }

    let tone: Tone
    let text: String

    static func make(for presentation: ReadinessPresentation, language: UILanguage) -> ReadinessSummary {
        let chinese = language == .chinese
        if let first = presentation.tasks.first {
            let need = needText(first.kind, chinese: chinese)
            let more = presentation.tasks.count - 1
            guard more > 0 else { return ReadinessSummary(tone: .attention, text: need) }
            return ReadinessSummary(
                tone: .attention,
                text: chinese ? "\(need)（还有 \(more) 项）" : "\(need) (+\(more) more)"
            )
        }
        switch presentation.phase {
        case .ready:
            return ReadinessSummary(tone: .ready, text: chinese ? "已就绪 · 按住 Fn 说话" : "Ready · Hold Fn to talk")
        case .checking:
            return ReadinessSummary(tone: .working, text: chinese ? "正在检查状态…" : "Checking status…")
        case .preparing:
            return ReadinessSummary(tone: .working, text: chinese ? "正在准备模型…" : "Preparing the model…")
        case .needsSetup, .repairRequired:
            return ReadinessSummary(
                tone: .attention,
                text: chinese ? "需要处理，打开准备状态查看" : "Needs attention, open Setup & Status"
            )
        }
    }

    private static func needText(_ kind: ReadinessTaskKind, chinese: Bool) -> String {
        switch kind {
        case .grantMicrophone: return chinese ? "需要麦克风权限" : "Microphone access needed"
        case .grantAccessibility: return chinese ? "需要辅助功能权限" : "Accessibility access needed"
        case .grantSpeechRecognition: return chinese ? "需要语音识别权限" : "Speech Recognition access needed"
        case .installSelectedModel: return chinese ? "需要下载模型" : "The model needs downloading"
        case .prepareSelectedModel: return chinese ? "模型还没准备好" : "The model isn't ready yet"
        case .repairLocalRuntime: return chinese ? "本地组件需要修复" : "The local helper needs repair"
        case .reinstallApplication: return chinese ? "需要重新安装 Flowtype" : "Flowtype needs reinstalling"
        }
    }
}
