import Foundation

enum PreferencesCopy {
    struct Texts {
        let title: String
        let subtitle: String
        let appearanceSectionTitle: String
        let appearanceSectionDetail: String
        let appearanceThemeTitle: String
        let numericFormattingTitle: String
        let numericFormattingDetail: String
        let numericFormattingToggle: String
        let numericFormattingExamples: String
        let academicReferenceFormattingTitle: String
        let academicReferenceFormattingDetail: String
        let academicReferenceFormattingToggle: String
        let academicReferenceFormattingExamples: String
        let mathNotationTitle: String
        let mathNotationDetail: String
        let mathNotationToggle: String
        let mathOutputFormatTitle: String
        let mathNotationExamples: String
        let latex: String
        let unicode: String
        let fillerCleanupTitle: String
        let fillerCleanupDetail: String
        let fillerCleanupToggle: String
        let fillerCleanupExamples: String
        let fillerCleanupSafetyNotice: String
        let fillerCleanupSafetyNoticeDismiss: String
        let examplesTitle: String
    }

    static func texts(for language: UILanguage) -> Texts {
        switch language {
        case .chinese:
            return Texts(
                title: "格式与外观",
                subtitle: "调整界面主题和转写结果的本地格式化。模型与设备设置分别在对应页面管理。",
                appearanceSectionTitle: "外观",
                appearanceSectionDetail: "选择 Flowtype 的界面配色。Apple 主题跟随 macOS 原生外观。",
                appearanceThemeTitle: "主题",
                numericFormattingTitle: "智能数字格式",
                numericFormattingDetail: "把口述的数值整理成书面格式：百分比、小数、日期、题号和验证码。句子里的普通中文数字保持原样，英文数字读法写成阿拉伯数字。全部在本地完成。",
                numericFormattingToggle: "启用智能数字格式",
                numericFormattingExamples: "示例：百分之三点五 → 3.5%；验证码是一二三四五六 → 验证码是123456；第三题 → 第3题；twenty one → 21。「这段代码两三行」保持不变",
                academicReferenceFormattingTitle: "学习题号与小问格式",
                academicReferenceFormattingDetail: "把口述的练习、题号和小问整理成规范格式，适合做题与课程笔记。关闭时只停用题号和小问的结构化，其他转写选项仍独立生效。",
                academicReferenceFormattingToggle: "启用学习题号与小问格式",
                academicReferenceFormattingExamples: "示例：Exercise three Q two H → Exercise 3 Q2(h)；Sheet one Exercise four B and C → Sheet 1 Exercise 4(b) and (c)",
                mathNotationTitle: "数学与统计符号",
                mathNotationDetail: "把口述的数学和统计表达转成规范符号，适合课程笔记与学术写作。可选 LaTeX 或 Unicode 两种输出。",
                mathNotationToggle: "启用数学与统计符号转换",
                mathOutputFormatTitle: "输出格式",
                mathNotationExamples: "示例：variance x → Var(X)；standard error beta hat → SE(β̂)；theta hat → $\\hat{\\theta}$（LaTeX）或 θ̂（Unicode）；x sub i → xᵢ；x bar → x̄",
                latex: "LaTeX",
                unicode: "Unicode",
                fillerCleanupTitle: "口头填充词清理",
                fillerCleanupDetail: "按本地规则清理部分停顿词，包括连续中文中的「呃」和「那嗯，继续」这类表达。保留引文、code、术语和未支持的表达；不判断 like、就是等词是否多余。有意说出的停顿音仍可能被误删。默认关闭。",
                fillerCleanupToggle: "启用口头填充词清理",
                fillerCleanupExamples: "示例：嗯，我现在先说结论 → 我现在先说结论",
                fillerCleanupSafetyNotice: "为防止误删正常词语，本次更新已关闭口头填充词清理。你可以查看说明后重新开启。",
                fillerCleanupSafetyNoticeDismiss: "关闭提示",
                examplesTitle: "示例"
            )
        case .english:
            return Texts(
                title: "Formatting & Appearance",
                subtitle: "Adjust the interface theme and how transcripts are formatted locally. Manage models and devices on their dedicated pages.",
                appearanceSectionTitle: "Appearance",
                appearanceSectionDetail: "Choose Flowtype's color palette. The Apple theme follows the native macOS look.",
                appearanceThemeTitle: "Theme",
                numericFormattingTitle: "Smart numeric formatting",
                numericFormattingDetail: "Formats spoken values as written text: percentages, decimals, dates, question numbers, and codes. Ordinary Chinese numbers in a sentence stay as spoken; spoken English numbers become numerals. Runs entirely on this Mac.",
                numericFormattingToggle: "Enable smart numeric formatting",
                numericFormattingExamples: "Examples: 百分之三点五 → 3.5%; twenty one → 21; three point five → 3.5. \"No one knows\" stays as spoken",
                academicReferenceFormattingTitle: "Study reference formatting",
                academicReferenceFormattingDetail: "Formats spoken exercises, question numbers, and subparts for problem-solving and course notes. When off, only study-reference structuring is disabled; other transcription options still apply independently.",
                academicReferenceFormattingToggle: "Enable study reference formatting",
                academicReferenceFormattingExamples: "Example: Exercise three Q two H → Exercise 3 Q2(h); Sheet one Exercise four B and C → Sheet 1 Exercise 4(b) and (c)",
                mathNotationTitle: "Math and statistics notation",
                mathNotationDetail: "Converts spoken math and statistics into proper notation — ideal for course notes and academic writing. Output as LaTeX or Unicode.",
                mathNotationToggle: "Enable math and statistics notation",
                mathOutputFormatTitle: "Output format",
                mathNotationExamples: "Examples: variance x → Var(X); standard error beta hat → SE(β̂); theta hat → $\\hat{\\theta}$ (LaTeX) or θ̂ (Unicode); x sub i → xᵢ; x bar → x̄",
                latex: "LaTeX",
                unicode: "Unicode",
                fillerCleanupTitle: "Filler cleanup",
                fillerCleanupDetail: "Uses local rules to clean some pauses, including 呃 inside Chinese text and attached 嗯 before a comma and continuation. Preserves quoted text, code, terms, and unsupported expressions. It does not decide whether words such as like are redundant; intentional pause sounds can still be removed. Off by default.",
                fillerCleanupToggle: "Enable filler cleanup",
                fillerCleanupExamples: "Example: Um, I will start with the conclusion → I will start with the conclusion",
                fillerCleanupSafetyNotice: "Filler cleanup was turned off in this update to prevent normal words from being removed. You can review it and re-enable it.",
                fillerCleanupSafetyNoticeDismiss: "Dismiss",
                examplesTitle: "Examples"
            )
        }
    }
}
