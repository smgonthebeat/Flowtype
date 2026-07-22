import SwiftUI

enum InlineFeedbackMotion {
    static let usesOpacityOnly = true
    static let animatesLayout = false

    static func duration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0.08 : 0.12
    }

    static func animation(reduceMotion: Bool) -> Animation {
        .easeOut(duration: duration(reduceMotion: reduceMotion))
    }
}
