import SwiftUI

enum AppThemeID: String, CaseIterable, Codable, Identifiable {
    case `default`
    case codex
    case oscurange
    case flowtype

    var id: String { rawValue }
}

/// Artwork painted once behind a window's content (see `ThemeBackdropView`).
enum AppThemeBackdrop: Equatable {
    /// Two corner images cut from the owner's reference icon: warm-on-blue at the bottom-trailing
    /// corner and its warm mirror image at the top-leading corner.
    case referenceCorners
}

struct AppTheme: Equatable {
    let id: AppThemeID
    let displayName: String
    let accentHex: String
    let onAccentHex: String
    let surfaceHex: String
    let inkHex: String
    let diffAddedHex: String
    let diffRemovedHex: String
    let skillHex: String
    let contrast: Int
    let usesSystemMaterials: Bool
    let prefersOpaqueWindows: Bool
    var elevatedSurfaceHex: String
    let controlSurfaceHex: String
    var sidebarSurfaceHex: String
    let hoverSurfaceHex: String
    let borderHex: String
    /// Recording-capsule waveform and status colours (design-spec 2.4).
    let voiceHex: String
    let warningHex: String
    /// True for themes that force the dark window appearance. Unused when `usesSystemMaterials`.
    let isDark: Bool
    let backdrop: AppThemeBackdrop?
    /// Set only by the Flowtype theme: its accent is a gradient (see `FlowtypeAccent`).
    var accentGradientHexes: [String]? = nil

