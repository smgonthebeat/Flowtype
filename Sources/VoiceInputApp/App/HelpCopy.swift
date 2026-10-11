import Foundation

/// What a Help entry's button does.
enum HelpAction: Equatable {
    case openSection(MainWindowSection)
    case copyLastTranscript
}

/// One common problem: what the user sees, why, what to do, and a button that goes there.
struct HelpProblem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let question: String
    let answer: String
    let actionTitle: String
    let action: HelpAction
}

/// Where users send a diagnostics report. The email and GitHub repository are the owner's
/// public contact points for Flowtype.
enum HelpContact {
    static let email = "smgbot@mail.grokbot.com"
    static let issuesURL = URL(string: "https://github.com/smgonthebeat/Flowtype/issues")!

    /// A `mailto:` link with the subject and a body that reminds the user to paste the report.
    static func mailURL(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

/// Help page text (2026-10-11 rewrite). The page is organised around problems a user hits,
/// because people open Help when something went wrong, not to read a feature list. Every
/// answer was checked against the current behaviour; keep them in step when it changes.
enum HelpCopy {
    struct Texts {
        let windowTitle: String
        let title: String
        let subtitle: String

        let basicsTitle: String
        let basicsRules: [String]
        let replayOnboarding: String

        let problemsTitle: String
        let problems: [HelpProblem]
        let copiedLastTranscript: String
        let noLastTranscript: String

        let diagnosticsTitle: String
        let diagnosticsBody: String
        let diagnosticsButton: String
        let diagnosticsRunning: String
        let diagnosticsResultPrefix: String
        let diagnosticsCopied: String
        let revealInFinder: String
        let openSetupStatus: String

        let contactLabel: String
        let contactGitHub: String
        let contactEmailSubject: String
        let contactEmailBody: String
    }

    static func texts(for language: UILanguage) -> Texts {
        switch language {
        case .chinese:
            return Texts(
                windowTitle: "Flowtype 帮助",
                title: "帮助",
                subtitle: "遇到问题先看这里，大多数情况点一下按钮就能处理。",
                basicsTitle: "基本用法",
                basicsRules: [
                    "按住 Fn 说话，说完松开就转写",
                    "只点一下 Fn 不会录音",
                    "文字会粘贴到你正在输入的地方"
                ],
                replayOnboarding: "重新看新手引导",
                problemsTitle: "常见问题",
                problems: [
                    HelpProblem(
                        id: "fn",
                        symbol: "keyboard",
                        question: "按 Fn 没有反应",
                        answer: "先在「准备状态」里看辅助功能权限和模型是否就绪：Flowtype 要有辅助功能权限才能收到 Fn。部分外接键盘的 Fn 不会发给 macOS，这时请用 Mac 自带键盘。",
                        actionTitle: "打开准备状态",
                        action: .openSection(.readiness)
                    ),
                    HelpProblem(
                        id: "paste",
                        symbol: "doc.on.clipboard",
                        question: "文字没有粘贴出来",
                        answer: "没法自动粘贴时，文字已经放进剪贴板，胶囊会提示「已复制，可按 ⌘V 粘贴」，直接按 ⌘V 就行。常见原因是光标不在输入框里，或者缺少辅助功能权限。",
                        actionTitle: "复制上次转写",
                        action: .copyLastTranscript
                    ),
                    HelpProblem(
                        id: "terms",
                        symbol: "text.book.closed",
                        question: "人名、术语总是认错",
                        answer: "把它们加进词典。词典里的词会提示模型按你写的样子输出，人名、课程代码、工具名都适用。",
                        actionTitle: "打开词典",
                        action: .openSection(.dictionary)
                    ),
                    HelpProblem(
                        id: "long",
                        symbol: "waveform",
                        question: "长录音只转出一小段",
                        answer: "开着转写历史时，这类记录会标出「可能不完整」，点「重新分段转写」再转一次。经常说很久的话，可以在「设置与存储」里调高录音时长上限。",
                        actionTitle: "打开主页",
                        action: .openSection(.home)
                    ),
                    HelpProblem(
                        id: "format",
                        symbol: "number",
                        question: "数字、数学或填充词的格式不是想要的",
                        answer: "这些都能单独开关：智能数字格式、口头填充词清理、学习题号与小问格式、数学与统计符号。",
                        actionTitle: "打开格式与外观",
                        action: .openSection(.preferences)
                    ),
                    HelpProblem(
                        id: "download",
                        symbol: "arrow.down.circle",
                        question: "模型下载很慢",
                        answer: "开着 VPN 时，下载可能绕远变慢。先关掉 VPN，下载完再打开。",
                        actionTitle: "打开模型",
                        action: .openSection(.models)
                    ),
                    HelpProblem(
                        id: "slow",
                        symbol: "tortoise",
                        question: "转写比平时慢",
                        answer: "刚打开 Flowtype 时模型要先加载，等菜单栏显示「已就绪」再用会快很多。「精准听写」（1.7B）比「日常听写」（0.6B）更准，也更慢。",
                        actionTitle: "打开模型",
                        action: .openSection(.models)
                    )
                ],
                copiedLastTranscript: "已复制，可按 ⌘V 粘贴",
                noLastTranscript: "还没有转写内容",
                diagnosticsTitle: "还是没解决？",
                diagnosticsBody: "点下面的按钮，Flowtype 会先重新检查一遍，再把诊断信息复制到剪贴板。把它粘贴进邮件或 GitHub，发给开发者就行。诊断信息不包含录音和转写文字。",
                diagnosticsButton: "检查并复制诊断信息",
                diagnosticsRunning: "正在检查…",
                diagnosticsResultPrefix: "检查结果：",
                diagnosticsCopied: "诊断信息已复制到剪贴板。",
                revealInFinder: "在 Finder 中显示",
                openSetupStatus: "打开准备状态",
                contactLabel: "发给开发者：",
                contactGitHub: "在 GitHub 反馈",
                contactEmailSubject: "Flowtype 问题反馈",
                contactEmailBody: "遇到的问题：\n\n诊断信息（在这里按 ⌘V 粘贴）：\n"
            )
        case .english:
            return Texts(
                windowTitle: "Flowtype Help",
                title: "Help",
                subtitle: "Start here when something isn't working. Most fixes are one click away.",
                basicsTitle: "The basics",
                basicsRules: [
                    "Hold Fn and talk, release to transcribe",
                    "A quick tap on Fn records nothing",
                    "Text is pasted where you're typing"
                ],
                replayOnboarding: "Replay Getting Started",
                problemsTitle: "Common problems",
                problems: [
                    HelpProblem(
                        id: "fn",
                        symbol: "keyboard",
                        question: "Nothing happens when I hold Fn",
                        answer: "Check Setup & Status for Accessibility access and the model: Flowtype needs Accessibility access to receive Fn. Some external keyboards never send Fn to macOS; use the Mac's built-in keyboard instead.",
                        actionTitle: "Open Setup & Status",
                        action: .openSection(.readiness)
                    ),
                    HelpProblem(
                        id: "paste",
                        symbol: "doc.on.clipboard",
                        question: "The text wasn't pasted",
                        answer: "When Flowtype can't paste, the text is already on the clipboard and the capsule says \"Copied. Press ⌘V to paste\". Just press ⌘V. Usually the cursor wasn't in a text field, or Accessibility access is missing.",
                        actionTitle: "Copy Last Transcript",
                        action: .copyLastTranscript
                    ),
                    HelpProblem(
                        id: "terms",
                        symbol: "text.book.closed",
                        question: "Names and terms keep coming out wrong",
                        answer: "Add them to the Dictionary. Entries there nudge the model to write them your way, which works for names, course codes and tool names.",
                        actionTitle: "Open Dictionary",
                        action: .openSection(.dictionary)
                    ),
                    HelpProblem(
                        id: "long",
                        symbol: "waveform",
                        question: "A long recording came out short",
                        answer: "With transcript history on, these entries are marked \"May be incomplete\". Click Retry with segments to transcribe again. If you often talk for a long time, raise the recording limit in Settings & Storage.",
                        actionTitle: "Open Home",
                        action: .openSection(.home)
                    ),
                    HelpProblem(
                        id: "format",
                        symbol: "number",
                        question: "Numbers, math or fillers aren't formatted the way I want",
                        answer: "Each one has its own switch: Smart numeric formatting, Filler cleanup, Study reference formatting, and Math and statistics notation.",
                        actionTitle: "Open Formatting & Appearance",
                        action: .openSection(.preferences)
                    ),
                    HelpProblem(
                        id: "download",
                        symbol: "arrow.down.circle",
                        question: "The model downloads slowly",
                        answer: "A VPN can route the download the long way round. Turn it off until the download finishes.",
                        actionTitle: "Open Models",
                        action: .openSection(.models)
                    ),
                    HelpProblem(
                        id: "slow",
                        symbol: "tortoise",
                        question: "Transcription is slower than usual",
                        answer: "Right after Flowtype opens, the model is still loading; wait until the menu bar says Ready. Precision Dictation (1.7B) is more accurate than Everyday Dictation (0.6B), and slower.",
                        actionTitle: "Open Models",
                        action: .openSection(.models)
                    )
                ],
                copiedLastTranscript: "Copied. Press ⌘V to paste",
                noLastTranscript: "No transcript yet",
                diagnosticsTitle: "Still stuck?",
                diagnosticsBody: "Flowtype checks everything again, then copies a diagnostics report to the clipboard. Paste it into an email or on GitHub to send it to the developer. It contains no recordings or transcript text.",
                diagnosticsButton: "Check and Copy Diagnostics",
                diagnosticsRunning: "Checking…",
                diagnosticsResultPrefix: "Result: ",
                diagnosticsCopied: "Diagnostics copied to the clipboard.",
                revealInFinder: "Show in Finder",
                openSetupStatus: "Open Setup & Status",
                contactLabel: "Send to the developer:",
                contactGitHub: "Report on GitHub",
                contactEmailSubject: "Flowtype feedback",
                contactEmailBody: "What went wrong:\n\nDiagnostics (press ⌘V here to paste):\n"
            )
        }
    }
}
