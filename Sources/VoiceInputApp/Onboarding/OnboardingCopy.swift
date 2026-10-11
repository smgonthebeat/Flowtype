import Foundation

/// Strings for the illustrated onboarding pages (2026-10-10 redesign). The
/// pages are meant to read from the pictures first, so most strings are short
/// captions; the older shared strings stay in `AppCopy`.
/// A spoken phrase and what Flowtype writes for it. `OnboardingExamplesTests` runs every
/// example through `TranscriptPostProcessor`, so the page never shows an output the app
/// would not produce.
struct OnboardingExample: Equatable {
    let spoken: String
    let written: String

    init(_ spoken: String, _ written: String) {
        self.spoken = spoken
        self.written = written
    }
}

enum OnboardingCopy {
    struct Texts {
        let welcomeFlowSpeak: String
        let welcomeFlowListen: String
        let welcomeFlowPaste: String
        let sampleSpokenText: String
        let sampleWrittenText: String

        let holdTitle: String
        let holdSubtitle: String
        let holdKeyPointer: String
        let holdRule: String
        let holdTapWarning: String
        let holdingFormat: String
        let holdExternalKeyboardNote: String

        let practiceTitle: String
        let practiceSubtitle: String
        let practicePrompt: String
        let practiceSuggestion: String
        let practicePlaceholder: String
        let practiceListening: String
        let practiceTranscribing: String
        let practiceSucceeded: String
        let practiceTooShort: String
        let practiceFailed: String
        let practiceNotReady: String

        let featuresTitle: String
        let featuresSubtitle: String
        let defaultOnBadge: String
        let numericExamples: [OnboardingExample]
        let academicExamples: [OnboardingExample]
        let mathLaTeXExamples: [OnboardingExample]
        let mathUnicodeExamples: [OnboardingExample]
        let fillerExamples: [OnboardingExample]

        let prepareVPNHint: String
        let modelScopeRoute: String
        let huggingFaceRoute: String

        func practiceFailedWithReason(_ reason: String) -> String {
            practiceFailed.hasSuffix("。") ? "\(practiceFailed)（\(reason)）" : "\(practiceFailed) (\(reason))"
        }

        func holdingText(seconds: Double) -> String {
            String(format: holdingFormat, String(format: "%.1f", max(seconds, 0)))
        }

        func mathExamples(for format: MathNotationOutputFormat) -> [OnboardingExample] {
            switch format {
            case .latex: return mathLaTeXExamples
            case .unicode: return mathUnicodeExamples
            }
        }

        func downloadRouteText(_ route: OnboardingDownloadRoute) -> String {
            switch route {
            case .modelScope: return modelScopeRoute
            case .huggingFace: return huggingFaceRoute
            }
        }
    }

    // Study references and math are spoken in English in both interface languages.
    static let academicExamples = [
        OnboardingExample("Exercise three Q two H", "Exercise 3 Q2(h)"),
        OnboardingExample("Q three B two", "Q3(b)(ii)"),
        OnboardingExample("Sheet one Exercise four B and C", "Sheet 1 Exercise 4(b) and (c)")
    ]

    static let mathLaTeXExamples = [
        OnboardingExample("variance x", "$\\operatorname{Var}(X)$"),
        OnboardingExample("x bar", "$\\bar{x}$"),
        OnboardingExample("X follows normal mu sigma squared", "$X \\sim N(\\mu, \\sigma^2)$")
    ]

    static let mathUnicodeExamples = [
        OnboardingExample("variance x", "Var(X)"),
        OnboardingExample("x bar", "x̄"),
        OnboardingExample("X follows normal mu sigma squared", "X ∼ N(μ, σ²)")
    ]

