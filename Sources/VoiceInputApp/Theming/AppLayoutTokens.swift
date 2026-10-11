import SwiftUI

/// 4pt spacing grid and its fixed uses.
enum AppSpacing {
    static let x1: CGFloat = 4
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    static let x8: CGFloat = 32
    static let x10: CGFloat = 40

    static let pageGutter: CGFloat = 32
    static let titleToSubtitle: CGFloat = 6
    static let headerToContent: CGFloat = 24
    static let sectionGap: CGFloat = 32
    static let sectionTitleToContent: CGFloat = 12
    static let subheadToRows: CGFloat = 8
    static let cardGap: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let rowVertical: CGFloat = 12
    static let rowHorizontal: CGFloat = 16
    static let controlGap: CGFloat = 8
    static let chipGap: CGFloat = 8
}

/// Three corner radii, all continuous. Capsules are reserved for tags, switches and the recording capsule.
enum AppRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
}

/// One feedback motion for hover, press, focus and inline feedback. Navigation, list reflow,
/// theme switches and artwork stay static (2026-07-17 motion decision).
enum AppMotion {
    static let feedbackDuration: TimeInterval = 0.12

    static func feedback(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: feedbackDuration)
    }
}
