import SwiftUI

/// The seven text roles of the type scale. Every role uses the default design (no rounded, no bold);
/// semibold is reserved for the three largest roles.
enum AppTextRole: CaseIterable {
    case display
    case title
    case heading
    case label
    case body
    case secondary
    case caption

    var size: CGFloat {
        switch self {
        case .display: return 28
        case .title: return 24
        case .heading: return 15
        case .label, .body: return 13
        case .secondary: return 12
        case .caption: return 11
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .title, .heading: return .semibold
        case .label, .caption: return .medium
        case .body, .secondary: return .regular
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display: return -0.4
        case .title: return -0.3
        default: return 0
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .body: return 4
        case .secondary: return 3
        default: return 0
        }
    }

    var usesMonospacedDigits: Bool {
        self == .display || self == .caption
    }

    /// AppKit font with the same metrics, for text measurement that must match SwiftUI rendering.
    var nsFont: NSFont {
        let nsWeight: NSFont.Weight
        switch weight {
        case .semibold: nsWeight = .semibold
        case .medium: nsWeight = .medium
        default: nsWeight = .regular
        }
        return usesMonospacedDigits
            ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: nsWeight)
            : NSFont.systemFont(ofSize: size, weight: nsWeight)
    }
}

extension View {
    /// Applies a type-scale role at the current interface text size: font, tracking and line
    /// spacing together. `nsFont` stays at the base size for AppKit surfaces that do not scale.
    func appText(_ role: AppTextRole) -> some View {
        scaledFont(size: role.size, weight: role.weight, monospacedDigit: role.usesMonospacedDigits)
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
    }
}

/// SF Symbol sizes that follow the adjacent text role.
enum AppSymbolSize {
    static let besideCaption: CGFloat = 10
    static let besideLabel: CGFloat = 13
    static let rowLeading: CGFloat = 15
    static let rowLeadingSlot: CGFloat = 20
    static let banner: CGFloat = 20
}

/// Maximum text widths for readable line lengths.
enum AppTextWidth {
    static let transcript: CGFloat = 640
    static let pageSubtitle: CGFloat = 560
    static let helpParagraph: CGFloat = 520
    static let onboardingParagraph: CGFloat = 440
    static let emptyState: CGFloat = 360
}
