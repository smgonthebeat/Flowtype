import Foundation

enum PasteSource: String, Sendable {
    case dictation
    case menuLastTranscript
    case history
}

struct PasteTargetIdentity: Equatable, Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
}

/// How the paste target was found, recorded in telemetry so a wrong target can be traced.
enum PasteTargetSource: String, Equatable, Sendable {
    case focusedApplication = "ax_focus"
    case frontmostApplication = "workspace_front"
    case lastActivated = "last_activated"
}

struct PasteAttempt: Equatable, Sendable {
    let id: UUID
    let source: PasteSource
    let text: String
    let target: PasteTargetIdentity?
    var targetSource: PasteTargetSource? = nil
}

enum CopyOnlyReason: String, Equatable, Sendable {
    case missingTarget
    case targetRejected
    case eventCreationFailed
    case inputSourceBusy
    /// The target is front, but its focused element cannot take text (Finder's Desktop).
    case noTextInput
}

enum PasteOutcome: Equatable, Sendable {
    case eventDispatched
    case copiedOnly(reason: CopyOnlyReason)
    case duplicateIgnored
    case invalidText
    case clipboardWriteFailed

    var diagnosticName: String {
        switch self {
        case .eventDispatched:
            return "event_dispatched"
        case let .copiedOnly(reason):
            return "copied_only_\(reason.rawValue)"
        case .duplicateIgnored:
            return "duplicate_ignored"
        case .invalidText:
            return "invalid_text"
        case .clipboardWriteFailed:
            return "clipboard_write_failed"
        }
    }

    var ownsPresentationCompletion: Bool {
        self != .duplicateIgnored
    }
}

struct PasteOperationResult: Equatable, Sendable {
    let outcome: PasteOutcome
    let pasteboardChangeCountBefore: Int
    let pasteboardChangeCountAfter: Int
    let eventPairCount: Int
    let frontmostMatch: Bool?
}
