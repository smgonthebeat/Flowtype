import Foundation

/// Fn is hold-to-talk. Users who expect tap-to-start / tap-to-stop release
/// the key almost immediately (owner report, 2026-10-10); a recording that
/// short holds no usable speech, so it gets a "hold Fn" hint instead of a
/// generic no-speech failure.
enum FnPressPolicy {
    static let accidentalTapThreshold: TimeInterval = 0.3

    static func isAccidentalTap(recordingDuration: TimeInterval) -> Bool {
        recordingDuration < accidentalTapThreshold
    }
}
