import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var readinessItem: NSMenuItem?
    private var readinessSeparator: NSMenuItem?
    private var pasteLastTranscriptItem: NSMenuItem?
    private let settingsStore: SettingsStore
    private let readinessSummary: () -> ReadinessSummary?
    private let hasLastTranscript: () -> Bool
    private let onMenuWillOpen: () -> Void
    private let onOpenHome: () -> Void
    private let onOpenDictionary: () -> Void
    private let onOpenModels: () -> Void
    private let onOpenPreferences: () -> Void
    private let onOpenSettings: () -> Void
    private let onShowHelp: () -> Void
    private let onOpenSetupStatus: () -> Void
    private let onShowOnboarding: () -> Void
    private let onPasteLastTranscript: () -> Void

    init(
        settingsStore: SettingsStore,
        readinessSummary: @escaping () -> ReadinessSummary? = { nil },
        hasLastTranscript: @escaping () -> Bool = { true },
        onMenuWillOpen: @escaping () -> Void = {},
        onOpenHome: @escaping () -> Void = {},
        onOpenDictionary: @escaping () -> Void = {},
        onOpenModels: @escaping () -> Void = {},
        onOpenPreferences: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onShowHelp: @escaping () -> Void = {},
        onOpenSetupStatus: @escaping () -> Void = {},
        onShowOnboarding: @escaping () -> Void = {},
        onPasteLastTranscript: @escaping () -> Void = {}
    ) {
        self.settingsStore = settingsStore
        self.readinessSummary = readinessSummary
        self.hasLastTranscript = hasLastTranscript
        self.onMenuWillOpen = onMenuWillOpen
        self.onOpenHome = onOpenHome
        self.onOpenDictionary = onOpenDictionary
        self.onOpenModels = onOpenModels
        self.onOpenPreferences = onOpenPreferences
        self.onOpenSettings = onOpenSettings
        self.onShowHelp = onShowHelp
        self.onOpenSetupStatus = onOpenSetupStatus
        self.onShowOnboarding = onShowOnboarding
        self.onPasteLastTranscript = onPasteLastTranscript
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.title = ""
            button.image = Self.makeStatusIcon()
            button.imagePosition = .imageOnly
        }

        item.menu = makeMenu()
        statusItem = item
    }

    func refreshMenu() {
        statusItem?.menu = makeMenu()
    }

    /// Order (owner review, 2026-10-11): readiness first, then the most common recovery
    /// action, then the main-window pages in sidebar order, then the other windows.
    private func makeMenu() -> NSMenu {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)
        let currentModel = VoiceInputModel.model(for: settingsStore.selectedModelID)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let readiness = NSMenuItem(title: "", action: #selector(openSetupStatus), keyEquivalent: "")
        readiness.target = self
        readiness.isHidden = true
        menu.addItem(readiness)
        readinessItem = readiness
        let separator = NSMenuItem.separator()
        separator.isHidden = true
        menu.addItem(separator)
        readinessSeparator = separator

        let paste = item(copy.menuPasteLastTranscript, #selector(pasteLastTranscript))
        menu.addItem(paste)
        pasteLastTranscriptItem = paste
        menu.addItem(.separator())

        menu.addItem(item(copy.menuShowHome, #selector(openHome)))
        menu.addItem(item(copy.menuShowDictionary, #selector(openDictionary)))
        menu.addItem(item(copy.currentModelMenuTitle(copy.modelRoleTitle(for: currentModel)), #selector(openModels)))
        menu.addItem(item(copy.menuSetupStatus, #selector(openSetupStatus)))
        menu.addItem(item(copy.menuShowPreferences, #selector(openPreferences)))
        menu.addItem(.separator())
        menu.addItem(item(copy.menuSettings, #selector(openSettings), key: ","))
        menu.addItem(item(copy.onboardingMenuTitle, #selector(showOnboarding)))
        menu.addItem(item(copy.menuHelp, #selector(showHelp)))
        menu.addItem(.separator())
        menu.addItem(item(copy.menuQuit, #selector(quit), key: "q"))
        updateDynamicItems()
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateDynamicItems()
        onMenuWillOpen()
    }

    /// Refreshes the readiness line and the paste item. Safe to call while the menu is open;
    /// AppKit redraws changed items in place.
    func updateDynamicItems() {
        pasteLastTranscriptItem?.isEnabled = hasLastTranscript()
        guard let readinessItem else { return }
        guard let summary = readinessSummary() else {
            readinessItem.isHidden = true
            readinessSeparator?.isHidden = true
            return
        }
        readinessItem.isHidden = false
        readinessSeparator?.isHidden = false
        readinessItem.title = summary.text
        readinessItem.image = Self.statusDot(for: summary.tone)
    }

    private static func statusDot(for tone: ReadinessSummary.Tone) -> NSImage? {
        let color: NSColor
        switch tone {
        case .ready: color = .systemGreen
        case .working: color = .systemGray
        case .attention: color = .systemOrange
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }

    /// Internal (not private) so the asset-library renderer can export the exact menu bar icon.
    static func makeStatusIcon() -> NSImage? {
        let sourceImage: NSImage?
        if let url = Bundle.main.url(forResource: "Flowtype-logo", withExtension: "svg") {
            sourceImage = NSImage(contentsOf: url)
        } else {
            sourceImage = NSImage(contentsOfFile: "Resources/Flowtype-logo.svg")
        }

        guard let sourceImage else { return NSImage(systemSymbolName: "waveform", accessibilityDescription: "Flowtype") }

        let image = NSImage(size: NSSize(width: 22, height: 18))
        image.lockFocus()
        let baseRect = NSRect(x: 0, y: 1, width: 22, height: 16)
        let sourceRect = NSRect(x: 210, y: 395, width: 860, height: 500)
        let offsets: [NSPoint] = [
            NSPoint(x: 0, y: 0),
            NSPoint(x: 0.22, y: 0),
            NSPoint(x: -0.22, y: 0)
        ]
        for offset in offsets {
            sourceImage.draw(
                in: baseRect.offsetBy(dx: offset.x, dy: offset.y),
                from: sourceRect,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }
        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "Flowtype"
        return image
    }

    func uninstall() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    @objc private func openHome() {
        onOpenHome()
    }

    @objc private func openDictionary() {
        onOpenDictionary()
    }

    @objc private func openModels() {
        onOpenModels()
    }

    @objc private func openPreferences() {
        onOpenPreferences()
    }

    @objc private func showOnboarding() {
        onShowOnboarding()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func showHelp() {
        onShowHelp()
    }

    @objc private func openSetupStatus() {
        onOpenSetupStatus()
    }

    @objc private func pasteLastTranscript() {
        onPasteLastTranscript()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
