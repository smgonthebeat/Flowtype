import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let settingsStore: SettingsStore
    private let baseActions: OnboardingActions

    /// Called after the window closes, regardless of whether the user
    /// finished or skipped; the app delegate marks onboarding complete and
    /// routes to the main window there.
    var onClose: (() -> Void)?

    init(settingsStore: SettingsStore, actions: OnboardingActions) {
        self.settingsStore = settingsStore
        self.baseActions = actions

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Flowtype"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        // Already on screen (e.g. the menu item is clicked again): just come
        // forward. Rebuilding the content view would reset the flow's state
        // mid-download.
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let copy = AppCopy.texts(for: settingsStore.uiLanguage)
        let theme = AppTheme.theme(for: settingsStore.appThemeID)

        var actions = baseActions
        actions.requestClose = { [weak self] in
            self?.close()
        }

        window?.backgroundColor = theme.usesSystemMaterials ? .windowBackgroundColor : NSColor(theme.surface)
        window?.appearance = theme.usesSystemMaterials ? nil : NSAppearance(named: .darkAqua)
        window?.contentView = NSHostingView(
            rootView: OnboardingView(
                copy: copy,
                model: VoiceInputModel.model(for: settingsStore.selectedModelID),
                actions: actions
            )
                .flowtypeTheme(theme)
        )
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
