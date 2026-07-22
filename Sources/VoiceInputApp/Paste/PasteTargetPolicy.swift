import AppKit

enum PasteTargetPolicy {
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
