import XCTest
@testable import VoiceInputApp

final class ApplicationReopenPolicyTests: XCTestCase {
    func testPreservesWindowOrderWhenSettingsAndMainWindowAreVisible() {
        XCTAssertEqual(
            ApplicationReopenPolicy.action(mainWindow: .visible, settingsWindow: .visible),
            .preserveVisibleWindowOrder
        )
    }

    func testPreservesWindowOrderWhenOnlyMainWindowIsVisible() {
        XCTAssertEqual(
            ApplicationReopenPolicy.action(mainWindow: .visible, settingsWindow: .notVisible),
            .preserveVisibleWindowOrder
        )
    }

    func testPreservesWindowOrderWhenOnlySettingsWindowIsVisible() {
        XCTAssertEqual(
            ApplicationReopenPolicy.action(mainWindow: .notVisible, settingsWindow: .visible),
            .preserveVisibleWindowOrder
        )
    }

    func testShowsMainWindowWhenUserWindowsAreNotVisible() {
        XCTAssertEqual(
            ApplicationReopenPolicy.action(mainWindow: .notVisible, settingsWindow: .notVisible),
            .showMainWindow
        )
    }

    func testShowsMainWindowWhenMainWindowIsMiniaturized() {
        XCTAssertEqual(
            ApplicationReopenPolicy.action(mainWindow: .miniaturized, settingsWindow: .notVisible),
            .showMainWindow
        )
    }

    func testShowsMainWindowWhenOnlyTransientPanelsCouldBeVisible() {
        XCTAssertEqual(
            ApplicationReopenPolicy.action(mainWindow: .notVisible, settingsWindow: .notVisible),
            .showMainWindow,
            "Transient panels are deliberately excluded from the user-window policy."
        )
    }

    func testWindowVisibilityPrioritizesMiniaturizedState() {
        XCTAssertEqual(
            ApplicationWindowVisibility(isVisible: true, isMiniaturized: true),
            .miniaturized
        )
        XCTAssertEqual(
            ApplicationWindowVisibility(isVisible: true, isMiniaturized: false),
            .visible
        )
        XCTAssertEqual(
            ApplicationWindowVisibility(isVisible: false, isMiniaturized: false),
            .notVisible
        )
    }
}
