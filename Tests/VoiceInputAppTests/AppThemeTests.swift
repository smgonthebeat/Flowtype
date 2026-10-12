import AppKit
import SwiftUI
import XCTest
@testable import VoiceInputApp

final class AppThemeTests: XCTestCase {
    func testBuiltInThemesExposeAppleCodexOscurangeAndFlowtype() {
        XCTAssertEqual(AppThemeID.allCases.map(\.rawValue), [
            "default",
            "codex",
            "oscurange",
            "flowtype"
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

    func testFlowtypeThemeIsLightWithReferenceCornerBackdrop() {
        let theme = AppTheme.theme(for: .flowtype)

        XCTAssertEqual(theme.id.rawValue, "flowtype")
        XCTAssertEqual(theme.displayName, "Flowtype Dawn")
        XCTAssertEqual(theme.accentHex, "#6F5FA6")
        XCTAssertEqual(theme.onAccentHex, "#2F3034")
        XCTAssertEqual(theme.accentGradientHexes, ["#FBD8C3", "#E3CFE0", "#ACCDF2"])
        XCTAssertEqual(theme.surfaceHex, "#FBFBFB")
        XCTAssertEqual(theme.inkHex, "#2F3034")
        XCTAssertEqual(theme.elevatedSurfaceHex, "#FFFFFF")
        XCTAssertEqual(theme.controlSurfaceHex, "#2F30340A")
        XCTAssertEqual(theme.sidebarSurfaceHex, "#FFFFFF4D")
        XCTAssertEqual(theme.hoverSurfaceHex, "#2F303414")
        XCTAssertEqual(theme.borderHex, "#2F303412")
        XCTAssertEqual(theme.voiceHex, "#5B9BE6")
        XCTAssertFalse(theme.usesSystemMaterials)
        XCTAssertTrue(theme.prefersOpaqueWindows)
        XCTAssertFalse(theme.isDark)
        XCTAssertEqual(theme.backdrop, .referenceCorners)
        XCTAssertEqual(theme.windowAppearance?.name, .aqua)
    }

    func testDawnCleanWhiteConstantsMatchTheOwnersChoiceC() {
        XCTAssertEqual(FlowtypeDawnSurface.baseHex, "#FBFBFB")
        XCTAssertEqual(FlowtypeDawnSurface.cornerSaturation, 1.25)
        XCTAssertEqual(FlowtypeDawnSurface.cornerDensity, 0.45)
        XCTAssertEqual(FlowtypeDawnSurface.centreGlow, 0.20)
        XCTAssertEqual(FlowtypeDawnSurface.centreGlowRadius, CGSize(width: 0.34, height: 0.40))
        XCTAssertEqual(FlowtypeDawnSurface.centreGlowCentre, CGPoint(x: 0.60, y: 0.46))
        XCTAssertEqual(FlowtypeDawnSurface.edgeHex, "#6F5FA6")
        XCTAssertEqual(FlowtypeDawnSurface.edgeOpacity, 0.08)
        XCTAssertEqual(FlowtypeDawnSurface.shadowOpacity, 0.14)
    }

    func testOnlyABackdropThemeOutlinesCardsInTheDawnViolet() {
        for id in AppThemeID.allCases {
            let theme = AppTheme.theme(for: id)
            if theme.backdrop != nil {
                XCTAssertEqual(theme.cardEdge, FlowtypeDawnSurface.edge, "card edge for \(id.rawValue)")
            } else {
                XCTAssertEqual(theme.cardEdge, theme.border, "card edge for \(id.rawValue)")
            }
        }
    }

    func testOnlyFlowtypeHasAGradientAccent() {
        for id in AppThemeID.allCases {
            let theme = AppTheme.theme(for: id)
            XCTAssertEqual(theme.accentGradientHexes != nil, id == .flowtype, "accent gradient for \(id.rawValue)")
        }
    }

    func testOnlyFlowtypeHasABackdrop() {
        for id in AppThemeID.allCases {
            let theme = AppTheme.theme(for: id)
            XCTAssertEqual(theme.backdrop != nil, id == .flowtype, "backdrop for \(id.rawValue)")
        }
    }

    func testWindowAppearanceFollowsThemeBrightness() {
        XCTAssertNil(AppTheme.theme(for: .default).windowAppearance)
        XCTAssertEqual(AppTheme.theme(for: .codex).windowAppearance?.name, .darkAqua)
        XCTAssertEqual(AppTheme.theme(for: .oscurange).windowAppearance?.name, .darkAqua)
        XCTAssertEqual(AppTheme.theme(for: .flowtype).windowAppearance?.name, .aqua)
    }

    func testHexColorParsesSixDigitValuesAsOpaque() {
        let components = HexColor.components("#3672C2")

        XCTAssertEqual(components.red, 0x36 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(components.green, 0x72 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(components.blue, 0xC2 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(components.alpha, 1)
        XCTAssertEqual(HexColor.components("0B0B0F"), HexColor.components("#0B0B0F"))
    }

    func testHexColorParsesEightDigitValuesWithAlpha() {
        let components = HexColor.components("#FFFFFFCC")

        XCTAssertEqual(components.red, 1)
        XCTAssertEqual(components.green, 1)
        XCTAssertEqual(components.blue, 1)
        XCTAssertEqual(components.alpha, 0xCC / 255.0, accuracy: 1e-9)

        let ink = HexColor.components("#2F30340F")
        XCTAssertEqual(ink.red, 0x2F / 255.0, accuracy: 1e-9)
        XCTAssertEqual(ink.green, 0x30 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(ink.blue, 0x34 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(ink.alpha, 0x0F / 255.0, accuracy: 1e-9)
    }

    func testColorHexKeepsSixDigitColoursUnchanged() throws {
        let color = try XCTUnwrap(NSColor(Color(hex: "#F9B98C")).usingColorSpace(.sRGB))

        XCTAssertEqual(color.redComponent, 0xF9 / 255.0, accuracy: 0.002)
        XCTAssertEqual(color.greenComponent, 0xB9 / 255.0, accuracy: 0.002)
        XCTAssertEqual(color.blueComponent, 0x8C / 255.0, accuracy: 0.002)
        XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.002)

        let translucent = try XCTUnwrap(NSColor(Color(hex: "#FFFFFF4D")).usingColorSpace(.sRGB))
        XCTAssertEqual(translucent.alphaComponent, 0x4D / 255.0, accuracy: 0.002)
    }
}
