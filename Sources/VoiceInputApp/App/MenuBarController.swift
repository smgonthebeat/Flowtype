import AppKit

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let settingsStore: SettingsStore
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

    private func makeMenu() -> NSMenu {
        let copy = AppCopy.texts(for: settingsStore.uiLanguage)
        let currentModel = VoiceInputModel.model(for: settingsStore.selectedModelID)
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: copy.menuShowHome, action: #selector(openHome), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: copy.menuShowDictionary, action: #selector(openDictionary), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: copy.currentModelMenuTitle(copy.modelRoleTitle(for: currentModel)), action: #selector(openModels), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: copy.menuShowPreferences, action: #selector(openPreferences), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: copy.menuSettings, action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: copy.menuSetupStatus, action: #selector(openSetupStatus), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: copy.onboardingMenuTitle, action: #selector(showOnboarding), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: copy.menuPasteLastTranscript, action: #selector(pasteLastTranscript), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: copy.menuQuit, action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    private static func makeStatusIcon() -> NSImage? {
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
