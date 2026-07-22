import SwiftUI

struct FlowtypeSwitchPalette: Equatable {
    let trackHex: String
    let thumbHex: String

    static func palette(for theme: AppTheme, isOn: Bool) -> FlowtypeSwitchPalette {
        // White thumb on every track, matching the system switch convention,
        // so light accents (Oscurange peach) keep a visible thumb edge.
        FlowtypeSwitchPalette(
            trackHex: isOn ? theme.accentHex : theme.controlSurfaceHex,
            thumbHex: "#FFFFFF"
        )
    }
}

struct FlowtypeSwitchMetrics: Equatable {
    let trackWidth: CGFloat
    let trackHeight: CGFloat
    let thumbSize: CGFloat
    let cornerRadius: CGFloat

    static let standard = FlowtypeSwitchMetrics(
        trackWidth: 42,
        trackHeight: 24,
        thumbSize: 20,
        cornerRadius: 11
    )
}

struct FlowtypeSwitchAppearance: Equatable {
    let palette: FlowtypeSwitchPalette
    let metrics: FlowtypeSwitchMetrics

    static func appearance(for theme: AppTheme, isOn: Bool) -> FlowtypeSwitchAppearance {
        FlowtypeSwitchAppearance(
            palette: .palette(for: theme, isOn: isOn),
            metrics: .standard
        )
    }
}

enum FlowtypeSwitchMotion {
    static let isScopedToSwitchArtwork = true

    static func duration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : 0.16
    }

    static func animatesThumb(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    static func animation(reduceMotion: Bool) -> Animation? {
        guard animatesThumb(reduceMotion: reduceMotion) else { return nil }
        return .easeInOut(duration: duration(reduceMotion: reduceMotion))
    }
}

struct FlowtypeSwitchToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        let appearance = FlowtypeSwitchAppearance.appearance(for: theme, isOn: configuration.isOn)

        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                configuration.label

                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: appearance.metrics.cornerRadius, style: .continuous)
                        .fill(Color(hex: appearance.palette.trackHex))
                        .overlay {
                            RoundedRectangle(cornerRadius: appearance.metrics.cornerRadius, style: .continuous)
                                .stroke(theme.border.opacity(configuration.isOn ? 0.0 : 1.0), lineWidth: 1)
                        }

                    Circle()
                        .fill(Color(hex: appearance.palette.thumbHex))
                        .frame(width: appearance.metrics.thumbSize, height: appearance.metrics.thumbSize)
                        .shadow(color: .black.opacity(0.24), radius: 1, x: 0, y: 1)
                        .padding(2)
                }
                .frame(width: appearance.metrics.trackWidth, height: appearance.metrics.trackHeight)
                .animation(
                    FlowtypeSwitchMotion.animation(reduceMotion: reduceMotion),
                    value: configuration.isOn
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRemoveTraits(.isButton)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
        .accessibilityAction {
            configuration.isOn.toggle()
        }
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}