    static func texts(for language: UILanguage) -> Texts {
        switch language {
        case .chinese:
            return Texts(
                welcomeFlowSpeak: "你说话",
                welcomeFlowListen: "本机识别",
                welcomeFlowPaste: "文字出现在光标处",
                sampleSpokenText: "这个 model 的 accuracy 是百分之九十二点五",
                sampleWrittenText: "这个 model 的 accuracy 是92.5%",
                holdTitle: "按住 Fn 说话，松开就转写",
                holdSubtitle: "Fn 在键盘最左下角，新款 MacBook 上印着地球图标和 fn；旧款只印 fn。",
                holdKeyPointer: "左下角这个键",
                holdRule: "按住 = 录音，松开 = 转写",
                holdTapWarning: "只点一下不会录音",
                holdingFormat: "按住 %@ 秒",
                holdExternalKeyboardNote: "部分外接键盘的 Fn 键 Flowtype 收不到；按了没反应时，请用 Mac 自带键盘。",
                practiceTitle: "试一试",
                practiceSubtitle: "在这里练一次，结果只显示在这个窗口，不会粘贴到别的应用。",
                practicePrompt: "按住 Fn 说一句话，说完再松开",
                practiceSuggestion: "比如：今天天气不错",
                practicePlaceholder: "说完松开后，文字会出现在这里",
                practiceListening: "正在听…说完再松开",
                practiceTranscribing: "正在转写…",
                practiceSucceeded: "成功了。以后在任何应用里都这样用。",
                practiceTooShort: "按得太短了：要一直按住 Fn，说完再松开。",
                practiceFailed: "这次没成功，再按住 Fn 试一次。",
                practiceNotReady: "模型准备好后就能练习",
                featuresTitle: "按需打开的功能",
                featuresSubtitle: "全部在这台 Mac 上处理。以后可以在主窗口的「格式与外观」里随时修改。",
                defaultOnBadge: "默认开启",
                numericExamples: [
                    OnboardingExample("百分之三点五", "3.5%"),
                    OnboardingExample("验证码是一二三四五六", "验证码是123456"),
                    OnboardingExample("十月二号我们见面", "10月2号我们见面")
                ],
                academicExamples: OnboardingCopy.academicExamples,
                mathLaTeXExamples: OnboardingCopy.mathLaTeXExamples,
                mathUnicodeExamples: OnboardingCopy.mathUnicodeExamples,
                fillerExamples: [
                    OnboardingExample("嗯，我先说结论", "我先说结论"),
                    OnboardingExample("我们呃明天再说", "我们明天再说"),
                    OnboardingExample("这个方案呃可以", "这个方案可以")
                ],
                prepareVPNHint: "开着 VPN 下载可能会变慢，可以先关掉，下载完再打开。",
                modelScopeRoute: "下载线路：国内（ModelScope）",
                huggingFaceRoute: "下载线路：国际（Hugging Face）"
            )
        case .english:
            return Texts(
                welcomeFlowSpeak: "You speak",
                welcomeFlowListen: "Recognized on this Mac",
                welcomeFlowPaste: "Text lands at your cursor",
                sampleSpokenText: "The model's accuracy is ninety two point five percent",
                sampleWrittenText: "The model's accuracy is 92.5%",
                holdTitle: "Hold Fn to talk, release to type",
                holdSubtitle: "Fn is the bottom-left key. Newer MacBooks show a globe and fn on it; older ones show fn only.",
                holdKeyPointer: "This bottom-left key",
                holdRule: "Hold = record, release = transcribe",
                holdTapWarning: "A quick tap records nothing",
                holdingFormat: "Holding %@ s",
                holdExternalKeyboardNote: "Some external keyboards never send Fn to macOS. If nothing happens, use the Mac's built-in keyboard.",
                practiceTitle: "Try it",
                practiceSubtitle: "Practice here. The text only appears in this window and isn't pasted anywhere else.",
                practicePrompt: "Hold Fn, say a sentence, then release",
                practiceSuggestion: "For example: The weather is nice today",
                practicePlaceholder: "Your words appear here after you release Fn",
                practiceListening: "Listening… release when you're done",
                practiceTranscribing: "Transcribing…",
                practiceSucceeded: "That's it. It works the same way in any app.",
                practiceTooShort: "Too short: keep holding Fn while you talk, then release.",
                practiceFailed: "That didn't work. Hold Fn and try again.",
                practiceNotReady: "Practice opens once the model is ready",
                featuresTitle: "Turn on what you need",
                featuresSubtitle: "Everything runs on this Mac. Change these anytime in Formatting & Appearance.",
                defaultOnBadge: "On by default",
                numericExamples: [
                    OnboardingExample("We need twenty one samples.", "We need 21 samples."),
                    OnboardingExample("three point five", "3.5"),
                    OnboardingExample("Ship version two", "Ship version 2")
                ],
                academicExamples: OnboardingCopy.academicExamples,
                mathLaTeXExamples: OnboardingCopy.mathLaTeXExamples,
                mathUnicodeExamples: OnboardingCopy.mathUnicodeExamples,
                fillerExamples: [
                    OnboardingExample("Um, I will start with the conclusion", "I will start with the conclusion"),
                    OnboardingExample("So um, the deadline is Friday.", "So the deadline is Friday.")
                ],
                prepareVPNHint: "Downloads can be slow with a VPN on. Try turning it off until the download finishes.",
                modelScopeRoute: "Download route: ModelScope (China)",
                huggingFaceRoute: "Download route: Hugging Face (global)"
            )
        }
    }
}
