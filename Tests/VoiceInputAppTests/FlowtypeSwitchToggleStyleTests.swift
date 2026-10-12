import XCTest
@testable import VoiceInputApp

final class FlowtypeSwitchToggleStyleTests: XCTestCase {
    func testPaletteUsesThemeAccentForOnTrack() {
        let theme = AppTheme.theme(for: .oscurange)

        let palette = FlowtypeSwitchPalette.palette(for: theme, isOn: true)

        XCTAssertEqual(palette.trackHex, theme.accentHex)
        XCTAssertEqual(palette.thumbHex, "#FFFFFF")
    }

    func testPaletteUsesControlSurfaceForOffTrack() {
        let theme = AppTheme.theme(for: .oscurange)

        let palette = FlowtypeSwitchPalette.palette(for: theme, isOn: false)

        XCTAssertEqual(palette.trackHex, theme.controlSurfaceHex)
        XCTAssertEqual(palette.thumbHex, "#FFFFFF")
    }

    func testFlowtypeThemeUsesAccentGradientForOnTrackAndInkTintForOffTrack() {
        let theme = AppTheme.theme(for: .flowtype)

        let on = FlowtypeSwitchPalette.palette(for: theme, isOn: true)
        let off = FlowtypeSwitchPalette.palette(for: theme, isOn: false)

        XCTAssertEqual(on.trackHex, theme.accentHex)
        XCTAssertEqual(on.trackGradientHexes, FlowtypeAccent.fillStops)
        XCTAssertNil(off.trackGradientHexes)
        XCTAssertEqual(on.thumbHex, "#FFFFFF")
        // Ink at 6% (not the 4% neutral surface, which was too faint), with a 7% ink border.
        XCTAssertEqual(off.trackHex, "#2F30340F")
        XCTAssertEqual(off.thumbHex, "#FFFFFF")
    }

    func testAppearanceUsesSharedMetrics() {
        let theme = AppTheme.theme(for: .oscurange)

        let appearance = FlowtypeSwitchAppearance.appearance(for: theme, isOn: true)

        XCTAssertEqual(appearance.metrics.trackWidth, 42)
        XCTAssertEqual(appearance.metrics.trackHeight, 24)
        XCTAssertEqual(appearance.metrics.thumbSize, 20)
        XCTAssertEqual(appearance.metrics.cornerRadius, 11)
        XCTAssertEqual(appearance.palette.trackHex, theme.accentHex)
        XCTAssertNil(appearance.palette.trackGradientHexes)
        XCTAssertEqual(appearance.palette.thumbHex, "#FFFFFF")
    }

    func testMotionKeepsExistingTimingAndDisablesMovementWhenReduced() {
        XCTAssertEqual(FlowtypeSwitchMotion.duration(reduceMotion: false), 0.16)
        XCTAssertEqual(FlowtypeSwitchMotion.duration(reduceMotion: true), 0)
        XCTAssertTrue(FlowtypeSwitchMotion.animatesThumb(reduceMotion: false))
        XCTAssertFalse(FlowtypeSwitchMotion.animatesThumb(reduceMotion: true))
        XCTAssertTrue(FlowtypeSwitchMotion.isScopedToSwitchArtwork)
    }
}
