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
        let copy = PreferencesCopy.texts(for: settingsStore.uiLanguage)

        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(copy: copy)
                    appearanceSection(copy: copy)
                    // Owner order (2026-10-11): the two switches that are on by default come first.
                    numericSection(copy: copy)
                    fillerSection(copy: copy)
                    academicReferenceSection(copy: copy)
                    mathSection(copy: copy)
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

    private func header(copy: PreferencesCopy.Texts) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.title)
                .scaledFont(size: 34, weight: .semibold)
            Text(copy.subtitle)
                .scaledFont(.callout)
                .foregroundStyle(theme.secondaryInk)
        }
        .foregroundStyle(theme.ink)
    }

    private func appearanceSection(copy: PreferencesCopy.Texts) -> some View {
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

    private func themeOption(themeID: AppThemeID, copy: PreferencesCopy.Texts) -> some View {
        let candidate = AppTheme.theme(for: themeID)
        let isSelected = settingsStore.appThemeID == themeID

        return Button {
            settingsStore.appThemeID = themeID
            state.refresh()
        } label: {
            HStack(spacing: 12) {
                Text("Aa")
                    .scaledFont(size: 17, weight: .bold)
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
                        .scaledFont(.headline)
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

    private func numericSection(copy: PreferencesCopy.Texts) -> some View {
        toggleSection(
            title: copy.numericFormattingTitle,
            detail: copy.numericFormattingDetail,
            toggleLabel: copy.numericFormattingToggle,
            examples: copy.numericFormattingExamples,
            isOn: binding(\.isSmartNumericFormattingEnabled)
        )
    }

    private func academicReferenceSection(copy: PreferencesCopy.Texts) -> some View {
        toggleSection(
            title: copy.academicReferenceFormattingTitle,
            detail: copy.academicReferenceFormattingDetail,
            toggleLabel: copy.academicReferenceFormattingToggle,
            examples: copy.academicReferenceFormattingExamples,
            isOn: binding(\.isAcademicReferenceFormattingEnabled)
        )
    }

    private func mathSection(copy: PreferencesCopy.Texts) -> some View {
        toggleSection(
            title: copy.mathNotationTitle,
            detail: copy.mathNotationDetail,
            toggleLabel: copy.mathNotationToggle,
            examples: copy.mathNotationExamples,
            isOn: binding(\.isMathNotationEnabled)
        ) {
            HStack(spacing: 12) {
                Text(copy.mathOutputFormatTitle)
                    .appText(.label)
                    .foregroundStyle(theme.ink)
                FlowtypeSegmentedPicker(
                    theme: theme,
                    selection: Binding(
                        get: { settingsStore.mathNotationOutputFormat },
                        set: {
                            settingsStore.mathNotationOutputFormat = $0
                            state.refresh()
                        }
                    ),
                    options: [(.latex, copy.latex), (.unicode, copy.unicode)]
                )
                .accessibilityLabel(copy.mathOutputFormatTitle)
                .disabled(!settingsStore.isMathNotationEnabled)
            }
        }
    }

    private func fillerSection(copy: PreferencesCopy.Texts) -> some View {
        toggleSection(
            title: copy.fillerCleanupTitle,
            detail: copy.fillerCleanupDetail,
            toggleLabel: copy.fillerCleanupToggle,
            examples: copy.fillerCleanupExamples,
            isOn: binding(\.isFillerCleanupEnabled)
        ) {
            if settingsStore.isFillerCleanupSafetyNoticePending {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(copy.fillerCleanupSafetyNotice)
                        .scaledFont(.callout)
                        .foregroundStyle(theme.secondaryInk)

                    Spacer(minLength: 8)

                    Button(copy.fillerCleanupSafetyNoticeDismiss) {
                        settingsStore.dismissFillerCleanupSafetyNotice()
                        state.refresh()
                    }
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .themedInset(theme, cornerRadius: 10)
            }
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Bool>) -> Binding<Bool> {
        Binding(
            get: { settingsStore[keyPath: keyPath] },
            set: {
                settingsStore[keyPath: keyPath] = $0
                state.refresh()
            }
        )
    }

    /// Owner choice (2026-10-03): the switch sits on the title row and the examples are listed one
    /// per line, input in grey and result in white, so each before/after pair reads at a glance.
    private func toggleSection<Extra: View>(
        title: String,
        detail: String,
        toggleLabel: String,
        examples: String,
        isOn: Binding<Bool>,
        @ViewBuilder extra: () -> Extra = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                sectionText(title, detail: detail)
                Spacer(minLength: 12)
                // The custom style draws its label, so the visible label is empty and the
                // "启用…" string becomes the accessibility label.
                Toggle(isOn: isOn) { EmptyView() }
                    .flowtypeSwitch(theme)
                    .accessibilityLabel(toggleLabel)
            }

            extra()

            exampleList(examples)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(theme)
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .scaledFont(.title3, weight: .semibold)
            Text(detail)
                .scaledFont(.callout)
                .foregroundStyle(theme.secondaryInk)
        }
    }

    private func sectionText(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appText(.heading)
                .foregroundStyle(theme.ink)
            Text(detail)
                .appText(.secondary)
                .foregroundStyle(theme.secondaryInk)
                .frame(maxWidth: AppTextWidth.pageSubtitle, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func exampleList(_ text: String) -> some View {
        let lines = PreferencesExampleFormatting.lines(text)
        let eyebrow = PreferencesCopy.texts(for: settingsStore.uiLanguage).examplesTitle

        return VStack(alignment: .leading, spacing: AppSpacing.x1) {
            Text(eyebrow)
                .appText(.caption)
                .foregroundStyle(theme.tertiaryInk)
                .padding(.bottom, 2)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line {
                case let .pair(input, output):
                    (Text(input).foregroundStyle(theme.secondaryInk)
                        + Text("  →  ").foregroundStyle(theme.tertiaryInk)
                        + Text(output).foregroundStyle(theme.ink))
                        .appText(.secondary)
                case let .note(note):
                    Text(note)
                        .appText(.secondary)
                        .foregroundStyle(theme.secondaryInk)
                }
            }
        }
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Splits a one-line example string ("示例：a → b；c → d。note") into one row per pair.
enum PreferencesExampleFormatting {
    enum Line: Equatable {
        case pair(String, String)
        case note(String)
    }

    static func lines(_ text: String) -> [Line] {
        var body = text
        for prefix in ["示例：", "Examples: ", "Example: "] where body.hasPrefix(prefix) {
            body = String(body.dropFirst(prefix.count))
        }
        let items = body
            .replacingOccurrences(of: "；", with: "\u{1F}")
            .replacingOccurrences(of: "; ", with: "\u{1F}")
            .split(separator: "\u{1F}")
        var lines: [Line] = []
        for item in items {
            // A trailing remark after the last pair ("…→ 21。“这段代码两三行”保持不变").
            let parts = String(item)
                .replacingOccurrences(of: "。", with: "\u{1F}")
                .replacingOccurrences(of: ". ", with: "\u{1F}")
                .split(separator: "\u{1F}")
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                if let arrow = trimmed.range(of: " → ") {
                    lines.append(.pair(String(trimmed[..<arrow.lowerBound]), String(trimmed[arrow.upperBound...])))
                } else {
                    lines.append(.note(trimmed))
                }
            }
        }
        return lines
    }
}
