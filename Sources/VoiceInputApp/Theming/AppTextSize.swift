import Combine
import SwiftUI

/// The three interface text sizes (2026-10-11). `small` reproduces the sizes the app used
/// before the setting existed. Owner decision after the first version: keep the original
/// layout and only make reading text a little larger, so only text below `layoutThreshold`
/// scales and the default `standard` adds about 8% (body 13 → 14pt).
enum AppTextSize: String, CaseIterable, Codable {
    case small
    case standard
    case large

    static let defaultSize: AppTextSize = .standard

    /// Multiplier for text below `displayThreshold`.
    var factor: CGFloat {
        switch self {
        case .small: return 1.0
        case .standard: return 1.08
        case .large: return 1.16
        }
    }

    /// Text at or above this size (page titles, sidebar navigation, stat numbers, section
    /// headings) keeps its original size, so the layout does not change.
    static let layoutThreshold: CGFloat = 15

    func scaled(_ base: CGFloat) -> CGFloat {
        guard base < Self.layoutThreshold else { return base }
        // Half-point steps keep glyphs on whole device pixels on Retina displays.
        return (base * factor * 2).rounded() / 2
    }

    /// Widths of fixed columns that hold text grow with it, so labels keep to one line.
    func scaledWidth(_ base: CGFloat) -> CGFloat {
        (base * factor).rounded()
    }

    var larger: AppTextSize? {
        switch self {
        case .small: return .standard
        case .standard: return .large
        case .large: return nil
        }
    }

    var smaller: AppTextSize? {
        switch self {
        case .small: return nil
        case .standard: return .small
        case .large: return .standard
        }
    }
}

/// The live text size every window reads. One shared value means a change from Settings or
/// from ⌘+ / ⌘− reaches all open windows at once, without each window wiring its own reload.
/// `SettingsStore.textSize` is the persisted source and keeps this in step.
final class AppTextSizeModel: ObservableObject {
    static let shared = AppTextSizeModel()

    @Published var size: AppTextSize

    init(size: AppTextSize = SettingsStore.storedTextSize()) {
        self.size = size
    }
}

/// macOS text styles the app uses, with their system point sizes and weights.
enum AppFontStyle {
    case body
    case callout
    case caption
    case headline
    case title3
    case title2

    var baseSize: CGFloat {
        switch self {
        case .body, .headline: return 13
        case .callout: return 12
        case .caption: return 10
        case .title3: return 15
        case .title2: return 17
        }
    }

    var defaultWeight: Font.Weight {
        self == .headline ? .bold : .regular
    }
}

private struct ScaledFontModifier: ViewModifier {
    @ObservedObject private var model = AppTextSizeModel.shared

    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let monospacedDigit: Bool

    func body(content: Content) -> some View {
        let font = Font.system(size: model.size.scaled(baseSize), weight: weight, design: design)
        return content.font(monospacedDigit ? font.monospacedDigit() : font)
    }
}

/// Sets the default font for controls and text that name no font of their own.
private struct BaseTextSizeModifier: ViewModifier {
    @ObservedObject private var model = AppTextSizeModel.shared

    func body(content: Content) -> some View {
        content.font(.system(size: model.size.scaled(AppFontStyle.body.baseSize)))
    }
}

extension View {
    /// A macOS text style at the current interface text size.
    func scaledFont(
        _ style: AppFontStyle,
        weight: Font.Weight? = nil,
        design: Font.Design = .default,
        monospacedDigit: Bool = false
    ) -> some View {
        modifier(ScaledFontModifier(
            baseSize: style.baseSize,
            weight: weight ?? style.defaultWeight,
            design: design,
            monospacedDigit: monospacedDigit
        ))
    }

    /// A fixed point size (as designed for the small size) at the current interface text size.
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        monospacedDigit: Bool = false
    ) -> some View {
        modifier(ScaledFontModifier(baseSize: size, weight: weight, design: design, monospacedDigit: monospacedDigit))
    }

    /// Applied at each window root so unstyled text and control labels follow the text size too.
    func flowtypeTextSize() -> some View {
        modifier(BaseTextSizeModifier())
    }
}
