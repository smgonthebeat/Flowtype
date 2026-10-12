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

    /// Settings, Help and onboarding are ordinary titled windows. A theme with a backdrop paints it
    /// under the titlebar as well, so a flat titlebar strip does not cut through the artwork.
    /// Other themes keep the standard layout.
    static func applyBackdropLayout(_ theme: AppTheme, to window: NSWindow) {
        if theme.backdrop != nil {
            window.styleMask.insert(.fullSizeContentView)
        } else {
            window.styleMask.remove(.fullSizeContentView)
        }
    }

    static func applyTheme(_ theme: AppTheme, to window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.backgroundColor = theme.usesSystemMaterials ? .windowBackgroundColor : NSColor(theme.surface)
        window.appearance = theme.windowAppearance
        window.contentView?.needsDisplay = true
    }
}
