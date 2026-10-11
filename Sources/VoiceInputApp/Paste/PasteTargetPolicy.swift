import AppKit

enum PasteTargetPolicy {
    /// Picks the paste target from the live focus owner first, then the workspace's frontmost
    /// app, then the last app seen activating. Each candidate must be a usable external target.
    static func chooseTarget<Candidate>(
        focused: Candidate?,
        frontmost: Candidate?,
        lastActivated: Candidate?,
        isUsable: (Candidate) -> Bool
    ) -> (candidate: Candidate, source: PasteTargetSource)? {
        let ordered: [(Candidate?, PasteTargetSource)] = [
            (focused, .focusedApplication),
            (frontmost, .frontmostApplication),
            (lastActivated, .lastActivated)
        ]
        for case let (candidate?, source) in ordered where isUsable(candidate) {
            return (candidate, source)
        }
        return nil
    }

    /// The live focus owner wins; the workspace's frontmost app is only a fallback for when
    /// Accessibility cannot answer, because it can lag the real focus (2026-10-03 report).
    /// Flowtype itself is never a paste target, so a transient own focus (its menu-bar menu
    /// while it closes) also falls back instead of blocking a paste into the app underneath.
    static func liveFrontProcessIdentifier(
        focused: pid_t?,
        frontmost: pid_t?,
        ownProcessIdentifier: pid_t
    ) -> pid_t? {
        guard let focused, focused != ownProcessIdentifier else { return frontmost }
        return focused
    }

    /// Apps where Cmd+V outside a text field does something other than inserting text.
    /// Finder turns pasted text into a text clipping file on the Desktop (2026-10-03 report).
    /// Electron apps such as Claude and Codex are deliberately absent: they do not reliably
    /// expose their focused element to Accessibility, so a role check would block real pastes.
    static let textInputRequiredBundleIdentifiers: Set<String> = ["com.apple.finder"]

    static let textInputRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox"]

    static func acceptsPastedText(bundleIdentifier: String?, focusedRole: String?) -> Bool {
        guard let bundleIdentifier,
              textInputRequiredBundleIdentifiers.contains(bundleIdentifier) else {
            return true
        }
        guard let focusedRole else { return false }
        return textInputRoles.contains(focusedRole)
    }

    static func matchesExpectedIdentity(
        processIdentifier: pid_t,
        bundleIdentifier: String?,
        expected: PasteTargetIdentity
    ) -> Bool {
        guard processIdentifier == expected.processIdentifier else { return false }
        guard let expectedBundleIdentifier = expected.bundleIdentifier else { return false }
        return bundleIdentifier == expectedBundleIdentifier
    }

    static func isUsableExternalTarget(
        _ application: NSRunningApplication?,
        ownBundleIdentifier: String?,
        ownProcessIdentifier: pid_t
    ) -> Bool {
        guard let application else { return false }
        return isUsableExternalTarget(
            isTerminated: application.isTerminated,
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            activationPolicy: application.activationPolicy,
            ownBundleIdentifier: ownBundleIdentifier,
            ownProcessIdentifier: ownProcessIdentifier
        )
    }

    static func isUsableExternalTarget(
        isTerminated: Bool,
        processIdentifier: pid_t,
        bundleIdentifier: String?,
        activationPolicy: NSApplication.ActivationPolicy,
        ownBundleIdentifier: String?,
        ownProcessIdentifier: pid_t
    ) -> Bool {
        guard !isTerminated else { return false }
        guard processIdentifier != ownProcessIdentifier else { return false }
        if let bundleIdentifier, bundleIdentifier == ownBundleIdentifier {
            return false
        }

        switch activationPolicy {
        case .regular, .accessory:
            return true
        case .prohibited:
            return false
        @unknown default:
            return false
        }
    }
}
