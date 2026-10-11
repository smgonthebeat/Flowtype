import SwiftUI

// Owner feedback (2026-10-03): AppKit draws accent-tinted bezels (prominent buttons, pop-up
// menu arrows, segmented pickers, progress bars) by darkening and desaturating the tint, so the
// Oscurange peach came out as a muddy gold in the running app. These controls are drawn here
// with the exact theme colours instead, at the same sizes as the system regular/large controls.

/// Accent-filled button in the exact theme accent, replacing `.borderedProminent`.
struct FlowtypeProminentButtonStyle: ButtonStyle {
    let theme: AppTheme
    var isLarge = false

    func makeBody(configuration: Configuration) -> some View {
        ProminentBody(configuration: configuration, theme: theme, isLarge: isLarge)
    }

    private struct ProminentBody: View {
        let configuration: Configuration
        let theme: AppTheme
        let isLarge: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .scaledFont(size: 13, weight: .medium)
                .foregroundStyle(isEnabled ? theme.onAccent : theme.tertiaryInk)
                .padding(.horizontal, isLarge ? 16 : 10)
                .frame(minHeight: isLarge ? 30 : 22)
                .background(
                    isEnabled ? theme.accent : theme.controlSurface,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .opacity(configuration.isPressed ? 0.82 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

/// Neutral filled button, for controls that sit beside a menu drawn the same way.
struct FlowtypeNeutralButtonStyle: ButtonStyle {
    let theme: AppTheme
    var isLarge = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(size: 13)
            .foregroundStyle(theme.ink)
            .padding(.horizontal, isLarge ? 16 : 10)
            .frame(minHeight: isLarge ? 30 : 22)
            .background(
                configuration.isPressed ? theme.hoverSurface : theme.controlSurface,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Two-or-more option picker drawn in the exact accent, replacing `.pickerStyle(.segmented)`.
struct FlowtypeSegmentedPicker<Value: Hashable>: View {
    let theme: AppTheme
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .scaledFont(size: 13, weight: isSelected ? .medium : .regular)
                        .foregroundStyle(textColor(isSelected: isSelected))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 22)
                        .background(
                            fillColor(isSelected: isSelected),
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    // Disabled uses neutral greys: a faded accent over the dark surface reads as muddy brown.
    private func fillColor(isSelected: Bool) -> Color {
        guard isSelected else { return .clear }
        return isEnabled ? theme.accent : theme.hoverSurface
    }

    private func textColor(isSelected: Bool) -> Color {
        guard isEnabled else { return theme.tertiaryInk }
        return isSelected ? theme.onAccent : theme.secondaryInk
    }
}

/// Determinate progress bar in the exact accent, replacing a tinted `ProgressView(value:)`.
struct FlowtypeProgressBar: View {
    let theme: AppTheme
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.controlSurface)
                Capsule()
                    .fill(theme.accent)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityValue("\(Int((min(max(value, 0), 1) * 100).rounded()))%")
    }
}
