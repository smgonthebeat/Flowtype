import AppKit

enum AppMainMenu {
    static func make(copy: AppCopy.Texts = AppCopy.texts(for: .chinese)) -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(applicationMenuItem(copy: copy))
        mainMenu.addItem(editMenuItem(copy: copy))
        mainMenu.addItem(viewMenuItem(copy: copy))
        return mainMenu
    }

    private static func applicationMenuItem(copy: AppCopy.Texts) -> NSMenuItem {
        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(
                title: copy.onboardingMenuTitle,
                action: #selector(AppDelegate.showOnboardingMenuItem(_:)),
                keyEquivalent: ""
            )
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: copy.mainMenuQuit,
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        let item = NSMenuItem()
        item.submenu = appMenu
        return item
    }

    /// Text size: ⌘+ / ⌘− step through the three sizes, ⌘0 returns to the default.
    private static func viewMenuItem(copy: AppCopy.Texts) -> NSMenuItem {
        let viewMenu = NSMenu(title: copy.mainMenuView)
        viewMenu.addItem(NSMenuItem(
            title: copy.mainMenuTextBigger,
            action: #selector(AppDelegate.increaseTextSize(_:)),
            keyEquivalent: "+"
        ))
        // ⌘= is the unshifted key that carries + on most layouts; accept it without listing it twice.
        let equalsItem = NSMenuItem(
            title: copy.mainMenuTextBigger,
            action: #selector(AppDelegate.increaseTextSize(_:)),
            keyEquivalent: "="
        )
        equalsItem.isHidden = true
        equalsItem.allowsKeyEquivalentWhenHidden = true
        viewMenu.addItem(equalsItem)
        viewMenu.addItem(NSMenuItem(
            title: copy.mainMenuTextSmaller,
            action: #selector(AppDelegate.decreaseTextSize(_:)),
            keyEquivalent: "-"
        ))
        viewMenu.addItem(.separator())
        viewMenu.addItem(NSMenuItem(
            title: copy.mainMenuTextDefault,
            action: #selector(AppDelegate.resetTextSize(_:)),
            keyEquivalent: "0"
        ))

        let item = NSMenuItem(title: copy.mainMenuView, action: nil, keyEquivalent: "")
        item.submenu = viewMenu
        return item
    }

    private static func editMenuItem(copy: AppCopy.Texts) -> NSMenuItem {
        let editMenu = NSMenu(title: copy.mainMenuEdit)
        editMenu.addItem(NSMenuItem(title: copy.mainMenuUndo, action: Selector(("undo:")), keyEquivalent: "z"))

        let redoItem = NSMenuItem(title: copy.mainMenuRedo, action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: copy.mainMenuCut, action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: copy.mainMenuCopy, action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: copy.mainMenuPaste, action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: copy.mainMenuSelectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        let item = NSMenuItem(title: copy.mainMenuEdit, action: nil, keyEquivalent: "")
        item.submenu = editMenu
        return item
    }
}
