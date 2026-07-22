import AppKit
import XCTest
@testable import VoiceInputApp

final class AppMainMenuTests: XCTestCase {
    func testApplicationMenuOffersOnboardingEntryPoint() {
        let chineseMenu = AppMainMenu.make(copy: AppCopy.texts(for: .chinese))
        let chineseItem = chineseMenu.items.first?.submenu?.item(withTitle: "新手引导…")
        XCTAssertNotNil(chineseItem)
        XCTAssertEqual(chineseItem?.action, #selector(AppDelegate.showOnboardingMenuItem(_:)))

        let englishMenu = AppMainMenu.make(copy: AppCopy.texts(for: .english))
        XCTAssertNotNil(englishMenu.items.first?.submenu?.item(withTitle: "Getting Started…"))
    }

    func testEditMenuProvidesStandardTextEditingCommands() {
        let menu = AppMainMenu.make()
        let editMenu = menu.item(withTitle: "Edit")?.submenu

        XCTAssertNotNil(editMenu)
        XCTAssertEqual(editMenu?.item(withTitle: "Select All")?.keyEquivalent, "a")
        XCTAssertEqual(editMenu?.item(withTitle: "Select All")?.action, #selector(NSText.selectAll(_:)))
        XCTAssertEqual(editMenu?.item(withTitle: "Copy")?.keyEquivalent, "c")
        XCTAssertEqual(editMenu?.item(withTitle: "Copy")?.action, #selector(NSText.copy(_:)))
        XCTAssertEqual(editMenu?.item(withTitle: "Paste")?.keyEquivalent, "v")
        XCTAssertEqual(editMenu?.item(withTitle: "Paste")?.action, #selector(NSText.paste(_:)))
    }
}
