import XCTest
@testable import VoiceInputApp

final class AppThemeTests: XCTestCase {
    func testBuiltInThemesExposeOnlyAppleCodexAndOscurange() {
        XCTAssertEqual(AppThemeID.allCases.map(\.rawValue), [
            "default",
            "codex",
            "oscurange"
        ])

        XCTAssertEqual(AppTheme.theme(for: .codex).accentHex, "#0169CC")
        XCTAssertEqual(AppTheme.theme(for: .codex).surfaceHex, "#111111")
        XCTAssertEqual(AppTheme.theme(for: .codex).inkHex, "#FCFCFC")

        XCTAssertEqual(AppTheme.theme(for: .oscurange).accentHex, "#F9B98C")
        XCTAssertEqual(AppTheme.theme(for: .oscurange).surfaceHex, "#0B0B0F")
        XCTAssertEqual(AppTheme.theme(for: .oscurange).inkHex, "#E6E6E6")
    }

    func testAppleThemeKeepsExistingDefaultIdentityAndSystemAppearance() {
        let theme = AppTheme.theme(for: .default)

        XCTAssertEqual(theme.id.rawValue, "default")
        XCTAssertTrue(theme.usesSystemMaterials)
        XCTAssertEqual(theme.displayName, "Apple")
    }

    func testThemeOptionPreviewUsesCandidateAccentForApple() {
        XCTAssertEqual(
            ThemeOptionPreviewPresentation.iconAccentHex(for: .default),
            "#0A84FF"
        )
    }

    func testThemesDefineReadableOnAccentColors() {
        XCTAssertEqual(AppTheme.theme(for: .default).onAccentHex, "#FFFFFF")
        XCTAssertEqual(AppTheme.theme(for: .codex).onAccentHex, "#FFFFFF")
        // Oscurange's light peach accent needs dark text on top, not white.
        XCTAssertEqual(AppTheme.theme(for: .oscurange).onAccentHex, "#33210F")
    }
}
