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
}
