import XCTest
@testable import VoiceInputApp

final class PermissionFlowPolicyTests: XCTestCase {
    func testRoutesToSetupStatusWhenRequiredPermissionIsMissing() {
        let report = ReadinessReport(generatedAt: Date(), checks: [
            ReadinessCheck(
                id: "microphone-permission",
                group: .permissions,
                title: "Microphone",
                detail: "",
                status: .notReady
            ),
            ReadinessCheck(
                id: "accessibility-permission",
                group: .permissions,
                title: "Accessibility",
                detail: "",
                status: .ready
            )
        ])

        XCTAssertTrue(PermissionFlowPolicy.shouldOpenSetupStatusOnLaunch(report: report))
    }

    func testDoesNotRouteWhenRequiredPermissionsAreReady() {
        let report = ReadinessReport(generatedAt: Date(), checks: [
            ReadinessCheck(
                id: "microphone-permission",
                group: .permissions,
                title: "Microphone",
                detail: "",
                status: .ready
            ),
            ReadinessCheck(
                id: "accessibility-permission",
                group: .permissions,
                title: "Accessibility",
                detail: "",
                status: .ready
            )
        ])

        XCTAssertFalse(PermissionFlowPolicy.shouldOpenSetupStatusOnLaunch(report: report))
    }

    func testSpeechRecognitionBlocksOnlyWhenItIsInTheCurrentReport() {
        let qwenReport = ReadinessReport(generatedAt: Date(), checks: [
            ReadinessCheck(
                id: "microphone-permission",
                group: .permissions,
                title: "Microphone",
                detail: "",
                status: .ready
            ),
            ReadinessCheck(
                id: "accessibility-permission",
                group: .permissions,
                title: "Accessibility",
                detail: "",
                status: .ready
            )
        ])
        let appleSpeechReport = ReadinessReport(generatedAt: Date(), checks: [
            ReadinessCheck(
                id: "microphone-permission",
                group: .permissions,
                title: "Microphone",
                detail: "",
                status: .ready
            ),
            ReadinessCheck(
                id: "accessibility-permission",
                group: .permissions,
                title: "Accessibility",
                detail: "",
                status: .ready
            ),
            ReadinessCheck(
                id: "speech-recognition-permission",
                group: .permissions,
                title: "Speech Recognition",
                detail: "",
                status: .notReady
            )
        ])

        XCTAssertFalse(PermissionFlowPolicy.shouldOpenSetupStatusOnLaunch(report: qwenReport))
        XCTAssertTrue(PermissionFlowPolicy.shouldOpenSetupStatusOnLaunch(report: appleSpeechReport))
    }

    func testNextAuthorizationActionUsesPermissionOrder() {
        let missingMicrophone = ReadinessReport(generatedAt: Date(), checks: [
            ReadinessCheck(
                id: "microphone-permission",
                group: .permissions,
                title: "Microphone",
                detail: "",
                status: .notReady,
                primaryAction: .requestMicrophone
            ),
            ReadinessCheck(
                id: "accessibility-permission",
                group: .permissions,
                title: "Accessibility",
                detail: "",
                status: .notReady,
                primaryAction: .openAccessibilitySettings
            )
        ])
        let missingAccessibility = ReadinessReport(generatedAt: Date(), checks: [
            ReadinessCheck(
                id: "microphone-permission",
                group: .permissions,
                title: "Microphone",
                detail: "",
                status: .ready
            ),
            ReadinessCheck(
                id: "accessibility-permission",
                group: .permissions,
                title: "Accessibility",
                detail: "",
                status: .notReady,
                primaryAction: .openAccessibilitySettings
            )
        ])
        let missingSpeechRecognition = ReadinessReport(generatedAt: Date(), checks: [
            ReadinessCheck(
                id: "microphone-permission",
                group: .permissions,
                title: "Microphone",
                detail: "",
                status: .ready
            ),
            ReadinessCheck(
                id: "accessibility-permission",
                group: .permissions,
                title: "Accessibility",
                detail: "",
                status: .ready
            ),
            ReadinessCheck(
                id: "speech-recognition-permission",
                group: .permissions,
                title: "Speech Recognition",
                detail: "",
                status: .notReady,
                primaryAction: .requestSpeechRecognition
            )
        ])

        XCTAssertEqual(PermissionFlowPolicy.nextAuthorizationAction(report: missingMicrophone), .requestMicrophone)
        XCTAssertEqual(PermissionFlowPolicy.nextAuthorizationAction(report: missingAccessibility), .openAccessibilitySettings)
        XCTAssertEqual(PermissionFlowPolicy.nextAuthorizationAction(report: missingSpeechRecognition), .requestSpeechRecognition)
    }

    func testNextAuthorizationActionIsNilWhenPermissionsAreReady() {
        let report = ReadinessReport(generatedAt: Date(), checks: [
            ReadinessCheck(
                id: "microphone-permission",
                group: .permissions,
                title: "Microphone",
                detail: "",
                status: .ready
            ),
            ReadinessCheck(
                id: "accessibility-permission",
                group: .permissions,
                title: "Accessibility",
                detail: "",
                status: .ready
            )
        ])

        XCTAssertNil(PermissionFlowPolicy.nextAuthorizationAction(report: report))
    }
}
