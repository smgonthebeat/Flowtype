import XCTest
@testable import VoiceInputApp

final class PermissionReadinessInspectorTests: XCTestCase {
    func testGrantedMicrophoneAndAccessibilityAreReadyAndSpeechCanBeOmitted() {
        let snapshot = PermissionSnapshot(
            microphone: .granted,
            accessibility: .granted,
            speechRecognition: .notDetermined
        )

        let checks = PermissionReadinessInspector().inspect(snapshot: snapshot, includeSpeechRecognition: false)

        XCTAssertEqual(checks.check("microphone-permission")?.status, .ready)
        XCTAssertEqual(checks.check("accessibility-permission")?.status, .ready)
        XCTAssertNil(checks.check("speech-recognition-permission"))
    }

    func testMissingAccessibilityShowsOpenSettingsAction() {
        let snapshot = PermissionSnapshot(
            microphone: .granted,
            accessibility: .notDetermined,
            speechRecognition: .notDetermined
        )

        let checks = PermissionReadinessInspector().inspect(snapshot: snapshot, includeSpeechRecognition: false)

        XCTAssertEqual(checks.check("accessibility-permission")?.status, .notReady)
        XCTAssertEqual(checks.check("accessibility-permission")?.primaryAction, .openAccessibilitySettings)
    }

    func testDeniedMicrophoneFailsWithRequestAction() {
        let snapshot = PermissionSnapshot(
            microphone: .denied,
            accessibility: .granted,
            speechRecognition: .granted
        )

        let checks = PermissionReadinessInspector().inspect(snapshot: snapshot, includeSpeechRecognition: false)

        XCTAssertEqual(checks.check("microphone-permission")?.status, .failed("Microphone permission is denied."))
        XCTAssertEqual(checks.check("microphone-permission")?.primaryAction, .requestMicrophone)
    }

    func testSpeechRecognitionIncludedMapsAllStates() {
        let granted = PermissionReadinessInspector().inspect(
            snapshot: PermissionSnapshot(microphone: .granted, accessibility: .granted, speechRecognition: .granted),
            includeSpeechRecognition: true
        )
        let denied = PermissionReadinessInspector().inspect(
            snapshot: PermissionSnapshot(microphone: .granted, accessibility: .granted, speechRecognition: .denied),
            includeSpeechRecognition: true
        )
        let notDetermined = PermissionReadinessInspector().inspect(
            snapshot: PermissionSnapshot(microphone: .granted, accessibility: .granted, speechRecognition: .notDetermined),
            includeSpeechRecognition: true
        )
        let unknown = PermissionReadinessInspector().inspect(
            snapshot: PermissionSnapshot(microphone: .granted, accessibility: .granted, speechRecognition: .unknown),
            includeSpeechRecognition: true
        )

        XCTAssertEqual(granted.check("speech-recognition-permission")?.status, .ready)
        XCTAssertEqual(denied.check("speech-recognition-permission")?.status, .failed("Speech Recognition permission is denied."))
        XCTAssertEqual(notDetermined.check("speech-recognition-permission")?.status, .notReady)
        XCTAssertEqual(unknown.check("speech-recognition-permission")?.status, .unknown)
        XCTAssertEqual(notDetermined.check("speech-recognition-permission")?.primaryAction, .requestSpeechRecognition)
    }

    func testUnknownAccessibilityKeepsSettingsAction() {
        let snapshot = PermissionSnapshot(
            microphone: .granted,
            accessibility: .unknown,
            speechRecognition: .granted
        )

        let checks = PermissionReadinessInspector().inspect(snapshot: snapshot, includeSpeechRecognition: false)

        XCTAssertEqual(checks.check("accessibility-permission")?.status, .unknown)
        XCTAssertEqual(checks.check("accessibility-permission")?.primaryAction, .openAccessibilitySettings)
    }
}

private extension Array where Element == ReadinessCheck {
    func check(_ id: String) -> ReadinessCheck? {
        first { $0.id == id }
    }
}
