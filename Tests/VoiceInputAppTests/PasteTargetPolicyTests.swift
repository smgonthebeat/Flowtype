import AppKit
import XCTest
@testable import VoiceInputApp

final class PasteTargetPolicyTests: XCTestCase {
    func testExpectedIdentityRequiresMatchingPIDAndBundleIdentifier() {
        let expected = PasteTargetIdentity(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Editor"
        )

        XCTAssertTrue(PasteTargetPolicy.matchesExpectedIdentity(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Editor",
            expected: expected
        ))
        XCTAssertFalse(PasteTargetPolicy.matchesExpectedIdentity(
            processIdentifier: 43,
            bundleIdentifier: "com.example.Editor",
            expected: expected
        ))
        XCTAssertFalse(PasteTargetPolicy.matchesExpectedIdentity(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Replacement",
            expected: expected
        ))
    }

    func testExpectedIdentityRejectsMissingCapturedBundleIdentifier() {
        let expected = PasteTargetIdentity(
            processIdentifier: 42,
            bundleIdentifier: nil
        )

        XCTAssertFalse(PasteTargetPolicy.matchesExpectedIdentity(
            processIdentifier: 42,
            bundleIdentifier: nil,
            expected: expected
        ))
    }

    func testRejectsTerminatedAndOwnApplicationTargets() {
        XCTAssertFalse(PasteTargetPolicy.isUsableExternalTarget(
            isTerminated: true,
            processIdentifier: 42,
            bundleIdentifier: "com.example.Notes",
            activationPolicy: .regular,
            ownBundleIdentifier: "com.example.VoiceInput",
            ownProcessIdentifier: 7
        ))

        XCTAssertFalse(PasteTargetPolicy.isUsableExternalTarget(
            isTerminated: false,
            processIdentifier: 7,
            bundleIdentifier: "com.example.VoiceInput",
            activationPolicy: .regular,
            ownBundleIdentifier: "com.example.VoiceInput",
            ownProcessIdentifier: 7
        ))
    }

    func testRejectsAppsThatCannotBeActivated() {
        XCTAssertFalse(PasteTargetPolicy.isUsableExternalTarget(
            isTerminated: false,
            processIdentifier: 42,
            bundleIdentifier: "com.example.Agent",
            activationPolicy: .prohibited,
            ownBundleIdentifier: "com.example.VoiceInput",
            ownProcessIdentifier: 7
        ))
    }

    func testAllowsLiveActivatableExternalTargets() {
        XCTAssertTrue(PasteTargetPolicy.isUsableExternalTarget(
            isTerminated: false,
            processIdentifier: 42,
            bundleIdentifier: "com.apple.TextEdit",
            activationPolicy: .regular,
            ownBundleIdentifier: "com.example.VoiceInput",
            ownProcessIdentifier: 7
        ))
    }
    // 2026-10-03 report: the workspace still named System Settings while Claude owned focus.
    func testLiveFocusOwnerWinsOverStaleWorkspaceState() {
        let choice = PasteTargetPolicy.chooseTarget(
            focused: "com.anthropic.claudefordesktop",
            frontmost: "com.apple.systempreferences",
            lastActivated: "com.apple.systempreferences",
            isUsable: { _ in true }
        )

        XCTAssertEqual(choice?.candidate, "com.anthropic.claudefordesktop")
        XCTAssertEqual(choice?.source, .focusedApplication)
    }

    func testTargetFallsBackWhenFocusIsUnreadableOrUnusable() {
        let unreadable = PasteTargetPolicy.chooseTarget(
            focused: nil,
            frontmost: "com.apple.TextEdit",
            lastActivated: "com.apple.Notes",
            isUsable: { _ in true }
        )
        XCTAssertEqual(unreadable?.candidate, "com.apple.TextEdit")
        XCTAssertEqual(unreadable?.source, .frontmostApplication)

        // Flowtype's own window owning focus is not a target; the last external app is.
        let ownWindowFocused = PasteTargetPolicy.chooseTarget(
            focused: "com.smg.flowtype",
            frontmost: "com.smg.flowtype",
            lastActivated: "com.apple.Notes",
            isUsable: { $0 != "com.smg.flowtype" }
        )
        XCTAssertEqual(ownWindowFocused?.candidate, "com.apple.Notes")
        XCTAssertEqual(ownWindowFocused?.source, .lastActivated)

        XCTAssertNil(PasteTargetPolicy.chooseTarget(
            focused: String?.none,
            frontmost: nil,
            lastActivated: nil,
            isUsable: { _ in true }
        ))
    }

    func testLiveFrontPrefersFocusOwnerAndFallsBackToWorkspace() {
        XCTAssertEqual(PasteTargetPolicy.liveFrontProcessIdentifier(focused: 42, frontmost: 7, ownProcessIdentifier: 1), 42)
        XCTAssertEqual(PasteTargetPolicy.liveFrontProcessIdentifier(focused: nil, frontmost: 7, ownProcessIdentifier: 1), 7)
        XCTAssertNil(PasteTargetPolicy.liveFrontProcessIdentifier(focused: nil, frontmost: nil, ownProcessIdentifier: 1))
        // Flowtype's own menu holding focus must not hide the app the text is going to.
        XCTAssertEqual(PasteTargetPolicy.liveFrontProcessIdentifier(focused: 1, frontmost: 7, ownProcessIdentifier: 1), 7)
    }

    // 2026-10-03 report: Cmd+V on Finder's Desktop created a text clipping file.
    func testFinderOnlyAcceptsTextWhenATextFieldHasFocus() {
        let finder = "com.apple.finder"
        XCTAssertFalse(PasteTargetPolicy.acceptsPastedText(bundleIdentifier: finder, focusedRole: "AXList"))
        XCTAssertFalse(PasteTargetPolicy.acceptsPastedText(bundleIdentifier: finder, focusedRole: "AXGroup"))
        XCTAssertFalse(PasteTargetPolicy.acceptsPastedText(bundleIdentifier: finder, focusedRole: nil))
        XCTAssertTrue(PasteTargetPolicy.acceptsPastedText(bundleIdentifier: finder, focusedRole: "AXTextField"))
        XCTAssertTrue(PasteTargetPolicy.acceptsPastedText(bundleIdentifier: finder, focusedRole: "AXTextArea"))
    }

    // Electron apps often report no focused element, so other apps are never gated by the role.
    func testOtherAppsAcceptTextWithoutAReadableFocusedElement() {
        XCTAssertTrue(PasteTargetPolicy.acceptsPastedText(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            focusedRole: nil
        ))
        XCTAssertTrue(PasteTargetPolicy.acceptsPastedText(bundleIdentifier: "com.openai.codex", focusedRole: "AXGroup"))
        XCTAssertTrue(PasteTargetPolicy.acceptsPastedText(bundleIdentifier: nil, focusedRole: nil))
    }
}
