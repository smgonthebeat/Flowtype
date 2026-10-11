import AppKit
import Combine
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let settingsStore: SettingsStore
    private let baseActions: OnboardingActions

    /// Called after the window closes, regardless of whether the user
    /// finished or skipped; the app delegate marks onboarding complete and
    /// routes to the main window there.
    var onClose: ((ReadinessSnapshot?) -> Void)?
    private var completionSnapshot: ReadinessSnapshot?
    /// Freezes the onboarding animations at one moment; set by the snapshot harness.
    var illustrationStillTime: Double?
    private var textSizeObserver: AnyCancellable?

    init(settingsStore: SettingsStore, actions: OnboardingActions) {
        self.settingsStore = settingsStore
        self.baseActions = actions

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: OnboardingLayout.windowSize(for: AppTextSizeModel.shared.size)),
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
        textSizeObserver = AppTextSizeModel.shared.$size
            .removeDuplicates()
            .sink { [weak window] size in
                window?.setContentSize(OnboardingLayout.windowSize(for: size))
            }
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

        loadContent()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Builds the themed onboarding content without presenting the window.
    /// `show()` calls this first; the offscreen UI snapshot harness calls it
    /// directly so it can render the window without ordering it front.
    func loadContent() {
        let theme = AppTheme.theme(for: settingsStore.appThemeID)

        var actions = baseActions
        actions.requestClose = { [weak self] snapshot in
            self?.completionSnapshot = snapshot
            self?.close()
        }

        window?.backgroundColor = theme.usesSystemMaterials ? .windowBackgroundColor : NSColor(theme.surface)
        window?.appearance = theme.usesSystemMaterials ? nil : NSAppearance(named: .darkAqua)
        window?.contentView = NSHostingView(
            rootView: OnboardingView(
                model: VoiceInputModel.model(for: settingsStore.selectedModelID),
                actions: actions,
                settingsStore: settingsStore,
                illustrationStillTime: illustrationStillTime
            )
                .flowtypeTheme(theme)
        )
    }

    func windowWillClose(_ notification: Notification) {
        let snapshot = completionSnapshot
        completionSnapshot = nil
        onClose?(snapshot)
    }
}
