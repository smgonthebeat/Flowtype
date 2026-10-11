import ApplicationServices

/// Live keyboard-focus queries through Accessibility, which Flowtype already holds for pasting.
///
/// Owner report (2026-10-03): `NSWorkspace.frontmostApplication` and the last activation
/// notification both still named System Settings about 40 s after the owner had switched to
/// Claude, so the dictation was rejected and only copied. Accessibility asks the window server
/// for the current focus owner on every call instead of relying on cached workspace state.
enum FocusedApplicationReader {
    /// Keeps a hung app from stalling the Fn press or the paste.
    private static let messagingTimeout: Float = 0.25

    /// Process that owns keyboard focus right now, or nil when Accessibility cannot answer.
    static func focusedProcessIdentifier() -> pid_t? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, messagingTimeout)
        guard let application = elementAttribute(kAXFocusedApplicationAttribute, of: systemWide) else {
            return nil
        }
        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(application, &processIdentifier) == .success,
              processIdentifier > 0 else {
            return nil
        }
        return processIdentifier
    }

    /// Accessibility role of the focused element inside an app, or nil when it cannot be read.
    static func focusedElementRole(processIdentifier: pid_t) -> String? {
        let application = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(application, messagingTimeout)
        guard let element = elementAttribute(kAXFocusedUIElementAttribute, of: application) else {
            return nil
        }
        var role: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success else {
            return nil
        }
        return role as? String
    }

    private static func elementAttribute(_ attribute: String, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }
}