    /// The `NSAppearance` a window should be forced to: the system's own for Apple, otherwise
    /// aqua for a light theme and darkAqua for a dark one.
    var windowAppearance: NSAppearance? {
        if usesSystemMaterials { return nil }
        return NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    /// With Reduce Transparency on, a backdrop theme keeps its artwork but its cards and sidebar
    /// become opaque white. Other themes are returned unchanged.
    func resolvingReduceTransparency(_ reduceTransparency: Bool) -> AppTheme {
        guard reduceTransparency, backdrop != nil else { return self }
        var resolved = self
        resolved.elevatedSurfaceHex = "#FFFFFF"
        resolved.sidebarSurfaceHex = "#FFFFFF"
        return resolved
    }

    var accent: Color { color(accentHex) }
    var voice: Color { color(voiceHex) }
    var warning: Color { usesSystemMaterials ? Color(nsColor: .systemOrange) : color(warningHex) }
    var onAccent: Color { color(onAccentHex) }
    var surface: Color { usesSystemMaterials ? Color(nsColor: .windowBackgroundColor) : color(surfaceHex) }
    var ink: Color { usesSystemMaterials ? .primary : color(inkHex) }
    var secondaryInk: Color { usesSystemMaterials ? .secondary : color(inkHex).opacity(0.70) }
    var tertiaryInk: Color { usesSystemMaterials ? Color(nsColor: .tertiaryLabelColor) : color(inkHex).opacity(0.52) }
    var success: Color { color(diffAddedHex) }
    var danger: Color { color(diffRemovedHex) }
    var skill: Color { color(skillHex) }
    var elevatedSurface: Color { usesSystemMaterials ? Color(nsColor: .controlBackgroundColor).opacity(0.90) : color(elevatedSurfaceHex) }
    var controlSurface: Color { usesSystemMaterials ? Color(nsColor: .quaternaryLabelColor).opacity(0.30) : color(controlSurfaceHex) }
    /// Fill for a strip or chip that sits directly on the page rather than inside a card. A backdrop
    /// theme keeps these white like cards, because the grey inset fill goes dirty on the artwork.
    var pageStripSurface: Color { backdrop == nil ? controlSurface : elevatedSurface }
    var sidebarSurface: Color { usesSystemMaterials ? Color(nsColor: .windowBackgroundColor) : color(sidebarSurfaceHex) }
    var hoverSurface: Color { usesSystemMaterials ? Color(nsColor: .quaternaryLabelColor).opacity(0.42) : color(hoverSurfaceHex) }
    var border: Color { usesSystemMaterials ? Color(nsColor: .separatorColor).opacity(0.72) : color(borderHex) }
    /// Outline of a white card sitting on the page. A backdrop theme outlines it in the Dawn violet
    /// (see `FlowtypeDawnSurface`); every other theme keeps its ordinary border.
    var cardEdge: Color { backdrop == nil ? border : FlowtypeDawnSurface.edge }
    var divider: Color { usesSystemMaterials ? Color(nsColor: .separatorColor).opacity(0.58) : color(borderHex).opacity(0.78) }

    static func theme(for id: AppThemeID) -> AppTheme {
        switch id {
        case .default:
            return AppTheme(
                id: .default,
                displayName: "Apple",
                accentHex: "#0A84FF",
                onAccentHex: "#FFFFFF",
                surfaceHex: "#1E1E1E",
                inkHex: "#F5F5F5",
                diffAddedHex: "#30D158",
                diffRemovedHex: "#FF453A",
                skillHex: "#BF5AF2",
                contrast: 50,
                usesSystemMaterials: true,
                prefersOpaqueWindows: false,
                elevatedSurfaceHex: "#2C2C2E",
                controlSurfaceHex: "#3A3A3C",
                sidebarSurfaceHex: "#242426",
                hoverSurfaceHex: "#3A3A3C",
                borderHex: "#48484A",
                voiceHex: "#409CFF",
                warningHex: "#FF9F0A",
                isDark: true,
                backdrop: nil
            )
        case .codex:
            return AppTheme(
                id: .codex,
                displayName: "Codex",
                accentHex: "#0169CC",
                onAccentHex: "#FFFFFF",
                surfaceHex: "#111111",
                inkHex: "#FCFCFC",
                diffAddedHex: "#00A240",
                diffRemovedHex: "#E02E2A",
                skillHex: "#B06DFF",
                contrast: 60,
                usesSystemMaterials: false,
                prefersOpaqueWindows: false,
                elevatedSurfaceHex: "#1C1C1C",
                controlSurfaceHex: "#252525",
                sidebarSurfaceHex: "#161616",
                hoverSurfaceHex: "#292929",
                borderHex: "#363636",
                voiceHex: "#4DA3FF",
                warningHex: "#E8A013",
                isDark: true,
                backdrop: nil
            )
        case .oscurange:
            return AppTheme(
                id: .oscurange,
                displayName: "Oscurange",
                accentHex: "#F9B98C",
                onAccentHex: "#33210F",
                surfaceHex: "#0B0B0F",
                inkHex: "#E6E6E6",
                diffAddedHex: "#40C977",
                diffRemovedHex: "#FA423E",
                skillHex: "#479FFA",
                contrast: 50,
                usesSystemMaterials: false,
                prefersOpaqueWindows: true,
                elevatedSurfaceHex: "#17171D",
                controlSurfaceHex: "#23232A",
                sidebarSurfaceHex: "#101014",
                hoverSurfaceHex: "#2A2524",
                borderHex: "#343038",
                voiceHex: "#F9B98C",
                warningHex: "#F5C24B",
                isDark: true,
                backdrop: nil
            )
        case .flowtype:
            return AppTheme(
                id: .flowtype,
                displayName: "Flowtype Dawn",
                accentHex: FlowtypeAccent.textHex,
                onAccentHex: FlowtypeAccent.onFillHex,
                surfaceHex: FlowtypeDawnSurface.baseHex,
                inkHex: "#2F3034",
                diffAddedHex: "#1F9D55",
                diffRemovedHex: "#D93A35",
                skillHex: "#7A5CC9",
                contrast: 50,
                usesSystemMaterials: false,
                prefersOpaqueWindows: true,
                elevatedSurfaceHex: "#FFFFFF",
                controlSurfaceHex: "#2F30340A",
                sidebarSurfaceHex: "#FFFFFF4D",
                hoverSurfaceHex: "#2F303414",
                borderHex: "#2F303412",
                voiceHex: "#5B9BE6",
                warningHex: "#C27A12",
                isDark: false,
                backdrop: .referenceCorners,
                accentGradientHexes: FlowtypeAccent.fillStops
            )
        }
    }

    private func color(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

extension Color {
    /// Accepts `#RRGGBB` or `#RRGGBBAA`.
    init(hex: String) {
        let components = HexColor.components(hex)
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.alpha
        )
    }
}

enum HexColor {
    struct Components: Equatable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    /// Parses `#RRGGBB` (alpha 1) or `#RRGGBBAA`. Anything else is read as a six-digit value,
    /// which keeps the long-standing behaviour for malformed input.
    static func components(_ hex: String) -> Components {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&value)

        if cleanHex.count == 8 {
            return Components(
                red: Double((value >> 24) & 0xFF) / 255.0,
                green: Double((value >> 16) & 0xFF) / 255.0,
                blue: Double((value >> 8) & 0xFF) / 255.0,
                alpha: Double(value & 0xFF) / 255.0
            )
        }

        return Components(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            alpha: 1
        )
    }
}
