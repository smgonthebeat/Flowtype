import CoreGraphics

enum MainWindowDetailLayout {
    static let compactWidthThreshold: CGFloat = 760
    static let compactHorizontalPadding: CGFloat = 24
    static let regularHorizontalPadding: CGFloat = 36
    static let topPadding: CGFloat = 34
    static let bottomPadding: CGFloat = 32

    static let standardContentMaxWidth: CGFloat = 980
    static let wideContentMaxWidth: CGFloat = 1180

    static let readinessContentMaxWidth = standardContentMaxWidth
    static let modelsContentMaxWidth = standardContentMaxWidth
    static let preferencesContentMaxWidth = standardContentMaxWidth

    static let homeContentMaxWidth = wideContentMaxWidth
    static let dictionaryContentMaxWidth = wideContentMaxWidth

    static func horizontalPadding(forWidth width: CGFloat) -> CGFloat {
        width < compactWidthThreshold ? compactHorizontalPadding : regularHorizontalPadding
    }
}
