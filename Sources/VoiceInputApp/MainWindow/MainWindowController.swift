import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let state = MainWindowState()
    let readinessStore: MainWindowReadinessStore
    private let hotwordStore: HotwordStore
    private let historyStore: TranscriptHistoryStore
    private let settingsStore: SettingsStore
    private var appThemeObserver: NSObjectProtocol?

    init(
        hotwordStore: HotwordStore,
        historyStore: TranscriptHistoryStore,
        usageStatsStore: UsageStatsStore?,
        settingsStore: SettingsStore,
        modelManager: ModelManager,
        initialReadinessSnapshot: ReadinessSnapshot,
        actions: MainWindowActions
    ) {
        self.hotwordStore = hotwordStore
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        readinessStore = MainWindowReadinessStore(
            initialSnapshot: initialReadinessSnapshot,
            refreshLightweight: actions.refreshReadiness,
            refreshLive: actions.refreshReadinessLive
        )

        let rootView = MainWindowView(
            state: state,
            hotwordStore: hotwordStore,
            historyStore: historyStore,
            usageStatsStore: usageStatsStore,
            settingsStore: settingsStore,
            modelManager: modelManager,
            readinessStore: readinessStore,
            actions: actions
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1600, height: 960),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        // Keep the window title for Mission Control/accessibility, but hide it
        // in the titlebar: the sidebar identity row already carries the brand.
        window.title = "Flowtype"
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 1100, height: 680)
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.center()

        super.init(window: window)
        window.delegate = self
        applyWindowTheme()
        appThemeObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.appThemeDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyWindowTheme()
                self?.state.refresh()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let appThemeObserver {
            NotificationCenter.default.removeObserver(appThemeObserver)
        }
    }

    func show(section: MainWindowSection = .home) {
        applyWindowTheme()
        state.show(section)
        NSApp.setActivationPolicy(.regular)
        if window?.isMiniaturized == true {
            window?.deminiaturize(nil)
        }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reload() {
        applyWindowTheme()
        state.refresh()
    }

    func replaceReadinessSnapshot(_ snapshot: ReadinessSnapshot, refreshLive: Bool = true) {
        readinessStore.replace(with: snapshot)
        guard refreshLive else { return }
        Task { [readinessStore] in
            await readinessStore.refreshLive()
        }
    }

    private func applyWindowTheme() {
        guard let window else { return }

        let theme = AppTheme.theme(for: settingsStore.appThemeID)
        if theme.usesSystemMaterials {
            window.titlebarAppearsTransparent = false
            window.backgroundColor = .windowBackgroundColor
            window.appearance = nil
        } else {
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(theme.surface)
            window.appearance = NSAppearance(named: .darkAqua)
        }
        window.contentView?.needsDisplay = true
        window.displayIfNeeded()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
