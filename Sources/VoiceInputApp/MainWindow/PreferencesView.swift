import AppKit
import SwiftUI

enum ThemeOptionPreviewPresentation {
    static func iconAccentHex(for themeID: AppThemeID) -> String {
        AppTheme.theme(for: themeID).accentHex
    }
}

struct PreferencesView: View {
    @Environment(\.appTheme) private var theme

    @ObservedObject var state: MainWindowState
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        let copy = Copy.texts(for: settingsStore.uiLanguage)

        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(copy: copy)
                    appearanceSection(copy: copy)
                    numericSection(copy: copy)
                    mathSection(copy: copy)
                    fillerSection(copy: copy)
                }
                .padding(.horizontal, MainWindowDetailLayout.horizontalPadding(forWidth: geometry.size.width))
                .padding(.top, MainWindowDetailLayout.topPadding)
                .padding(.bottom, MainWindowDetailLayout.bottomPadding)
                .frame(maxWidth: MainWindowDetailLayout.preferencesContentMaxWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(theme.surface)
        }
    }

    private func header(copy: Copy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.title)
                .font(.system(size: 34, weight: .semibold))
            Text(copy.subtitle)
                .font(.callout)
                .foregroundStyle(theme.secondaryInk)
        }
        .foregroundStyle(theme.ink)
    }

    private func appearanceSection(copy: Copy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(copy.appearanceSectionTitle, detail: copy.appearanceSectionDetail)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(AppThemeID.allCases) { themeID in
                    themeOption(themeID: themeID, copy: copy)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(theme)
    }

    private func themeOption(themeID: AppThemeID, copy: Copy.Texts) -> some View {
        let candidate = AppTheme.theme(for: themeID)
        let isSelected = settingsStore.appThemeID == themeID

        return Button {
            settingsStore.appThemeID = themeID
            state.refresh()
        } label: {
            HStack(spacing: 12) {
                Text("Aa")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: ThemeOptionPreviewPresentation.iconAccentHex(for: themeID)))
                    .frame(width: 38, height: 34)
                    .background(
                        candidate.usesSystemMaterials ? theme.controlSurface : candidate.surface,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(candidate.usesSystemMaterials ? theme.border : candidate.border, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.displayName)
                        .font(.headline)
                }

                Spacer()

                HStack(spacing: 4) {
                    swatch(candidate.accent)
                    swatch(candidate.surface)
                    swatch(candidate.ink)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? theme.accent : theme.secondaryInk)
            }
            .padding(12)
            .foregroundStyle(theme.ink)
            .themedInset(theme, cornerRadius: 12)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? theme.accent : theme.border, lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(copy.appearanceThemeTitle): \(candidate.displayName)")
    }

    private func swatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 13, height: 13)
            .overlay {
                Circle()
                    .stroke(theme.border, lineWidth: 0.8)
            }
    }

    private func numericSection(copy: Copy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(copy.numericFormattingTitle, detail: copy.numericFormattingDetail)
            Toggle(copy.numericFormattingToggle, isOn: Binding(
                get: { settingsStore.isSmartNumericFormattingEnabled },
                set: {
                    settingsStore.isSmartNumericFormattingEnabled = $0
                    state.refresh()
                }
            ))
            .flowtypeSwitch(theme)
            exampleText(copy.numericFormattingExamples)
                .foregroundStyle(theme.secondaryInk)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(theme.ink)
        .themedCard(theme)
    }

    private func mathSection(copy: Copy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(copy.mathNotationTitle, detail: copy.mathNotationDetail)

            Toggle(copy.mathNotationToggle, isOn: Binding(
                get: { settingsStore.isMathNotationEnabled },
                set: {
                    settingsStore.isMathNotationEnabled = $0
                    state.refresh()
                }
            ))
            .flowtypeSwitch(theme)

            Picker(copy.mathOutputFormatTitle, selection: Binding(
                get: { settingsStore.mathNotationOutputFormat },
                set: {
                    settingsStore.mathNotationOutputFormat = $0
                    state.refresh()
                }
            )) {
                Text(copy.latex).tag(MathNotationOutputFormat.latex)
                Text(copy.unicode).tag(MathNotationOutputFormat.unicode)
            }
            .pickerStyle(.segmented)
            .disabled(!settingsStore.isMathNotationEnabled)

            exampleText(copy.mathNotationExamples)
                .foregroundStyle(theme.secondaryInk)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(theme.ink)
        .themedCard(theme)
    }

    private func fillerSection(copy: Copy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(copy.fillerCleanupTitle, detail: copy.fillerCleanupDetail)
            Toggle(copy.fillerCleanupToggle, isOn: Binding(
                get: { settingsStore.isFillerCleanupEnabled },
                set: {
                    settingsStore.isFillerCleanupEnabled = $0
                    state.refresh()
                }
            ))
            .flowtypeSwitch(theme)
            exampleText(copy.fillerCleanupExamples)
                .foregroundStyle(theme.secondaryInk)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(theme.ink)
        .themedCard(theme)
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(theme.secondaryInk)
        }
    }

    private func exampleText(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.medium))
            .textSelection(.enabled)
    }
}

