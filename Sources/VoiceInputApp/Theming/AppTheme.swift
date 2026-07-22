import SwiftUI

enum AppThemeID: String, CaseIterable, Codable, Identifiable {
    case `default`
    case codex
    case oscurange

    var id: String { rawValue }
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
    let elevatedSurfaceHex: String
    let controlSurfaceHex: String
    let sidebarSurfaceHex: String
    let hoverSurfaceHex: String
    let borderHex: String

    var accent: Color { color(accentHex) }
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
    var sidebarSurface: Color { usesSystemMaterials ? Color(nsColor: .windowBackgroundColor) : color(sidebarSurfaceHex) }
    var hoverSurface: Color { usesSystemMaterials ? Color(nsColor: .quaternaryLabelColor).opacity(0.42) : color(hoverSurfaceHex) }
    var border: Color { usesSystemMaterials ? Color(nsColor: .separatorColor).opacity(0.72) : color(borderHex) }
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
                borderHex: "#48484A"
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
                borderHex: "#363636"
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
                borderHex: "#343038"
            )
        }
    }

    private func color(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
