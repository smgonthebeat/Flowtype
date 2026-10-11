import AppKit

/// One window treatment for every Flowtype window: full-size content under a transparent,
/// separator-free titlebar, so the sidebar (or page) colour runs to the top edge and the
/// traffic lights float on it. The window title stays set for Mission Control and VoiceOver.
enum WindowChrome {
    static func configure(_ window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
    }

    static func applyTheme(_ theme: AppTheme, to window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.backgroundColor = theme.usesSystemMaterials ? .windowBackgroundColor : NSColor(theme.surface)
        window.appearance = theme.usesSystemMaterials ? nil : NSAppearance(named: .darkAqua)
        window.contentView?.needsDisplay = true
    }
}