private enum Copy {
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
    }

    static func texts(for language: UILanguage) -> Texts {
        switch language {
        case .chinese:
            return Texts(
                title: "转写与外观",
                subtitle: "调整界面主题和转写结果的本地格式化。模型与设备设置分别在对应页面管理。",
                appearanceSectionTitle: "外观",
                appearanceSectionDetail: "选择 Flowtype 的界面配色。Apple 主题跟随 macOS 原生外观。",
                appearanceThemeTitle: "主题",
                numericFormattingTitle: "智能数字格式",
                numericFormattingDetail: "自动把口述的数字整理成书面格式：日期、百分比、小数和常见编号。全部在本地完成。",
                numericFormattingToggle: "启用智能数字格式",
                numericFormattingExamples: "示例：二零二四年三月十八号 → 2024年3月18号；百分之三点五 → 3.5%",
                mathNotationTitle: "数学与统计符号",
                mathNotationDetail: "把口述的数学和统计表达转成规范符号，适合课程笔记与学术写作。可选 LaTeX 或 Unicode 两种输出。",
                mathNotationToggle: "启用数学与统计符号转换",
                mathOutputFormatTitle: "输出格式",
                mathNotationExamples: "示例：variance x → Var(X)；standard error beta hat → SE(β̂)；theta hat → \\hat{\\theta}（LaTeX）或 θ̂（Unicode）；x sub i → xᵢ；x bar → x̄",
                latex: "LaTeX",
                unicode: "Unicode",
                fillerCleanupTitle: "口头填充词清理",
                fillerCleanupDetail: "只删除“呃”“嗯”“um”这类短促的停顿词；“就是说”“然后呢”等表达会保留，不会改写你的原话。",
                fillerCleanupToggle: "启用口头填充词清理",
                fillerCleanupExamples: "示例：哦，嗯，我现在啊先说结论 → 我现在先说结论"
            )
        case .english:
            return Texts(
                title: "Transcription & Appearance",
                subtitle: "Adjust the interface theme and how transcripts are formatted locally. Manage models and devices on their dedicated pages.",
                appearanceSectionTitle: "Appearance",
                appearanceSectionDetail: "Choose Flowtype's color palette. The Apple theme follows the native macOS look.",
                appearanceThemeTitle: "Theme",
                numericFormattingTitle: "Smart numeric formatting",
                numericFormattingDetail: "Automatically formats spoken numbers as written text: dates, percentages, decimals, and common identifiers. Runs entirely on this Mac.",
                numericFormattingToggle: "Enable smart numeric formatting",
                numericFormattingExamples: "Example: 二零二四年三月十八号 → 2024年3月18号; 百分之三点五 → 3.5%",
                mathNotationTitle: "Math and statistics notation",
                mathNotationDetail: "Converts spoken math and statistics into proper notation — ideal for course notes and academic writing. Output as LaTeX or Unicode.",
                mathNotationToggle: "Enable math and statistics notation",
                mathOutputFormatTitle: "Output format",
                mathNotationExamples: "Examples: variance x → Var(X); standard error beta hat → SE(β̂); theta hat → \\hat{\\theta} (LaTeX) or θ̂ (Unicode); x sub i → xᵢ; x bar → x̄",
                latex: "LaTeX",
                unicode: "Unicode",
                fillerCleanupTitle: "Filler cleanup",
                fillerCleanupDetail: "Removes only short pause fillers such as 呃, 嗯, um, and uh. Connective phrases like 就是说 and 然后呢 are preserved — your wording is never rewritten.",
                fillerCleanupToggle: "Enable filler cleanup",
                fillerCleanupExamples: "Example: 哦，嗯，我现在啊先说结论 → 我现在先说结论"
            )
        }
    }
}
