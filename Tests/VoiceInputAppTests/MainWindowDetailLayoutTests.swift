import XCTest
@testable import VoiceInputApp

final class MainWindowDetailLayoutTests: XCTestCase {
    func testSetupStatusUsesStandardContentWidth() {
        XCTAssertEqual(MainWindowDetailLayout.readinessContentMaxWidth, MainWindowDetailLayout.standardContentMaxWidth)
        XCTAssertEqual(MainWindowDetailLayout.modelsContentMaxWidth, MainWindowDetailLayout.standardContentMaxWidth)
        XCTAssertEqual(MainWindowDetailLayout.preferencesContentMaxWidth, MainWindowDetailLayout.standardContentMaxWidth)
    }

    func testWideContentPagesStayGroupedSeparately() {
        XCTAssertEqual(MainWindowDetailLayout.homeContentMaxWidth, MainWindowDetailLayout.wideContentMaxWidth)
        XCTAssertEqual(MainWindowDetailLayout.dictionaryContentMaxWidth, MainWindowDetailLayout.wideContentMaxWidth)
    }

    func testResponsiveHorizontalPaddingMatchesExistingMainWindowPages() {
        XCTAssertEqual(MainWindowDetailLayout.horizontalPadding(forWidth: 759), 24)
        XCTAssertEqual(MainWindowDetailLayout.horizontalPadding(forWidth: 760), 36)
    }
}
