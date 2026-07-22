import AppKit

enum AppMainMenu {
    static func make(copy: AppCopy.Texts = AppCopy.texts(for: .chinese)) -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(applicationMenuItem(copy: copy))
        mainMenu.addItem(editMenuItem())
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
                title: "Quit Flowtype",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        let item = NSMenuItem()
        item.submenu = appMenu
        return item
    }

    private static func editMenuItem() -> NSMenuItem {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))

        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        let item = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        item.submenu = editMenu
        return item
    }
}
