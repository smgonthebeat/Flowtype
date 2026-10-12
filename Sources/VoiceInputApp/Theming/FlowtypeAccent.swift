import SwiftUI

/// The Flowtype Dawn theme's accent ("Dawn", 晨光, named by the owner 2026-10-12): the logo's own warm-to-cool blend (peach, through pink-lavender,
/// into soft blue), measured from the bottom-right corner of the backdrop and drawn as one smooth
/// gradient. Text and tinted system controls cannot take a gradient, so the theme also carries one
/// solid `textHex` for link text, accent icons and `.tint`.
///
/// The other three themes have no gradient and keep their solid accent.
enum FlowtypeAccent {
    /// Three stops, leading to trailing.
    static let fillStops = ["#FBD8C3", "#E3CFE0", "#ACCDF2"]
    /// Text and icons drawn on the fill (the ink colour; the fill is light).
    static let onFillHex = "#2F3034"
    /// The single solid accent for link text, accent icons and system tint.
    static let textHex = "#6F5FA6"

    static func gradient(stops hexes: [String] = fillStops) -> LinearGradient {
        LinearGradient(colors: hexes.map { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing)
    }
}

/// The Flowtype Dawn page's "clean white" tuning (owner choice C 冷白清透, 2026-10-12, D45): a
/// near-white base, richer corner colour, a soft white glow in the middle, and white cards lifted
/// by a Dawn-violet edge and shadow instead of a grey rim. Only themes with a backdrop use these.
enum FlowtypeDawnSurface {
    /// Page base colour (owner choice C, 2026-10-12): 98.5% lightness, neutral.
    static let baseHex = "#FBFBFB"
    /// Saturation applied to both corner images (owner choice C, 2026-10-12).
    static let cornerSaturation = 1.25
    /// Opacity of the second copy of each corner image drawn on top, which keeps the colour rich
    /// now that the base is white (owner choice C, 2026-10-12).
    static let cornerDensity = 0.45
    /// Peak opacity of the white glow in the middle of the page (owner choice C, 2026-10-12).
    static let centreGlow = 0.20
    /// The glow's inner stop, as a fraction of its peak, reached 45% of the way out.
    static let centreGlowMidFraction = 0.6
    static let centreGlowMidLocation = 0.45
    /// The glow ellipse: radii as a fraction of the window, centred at (x, y) fractions.
    static let centreGlowRadius = CGSize(width: 0.34, height: 0.40)
    static let centreGlowCentre = CGPoint(x: 0.60, y: 0.46)
    /// Card edge and shadow colour: the Dawn violet (owner choice C, 2026-10-12).
    static let edgeHex = FlowtypeAccent.textHex
    static let edgeOpacity = 0.08
    static let shadowOpacity = 0.14
    /// A SwiftUI shadow radius is about half a CSS blur; the mock-up used a CSS blur of 8px.
    static let shadowRadius: CGFloat = 4
    static let shadowOffsetY: CGFloat = 2

    static var edge: Color { Color(hex: edgeHex).opacity(edgeOpacity) }
    static var shadow: Color { Color(hex: edgeHex).opacity(shadowOpacity) }
}

extension AppTheme {
    /// What a filled or stroked accent shape is painted with: the blend for Flowtype, the solid
    /// accent for every other theme.
    var accentFill: AnyShapeStyle {
        guard let stops = accentGradientHexes else { return AnyShapeStyle(accent) }
        return AnyShapeStyle(FlowtypeAccent.gradient(stops: stops))
    }

    /// The accent for an outline. Solid themes keep their translucent outline; the gradient is
    /// used as it is, because a faded pastel stroke disappears on white.
    func accentOutline(solidOpacity: Double = 1) -> AnyShapeStyle {
        accentGradientHexes == nil ? AnyShapeStyle(accent.opacity(solidOpacity)) : accentFill
    }
}

extension AppTheme {
    /// Recording marks (owner choice "3", 2026-10-12): a gradient theme paints them in its blend,
    /// each mark taking its place along the stops and glowing in that colour; a solid theme keeps
    /// its voice colour and no glow. Mirrors the real capsule in `FloatingCapsulePanel`.
    var voiceGlows: Bool { accentGradientHexes != nil }

    func voiceColors(count: Int) -> [Color] {
        guard let stops = accentGradientHexes else { return Array(repeating: voice, count: count) }
        return WaveformPalette.colors(stops: stops, count: count).map {
            Color(.sRGB, red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.alpha)
        }
    }

    /// A larger recording shape (the held fn key, its hold ring, the hold timer pill).
    var voiceFill: AnyShapeStyle {
        guard let stops = accentGradientHexes else { return AnyShapeStyle(voice) }
        return AnyShapeStyle(FlowtypeAccent.gradient(stops: stops))
    }

    /// The glow around a recording shape: the blend's middle colour, or the voice colour.
    var voiceGlow: Color {
        voiceGlows ? voiceColors(count: 3)[1] : voice
    }

    /// Recording text and icons on a light page. The pale blend would vanish there, so a gradient
    /// theme uses its solid text accent instead.
    var voiceInk: Color {
        voiceGlows ? accent : voice
    }
}

/// An accent-filled surface: a solid accent, or the blend for a gradient theme.
struct AccentSurface<S: InsettableShape>: View {
    let theme: AppTheme
    let shape: S

    var body: some View {
        shape.fill(theme.accentFill)
    }
}
