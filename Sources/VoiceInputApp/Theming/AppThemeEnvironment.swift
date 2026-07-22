import SwiftUI

private struct AppThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppTheme.theme(for: .oscurange)
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeEnvironmentKey.self] }
        set { self[AppThemeEnvironmentKey.self] = newValue }
    }
}

extension View {
    func flowtypeTheme(_ theme: AppTheme) -> some View {
        environment(\.appTheme, theme)
            .accentColor(theme.accent)
            .tint(theme.accent)
    }

    func flowtypeSwitch(_ theme: AppTheme) -> some View {
        toggleStyle(FlowtypeSwitchToggleStyle(theme: theme))
    }

    func themedCard(_ theme: AppTheme, cornerRadius: CGFloat = 16) -> some View {
        background(theme.elevatedSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            }
    }

    func themedInset(_ theme: AppTheme, cornerRadius: CGFloat = 10) -> some View {
        background(theme.controlSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
