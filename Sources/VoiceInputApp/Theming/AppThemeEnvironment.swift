import SwiftUI

private struct AppThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppTheme.theme(for: .flowtype)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeEnvironmentKey.self] }
        set { self[AppThemeEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Window-root styling: theme colours plus the interface text size.
    func flowtypeTheme(_ theme: AppTheme) -> some View {
        modifier(FlowtypeThemeModifier(theme: theme))
    }

    func flowtypeSwitch(_ theme: AppTheme) -> some View {
        toggleStyle(FlowtypeSwitchToggleStyle(theme: theme))
    }

    func themedCard(_ theme: AppTheme, cornerRadius: CGFloat = 16) -> some View {
        background(theme.elevatedSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.cardEdge, lineWidth: 1)
            }
            .themedCardShadow(theme)
    }

    /// A soft Dawn-violet shadow so opaque white cards still lift off the near-white base. Only a
    /// backdrop theme gets one; the other themes render exactly as before.
    @ViewBuilder
    func themedCardShadow(_ theme: AppTheme) -> some View {
        if theme.backdrop == nil {
            self
        } else {
            shadow(
                color: FlowtypeDawnSurface.shadow,
                radius: FlowtypeDawnSurface.shadowRadius,
                x: 0,
                y: FlowtypeDawnSurface.shadowOffsetY
            )
        }
    }

    /// A strip that sits directly on the page backdrop (not inside a card): the inset fill for
    /// flat themes, the white card treatment for a backdrop theme.
    @ViewBuilder
    func themedPageStrip(_ theme: AppTheme, cornerRadius: CGFloat = 10) -> some View {
        if theme.backdrop == nil {
            themedInset(theme, cornerRadius: cornerRadius)
        } else {
            themedCard(theme, cornerRadius: cornerRadius)
        }
    }

    func themedInset(_ theme: AppTheme, cornerRadius: CGFloat = 10) -> some View {
        background(theme.controlSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct FlowtypeThemeModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let theme: AppTheme

    func body(content: Content) -> some View {
        let resolved = theme.resolvingReduceTransparency(reduceTransparency)
        content
            .environment(\.appTheme, resolved)
            .accentColor(resolved.accent)
            .tint(resolved.accent)
            .flowtypeTextSize()
    }
}
